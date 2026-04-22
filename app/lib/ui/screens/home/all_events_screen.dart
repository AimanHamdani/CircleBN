import 'package:flutter/material.dart';

import '../../../data/event_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../data/sample_clubs.dart';
import '../../../models/event.dart';
import '../../../models/user_profile.dart';
import 'event_detail_screen.dart';
import 'notifications_screen.dart';
import '../../widgets/event_thumbnail_header.dart';
import '../../theme/app_theme.dart';

class AllEventsScreen extends StatefulWidget {
  static const routeName = '/events';
  const AllEventsScreen({super.key});

  @override
  State<AllEventsScreen> createState() => _AllEventsScreenState();
}

enum _AllEventsTimeBand { morning, afternoon, night }
enum _AllEventsAvailability { open, full }
enum _AllEventsFeeType { free, paid }

const List<String> _allEventsSkillOptions = <String>[
  'Any',
  'Beginner',
  'Novice',
  'Intermediate',
  'Advanced',
  'Pro/Master',
];

class _AllEventsScreenState extends State<AllEventsScreen> {
  DateTime? _selectedDate;

  /// 0 = calendar week that contains today (Mon–Sun). Increase to show future weeks.
  int _visibleWeekPage = 0;

  String? _filterSport;
  _AllEventsTimeBand? _filterTimeBand;
  String? _filterSkillLevel;
  _AllEventsAvailability? _filterAvailability;
  _AllEventsFeeType? _filterFeeType;

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

