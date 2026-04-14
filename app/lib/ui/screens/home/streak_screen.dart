import 'package:flutter/material.dart';

import 'all_events_screen.dart';

class StreakScreen extends StatelessWidget {
  static const routeName = '/streak';

  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8F2EA);
    const header = Color(0xFFE86F12);
    const headerDeep = Color(0xFFD55F0E);
    const cardBorder = Color(0xFFE4A055);

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
                      const SizedBox(width: 38),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('🔥', style: TextStyle(fontSize: 58)),
                  const Text(
                    '5',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 76,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'day streak',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 35 / 1.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join an event today to keep it going!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _WeekStreakRow(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: _StatCard(value: '5', label: 'Current'),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            value: '12',
                            label: 'Best ever',
                            isMuted: true,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            value: '240',
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
                      child: const Column(
                        children: [
                          _MilestoneRow(
                            emoji: '🔥',
                            title: '7-day streak',
                            subtitle: 'Unlock a voucher reward',
                            progress: 5 / 7,
                            trailing: '5/7',
                            progressColor: Color(0xFFE86F12),
                          ),
                          Divider(height: 1, color: Color(0xFFFFD2A6)),
                          _MilestoneRow(
                            emoji: '⚡',
                            title: '14-day streak',
                            subtitle: 'Earn a Gold badge',
                            progress: 5 / 14,
                            trailing: '5/14',
                            trailingColor: Color(0xFF4A58D8),
                            progressColor: Color(0xFF646CE9),
                          ),
                          Divider(height: 1, color: Color(0xFFFFD2A6)),
                          _MilestoneRow(
                            emoji: '👑',
                            title: '30-day streak',
                            subtitle: 'Crown badge + exclusive voucher',
                            trailing: 'Locked',
                            isLocked: true,
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
                          const Text(
                            'Join or create an event',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 30 / 1.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Any sport counts - keep the streak alive!',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.66),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pushNamed(AllEventsScreen.routeName),
                            style: FilledButton.styleFrom(
                              backgroundColor: header,
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Browse events →',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
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
  }
}

class _WeekStreakRow extends StatelessWidget {
  const _WeekStreakRow();

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int i = 0; i < labels.length; i++)
          _DayPill(label: labels[i], isDone: i < 4, isToday: i == 4),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: progress,
                      backgroundColor: const Color(0xFFDFDFDD),
                      valueColor: AlwaysStoppedAnimation(progressColor),
                    ),
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
