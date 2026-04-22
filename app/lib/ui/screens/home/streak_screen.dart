import 'package:flutter/material.dart';

import '../../../data/achievement_repository.dart';
import 'all_events_screen.dart';
import 'redeem_points_screen.dart';

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
                          const SizedBox(width: 40, height: 40),
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
                              child: _StatCard(value: '$streak', label: 'Current'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                value: '$best',
                                label: 'Best ever',
                                isMuted: true,
                              ),
                            ),
                          ],
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
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed(RedeemPointsScreen.routeName),
                          icon: const Icon(Icons.card_giftcard),
                          label: const Text('Go to Redeem Points'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
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

  const _StatCard({
    required this.value,
    required this.label,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isMuted ? const Color(0xFFF0F1F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4A055), width: 1.5),
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
