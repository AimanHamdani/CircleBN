import 'package:flutter/material.dart';

import '../../../data/membership_repository.dart';

// Sportly-inspired warm palette (CircleBN Pro paywall).
abstract final class _ProColors {
  static const Color cream = Color(0xFFFFFBF0);
  static const Color creamDeep = Color(0xFFFFF7E6);
  static const Color brown = Color(0xFF5C3D2E);
  static const Color brownMuted = Color(0xFF8B6914);
  static const Color gold = Color(0xFFE5A832);
  static const Color goldDeep = Color(0xFFC2780A);
  static const Color orange = Color(0xFFF97316);
  static const Color orangeDeep = Color(0xFFEA580C);
  static const Color divider = Color(0xFFE8DDD0);
  static const Color tableHeaderBg = Color(0xFFF3EDE4);
}

String _formatRenewal(DateTime d) {
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
  final local = d.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

/// Mock paywall with rich explanation, plan picker, and Free vs Pro comparison.
class MembershipScreen extends StatefulWidget {
  static const routeName = '/profile/membership';

  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  late Future<MembershipStatus> _statusFuture;
  String? _busyPlanId;
  String _selectedPlanId = 'yearly';

  @override
  void initState() {
    super.initState();
    _statusFuture = membershipRepository().getStatus();
  }

  void _reload() {
    setState(() {
      _statusFuture = membershipRepository().getStatus();
    });
  }

  Future<void> _subscribe(String planId) async {
    setState(() => _busyPlanId = planId);
    try {
      await membershipRepository().subscribeMock(planId: planId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to CircleBN Pro (demo).')),
      );
      _reload();
    } finally {
      if (mounted) {
        setState(() => _busyPlanId = null);
      }
    }
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel membership?'),
        content: const Text(
          'This demo removes Pro access immediately. '
          'A real app would keep benefits until the billing period ends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Pro'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    setState(() => _busyPlanId = 'cancel');
    try {
      await membershipRepository().cancelMock();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pro cancelled (demo).')),
      );
      _reload();
    } finally {
      if (mounted) {
        setState(() => _busyPlanId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ProColors.cream,
      appBar: AppBar(
        backgroundColor: _ProColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _ProColors.brown.withValues(alpha: 0.9)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'CircleBN Pro',
          style: TextStyle(
            color: _ProColors.brown,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<MembershipStatus>(
        future: _statusFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done &&
              snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final status = snap.data ?? MembershipStatus.none();

          if (status.isPremium) {
            return _buildSubscribedBody(context, status);
          }
          return _buildPaywallBody(context);
        },
      ),
    );
  }

  Widget _buildSubscribedBody(BuildContext context, MembershipStatus status) {
    final renews = status.renewsAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        _HeroBanner(
          isPremium: true,
          planLabel: status.planLabel,
          renewsText: renews == null
              ? 'Active until canceled'
              : 'Renews ${_formatRenewal(renews)}',
        ),
        const SizedBox(height: 20),
        _WhatsIncludedCard(items: _benefitItems()),
        const SizedBox(height: 16),
        _FreeVsProTable(),
        const SizedBox(height: 24),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: _ProColors.brown,
            side: BorderSide(color: _ProColors.brown.withValues(alpha: 0.35)),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _busyPlanId != null ? null : _confirmCancel,
          child: _busyPlanId == 'cancel'
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Cancel membership (demo)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
        const SizedBox(height: 14),
        Text(
          'No real payment is processed. This flow is for UI and testing only.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.42),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildPaywallBody(BuildContext context) {
    final ctaBusy = _busyPlanId == _selectedPlanId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
      children: [
        _HeroBanner(
          isPremium: false,
          planLabel: '',
          renewsText: '',
        ),
        const SizedBox(height: 18),
        _PlanPickerRow(
          selectedId: _selectedPlanId,
          onSelect: (id) => setState(() => _selectedPlanId = id),
        ),
        const SizedBox(height: 22),
        _WhatsIncludedCard(items: _benefitItems()),
        const SizedBox(height: 16),
        _FreeVsProTable(),
        const SizedBox(height: 24),
        _GradientCtaButton(
          label: _selectedPlanId == 'yearly'
              ? '👑  Start Pro — \$39.99 / year'
              : '👑  Start Pro — \$4.99 / month',
          busy: ctaBusy,
          onPressed: ctaBusy
              ? null
              : () => _subscribe(_selectedPlanId),
        ),
        const SizedBox(height: 12),
        Text(
          '7-day free trial · Cancel anytime · Billed ${_selectedPlanId == 'yearly' ? 'annually' : 'monthly'} (demo copy)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ProColors.brownMuted.withValues(alpha: 0.75),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Prices are placeholders. No app store or card is charged.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.4),
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  List<_BenefitItem> _benefitItems() {
    return [
      _BenefitItem(
        title: 'Ad-free experience',
        description:
            'No banners, no pop-ups, no interruptions. Browse events, clubs, and chats without clutter.',
        freeNote: 'Available on Free: Ads shown',
        iconBg: const Color(0xFFFFF4D6),
        icon: const Text('🚫', style: TextStyle(fontSize: 22)),
      ),
      _BenefitItem(
        title: 'Full game statistics',
        description:
            'See personal stats from every match — wins, losses, streaks, skill progression, and per-sport breakdowns.',
        freeNote: 'Available on Free: Basic stats only',
        iconBg: const Color(0xFFE8E6FF),
        icon: const Text('📊', style: TextStyle(fontSize: 22)),
      ),
      _BenefitItem(
        title: 'Detailed skill tracking',
        description:
            'View skill points, level progress, and how you compare across events and sports.',
        freeNote: 'Available on Free: Level number only',
        iconBg: const Color(0xFFF3E8FF),
        icon: const Text('🏅', style: TextStyle(fontSize: 22)),
      ),
      _BenefitItem(
        title: 'Full match history',
        description:
            'Complete game history with per-match stats, opponents, and outcomes from your first event onward.',
        freeNote: 'Available on Free: Last 5 matches only',
        iconBg: const Color(0xFFE8F8EF),
        icon: const Text('📋', style: TextStyle(fontSize: 22)),
      ),
    ];
  }
}

class _HeroBanner extends StatelessWidget {
  final bool isPremium;
  final String planLabel;
  final String renewsText;

  const _HeroBanner({
    required this.isPremium,
    required this.planLabel,
    required this.renewsText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF5D565),
            Color(0xFFF59E0B),
            Color(0xFFF97316),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _ProColors.orange.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        children: [
          const Text('👑', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 6),
          Text(
            'CircleBN Pro',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPremium
                ? 'You have the full CircleBN experience.'
                : 'Unlock the full CircleBN experience.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Text(
              isPremium
                  ? '✓  Pro · $planLabel · $renewsText'
                  : '⚡  Currently on Free plan',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPickerRow extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _PlanPickerRow({
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SelectablePlanCard(
            label: 'MONTHLY',
            price: r'$4.99',
            subPrice: 'per month',
            selected: selectedId == 'monthly',
            saveBadge: null,
            monthlyEquiv: null,
            onTap: () => onSelect('monthly'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SelectablePlanCard(
            label: 'YEARLY',
            price: r'$39.99',
            subPrice: 'per year',
            monthlyEquiv: r'$3.33 / month',
            selected: selectedId == 'yearly',
            saveBadge: 'Save 33%',
            onTap: () => onSelect('yearly'),
          ),
        ),
      ],
    );
  }
}

class _SelectablePlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String subPrice;
  final String? monthlyEquiv;
  final String? saveBadge;
  final bool selected;
  final VoidCallback onTap;

  const _SelectablePlanCard({
    required this.label,
    required this.price,
    required this.subPrice,
    required this.selected,
    required this.onTap,
    this.monthlyEquiv,
    this.saveBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFFF5F0E8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _ProColors.gold : _ProColors.divider,
              width: selected ? 2.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _ProColors.gold.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (saveBadge != null)
                Positioned(
                  right: -4,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _ProColors.orangeDeep,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      saveBadge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: _ProColors.brownMuted.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    style: TextStyle(
                      color: selected ? _ProColors.brown : Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subPrice,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  if (monthlyEquiv != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      monthlyEquiv!,
                      style: TextStyle(
                        color: _ProColors.brownMuted.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected ? _ProColors.goldDeep : Colors.black38,
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitItem {
  final String title;
  final String description;
  final String freeNote;
  final Color iconBg;
  final Widget icon;

  _BenefitItem({
    required this.title,
    required this.description,
    required this.freeNote,
    required this.iconBg,
    required this.icon,
  });
}

class _WhatsIncludedCard extends StatelessWidget {
  final List<_BenefitItem> items;

  const _WhatsIncludedCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _ProColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              "What's included",
              style: TextStyle(
                color: _ProColors.brown,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: _ProColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: _BenefitRow(item: items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final _BenefitItem item;

  const _BenefitRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: item.iconBg,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: item.icon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF292524),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _ProColors.creamDeep,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _ProColors.divider.withValues(alpha: 0.8),
                  ),
                ),
                child: Text(
                  item.freeNote,
                  style: TextStyle(
                    color: _ProColors.brownMuted.withValues(alpha: 0.95),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FreeVsProTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rows = <_CmpRow>[
      _CmpRow(
        feature: 'Ads',
        freeText: '',
        freeIsBad: true,
        proOk: true,
      ),
      _CmpRow(
        feature: 'Game stats',
        freeText: 'Basic',
        freeIsBad: false,
        proOk: true,
      ),
      _CmpRow(
        feature: 'Match history',
        freeText: '5 matches',
        freeIsBad: false,
        proOk: true,
      ),
      _CmpRow(
        feature: 'Skill tracking',
        freeText: 'Level only',
        freeIsBad: false,
        proOk: true,
      ),
      _CmpRow(
        feature: 'Create events',
        freeText: '',
        freeIsBad: false,
        proOk: true,
        freeCheck: true,
      ),
      _CmpRow(
        feature: 'Join clubs',
        freeText: '',
        freeIsBad: false,
        proOk: true,
        freeCheck: true,
      ),
      _CmpRow(
        feature: 'Streaks & badges',
        freeText: '',
        freeIsBad: false,
        proOk: true,
        freeCheck: true,
      ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _ProColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(
              'Free vs Pro',
              style: TextStyle(
                color: _ProColors.brown,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          Container(
            color: _ProColors.tableHeaderBg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'Feature',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: _ProColors.brownMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Free',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: _ProColors.brownMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Pro 👑',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: _ProColors.brownMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: _ProColors.divider),
            _ComparisonRowWidget(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _CmpRow {
  final String feature;
  final String freeText;
  final bool freeIsBad;
  final bool proOk;
  final bool freeCheck;

  _CmpRow({
    required this.feature,
    required this.freeText,
    required this.freeIsBad,
    required this.proOk,
    this.freeCheck = false,
  });
}

class _ComparisonRowWidget extends StatelessWidget {
  final _CmpRow row;

  const _ComparisonRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              row.feature,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF44403C),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _FreeCell(row: row),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: row.proOk
                  ? Icon(Icons.check_circle, color: Colors.green.shade600, size: 22)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeCell extends StatelessWidget {
  final _CmpRow row;

  const _FreeCell({required this.row});

  @override
  Widget build(BuildContext context) {
    if (row.feature == 'Ads') {
      return Center(
        child: Icon(Icons.cancel, color: Colors.red.shade400, size: 22),
      );
    }
    if (row.freeCheck) {
      return Center(
        child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
      );
    }
    return Text(
      row.freeText,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: Colors.black.withValues(alpha: 0.55),
      ),
    );
  }
}

class _GradientCtaButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  const _GradientCtaButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: busy ? null : onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF7C2D12),
                Color(0xFF9A3412),
                Color(0xFFEA580C),
                Color(0xFFF97316),
              ],
              stops: [0.0, 0.25, 0.65, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: _ProColors.orange.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
