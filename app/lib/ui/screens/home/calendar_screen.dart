import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../auth/current_user.dart';
import '../../../data/club_member_repository.dart';
import '../../../data/club_repository.dart';
import '../../../data/event_repository.dart';
import '../../../models/club.dart';
import '../../../models/event.dart';
import '../../widgets/event_thumbnail_header.dart';
import 'event_detail_screen.dart';

class _CalendarPayload {
  final List<Event> events;
  final List<ClubMember> memberships;
  final List<Club> clubs;

  const _CalendarPayload({
    required this.events,
    required this.memberships,
    required this.clubs,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<_CalendarPayload> _payloadFuture;

  DateTime _visibleMonth = _monthStart(DateTime.now());
  DateTime? _selectedDate;

  /// When true, only events with [Event.clubId] in [_selectedClubIds] (intersected with joined clubs).
  bool _clubFilterEnabled = false;

  /// Subset of joined clubs to include; when empty while [_clubFilterEnabled], treated as no clubs selected.
  final Set<String> _selectedClubIds = {};

  @override
  void initState() {
    super.initState();
    _payloadFuture = _loadCalendarPayload();
    _selectedDate = DateTime.now();
  }

  Future<_CalendarPayload> _loadCalendarPayload() async {
    final events = await eventRepository().listEvents();
    final me = currentUserId.trim();
    final memberships = me.isEmpty
        ? const <ClubMember>[]
        : await clubMemberRepository().listMembershipsForUser(userId: me);
    final clubs = await clubRepository().listClubs();
    return _CalendarPayload(
      events: events,
      memberships: memberships,
      clubs: clubs,
    );
  }

  void _refreshPayload() {
    setState(() {
      _payloadFuture = _loadCalendarPayload();
    });
  }

  static Set<String> _joinedOrCreatedClubIds({
    required List<ClubMember> memberships,
    required List<Club> clubs,
    required String currentUserId,
  }) {
    final out = <String>{};
    for (final m in memberships) {
      final id = m.clubId.trim();
      if (id.isNotEmpty) {
        out.add(id);
      }
    }
    final me = currentUserId.trim();
    if (me.isNotEmpty) {
      for (final c in clubs) {
        final creatorId = (c.creatorId ?? '').trim();
        if (creatorId.isNotEmpty && creatorId == me) {
          out.add(c.id);
        }
      }
    }
    return out;
  }

  static List<Club> _joinedClubsList(List<Club> clubs, Set<String> joinedIds) {
    final list = clubs.where((c) => joinedIds.contains(c.id)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Events that are not fully over yet, optionally limited to club-hosted events for joined clubs.
  List<Event> _filteredVisibleEvents(
    List<Event> all,
    Set<String> joinedClubIds,
  ) {
    final now = DateTime.now();
    final me = currentUserId.trim();
    var list = all
        .where((e) => e.startAt.add(e.duration).isAfter(now))
        .toList();
    if (_clubFilterEnabled) {
      if (_selectedClubIds.isEmpty) {
        return list.where((e) => (e.creatorId ?? '').trim() == me).toList();
      }
      final allowed = _selectedClubIds.intersection(joinedClubIds);
      list = list.where((e) {
        final isCreatedByMe = (e.creatorId ?? '').trim() == me;
        if (isCreatedByMe) {
          return true;
        }
        final cid = e.clubId?.trim() ?? '';
        return cid.isNotEmpty && allowed.contains(cid);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    const accentOrange = Color(0xFFF6A300);
    final monthLabel = _monthYearLabel(_visibleMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF7F3),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: accentOrange,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: const Text(
                'Calendar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34 / 1.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: FutureBuilder<_CalendarPayload>(
                  future: _payloadFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Could not load events.',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: _refreshPayload,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final payload = snap.data!;
                    final joinedIds = _joinedOrCreatedClubIds(
                      memberships: payload.memberships,
                      clubs: payload.clubs,
                      currentUserId: currentUserId,
                    );
                    final joinedClubs = _joinedClubsList(
                      payload.clubs,
                      joinedIds,
                    );
                    final visibleEvents = _filteredVisibleEvents(
                      payload.events,
                      joinedIds,
                    );
                    final eventCountsByDay = _eventCountsByDay(visibleEvents);
                    final selected = _selectedDate ?? DateTime.now();
                    final eventsOnSelectedDay = _eventsOnCalendarDay(
                      visibleEvents,
                      selected,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<bool>(
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: accentOrange.withValues(
                              alpha: 0.22,
                            ),
                            foregroundColor: Colors.black87,
                          ),
                          segments: const [
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('All events'),
                              icon: Icon(Icons.event_outlined, size: 18),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('My clubs'),
                              icon: Icon(Icons.groups_outlined, size: 18),
                            ),
                          ],
                          selected: {_clubFilterEnabled},
                          onSelectionChanged: (Set<bool> next) {
                            final v = next.first;
                            setState(() {
                              _clubFilterEnabled = v;
                              if (v && joinedIds.isNotEmpty) {
                                _selectedClubIds
                                  ..clear()
                                  ..addAll(joinedIds);
                              }
                            });
                          },
                        ),
                        if (_clubFilterEnabled) ...[
                          const SizedBox(height: 8),
                          if (joinedClubs.isEmpty)
                            Text(
                              'Join a club from Circle to filter by club-hosted events.',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.55),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            SizedBox(
                              height: 40,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: joinedClubs.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  final c = joinedClubs[i];
                                  final sel = _selectedClubIds.contains(c.id);
                                  return FilterChip(
                                    label: Text(
                                      c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    selected: sel,
                                    onSelected: (on) {
                                      setState(() {
                                        if (on) {
                                          _selectedClubIds.add(c.id);
                                        } else {
                                          _selectedClubIds.remove(c.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                        const SizedBox(height: 10),
                        Expanded(
                          flex: 6,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEFEFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE9C261),
                                width: 1.2,
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    _MonthNavButton(
                                      icon: Icons.chevron_left,
                                      onPressed: () => _shiftMonth(-1),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF5DB),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE8C36A),
                                            ),
                                          ),
                                          child: Text(
                                            monthLabel,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _MonthNavButton(
                                      icon: Icons.chevron_right,
                                      onPressed: () => _shiftMonth(1),
                                      color: const Color(0xFFFFF5DB),
                                      borderColor: const Color(0xFFE8C36A),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _WeekdayHeader(),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _MonthGrid(
                                    monthStart: _visibleMonth,
                                    selectedDate: _selectedDate,
                                    eventCountsByDay: eventCountsByDay,
                                    onSelectDate: (d) =>
                                        setState(() => _selectedDate = d),
                                    accent: accentOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Events · ${_dayHeadingLabel(selected)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          flex: 5,
                          child: eventsOnSelectedDay.isEmpty
                              ? Center(
                                  child: Text(
                                    'No events on this day.',
                                    style: TextStyle(
                                      color: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: eventsOnSelectedDay.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final e = eventsOnSelectedDay[i];
                                    final badge = _badgeForMe(e);
                                    return _UpcomingEventCard(
                                      event: e,
                                      badgeText: badge,
                                      accent: accentOrange,
                                      onTap: () =>
                                          Navigator.of(context).pushNamed(
                                            EventDetailScreen.routeName,
                                            arguments: e,
                                          ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = _monthStart(
        DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1),
      );
    });
  }

  static DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);

  static String _monthYearLabel(DateTime d) =>
      '${_monthName(d.month)} ${d.year}';

  static String _monthName(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[(m - 1).clamp(0, 11)];
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Keep the stored wall-clock components as entered (do not timezone-shift).
  /// This matches Home/Event Detail behavior and avoids 3 PM -> 11 PM drifts.
  static DateTime _displayWallClock(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);

  /// Calendar bucket in wall-clock date (date-only).
  static String _calendarDayKey(DateTime instant) {
    final d = _displayWallClock(instant);
    return _dayKey(DateTime(d.year, d.month, d.day));
  }

  static Map<String, int> _eventCountsByDay(List<Event> events) {
    final out = <String, int>{};
    for (final e in events) {
      final k = _calendarDayKey(e.startAt);
      out[k] = (out[k] ?? 0) + 1;
    }
    return out;
  }

  static List<Event> _eventsOnCalendarDay(List<Event> events, DateTime day) {
    final key = _calendarDayKey(day);
    final list = events
        .where((e) => _calendarDayKey(e.startAt) == key)
        .toList();
    list.sort((a, b) => a.startAt.compareTo(b.startAt));
    return list;
  }

  static String _dayHeadingLabel(DateTime d) {
    final l = d.toLocal();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final wd = weekdays[(l.weekday - 1).clamp(0, 6)];
    return '$wd ${_monthName(l.month)} ${l.day}, ${l.year}';
  }

  static String _badgeForMe(Event e) {
    final me = currentUserId.trim();
    final isCreator =
        (e.creatorId ?? '').trim().isNotEmpty &&
        (e.creatorId ?? '').trim() == me;
    if (isCreator) {
      return 'Created';
    }
    if (e.joinedByMe) {
      return 'Joined';
    }
    return '';
  }
}

class _MonthNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color borderColor;

  const _MonthNavButton({
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFFF4F6F6),
    this.borderColor = const Color(0xFFE3E7EE),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(child: Icon(icon)),
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
    return Row(
      children: [
        for (final s in labels)
          Expanded(
            child: Center(
              child: Text(
                s,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime monthStart;
  final DateTime? selectedDate;
  final Map<String, int> eventCountsByDay;
  final ValueChanged<DateTime> onSelectDate;
  final Color accent;

  const _MonthGrid({
    required this.monthStart,
    required this.selectedDate,
    required this.eventCountsByDay,
    required this.onSelectDate,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(monthStart.year, monthStart.month, 1);
    final firstWeekdaySunday0 = firstOfMonth.weekday % 7; // Sunday=0
    final gridStart = firstOfMonth.subtract(
      Duration(days: firstWeekdaySunday0),
    );
    final days = List.generate(42, (i) => gridStart.add(Duration(days: i)));

    // Rows used `AspectRatio(1)` inside `Row` → each row height became ~row width, which
    // overflows short viewports. Size cells from the bounded height we get from `Expanded`.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        if (maxW <= 0 || maxH <= 0) {
          return const SizedBox.shrink();
        }
        const rowGap = 4.0;
        final side = math.min(maxW / 7, (maxH - 5 * rowGap) / 6);

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            for (var row = 0; row < 6; row++) ...[
              SizedBox(
                height: side,
                child: Row(
                  children: [
                    for (final d in days.skip(row * 7).take(7).toList())
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: _dayCell(d, side),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (row < 5) const SizedBox(height: rowGap),
            ],
          ],
        );
      },
    );
  }

  Widget _dayCell(DateTime d, double cellSize) {
    final isInMonth = d.month == monthStart.month;
    final key = _CalendarScreenState._calendarDayKey(d);
    final eventCount = eventCountsByDay[key] ?? 0;
    final selectedKey = selectedDate == null
        ? null
        : _CalendarScreenState._calendarDayKey(selectedDate!);
    final isSelected = selectedKey == key;
    final baseText = isInMonth
        ? Colors.black
        : Colors.black.withValues(alpha: 0.35);

    final bg = isSelected
        ? Colors.black.withValues(alpha: 0.92)
        : Colors.transparent;

    final textColor = isSelected ? Colors.white : baseText;
    final markerColor = isSelected ? Colors.white : accent;
    final dotBottom = math.max(4.0, cellSize * 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelectDate(d),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '${d.day}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
              if (eventCount > 0)
                Positioned(
                  bottom: dotBottom,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _DayEventMarkers(
                      count: eventCount,
                      cellSize: cellSize,
                      color: markerColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1–3 events: that many dots. More than 3: three dots plus "+N" where N is events beyond 3
/// (e.g. 4 → "+1", 6 → "+3").
class _DayEventMarkers extends StatelessWidget {
  final int count;
  final double cellSize;
  final Color color;

  const _DayEventMarkers({
    required this.count,
    required this.cellSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    final dotSize = math.max(3.0, cellSize * 0.075).clamp(3.0, 5.0);
    const gap = 2.0;
    final fontSize = math.max(7.5, cellSize * 0.16).clamp(7.5, 11.0);

    final dots = count <= 3 ? count : 3;
    final overflow = count > 3 ? count - 3 : 0;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < dots; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
          if (overflow > 0) ...[
            const SizedBox(width: gap),
            Text(
              '+$overflow',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  final Event event;
  final String badgeText;
  final VoidCallback onTap;
  final Color accent;

  const _UpcomingEventCard({
    required this.event,
    required this.badgeText,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE8C36A)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EventThumbnailHeader(event: event, height: 140),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _eventSubtitle(event),
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badgeText.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w900,
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
  }

  static String _eventSubtitle(Event e) {
    final d = _CalendarScreenState._displayWallClock(e.startAt);
    final dow = _dowLabel(d.weekday);
    final m = _CalendarScreenState._monthName(d.month);
    final day = d.day.toString();
    final time = _timeLabel(d);
    final loc = e.location.trim().isNotEmpty ? ' • ${e.location.trim()}' : '';
    return '$dow $day $m • $time$loc';
  }

  static String _dowLabel(int weekday) {
    const labels = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[weekday.clamp(1, 7)];
  }

  static String _timeLabel(DateTime d) {
    final h = d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final isPm = h >= 12;
    final h12 = ((h + 11) % 12) + 1;
    return '$h12:$m ${isPm ? 'PM' : 'AM'}';
  }
}
