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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _mockLastMessage(Club c) {
    final h = c.id.hashCode.abs();
    final lastSports = c.sports.toList();
    final sport = lastSports.isNotEmpty ? lastSports[h % lastSports.length] : 'Sport';
    final templates = <String>[
      'Let us play $sport tomorrow',
      'Practice starts soon for $sport',
      'Reminder: bring water for $sport',
      'Schedule updated for $sport',
      'Join us for $sport session',
    ];
    return templates[h % templates.length];
  }

  String _mockLastTimeText(Club c) {
    final h = c.id.hashCode.abs();
    final labels = <String>[
      'Just Now',
      'Yesterday',
      '13/2',
      '1:30',
    ];
    return labels[h % labels.length];
  }

  int _mockUnreadCount(Club c) {
    final h = c.id.hashCode.abs();
    return h % 3;
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
    final searchLower = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Club', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search for Clubs',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sport', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _showPickSport,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 48,
                      child: InputDecorator(
                        isEmpty: _selectedSport.isEmpty,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedSport,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Club>>(
                future: clubRepository().listClubs(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final clubs = snap.data ?? SampleData.clubs;
                  final filtered = clubs.where((c) {
                    final sportOk = _selectedSport == 'All' || c.sports.contains(_selectedSport);
                    if (!sportOk) return false;

                    if (searchLower.isEmpty) return true;
                    final lastMessage = _mockLastMessage(c).toLowerCase();
                    final nameOk = c.name.toLowerCase().contains(searchLower);
                    final msgOk = lastMessage.contains(searchLower);
                    return nameOk || msgOk;
                  }).toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No clubs found.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final c = filtered[idx];
                      final unread = _mockUnreadCount(c);
                      final lastTime = _mockLastTimeText(c);
                      final lastMessage = _mockLastMessage(c);

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          // Defer push so web pointer/hover teardown finishes before chat builds
                          // (avoids hit-test / mouse_tracker / hasSize assertions).
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!context.mounted) {
                                return;
                              }
                              Navigator.of(context).pushNamed(
                                ClubChatScreen.routeName,
                                arguments: c,
                              );
                            });
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE3E7EE)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
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
                                      const SizedBox(height: 2),
                                      Text(
                                        'User: $lastMessage',
                                        style: TextStyle(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          fontSize: 12.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      lastTime,
                                      style: TextStyle(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (unread > 0)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$unread',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

