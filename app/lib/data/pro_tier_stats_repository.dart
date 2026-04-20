import '../models/user_profile.dart';
import 'achievement_repository.dart';
import 'free_tier_stats_repository.dart' show MatchOutcome;
import 'profile_repository.dart';

/// Aggregated Pro stats (optionally filtered to one sport using [matchHistory] only).
class ProStatsSnapshot {
  final int eventsJoinedCount;
  final double? winRatePercent;
  final double? avgPointsPerMatch;
  final int currentStreak;
  final int bestStreak;
  final int wins;
  final int draws;
  final int losses;
  final int totalPointsFromMatches;
  /// Oldest → newest (max 10) for form tiles left-to-right.
  final List<MatchOutcome> formLast10Chronological;
  final String formSummaryLine;
  final List<ProfileMatchRecord> recentMatchesForCard;
  final List<ProfileMatchRecord> fullMatchHistory;
  final String? sportFilter;

  const ProStatsSnapshot({
    required this.eventsJoinedCount,
    required this.winRatePercent,
    required this.avgPointsPerMatch,
    required this.currentStreak,
    required this.bestStreak,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.totalPointsFromMatches,
    required this.formLast10Chronological,
    required this.formSummaryLine,
    required this.recentMatchesForCard,
    required this.fullMatchHistory,
    required this.sportFilter,
  });

  int get totalResults => wins + draws + losses;
}

class ProTierStatsRepository {
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

  static bool _sportMatches(ProfileMatchRecord r, String sportKey) {
    final a = r.sport.trim().toLowerCase();
    final b = sportKey.trim().toLowerCase();
    if (a.isEmpty || b.isEmpty) {
      return false;
    }
    return a == b || a.contains(b) || b.contains(a);
  }

  static List<ProfileMatchRecord> _filterHistory(
    List<ProfileMatchRecord> all,
    String? sportFilter,
  ) {
    if (sportFilter == null || sportFilter.trim().isEmpty) {
      return List<ProfileMatchRecord>.from(all);
    }
    return all.where((r) => _sportMatches(r, sportFilter)).toList();
  }

  static ({int w, int d, int l}) _countOutcomes(List<ProfileMatchRecord> hist) {
    var w = 0;
    var d = 0;
    var l = 0;
    for (final r in hist) {
      switch (r.outcome.toLowerCase()) {
        case 'win':
          w++;
          break;
        case 'draw':
          d++;
          break;
        default:
          l++;
          break;
      }
    }
    return (w: w, d: d, l: l);
  }

  static String _formatFormSummary(List<MatchOutcome> chronological) {
    if (chronological.isEmpty) {
      return '';
    }
    var tailWins = 0;
    for (var i = chronological.length - 1; i >= 0; i--) {
      if (chronological[i] == MatchOutcome.win) {
        tailWins++;
      } else {
        break;
      }
    }
    final winsInLast6 = chronological.length >= 6
        ? chronological
              .sublist(chronological.length - 6)
              .where((e) => e == MatchOutcome.win)
              .length
        : chronological.where((e) => e == MatchOutcome.win).length;
    final tone = tailWins >= 3
        ? 'strong form ↑'
        : tailWins >= 1
        ? 'building momentum'
        : 'stay consistent';
    return 'Current: W$tailWins — $tone (W$winsInLast6 in last ${chronological.length.clamp(1, 6)})';
  }

  static ProStatsSnapshot buildSnapshot({
    required UserProfile profile,
    required AchievementSnapshot achievements,
    String? sportFilter,
  }) {
    final trimmedFilter = sportFilter?.trim();
    final filterActive =
        trimmedFilter != null && trimmedFilter.isNotEmpty && trimmedFilter != 'All sports';

    final histAll = profile.matchHistory;
    final hist = _filterHistory(histAll, filterActive ? trimmedFilter : null);

    final counts = filterActive
        ? _countOutcomes(hist)
        : (
            w: profile.matchWins,
            d: profile.matchDraws,
            l: profile.matchLosses,
          );
    final w = counts.w;
    final d = counts.d;
    final l = counts.l;
    final total = w + d + l;

    final winRate = total > 0 ? (w * 100.0) / total : null;
    final ptsSum = hist.fold<int>(0, (s, r) => s + r.pointsAwarded);
    final avgPts = hist.isNotEmpty ? ptsSum / hist.length : null;

    final eventsJoined = filterActive
        ? hist.map((e) => e.eventId).toSet().length
        : achievements.joinedEventsCount;

    // Newest-first in profile → take last 10 for recency, reverse to chronological for tiles.
    final last10Newest = hist.take(10).toList();
    final chrono = last10Newest.reversed
        .map((r) => _outcomeFromString(r.outcome))
        .toList();
    final formLine = _formatFormSummary(chrono);

    final recent = hist.take(10).toList();

    return ProStatsSnapshot(
      eventsJoinedCount: eventsJoined,
      winRatePercent: winRate,
      avgPointsPerMatch: avgPts,
      currentStreak: achievements.currentStreak,
      bestStreak: achievements.bestStreak,
      wins: w,
      draws: d,
      losses: l,
      totalPointsFromMatches: ptsSum,
      formLast10Chronological: chrono,
      formSummaryLine: formLine,
      recentMatchesForCard: recent,
      fullMatchHistory: hist,
      sportFilter: filterActive ? trimmedFilter : null,
    );
  }

  Future<ProStatsSnapshot> getMySnapshot({String? sportFilter}) async {
    final rows = await Future.wait<Object?>([
      profileRepository().getMyProfile(),
      achievementRepository().getMySnapshot(),
    ]);
    final profile = rows[0] as UserProfile;
    final ach = rows[1] as AchievementSnapshot;
    return buildSnapshot(
      profile: profile,
      achievements: ach,
      sportFilter: sportFilter,
    );
  }
}

ProTierStatsRepository proTierStatsRepository() {
  return ProTierStatsRepository();
}
