import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/current_user.dart';
import '../../../data/achievement_repository.dart';
import '../../../data/badge_display_repository.dart';

class AchievementsScreen extends StatefulWidget {
  static const routeName = '/achievements';

  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late Future<AchievementSnapshot> _future;
  static AchievementSnapshot? _cachedSnapshot;
  Set<String> _selectedBadgeIds = <String>{};
  bool _selectedLoaded = false;
  bool _checkedNewUnlocks = false;

  Map<String, String?> _buildPrerequisiteMap(List<BadgeProgress> allBadges) {
    final byCategory = <BadgeCategory, List<BadgeProgress>>{};
    for (final badge in allBadges) {
      byCategory.putIfAbsent(badge.badge.category, () => <BadgeProgress>[]);
      byCategory[badge.badge.category]!.add(badge);
    }
    final prerequisiteById = <String, String?>{};
    for (final entry in byCategory.entries) {
      final list = entry.value
        ..sort((a, b) {
          final targetCompare = a.badge.target.compareTo(b.badge.target);
          if (targetCompare != 0) {
            return targetCompare;
          }
          return a.badge.id.compareTo(b.badge.id);
        });
      for (var i = 0; i < list.length; i++) {
        prerequisiteById[list[i].badge.id] = i == 0 ? null : list[i - 1].badge.id;
      }
    }
    return prerequisiteById;
  }

