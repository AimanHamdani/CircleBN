import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../data/achievement_repository.dart';
import '../../../data/free_tier_stats_repository.dart';
import '../../../data/membership_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../data/sample_clubs.dart';
import '../../../models/user_profile.dart';
import 'membership_screen.dart';
import 'pro_stats_screen.dart';

/// Stats hub for Free accounts (non‑Pro). Pro users are redirected to a short message.
class FreeStatsScreen extends StatefulWidget {
  static const routeName = '/profile/free-stats';

  const FreeStatsScreen({super.key});

  @override
  State<FreeStatsScreen> createState() => _FreeStatsScreenState();
}

class _FreeStatsScreenState extends State<FreeStatsScreen> {
  late Future<List<Object?>> _pageFuture;

  @override
  void initState() {
    super.initState();
    _pageFuture = _load();
  }

  Future<List<Object?>> _load() async {
    final rows = await Future.wait<Object?>([
      profileRepository().getMyProfile(),
      achievementRepository().getMySnapshot(),
      membershipRepository().getStatus(),
    ]);
    final profile = rows[0] as UserProfile;
    final achievements = rows[1] as AchievementSnapshot;
    final membership = rows[2] as MembershipStatus;
    final stats = FreeTierStatsRepository.buildSnapshot(
      profile: profile,
      achievements: achievements,
    );
    return [profile, stats, membership];
  }

  void _reload() {
    setState(() {
      _pageFuture = _load();
    });
  }

