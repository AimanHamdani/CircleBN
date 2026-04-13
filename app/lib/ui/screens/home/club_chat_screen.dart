import 'package:flutter/material.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../models/club.dart';
import 'club_info_screen.dart';

/// Club group chat. Tapping the app bar (icon + name) opens [ClubInfoScreen].
class ClubChatScreen extends StatefulWidget {
  static const routeName = '/club-chat';

  const ClubChatScreen({super.key});

  @override
  State<ClubChatScreen> createState() => _ClubChatScreenState();
}

class _ClubChatScreenState extends State<ClubChatScreen> {
  final _composerCtrl = TextEditingController();

  @override
  void dispose() {
    _composerCtrl.dispose();
    super.dispose();
  }

  Club _clubFromRoute(BuildContext context) {
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

  int _mockMembers(Club c) => 20 + (c.id.hashCode.abs() % 80);
  int _mockOnline(Club c) => 3 + (c.id.hashCode.abs() % 12);

  void _openInfo(Club club) {
    // On web, stacked post-frame callbacks can wait for another pointer event.
    // Use next event-loop turn so navigation happens immediately after tap.
    Future<void>.delayed(Duration.zero, () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: ClubInfoScreen.routeName,
            arguments: club,
          ),
          builder: (context) => const ClubInfoScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final club = _clubFromRoute(context);
    final cs = Theme.of(context).colorScheme;
    final members = _mockMembers(club);
    final online = _mockOnline(club);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        // Web/AppBar: avoid LayoutBuilder + flex in the title slot (constraints can be
        // loose/unbounded briefly). Use MediaQuery for a finite width every frame.
        title: Builder(
          builder: (context) {
            final screenW = MediaQuery.sizeOf(context).width;
            final titleW = screenW > 0 ? (screenW - 72).clamp(160.0, 1200.0) : 280.0;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openInfo(club),
              child: SizedBox(
                width: titleW,
                height: kToolbarHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ClubChatThumb(club: club, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            club.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$members members · $online online',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, viewportConstraints) {
                final listW = viewportConstraints.maxWidth.isFinite && viewportConstraints.maxWidth > 0
                    ? viewportConstraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                final contentW = listW > 0 ? (listW - 32).clamp(120.0, 2000.0) : 320.0;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE3E7EE)),
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: contentW,
                      child: _IncomingBubble(
                        name: 'Sarah Lim',
                        avatarColor: const Color(0xFFFF9800),
                        avatarIcon: Icons.emoji_events_outlined,
                        text: 'Hey team! Are we still on for Saturday? ⚽',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: contentW,
                      child: _IncomingBubble(
                        name: 'James Wong',
                        avatarColor: const Color(0xFF2196F3),
                        avatarIcon: Icons.bolt_outlined,
                        text: "Yes! I'll be there at 5:45pm 👍",
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: contentW,
                      child: _PinnedEventCard(
                        primary: cs.primary,
                        onView: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('View event (mock).')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: contentW,
                      child: _OutgoingBubble(
                        text: 'Same, bringing extra balls 🔥',
                        primary: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: contentW,
                      child: _IncomingBubble(
                        name: 'Sarah Lim',
                        avatarColor: const Color(0xFFFF9800),
                        avatarIcon: Icons.emoji_events_outlined,
                        text: 'See you all there! 🙌',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composerCtrl,
                      decoration: InputDecoration(
                        hintText: 'Message ${club.name}...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (_composerCtrl.text.trim().isEmpty) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Message sent (mock).')),
                        );
                        _composerCtrl.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(999),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        if (_composerCtrl.text.trim().isEmpty) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Message sent (mock).')),
                        );
                        _composerCtrl.clear();
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubChatThumb extends StatelessWidget {
  final Club club;
  final double size;

  const _ClubChatThumb({required this.club, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
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
                final bytes = snap.data;
                if (snap.connectionState == ConnectionState.done &&
                    bytes != null &&
                    bytes.isNotEmpty) {
                  return Image.memory(bytes, fit: BoxFit.cover, width: size, height: size);
                }
                if (snap.connectionState == ConnectionState.waiting ||
                    snap.connectionState == ConnectionState.active) {
                  return Center(
                    child: SizedBox(
                      width: size * 0.45,
                      height: size * 0.45,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }
                return Icon(Icons.sports_soccer, color: Theme.of(context).colorScheme.primary, size: size * 0.5);
              },
            )
          : Icon(Icons.sports_soccer, color: Theme.of(context).colorScheme.primary, size: size * 0.5),
    );
  }
}

class _IncomingBubble extends StatelessWidget {
  final String name;
  final Color avatarColor;
  final IconData avatarIcon;
  final String text;

  const _IncomingBubble({
    required this.name,
    required this.avatarColor,
    required this.avatarIcon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: Icon(avatarIcon, color: avatarColor, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black.withValues(alpha: 0.45))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  border: Border.all(color: const Color(0xFFE3E7EE)),
                ),
                child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutgoingBubble extends StatelessWidget {
  final String text;
  final Color primary;

  const _OutgoingBubble({required this.text, required this.primary});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final maxBubbleW = screenW > 0 ? screenW * 0.78 : 320.0;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxBubbleW),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
      ),
    );
  }
}

class _PinnedEventCard extends StatelessWidget {
  final Color primary;
  final VoidCallback onView;

  const _PinnedEventCard({required this.primary, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E7EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.push_pin, size: 16, color: Colors.red.shade400),
              const SizedBox(width: 6),
              Text(
                'EVENT PINNED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('5-a-side Football', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Sat 13 Sep · 6pm · Bukit Timah',
            style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: onView,
              style: FilledButton.styleFrom(
                foregroundColor: primary,
                backgroundColor: primary.withValues(alpha: 0.12),
              ),
              child: const Text('View Event', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
