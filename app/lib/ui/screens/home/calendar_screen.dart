import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../auth/current_user.dart';
import '../../../data/event_repository.dart';
import '../../../models/event.dart';
import '../../widgets/event_thumbnail_header.dart';
import 'event_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<List<Event>> _eventsFuture;

  DateTime _visibleMonth = _monthStart(DateTime.now());
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _eventsFuture = eventRepository().listEvents();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthLabel = _monthYearLabel(_visibleMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Calendar',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: FutureBuilder<List<Event>>(
                  future: _eventsFuture,
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
                              style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  _eventsFuture = eventRepository().listEvents();
                                });
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final events = snap.data ?? const <Event>[];
                    final eventDays = _myEventDayKeys(events);
                    final upcomingMine = _upcomingForMe(events);

                    return Column(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF4F6F6),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                                          ),
                                          child: Text(
                                            monthLabel,
                                            style: const TextStyle(fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _MonthNavButton(
                                      icon: Icons.chevron_right,
                                      onPressed: () => _shiftMonth(1),
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
                                    eventDayKeys: eventDays,
                                    onSelectDate: (d) => setState(() => _selectedDate = d),
                                    accent: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text(
                              'Upcoming Sport Event',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          flex: 5,
                          child: upcomingMine.isEmpty
                              ? Center(
                                  child: Text(
                                    'No upcoming events yet.',
                                    style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: upcomingMine.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final e = upcomingMine[i];
                                    final badge = _badgeForMe(e);
                                    return _UpcomingEventCard(
                                      event: e,
                                      badgeText: badge,
                                      onTap: () => Navigator.of(context).pushNamed(
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
            ],
          ),
        ),
      ),
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = _monthStart(DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1));
    });
  }

  static DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);

  static String _monthYearLabel(DateTime d) => '${_monthName(d.month)} ${d.year}';

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

  static String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _isMyEvent(Event e, String me) {
    if (me.isEmpty) {
      return false;
    }
    final isCreator = (e.creatorId ?? '').trim() == me;
    return isCreator || e.joinedByMe;
  }

  static Set<String> _myEventDayKeys(List<Event> events) {
    final me = currentUserId.trim();
    final out = <String>{};
    for (final e in events) {
      if (!_isMyEvent(e, me)) {
        continue;
      }
      out.add(_dayKey(e.startAt.toLocal()));
    }
    return out;
  }

  static List<Event> _upcomingForMe(List<Event> events) {
    final me = currentUserId.trim();
    final now = DateTime.now();
    final filtered = events.where((e) {
      if (e.startAt.isBefore(now)) {
        return false;
      }
      return _isMyEvent(e, me);
    }).toList();
    filtered.sort((a, b) => a.startAt.compareTo(b.startAt));
    return filtered;
  }

  static String _badgeForMe(Event e) {
    final me = currentUserId.trim();
    final isCreator = (e.creatorId ?? '').trim().isNotEmpty && (e.creatorId ?? '').trim() == me;
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

  const _MonthNavButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F6F6),
      borderRadius: BorderRadius.circular(12),
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
  final Set<String> eventDayKeys;
  final ValueChanged<DateTime> onSelectDate;
  final Color accent;

  const _MonthGrid({
    required this.monthStart,
    required this.selectedDate,
    required this.eventDayKeys,
    required this.onSelectDate,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(monthStart.year, monthStart.month, 1);
    final firstWeekdaySunday0 = firstOfMonth.weekday % 7; // Sunday=0
    final gridStart = firstOfMonth.subtract(Duration(days: firstWeekdaySunday0));
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
        final side = math.min(
          maxW / 7,
          (maxH - 5 * rowGap) / 6,
        );

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
    final key = _CalendarScreenState._dayKey(d);
    final hasEvent = eventDayKeys.contains(key);
    final selectedKey = selectedDate == null ? null : _CalendarScreenState._dayKey(selectedDate!);
    final isSelected = selectedKey == key;
    final baseText = isInMonth ? Colors.black : Colors.black.withValues(alpha: 0.35);

    final bg = isSelected
        ? Colors.black.withValues(alpha: 0.92)
        : hasEvent
            ? accent.withValues(alpha: 0.16)
            : Colors.transparent;

    final textColor = isSelected ? Colors.white : baseText;
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
                  style: TextStyle(fontWeight: FontWeight.w900, color: textColor),
                ),
              ),
              if (hasEvent && !isSelected)
                Positioned(
                  bottom: dotBottom,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
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

class _UpcomingEventCard extends StatelessWidget {
  final Event event;
  final String badgeText;
  final VoidCallback onTap;

  const _UpcomingEventCard({
    required this.event,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: cs.primary,
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
    // Match calendar grid: keys use local calendar date. If [startAt] is UTC,
    // using .day/.month on it can be the *previous* UTC day vs local (off-by-one).
    final d = e.startAt.toLocal();
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

