import 'package:flutter/material.dart';

import '../../../data/sample_events.dart';
import '../../../models/event.dart';
import '../login_screen.dart';
import 'all_events_screen.dart';
import 'event_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    // For now: only Home tab is functional (no db/pages yet).
    return Scaffold(
      body: _tabIndex == 0 ? const _HomeBody() : const _PlaceholderTab(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Circle'),
                NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: ''),
                NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This page is not available yet.'),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                LoginScreen.routeName,
                (_) => false,
              ),
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  @override
  Widget build(BuildContext context) {
    final events = SampleEvents.all;
    final joinedEvents = events.where((e) => e.joinedByMe).toList();
    final today = _today();
    final todaysEvents = events.where((e) => _isSameDay(e.startAt, today)).toList();
    final upcomingEvents = events
        .where((e) => e.startAt.isAfter(today))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final shownEvents = todaysEvents.isNotEmpty ? todaysEvents : upcomingEvents.take(3).toList();
    final eventsLabel = todaysEvents.isNotEmpty ? "Today's Events" : 'Upcoming Events';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Good morning,', style: TextStyle(color: Colors.black54)),
                      SizedBox(height: 2),
                      Text('User', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                InkWell(
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE3E7EE)),
                    ),
                    child: const Icon(Icons.notifications_none),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text('Your Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Your Activity page is not available yet.')),
                    );
                  },
                  child: const Text('Show all'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: joinedEvents.isEmpty
                    ? [
                        _ActivityCard(
                          title: 'No joined events yet',
                          subtitle: 'Join an event to see it here',
                          icon: Icons.event_available,
                          onTap: () {},
                        ),
                      ]
                    : [
                        for (int i = 0; i < joinedEvents.length; i++) ...[
                          _ActivityCard(
                            title: joinedEvents[i].title,
                            subtitle: _activitySubtitle(joinedEvents[i]),
                            icon: _sportIcon(joinedEvents[i].sport),
                            onTap: () => Navigator.of(context).pushNamed(
                              EventDetailScreen.routeName,
                              arguments: EventDetailArgs(
                                event: joinedEvents[i],
                                showRegisterButton: false,
                              ),
                            ),
                          ),
                          if (i != joinedEvents.length - 1) const SizedBox(width: 12),
                        ]
                      ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text('All Events', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed(AllEventsScreen.routeName),
                  child: const Text('Show all'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              eventsLabel,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (shownEvents.isEmpty)
              _TodayEmptyCard(date: today)
            else
              Column(
                children: [
                  for (int i = 0; i < shownEvents.length; i++) ...[
                    _TodayEventCard(
                      event: shownEvents[i],
                      onOpen: () => Navigator.of(context).pushNamed(
                        EventDetailScreen.routeName,
                        arguments: EventDetailArgs(event: shownEvents[i], showRegisterButton: true),
                      ),
                    ),
                    if (i != shownEvents.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TodayEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onOpen;
  const _TodayEventCard({required this.event, required this.onOpen});

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_sportIcon(event.sport), color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
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
              const SizedBox(width: 10),
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
      ),
    );
  }
}

class _TodayEmptyCard extends StatelessWidget {
  final DateTime date;
  const _TodayEmptyCard({required this.date});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.event_busy, color: c.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No events today', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text('Tap “Show all” to browse upcoming events.', style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class _ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E7EE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
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

String _activitySubtitle(Event e) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final wd = weekdays[(e.startAt.weekday - 1).clamp(0, 6)];
  return '$wd • ${_fmtTime(e.startAt)}';
}

IconData _sportIcon(String sport) {
  final s = sport.toLowerCase();
  if (s.contains('badminton')) return Icons.sports_tennis;
  if (s.contains('volley')) return Icons.sports_volleyball;
  if (s.contains('football')) return Icons.sports_soccer;
  if (s.contains('basketball')) return Icons.sports_basketball;
  if (s.contains('swim')) return Icons.pool;
  if (s.contains('cycle')) return Icons.directions_bike;
  if (s.contains('run') || s.contains('jog')) return Icons.directions_run;
  if (s.contains('table')) return Icons.sports_tennis;
  if (s.contains('tennis')) return Icons.sports_tennis;
  return Icons.sports;
}

