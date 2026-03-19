import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../models/event.dart';
import 'create_event_screen.dart';

class EventDetailArgs {
  final Event event;
  final bool showRegisterButton;
  const EventDetailArgs({
    required this.event,
    this.showRegisterButton = true,
  });
}

enum _EventDetailTab { details, chat }

class EventDetailScreen extends StatefulWidget {
  static const routeName = '/event';
  const EventDetailScreen({super.key});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  _EventDetailTab _tab = _EventDetailTab.details;
  final _composerCtrl = TextEditingController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _composerCtrl.dispose();
    super.dispose();
  }

  EventDetailArgs _argsFromRoute(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is EventDetailArgs) return args;
    if (args is Event) return EventDetailArgs(event: args);

    return EventDetailArgs(
      event: Event(
        id: 'missing',
        title: 'Event',
        sport: 'Sport',
        startAt: DateTime.now(),
        duration: const Duration(hours: 1),
        location: 'Location',
        joined: 0,
        capacity: 0,
        skillLevel: '—',
        entryFeeLabel: '—',
        description: 'No data (mock).',
        joinedByMe: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = _argsFromRoute(context);
    final e = args.event;
    final cs = Theme.of(context).colorScheme;
    final messages = _sampleMessagesFor(e.id);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary.withValues(alpha: 0.25),
                        const Color(0xFFFFFFFF),
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  child: e.thumbnailFileId != null && e.thumbnailFileId!.isNotEmpty
                      ? FutureBuilder(
                          future: AppwriteService.getFileViewBytes(
                            bucketId: AppwriteConfig.eventImagesBucketId,
                            fileId: e.thumbnailFileId!,
                          ),
                          builder: (context, snap) {
                            if (snap.hasData) {
                              return Image.memory(
                                snap.data!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              );
                            }
                            return Icon(Icons.image_outlined, color: Colors.black.withValues(alpha: 0.35), size: 56);
                          },
                        )
                      : Icon(Icons.image_outlined, color: Colors.black.withValues(alpha: 0.35), size: 56),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _RoundIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                if (e.creatorId != null && e.creatorId == currentUserId)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      children: [
                        _RoundIconButton(
                          icon: Icons.edit_outlined,
                          onTap: () => Navigator.of(context).pushNamed(
                            CreateEventScreen.routeName,
                            arguments: e,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RoundIconButton(
                          icon: _isDeleting ? Icons.hourglass_top : Icons.delete_outline,
                          onTap: _isDeleting ? () {} : () => _confirmDeleteEvent(e),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: _TabHeader(
                selected: _tab,
                onSelect: (t) => setState(() => _tab = t),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _tab == _EventDetailTab.details
                    ? _DetailsTab(
                        key: const ValueKey('details'),
                        event: e,
                      )
                    : _ChatTab(
                        key: const ValueKey('chat'),
                        eventTitle: e.title,
                        messages: messages,
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _tab == _EventDetailTab.details
          ? (args.showRegisterButton ? _registerBar(context) : null)
          : _chatComposerBar(context),
    );
  }

  Widget _registerBar(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottomInset),
        child: FilledButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registered (mock).')),
            );
          },
          child: const Text('Register'),
        ),
      ),
    );
  }

  Widget _chatComposerBar(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottomInset),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _composerCtrl,
                decoration: const InputDecoration(
                  hintText: 'Message (mock)',
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMock(),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: _sendMock,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMock() {
    final txt = _composerCtrl.text.trim();
    _composerCtrl.clear();
    if (txt.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message sent (mock). Not stored yet.')),
    );
  }

  Future<void> _confirmDeleteEvent(Event event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Cancel this event by deleting it? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      return;
    }

    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.eventsCollectionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appwrite is not configured yet.')),
      );
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await AppwriteService.deleteDocument(
        collectionId: AppwriteConfig.eventsCollectionId,
        documentId: event.id,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop('deleted');
    } on AppwriteException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to delete event.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete event.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}

