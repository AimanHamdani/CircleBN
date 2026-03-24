import 'package:flutter/material.dart';

import '../../../data/event_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/event.dart';
import '../../../models/user_profile.dart';
import 'event_detail_screen.dart';
import '../../widgets/event_thumbnail_header.dart';

class AllEventsScreen extends StatefulWidget {
  static const routeName = '/events';
  const AllEventsScreen({super.key});

  @override
  State<AllEventsScreen> createState() => _AllEventsScreenState();
}

class _AllEventsScreenState extends State<AllEventsScreen> {
  DateTime? _selectedDate;
  /// 0 = calendar week that contains today (Mon–Sun). Increase to show future weeks.
  int _visibleWeekPage = 0;

  late Future<List<Object?>> _screenDataFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _screenDataFuture = Future.wait<Object?>([
      eventRepository().listEvents(),
      profileRepository().getMyProfile(),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedDate ??= _today();
  }

  void _setVisibleWeekPage(int page) {
    if (page < 0) {
      return;
    }
    setState(() {
      _visibleWeekPage = page;
      _clampSelectedToVisibleWeek();
    });
  }

  void _clampSelectedToVisibleWeek() {
    final monday = _mondayOfWeekPage(_visibleWeekPage);
    final sel = _selectedDate;
    if (sel == null || !_isDateInWeek(sel, monday)) {
      final today = _today();
      _selectedDate = _isDateInWeek(today, monday) ? today : monday;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDate;
    final weekMonday = _mondayOfWeekPage(_visibleWeekPage);
    final weekEnd = weekMonday.add(const Duration(days: 6));
    const headerDividerColor = Color(0xFFE8EDEB);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 56 : 0,
        leading: Navigator.of(context).canPop()
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE3E7EE)),
                      ),
                      child: const Icon(Icons.arrow_back),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
        titleSpacing: 8,
        toolbarHeight: 88,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Home',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.0, color: Colors.black87),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'All Events',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.0, color: Colors.black87),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications (mock).')),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE3E7EE)),
                  ),
                  child: const Icon(Icons.notifications_none),
                ),
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: headerDividerColor),
        ),
      ),
      body: FutureBuilder<List<Object?>>(
        future: _screenDataFuture,
        builder: (context, snap) {
          final allRaw = (snap.data != null ? snap.data![0] as List<Event> : const <Event>[]);
          final profile = (snap.data != null ? snap.data![1] as UserProfile : null);
          final all = _prioritizeByPreferredSports(allRaw, profile?.preferredSports ?? const <String>{});
          final events = selected == null ? all : all.where((e) => _isSameDay(e.startAt, selected)).toList();

          return Column(
            children: [
              Material(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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
                            color: const Color(0xFFF0F4F3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE3E7EE)),
                          ),
                          child: Icon(
                            Icons.tune,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _WeekNavIconButton(
                        icon: Icons.chevron_left,
                        enabled: _visibleWeekPage > 0,
                        onTap: () => _setVisibleWeekPage(_visibleWeekPage - 1),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _WeekDateStrip(
                          weekStart: weekMonday,
                          weekEnd: weekEnd,
                          selectedDate: selected,
                          onSelectDay: (d) => setState(() => _selectedDate = d),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _WeekNavIconButton(
                        icon: Icons.chevron_right,
                        enabled: true,
                        onTap: () => _setVisibleWeekPage(_visibleWeekPage + 1),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: snap.connectionState != ConnectionState.done && all.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : events.isEmpty
                        ? _EmptyDayState(selectedDate: selected)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                            itemCount: events.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, idx) {
                              final e = events[idx];
                              return _AllEventCard(
                                event: e,
                                onOpen: () async {
                                  await Navigator.of(context).pushNamed(
                                    EventDetailScreen.routeName,
                                    arguments: EventDetailArgs(event: e, showRegisterButton: true),
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  setState(_refreshData);
                                },
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

class _WeekNavIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _WeekNavIconButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E7EE)),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.black87 : Colors.black26,
        ),
      ),
    );
  }
}

/// One calendar week (Mon–Sun) with a range label and day chips.
class _WeekDateStrip extends StatelessWidget {
  final DateTime weekStart;
  final DateTime weekEnd;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelectDay;
  const _WeekDateStrip({
    required this.weekStart,
    required this.weekEnd,
    required this.selectedDate,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final days = List<DateTime>.generate(
      7,
      (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _weekRangeLabel(weekStart, weekEnd),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.black.withValues(alpha: 0.38),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < days.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _DateChip(
                label: '${days[i].day}',
                sub: _weekdayShort(days[i]),
                selected: selectedDate != null && _isSameDay(days[i], selectedDate!),
                onTap: () => onSelectDay(days[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AllEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onOpen;
  const _AllEventCard({required this.event, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE3E7EE)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EventThumbnailHeader(event: event),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 34, height: 0.95),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${event.location} · ${_fmtTime(event.startAt)}',
                          style: TextStyle(color: Colors.black.withValues(alpha: 0.4), fontSize: 24, height: 0.95),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Open',
                      style: TextStyle(
                        color: cs.primary,
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
        width: 62,
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
            Text(sub, style: TextStyle(color: fg.withValues(alpha: 0.90), fontSize: 12)),
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

/// Monday of the week for page 0 = week that contains today; page 1 = next week, etc.
DateTime _mondayOfWeekPage(int page) {
  final today = _today();
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return monday.add(Duration(days: 7 * page));
}

bool _isDateInWeek(DateTime date, DateTime weekMonday) {
  final d = DateTime(date.year, date.month, date.day);
  final mon = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
  final days = d.difference(mon).inDays;
  return days >= 0 && days <= 6;
}

String _weekRangeLabel(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    return '${_monthShort(start.month)} ${start.day}–${end.day}';
  }
  if (start.year == end.year) {
    return '${_monthShort(start.month)} ${start.day} – ${_monthShort(end.month)} ${end.day}';
  }
  return '${_monthShort(start.month)} ${start.day}, ${start.year} – ${_monthShort(end.month)} ${end.day}';
}

String _weekdayShort(DateTime dt) {
  const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return w[(dt.weekday - 1).clamp(0, 6)];
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

List<Event> _prioritizeByPreferredSports(List<Event> events, Set<String> preferredSports) {
  if (preferredSports.isEmpty) {
    return events;
  }
  final preferred = preferredSports.map((e) => e.toLowerCase()).toSet();
  final sorted = [...events];
  sorted.sort((a, b) {
    final aFav = _sportMatchesPreferred(a.sport, preferred) ? 0 : 1;
    final bFav = _sportMatchesPreferred(b.sport, preferred) ? 0 : 1;
    if (aFav != bFav) return aFav.compareTo(bFav);
    return a.startAt.compareTo(b.startAt);
  });
  return sorted;
}

bool _sportMatchesPreferred(String sport, Set<String> preferred) {
  final s = sport.toLowerCase();
  for (final p in preferred) {
    if (s.contains(p) || p.contains(s)) {
      return true;
    }
  }
  return false;
}

