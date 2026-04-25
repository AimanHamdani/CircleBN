import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../data/club_chat_repository.dart';
import '../../../data/club_repository.dart';
import '../../../data/membership_repository.dart';
import '../../../data/sample_clubs.dart';
import '../../../models/club.dart';
import '../../widgets/ad_banner.dart';
import 'club_chat_screen.dart';

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
  late Future<List<Club>> _clubsFuture;
  late Future<MembershipStatus> _membershipFuture;
  int _chatMetaRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _clubsFuture = clubRepository().listClubs();
    _membershipFuture = membershipRepository().getStatus();
  }

  void _refreshClubs() {
    setState(() {
      _clubsFuture = clubRepository().listClubs();
      _chatMetaRefreshToken++;
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
                ],
              ),
            ),
            FutureBuilder<MembershipStatus>(
              future: _membershipFuture,
              builder: (context, membershipSnap) {
                if (membershipSnap.data?.isPremium == true) {
                  return const SizedBox.shrink();
                }
                return const AppAdBanner();
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Club>>(
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

                  if (sportFiltered.isEmpty) {
                    return Center(
                      child: Text(
                        clubs.isEmpty
                            ? 'No clubs yet. Create one from Home.'
                            : 'No clubs match your filters.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return FutureBuilder<Map<String, _ClubChatMeta>>(
                    key: ValueKey(
                      '${sportFiltered.map((c) => c.id).join("|")}#$_chatMetaRefreshToken',
                    ),
                    future: _loadChatMeta(sportFiltered),
                    builder: (context, metaSnap) {
                      final metaByClub = metaSnap.data ?? const <String, _ClubChatMeta>{};
                      final filtered = sportFiltered.where((c) {
                        final meta = metaByClub[c.id] ?? const _ClubChatMeta.empty();
                        return _clubMatchesSearchWithMeta(c, searchLower, meta);
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