  int _badgePoints(String badgeId) {
    switch (badgeId) {
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
  void initState() {
    super.initState();
    _future = _loadSnapshot();
    _loadSelectedBadges();
  }

  Future<AchievementSnapshot> _loadSnapshot() async {
    final snapshot = await achievementRepository().getMySnapshot();
    _cachedSnapshot = snapshot;
    return snapshot;
  }

  Future<void> _loadSelectedBadges() async {
    final selected = await badgeDisplayRepository().getSelectedBadgeIds(
      currentUserId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBadgeIds = selected;
      _selectedLoaded = true;
    });
  }

  Future<void> _toggleDisplayedBadge({
    required BadgeProgress badge,
    required Set<String> unlockedIds,
  }) async {
    if (!badge.isUnlocked) {
      return;
    }
    final next = Set<String>.from(_selectedBadgeIds);
    if (next.contains(badge.badge.id)) {
      next.remove(badge.badge.id);
    } else {
      next.add(badge.badge.id);
    }
    next.removeWhere((id) => !unlockedIds.contains(id));
    await badgeDisplayRepository().saveSelectedBadgeIds(
      userId: currentUserId,
      badgeIds: next,
    );
    if (!mounted) {
      return;
    }
    final wasSelected = _selectedBadgeIds.contains(badge.badge.id);
    final isNowDisplayed = !wasSelected;
    if (isNowDisplayed) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _selectedBadgeIds = next;
    });
    _showBadgeSelectionFeedback(
      badgeName: badge.badge.name,
      isDisplayed: isNowDisplayed,
    );
  }

  Future<void> _showBadgeSelectionFeedback({
    required String badgeName,
    required bool isDisplayed,
  }) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final icon = isDisplayed ? Icons.celebration : Icons.visibility_off;
        final iconColor = isDisplayed
            ? const Color(0xFF3AA36B)
            : const Color(0xFF6F7A87);
        final title = isDisplayed
            ? 'Displayed on profile'
            : 'Removed from profile';
        final subtitle = isDisplayed
            ? '$badgeName will now appear on your profile.'
            : '$badgeName is hidden from your profile.';
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.85, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE4E8EF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.62),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkForNewUnlockCelebration(
    AchievementSnapshot snapshot,
  ) async {
    final unlocked = snapshot.unlockedBadges;
    if (unlocked.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'seen_unlocked_badges_$currentUserId';
    final seen = prefs.getStringList(key)?.toSet() ?? <String>{};
    final unlockedIds = unlocked.map((b) => b.badge.id).toSet();
    final newlyUnlocked = unlocked
        .where((b) => !seen.contains(b.badge.id))
        .toList(growable: false);

    if (!mounted) {
      return;
    }

    if (newlyUnlocked.isNotEmpty) {
      HapticFeedback.heavyImpact();
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _AchievementCelebrationDialog(
          unlockedCount: newlyUnlocked.length,
          badgeName: newlyUnlocked.first.badge.name,
        ),
      );
    }

    await prefs.setStringList(key, unlockedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    const headerTop = Color(0xFF3E3DA8);
    const headerBottom = Color(0xFF5D5AE8);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFEDEFF4),
        body: FutureBuilder<AchievementSnapshot>(
          future: _future,
          initialData: _cachedSnapshot,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final unlockedBadges = data?.unlockedBadges ?? const <BadgeProgress>[];
            final unlocked = unlockedBadges.length;
            final total = data?.allBadges.length ?? 0;
            final progress = total == 0 ? 0.0 : unlocked / total;
            final earnedPoints = unlockedBadges.fold<int>(
              0,
              (sum, badge) => sum + _badgePoints(badge.badge.id),
            );
            final unlockedIds =
                (data?.unlockedBadges ?? const <BadgeProgress>[])
                    .map((e) => e.badge.id)
                    .toSet();
            final allBadges = data?.allBadges ?? const <BadgeProgress>[];
            final prerequisites = _buildPrerequisiteMap(allBadges);
            final availableInProgress = allBadges.where((badge) {
              if (badge.isUnlocked) {
                return false;
              }
              final prerequisiteId = prerequisites[badge.badge.id];
              return prerequisiteId == null || unlockedIds.contains(prerequisiteId);
            }).toList();
            final lockedBadges = allBadges.where((badge) {
              if (badge.isUnlocked) {
                return false;
              }
              final prerequisiteId = prerequisites[badge.badge.id];
              return prerequisiteId != null && !unlockedIds.contains(prerequisiteId);
            }).toList();
            if (snapshot.connectionState == ConnectionState.done &&
                _selectedLoaded &&
                _selectedBadgeIds.any((id) => !unlockedIds.contains(id))) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final filtered = _selectedBadgeIds
                    .where(unlockedIds.contains)
                    .toSet();
                await badgeDisplayRepository().saveSelectedBadgeIds(
                  userId: currentUserId,
                  badgeIds: filtered,
                );
                if (!mounted) {
                  return;
                }
                setState(() {
                  _selectedBadgeIds = filtered;
                });
              });
            }
            if (snapshot.connectionState == ConnectionState.done &&
                data != null &&
                !_checkedNewUnlocks) {
              _checkedNewUnlocks = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkForNewUnlockCelebration(data);
              });
            }
            return SafeArea(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [headerTop, headerBottom],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () => Navigator.of(context).maybePop(),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Achievements',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 38),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '🏅',
                                style: TextStyle(fontSize: 32),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: unlocked.toDouble(),
                                    ),
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, animated, _) {
                                      return Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: animated.round().toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 44,
                                              ),
                                            ),
                                            TextSpan(
                                              text: ' / $total',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.7,
                                                ),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 30,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  Text(
                                    'badges earned',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _SmoothLinearProgress(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.25,
                                    ),
                                    valueColor: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 72,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$earnedPoints',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 32 / 1.6,
                                    ),
                                  ),
                                  Text(
                                    'pts earned',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: const Color(0xFFE7E9EF),
                    child: const TabBar(
                      labelColor: Color(0xFF4B4AE0),
                      unselectedLabelColor: Color(0xFF6F7A87),
                      indicatorColor: Color(0xFF4B4AE0),
                      labelStyle: TextStyle(fontWeight: FontWeight.w800),
                      tabs: [
                        Tab(text: 'Earned'),
                        Tab(text: 'In progress'),
                        Tab(text: 'Locked'),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        snapshot.connectionState != ConnectionState.done &&
                            data == null
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            children: [
                              _AllBadgeSections(
                                earnedBadges: unlockedBadges,
                                inProgressBadges: availableInProgress,
                                lockedBadges: lockedBadges,
                                selectedBadgeIds: _selectedBadgeIds,
                                onToggleSelected: (badge) {
                                  _toggleDisplayedBadge(
                                    badge: badge,
                                    unlockedIds: unlockedIds,
                                  );
                                },
                                pointsForBadge: _badgePoints,
                              ),
                              _BadgeList(
                                badges: availableInProgress,
                                emptyLabel: 'No in-progress badges yet.',
                                selectedBadgeIds: _selectedBadgeIds,
                                pointsForBadge: _badgePoints,
                              ),
                              _BadgeList(
                                badges: lockedBadges,
                                emptyLabel: 'No locked badges.',
                                selectedBadgeIds: _selectedBadgeIds,
                                isLockedList: true,
                                pointsForBadge: _badgePoints,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AchievementCelebrationDialog extends StatelessWidget {
  final int unlockedCount;
  final String badgeName;

  const _AchievementCelebrationDialog({
    required this.unlockedCount,
    required this.badgeName,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = unlockedCount == 1
        ? 'You unlocked "$badgeName". Keep it going!'
        : 'You unlocked $unlockedCount new badges. Keep it going!';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E9F4)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 8),
                  const Text(
                    'Achievement Unlocked!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Awesome'),
                  ),
                ],
              ),
            ),
            const Positioned(top: -8, left: 14, child: Text('✨')),
            const Positioned(top: -10, right: 20, child: Text('🎊')),
            const Positioned(bottom: -8, left: 24, child: Text('✨')),
            const Positioned(bottom: -10, right: 26, child: Text('🎉')),
          ],
        ),
      ),
    );
  }
}

class _AllBadgeSections extends StatelessWidget {
  final List<BadgeProgress> earnedBadges;
  final List<BadgeProgress> inProgressBadges;
  final List<BadgeProgress> lockedBadges;
  final Set<String> selectedBadgeIds;
  final ValueChanged<BadgeProgress>? onToggleSelected;
  final int Function(String badgeId) pointsForBadge;

