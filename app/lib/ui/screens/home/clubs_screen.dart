import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../data/club_chat_repository.dart';
import '../../../data/club_member_repository.dart';
import '../../../data/club_repository.dart';
import '../../../data/direct_message_repository.dart';
import '../../../data/membership_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../data/sample_clubs.dart';
import '../../../models/club.dart';
import '../../../models/direct_message.dart';
import '../../../models/user_profile.dart';
import '../../widgets/ad_banner.dart';
import 'club_chat_screen.dart';
import 'direct_message_screen.dart';

enum _ClubJoinFilterTab { joined, discover, dm }

class ClubsScreen extends StatefulWidget {
  static const routeName = '/clubs';

  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  final _searchCtrl = TextEditingController();
  final _chatRepository = clubChatRepository();

  String _selectedSport = 'All';
  _ClubJoinFilterTab _joinFilterTab = _ClubJoinFilterTab.joined;
  late Future<List<Club>> _clubsFuture;
  late Future<List<ClubMember>> _membershipsFuture;
  late Future<MembershipStatus> _membershipFuture;
  late Future<List<DirectMessageThread>> _dmThreadsFuture;
  int _chatMetaRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _clubsFuture = clubRepository().listClubs();
    _membershipsFuture = currentUserId.trim().isEmpty
        ? Future.value(const <ClubMember>[])
        : clubMemberRepository().listMembershipsForUser(userId: currentUserId);
    _membershipFuture = membershipRepository().getStatus();
    _dmThreadsFuture = directMessageRepository().listThreadsForUser(
      userId: currentUserId,
    );
  }

  void _refreshClubs() {
    setState(() {
      _clubsFuture = clubRepository().listClubs();
      _membershipsFuture = currentUserId.trim().isEmpty
          ? Future.value(const <ClubMember>[])
          : clubMemberRepository().listMembershipsForUser(userId: currentUserId);
      _chatMetaRefreshToken++;
      _dmThreadsFuture = directMessageRepository().listThreadsForUser(
        userId: currentUserId,
      );
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _clubSubtitle(Club c) {
    final d = c.description.trim();
    if (d.isNotEmpty) {
      return d;
    }
    if (c.sports.isNotEmpty) {
      return c.sports.join(' · ');
    }
    final loc = c.location.trim();
    if (loc.isNotEmpty) {
      return loc;
    }
    return '';
  }

  String _chatReadKey(String clubId) {
    return 'club_chat_last_read_${currentUserId}_$clubId';
  }

  String _dmReadKey(String otherUserId) {
    return 'direct_dm_last_read_${currentUserId}_$otherUserId';
  }

  Future<void> _markClubChatRead(String clubId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatReadKey(clubId), DateTime.now().toIso8601String());
  }

  Future<Map<String, _ClubChatMeta>> _loadChatMeta(List<Club> clubs) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, _ClubChatMeta>{};
    for (final club in clubs) {
      try {
        final items = await _chatRepository.listForClub(club.id, limit: 120);
        if (items.isEmpty) {
          result[club.id] = const _ClubChatMeta.empty();
          continue;
        }
        final sorted = [...items]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final latest = sorted.first;
        final readRaw = prefs.getString(_chatReadKey(club.id));
        final lastReadAt = readRaw == null ? null : DateTime.tryParse(readRaw);
        final unread = sorted
            .where((m) => m.senderId.trim() != currentUserId.trim())
            .where((m) {
              if (lastReadAt == null) {
                return true;
              }
              return m.createdAt.isAfter(lastReadAt);
            })
            .length;
        final searchableText = sorted
            .map((m) {
              final text = m.text.trim();
              final sender = m.senderName.trim();
              return sender.isEmpty ? text : '$sender $text';
            })
            .where((chunk) => chunk.trim().isNotEmpty)
            .join(' ')
            .toLowerCase();
        result[club.id] = _ClubChatMeta(
          latestSender: latest.senderName.trim().isEmpty
              ? 'Member'
              : latest.senderName.trim(),
          latestText: latest.text.trim().isEmpty
              ? (latest.imageFileId?.trim().isNotEmpty == true
                    ? 'sent a photo'
                    : '')
              : latest.text.trim(),
          latestAt: latest.createdAt,
          unreadCount: unread,
          searchableText: searchableText,
        );
      } catch (_) {
        result[club.id] = const _ClubChatMeta.empty();
      }
    }
    return result;
  }

  Future<Map<String, int>> _loadDmUnreadCounts(
    List<DirectMessageThread> threads,
  ) async {
    final me = currentUserId.trim();
    if (me.isEmpty || threads.isEmpty) {
      return const <String, int>{};
    }
    final prefs = await SharedPreferences.getInstance();
    final out = <String, int>{};
    for (final thread in threads) {
      final other = thread.otherUserId.trim();
      if (other.isEmpty) {
        continue;
      }
      final raw = prefs.getString(_dmReadKey(other));
      final lastRead = raw == null ? null : DateTime.tryParse(raw);
      try {
        final convo = await directMessageRepository().listConversation(
          userA: me,
          userB: other,
        );
        final unread = convo
            .where((m) => m.senderId.trim() == other)
            .where((m) => lastRead == null || m.createdAt.isAfter(lastRead))
            .length;
        out[other] = unread;
      } catch (_) {
        out[other] = 0;
      }
    }
    return out;
  }

  String _formatChatTime(DateTime time) {
    final now = DateTime.now();
    final local = time.toLocal();
    if (now.year == local.year &&
        now.month == local.month &&
        now.day == local.day) {
      final h = local.hour;
      final hour12 = ((h + 11) % 12) + 1;
      final ampm = h >= 12 ? 'PM' : 'AM';
      final min = local.minute.toString().padLeft(2, '0');
      return '$hour12:$min $ampm';
    }
    if (now.difference(local).inDays == 1) {
      return 'Yesterday';
    }
    return '${local.month}/${local.day}';
  }

  bool _clubMatchesSearch(Club c, String searchLower) {
    if (searchLower.isEmpty) {
      return true;
    }
    if (c.name.toLowerCase().contains(searchLower)) {
      return true;
    }
    if (c.description.toLowerCase().contains(searchLower)) {
      return true;
    }
    if (c.location.toLowerCase().contains(searchLower)) {
      return true;
    }
    for (final s in c.sports) {
      if (s.toLowerCase().contains(searchLower)) {
        return true;
      }
    }
    return false;
  }

  bool _clubMatchesSearchWithMeta(
    Club c,
    String searchLower,
    _ClubChatMeta meta,
  ) {
    if (_clubMatchesSearch(c, searchLower)) {
      return true;
    }
    if (searchLower.isEmpty) {
      return true;
    }
    final latestText = meta.latestText.toLowerCase();
    if (latestText.contains(searchLower)) {
      return true;
    }
    final latestSender = meta.latestSender.toLowerCase();
    if (latestSender.contains(searchLower)) {
      return true;
    }
    if (meta.searchableText.contains(searchLower)) {
      return true;
    }
    return false;
  }

  Future<void> _showPickSport() async {
    final sports = <String>['All', ...SampleData.sports];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.32,
        maxChildSize: 0.92,
        builder: (sheetCtx, scrollController) {
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Sport',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: sports.length,
                    itemBuilder: (context, i) {
                      final s = sports[i];
                      return ListTile(
                        title: Text(
                          s,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: s == _selectedSport
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.of(ctx).pop(s),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (!mounted || chosen == null) return;
    setState(() => _selectedSport = chosen);
  }

  @override
  Widget build(BuildContext context) {
    const headerTeal = Color(0xFF1FB8AD);
    final searchLower = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: const Color(0xFFEFF7F3),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: headerTeal,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Circle',
                    style: TextStyle(
                      fontSize: 34 / 1.6,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFFBDE7E3),
                      ),
                      hintText: 'Search keyword',
                      hintStyle: const TextStyle(color: Color(0xFFBDE7E3)),
                      fillColor: Colors.white.withValues(alpha: 0.14),
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xFF6CD8D0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(
                          color: Color(0xFFBDE7E3),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _showPickSport,
                    child: Text(
                      'Sport  ▾',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _JoinFilterChip(
                        label: 'Joined',
                        selected: _joinFilterTab == _ClubJoinFilterTab.joined,
                        onTap: () => setState(
                          () => _joinFilterTab = _ClubJoinFilterTab.joined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _JoinFilterChip(
                        label: 'Discover',
                        selected: _joinFilterTab == _ClubJoinFilterTab.discover,
                        onTap: () => setState(
                          () => _joinFilterTab = _ClubJoinFilterTab.discover,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _JoinFilterChip(
                        label: 'DM',
                        selected: _joinFilterTab == _ClubJoinFilterTab.dm,
                        onTap: () => setState(
                          () => _joinFilterTab = _ClubJoinFilterTab.dm,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            FutureBuilder<MembershipStatus>(
              future: _membershipFuture,
              builder: (context, membershipSnap) {
                if (membershipSnap.connectionState != ConnectionState.done &&
                    membershipSnap.data == null) {
                  return const SizedBox.shrink();
                }
                if (membershipSnap.data?.isPremium == true) {
                  return const SizedBox.shrink();
                }
                return const AppAdBanner();
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    _joinFilterTab == _ClubJoinFilterTab.joined
                        ? 'Joined clubs'
                        : _joinFilterTab == _ClubJoinFilterTab.discover
                        ? 'Discover clubs'
                        : 'Direct messages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5E7B76),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Divider(
                      height: 1,
                      color: const Color(0xFF5E7B76).withValues(alpha: 0.24),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _joinFilterTab == _ClubJoinFilterTab.dm
                  ? _buildDmList(searchLower)
                  : FutureBuilder<List<Club>>(
                future: _clubsFuture,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Could not load clubs.\n${snap.error}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _refreshClubs,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final clubs = snap.data ?? const <Club>[];
                  final sportFiltered = clubs.where((c) {
                    final sportOk =
                        _selectedSport == 'All' ||
                        c.sports.contains(_selectedSport);
                    if (!sportOk) {
                      return false;
                    }
                    return true;
                  }).toList();

                  return FutureBuilder<List<ClubMember>>(
                    future: _membershipsFuture,
                    builder: (context, memberSnap) {
                      final me = currentUserId.trim();
                      final joinedClubIds = <String>{
                        for (final m in (memberSnap.data ?? const <ClubMember>[]))
                          m.clubId.trim(),
                      }..removeWhere((id) => id.isEmpty);
                      for (final c in clubs) {
                        final creatorId = (c.creatorId ?? '').trim();
                        if (creatorId.isNotEmpty && creatorId == me) {
                          joinedClubIds.add(c.id);
                        }
                      }
                      final joinFiltered = sportFiltered.where((c) {
                        final isJoined = joinedClubIds.contains(c.id);
                        if (_joinFilterTab == _ClubJoinFilterTab.joined) {
                          return isJoined;
                        }
                        return !isJoined;
                      }).toList();
                      if (joinFiltered.isEmpty) {
                        final emptyText = clubs.isEmpty
                            ? 'No clubs yet. Create one from Home.'
                            : _joinFilterTab == _ClubJoinFilterTab.joined
                            ? 'You have not joined any clubs yet.'
                            : 'No more clubs available for this filter.';
                        return Center(
                          child: Text(emptyText, textAlign: TextAlign.center),
                        );
                      }
                      if (_joinFilterTab == _ClubJoinFilterTab.discover) {
                        final filtered = joinFiltered.where(
                          (c) => _clubMatchesSearch(c, searchLower),
                        ).toList()..sort((a, b) => a.name.compareTo(b.name));
                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text(
                              'No clubs match your filters.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final c = filtered[idx];
                            final subtitle = _clubSubtitle(c);
                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  ClubChatScreen.routeName,
                                  arguments: c,
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FFFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFCCE9DF)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDDF3F0),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          clipBehavior: Clip.antiAlias,
                                          child:
                                              c.thumbnailFileId != null &&
                                                  c.thumbnailFileId!.isNotEmpty
                                              ? FutureBuilder(
                                                  future: AppwriteService.getFileViewBytes(
                                                    bucketId: AppwriteConfig
                                                        .storageBucketId,
                                                    fileId: c.thumbnailFileId!,
                                                  ),
                                                  builder: (context, snap) {
                                                    if (snap.hasData) {
                                                      return Image.memory(
                                                        snap.data!,
                                                        fit: BoxFit.cover,
                                                      );
                                                    }
                                                    return const Icon(
                                                      Icons.groups,
                                                      size: 20,
                                                    );
                                                  },
                                                )
                                              : const Icon(Icons.groups, size: 20),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14.5,
                                              ),
                                            ),
                                            if (subtitle.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                subtitle,
                                                style: TextStyle(
                                                  color: Colors.black.withValues(
                                                    alpha: 0.55,
                                                  ),
                                                  fontSize: 12.5,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF12B7AA).withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'Tap to view and join',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F7F73),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return FutureBuilder<Map<String, _ClubChatMeta>>(
                        key: ValueKey(
                          '${joinFiltered.map((c) => c.id).join("|")}#$_chatMetaRefreshToken#${_joinFilterTab.name}',
                        ),
                        future: _loadChatMeta(joinFiltered),
                        builder: (context, metaSnap) {
                          final metaByClub =
                              metaSnap.data ?? const <String, _ClubChatMeta>{};
                          final filtered = joinFiltered.where((c) {
                            final meta =
                                metaByClub[c.id] ?? const _ClubChatMeta.empty();
                            return _clubMatchesSearchWithMeta(
                              c,
                              searchLower,
                              meta,
                            );
                          }).toList()..sort((a, b) => a.name.compareTo(b.name));
                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text(
                                'No clubs match your filters.',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final c = filtered[idx];
                          final fallbackSubtitle = _clubSubtitle(c);
                          final meta = metaByClub[c.id] ?? const _ClubChatMeta.empty();
                          final sender = meta.latestSender.trim();
                          final latestText = meta.latestText.trim();
                          final subtitle = latestText.isNotEmpty
                              ? (sender.isNotEmpty ? '$sender: $latestText' : latestText)
                              : fallbackSubtitle;

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  () async {
                                    await _markClubChatRead(c.id);
                                    if (!context.mounted) {
                                      return;
                                    }
                                    _refreshClubs();
                                    Navigator.of(context)
                                        .pushNamed(
                                          ClubChatScreen.routeName,
                                          arguments: c,
                                        )
                                        .then((_) async {
                                          if (!context.mounted) {
                                            return;
                                          }
                                          await _markClubChatRead(c.id);
                                          _refreshClubs();
                                        });
                                  }();
                                });
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFDDE8E5)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDDF3F0),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        clipBehavior: Clip.antiAlias,
                                        child:
                                            c.thumbnailFileId != null &&
                                                c.thumbnailFileId!.isNotEmpty
                                            ? FutureBuilder(
                                                future:
                                                    AppwriteService.getFileViewBytes(
                                                      bucketId: AppwriteConfig
                                                          .storageBucketId,
                                                      fileId: c.thumbnailFileId!,
                                                    ),
                                                builder: (context, snap) {
                                                  if (snap.hasData) {
                                                    return Image.memory(
                                                      snap.data!,
                                                      fit: BoxFit.cover,
                                                    );
                                                  }
                                                  return const Icon(
                                                    Icons.groups,
                                                    size: 20,
                                                  );
                                                },
                                              )
                                            : const Icon(Icons.groups, size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                          if (subtitle.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              subtitle,
                                              style: TextStyle(
                                                color: Colors.black.withValues(
                                                  alpha: 0.55,
                                                ),
                                                fontSize: 12.5,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    _rightMetaPill(meta),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rightMetaPill(_ClubChatMeta meta) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (meta.latestAt != null)
          Text(
            _formatChatTime(meta.latestAt!),
            style: const TextStyle(
              color: Color(0xFF9AA6A3),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (meta.unreadCount > 0) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 18),
            height: 18,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF12B7AA),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              meta.unreadCount > 99 ? '99+' : meta.unreadCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDmList(String searchLower) {
    return FutureBuilder<List<DirectMessageThread>>(
      future: _dmThreadsFuture,
      builder: (context, threadSnap) {
        if (threadSnap.connectionState != ConnectionState.done &&
            (threadSnap.data == null || threadSnap.data!.isEmpty)) {
          return const Center(child: CircularProgressIndicator());
        }
        if (threadSnap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Could not load direct messages.\n${threadSnap.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _refreshClubs,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final threads = threadSnap.data ?? const <DirectMessageThread>[];
        if (threads.isEmpty) {
          return const Center(
            child: Text(
              'No direct messages yet.\nOpen a profile and tap Direct Message.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return FutureBuilder<List<UserProfile>>(
          future: profileRepository().getProfilesByIds(
            threads.map((t) => t.otherUserId).toList(),
          ),
          builder: (context, profileSnap) {
            final profiles = profileSnap.data ?? const <UserProfile>[];
            final byId = <String, UserProfile>{
              for (final profile in profiles) profile.userId.trim(): profile,
            };
            final filtered = threads.where((thread) {
              final profile = byId[thread.otherUserId.trim()];
              final name = _profileDisplayName(profile).toLowerCase();
              final preview = thread.previewText.toLowerCase();
              if (searchLower.isEmpty) {
                return true;
              }
              return name.contains(searchLower) || preview.contains(searchLower);
            }).toList()
              ..sort((a, b) => b.latestAt.compareTo(a.latestAt));
            if (filtered.isEmpty) {
              return const Center(
                child: Text(
                  'No direct messages match your search.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            return FutureBuilder<Map<String, int>>(
              future: _loadDmUnreadCounts(filtered),
              builder: (context, unreadSnap) {
                final unreadByUser = unreadSnap.data ?? const <String, int>{};
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final thread = filtered[idx];
                    final profile = byId[thread.otherUserId.trim()];
                    final name = _profileDisplayName(profile);
                    final preview = thread.latestFromMe
                        ? 'You: ${thread.previewText}'
                        : thread.previewText;
                    final unread = unreadByUser[thread.otherUserId.trim()] ?? 0;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context)
                            .pushNamed(
                              DirectMessageScreen.routeName,
                              arguments: DirectMessageArgs(
                                otherUserId: thread.otherUserId,
                                initialName: name,
                              ),
                            )
                            .then((_) => _refreshClubs());
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDDE8E5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.transparent,
                                child: _DmUserAvatar(
                                  name: name,
                                  avatarFileId: profile?.avatarFileId,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      preview,
                                      style: TextStyle(
                                        color: Colors.black.withValues(alpha: 0.55),
                                        fontSize: 12.5,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatChatTime(thread.latestAt),
                                    style: const TextStyle(
                                      color: Color(0xFF9AA6A3),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (unread > 0) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 18),
                                      height: 18,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF12B7AA),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        unread > 99 ? '99+' : unread.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _profileDisplayName(UserProfile? profile) {
    if (profile == null) {
      return 'User';
    }
    final realName = profile.realName.trim();
    final username = profile.username.trim();
    if (realName.isNotEmpty && realName != 'Name') {
      return realName;
    }
    if (username.isNotEmpty && username != 'Username') {
      return username;
    }
    if (realName.isNotEmpty) {
      return realName;
    }
    if (username.isNotEmpty) {
      return username;
    }
    return 'User';
  }
}

class _JoinFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _JoinFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFFBDE7E3)
                : const Color(0xFF6CD8D0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: selected ? 0.98 : 0.9),
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ClubChatMeta {
  final String latestSender;
  final String latestText;
  final DateTime? latestAt;
  final int unreadCount;
  final String searchableText;

  const _ClubChatMeta({
    required this.latestSender,
    required this.latestText,
    required this.latestAt,
    required this.unreadCount,
    required this.searchableText,
  });

  const _ClubChatMeta.empty()
    : latestSender = '',
      latestText = '',
      latestAt = null,
      unreadCount = 0,
      searchableText = '';
}

class _DmUserAvatar extends StatelessWidget {
  final String name;
  final String? avatarFileId;

  const _DmUserAvatar({required this.name, required this.avatarFileId});

  @override
  Widget build(BuildContext context) {
    final fileId = (avatarFileId ?? '').trim();
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    if (fileId.isEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFDDF3F0),
        child: Text(
          initial,
          style: const TextStyle(
            color: Color(0xFF0F7F73),
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    return FutureBuilder<Uint8List>(
      future: AppwriteService.getFileViewBytes(
        bucketId: AppwriteConfig.profileImagesBucketId,
        fileId: fileId,
      ),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes != null && bytes.isNotEmpty) {
          return CircleAvatar(
            radius: 22,
            backgroundImage: MemoryImage(bytes),
            backgroundColor: const Color(0xFFDDF3F0),
          );
        }
        return CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFDDF3F0),
          child: Text(
            initial,
            style: const TextStyle(
              color: Color(0xFF0F7F73),
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      },
    );
  }
}
