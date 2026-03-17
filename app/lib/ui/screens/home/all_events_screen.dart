import 'package:flutter/material.dart';

import '../../../data/sample_events.dart';
import '../../../models/event.dart';
import 'event_detail_screen.dart';

class AllEventsScreen extends StatefulWidget {
  static const routeName = '/events';
  const AllEventsScreen({super.key});

  @override
  State<AllEventsScreen> createState() => _AllEventsScreenState();
}

class _AllEventsScreenState extends State<AllEventsScreen> {
  DateTime? _selectedDate;
  int _weekOffset = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedDate ??= _today();
  }

  @override
  Widget build(BuildContext context) {
    final all = SampleEvents.all;
    final selected = _selectedDate;
    final weekDays = _weekDaysFromTodayOffset(_weekOffset);
    final events = selected == null ? all : all.where((e) => _isSameDay(e.startAt, selected)).toList();
    final canPrevWeek = _weekOffset > 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Home', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('All Events', style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Filters (mock).')),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE3E7EE)),
                      ),
                      child: const Icon(Icons.tune),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  InkWell(
                    onTap: canPrevWeek
                        ? () => setState(() {
                            _weekOffset -= 1;
                            _selectedDate = _weekDaysFromTodayOffset(_weekOffset).first;
                          })
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE3E7EE)),
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        color: canPrevWeek ? null : Colors.black26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _weekTitle(weekDays.first, weekDays.last),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        const Text('Pick a day', style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() {
                      _weekOffset += 1;
                      _selectedDate = _weekDaysFromTodayOffset(_weekOffset).first;
                    }),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE3E7EE)),
                      ),
                      child: const Icon(Icons.chevron_right),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemCount: weekDays.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final d = weekDays[i];
                  return _DateChip(
                    label: '${d.day}',
                    sub: _weekdayLetter(d),
                    selected: selected != null && _isSameDay(d, selected),
                    onTap: () => setState(() => _selectedDate = d),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: events.isEmpty
                  ? _EmptyDayState(selectedDate: selected)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final e = events[idx];
                        return _AllEventCard(
                          event: e,
                          onOpen: () => Navigator.of(context).pushNamed(
                            EventDetailScreen.routeName,
                            arguments: EventDetailArgs(event: e, showRegisterButton: true),
                          ),
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

class _AllEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onOpen;
  const _AllEventCard({required this.event, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E7EE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 165,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.20),
                    const Color(0xFFFFFFFF),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.image_outlined, color: Colors.black.withValues(alpha: 0.35), size: 44),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          '${event.location} • ${_fmtTime(event.startAt)}',
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Open',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
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
}

class _DateChip extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Theme.of(context).colorScheme.primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.transparent : const Color(0xFFE3E7EE)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w900)),
            Text(sub, style: TextStyle(color: fg.withValues(alpha: 0.90), fontSize: 11)),
          ],
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

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _monthShort(int month) {
  const months = [
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
  return months[(month - 1).clamp(0, 11)];
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

List<DateTime> _weekDaysFromTodayOffset(int weekOffset) {
  final start = _today().add(Duration(days: weekOffset * 7));
  return List<DateTime>.generate(
    7,
    (i) => DateTime(start.year, start.month, start.day + i),
  );
}

String _weekdayShort(DateTime dt) {
  const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return w[(dt.weekday - 1).clamp(0, 6)];
}

String _weekdayLetter(DateTime dt) {
  const w = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return w[(dt.weekday - 1).clamp(0, 6)];
}

String _weekTitle(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    return '${start.day}–${end.day} ${_monthShort(start.month)}';
  }
  if (start.year == end.year) {
    return '${start.day} ${_monthShort(start.month)} – ${end.day} ${_monthShort(end.month)}';
  }
  return '${start.day} ${_monthShort(start.month)} ${start.year} – ${end.day} ${_monthShort(end.month)} ${end.year}';
}

class _EmptyDayState extends StatelessWidget {
  final DateTime? selectedDate;
  const _EmptyDayState({required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dt = selectedDate;
    final title = dt == null ? 'No events available' : 'No events available on this day';
    final subtitle = dt == null
        ? 'Try another date.'
        : '${_weekdayShort(dt)} • ${dt.day} ${_monthShort(dt.month)}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E7EE)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.event_busy, color: c.primary),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Check back later or pick a different date.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

