import 'package:flutter/material.dart';

import '../../../data/achievement_repository.dart';

class RedeemPointsScreen extends StatefulWidget {
  static const routeName = '/redeem-points';

  const RedeemPointsScreen({super.key});

  @override
  State<RedeemPointsScreen> createState() => _RedeemPointsScreenState();
}

class _RedeemPointsScreenState extends State<RedeemPointsScreen> {
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

  int _streakRedeemPoints(int streak) {
    if (streak <= 0) return 0;
    if (streak <= 7) return 50 + ((streak - 1) * 25);
    var total = 200;
    if (streak >= 14) total += 500;
    if (streak >= 30) total += 700;
    return total;
  }

  int _pointsForBadge(BadgeProgress progress) {
    switch (progress.badge.id) {
      case 'events_joined_1':
        return 50;
      case 'events_created_1':
        return 75;
      case 'clubs_created_1':
      case 'clubs_joined_3':
        return 100;
      case 'streak_7':
      case 'events_joined_5':
        return 150;
      case 'events_created_5':
        return 200;
      case 'events_joined_15':
        return 300;
      case 'streak_14':
        return 350;
      case 'events_created_10':
        return 500;
      case 'events_joined_30':
        return 600;
      case 'streak_30':
        return 750;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8F2EA);
    const header = Color(0xFFE8A100);
    const headerDeep = Color(0xFFB9660C);

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
        final unlockedBadges = data?.unlockedBadges ?? const <BadgeProgress>[];
        final joinedEvents = data?.joinedEventsCount ?? 0;

        final streakPoints = _streakRedeemPoints(streak);
        final badgePoints = unlockedBadges.fold<int>(
          0,
          (sum, item) => sum + _pointsForBadge(item),
        );
        final eventPoints = joinedEvents * 50;
        final totalPoints = streakPoints + badgePoints + eventPoints;

        final vouchers = <_Voucher>[
          const _Voucher(
            title: '10% Off Court Booking',
            subtitle: 'Kallang Badminton Centre · Expires 31 Dec',
            icon: '🎾',
            cost: 150,
          ),
          const _Voucher(
            title: 'Free Delivery',
            subtitle: 'SportXL Online Store · Expires 15 Nov',
            icon: '👟',
            cost: 100,
          ),
          const _Voucher(
            title: 'Free Sports Drink',
            subtitle: '100Plus · Used on 10 Sep',
            icon: '🥤',
            cost: 50,
            isUsed: true,
          ),
          const _Voucher(
            title: 'Free Event Entry',
            subtitle: 'Any Sportly event · No expiry',
            icon: '🏟️',
            cost: 500,
          ),
        ];

        return Scaffold(
          backgroundColor: background,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
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
                              'Redeem Points',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 40, height: 40),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _BalanceCard(points: totalPoints),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('HOW YOU EARNED IT'),
                        const SizedBox(height: 8),
                        _EarnedBreakdownCard(
                          streakPoints: streakPoints,
                          badgePoints: badgePoints,
                          eventPoints: eventPoints,
                        ),
                        const SizedBox(height: 14),
                        const _SectionTitle('REDEEM FOR REWARDS'),
                        const SizedBox(height: 8),
                        for (int i = 0; i < vouchers.length; i++) ...[
                          _VoucherCard(
                            voucher: vouchers[i],
                            totalPoints: totalPoints,
                          ),
                          if (i != vouchers.length - 1) const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4D9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE8B230)),
                          ),
                          child: const Text(
                            '💡 Vouchers are single-use and sent to your email when redeemed. Coupons are mock and not real purchases.',
                            style: TextStyle(
                              color: Color(0xFF8A5A00),
                              fontWeight: FontWeight.w700,
                            ),
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

class _BalanceCard extends StatelessWidget {
  final int points;
  const _BalanceCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3AA3D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available balance',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$points pts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 48 / 1.6,
                  ),
                ),
              ],
            ),
          ),
          const Text('🎁', style: TextStyle(fontSize: 36)),
        ],
      ),
    );
  }
}

class _EarnedBreakdownCard extends StatelessWidget {
  final int streakPoints;
  final int badgePoints;
  final int eventPoints;

  const _EarnedBreakdownCard({
    required this.streakPoints,
    required this.badgePoints,
    required this.eventPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8B230), width: 1.4),
      ),
      child: Column(
        children: [
          _EarnRow(icon: '🔥', label: 'Streak rewards', points: streakPoints),
          const Divider(height: 16),
          _EarnRow(icon: '🏅', label: 'Badges earned', points: badgePoints),
          const Divider(height: 16),
          _EarnRow(icon: '⚽', label: 'Joining events', points: eventPoints),
        ],
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  final String icon;
  final String label;
  final int points;

  const _EarnRow({
    required this.icon,
    required this.label,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(icon),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18 / 1.3),
          ),
        ),
        Text(
          '+$points pts',
          style: const TextStyle(
            color: Color(0xFFB05907),
            fontWeight: FontWeight.w900,
            fontSize: 18 / 1.3,
          ),
        ),
      ],
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final _Voucher voucher;
  final int totalPoints;

  const _VoucherCard({required this.voucher, required this.totalPoints});

  @override
  Widget build(BuildContext context) {
    final notEnough = totalPoints < voucher.cost;
    final disabled = voucher.isUsed || notEnough;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF3F3F1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8B230), width: 1.4),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(voucher.icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20 / 1.3,
                        color: disabled ? const Color(0xFF9DA2AA) : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      voucher.subtitle,
                      style: TextStyle(
                        color: disabled
                            ? const Color(0xFFB0B5BD)
                            : Colors.black.withValues(alpha: 0.48),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 1,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.black.withValues(alpha: 0.18),
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                notEnough ? '${voucher.cost} pts needed' : '${voucher.cost} pts',
                style: TextStyle(
                  color: notEnough
                      ? const Color(0xFFE16B5D)
                      : const Color(0xFF9C3F11),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: disabled ? null : () {},
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFBE7A0A),
                  disabledBackgroundColor: const Color(0xFFE4E4DF),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFFAFB3BA),
                  minimumSize: const Size(110, 36),
                ),
                child: Text(voucher.isUsed ? 'Used' : (notEnough ? 'Not enough' : 'Redeem')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF8A4A03),
        letterSpacing: 0.8,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _Voucher {
  final String title;
  final String subtitle;
  final String icon;
  final int cost;
  final bool isUsed;

  const _Voucher({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.cost,
    this.isUsed = false,
  });
}
