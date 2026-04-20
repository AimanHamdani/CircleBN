import '../models/user_profile.dart';
import 'achievement_repository.dart';
import 'profile_repository.dart';

/// Outcome of a single match (UI + history).
enum MatchOutcome { win, draw, loss }

/// Last matches on the Free stats page: result, sport, points only.
class RecentMatchEntry {
  final MatchOutcome outcome;
  final String sportName;
  final int pointsAwarded;

  const RecentMatchEntry({
    required this.outcome,
    required this.sportName,
    required this.pointsAwarded,
  });

  String get pointsLabel {
    if (pointsAwarded == 0) {
      return '0 pts';
    }
    if (pointsAwarded == 1) {
      return '+1 pt';
    }
    return '+$pointsAwarded pts';
  }
}

/// Aggregated numbers for the Free-tier stats UI (real profile + achievements).
class FreeTierStatsSnapshot {
  final int eventsCount;
  final int wins;
  final int draws;
  final int losses;
  final int currentStreak;
  final int bestStreak;
  final List<RecentMatchEntry> recentMatches;

  const FreeTierStatsSnapshot({
    required this.eventsCount,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.currentStreak,
    required this.bestStreak,
    required this.recentMatches,
  });

  int get totalResults => wins + draws + losses;
}

class FreeTierStatsRepository {
  /// Builds the Free stats view model from already-loaded profile + achievements.
  static FreeTierStatsSnapshot buildSnapshot({
    required UserProfile profile,
    required AchievementSnapshot achievements,
  }) {
    final recent = profile.matchHistory
        .take(5)
        .map(
          (r) => RecentMatchEntry(
            outcome: _outcomeFromString(r.outcome),
            sportName: r.sport.trim().isEmpty ? 'Sport' : r.sport.trim(),
            pointsAwarded: r.pointsAwarded,
          ),
        )
        .toList();

    return FreeTierStatsSnapshot(
      eventsCount: achievements.joinedEventsCount,
      wins: profile.matchWins,
      draws: profile.matchDraws,
      losses: profile.matchLosses,
      currentStreak: achievements.currentStreak,
      bestStreak: achievements.bestStreak,
      recentMatches: recent,
    );
  }

  static MatchOutcome _outcomeFromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'win':
        return MatchOutcome.win;
      case 'draw':
        return MatchOutcome.draw;
      default:
        return MatchOutcome.loss;
    }
  }

  Future<FreeTierStatsSnapshot> getMySnapshot() async {
    final results = await Future.wait<Object?>([
      profileRepository().getMyProfile(),
      achievementRepository().getMySnapshot(),
    ]);
    final profile = results[0] as UserProfile;
    final achievements = results[1] as AchievementSnapshot;
    return buildSnapshot(profile: profile, achievements: achievements);
  }
}

FreeTierStatsRepository freeTierStatsRepository() {
  return FreeTierStatsRepository();
}
