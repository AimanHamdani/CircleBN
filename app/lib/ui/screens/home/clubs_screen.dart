import 'package:flutter/material.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../data/club_repository.dart';
import '../../../data/sample_clubs.dart';
import '../../../models/club.dart';
import 'club_chat_screen.dart';

class ClubsScreen extends StatefulWidget {
  static const routeName = '/clubs';

  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  final _searchCtrl = TextEditingController();

  String _selectedSport = 'All';
  late Future<List<Club>> _clubsFuture;

  @override
  void initState() {
    super.initState();
    _clubsFuture = clubRepository().listClubs();
  }

  void _refreshClubs() {
    setState(() {
      _clubsFuture = clubRepository().listClubs();
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                        trailing: s == _selectedSport ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
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
                    'Clubs',
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
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFBDE7E3)),
                      suffixIcon: const Icon(Icons.tune, size: 18, color: Color(0xFFBDE7E3)),
                      hintText: 'Search for clubs...',
                      hintStyle: const TextStyle(color: Color(0xFFBDE7E3)),
                      fillColor: Colors.white.withValues(alpha: 0.14),
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xFF6CD8D0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0xFFBDE7E3), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final clubs = snap.data ?? const <Club>[];
                  final filtered = clubs.where((c) {
                    final sportOk = _selectedSport == 'All' || c.sports.contains(_selectedSport);
                    if (!sportOk) {
                      return false;
                    }
                    return _clubMatchesSearch(c, searchLower);
                  }).toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        clubs.isEmpty ? 'No clubs yet. Create one from Home.' : 'No clubs match your filters.',
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
                          // Defer push so web pointer/hover teardown finishes before chat builds
                          // (avoids hit-test / mouse_tracker / hasSize assertions).
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!context.mounted) {
                                return;
                              }
                              Navigator.of(context)
                                  .pushNamed(
                                    ClubChatScreen.routeName,
                                    arguments: c,
                                  )
                                  .then((_) {
                                if (context.mounted) {
                                  _refreshClubs();
                                }
                              });
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
                                    child: c.thumbnailFileId != null && c.thumbnailFileId!.isNotEmpty
                                        ? FutureBuilder(
                                            future: AppwriteService.getFileViewBytes(
                                              bucketId: AppwriteConfig.storageBucketId,
                                              fileId: c.thumbnailFileId!,
                                            ),
                                            builder: (context, snap) {
                                              if (snap.hasData) {
                                                return Image.memory(
                                                  snap.data!,
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return const Icon(Icons.groups, size: 20);
                                            },
                                          )
                                        : const Icon(Icons.groups, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                                      ),
                                      if (subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitle,
                                          style: TextStyle(
                                            color: Colors.black.withValues(alpha: 0.55),
                                            fontSize: 12.5,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                _rightMetaPill(idx),
                              ],
                            ),
                          ),
                        ),
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

  Widget _rightMetaPill(int idx) {
    if (idx % 3 == 0) {
      return const Text(
        '1:30',
        style: TextStyle(
          color: Color(0xFF9AA6A3),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (idx % 3 == 1) {
      return Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF12B7AA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          '2',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return const Text(
      'Yesterday',
      style: TextStyle(
        color: Color(0xFF9AA6A3),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

