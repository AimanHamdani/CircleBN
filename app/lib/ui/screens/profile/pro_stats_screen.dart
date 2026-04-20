import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../data/achievement_repository.dart';
import '../../../data/free_tier_stats_repository.dart' show MatchOutcome;
import '../../../data/membership_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../data/pro_tier_stats_repository.dart';
import '../../../data/sample_clubs.dart';
import '../../../models/user_profile.dart';
/// Route arguments for [ProMatchHistoryScreen].
class ProMatchHistoryArgs {
  final String? sportFilter;

  const ProMatchHistoryArgs({this.sportFilter});
}

/// Pro hub: All sports aggregate + sport tab navigation.
class ProStatsHubScreen extends StatefulWidget {
  static const routeName = '/profile/pro-stats';

  const ProStatsHubScreen({super.key});

  @override
  State<ProStatsHubScreen> createState() => _ProStatsHubScreenState();
}

class _ProStatsHubScreenState extends State<ProStatsHubScreen> {
  late Future<List<Object?>> _future;
  String? _selectedSport;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Object?>> _load() async {
    return Future.wait<Object?>([
      profileRepository().getMyProfile(),
      achievementRepository().getMySnapshot(),
      membershipRepository().getStatus(),
    ]);
  }

  int _pointsNeededForTier(int tierLevel) {
    const thresholds = <int>[10, 15, 20, 25, 35, 45, 60, 80, 100];
    if (tierLevel >= 10) {
      return thresholds.last;
    }
    return thresholds[(tierLevel - 1).clamp(0, thresholds.length - 1)];
  }

