import '../auth/current_user.dart';
import '../models/event.dart';
import 'club_member_repository.dart';
import 'club_repository.dart';
import 'event_registration_repository.dart';
import 'event_repository.dart';
import 'streak_repository.dart';

enum BadgeCategory {
  streak,
  eventsJoined,
  clubsJoined,
  clubsCreated,
  eventsCreated,
}

class BadgeDefinition {
  final String id;
  final BadgeCategory category;
  final String emoji;
  final String name;
  final String description;
  final int target;

  const BadgeDefinition({
    required this.id,
    required this.category,
    required this.emoji,
    required this.name,
    required this.description,
    required this.target,
  });
}

class BadgeProgress {
  final BadgeDefinition badge;
  final int current;

  const BadgeProgress({required this.badge, required this.current});

  bool get isUnlocked {
    return current >= badge.target;
  }

  double get progress {
    if (badge.target <= 0) {
      return 1;
    }
    final value = current / badge.target;
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }

  String get progressLabel {
    if (isUnlocked) {
      return 'Earned';
    }
    return '$current/${badge.target}';
  }
}

class AchievementSnapshot {
  final int currentStreak;
  final int bestStreak;
  final int joinedEventsCount;
  final bool hasStreakActivity;
  final int joinedClubsCount;
  final int createdClubsCount;
  final int createdEventsCount;
  final List<BadgeProgress> allBadges;

  const AchievementSnapshot({
    required this.currentStreak,
    required this.bestStreak,
    required this.joinedEventsCount,
    required this.hasStreakActivity,
    required this.joinedClubsCount,
    required this.createdClubsCount,
    required this.createdEventsCount,
    required this.allBadges,
  });

  List<BadgeProgress> get unlockedBadges {
    return allBadges.where((b) => b.isUnlocked).toList();
  }

  List<BadgeProgress> get inProgressBadges {
    return allBadges.where((b) => !b.isUnlocked && b.current > 0).toList();
  }

  List<BadgeProgress> get lockedBadges {
    return allBadges.where((b) => !b.isUnlocked && b.current <= 0).toList();
  }
}

class AchievementRepository {
  static const int _demoCurrentStreak = 5;

  static const List<BadgeDefinition> _definitions = <BadgeDefinition>[
    BadgeDefinition(
      id: 'streak_7',
      category: BadgeCategory.streak,
      emoji: '🔥',
      name: 'Heat Wave',
      description: 'Kept the fire going for 7 days straight.',
      target: 7,
    ),
    BadgeDefinition(
      id: 'streak_14',
      category: BadgeCategory.streak,
      emoji: '⚡',
      name: 'On Fire',
      description: 'Two weeks of unstoppable momentum.',
      target: 14,
    ),
    BadgeDefinition(
      id: 'streak_30',
      category: BadgeCategory.streak,
      emoji: '🔥',
      name: 'Inferno',
      description: 'A full month and you are a force of nature.',
      target: 30,
    ),
    BadgeDefinition(
      id: 'events_joined_1',
      category: BadgeCategory.eventsJoined,
      emoji: '🏟️',
      name: 'First Whistle',
      description: 'Showed up and played your first event.',
      target: 1,
    ),
    BadgeDefinition(
      id: 'events_joined_5',
      category: BadgeCategory.eventsJoined,
      emoji: '🎟️',
      name: 'Regular',
      description: 'You are becoming a familiar face.',
      target: 5,
    ),
    BadgeDefinition(
      id: 'events_joined_15',
      category: BadgeCategory.eventsJoined,
      emoji: '🎯',
      name: 'Seasoned Player',
      description: '15 events in and you know the drill.',
      target: 15,
    ),
    BadgeDefinition(
      id: 'events_joined_30',
      category: BadgeCategory.eventsJoined,
      emoji: '🏆',
      name: 'MVP',
      description: '30 events. Committed, consistent, unstoppable.',
      target: 30,
    ),
    BadgeDefinition(
      id: 'clubs_joined_3',
      category: BadgeCategory.clubsJoined,
      emoji: '⭐',
      name: 'Social Butterfly',
      description: 'Joined 3 different clubs.',
      target: 3,
    ),
    BadgeDefinition(
      id: 'clubs_created_1',
      category: BadgeCategory.clubsCreated,
      emoji: '🏅',
      name: 'Club Founder',
      description: 'Created your first club.',
      target: 1,
    ),
    BadgeDefinition(
      id: 'events_created_1',
      category: BadgeCategory.eventsCreated,
      emoji: '🗓️',
      name: 'Game Maker',
      description: 'Organised your first event.',
      target: 1,
    ),
    BadgeDefinition(
      id: 'events_created_5',
      category: BadgeCategory.eventsCreated,
      emoji: '📣',
      name: 'Go-to Organiser',
      description: 'People keep showing up to your events.',
      target: 5,
    ),
    BadgeDefinition(
      id: 'events_created_10',
      category: BadgeCategory.eventsCreated,
      emoji: '👑',
      name: 'League of Their Own',
      description: '10 events organised and you run the scene.',
      target: 10,
    ),
  ];

