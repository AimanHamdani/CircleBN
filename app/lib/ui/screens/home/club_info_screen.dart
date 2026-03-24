import 'package:flutter/material.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../models/club.dart';

/// Club profile / info page (opened from chat app bar).
class ClubInfoScreen extends StatelessWidget {
  static const routeName = '/club-info';

  const ClubInfoScreen({super.key});

  Club _club(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Club) {
      return args;
    }
    return const Club(
      id: 'unknown',
      name: 'Club',
      description: '',
      sports: {'Other'},
    );
  }

  int _members(Club c) => 20 + (c.id.hashCode.abs() % 80);
  int _eventsCount(Club c) => 8 + (c.id.hashCode.abs() % 25);
  int _admins(Club c) => 1 + (c.id.hashCode.abs() % 3);

  String _primarySport(Club c) {
    if (c.sports.isEmpty) {
      return 'Sport';
    }
    final list = c.sports.toList()..sort();
    return list.first;
  }

  String _foundedLabel(Club c) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = c.id.hashCode.abs() % 12;
    final y = 2021 + (c.id.hashCode.abs() % 5);
    return 'Founded ${months[m]} $y';
  }

  @override
  Widget build(BuildContext context) {
    final club = _club(context);
    final cs = Theme.of(context).colorScheme;
    final members = _members(club);
    final eventsN = _eventsCount(club);
    final admins = _admins(club);
    final sport = _primarySport(club);
    final locationText = club.location.trim().isNotEmpty ? club.location.trim() : 'Location not set';
    final desc = club.description.trim().isNotEmpty
        ? club.description.trim()
        : 'A casual club for all skill levels. Everyone is welcome — join us for sessions and events.';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      // Web / route transition: horizontal constraints can be loose briefly; Row→Expanded
      // under SingleChildScrollView then never lays out → blank screen + mouse_tracker asserts.
      body: LayoutBuilder(
        builder: (context, constraints) {
          var w = constraints.maxWidth;
          if (!w.isFinite || w <= 0) {
            w = MediaQuery.sizeOf(context).width;
          }
          if (!w.isFinite || w <= 0) {
            w = 400.0;
          }
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 200,
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(child: _ClubBanner(club: club)),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 72,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Material(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      shape: const CircleBorder(),
                                      clipBehavior: Clip.antiAlias,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.arrow_back),
                                        onPressed: () => Navigator.of(context).maybePop(),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Material(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      shape: const CircleBorder(),
                                      clipBehavior: Clip.antiAlias,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.more_vert),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Club menu (mock).')),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    // stretch: give each child the full content width. With .start, the header
                    // Row can see an unbounded max width → FilledButton gets w=Infinity and crashes.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ClubInfoAvatar(club: club),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    club.name,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        sport,
                                        style: TextStyle(
                                          color: Colors.black.withValues(alpha: 0.45),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          club.privacy.isNotEmpty ? club.privacy : 'Public',
                                          style: TextStyle(
                                            color: cs.primary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Row lays out non-flex children with an unbounded main-axis max width;
                            // FilledButton then hits "BoxConstraints forces an infinite width".
                            Flexible(
                              fit: FlexFit.loose,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Join club (mock).')),
                                    );
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Join', style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE3E7EE)),
                          ),
                          child: Row(
                            children: [
                              _StatCell(value: '$members', label: 'Members'),
                              _divider(),
                              _StatCell(value: '$eventsN', label: 'Events'),
                              _divider(),
                              _StatCell(value: '$admins', label: 'Admins'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('About', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(desc, style: TextStyle(height: 1.45, color: Colors.black.withValues(alpha: 0.72), fontSize: 14)),
                        const SizedBox(height: 14),
                        _MetaRow(icon: Icons.location_on_outlined, text: locationText),
                        const SizedBox(height: 8),
                        _MetaRow(icon: Icons.calendar_today_outlined, text: _foundedLabel(club)),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Members ($members)',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('See all members (mock).')),
                                );
                              },
                              child: Text('See all', style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _MemberTile(
                          name: 'Alex Tan',
                          subtitle: 'Admin · Joined Mar 2023',
                          avatarColor: cs.primary,
                          icon: Icons.sports_soccer,
                          badge: 'Admin',
                          primary: cs.primary,
                        ),
                        const SizedBox(height: 10),
                        _MemberTile(
                          name: 'Sarah Lim',
                          subtitle: 'Member · Joined Jun 2023',
                          avatarColor: const Color(0xFFFF9800),
                          icon: Icons.emoji_events_outlined,
                        ),
                        const SizedBox(height: 10),
                        _MemberTile(
                          name: 'James Wong',
                          subtitle: 'Member · Joined Aug 2023',
                          avatarColor: const Color(0xFF2196F3),
                          icon: Icons.bolt_outlined,
                        ),
                        const SizedBox(height: 10),
                        _MemberTile(
                          name: 'Nurul Ain',
                          subtitle: 'Member · Joined Sep 2023',
                          avatarColor: const Color(0xFF9C27B0),
                          icon: Icons.track_changes_outlined,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Upcoming Events',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('See all events (mock).')),
                                );
                              },
                              child: Text('See all', style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _UpcomingEventLargeCard(primary: cs.primary),
                        const SizedBox(height: 12),
                        _UpcomingEventCompactCard(primary: cs.primary),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: const Color(0xFFE3E7EE));
  }
}

class _ClubBanner extends StatelessWidget {
  final Club club;

  const _ClubBanner({required this.club});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (club.thumbnailFileId != null && club.thumbnailFileId!.isNotEmpty) {
      return FutureBuilder(
        future: AppwriteService.getFileViewBytes(
          bucketId: AppwriteConfig.storageBucketId,
          fileId: club.thumbnailFileId!,
        ),
        builder: (context, snap) {
          if (snap.hasError) {
            return _bannerPlaceholder(cs);
          }
          final bytes = snap.data;
          if (snap.connectionState == ConnectionState.done && bytes != null && bytes.isNotEmpty) {
            return SizedBox.expand(
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting || snap.connectionState == ConnectionState.active) {
            return Center(child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2));
          }
          return _bannerPlaceholder(cs);
        },
      );
    }
    return _bannerPlaceholder(cs);
  }

  Widget _bannerPlaceholder(ColorScheme cs) {
    return Container(
      width: double.infinity,
      color: cs.primary.withValues(alpha: 0.12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.black.withValues(alpha: 0.25)),
          const SizedBox(height: 6),
          Text(
            'Club banner',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.35), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ClubInfoAvatar extends StatelessWidget {
  final Club club;

  const _ClubInfoAvatar({required this.club});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.45),
            cs.primary.withValues(alpha: 0.15),
          ],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: club.thumbnailFileId != null && club.thumbnailFileId!.isNotEmpty
          ? FutureBuilder(
              future: AppwriteService.getFileViewBytes(
                bucketId: AppwriteConfig.storageBucketId,
                fileId: club.thumbnailFileId!,
              ),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Icon(Icons.sports_soccer, color: cs.primary, size: 40);
                }
                final bytes = snap.data;
                if (snap.connectionState == ConnectionState.done && bytes != null && bytes.isNotEmpty) {
                  return Image.memory(bytes, fit: BoxFit.cover);
                }
                if (snap.connectionState == ConnectionState.waiting || snap.connectionState == ConnectionState.active) {
                  return Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)));
                }
                return Icon(Icons.sports_soccer, color: cs.primary, size: 40);
              },
            )
          : Icon(Icons.sports_soccer, color: cs.primary, size: 40),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;

  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.45), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black.withValues(alpha: 0.45)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.65), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _AdminPill extends StatelessWidget {
  final String text;
  final Color color;

  const _AdminPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final Color avatarColor;
  final IconData icon;
  final String? badge;
  final Color? primary;

  const _MemberTile({
    required this.name,
    required this.subtitle,
    required this.avatarColor,
    required this.icon,
    this.badge,
    this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: avatarColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.45), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (badge != null && primary != null)
            _AdminPill(text: badge!, color: primary!),
        ],
      ),
    );
  }
}

class _UpcomingEventLargeCard extends StatelessWidget {
  final Color primary;

  const _UpcomingEventLargeCard({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary.withValues(alpha: 0.22),
                  Colors.white,
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_outlined, size: 40, color: Colors.black.withValues(alpha: 0.25)),
                const SizedBox(height: 4),
                Text('Event', style: TextStyle(color: Colors.black.withValues(alpha: 0.35), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('5-a-side Football', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      SizedBox(height: 4),
                      Text(
                        'Sat 13 Sep · 6pm · Bukit Timah',
                        style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('Open', style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventCompactCard extends StatelessWidget {
  final Color primary;

  const _UpcomingEventCompactCard({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EE)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Training Session', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                SizedBox(height: 4),
                Text(
                  'Wed 17 Sep · 7pm · Bishan',
                  style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('Open', style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