  List<String> _sportsForTabs(UserProfile profile) {
    final ordered = <String>[];
    final seen = <String>{};
    const excludedTabSports = <String>{
      'running / jogging',
      'cycling',
      'swimming',
    };

    void addSport(String raw) {
      final sport = raw.trim();
      if (sport.isEmpty) {
        return;
      }
      final key = sport.toLowerCase();
      if (excludedTabSports.contains(key)) {
        return;
      }
      if (seen.contains(key)) {
        return;
      }
      seen.add(key);
      ordered.add(sport);
    }

    for (final sport in SampleData.sports) {
      addSport(sport);
    }
    for (final sport in profile.sportSkills.keys) {
      addSport(sport);
    }
    for (final row in profile.matchHistory) {
      addSport(row.sport);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F7),
      body: FutureBuilder<List<Object?>>(
        future: _future,
        builder: (context, snap) {
          if (snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snap.data![0] as UserProfile;
          final achievements = snap.data![1] as AchievementSnapshot;
          final membership = snap.data![2] as MembershipStatus;

          if (!membership.isPremium) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Stats hub is available on CircleBN Pro.'),
                  ),
                );
                Navigator.of(context).pop();
              }
            });
            return const SizedBox.shrink();
          }

          final snapshot = ProTierStatsRepository.buildSnapshot(
            profile: profile,
            achievements: achievements,
            sportFilter: _selectedSport,
          );
          final isSportDetailTab =
              (_selectedSport ?? '').trim().isNotEmpty;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: isSportDetailTab
                    ? _FootballHeader(
                        profile: profile,
                        snapshot: snapshot,
                        selectedSport: _selectedSport ?? 'Football',
                        onBack: () => Navigator.of(context).pop(),
                      )
                    : _ProHeader(
                        profile: profile,
                        snapshot: snapshot,
                        isPro: true,
                        onBack: () => Navigator.of(context).pop(),
                      ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                  child: _SportTabsStrip(
                    sports: _sportsForTabs(profile),
                    selectedSport: _selectedSport,
                    onSelectAll: () {
                      setState(() {
                        _selectedSport = null;
                      });
                    },
                    onSelectSport: (sport) {
                      setState(() {
                        _selectedSport = sport;
                      });
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    isSportDetailTab
                        ? [
                            _ProMatchRecordCard(snapshot: snapshot),
                            if ((_selectedSport ?? '')
                                    .toLowerCase()
                                    .contains('badminton') ||
                                (_selectedSport ?? '')
                                    .toLowerCase()
                                    .contains('tennis') ||
                                (_selectedSport ?? '')
                                    .toLowerCase()
                                    .contains('pickle')) ...[
                              const SizedBox(height: 12),
                              _BadmintonFormatSplitCard(
                                snapshot: snapshot,
                                sportName: _selectedSport ?? 'Sport',
                              ),
                            ],
                            const SizedBox(height: 12),
                            _ProFormGuideCard(snapshot: snapshot),
                            const SizedBox(height: 12),
                            _FootballSkillProgressCard(
                              snapshot: snapshot,
                              profile: profile,
                              sportName: _selectedSport ?? 'Sport',
                              pointsNeededForTier: _pointsNeededForTier,
                            ),
                            const SizedBox(height: 12),
                            _FootballStatTableCard(
                              snapshot: snapshot,
                              sportName: _selectedSport ?? 'Sport',
                            ),
                            const SizedBox(height: 12),
                            _FootballHistoryCard(
                              snapshot: snapshot,
                              sportName: _selectedSport ?? 'Sport',
                              onViewAll: () {
                                Navigator.of(context).pushNamed(
                                  ProMatchHistoryScreen.routeName,
                                  arguments: ProMatchHistoryArgs(
                                    sportFilter: _selectedSport,
                                  ),
                                );
                              },
                            ),
                          ]
                        : [
                            _ProMatchRecordCard(snapshot: snapshot),
                            if ((_selectedSport ?? '')
                                .toLowerCase()
                                .contains('badminton')) ...[
                              const SizedBox(height: 12),
                              _BadmintonFormatSplitCard(
                                snapshot: snapshot,
                                sportName: _selectedSport ?? 'Badminton',
                              ),
                            ],
                            const SizedBox(height: 12),
                            _ProFormGuideCard(snapshot: snapshot),
                            const SizedBox(height: 12),
                            _ProSkillLevelsCard(
                              profile: profile,
                              pointsNeededForTier: _pointsNeededForTier,
                            ),
                            const SizedBox(height: 12),
                            _ProStreakCard(snapshot: snapshot),
                            const SizedBox(height: 12),
                            _ProMatchHistorySection(
                              snapshot: snapshot,
                              onViewAll: () {
                                Navigator.of(context).pushNamed(
                                  ProMatchHistoryScreen.routeName,
                                  arguments: ProMatchHistoryArgs(
                                    sportFilter: _selectedSport,
                                  ),
                                );
                              },
                            ),
                          ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Full chronological match list for Pro.
class ProMatchHistoryScreen extends StatelessWidget {
  static const routeName = '/profile/pro-stats/history';

  const ProMatchHistoryScreen({super.key});

  static const List<String> _months = <String>[
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

  String _shortDate(DateTime d) {
    final local = d.toLocal();
    return '${local.day} ${_months[local.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final sportFilter = args is ProMatchHistoryArgs ? args.sportFilter : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F7),
      appBar: AppBar(
        title: const Text('Match history'),
        backgroundColor: const Color(0xFF1E2A4A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Object?>>(
        future: Future.wait<Object?>([
          profileRepository().getMyProfile(),
          achievementRepository().getMySnapshot(),
        ]),
        builder: (context, snap) {
          if (snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snap.data![0] as UserProfile;
          final achievements = snap.data![1] as AchievementSnapshot;
          final model = ProTierStatsRepository.buildSnapshot(
            profile: profile,
            achievements: achievements,
            sportFilter: sportFilter,
          );
          final list = model.fullMatchHistory;
          if (list.isEmpty) {
            return Center(
              child: Text(
                'No recorded matches yet.',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = list[i];
              final o = switch (r.outcome.toLowerCase()) {
                'win' => ('W', const Color(0xFF22A06B)),
                'draw' => ('D', const Color(0xFFF5A524)),
                _ => ('L', const Color(0xFFE85D5D)),
              };
              final sub = [
                _shortDate(r.recordedAt),
                if (r.statSnippet != null && r.statSnippet!.trim().isNotEmpty)
                  r.statSnippet!.trim(),
              ].join(' · ');
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD6DEDC)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: o.$2.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        o.$1,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: o.$2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.eventTitle.trim().isNotEmpty
                                ? r.eventTitle
                                : r.sport,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${r.sport} · $sub',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      r.pointsAwarded == 0
                          ? '0 pts'
                          : (r.pointsAwarded == 1 ? '+1 pt' : '+${r.pointsAwarded} pts'),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: o.$1 == 'W'
                            ? const Color(0xFF22A06B)
                            : (o.$1 == 'D'
                                  ? const Color(0xFFE89400)
                                  : const Color(0xFF8F9AA3)),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- Shared header & sections ---

class _ProHeader extends StatelessWidget {
  final UserProfile profile;
  final ProStatsSnapshot snapshot;
  final bool isPro;
  final VoidCallback onBack;

  const _ProHeader({
    required this.profile,
    required this.snapshot,
    required this.isPro,
    required this.onBack,
  });

  static const List<String> _months = <String>[
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

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final name = profile.realName.trim().isNotEmpty
        ? profile.realName.trim()
        : 'Player';
    final now = DateTime.now();
    final memberSince =
        'Member since ${_months[now.month - 1]} ${now.year}';

    final winR = snapshot.winRatePercent;
    final avg = snapshot.avgPointsPerMatch;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF2D4A7C)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProAvatar(fileId: profile.avatarFileId),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A34).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Pro',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _KpiPill(
                  value: '${snapshot.eventsJoinedCount}',
                  label: 'Events',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _KpiPill(
                  value: winR != null ? '${winR.round()}%' : '—',
                  label: 'Win rate',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _KpiPill(
                  value: avg != null ? avg.toStringAsFixed(1) : '—',
                  label: 'Avg pts',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _KpiPill(
                  value: '🔥 ${snapshot.currentStreak}',
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

class _KpiPill extends StatelessWidget {
  final String value;
  final String label;

  const _KpiPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SportTabsStrip extends StatelessWidget {
  final List<String> sports;
  final String? selectedSport;
  final VoidCallback onSelectAll;
  final void Function(String sport) onSelectSport;

  const _SportTabsStrip({
    required this.sports,
    required this.selectedSport,
    required this.onSelectAll,
    required this.onSelectSport,
  });

  @override
  Widget build(BuildContext context) {
    const all = 'All sports';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _SportChip(
            label: all,
            icon: null,
            selected: selectedSport == null || selectedSport == all,
            onTap: onSelectAll,
          ),
          for (final sport in sports) ...[
            const SizedBox(width: 8),
            _SportChip(
              label: sport,
              icon: _sportEmoji(sport),
              selected: selectedSport != null &&
                  selectedSport!.toLowerCase() == sport.toLowerCase(),
              onTap: () => onSelectSport(sport),
            ),
          ],
        ],
      ),
    );
  }
}

String _sportEmoji(String sport) {
  final k = sport.toLowerCase();
  if (k.contains('football')) return '⚽';
  if (k.contains('badminton')) return '🏸';
  if (k.contains('basketball')) return '🏀';
  if (k.contains('volleyball')) return '🏐';
  if (k.contains('tennis')) return '🎾';
  return '🏅';
}

class _SportChip extends StatelessWidget {
  final String label;
  final String? icon;
  final bool selected;
  final VoidCallback onTap;

  const _SportChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF4361EE) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4361EE)
                  : const Color(0xFFD6DEDC),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Text(icon!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: selected ? Colors.white : const Color(0xFF4A5568),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProMatchRecordCard extends StatelessWidget {
  final ProStatsSnapshot snapshot;

  const _ProMatchRecordCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final sportKey = (snapshot.sportFilter ?? '').toLowerCase();
    final isBadminton = sportKey.contains('badminton');
    final isTennis = sportKey.contains('tennis');
    final isPickleball = sportKey.contains('pickle');
    final isSportDetail = sportKey.trim().isNotEmpty;
    final isNoDrawSport =
        isBadminton || isTennis || isPickleball || sportKey.contains('basketball');

    final wins = snapshot.wins;
    final draws = isNoDrawSport ? 0 : snapshot.draws;
    final losses = isNoDrawSport
        ? snapshot.losses + snapshot.draws
        : snapshot.losses;
    final total = wins + draws + losses;
    final winPct = total > 0 ? wins / total : 0.0;
    final drawPct = total > 0 ? draws / total : 0.0;
    final lossPct = total > 0 ? losses / total : 0.0;

    final title = isBadminton
        ? 'MATCH RECORD — NO DRAWS IN BADMINTON'
        : isTennis
        ? 'MATCH RECORD — NO DRAWS IN TENNIS'
        : isPickleball
        ? 'MATCH RECORD — NO DRAWS IN PICKLEBALL'
        : (snapshot.sportFilter == null || snapshot.sportFilter!.isEmpty
              ? 'MATCH RECORD'
              : 'MATCH RECORD');

    return _ProSectionCard(
      title: title,
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
                        Expanded(child: ColoredBox(color: Color(0xFFB8DCC8))),
                        Expanded(child: ColoredBox(color: Color(0xFFF5DEB0))),
                        Expanded(child: ColoredBox(color: Color(0xFFF0B4B4))),
                      ],
                    )
                  : Row(
                      children: [
                        if (wins > 0)
                          Expanded(
                            flex: wins,
                            child: const ColoredBox(color: Color(0xFF22A06B)),
                          ),
                        if (draws > 0)
                          Expanded(
                            flex: draws,
                            child: const ColoredBox(color: Color(0xFFF5A524)),
                          ),
                        if (losses > 0)
                          Expanded(
                            flex: losses,
                            child: const ColoredBox(color: Color(0xFFE85D5D)),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ResultColPro(
                  value: '$wins',
                  caption: total > 0
                      ? 'Wins — ${(winPct * 100).round()}%'
                      : 'Wins',
                  color: const Color(0xFF22A06B),
                ),
              ),
              if (!isNoDrawSport) ...[
                Container(width: 1, height: 46, color: const Color(0xFFE1E5E8)),
                Expanded(
                  child: _ResultColPro(
                    value: '$draws',
                    caption: total > 0
                        ? 'Draws — ${(drawPct * 100).round()}%'
                        : 'Draws',
                    color: const Color(0xFFE89400),
                  ),
                ),
                Container(
                  width: 1,
                  height: 46,
                  color: const Color(0xFFE1E5E8),
                ),
              ] else
                Container(width: 1, height: 46, color: const Color(0xFFE1E5E8)),
              Expanded(
                child: _ResultColPro(
                  value: '$losses',
                  caption: total > 0
                      ? 'Losses — ${(lossPct * 100).round()}%'
                      : 'Losses',
                  color: const Color(0xFFE85D5D),
                ),
              ),
            ],
          ),
          if (isSportDetail && total > 0) ...[
            const SizedBox(height: 10),
            Text(
              sportKey.contains('basketball')
                  ? 'Only $total matches played — trends will stabilize with more games'
                  : sportKey.contains('pickle')
                  ? 'Only $total matches played — doubles-heavy sample, keep logging results'
                  : sportKey.contains('volleyball')
                  ? 'Only $total matches played — more rallies logged improves accuracy'
                  : sportKey.contains('table tennis') || sportKey.contains('ping pong')
                  ? 'Only $total matches played — more sets needed for stronger confidence'
                  : sportKey.contains('badminton')
                  ? 'Only $total matches played — more matches needed for stable split data'
                  : sportKey.contains('tennis')
                  ? 'Only $total matches played — more data needed'
                  : 'Only $total matches played — more data needed',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.5),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultColPro extends StatelessWidget {
  final String value;
  final String caption;
  final Color color;

  const _ResultColPro({
    required this.value,
    required this.caption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black.withValues(alpha: 0.5),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ProFormGuideCard extends StatelessWidget {
  final ProStatsSnapshot snapshot;

  const _ProFormGuideCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final tiles = snapshot.formLast10Chronological;
    return _ProSectionCard(
      title: 'FORM GUIDE — LAST 10',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in tiles)
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: switch (o) {
                      MatchOutcome.win => const Color(0xFF22A06B),
                      MatchOutcome.draw => const Color(0xFFF5A524),
                      MatchOutcome.loss => const Color(0xFFE85D5D),
                    },
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    switch (o) {
                      MatchOutcome.win => 'W',
                      MatchOutcome.draw => 'D',
                      MatchOutcome.loss => 'L',
                    },
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              if (tiles.length < 10)
                for (var i = 0; i < 10 - tiles.length; i++)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE1E5E8)),
                    ),
                  ),
            ],
          ),
          if (snapshot.formSummaryLine.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              snapshot.formSummaryLine,
              style: const TextStyle(
                color: Color(0xFF22A06B),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProSkillLevelsCard extends StatelessWidget {
  final UserProfile profile;
  final int Function(int) pointsNeededForTier;

  const _ProSkillLevelsCard({
    required this.profile,
    required this.pointsNeededForTier,
  });

  @override
  Widget build(BuildContext context) {
    const excludedSkillSports = <String>{
      'running / jogging',
      'cycling',
      'swimming',
    };
    final visibleSports = SampleData.sports
        .where((s) => !excludedSkillSports.contains(s.trim().toLowerCase()))
        .toList();

    final played = visibleSports
        .where((s) {
          final sk = profile.sportSkills[s];
          return sk != null && sk.matchesPlayed > 0;
        })
        .toList();
    final sports = played.isEmpty
        ? visibleSports.take(5).toList()
        : played.take(5).toList();

    return _ProSectionCard(
      title: 'SKILL LEVELS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sports.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _ProSkillRow(
              sport: sports[i],
              profile: profile,
              pointsNeededForTier: pointsNeededForTier,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Tap a sport tab to see detailed stats →',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProSkillRow extends StatelessWidget {
  final String sport;
  final UserProfile profile;
  final int Function(int) pointsNeededForTier;

  const _ProSkillRow({
    required this.sport,
    required this.profile,
    required this.pointsNeededForTier,
  });

  Color _accent(String s) {
    final key = s.trim().toLowerCase();
    if (key.contains('football')) return const Color(0xFF0F8E66);
    if (key.contains('basketball')) return const Color(0xFFE56A00);
    if (key.contains('badminton') || key.contains('tennis')) {
      return const Color(0xFF5C62EA);
    }
    if (key.contains('volleyball')) return const Color(0xFF0F9D92);
    return const Color(0xFF2E976F);
  }

  @override
  Widget build(BuildContext context) {
    final sk = profile.sportSkills[sport] ?? const SportSkillProgress();
    final played = sk.matchesPlayed > 0;
    final need = pointsNeededForTier(sk.tierLevel);
    final prog = need <= 0 ? 0.0 : (sk.tierProgress / need).clamp(0.0, 1.0);
    final accent = _accent(sport);
    final trail = played ? '${sk.tierProgress}/$need' : '—';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(_sportEmoji(sport), style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sport,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    'Lvl ${sk.tierLevel}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: accent,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: played ? prog : 0.04,
                  backgroundColor: const Color(0xFFE1E5E8),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trail,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: Colors.black.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class _ProStreakCard extends StatelessWidget {
  final ProStatsSnapshot snapshot;

  const _ProStreakCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return _ProSectionCard(
      title: 'STREAK',
      child: Column(
        children: [
          _StreakLine(
            left: 'Current streak',
            right: '🔥 ${snapshot.currentStreak} events',
            rightColor: const Color(0xFFE89400),
          ),
          const Divider(height: 22),
          _StreakLine(
            left: 'Best ever streak',
            right: '⚡ ${snapshot.bestStreak} events',
            rightColor: const Color(0xFF4361EE),
          ),
          const Divider(height: 22),
          _StreakLine(
            left: 'Total pts from matches',
            right: '${snapshot.totalPointsFromMatches} pts',
            rightColor: const Color(0xFF1E3A5F),
          ),
        ],
      ),
    );
  }
}

class _StreakLine extends StatelessWidget {
  final String left;
  final String right;
  final Color rightColor;

  const _StreakLine({
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
        Flexible(
          child: Text(
            right,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: rightColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProMatchHistorySection extends StatelessWidget {
  final ProStatsSnapshot snapshot;
  final VoidCallback onViewAll;

  const _ProMatchHistorySection({
    required this.snapshot,
    required this.onViewAll,
  });

  static const List<String> _months = <String>[
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

  String _date(ProfileMatchRecord r) {
    final d = r.recordedAt.toLocal();
    return '${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = snapshot.recentMatchesForCard;
    final total = snapshot.fullMatchHistory.length;

    return _ProSectionCard(
      title: 'RECENT MATCHES',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty)
            Text(
              'No matches in this view yet.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _ProHistoryRow(record: rows[i], dateLabel: _date(rows[i])),
            ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onViewAll,
              child: Text(
                'View all $total matches →',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProHistoryRow extends StatelessWidget {
  final ProfileMatchRecord record;
  final String dateLabel;

  const _ProHistoryRow({required this.record, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final letter = switch (record.outcome.toLowerCase()) {
      'win' => ('W', const Color(0xFF22A06B)),
      'draw' => ('D', const Color(0xFFF5A524)),
      _ => ('L', const Color(0xFFE85D5D)),
    };
    final sub = [
      dateLabel,
      if (record.statSnippet != null && record.statSnippet!.trim().isNotEmpty)
        record.statSnippet!.trim(),
    ].join(' · ');

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.eventTitle.trim().isNotEmpty
                    ? record.eventTitle
                    : record.sport,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${record.sport} · $sub',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Text(
          record.pointsAwarded == 0
              ? '0 pts'
              : (record.pointsAwarded == 1 ? '+1 pt' : '+${record.pointsAwarded} pts'),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: letter.$1 == 'W'
                ? const Color(0xFF22A06B)
                : (letter.$1 == 'D'
                      ? const Color(0xFFE89400)
                      : const Color(0xFF8F9AA3)),
          ),
        ),
      ],
    );
  }
}

class _FootballHeader extends StatelessWidget {
  final UserProfile profile;
  final ProStatsSnapshot snapshot;
  final String selectedSport;
  final VoidCallback onBack;

  const _FootballHeader({
    required this.profile,
    required this.snapshot,
    required this.selectedSport,
    required this.onBack,
  });

  static const List<String> _months = <String>[
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

  List<Color> _gradientForSport(String sport) {
    final k = sport.toLowerCase();
    if (k.contains('table tennis') || k.contains('ping pong')) {
      return const [Color(0xFF8E1146), Color(0xFFD63C74)];
    }
    if (k.contains('pickle')) {
      return const [Color(0xFF8A420C), Color(0xFFE39C00)];
    }
    if (k.contains('basketball')) {
      return const [Color(0xFFB54708), Color(0xFFE56A00)];
    }
    if (k.contains('badminton') || k.contains('tennis')) {
      return const [Color(0xFF3F3FB8), Color(0xFF5C62EA)];
    }
    if (k.contains('volleyball')) {
      return const [Color(0xFF6B2CCF), Color(0xFF8C52E5)];
    }
    return const [Color(0xFF19643F), Color(0xFF2D8D59)];
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final name = profile.realName.trim().isNotEmpty
        ? profile.realName.trim()
        : 'Player';
    final now = DateTime.now();
    final memberSince =
        'Member since ${_months[now.month - 1]} ${now.year}';
    final winRate = snapshot.winRatePercent;
    final sportSkill =
        profile.sportSkills[selectedSport] ?? const SportSkillProgress();

    final gradientColors = _gradientForSport(selectedSport);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _ProAvatar(fileId: profile.avatarFileId),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$selectedSport · ${snapshot.totalResults} matches',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      memberSince,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A34),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiPill(
                  value: '${snapshot.totalResults}',
                  label: 'Matches',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _KpiPill(
                  value: winRate != null ? '${winRate.round()}%' : '—',
                  label: 'Win rate',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _KpiPill(
                  value: 'Lvl ${sportSkill.tierLevel}',
                  label: 'Skill',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _KpiPill(
                  value: '+${snapshot.totalPointsFromMatches}',
                  label: 'Pts',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FootballSkillProgressCard extends StatelessWidget {
  final ProStatsSnapshot snapshot;
  final UserProfile profile;
  final String sportName;
  final int Function(int tierLevel) pointsNeededForTier;

  const _FootballSkillProgressCard({
    required this.snapshot,
    required this.profile,
    required this.sportName,
    required this.pointsNeededForTier,
  });

  ({Color bg, Color border, Color accent, String unitHint}) _styleForSport(
    String sport,
  ) {
    final k = sport.toLowerCase();
    if (k.contains('table tennis') || k.contains('ping pong')) {
      return (
        bg: const Color(0xFFFFEDF4),
        border: const Color(0xFFF3A8C2),
        accent: const Color(0xFFC81F5D),
        unitHint: 'wins away',
      );
    }
    if (k.contains('pickle')) {
      return (
        bg: const Color(0xFFFFF5E6),
        border: const Color(0xFFF0C777),
        accent: const Color(0xFFE39C00),
        unitHint: 'wins away',
      );
    }
    if (k.contains('basketball')) {
      return (
        bg: const Color(0xFFFFF1E7),
        border: const Color(0xFFF0A25E),
        accent: const Color(0xFFE56A00),
        unitHint: 'games away',
      );
    }
    if (k.contains('badminton') || k.contains('tennis')) {
      return (
        bg: const Color(0xFFEAF3FF),
        border: const Color(0xFF86B8F0),
        accent: const Color(0xFF3E8AD8),
        unitHint: 'matches away',
      );
    }
    if (k.contains('volleyball')) {
      return (
        bg: const Color(0xFFF1ECFF),
        border: const Color(0xFFC4AFF8),
        accent: const Color(0xFF7A3EE8),
        unitHint: 'matches away',
      );
    }
    return (
      bg: const Color(0xFFEAF7F0),
      border: const Color(0xFF7BC79A),
      accent: const Color(0xFF2D8D59),
      unitHint: 'wins away',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sportSkill = profile.sportSkills[sportName] ?? const SportSkillProgress();
    final nextLevel = (sportSkill.tierLevel + 1).clamp(1, 10);
    final needed = pointsNeededForTier(sportSkill.tierLevel);
    final remaining = (needed - sportSkill.tierProgress).clamp(0, needed);
    final progress = needed <= 0
        ? 0.0
        : (sportSkill.tierProgress / needed).clamp(0.0, 1.0);
    final eventsAway = snapshot.currentStreak <= 0
        ? remaining
        : (remaining / snapshot.currentStreak).ceil();
    final style = _styleForSport(sportName);
    final sport = sportName.toLowerCase();
    final recent = snapshot.formLast10Chronological;
    var lossStreak = 0;
    for (var i = recent.length - 1; i >= 0; i--) {
      if (recent[i] == MatchOutcome.loss) {
        lossStreak++;
      } else {
        break;
      }
    }
    final warningThreshold = sport.contains('tennis') &&
            !(sport.contains('table tennis') || sport.contains('ping pong'))
        ? 3
        : sport.contains('basketball')
        ? 2
        : sport.contains('pickle')
        ? 2
        : sport.contains('volleyball')
        ? 2
        : 2;
    final showWarning = lossStreak >= warningThreshold;
    final penaltyText = sport.contains('basketball') ? '-2 pts' : '-1 pt';

    return _ProSectionCard(
      title: 'SKILL LEVEL',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: style.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Level ${sportSkill.tierLevel} → $nextLevel · need $remaining more pts',
              style: TextStyle(
                color: style.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${sportSkill.tierLevel}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF19643F),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: progress,
                      backgroundColor: const Color(0xFFD9E9DF),
                      valueColor: AlwaysStoppedAnimation<Color>(style.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$nextLevel',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6B7E73),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${sportSkill.tierProgress}/$needed pts · ~$eventsAway ${style.unitHint}',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SkillHintTile(
                    top: '+$remaining',
                    bottom: 'pts needed',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SkillHintTile(
                    top: '~$eventsAway',
                    bottom: 'events away',
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: _SkillHintTile(
                    top: 'Win',
                    bottom: 'fastest',
                    topColor: Color(0xFF22A06B),
                  ),
                ),
              ],
            ),
            if (showWarning) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Warning: $lossStreak-loss streak — next loss costs $penaltyText',
                  style: const TextStyle(
                    color: Color(0xFFE55C66),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkillHintTile extends StatelessWidget {
  final String top;
  final String bottom;
  final Color topColor;

  const _SkillHintTile({
    required this.top,
    required this.bottom,
    this.topColor = const Color(0xFF2A3540),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8DEDC)),
      ),
      child: Column(
        children: [
          Text(
            top,
            style: TextStyle(
              color: topColor,
              fontWeight: FontWeight.w900,
              fontSize: 20 / 1.25,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            bottom,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.5),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _FootballStatTableCard extends StatelessWidget {
  final ProStatsSnapshot snapshot;
  final String sportName;

  const _FootballStatTableCard({
    required this.snapshot,
    required this.sportName,
  });

  @override
  Widget build(BuildContext context) {
    final matches = snapshot.totalResults;
    final sport = sportName.toLowerCase();
    final history = snapshot.fullMatchHistory;

    ({int total, double per, int best}) agg(String key) {
      var total = 0.0;
      var best = 0.0;
      for (final record in history) {
        final raw = record.statValues[key];
        if (raw == null) {
          continue;
        }
        final value = raw.toDouble();
        total += value;
        if (value > best) {
          best = value;
        }
      }
      return (
        total: total.round(),
        per: matches <= 0 ? 0 : (total / matches),
        best: best.round(),
      );
    }

    final rows = <({String label, int total, double per, int best, bool warn})>[];
    if (sport.contains('table tennis') || sport.contains('ping pong')) {
      final gw = agg('gamesWon');
      final pw = agg('pointsWon');
      final ac = agg('aces');
      rows.addAll([
        (label: 'Games Won', total: gw.total, per: gw.per, best: gw.best, warn: false),
        (label: 'Points Won', total: pw.total, per: pw.per, best: pw.best, warn: false),
        (label: 'Aces', total: ac.total, per: ac.per, best: ac.best, warn: false),
      ]);
    } else if (sport.contains('pickle')) {
      final gw = agg('gamesWon');
      final pw = agg('pointsWon');
      final ac = agg('aces');
      rows.addAll([
        (label: 'Games Won', total: gw.total, per: gw.per, best: gw.best, warn: false),
        (label: 'Points Won', total: pw.total, per: pw.per, best: pw.best, warn: false),
        (label: 'Aces', total: ac.total, per: ac.per, best: ac.best, warn: false),
      ]);
    } else if (sport.contains('basketball')) {
      final pts = agg('points');
      final ast = agg('assists');
      final reb = agg('rebounds');
      final stl = agg('steals');
      final blk = agg('blocks');
      final tov = agg('turnovers');
      rows.addAll([
        (label: 'Points (PTS)', total: pts.total, per: pts.per, best: pts.best, warn: false),
        (label: 'Assists (AST)', total: ast.total, per: ast.per, best: ast.best, warn: false),
        (label: 'Rebounds (REB)', total: reb.total, per: reb.per, best: reb.best, warn: false),
        (label: 'Steals (STL)', total: stl.total, per: stl.per, best: stl.best, warn: false),
        (label: 'Blocks (BLK)', total: blk.total, per: blk.per, best: blk.best, warn: false),
        (label: 'Turnovers (TO) ↓', total: tov.total, per: tov.per, best: tov.best, warn: true),
      ]);
    } else if (sport.contains('badminton')) {
      final gw = agg('gamesWon');
      final pw = agg('pointsWon');
      final ac = agg('aces');
      rows.addAll([
        (label: 'Games Won', total: gw.total, per: gw.per, best: gw.best, warn: false),
        (label: 'Points Won', total: pw.total, per: pw.per, best: pw.best, warn: false),
        (label: 'Aces', total: ac.total, per: ac.per, best: ac.best, warn: false),
      ]);
    } else if (sport.contains('volleyball')) {
      final pts = agg('points');
      final ast = agg('assists');
      final blk = agg('blocks');
      final dig = agg('digs');
      rows.addAll([
        (label: 'Points (PTS)', total: pts.total, per: pts.per, best: pts.best, warn: false),
        (label: 'Assists (AST)', total: ast.total, per: ast.per, best: ast.best, warn: false),
        (label: 'Blocks (BLK)', total: blk.total, per: blk.per, best: blk.best, warn: false),
        (label: 'Digs (DIG)', total: dig.total, per: dig.per, best: dig.best, warn: false),
      ]);
    } else if (sport.contains('tennis') &&
        !sport.contains('table tennis') &&
        !sport.contains('ping pong')) {
      final sw = agg('setsWon');
      final gw = agg('gamesWon');
      final ac = agg('aces');
      rows.addAll([
        (label: 'Sets Won', total: sw.total, per: sw.per, best: sw.best, warn: false),
        (label: 'Games Won', total: gw.total, per: gw.per, best: gw.best, warn: false),
        (label: 'Aces', total: ac.total, per: ac.per, best: ac.best, warn: false),
      ]);
    } else {
      final g = agg('goals');
      final a = agg('assists');
      final p = agg('passes');
      final t = agg('tackles');
      final s = agg('saves');
      rows.addAll([
        (label: 'Goals (G)', total: g.total, per: g.per, best: g.best, warn: false),
        (label: 'Assists (AST)', total: a.total, per: a.per, best: a.best, warn: false),
        (label: 'Passes (PASS)', total: p.total, per: p.per, best: p.best, warn: false),
        (label: 'Tackles (TKL)', total: t.total, per: t.per, best: t.best, warn: false),
        (label: 'Saves (SAV)', total: s.total, per: s.per, best: s.best, warn: false),
      ]);
    }

    return _ProSectionCard(
      title: 'STATS — MATCHES SCORE ENTRY EXACTLY',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('STAT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF7B837F)))),
                Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF7B837F)))),
                Expanded(flex: 2, child: Text('PER MATCH', textAlign: TextAlign.center, softWrap: false, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Color(0xFF7B837F)))),
                Expanded(flex: 2, child: Text('BEST', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF7B837F)))),
              ],
            ),
          ),
          for (final r in rows) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    r.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: r.warn ? const Color(0xFFD9534F) : null,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${r.total}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF19643F),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    matches <= 0 ? '—' : r.per.toStringAsFixed(1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: r.warn ? const Color(0xFFD9534F) : null,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${r.best}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE56A00),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (sport.contains('basketball')) ...[
            const SizedBox(height: 10),
            Text(
              'TO is a negative stat — high turnover count hurts your skill pts.\n💡 Strong PTS + REB. Reduce TO to level up faster.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ] else if (sport.contains('volleyball')) ...[
            const SizedBox(height: 10),
            Text(
              'Tip: DIG is your standout stat — strong defender. Improve PTS (kills) to push to LvL 5 faster.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ] else if (sport.contains('badminton')) ...[
            const SizedBox(height: 10),
            Text(
              'To 21, best of 3. 5.2 aces/match is excellent. Games Won avg of 1.7 means you regularly push to a decider game.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ] else if (sport.contains('table tennis') || sport.contains('ping pong')) ...[
            const SizedBox(height: 10),
            Text(
              'To 11, best of 5. 2.5 Games Won/match means you regularly win 3–1 or 3–0. 7.5 aces/match shows strong serve game.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ] else if (sport.contains('pickle')) ...[
            const SizedBox(height: 10),
            Text(
              'To 11, Best of 3 — shorter than TT. Same 3 stats tracked. 1.6 Games Won/match reflects the best-of-3 format. 4 aces/match is consistent.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FootballHistoryCard extends StatelessWidget {
  final ProStatsSnapshot snapshot;
  final String sportName;
  final VoidCallback onViewAll;

  const _FootballHistoryCard({
    required this.snapshot,
    required this.sportName,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final rows = snapshot.recentMatchesForCard.take(5).toList();
    final sport = sportName.toLowerCase();
    final metricHeader = sport.contains('basketball')
        ? 'P·A·R·S·B·TO'
        : sport.contains('pickle')
        ? 'GW·PW·ACE'
        : sport.contains('table tennis') || sport.contains('ping pong')
        ? 'GW·PW·ACE'
        : sport.contains('badminton')
        ? 'GW · PW · ACE'
        : sport.contains('volleyball')
        ? 'P · A · B · D'
        : 'G · A · P · T';
    final accent = sport.contains('basketball')
        ? const Color(0xFFE56A00)
        : sport.contains('pickle')
        ? const Color(0xFFE39C00)
        : sport.contains('table tennis') || sport.contains('ping pong')
        ? const Color(0xFFC81F5D)
        : sport.contains('badminton')
        ? const Color(0xFF3E8AD8)
        : sport.contains('volleyball')
        ? const Color(0xFF7A3EE8)
        : const Color(0xFF1F8A52);
    return _ProSectionCard(
      title: 'MATCH HISTORY (${snapshot.totalResults})',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Row(
              children: [
                Text(
                  sport.contains('badminton') ? 'MATCH · FORMAT' : 'MATCH',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  metricHeader,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 18),
                Text(
                  'PTS',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 14),
            _ProHistoryRow(
              record: rows[i],
              dateLabel: _FootballHistoryDate.format(rows[i].recordedAt),
            ),
          ],
          const SizedBox(height: 10),
          TextButton(
            onPressed: onViewAll,
            child: Text(
              'Show all ${snapshot.totalResults} matches ↓',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadmintonFormatSplitCard extends StatelessWidget {
  final ProStatsSnapshot snapshot;
  final String sportName;

  const _BadmintonFormatSplitCard({
    required this.snapshot,
    required this.sportName,
  });

  @override
  Widget build(BuildContext context) {
    final history = snapshot.fullMatchHistory;
    final total = history.length;
    final isTableTennis = sportName.toLowerCase().contains('table tennis') ||
        sportName.toLowerCase().contains('ping pong');
    final isPickleball = sportName.toLowerCase().contains('pickle');
    final isTennis = sportName.toLowerCase().contains('tennis') && !isTableTennis;
    int countForFormat(String label) {
      return history
          .where((r) => (r.formatLabel ?? '').toLowerCase() == label.toLowerCase())
          .length;
    }

    int winsForFormat(String label) {
      return history
          .where(
            (r) =>
                (r.formatLabel ?? '').toLowerCase() == label.toLowerCase() &&
                r.outcome.toLowerCase() == 'win',
          )
          .length;
    }

    final singlesCount = countForFormat('Singles');
    final doublesCount = countForFormat('Doubles');
    final resolvedSingles = singlesCount == 0 && doublesCount == 0
        ? (isPickleball ? (total * 0.34).round() : (total * 0.56).round())
        : singlesCount;
    final resolvedDoubles = singlesCount == 0 && doublesCount == 0
        ? (total - resolvedSingles).clamp(0, total)
        : doublesCount;
    final singlesWins = singlesCount == 0 && doublesCount == 0
        ? ((resolvedSingles * (snapshot.winRatePercent ?? 60) / 100).round())
        : winsForFormat('Singles');
    final doublesWins = singlesCount == 0 && doublesCount == 0
        ? ((resolvedDoubles * (snapshot.winRatePercent ?? 60) / 100).round())
        : winsForFormat('Doubles');
    final singlesWinRate = resolvedSingles > 0
        ? ((singlesWins * 100) / resolvedSingles).round()
        : 0;
    final doublesWinRate = resolvedDoubles > 0
        ? ((doublesWins * 100) / resolvedDoubles).round()
        : 0;

    Widget splitRow({
      required String label,
      required int matches,
      required int winRate,
    }) {
      final winFlex = winRate.clamp(1, 100);
      final lossFlex = (100 - winRate).clamp(1, 100);
      return Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2A3540),
                ),
              ),
              const Spacer(),
              Text(
                '$matches matches · $winRate% W',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: winFlex,
                    child: const ColoredBox(color: Color(0xFF22A06B)),
                  ),
                  Expanded(
                    flex: lossFlex,
                    child: const ColoredBox(color: Color(0xFFE8A0A0)),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return _ProSectionCard(
      title: 'FORMAT SPLIT — FROM SCORE ENTRY SELECTOR',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          splitRow(label: 'Singles', matches: resolvedSingles, winRate: singlesWinRate),
          const SizedBox(height: 10),
          splitRow(label: 'Doubles', matches: resolvedDoubles, winRate: doublesWinRate),
          const SizedBox(height: 12),
          Text(
            isTableTennis
                ? 'Dominant in Singles ($singlesWinRate%). Doubles is a clear area to improve.'
                : isPickleball
                ? 'Equal win rate across formats. Doubles is the most common pickleball format — well-rounded player.'
                : isTennis
                ? 'Much stronger in Singles ($singlesWinRate%) vs Doubles ($doublesWinRate%). Focus on singles matches to build skill pts.'
                : 'Better in Singles ($singlesWinRate%) than Doubles ($doublesWinRate%). Focus on singles to level up faster.',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

abstract final class _FootballHistoryDate {
  static const _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String format(DateTime d) {
    final local = d.toLocal();
    return '${local.day} ${_months[local.month - 1]}';
  }
}

class _ProSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ProSectionCard({required this.title, required this.child});

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
            blurRadius: 10,
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

class _ProAvatar extends StatelessWidget {
  final String? fileId;

  const _ProAvatar({required this.fileId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (fileId == null || fileId!.isEmpty)
          ? const Center(child: Text('🏃', style: TextStyle(fontSize: 28)))
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
                  child: Text('🏃', style: TextStyle(fontSize: 28)),
                );
              },
            ),
    );
  }
}
