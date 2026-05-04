import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../data/club_repository.dart';
import '../../../data/event_invite_repository.dart';
import '../../../data/event_registration_repository.dart';
import '../../../data/event_repository.dart';
import '../../../data/notification_repository.dart';
import '../../../models/app_notification.dart';
import '../../../models/event.dart';
import 'club_info_screen.dart';
import 'event_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  static const routeName = '/notifications';

  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _NotificationsFilter { all, clubs, events }

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _knownEventIdsKeyPrefix = 'notifications_known_event_ids_v2_';

  late Future<_NotificationPayload> _notificationsFuture;
  Timer? _clockTimer;
  _NotificationsFilter _filter = _NotificationsFilter.all;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    AppwriteService.dataVersion.addListener(_handleGlobalDataChange);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    AppwriteService.dataVersion.removeListener(_handleGlobalDataChange);
    super.dispose();
  }

  void _handleGlobalDataChange() {
    if (!mounted) {
      return;
    }
    _reload();
  }

  String _knownKeyForUser(String userId) {
    return '$_knownEventIdsKeyPrefix$userId';
  }

  Future<_NotificationPayload> _loadNotifications() async {
    final myId = currentUserId.trim();
    if (myId.isEmpty) {
      return const _NotificationPayload(
        items: <AppNotification>[],
        eventById: <String, Event>{},
      );
    }

    final events = await eventRepository().listEvents();
    final eventById = <String, Event>{for (final e in events) e.id: e};
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final previousKnownEventIds =
        prefs.getStringList(_knownKeyForUser(myId))?.toSet() ?? <String>{};
    final currentEventIds = eventById.keys.toSet();
    final disappearedEventIds = previousKnownEventIds.difference(currentEventIds);

    final joinedIds = <String>{
      ...events.where((e) => e.joinedByMe).map((e) => e.id),
    };
    final registrations = await eventRegistrationRepository()
        .listMyRegisteredEventIds(myId);
    joinedIds.addAll(registrations);

    final generated = <AppNotification>[];

    for (final eventId in joinedIds) {
      final event = eventById[eventId];
      if (event == null) {
        if (disappearedEventIds.contains(eventId)) {
          generated.add(
            AppNotification(
              id: 'gone_$eventId',
              userId: myId,
              type: AppNotificationType.eventCancelledOrDeleted,
              title: 'Event cancelled',
              message: 'An event you joined is no longer available.',
              createdAt: now,
              targetEventId: eventId,
            ),
          );
        }
        continue;
      }

      final startsIn = event.startAt.difference(now);
      if (startsIn.inMinutes >= 0 && startsIn <= const Duration(hours: 1)) {
        generated.add(
          AppNotification(
            id: 'soon_${event.id}',
            userId: myId,
            type: AppNotificationType.eventStartingSoon,
            title: 'Event starting soon',
            message: '${event.title} starts in ${_timeUntilLabel(startsIn)}.',
            createdAt: now.subtract(const Duration(minutes: 1)),
            targetEventId: event.id,
          ),
        );
      }
    }

    for (final event in events) {
      final isPrivateInvite =
          eventInviteRepository().isPrivate(event) &&
          eventInviteRepository().isInvited(event, userId: myId) &&
          !event.joinedByMe &&
          !event.rejectedInviteUserIds.contains(myId);
      if (!isPrivateInvite) {
        continue;
      }
      generated.add(
        AppNotification(
          id: 'invite_${event.id}',
          userId: myId,
          type: AppNotificationType.eventInvite,
          title: 'Private event invite',
          message: 'You were invited to ${event.title}.',
          createdAt: now.subtract(const Duration(minutes: 2)),
          targetEventId: event.id,
        ),
      );
    }

    await notificationRepository().upsertMany(myId, generated);
    await prefs.setStringList(_knownKeyForUser(myId), currentEventIds.toList());
    final stored = await notificationRepository().listForUser(myId);
    return _NotificationPayload(items: stored, eventById: eventById);
  }

  Future<void> _reload() async {
    setState(() {
      _notificationsFuture = _loadNotifications();
    });
  }

  Future<void> _onPullRefresh() async {
    await _reload();
    await _notificationsFuture;
  }

  bool _matchesNotificationsFilter(AppNotification item) {
    switch (_filter) {
      case _NotificationsFilter.all:
        return true;
      case _NotificationsFilter.clubs:
        return item.type == AppNotificationType.clubJoinRequest;
      case _NotificationsFilter.events:
        return item.type != AppNotificationType.clubJoinRequest;
    }
  }

  Future<void> _openNotification(
    AppNotification item,
    Map<String, Event> eventById,
  ) async {
    await notificationRepository().markRead(
      userId: currentUserId,
      notificationId: item.id,
    );
    if (!mounted) {
      return;
    }

    if (item.type == AppNotificationType.clubJoinRequest) {
      final clubId = (item.targetClubId ?? '').trim();
      if (clubId.isEmpty) {
        await _reload();
        return;
      }
      final loaded = await clubRepository().getClub(clubId);
      if (!mounted) {
        return;
      }
      if (loaded != null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            settings: RouteSettings(
              name: ClubInfoScreen.routeName,
              arguments: loaded,
            ),
            builder: (context) => const ClubInfoScreen(),
          ),
        );
      }
      await _reload();
      return;
    }

    final eventId = item.targetEventId?.trim();
    if (eventId == null || eventId.isEmpty) {
      await _reload();
      return;
    }
    final event = eventById[eventId];
    if (event != null) {
      await Navigator.of(context).pushNamed(
        EventDetailScreen.routeName,
        arguments: EventDetailArgs(event: event, showRegisterButton: true),
      );
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    const pageBackground = Color(0xFFEDEFF8);
    const headerBlue = Color(0xFF5E62E8);
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: headerBlue,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await notificationRepository().markAllRead(currentUserId);
              if (!mounted) {
                return;
              }
              await _reload();
            },
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0),
          child: SizedBox.shrink(),
        ),
      ),
      body: FutureBuilder<_NotificationPayload>(
        future: _notificationsFuture,
        builder: (context, snap) {
          final payload =
              snap.data ??
              const _NotificationPayload(
                items: <AppNotification>[],
                eventById: <String, Event>{},
              );
          final items = payload.items;
          final filtered = items.where(_matchesNotificationsFilter).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: pageBackground,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _filter == _NotificationsFilter.all,
                        onSelected: (_) {
                          setState(() => _filter = _NotificationsFilter.all);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Clubs'),
                        selected: _filter == _NotificationsFilter.clubs,
                        onSelected: (_) {
                          setState(() => _filter = _NotificationsFilter.clubs);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Events & other'),
                        selected: _filter == _NotificationsFilter.events,
                        onSelected: (_) {
                          setState(() => _filter = _NotificationsFilter.events);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return RefreshIndicator(
                      onRefresh: _onPullRefresh,
                      child: Builder(
                        builder: (context) {
                          Widget scrollableFill(Widget child) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: child,
                              ),
                            );
                          }

                          if (snap.connectionState != ConnectionState.done &&
                              items.isEmpty) {
                            return scrollableFill(
                              const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (items.isEmpty) {
                            return scrollableFill(
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'No notifications yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          if (filtered.isEmpty) {
                            final msg = _filter == _NotificationsFilter.clubs
                                ? 'No club notifications yet.'
                                : _filter == _NotificationsFilter.events
                                ? 'No event or other notifications.'
                                : 'No notifications yet.';
                            return scrollableFill(
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    msg,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _NotificationTile(
                                item: item,
                                unread: !item.isRead,
                                onTap: () => _openNotification(
                                  item,
                                  payload.eventById,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationPayload {
  final List<AppNotification> items;
  final Map<String, Event> eventById;

  const _NotificationPayload({required this.items, required this.eventById});
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final bool unread;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSoon = item.type == AppNotificationType.eventStartingSoon;
    final isInvite = item.type == AppNotificationType.eventInvite;
    final isUpdated = item.type == AppNotificationType.eventUpdated;
    final isEventJoinRequest =
        item.type == AppNotificationType.eventJoinRequest;
    final isClubJoinRequest =
        item.type == AppNotificationType.clubJoinRequest;
    final isChat = item.type == AppNotificationType.chatMessage;
    final iconBackground = isSoon
        ? const Color(0xFFDFF0E7)
        : isInvite
        ? const Color(0xFFEAE8FF)
        : isUpdated
        ? const Color(0xFFE7F2FF)
        : isClubJoinRequest
        ? const Color(0xFFD7F5EA)
        : isEventJoinRequest
        ? const Color(0xFFFFF4E5)
        : isChat
        ? const Color(0xFFE0F7F4)
        : const Color(0xFFF1F2F7);
    final iconColor = isSoon
        ? const Color(0xFF4A8D64)
        : isInvite
        ? const Color(0xFF5E62E8)
        : isUpdated
        ? const Color(0xFF2A73C9)
        : isClubJoinRequest
        ? const Color(0xFF0F766E)
        : isEventJoinRequest
        ? const Color(0xFFB45309)
        : isChat
        ? const Color(0xFF0F766E)
        : const Color(0xFFB05A76);
    final borderColor = unread
        ? const Color(0xFF6B6FF0)
        : const Color(0xFFD0D2DA);
    final cardColor = unread ? Colors.white : const Color(0xFFF6F6F9);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: unread ? 2 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                isSoon
                    ? Icons.schedule
                    : isInvite
                    ? Icons.mail_outline
                    : isUpdated
                    ? Icons.edit_calendar_outlined
                    : isClubJoinRequest
                    ? Icons.groups_2_outlined
                    : isEventJoinRequest
                    ? Icons.person_add_alt_1_outlined
                    : isChat
                    ? Icons.chat_bubble_outline
                    : Icons.close,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.68),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(item.createdAt),
                    style: const TextStyle(color: Colors.black38, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF6B6FF0),
                  shape: BoxShape.circle,
                ),
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
