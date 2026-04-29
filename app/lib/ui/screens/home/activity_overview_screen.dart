import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../data/event_repository.dart';
import '../../../data/event_registration_repository.dart';
import '../../../data/membership_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/event.dart';
import '../../../models/user_profile.dart';
import '../../../services/ticket_service.dart';
import '../../../auth/current_user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ad_banner.dart';

import 'event_detail_screen.dart';
import '../../widgets/event_thumbnail_header.dart';

class ActivityOverviewScreen extends StatefulWidget {
  static const routeName = '/activity';

  const ActivityOverviewScreen({super.key});

  @override
  State<ActivityOverviewScreen> createState() => _ActivityOverviewScreenState();
}

enum _ActivityTab { ticket, created, history }

class _ActivityOverviewScreenState extends State<ActivityOverviewScreen> {
  _ActivityTab _tab = _ActivityTab.ticket;
  final Set<String> _cancellingEventIds = <String>{};
  late Future<MembershipStatus> _membershipFuture;
  late Future<List<Object?>> _activityPayloadFuture;

  @override
  void initState() {
    super.initState();
    _membershipFuture = membershipRepository().getStatus();
    _activityPayloadFuture = _loadActivityPayload();
  }

  Future<List<Object?>> _loadActivityPayload() {
    return Future.wait<Object?>([
      eventRepository().listEvents(),
      profileRepository().getMyProfile(),
    ]);
  }

  void _refreshActivityPayload() {
    setState(() {
      _activityPayloadFuture = _loadActivityPayload();
    });
  }

