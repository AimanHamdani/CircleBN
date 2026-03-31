import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/current_user.dart';
import '../../../data/event_registration_repository.dart';
import '../../../data/event_repository.dart';
import '../../../models/event.dart';
import 'event_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  static const routeName = '/notifications';

  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _knownEventIdsKey = 'notifications_known_event_ids_v1';
  late final Future<List<_AppNotificationItem>> _notificationsFuture;
  final Set<String> _readIds = <String>{};
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<List<_AppNotificationItem>> _loadNotifications() async {
    final events = await eventRepository().listEvents();
    final prefs = await SharedPreferences.getInstance();
    final previousKnownEventIds = prefs.getStringList(_knownEventIdsKey)?.toSet() ?? <String>{};
    final myId = currentUserId.trim();
    final joinedIds = <String>{
      ...events.where((e) => e.joinedByMe).map((e) => e.id),
    };
    if (myId.isNotEmpty) {
      final registrations = await eventRegistrationRepository().listMyRegisteredEventIds(myId);
      joinedIds.addAll(registrations);
    }

    final now = DateTime.now();
    final eventById = <String, Event>{
      for (final e in events) e.id: e,
    };
    final currentEventIds = eventById.keys.toSet();
    final disappearedEventIds = previousKnownEventIds.difference(currentEventIds);

    final items = <_AppNotificationItem>[];

    for (final eventId in joinedIds) {
      final event = eventById[eventId];
      if (event == null) {
        if (disappearedEventIds.contains(eventId)) {
          items.add(
            _AppNotificationItem(
              id: 'gone_$eventId',
              type: _AppNotificationType.cancelledOrDeleted,
              title: 'Event cancelled',
              message: 'An event you joined is no longer available.',
              createdAt: now,
            ),
          );
        }
        continue;
      }

      final startsIn = event.startAt.difference(now);
      if (startsIn.inMinutes >= 0 && startsIn <= const Duration(hours: 1)) {
        items.add(
          _AppNotificationItem(
            id: 'soon_${event.id}',
            type: _AppNotificationType.startingSoon,
            title: 'Event starting soon',
            message: '${event.title} starts in ${_timeUntilLabel(startsIn)}.',
            createdAt: now.subtract(const Duration(minutes: 1)),
            event: event,
          ),
        );
      }
    }

    await prefs.setStringList(_knownEventIdsKey, currentEventIds.toList());
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> _openNotification(_AppNotificationItem item) async {
    setState(() => _readIds.add(item.id));
    if (item.event == null) {
      return;
    }
    await Navigator.of(context).pushNamed(
      EventDetailScreen.routeName,
      arguments: EventDetailArgs(event: item.event!, showRegisterButton: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
            onPressed: () async {
              final items = await _notificationsFuture;
              if (!mounted) {
                return;
              }
              setState(() {
                _readIds.addAll(items.map((e) => e.id));
              });
            },
            child: const Text('Mark all read'),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE0E8E4)),
        ),
      ),
      body: FutureBuilder<List<_AppNotificationItem>>(
        future: _notificationsFuture,
        builder: (context, snap) {
          final items = snap.data ?? const <_AppNotificationItem>[];
          if (snap.connectionState != ConnectionState.done && items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No notifications yet.\nYou will see joined-event alerts here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final unread = !_readIds.contains(item.id);
              return _NotificationTile(
                item: item,
                unread: unread,
                onTap: () => _openNotification(item),
              );
            },
          );
        },
      ),
    );
  }
}

enum _AppNotificationType { startingSoon, cancelledOrDeleted }

class _AppNotificationItem {
  final String id;
  final _AppNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final Event? event;

  const _AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.event,
  });
}

class _NotificationTile extends StatelessWidget {
  final _AppNotificationItem item;
  final bool unread;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSoon = item.type == _AppNotificationType.startingSoon;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSoon ? const Color(0xFFD9EDE6) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFA9D5C8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSoon ? const Color(0xFF3EA174) : const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                isSoon ? Icons.schedule : Icons.close,
                color: isSoon ? Colors.white : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20 - 3)),
                  const SizedBox(height: 2),
                  Text(item.message, style: TextStyle(color: Colors.black.withValues(alpha: 0.62), fontSize: 13.5)),
                  const SizedBox(height: 6),
                  Text(_relativeTime(item.createdAt), style: const TextStyle(color: Colors.black38, fontSize: 12)),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(color: Color(0xFF3EA174), shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

String _timeUntilLabel(Duration d) {
  if (d.inMinutes <= 1) {
    return '1 minute';
  }
  if (d.inMinutes < 60) {
    return '${d.inMinutes} minutes';
  }
  final hours = d.inHours;
  return hours == 1 ? '1 hour' : '$hours hours';
}

String _relativeTime(DateTime when) {
  final now = DateTime.now();
  final d = now.difference(when);
  if (d.inMinutes < 1) {
    return 'Just now';
  }
  return _formatTimestamp(when);
}

String _formatTimestamp(DateTime dt) {
  final hour = ((dt.hour + 11) % 12) + 1;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $ampm';
}