  Future<AchievementSnapshot> getMySnapshot() async {
    final userId = currentUserId.trim();
    return getSnapshotForUser(userId);
  }

  Future<AchievementSnapshot> getSnapshotForUser(String rawUserId) async {
    final userId = rawUserId.trim();
    if (userId.isEmpty || userId == 'current_user_placeholder') {
      final all = _definitions
          .map(
            (d) => BadgeProgress(
              badge: d,
              current: d.category == BadgeCategory.streak
                  ? _demoCurrentStreak
                  : 0,
            ),
          )
          .toList();
      return AchievementSnapshot(
        currentStreak: _demoCurrentStreak,
        bestStreak: _demoCurrentStreak,
        joinedEventsCount: 0,
        hasStreakActivity: false,
        joinedClubsCount: 0,
        createdClubsCount: 0,
        createdEventsCount: 0,
        allBadges: all,
      );
    }

    final joinedEventsFuture = eventRegistrationRepository()
        .listMyRegisteredEventIds(userId);
    final membershipsFuture = clubMemberRepository().listMembershipsForUser(
      userId: userId,
    );
    final eventsFuture = eventRepository().listEvents();
    final clubsFuture = clubRepository().listClubs();

    final joinedEventIds = await joinedEventsFuture;
    final memberships = await membershipsFuture;
    final events = await eventsFuture;
    final clubs = await clubsFuture;

    final joinedEventsCount = joinedEventIds.length;
    final now = DateTime.now();
    final hasActiveJoinedEvent = events.any((event) {
      if (!joinedEventIds.contains(event.id)) {
        return false;
      }
      final endAt = event.startAt.add(event.duration);
      return endAt.isAfter(now);
    });
    final hasActiveCreatedEvent = events.any((event) {
      if ((event.creatorId ?? '').trim() != userId) {
        return false;
      }
      final endAt = event.startAt.add(event.duration);
      return endAt.isAfter(now);
    });
    final hasChatActivity = false;
    final hasStreakActivity =
        hasActiveJoinedEvent || hasActiveCreatedEvent || hasChatActivity;
    final streakState = await streakRepository().refreshForUser(
      userId: userId,
      hasStreakActivity: hasStreakActivity,
    );
    final joinedClubsCount = memberships.map((m) => m.clubId).toSet().length;
    final createdClubsCount = clubs
        .where((c) => (c.creatorId ?? '').trim() == userId)
        .length;
    final createdEventsCount = _countCreatedEvents(events, userId);

    final all = _definitions.map((d) {
      return BadgeProgress(
        badge: d,
        current: _resolveCurrentValue(
          category: d.category,
          currentStreak: streakState.currentStreak,
          joinedEventsCount: joinedEventsCount,
          joinedClubsCount: joinedClubsCount,
          createdClubsCount: createdClubsCount,
          createdEventsCount: createdEventsCount,
        ),
      );
    }).toList();

    return AchievementSnapshot(
      currentStreak: streakState.currentStreak,
      bestStreak: streakState.bestStreak,
      joinedEventsCount: joinedEventsCount,
      hasStreakActivity: hasStreakActivity,
      joinedClubsCount: joinedClubsCount,
      createdClubsCount: createdClubsCount,
      createdEventsCount: createdEventsCount,
      allBadges: all,
    );
  }

  int _countCreatedEvents(List<Event> events, String userId) {
    return events.where((e) => (e.creatorId ?? '').trim() == userId).length;
  }

  int _resolveCurrentValue({
    required BadgeCategory category,
    required int currentStreak,
    required int joinedEventsCount,
    required int joinedClubsCount,
    required int createdClubsCount,
    required int createdEventsCount,
  }) {
    switch (category) {
      case BadgeCategory.streak:
        return currentStreak;
      case BadgeCategory.eventsJoined:
        return joinedEventsCount;
      case BadgeCategory.clubsJoined:
        return joinedClubsCount;
      case BadgeCategory.clubsCreated:
        return createdClubsCount;
      case BadgeCategory.eventsCreated:
        return createdEventsCount;
    }
  }
}

AchievementRepository achievementRepository() {
  return AchievementRepository();
}
