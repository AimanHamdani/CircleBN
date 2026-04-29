import 'package:flutter/material.dart';

import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../data/event_invite_repository.dart';
import '../../../data/event_repository.dart';
import '../../../models/event.dart';
import '../../theme/app_theme.dart';
import '../../widgets/event_thumbnail_header.dart';
import 'event_detail_screen.dart';

class PrivateEventsScreen extends StatefulWidget {
  static const routeName = '/private-events';

  const PrivateEventsScreen({super.key});

  @override
  State<PrivateEventsScreen> createState() => _PrivateEventsScreenState();
}

class _PrivateEventsScreenState extends State<PrivateEventsScreen> {
  late Future<List<Event>> _eventsFuture;

  void _refreshEvents() {
    setState(() {
      _eventsFuture = eventRepository().listEvents();
    });
  }

  @override
  void initState() {
    super.initState();
    _eventsFuture = eventRepository().listEvents();
    AppwriteService.dataVersion.addListener(_handleGlobalDataChange);
  }

  @override
  void dispose() {
    AppwriteService.dataVersion.removeListener(_handleGlobalDataChange);
    super.dispose();
  }

  void _handleGlobalDataChange() {
    if (!mounted) {
      return;
    }
    _refreshEvents();
  }

  Future<void> _openEventDetails(Event event) async {
    await Navigator.of(context).pushNamed(
      EventDetailScreen.routeName,
      arguments: EventDetailArgs(
        event: event,
        showRegisterButton: true,
      ),
    );
    if (!mounted) {
      return;
    }
    _refreshEvents();
  }

  Widget _buildRefreshableEmpty() {
    return RefreshIndicator(
      onRefresh: () async => _refreshEvents(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No private events for you yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.eventFlowTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Private Events',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              onPressed: _refreshEvents,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<List<Event>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            final all = snapshot.data ?? const <Event>[];
            final privateEvents = all.where((e) {
              if (!_isUpcomingOrOngoing(e)) {
                return false;
              }
              if (!eventInviteRepository().isPrivate(e)) {
                return false;
              }
              final isCreator = (e.creatorId ?? '').trim() == currentUserId;
              final isInvited = eventInviteRepository().isInvited(
                e,
                userId: currentUserId,
              );
              final hasPendingRequest = e.pendingJoinRequestUserIds.contains(
                currentUserId,
              );
              final isJoined = e.joinedByMe;
              return isCreator || isInvited || hasPendingRequest || isJoined;
            }).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));

            if (snapshot.connectionState != ConnectionState.done &&
                privateEvents.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (privateEvents.isEmpty) {
              return _buildRefreshableEmpty();
            }

            return RefreshIndicator(
              onRefresh: () async => _refreshEvents(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                itemCount: privateEvents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final event = privateEvents[i];
                  final rejected = event.rejectedInviteUserIds.contains(
                    currentUserId,
                  );
                  final isCreator = (event.creatorId ?? '').trim() == currentUserId;
                  final hasPendingRequest = event.pendingJoinRequestUserIds
                      .contains(currentUserId);
                  final statusLabel = isCreator
                      ? 'Created'
                      : event.joinedByMe
                      ? 'Joined'
                      : rejected
                      ? 'Rejected'
                      : eventInviteRepository().isRequestJoinPrivate(event) &&
                            hasPendingRequest
                      ? 'Request sent'
                      : 'Invited';
                  final statusColor = isCreator
                      ? const Color(0xFF1D4ED8)
                      : event.joinedByMe
                      ? const Color(0xFF15803D)
                      : rejected
                      ? const Color(0xFFB45309)
                      : AppTheme.eventPurple;
                  return InkWell(
                    onTap: () => _openEventDetails(event),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE3E7EE)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          EventThumbnailHeader(event: event),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${event.location} • ${_fmtTime(event.startAt)}',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
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
            );
          },
        ),
      ),
    );
  }
}

String _fmtTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = dt.hour;
  final m = two(dt.minute);
  final hour12 = ((h + 11) % 12) + 1;
  final ampm = h >= 12 ? 'PM' : 'AM';
  return '$hour12:$m $ampm';
}

bool _isUpcomingOrOngoing(Event event) {
  final endAt = event.startAt.add(event.duration);
  return endAt.isAfter(DateTime.now());
}