  Future<void> _showAllEventsFilterDialog(
    BuildContext context,
    List<String> sportOptions,
    List<String> skillOptions,
  ) async {
    final result = await showDialog<_AllEventsFilterDialogResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return _AllEventsFilterDialog(
          sportOptions: sportOptions,
          skillOptions: skillOptions,
          initialSport: _filterSport,
          initialTimeBand: _filterTimeBand,
          initialSkillLevel: _filterSkillLevel,
          initialAvailability: _filterAvailability,
          initialFeeType: _filterFeeType,
        );
      },
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.clearOnly) {
      setState(() {
        _filterSport = null;
        _filterTimeBand = null;
        _filterSkillLevel = null;
        _filterAvailability = null;
        _filterFeeType = null;
      });
      return;
    }
    setState(() {
      _filterSport = result.sport;
      _filterTimeBand = result.timeBand;
      _filterSkillLevel = result.skillLevel;
      _filterAvailability = result.availability;
      _filterFeeType = result.feeType;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDate;
    final weekMonday = _mondayOfWeekPage(_visibleWeekPage);
    final weekEnd = weekMonday.add(const Duration(days: 6));

    return Theme(
      data: AppTheme.eventFlowTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: FutureBuilder<List<Object?>>(
          future: _screenDataFuture,
          builder: (context, snap) {
            final allRaw = (snap.data != null
                ? snap.data![0] as List<Event>
                : const <Event>[]);
            final profile = (snap.data != null
                ? snap.data![1] as UserProfile
                : null);
            final prioritized = _prioritizeByPreferredSports(
              allRaw,
              profile?.preferredSports ?? const <String>{},
            );
            final all = prioritized.where(_isUpcomingOrOngoing).toList();
            // Sports from all loaded events so the menu stays useful even if the
            // visible week/day has no matches (DropdownButton/Picker still needs options).
            final sportOptions = [...SampleData.sports]..sort();
            final skillOptions = [..._allEventsSkillOptions];
            var events = selected == null
                ? all
                : all
                      .where((e) => _isSameDay(e.startAt.toLocal(), selected))
                      .toList();
            if (_filterSport != null) {
              final s = _filterSport!.toLowerCase();
              events = events.where((e) => e.sport.toLowerCase() == s).toList();
            }
            if (_filterTimeBand != null) {
              events = events
                  .where(
                    (e) => _eventMatchesTimeBand(
                      e.startAt.toLocal(),
                      _filterTimeBand!,
                    ),
                  )
                  .toList();
            }
            if (_filterSkillLevel != null) {
              final level = _filterSkillLevel!.toLowerCase();
              events = events
                  .where(
                    (e) =>
                        _normalizeSkillLevelLabel(e.skillLevel)
                            .toLowerCase() ==
                        level,
                  )
                  .toList();
            }
            if (_filterAvailability != null) {
              events = events.where((e) {
                final isFull = e.capacity > 0 && e.joined >= e.capacity;
                if (_filterAvailability == _AllEventsAvailability.full) {
                  return isFull;
                }
                return !isFull;
              }).toList();
            }
            if (_filterFeeType != null) {
              events = events.where((e) {
                final fee = e.entryFeeLabel.trim().toLowerCase();
                final isFree = fee == 'free' || fee == '\$0' || fee == '0';
                if (_filterFeeType == _AllEventsFeeType.free) {
                  return isFree;
                }
                return !isFree;
              }).toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AllEventsPurpleHeader(
                  canPop: Navigator.of(context).canPop(),
                  onBack: () => Navigator.of(context).maybePop(),
                  onOpenNotifications: () => Navigator.of(
                    context,
                  ).pushNamed(NotificationsScreen.routeName),
                ),
                Material(
                  color: Colors.white,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () async {
                                await _showAllEventsFilterDialog(
                                  context,
                                  sportOptions,
                                  skillOptions,
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.eventPurple,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.eventPurple.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Center(
                                      child: Icon(
                                        Icons.tune,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (_filterSport != null ||
                                        _filterTimeBand != null ||
                                        _filterSkillLevel != null ||
                                        _filterAvailability != null ||
                                        _filterFeeType != null)
                                      Positioned(
                                        right: 6,
                                        top: 6,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _WeekNavIconButton(
                              icon: Icons.chevron_left,
                              enabled: _visibleWeekPage > 0,
                              onTap: () =>
                                  _setVisibleWeekPage(_visibleWeekPage - 1),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: constraints.maxWidth > 640 ? 520 : 420,
                              child: _WeekDateStrip(
                                weekStart: weekMonday,
                                weekEnd: weekEnd,
                                selectedDate: selected,
                                onSelectDay: (d) =>
                                    setState(() => _selectedDate = d),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _WeekNavIconButton(
                              icon: Icons.chevron_right,
                              enabled: true,
                              onTap: () =>
                                  _setVisibleWeekPage(_visibleWeekPage + 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child:
                      snap.connectionState != ConnectionState.done &&
                          all.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : events.isEmpty
                      ? _EmptyDayState(selectedDate: selected)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                          itemCount: events.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, idx) {
                            final e = events[idx];
                            return _AllEventCard(
                              event: e,
                              onOpen: () async {
                                await Navigator.of(context).pushNamed(
                                  EventDetailScreen.routeName,
                                  arguments: EventDetailArgs(
                                    event: e,
                                    showRegisterButton: true,
                                  ),
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
      ),
    );
  }
}

class _AllEventsPurpleHeader extends StatelessWidget {
  final bool canPop;
  final VoidCallback onBack;
  final VoidCallback onOpenNotifications;

  const _AllEventsPurpleHeader({
    required this.canPop,
    required this.onBack,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(left: 12, right: 18, top: top + 6, bottom: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.eventPurpleDeep, AppTheme.eventPurple],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onBack,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Home',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All Events',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.98),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onOpenNotifications,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Icon(
                Icons.notifications_none,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
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
          color: AppTheme.eventPurpleLightBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.eventPurple.withValues(alpha: 0.22),
          ),
        ),
        child: Icon(icon, color: enabled ? Colors.black87 : Colors.black26),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _DateChip(
                  label: '${days[i].day}',
                  sub: _weekdayShort(days[i]),
                  selected:
                      selectedDate != null &&
                      _isSameDay(days[i], selectedDate!),
                  onTap: () => onSelectDay(days[i]),
                ),
              ],
            ],
          ),
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
    final isFull = event.capacity > 0 && event.joined >= event.capacity;
    final Color badgeBg;
    final Color badgeFg;
    final String badgeLabel;
    if (isFull) {
      badgeBg = const Color(0xFFFFF7ED);
      badgeFg = const Color(0xFFEA580C);
      badgeLabel = 'Full';
    } else {
      badgeBg = cs.primary.withValues(alpha: 0.14);
      badgeFg = cs.primary;
      badgeLabel = 'Open';
    }
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
            EventThumbnailHeader(event: event, height: 120),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                            fontSize: 17,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${event.location} · ${_fmtTime(event.startAt.toLocal())}',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.45),
                            fontSize: 12.5,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        color: badgeFg,
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
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _DateChip({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

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
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFE3E7EE),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w900),
            ),
            Text(
              sub,
              style: TextStyle(color: fg.withValues(alpha: 0.90), fontSize: 12),
            ),
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

/// Match Calendar screen behavior: include events until they have fully ended.
bool _isUpcomingOrOngoing(Event e) {
  final now = DateTime.now();
  final endAt = e.startAt.add(e.duration);
  return endAt.isAfter(now);
}

/// Local time-of-day bands for filter chips (Morning / Afternoon / Night).
bool _eventMatchesTimeBand(DateTime startLocal, _AllEventsTimeBand band) {
  final h = startLocal.hour;
  switch (band) {
    case _AllEventsTimeBand.morning:
      return h >= 5 && h < 12;
    case _AllEventsTimeBand.afternoon:
      return h >= 12 && h < 17;
    case _AllEventsTimeBand.night:
      return h >= 17 || h < 5;
  }
}

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
    final title = dt == null
        ? 'No events available'
        : 'No events available on this day';
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
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
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

List<Event> _prioritizeByPreferredSports(
  List<Event> events,
  Set<String> preferredSports,
) {
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

String _normalizeSkillLevelLabel(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text == '—') {
    return 'Any';
  }
  for (final option in _allEventsSkillOptions) {
    if (text.toLowerCase() == option.toLowerCase()) {
      return option;
    }
  }
  if (text.toLowerCase() == 'novice intermediate') {
    return 'Intermediate';
  }
  final matches = RegExp(r'\d+')
      .allMatches(text)
      .map((m) => int.tryParse(m.group(0)!))
      .whereType<int>()
      .toList();
  if (matches.isNotEmpty) {
    final min = matches.first;
    final max = matches.last;
    final score = ((min + max) / 2).round();
    if (score <= 2) return 'Beginner';
    if (score <= 4) return 'Novice';
    if (score <= 6) return 'Intermediate';
    if (score <= 8) return 'Advanced';
    return 'Pro/Master';
  }
  return text;
}

class _AllEventsFilterDialogResult {
  final String? sport;
  final _AllEventsTimeBand? timeBand;
  final String? skillLevel;
  final _AllEventsAvailability? availability;
  final _AllEventsFeeType? feeType;
  final bool clearOnly;

  const _AllEventsFilterDialogResult({
    this.sport,
    this.timeBand,
    this.skillLevel,
    this.availability,
    this.feeType,
    this.clearOnly = false,
  });
}

class _AllEventsFilterDialog extends StatefulWidget {
  final List<String> sportOptions;
  final List<String> skillOptions;
  final String? initialSport;
  final _AllEventsTimeBand? initialTimeBand;
  final String? initialSkillLevel;
  final _AllEventsAvailability? initialAvailability;
  final _AllEventsFeeType? initialFeeType;

  const _AllEventsFilterDialog({
    required this.sportOptions,
    required this.skillOptions,
    required this.initialSport,
    required this.initialTimeBand,
    required this.initialSkillLevel,
    required this.initialAvailability,
    required this.initialFeeType,
  });

  @override
  State<_AllEventsFilterDialog> createState() => _AllEventsFilterDialogState();
}

class _AllEventsFilterDialogState extends State<_AllEventsFilterDialog> {
  late String? _sport;
  late _AllEventsTimeBand? _timeBand;
  late String? _skillLevel;
  late _AllEventsAvailability? _availability;
  late _AllEventsFeeType? _feeType;

  static const _sheetBg = Color(0xFFF5F3FF);
  static const _chipSelectedBg = Color(0xFFEDE9FE);

  @override
  void initState() {
    super.initState();
    _timeBand = widget.initialTimeBand;
    _availability = widget.initialAvailability;
    _feeType = widget.initialFeeType;
    final s = widget.initialSport;
    _sport = (s != null && widget.sportOptions.contains(s)) ? s : null;
    final level = widget.initialSkillLevel;
    _skillLevel = (level != null && widget.skillOptions.contains(level))
        ? level
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Material(
        color: _sheetBg,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Filter',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Sport',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                ),
                child: PopupMenuButton<String?>(
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                  offset: const Offset(0, 40),
                  tooltip: 'Choose sport',
                  onSelected: (v) => setState(() => _sport = v),
                  itemBuilder: (context) => [
                    const PopupMenuItem<String?>(
                      value: null,
                      child: Text('All sports'),
                    ),
                    ...widget.sportOptions.map(
                      (s) => PopupMenuItem<String?>(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _sport ?? 'All sports',
                            style: const TextStyle(fontSize: 16, height: 1.2),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Skill level',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                ),
                child: PopupMenuButton<String?>(
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                  offset: const Offset(0, 40),
                  tooltip: 'Choose skill level',
                  onSelected: (v) => setState(() => _skillLevel = v),
                  itemBuilder: (context) => [
                    const PopupMenuItem<String?>(
                      value: null,
                      child: Text('All levels'),
                    ),
                    ...widget.skillOptions.map(
                      (s) => PopupMenuItem<String?>(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _skillLevel ?? 'All levels',
                            style: const TextStyle(fontSize: 16, height: 1.2),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Time',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FilterTimeChip(
                      label: 'Morning',
                      selected: _timeBand == _AllEventsTimeBand.morning,
                      selectedColor: _chipSelectedBg,
                      onTap: () => setState(() {
                        _timeBand = _timeBand == _AllEventsTimeBand.morning
                            ? null
                            : _AllEventsTimeBand.morning;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterTimeChip(
                      label: 'Afternoon',
                      selected: _timeBand == _AllEventsTimeBand.afternoon,
                      selectedColor: _chipSelectedBg,
                      onTap: () => setState(() {
                        _timeBand = _timeBand == _AllEventsTimeBand.afternoon
                            ? null
                            : _AllEventsTimeBand.afternoon;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterTimeChip(
                      label: 'Night',
                      selected: _timeBand == _AllEventsTimeBand.night,
                      selectedColor: _chipSelectedBg,
                      onTap: () => setState(() {
                        _timeBand = _timeBand == _AllEventsTimeBand.night
                            ? null
                            : _AllEventsTimeBand.night;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Availability',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FilterTimeChip(
                      label: 'Open',
                      selected: _availability == _AllEventsAvailability.open,
                      selectedColor: _chipSelectedBg,
                      onTap: () => setState(() {
                        _availability =
                            _availability == _AllEventsAvailability.open
                            ? null
                            : _AllEventsAvailability.open;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterTimeChip(
                      label: 'Full',
                      selected: _availability == _AllEventsAvailability.full,
                      selectedColor: _chipSelectedBg,
                      onTap: () => setState(() {
                        _availability =
                            _availability == _AllEventsAvailability.full
                            ? null
                            : _AllEventsAvailability.full;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Fee',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FilterTimeChip(
                      label: 'Free',
                      selected: _feeType == _AllEventsFeeType.free,
                      selectedColor: _chipSelectedBg,
                      onTap: () => setState(() {
                        _feeType = _feeType == _AllEventsFeeType.free
                            ? null
                            : _AllEventsFeeType.free;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterTimeChip(
                      label: 'Paid',
                      selected: _feeType == _AllEventsFeeType.paid,
                      selectedColor: _chipSelectedBg,
                      onTap: () => setState(() {
                        _feeType = _feeType == _AllEventsFeeType.paid
                            ? null
                            : _AllEventsFeeType.paid;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const _AllEventsFilterDialogResult(clearOnly: true)),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _AllEventsFilterDialogResult(
                          sport: _sport,
                          timeBand: _timeBand,
                          skillLevel: _skillLevel,
                          availability: _availability,
                          feeType: _feeType,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterTimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _FilterTimeChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : const Color(0xFFE3E7EE),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: Colors.black.withValues(alpha: selected ? 0.87 : 0.72),
            ),
          ),
        ),
      ),
    );
  }
}