  int _pointsNeededForTier(int tierLevel) {
    const thresholds = <int>[10, 15, 20, 25, 35, 45, 60, 80, 100];
    if (tierLevel >= 10) {
      return thresholds.last;
    }
    return thresholds[(tierLevel - 1).clamp(0, thresholds.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F7),
      body: FutureBuilder<List<Object?>>(
        future: _pageFuture,
        builder: (context, snap) {
          if (snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snap.data![0] as UserProfile;
          final stats = snap.data![1] as FreeTierStatsSnapshot;
          final membership = snap.data![2] as MembershipStatus;

          if (membership.isPremium) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pushReplacementNamed(
                ProStatsHubScreen.routeName,
              );
            });
            return const Center(child: CircularProgressIndicator());
          }

          final realName = profile.realName.trim().isNotEmpty
              ? profile.realName.trim()
              : 'Player';
          final memberSince = _memberSinceLabel();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _StatsHeader(
                  realName: realName,
                  memberSince: memberSince,
                  avatarFileId: profile.avatarFileId,
                  stats: stats,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _MatchRecordCard(stats: stats),
                    const SizedBox(height: 12),
                    _StreakCard(stats: stats),
                    const SizedBox(height: 12),
                    _SkillLevelsCard(
                      profile: profile,
                      pointsNeededForTier: _pointsNeededForTier,
                    ),
                    const SizedBox(height: 12),
                    _RecentMatchesCard(stats: stats),
                    const SizedBox(height: 12),
                    _LockedDetailedStatsSection(
                      onUpgrade: () async {
                        await Navigator.of(context).pushNamed(
                          MembershipScreen.routeName,
                        );
                        if (context.mounted) {
                          _reload();
                        }
                      },
                    ),
                    const SizedBox(height: 28),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _memberSinceLabel() {
    const months = <String>[
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
    final now = DateTime.now();
    return 'Member since ${months[now.month - 1]} ${now.year}';
  }
}

class _StatsHeader extends StatelessWidget {
  final String realName;
  final String memberSince;
  final String? avatarFileId;
  final FreeTierStatsSnapshot stats;

  const _StatsHeader({
    required this.realName,
    required this.memberSince,
    required this.avatarFileId,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4361EE), Color(0xFF7B2CBF)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatsAvatar(fileId: avatarFileId),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      realName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      memberSince,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                child: const Text(
                  'Free',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _QuickStatPill(
                  value: '${stats.eventsCount}',
                  label: 'Events',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickStatPill(
                  value: '${stats.wins}',
                  label: 'Wins',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickStatPill(
                  value: '🔥 ${stats.currentStreak}',
                  label: 'Streak',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStatPill extends StatelessWidget {
  final String value;
  final String label;

  const _QuickStatPill({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchRecordCard extends StatelessWidget {
  final FreeTierStatsSnapshot stats;

  const _MatchRecordCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.totalResults;

    return _SectionCard(
      title: 'MATCH RECORD — ALL SPORTS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: total <= 0
                  ? const Row(
                      children: [
                        Expanded(
                          child: ColoredBox(color: Color(0xFFB8DCC8)),
                        ),
                        Expanded(
                          child: ColoredBox(color: Color(0xFFF5DEB0)),
                        ),
                        Expanded(
                          child: ColoredBox(color: Color(0xFFF0B4B4)),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        if (stats.wins > 0)
                          Expanded(
                            flex: stats.wins,
                            child: const ColoredBox(
                              color: Color(0xFF22A06B),
                            ),
                          ),
                        if (stats.draws > 0)
                          Expanded(
                            flex: stats.draws,
                            child: const ColoredBox(
                              color: Color(0xFFF5A524),
                            ),
                          ),
                        if (stats.losses > 0)
                          Expanded(
                            flex: stats.losses,
                            child: const ColoredBox(
                              color: Color(0xFFE85D5D),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ResultColumn(
                  value: '${stats.wins}',
                  caption: 'Wins',
                  valueColor: const Color(0xFF22A06B),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: const Color(0xFFE1E5E8),
              ),
              Expanded(
                child: _ResultColumn(
                  value: '${stats.draws}',
                  caption: 'Draws',
                  valueColor: const Color(0xFFE89400),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: const Color(0xFFE1E5E8),
              ),
              Expanded(
                child: _ResultColumn(
                  value: '${stats.losses}',
                  caption: 'Losses',
                  valueColor: const Color(0xFFE85D5D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultColumn extends StatelessWidget {
  final String value;
  final String caption;
  final Color valueColor;

  const _ResultColumn({
    required this.value,
    required this.caption,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.black.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  final FreeTierStatsSnapshot stats;

  const _StreakCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'STREAK',
      child: Column(
        children: [
          _StreakRow(
            left: 'Current streak',
            right: '🔥 ${stats.currentStreak} events',
            rightColor: const Color(0xFFE89400),
          ),
          const Divider(height: 22),
          _StreakRow(
            left: 'Best ever streak',
            right: '⚡ ${stats.bestStreak} events',
            rightColor: const Color(0xFF7B2CBF),
          ),
        ],
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  final String left;
  final String right;
  final Color rightColor;

  const _StreakRow({
    required this.left,
    required this.right,
    required this.rightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF3D4F5F),
            ),
          ),
        ),
        Text(
          right,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: rightColor,
          ),
        ),
      ],
    );
  }
}

class _SkillLevelsCard extends StatelessWidget {
  final UserProfile profile;
  final int Function(int) pointsNeededForTier;

  const _SkillLevelsCard({
    required this.profile,
    required this.pointsNeededForTier,
  });

  @override
  Widget build(BuildContext context) {
    final sports = SampleData.sports
        .where((s) {
          final sk = profile.sportSkills[s];
          return sk != null && sk.matchesPlayed > 0;
        })
        .toList();
    final display = sports.isEmpty
        ? SampleData.sports.take(5).toList()
        : sports.take(5).toList();

    return _SectionCard(
      title: 'SKILL LEVELS',
      child: Column(
        children: [
          for (var i = 0; i < display.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _SkillRow(
              sport: display[i],
              profile: profile,
              pointsNeededForTier: pointsNeededForTier,
            ),
          ],
        ],
      ),
    );
  }
}

String _emojiForSport(String sport) {
  final k = sport.toLowerCase();
  if (k.contains('football')) return '⚽';
  if (k.contains('badminton')) return '🏸';
  if (k.contains('basketball')) return '🏀';
  if (k.contains('volleyball')) return '🏐';
  if (k.contains('tennis')) return '🎾';
  if (k.contains('running') || k.contains('jogging')) return '🏃';
  return '🏅';
}

Color _accentForSport(String sport) {
  final key = sport.trim().toLowerCase();
  if (key.contains('football')) {
    return const Color(0xFF0F8E66);
  }
  if (key.contains('basketball')) {
    return const Color(0xFFE56A00);
  }
  if (key.contains('badminton') || key.contains('tennis')) {
    return const Color(0xFF5C62EA);
  }
  if (key.contains('volleyball')) {
    return const Color(0xFF0F9D92);
  }
  return const Color(0xFF2E976F);
}

class _SkillRow extends StatelessWidget {
  final String sport;
  final UserProfile profile;
  final int Function(int) pointsNeededForTier;

  const _SkillRow({
    required this.sport,
    required this.profile,
    required this.pointsNeededForTier,
  });

  @override
  Widget build(BuildContext context) {
    final sportSkill =
        profile.sportSkills[sport] ?? const SportSkillProgress();
    final hasPlayed = sportSkill.matchesPlayed > 0;
    final needed = pointsNeededForTier(sportSkill.tierLevel);
    final progress = needed <= 0
        ? 0.0
        : (sportSkill.tierProgress / needed).clamp(0.0, 1.0);
    final accent = _accentForSport(sport);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(_emojiForSport(sport), style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sport,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: hasPlayed ? progress : 0.03,
                  backgroundColor: const Color(0xFFE1E5E8),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Lvl ${sportSkill.tierLevel}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentMatchesCard extends StatelessWidget {
  final FreeTierStatsSnapshot stats;

  const _RecentMatchesCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final list = stats.recentMatches;
    return _SectionCard(
      title: 'RECENT MATCHES — LAST 5',
      child: list.isEmpty
          ? Text(
              'No recent matches yet. Join events and record scores to build your history.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _RecentMatchRow(entry: list[i]),
                ],
              ],
            ),
    );
  }
}

class _RecentMatchRow extends StatelessWidget {
  final RecentMatchEntry entry;

  const _RecentMatchRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final letter = switch (entry.outcome) {
      MatchOutcome.win => ('W', const Color(0xFF22A06B)),
      MatchOutcome.draw => ('D', const Color(0xFFF5A524)),
      MatchOutcome.loss => ('L', const Color(0xFFE85D5D)),
    };
    final ptsColor = switch (entry.outcome) {
      MatchOutcome.win => const Color(0xFF22A06B),
      MatchOutcome.draw => const Color(0xFFE89400),
      MatchOutcome.loss => const Color(0xFF8F9AA3),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: letter.$2.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Text(
            letter.$1,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: letter.$2,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            entry.sportName,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        Text(
          entry.pointsLabel,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: ptsColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _LockedDetailedStatsSection extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _LockedDetailedStatsSection({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DETAILED STATS',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.45),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 12,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: const _FakeDetailedStatsPreview(),
                ),
              ),
              Container(
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.52),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                child: _UnlockDetailedStatsCard(onUpgrade: onUpgrade),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Decorative placeholder behind the blur (not real user data).
class _FakeDetailedStatsPreview extends StatelessWidget {
  const _FakeDetailedStatsPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Form Guide',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.black.withValues(alpha: 0.85),
              ),
            ),
            const Spacer(),
            Text(
              'Last 10',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.45),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in [
              Color(0xFF22A06B),
              Color(0xFF22A06B),
              Color(0xFFF5A524),
              Color(0xFF22A06B),
              Color(0xFFE8E8E8),
              Color(0xFF22A06B),
              Color(0xFF22A06B),
            ])
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Win rate',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '58%',
                      style: TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avg pts/match',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '2.4',
                      style: TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Per-sport trends · full match log · opponent history',
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.4),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _UnlockDetailedStatsCard extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _UnlockDetailedStatsCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF5C542), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFC9A227), size: 30),
            const SizedBox(height: 10),
            const Text(
              'Unlock detailed stats',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: Color(0xFF2A3540),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Form guide, win rate & averages, per-sport trends, full match '
              'history with opponents, and skill-level breakdowns.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                height: 1.35,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8C547), Color(0xFFC9A227)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE8C547).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onUpgrade,
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.workspace_premium,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Upgrade to Pro',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6DEDC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.45),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatsAvatar extends StatelessWidget {
  final String? fileId;

  const _StatsAvatar({required this.fileId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (fileId == null || fileId!.isEmpty)
          ? const Center(child: Text('🏃', style: TextStyle(fontSize: 32)))
          : FutureBuilder<Uint8List>(
              future: AppwriteService.getFileViewBytes(
                bucketId: AppwriteConfig.profileImagesBucketId,
                fileId: fileId!,
              ),
              builder: (context, snap) {
                if (snap.hasData) {
                  return Image.memory(snap.data!, fit: BoxFit.cover);
                }
                return const Center(
                  child: Text('🏃', style: TextStyle(fontSize: 32)),
                );
              },
            ),
    );
  }
}
