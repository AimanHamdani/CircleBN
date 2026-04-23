import 'package:flutter/material.dart';

import '../../../appwrite/appwrite_service.dart';
import '../../../data/achievement_repository.dart';
import '../../../data/club_repository.dart';
import '../../../data/event_repository.dart';
import '../../../data/membership_repository.dart';
import '../../../data/notification_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/event.dart';
import '../../../models/user_profile.dart';
import '../../../auth/current_user.dart';
import '../../../auth/session_persistence.dart';
import '../login_screen.dart';
import '../../../data/event_invite_repository.dart';
import 'all_events_screen.dart';
import 'create_event_screen.dart';
import 'create_club_screen.dart';
import 'event_detail_screen.dart';
import '../profile/profile_screen.dart';
import 'activity_overview_screen.dart';
import 'clubs_screen.dart';
import 'calendar_screen.dart';
import 'notifications_screen.dart';
import 'redeem_points_screen.dart';
import 'streak_screen.dart';
import 'private_events_screen.dart';
import '../../app_route_observer.dart';
import '../../widgets/event_thumbnail_header.dart';
import '../../theme/app_theme.dart';

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
    final navAccent = _navAccentForTab(_tabIndex);
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
        child: SizedBox(
          height: 78,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFD7E7E2), width: 1),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final centerGap = (constraints.maxWidth * 0.16).clamp(
                      42.0,
                      64.0,
                    );
                    return Row(
                      children: [
                        Expanded(
                          child: _BottomNavItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home,
                            label: 'Home',
                            selected: _tabIndex == 0,
                            activeColor: navAccent,
                            onTap: () => setState(() => _tabIndex = 0),
                          ),
                        ),
                        Expanded(
                          child: _BottomNavItem(
                            icon: Icons.people_outline,
                            activeIcon: Icons.people,
                            label: 'Circle',
                            selected: _tabIndex == 1,
                            activeColor: navAccent,
                            onTap: () => setState(() => _tabIndex = 1),
                          ),
                        ),
                        SizedBox(width: centerGap),
                        Expanded(
                          child: _BottomNavItem(
                            icon: Icons.calendar_month_outlined,
                            activeIcon: Icons.calendar_month,
                            label: 'Calendar',
                            selected: _tabIndex == 3,
                            activeColor: navAccent,
                            onTap: () => setState(() => _tabIndex = 3),
                          ),
                        ),
                        Expanded(
                          child: _BottomNavItem(
                            icon: Icons.person_outline,
                            activeIcon: Icons.person,
                            label: 'Profile',
                            selected: false,
                            activeColor: navAccent,
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(ProfileScreen.routeName),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: -8,
                child: Center(
                  child: InkWell(
                    onTap: () => _showCreateChoice(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: navAccent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: navAccent.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 26,
                      ),
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

  Color _navAccentForTab(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return const Color(0xFF1FB8AD); // Clubs/Circle
      case 3:
        return const Color(0xFFF6A300); // Calendar
      default:
        return AppTheme.eventPurple; // Home
    }
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
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.event,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text(
                  'Event',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Create a new event'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(
                    context,
                  ).pushNamed(CreateEventScreen.routeName).then((result) {
                    if (!mounted) {
                      return;
                    }
                    if (result == 'created' ||
                        result == 'updated' ||
                        result == true) {
                      setState(() => _tabIndex = 0);
                      final text = result == 'updated'
                          ? 'Event updated.'
                          : 'Event created.';
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(text)));
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
                  child: Icon(
                    Icons.people_outline,
                    color: Colors.grey.shade600,
                  ),
                ),
                title: const Text(
                  'Club',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Create a new club'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(
                    context,
                  ).pushNamed(CreateClubScreen.routeName).then((created) {
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

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : const Color(0xFF8D9692);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? activeIcon : icon, size: 20, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
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
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(LoginScreen.routeName, (_) => false);
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

class _HomeBodyState extends State<_HomeBody> with RouteAware {
  late Future<UserProfile> _profileFuture;
  late Future<int> _unreadNotificationsFuture;
  late Future<MembershipStatus> _membershipFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = profileRepository().getMyProfile();
    _unreadNotificationsFuture = _loadUnreadNotificationsCount();
    _membershipFuture = membershipRepository().getStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (!mounted) return;
    setState(() {
      _membershipFuture = membershipRepository().getStatus();
    });
  }

  Future<int> _loadUnreadNotificationsCount() async {
    final items = await notificationRepository().listForUser(currentUserId);
    return items.where((n) => !n.isRead).length;
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).pushNamed(NotificationsScreen.routeName);
    if (!mounted) {
      return;
    }
    setState(() {
      _unreadNotificationsFuture = _loadUnreadNotificationsCount();
    });
  }

  String _displayName(UserProfile? profile) {
    if (profile == null) {
      return 'there';
    }
    final realName = profile.realName.trim();
    if (realName.isNotEmpty) {
      return realName;
    }
    final username = profile.username.trim();
    if (username.isNotEmpty) {
      return username;
    }
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.eventFlowTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: MediaQuery.paddingOf(context).top + 8,
                bottom: 20,
              ),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Good morning,',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<UserProfile>(
                          future: _profileFuture,
                          builder: (context, snapshot) {
                            final name = _displayName(snapshot.data);
                            return Text(
                              '$name 👋',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.05,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(StreakScreen.routeName),
                        borderRadius: BorderRadius.circular(14),
                        child: FutureBuilder<AchievementSnapshot>(
                          future: achievementRepository().getMySnapshot(),
                          builder: (context, snapshot) {
                            final streak = snapshot.data?.currentStreak ?? 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    color: Colors.white.withValues(alpha: 0.95),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  _AnimatedCounterText(
                                    value: streak,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.95,
                                      ),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(RedeemPointsScreen.routeName),
                        borderRadius: BorderRadius.circular(14),
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
                            Icons.card_giftcard,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _openNotifications,
                        borderRadius: BorderRadius.circular(14),
                        child: FutureBuilder<int>(
                          future: _unreadNotificationsFuture,
                          builder: (context, snapshot) {
                            final unreadCount = snapshot.data ?? 0;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
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
                                    Icons.notifications_none,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF4D4F),
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        unreadCount > 99
                                            ? '99+'
                                            : unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            FutureBuilder<MembershipStatus>(
              future: _membershipFuture,
              builder: (context, membershipSnap) {
                if (membershipSnap.data?.isPremium == true) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 76,
                      width: double.infinity,
                      color: const Color(0xFFF1F3F5),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.campaign_outlined,
                        size: 28,
                        color: Colors.black.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Your Activity',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushNamed(ActivityOverviewScreen.routeName);
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
                          child: Text(
                            'All Events',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed(AllEventsScreen.routeName),
                          child: const Text('Show all'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed(PrivateEventsScreen.routeName),
                          child: const Text('Private'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _PrivateInvitesSection(),
                    const SizedBox(height: 10),
                    _HomeEventsSection(),
                  ],
                ),
              ),
            ),
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
        final events = (snap.data != null
            ? snap.data![0] as List<Event>
            : const <Event>[]);
        final profile = (snap.data != null
            ? snap.data![1] as UserProfile
            : null);
        final preferred = profile?.preferredSports ?? const <String>{};
        final prioritized = _prioritizeByPreferredSports(events, preferred);
        final now = DateTime.now();
        final joinedEvents = prioritized.where((e) {
          if (!(e.joinedByMe ||
              (e.creatorId != null && e.creatorId == currentUserId))) {
            return false;
          }
          final endAt = e.startAt.add(e.duration);
          return endAt.isAfter(now);
        }).toList();

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
                  ],
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
        final events = (snap.data != null
            ? snap.data![0] as List<Event>
            : const <Event>[]);
        final profile = (snap.data != null
            ? snap.data![1] as UserProfile
            : null);
        final preferred = profile?.preferredSports ?? const <String>{};
        final prioritized = _prioritizeByPreferredSports(events, preferred);
        final now = DateTime.now();
        final activeEvents = prioritized.where(_isUpcomingOrOngoing).toList();
        final today = _today();
        final todaysEvents = activeEvents
            .where((e) => _isSameDay(e.startAt.toLocal(), today))
            .toList();
        final upcomingEvents =
            activeEvents.where((e) => e.startAt.isAfter(now)).toList()
              ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final shownEvents = todaysEvents.isNotEmpty
            ? todaysEvents
            : upcomingEvents.take(3).toList();
        final eventsLabel = todaysEvents.isNotEmpty
            ? "Today's Events"
            : 'Upcoming Events';

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
                        arguments: EventDetailArgs(
                          event: shownEvents[i],
                          showRegisterButton: true,
                        ),
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

class _PrivateInvitesSection extends StatefulWidget {
  @override
  State<_PrivateInvitesSection> createState() => _PrivateInvitesSectionState();
}

class _PrivateInvitesSectionState extends State<_PrivateInvitesSection> {
  late Future<_PrivateInvitesPayload> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadInvites();
  }

  Future<_PrivateInvitesPayload> _loadInvites() async {
    final events = await eventRepository().listEvents();
    final clubs = await clubRepository().listClubs();
    final clubNameById = <String, String>{
      for (final club in clubs) club.id: club.name,
    };
    final invites = events.where((e) {
      if (!_isUpcomingOrOngoing(e)) {
        return false;
      }
      if (!eventInviteRepository().isPrivate(e)) {
        return false;
      }
      final invited = eventInviteRepository().isInvited(
        e,
        userId: currentUserId,
      );
      if (!invited || e.joinedByMe) {
        return false;
      }
      final rejected = e.rejectedInviteUserIds.contains(currentUserId);
      return !rejected;
    }).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));
    return _PrivateInvitesPayload(invites: invites, clubNameById: clubNameById);
  }

  Future<void> _acceptInvite(Event event) async {
    try {
      await eventInviteRepository().acceptInvite(
        event: event,
        userId: currentUserId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _future = _loadInvites();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Joined ${event.title}.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to accept invite.')));
    }
  }

  Future<void> _rejectInvite(Event event) async {
    try {
      await eventInviteRepository().rejectInvite(
        event: event,
        userId: currentUserId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _future = _loadInvites();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite rejected.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to reject invite.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PrivateInvitesPayload>(
      future: _future,
      builder: (context, snapshot) {
        final payload =
            snapshot.data ??
            const _PrivateInvitesPayload(
              invites: <Event>[],
              clubNameById: <String, String>{},
            );
        final invites = payload.invites;
        if (invites.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Private Invites',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < invites.length; i++) ...[
              _InviteCard(
                event: invites[i],
                clubName: payload.clubNameById[invites[i].clubId ?? ''],
                onOpen: () {
                  Navigator.of(context).pushNamed(
                    EventDetailScreen.routeName,
                    arguments: EventDetailArgs(
                      event: invites[i],
                      showRegisterButton: true,
                    ),
                  );
                },
                onAccept: () => _acceptInvite(invites[i]),
                onReject: () => _rejectInvite(invites[i]),
              ),
              if (i != invites.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _PrivateInvitesPayload {
  final List<Event> invites;
  final Map<String, String> clubNameById;

  const _PrivateInvitesPayload({
    required this.invites,
    required this.clubNameById,
  });
}

class _InviteCard extends StatelessWidget {
  final Event event;
  final String? clubName;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InviteCard({
    required this.event,
    required this.clubName,
    required this.onOpen,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final clubLabel = (clubName ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7CBFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (clubLabel.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE7E9FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Invited from club: $clubLabel',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B4AE0),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            event.title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${event.location} • ${_fmtTime(event.startAt)}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onOpen, child: const Text('Details')),
            ],
          ),
        ],
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
    final cs = Theme.of(context).colorScheme;
    final isFull = event.capacity > 0 && event.joined >= event.capacity;
    final joinedMe = event.joinedByMe;
    final Color badgeBg;
    final Color badgeFg;
    final String badgeLabel;
    if (joinedMe) {
      badgeBg = AppTheme.eventPurpleLightBg;
      badgeFg = AppTheme.eventPurple;
      badgeLabel = 'Joined';
    } else if (isFull) {
      badgeBg = const Color(0xFFFFF7ED);
      badgeFg = const Color(0xFFEA580C);
      badgeLabel = 'Full';
    } else {
      badgeBg = cs.primary.withValues(alpha: 0.12);
      badgeFg = cs.primary;
      badgeLabel = 'Open';
    }
    return _PressableCard(
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
                        Text(
                          event.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
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
                      horizontal: 12,
                      vertical: 8,
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
                Text(
                  'No events today',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  'Tap “Show all” to browse upcoming events.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
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

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isUpcomingOrOngoing(Event event) {
  final endAt = event.startAt.add(event.duration);
  return endAt.isAfter(DateTime.now());
}

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
    return _PressableCard(
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
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

class _PressableCard extends StatefulWidget {
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final Widget child;

  const _PressableCard({
    required this.onTap,
    required this.borderRadius,
    required this.child,
  });

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: widget.borderRadius,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _AnimatedCounterText extends StatelessWidget {
  final int value;
  final TextStyle style;

  const _AnimatedCounterText({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return Text(animated.round().toString(), style: style);
      },
    );
  }
}