  const _AllBadgeSections({
    required this.earnedBadges,
    required this.inProgressBadges,
    required this.lockedBadges,
    required this.selectedBadgeIds,
    this.onToggleSelected,
    required this.pointsForBadge,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      children: [
        _SectionLabel(label: 'Earned'),
        const SizedBox(height: 10),
        _BadgeList(
          badges: earnedBadges,
          emptyLabel: 'No earned badges yet.',
          selectedBadgeIds: selectedBadgeIds,
          onToggleSelected: onToggleSelected,
          pointsForBadge: pointsForBadge,
          embedded: true,
        ),
        const SizedBox(height: 14),
        _SectionLabel(label: 'In progress'),
        const SizedBox(height: 10),
        _BadgeList(
          badges: inProgressBadges,
          emptyLabel: 'No in-progress badges yet.',
          selectedBadgeIds: selectedBadgeIds,
          pointsForBadge: pointsForBadge,
          embedded: true,
        ),
        const SizedBox(height: 14),
        _SectionLabel(label: 'Locked'),
        const SizedBox(height: 10),
        _BadgeList(
          badges: lockedBadges,
          emptyLabel: 'No locked badges.',
          selectedBadgeIds: selectedBadgeIds,
          isLockedList: true,
          pointsForBadge: pointsForBadge,
          embedded: true,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF2F3DAA),
        letterSpacing: 0.8,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _BadgeList extends StatelessWidget {
  final List<BadgeProgress> badges;
  final String emptyLabel;
  final Set<String> selectedBadgeIds;
  final ValueChanged<BadgeProgress>? onToggleSelected;
  final bool isLockedList;
  final int Function(String badgeId) pointsForBadge;
  final bool embedded;

  const _BadgeList({
    required this.badges,
    required this.emptyLabel,
    required this.selectedBadgeIds,
    this.onToggleSelected,
    this.isLockedList = false,
    required this.pointsForBadge,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (embedded) {
      return Column(
        children: [
          for (int index = 0; index < badges.length; index++) ...[
            _BadgeCard(
              item: badges[index],
              isLocked: isLockedList,
              points: pointsForBadge(badges[index].badge.id),
              isSelectedForProfile: selectedBadgeIds.contains(
                badges[index].badge.id,
              ),
              onToggleSelected: onToggleSelected == null
                  ? null
                  : () => onToggleSelected!(badges[index]),
            ),
            if (index != badges.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      itemCount: badges.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = badges[index];
        return _BadgeCard(
          item: item,
          isLocked: isLockedList,
          points: pointsForBadge(item.badge.id),
          isSelectedForProfile: selectedBadgeIds.contains(item.badge.id),
          onToggleSelected: onToggleSelected == null
              ? null
              : () => onToggleSelected!(item),
        );
      },
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeProgress item;
  final bool isLocked;
  final int points;
  final bool isSelectedForProfile;
  final VoidCallback? onToggleSelected;

  const _BadgeCard({
    required this.item,
    this.isLocked = false,
    required this.points,
    required this.isSelectedForProfile,
    this.onToggleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final earned = item.isUnlocked;
    final softBg = isLocked
        ? const Color(0xFFF1F2F4)
        : (earned ? const Color(0xFFF1F5F2) : const Color(0xFFF5F3F0));
    final badgeBg = isLocked
        ? const Color(0xFFE5E7EB)
        : (earned ? const Color(0xFFCEE7DA) : const Color(0xFFEAE7E3));
    final chipBg = isLocked
        ? const Color(0xFFE5E7EB)
        : (earned ? const Color(0xFFD9ECE2) : const Color(0xFFE9E8E6));
    final progressColor = earned
        ? const Color(0xFF3AA36B)
        : const Color(0xFFE2751D);
    return _PressableCard(
      onTap: earned && onToggleSelected != null ? onToggleSelected : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: softBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLocked ? const Color(0xFFD6DAE2) : const Color(0xFF96A4F9),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.badge.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.badge.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 24 / 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.badge.description,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isLocked ? 'Locked' : item.progressLabel,
                        style: TextStyle(
                          color: isLocked
                              ? const Color(0xFF7A828D)
                              : earned
                              ? const Color(0xFF2E8A5D)
                              : const Color(0xFF8D7E6D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '+$points pts',
                      style: TextStyle(
                        color: isLocked
                            ? const Color(0xFFA6AFBC)
                            : earned
                            ? const Color(0xFF0F8D53)
                            : const Color(0xFF0F8D53),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (earned && !isLocked) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onToggleSelected,
                  icon: Icon(
                    isSelectedForProfile
                        ? Icons.visibility
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(
                    isSelectedForProfile
                        ? 'Displayed on profile'
                        : 'Display on profile',
                  ),
                ),
              ),
            ],
            if (!earned && !isLocked) ...[
              const SizedBox(height: 10),
              _SmoothLinearProgress(
                value: item.progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFDDDDDA),
                valueColor: progressColor,
              ),
            ],
          ],
        ),
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
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: safeValue),
        duration: const Duration(milliseconds: 560),
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

class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressableCard({required this.child, this.onTap});

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _pressed = false),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.988 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
