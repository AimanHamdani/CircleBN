import 'package:flutter/material.dart';

import '../../../data/achievement_repository.dart';
import 'all_events_screen.dart';

class StreakScreen extends StatefulWidget {
  static const routeName = '/streak';

  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  late Future<AchievementSnapshot> _future;
  static AchievementSnapshot? _cachedSnapshot;

  @override
  void initState() {
    super.initState();
    _future = _loadSnapshot();
  }

  Future<AchievementSnapshot> _loadSnapshot() async {
    final snapshot = await achievementRepository().getMySnapshot();
    _cachedSnapshot = snapshot;
    return snapshot;
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8F2EA);
    const header = Color(0xFFE86F12);
    const headerDeep = Color(0xFFD55F0E);
    const cardBorder = Color(0xFFE4A055);

    return FutureBuilder<AchievementSnapshot>(
      future: _future,
      initialData: _cachedSnapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            snapshot.data == null) {
          return const Scaffold(
            backgroundColor: background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data;
        final streak = data?.currentStreak ?? 0;
        final best = data?.bestStreak ?? streak;
        final isEligible = data?.hasStreakActivity ?? false;
        final points = streak * 10;
        return Scaffold(
          backgroundColor: background,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [headerDeep, header],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.of(context).maybePop(),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Daily Streak',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30 / 1.6,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('🔥', style: TextStyle(fontSize: 58)),
                      Text(
                        '$streak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 76,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        streak == 1 ? 'day streak' : 'days streak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 35 / 1.6,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEligible
                            ? 'Log in daily to keep your streak going!'
                            : 'Join at least one event to start your streak.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _WeekStreakRow(streak: streak),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                value: '$streak',
                                label: 'Current',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                value: '$best',
                                label: 'Best ever',
                                isMuted: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                value: '$points',
                                label: 'Total pts',
                                isGoldBorder: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Milestone rewards',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 32 / 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              _MilestoneRow(
                                emoji: '🔥',
                                title: '7-day streak',
                                subtitle: 'Unlock a voucher reward',
                                progress: streak / 7,
                                trailing: '${streak.clamp(0, 7)}/7',
                                progressColor: const Color(0xFFE86F12),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFFFD2A6),
                              ),
                              _MilestoneRow(
                                emoji: '⚡',
                                title: '14-day streak',
                                subtitle: 'Earn a Gold badge',
                                progress: streak / 14,
                                trailing: '${streak.clamp(0, 14)}/14',
                                trailingColor: const Color(0xFF4A58D8),
                                progressColor: const Color(0xFF646CE9),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFFFD2A6),
                              ),
                              _MilestoneRow(
                                emoji: '👑',
                                title: '30-day streak',
                                subtitle: 'Crown badge + exclusive voucher',
                                trailing: streak >= 30
                                    ? 'Earned'
                                    : '${streak.clamp(0, 30)}/30',
                                progress: streak >= 30 ? null : (streak / 30),
                                isLocked: streak < 30,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cardBorder, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "TODAY'S TASK",
                                style: TextStyle(
                                  color: Color(0xFFC45F12),
                                  letterSpacing: 0.7,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isEligible
                                    ? 'Open the app today'
                                    : 'Join your first event',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 30 / 1.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEligible
                                    ? 'You are building consistency. Keep showing up and own your streak!'
                                    : 'You need at least 1 joined event to start streak tracking.',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.66),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed(AllEventsScreen.routeName),
                                style: FilledButton.styleFrom(
                                  backgroundColor: header,
                                  minimumSize: const Size(double.infinity, 46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Browse events',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Streak updates daily after 12am. Missing a day resets the streak.',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeekStreakRow extends StatelessWidget {
  final int streak;
  const _WeekStreakRow({required this.streak});

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayIndex = DateTime.now().weekday - 1;
    final doneIndices = <int>{};
    final completedBeforeToday = (streak - 1).clamp(0, labels.length - 1);
    for (var offset = 1; offset <= completedBeforeToday; offset++) {
      final idx = (todayIndex - offset) % labels.length;
      doneIndices.add(idx < 0 ? idx + labels.length : idx);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int i = 0; i < labels.length; i++)
          _DayPill(
            label: labels[i],
            isDone: doneIndices.contains(i),
            isToday: i == todayIndex,
          ),
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isToday;

  const _DayPill({
    required this.label,
    required this.isDone,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isToday
        ? Colors.white
        : Colors.white.withValues(alpha: 0.35);
    final fill = isDone ? const Color(0xFFF58A1D) : Colors.transparent;
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: isToday ? 3 : 2),
          ),
          alignment: Alignment.center,
          child: Text(
            isDone
                ? '✓'
                : isToday
                ? '🔥'
                : '',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: isToday ? 1 : 0.85),
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final bool isMuted;
  final bool isGoldBorder;

  const _StatCard({
    required this.value,
    required this.label,
    this.isMuted = false,
    this.isGoldBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = isGoldBorder
        ? const Color(0xFFEBC43A)
        : const Color(0xFFE4A055);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isMuted ? const Color(0xFFF0F1F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 36 / 1.6,
              color: isMuted
                  ? const Color(0xFF10192B)
                  : const Color(0xFF9C3F11),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.45),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;
  final double? progress;
  final Color progressColor;
  final bool isLocked;

  const _MilestoneRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.trailing = '',
    this.trailingColor = const Color(0xFFC94F0B),
    this.progress,
    this.progressColor = const Color(0xFFE86F12),
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final alpha = isLocked ? 0.35 : 1.0;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F2ED).withValues(alpha: alpha),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: TextStyle(
                fontSize: 22,
                color: Colors.black.withValues(alpha: alpha),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.black.withValues(alpha: alpha),
                        ),
                      ),
                    ),
                    Text(
                      trailing,
                      style: TextStyle(
                        color: trailingColor.withValues(alpha: alpha),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.5 * alpha),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  _SmoothLinearProgress(
                    value: progress!,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFDFDFDD),
                    valueColor: progressColor,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmoothLinearProgress extends StatelessWidget {
  final double value;
  final double minHeight;
  final Color backgroundColor;
  final Color valueColor;

  const _SmoothLinearProgress({
    required this.value,
    required this.minHeight,
    required this.backgroundColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: safeValue),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) {
          return LinearProgressIndicator(
            minHeight: minHeight,
            value: animatedValue,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation(valueColor),
          );
        },
      ),
    );
  }
}