  String _headerTitleForTab(_ActivityTab tab) {
    switch (tab) {
      case _ActivityTab.ticket:
        return 'Event Ticket';
      case _ActivityTab.created:
        return 'Created Event';
      case _ActivityTab.history:
        return 'History';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final activityTheme = AppTheme.eventFlowTheme(Theme.of(context));
    return Theme(
      data: activityTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F1FF),
        appBar: AppBar(
          backgroundColor: AppTheme.eventPurpleDeep,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 56,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
          ),
          title: Text(
            _headerTitleForTab(_tab),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.98),
            ),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              onPressed: _refreshActivityPayload,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<List<Object?>>(
          future: _activityPayloadFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = (snap.data != null
                ? snap.data![0] as List<Event>
                : const <Event>[]);
            final profile = (snap.data != null
                ? snap.data![1] as UserProfile?
                : null);
            final fullName = profile?.realName.trim().isNotEmpty == true
                ? profile!.realName.trim()
                : '—';
            bool isParticipant(Event e) =>
                e.joinedByMe ||
                (e.creatorId != null && e.creatorId == currentUserId);

            final created = events.where((e) {
              if (e.creatorId == null || e.creatorId != currentUserId) {
                return false;
              }
              final endAt = e.startAt.add(e.duration);
              return endAt.isAfter(now);
            }).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));
            final ticket = events.where((e) {
              if (!isParticipant(e)) return false;
              final endAt = e.startAt.add(e.duration);
              return endAt.isAfter(now);
            }).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));
            final history = events.where((e) {
              if (!isParticipant(e)) return false;
              final endAt = e.startAt.add(e.duration);
              return !endAt.isAfter(now);
            }).toList()..sort((a, b) => b.startAt.compareTo(a.startAt));

            return Column(
              children: [
                _ActivityTabHeader(
                  selected: _tab,
                  onSelect: (t) => setState(() => _tab = t),
                ),
                FutureBuilder<MembershipStatus>(
                  future: _membershipFuture,
                  builder: (context, membershipSnap) {
                    if (membershipSnap.connectionState !=
                            ConnectionState.done &&
                        membershipSnap.data == null) {
                      return const SizedBox.shrink();
                    }
                    if (membershipSnap.data?.isPremium == true) {
                      return const SizedBox.shrink();
                    }
                    return const AppAdBanner(
                      padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _ActivityTabBody(
                    tab: _tab,
                    now: now,
                    fullName: fullName,
                    created: created,
                    ticket: ticket,
                    history: history,
                    onOpenEvent:
                        (
                          event, {
                          required bool allowCreatorActions,
                          required bool showRegisterButton,
                          DateTime? chatEnabledUntil,
                        }) {
                          Navigator.of(context)
                              .pushNamed(
                                EventDetailScreen.routeName,
                                arguments: EventDetailArgs(
                                  event: event,
                                  showRegisterButton: showRegisterButton,
                                  allowCreatorActions: allowCreatorActions,
                                  chatEnabledUntil: chatEnabledUntil,
                                ),
                              )
                              .then((_) {
                                if (!mounted) {
                                  return;
                                }
                                _refreshActivityPayload();
                              });
                        },
                    onCancelTicket: _cancelTicket,
                    isCancellingEvent: (eventId) =>
                        _cancellingEventIds.contains(eventId),
                    onRefresh: () async => _refreshActivityPayload(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _cancelTicket(Event event) async {
    if (_cancellingEventIds.contains(event.id)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Cancel ticket?'),
          content: const Text('Are you sure you want to leave this event?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _cancellingEventIds.add(event.id));
    try {
      await eventRegistrationRepository().cancel(
        eventId: event.id,
        userId: currentUserId,
      );
      final joined = await eventRegistrationRepository().getJoinedCount(
        event.id,
      );
      if (AppwriteService.isConfigured &&
          AppwriteConfig.databaseId.isNotEmpty &&
          AppwriteConfig.eventsCollectionId.isNotEmpty) {
        await AppwriteService.updateDocument(
          collectionId: AppwriteConfig.eventsCollectionId,
          documentId: event.id,
          data: {'joined': joined},
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ticket cancelled.')));
      _refreshActivityPayload();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to cancel ticket.')));
    } finally {
      if (mounted) {
        setState(() => _cancellingEventIds.remove(event.id));
      }
    }
  }
}

class _ActivityTabHeader extends StatelessWidget {
  final _ActivityTab selected;
  final ValueChanged<_ActivityTab> onSelect;

  const _ActivityTabHeader({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget buildTab(_ActivityTab t, String label) {
      final isSelected = selected == t;
      return Expanded(
        child: InkWell(
          onTap: () => onSelect(t),
          borderRadius: BorderRadius.circular(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.black87 : Colors.black45,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isSelected ? c.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
        ),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildTab(_ActivityTab.ticket, 'Ticket'),
            buildTab(_ActivityTab.created, 'Created'),
            buildTab(_ActivityTab.history, 'History'),
          ],
        ),
      ),
    );
  }
}

class _ActivityTabBody extends StatelessWidget {
  final _ActivityTab tab;
  final DateTime now;
  final String fullName;
  final List<Event> ticket;
  final List<Event> created;
  final List<Event> history;
  final void Function(
    Event event, {
    required bool allowCreatorActions,
    required bool showRegisterButton,
    DateTime? chatEnabledUntil,
  })
  onOpenEvent;
  final Future<void> Function(Event event) onCancelTicket;
  final bool Function(String eventId) isCancellingEvent;
  final Future<void> Function() onRefresh;

  const _ActivityTabBody({
    required this.tab,
    required this.now,
    required this.fullName,
    required this.ticket,
    required this.created,
    required this.history,
    required this.onOpenEvent,
    required this.onCancelTicket,
    required this.isCancellingEvent,
    required this.onRefresh,
  });

  String _fmtTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hour12 = ((dt.hour + 11) % 12) + 1;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${two(dt.minute)} $ampm';
  }

  String _fmtDuration(DateTime start, Duration d) {
    final minutes = d.inMinutes;
    if (minutes <= 60) return '1 Hour';
    if (minutes == 90) return '1.5 Hours';
    if (minutes == 120) return '2 Hours';
    if (minutes == 150) return '2.5 Hours';
    if (minutes == 180) return '3 Hours';
    if (minutes == 210) return '3.5 Hours';
    if (minutes == 240) return '4 Hours';
    if (minutes == 270) return '4.5 Hours';
    if (minutes == 300) return '5 Hours';
    return '$minutes Min';
  }

  int _freezeHoursFromLabel(String label) {
    final match = RegExp(r'(\d+)').firstMatch(label);
    final hours = int.tryParse(match?.group(1) ?? '');
    return (hours ?? 12).clamp(0, 240);
  }

  String _fmtTemplateDate(DateTime dt) {
    const months = <String>[
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];

    return '${_ordinalDay(dt.day)} ${months[dt.month - 1]} ${dt.year}';
  }

  String _ordinalDay(int day) {
    if (day >= 11 && day <= 13) {
      return '${day}th';
    }

    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  Widget _buildTemplateField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF666666),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateTearLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 12).floor().clamp(16, 42);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(
            count,
            (index) => Container(
              width: 8,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = tab == _ActivityTab.ticket
        ? ticket
        : tab == _ActivityTab.created
        ? created
        : history;

    if (list.isEmpty) {
      final label = tab == _ActivityTab.ticket
          ? 'No joined events yet'
          : tab == _ActivityTab.created
          ? 'No created events yet'
          : 'No history yet';
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 140),
            Center(
              child: Text(
                label,
                style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        itemBuilder: (context, idx) {
        final e = list[idx];
        final endAt = e.startAt.add(e.duration);
        final dateTimeStr =
            '${e.startAt.day}/${e.startAt.month}/${e.startAt.year.toString().substring(2)}';
        final timeStr = _fmtTime(e.startAt);
        final durationStr = _fmtDuration(e.startAt, e.duration);
        final freezeHours = _freezeHoursFromLabel(e.cancellationFreeze);
        final cancellationCutoff = e.startAt.subtract(
          Duration(hours: freezeHours),
        );
        final canCancelNow = now.isBefore(cancellationCutoff);

        final card = Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E7EE)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (tab == _ActivityTab.created) {
                onOpenEvent(
                  e,
                  allowCreatorActions: true,
                  showRegisterButton: false,
                );
                return;
              }

              if (tab == _ActivityTab.history) {
                onOpenEvent(
                  e,
                  allowCreatorActions: false,
                  showRegisterButton: false,
                  chatEnabledUntil: endAt.add(const Duration(days: 7)),
                );
                return;
              }

              // ticket
              onOpenEvent(
                e,
                allowCreatorActions: false,
                showRegisterButton: false,
              );
            },
            child: tab == _ActivityTab.ticket
                ? FutureBuilder<int>(
                    future: TicketService.generateTicketId(
                      eventId: e.id,
                      userId: currentUserId,
                    ),
                    builder: (context, ticketSnap) {
                      final ticketId = ticketSnap.hasData
                          ? ticketSnap.data
                          : null;
                      final ticketCode = ticketId != null
                          ? ticketId.toString().padLeft(5, '0')
                          : '-----';
                      final qrData = ticketId != null
                          ? TicketService.buildTicketQrData(
                              event: e,
                              userId: currentUserId,
                              ticketId: ticketId,
                            )
                          : TicketService.buildLegacyUserLookupQrData(
                              eventId: e.id,
                              userId: currentUserId,
                            );
                      final eventDate = _fmtTemplateDate(e.startAt);
                      final eventTime = _fmtTime(e.startAt);
                      final validUntil = _fmtTime(e.startAt.add(e.duration));
                      final location = e.location.trim().isEmpty
                          ? 'TBA'
                          : e.location;

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      color: const Color(0xFFF2F2F2),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            height: 44,
                                            color: const Color(0xFF00701F),
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'CIRCLE.BN',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 26,
                                            ),
                                            child: Text(
                                              e.title.toUpperCase(),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 32,
                                                height: 1,
                                                letterSpacing: 0.4,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: _buildTemplateTearLine(),
                                  ),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      width: double.infinity,
                                      color: const Color(0xFFF2F2F2),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        18,
                                        16,
                                        18,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: _buildTemplateField(
                                                  label: 'NAME',
                                                  value: fullName,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _buildTemplateField(
                                                  label: 'DATE',
                                                  value: eventDate,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: _buildTemplateField(
                                                  label: 'TICKET ID',
                                                  value: ticketCode,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _buildTemplateField(
                                                  label: 'TIME',
                                                  value: eventTime,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: _buildTemplateField(
                                                  label: 'SPORT',
                                                  value: e.sport,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _buildTemplateField(
                                                  label: 'VALID UNTIL',
                                                  value: validUntil,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Center(
                                            child: Container(
                                              color: Colors.white,
                                              padding: const EdgeInsets.all(8),
                                              child: QrImageView(
                                                data: qrData,
                                                version: QrVersions.auto,
                                                size: 190,
                                                backgroundColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Container(
                                            height: 2,
                                            color: Colors.black,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Present this QR code at the entrance',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Valid until ${_fmtTime(e.startAt.add(e.duration))}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF666666),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          const Text(
                                            'LOCATION',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF666666),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            location.toUpperCase(),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Colors.black,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              canCancelNow
                                  ? 'Cancellation allowed until ${_fmtTime(cancellationCutoff)}'
                                  : 'Cancellation freeze started (${e.cancellationFreeze})',
                              style: TextStyle(
                                color: canCancelNow
                                    ? Colors.black54
                                    : Colors.red.shade300,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (canCancelNow)
                                  TextButton(
                                    onPressed: isCancellingEvent(e.id)
                                        ? null
                                        : () => onCancelTicket(e),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red.shade400,
                                    ),
                                    child: Text(
                                      isCancellingEvent(e.id)
                                          ? 'Cancelling...'
                                          : 'Cancel',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EventThumbnailHeader(event: e),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    e.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (tab == _ActivityTab.created)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Location: ${e.location}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Date: $dateTimeStr  Time: $timeStr',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Duration: $durationStr',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );

        return card;
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: list.length,
      ),
    );
  }
}
