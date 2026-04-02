import 'package:flutter/material.dart';

import '../../../appwrite/appwrite_service.dart';
import '../../../data/event_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/event.dart';
import '../../../models/user_profile.dart';
import '../../../auth/current_user.dart';
import '../../../auth/session_persistence.dart';
import '../login_screen.dart';
import 'all_events_screen.dart';
import 'create_event_screen.dart';
import 'create_club_screen.dart';
import 'event_detail_screen.dart';
import '../profile/profile_screen.dart';
import 'activity_overview_screen.dart';
import 'clubs_screen.dart';
import 'calendar_screen.dart';
import 'notifications_screen.dart';
import '../../widgets/event_thumbnail_header.dart';

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
    // Tabs:
    // - index 0: Home
    // - index 1: Clubs (Circle)
    // - index 2: Create modal
    // - index 3: Calendar (placeholder)
    // - index 4: Profile (route)
    return Scaffold(
      body: _tabIndex == 0
          ? const _HomeBody()
          : _tabIndex == 1
              ? const ClubsScreen()
              : _tabIndex == 3
                  ? const CalendarScreen()
              : const _PlaceholderTab(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) {
                if (i == 2) {
                  _showCreateChoice(context);
                  return;
                }
                if (i == 4) {
                  Navigator.of(context).pushNamed(ProfileScreen.routeName);
                  return;
                }
                setState(() => _tabIndex = i);
              },
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

  void _showCreateChoice(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Create',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                ),
                title: const Text('Event', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Create a new event'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamed(CreateEventScreen.routeName).then((result) {
                    if (!mounted) {
                      return;
                    }
                    if (result == 'created' || result == 'updated' || result == true) {
                      setState(() => _tabIndex = 0);
                      final text = result == 'updated' ? 'Event updated.' : 'Event created.';
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(text)),
                        );
                      });
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.people_outline, color: Colors.grey.shade600),
                ),
                title: const Text('Club', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Create a new club'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamed(CreateClubScreen.routeName).then((created) {
                    if (created == true && mounted) {
                      setState(() => _tabIndex = 0);
                    }
                  });
                },
              ),
            ],
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
              onPressed: () async {
                try {
                  await AppwriteService.account.deleteSessions();
                } catch (_) {}
                await SessionPersistence.clear();
                CurrentUser.reset();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  LoginScreen.routeName,
                  (_) => false,
                );
              },
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
  late Future<UserProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = profileRepository().getMyProfile();
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
        automaticallyImplyLeading: false,
        toolbarHeight: 76,
        titleSpacing: 18,
        title: Row(
          children: [
            Expanded(
              child: FutureBuilder<UserProfile>(
                future: _profileFuture,
                builder: (context, snap) {
                  final username = (snap.data?.username.trim().isNotEmpty ?? false)
                      ? snap.data!.username.trim()
                      : 'User';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Good morning,',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        username,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                    ],
                  );
                },
              ),
            ),
            InkWell(
              onTap: () => Navigator.of(context).pushNamed(NotificationsScreen.routeName),
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
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE8EDEB)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Your Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(ActivityOverviewScreen.routeName);
                  },
                  child: const Text('Show all'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(height: 168, child: _ActivityList()),
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
            _HomeEventsSection(),
          ],
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object?>>(
      future: Future.wait<Object?>([
        eventRepository().listEvents(),
        profileRepository().getMyProfile(),
      ]),
      builder: (context, snap) {
        final events = (snap.data != null ? snap.data![0] as List<Event> : const <Event>[]);
        final profile = (snap.data != null ? snap.data![1] as UserProfile : null);
        final preferred = profile?.preferredSports ?? const <String>{};
        final prioritized = _prioritizeByPreferredSports(events, preferred);
        final now = DateTime.now();
        final joinedEvents = prioritized
            .where((e) {
              if (!(e.joinedByMe || (e.creatorId != null && e.creatorId == currentUserId))) {
                return false;
              }
              final endAt = e.startAt.add(e.duration);
              return endAt.isAfter(now);
            })
            .toList();

        if (snap.connectionState != ConnectionState.done && events.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          scrollDirection: Axis.horizontal,
          children: joinedEvents.isEmpty
              ? [
                  _ActivityCard(
                    title: 'No activity yet',
                    subtitle: 'Join or create an event to see it here',
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
        );
      },
    );
  }
}

class _HomeEventsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object?>>(
      future: Future.wait<Object?>([
        eventRepository().listEvents(),
        profileRepository().getMyProfile(),
      ]),
      builder: (context, snap) {
        final events = (snap.data != null ? snap.data![0] as List<Event> : const <Event>[]);
        final profile = (snap.data != null ? snap.data![1] as UserProfile : null);
        final preferred = profile?.preferredSports ?? const <String>{};
        final prioritized = _prioritizeByPreferredSports(events, preferred);
        final today = _today();
        final todaysEvents = prioritized.where((e) => _isSameDay(e.startAt, today)).toList();
        final upcomingEvents = prioritized
            .where((e) => e.startAt.isAfter(today))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final shownEvents = todaysEvents.isNotEmpty ? todaysEvents : upcomingEvents.take(3).toList();
        final eventsLabel = todaysEvents.isNotEmpty ? "Today's Events" : 'Upcoming Events';

        if (snap.connectionState != ConnectionState.done && events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Failed to load events. Showing local data if available.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
        );
      },
    );
  }
}

class _TodayEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onOpen;
  const _TodayEventCard({required this.event, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onOpen,
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
                      color: cs.primary.withValues(alpha: 0.12),
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
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E7EE)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 92,
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: cs.primary, size: 30),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