class _TabHeader extends StatelessWidget {
  final _EventDetailTab selected;
  final ValueChanged<_EventDetailTab> onSelect;
  const _TabHeader({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabButton(
          label: 'Details',
          selected: selected == _EventDetailTab.details,
          onTap: () => onSelect(_EventDetailTab.details),
        ),
        const SizedBox(width: 14),
        _TabButton(
          label: 'Chat',
          selected: selected == _EventDetailTab.chat,
          onTap: () => onSelect(_EventDetailTab.chat),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: selected ? Colors.black87 : Colors.black45,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: 34,
              decoration: BoxDecoration(
                color: selected ? c.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final Event event;
  const _DetailsTab({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            event.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              _InfoRow(icon: Icons.event, label: _fmtDateTime(event.startAt)),
              const SizedBox(height: 6),
              _InfoRow(icon: Icons.schedule, label: _fmtDuration(event.duration)),
              const SizedBox(height: 6),
              _InfoRow(icon: Icons.location_on_outlined, label: event.location),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MetricTile(title: 'SPORT', value: event.sport)),
              const SizedBox(width: 10),
              Expanded(child: _MetricTile(title: 'SKILL LEVEL', value: event.skillLevel)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MetricTile(title: 'JOINED', value: '${event.joined} / ${event.capacity}')),
              const SizedBox(width: 10),
              Expanded(child: _MetricTile(title: 'ENTRY FEE', value: event.entryFeeLabel)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(event.description, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _ChatTab extends StatelessWidget {
  final String eventTitle;
  final List<_ChatMessage> messages;
  const _ChatTab({super.key, required this.eventTitle, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text('No messages yet (mock).'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final m = messages[idx];
        final bubble = _MessageBubble(
          text: m.text,
          isMe: m.isMe,
        );

        return Row(
          mainAxisAlignment: m.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: bubble,
            ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  const _MessageBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final bg = isMe ? c.primary.withValues(alpha: 0.12) : Colors.white;
    final border = isMe ? c.primary.withValues(alpha: 0.25) : const Color(0xFFE3E7EE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  const _MetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE3E7EE)),
        ),
        child: Icon(icon),
      ),
    );
  }
}

String _fmtDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  final month = two(dt.month);
  final day = two(dt.day);
  final year = dt.year;
  final h = dt.hour;
  final hour12 = ((h + 11) % 12) + 1;
  final ampm = h >= 12 ? 'PM' : 'AM';
  final min = two(dt.minute);
  return '$month/$day/$year, $hour12:$min $ampm';
}

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0 && m > 0) return '$h Hours $m Min';
  if (h > 0) return '$h Hours';
  return '$m Min';
}

class _ChatMessage {
  final bool isMe;
  final String text;
  const _ChatMessage({required this.isMe, required this.text});
}

List<_ChatMessage> _sampleMessagesFor(String eventId) {
  final map = <String, List<_ChatMessage>>{
    'lets_go_volley': const [
      _ChatMessage(isMe: false, text: 'Hi everyone! Court is confirmed.'),
      _ChatMessage(isMe: true, text: 'Nice, what time should we arrive?'),
      _ChatMessage(isMe: false, text: 'Try to be there 15 mins earlier for warm-up.'),
    ],
    'badminton_meet': const [
      _ChatMessage(isMe: false, text: 'Hi! Please bring a dark shirt if possible.'),
      _ChatMessage(isMe: true, text: 'Got it. Are shuttlecocks provided?'),
      _ChatMessage(isMe: false, text: 'Yes, we will bring them.'),
    ],
    'fun_run': const [
      _ChatMessage(isMe: false, text: 'Welcome! Route will be shared soon.'),
      _ChatMessage(isMe: true, text: 'Thanks! Looking forward to it.'),
    ],
  };
  return map[eventId] ?? const [];
}

