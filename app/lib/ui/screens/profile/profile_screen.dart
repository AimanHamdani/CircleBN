import 'dart:typed_data';
import 'dart:math' as math;

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/account_guard.dart';
import '../../../data/achievement_repository.dart';
import '../../../data/badge_display_repository.dart';
import '../../../data/height_display_repository.dart';
import '../../../data/membership_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../data/sample_clubs.dart';
import '../../../models/user_profile.dart';
import '../../../utils/height_display.dart';
import '../home/home_screen.dart';
import '../home/streak_screen.dart';
import 'achievements_screen.dart';
import '../login_screen.dart';
import 'edit_profile_screen.dart';
import 'membership_screen.dart';
import 'free_stats_screen.dart';
import 'pro_stats_screen.dart';
import 'change_password_screen.dart';
import '../../../auth/current_user.dart';
import '../../../auth/session_persistence.dart';

/// Shown per sport when there are no scored matches yet (profile skill section).
const String _kUnlockSportSkillLevelMessage =
    'Play 3 matches to unlock skill level';

const String _kSkillLevelRankHelpBody =
    'Per-sport tiers (Lvl 1–10) line up with rank labels like this:\n\n'
    '1–2 = Beginner\n'
    '3–4 = Novice\n'
    '5–6 = Intermediate\n'
    '7–8 = Advanced\n'
    '9–10 = Pro/Master\n\n'
    'Skill thresholds and level thresholds both refer to this same ladder—how far you have progressed within each sport.';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';

  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _ProfileContentTab { profile, sports, settings }

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile> _future;
  late Future<AchievementSnapshot> _achievementFuture;
  late Future<Set<String>> _displayBadgeIdsFuture;
  late Future<List<Object?>> _pageFuture;
  static List<Object?>? _cachedPageData;
  bool _showAllSportsSkills = false;
  _ProfileContentTab _activeTab = _ProfileContentTab.profile;

  @override
  void initState() {
    super.initState();
    _future = profileRepository().getMyProfile();
    _achievementFuture = achievementRepository().getMySnapshot();
    _displayBadgeIdsFuture = badgeDisplayRepository().getSelectedBadgeIds(
      currentUserId,
    );
    _pageFuture = _buildPageFuture();
  }

  void _reload() {
    setState(() {
      _future = profileRepository().getMyProfile();
      _achievementFuture = achievementRepository().getMySnapshot();
      _displayBadgeIdsFuture = badgeDisplayRepository().getSelectedBadgeIds(
        currentUserId,
      );
      _pageFuture = _buildPageFuture();
    });
  }

  Future<List<Object?>> _buildPageFuture() async {
    final data = await Future.wait<Object?>([
      _future,
      _achievementFuture,
      _displayBadgeIdsFuture,
      heightDisplayRepository().getUseImperial(),
      membershipRepository().getStatus(),
    ]);
    _cachedPageData = data;
    return data;
  }

  int _pointsNeededForTier(int tierLevel) {
    const thresholds = <int>[10, 15, 20, 25, 35, 45, 60, 80, 100];
    if (tierLevel >= 10) {
      return thresholds.last;
    }
    return thresholds[(tierLevel - 1).clamp(0, thresholds.length - 1)];
  }

  void _showSkillLevelHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How skill levels work'),
        content: const SingleChildScrollView(
          child: Text(_kSkillLevelRankHelpBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(HomeScreen.routeName, (_) => false);
  }

  Future<void> _editPreferredSports(UserProfile profile) async {
    final selected = {...profile.preferredSports};
    final updated = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetMaxHeight = MediaQuery.sizeOf(ctx).height * 0.5;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: EdgeInsets.fromLTRB(
                18,
                14,
                18,
                18 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sports Recommendation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Events in these sports will be shown first.',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: sheetMaxHeight),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final sport in SampleData.sports)
                              FilterChip(
                                label: Text(sport),
                                selected: selected.contains(sport),
                                onSelected: (on) {
                                  setLocal(() {
                                    if (on) {
                                      selected.add(sport);
                                    } else {
                                      selected.remove(sport);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(selected),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (updated == null) {
      return;
    }
    try {
      await profileRepository().saveMyProfile(
        profile.copyWith(preferredSports: updated),
      );
      if (mounted) {
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save sports. Ensure Appwrite has a string array attribute '
              'preferredSports on the profiles collection.\n$e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _onDeactivateAccount() async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Step 1 of 3'),
        content: const Text(
          'You are about to deactivate this account. You will be logged out immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (firstConfirm != true) {
      return;
    }

    final typedController = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Step 2 of 3'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type DEACTIVATE to confirm this action.'),
              const SizedBox(height: 10),
              TextField(
                controller: typedController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'DEACTIVATE',
                  isDense: true,
                ),
                onChanged: (_) => setLocal(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  typedController.text.trim().toUpperCase() == 'DEACTIVATE'
                  ? () => Navigator.of(ctx).pop(true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    typedController.dispose();
    if (secondConfirm != true) {
      return;
    }

    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Step 3 of 3'),
        content: const Text('Final confirmation: deactivate this account now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate Account'),
          ),
        ],
      ),
    );
    if (finalConfirm != true) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await deactivateCurrentAccount();
      try {
        await AppwriteService.account.deleteSessions();
      } catch (_) {}
      await SessionPersistence.clear();
      CurrentUser.reset();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Account deactivated.')),
      );
      navigator.pushNamedAndRemoveUntil(LoginScreen.routeName, (_) => false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to deactivate account.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        body: FutureBuilder<List<Object?>>(
          future: _pageFuture,
          initialData: _cachedPageData,
          builder: (context, snap) {
            if (snap.data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile = snap.data![0] as UserProfile;
            final achievements = snap.data![1] as AchievementSnapshot;
            final selectedBadgeIds = snap.data![2] as Set<String>;
            final useImperialHeight = snap.data![3] as bool;
            final membership = snap.data![4] as MembershipStatus;

            final realName = profile.realName.trim().isNotEmpty
                ? profile.realName.trim()
                : 'Name';
            final age = profile.age != null ? '${profile.age}' : '—';
            final gender = profile.gender.trim().isNotEmpty
                ? profile.gender.trim()
                : '—';
            final skillLevel = profile.skillLevel.trim().isNotEmpty
                ? profile.skillLevel.trim()
                : '—';
            final email = profile.email.trim().isNotEmpty
                ? profile.email.trim()
                : '—';
            final emergency = profile.emergencyContact.trim().isNotEmpty
                ? profile.emergencyContact.trim()
                : '—';
            final height = formatHeightForDisplay(
              profile.heightCm,
              useImperial: useImperialHeight,
            );
            final notificationsEnabled = profile.notificationsEnabled;
            final sportsPreview = profile.preferredSports.toList()..sort();
            final sportsLabel = sportsPreview.isEmpty
                ? 'Football · Badminton · Running'
                : sportsPreview.take(3).join(' · ');

            return SafeArea(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E976F), Color(0xFF5C62EA)],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: _goBack,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _ProfileAvatarBox(fileId: profile.avatarFileId),
                        const SizedBox(height: 14),
                        Text(
                          realName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40 / 1.6,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          sportsLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _TopChip(
                              icon: Icons.local_fire_department,
                              value: achievements.currentStreak,
                              suffix: 'streak',
                            ),
                            _TopChip(
                              icon: Icons.workspace_premium,
                              value: achievements.unlockedBadges.length,
                              suffix: 'badges',
                            ),
                            if (membership.isPremium)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Color(0xFFFEC84B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${membership.planLabel} · Pro',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
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
                  _ProfileTopTabs(
                    selected: _activeTab,
                    onSelect: (tab) => setState(() => _activeTab = tab),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      child: Column(
                        children: [
                          if (_activeTab == _ProfileContentTab.profile)
                            _CardSection(
                              title: 'PERSONAL INFO',
                              child: Column(
                                children: [
                                  _InfoRow(label: 'Name', value: realName),
                                  _InfoRow(label: 'Height', value: height),
                                  _InfoRow(label: 'Age', value: age),
                                  _InfoRow(label: 'Gender', value: gender),
                                  _InfoRow(
                                    label: 'Skill Level',
                                    value: skillLevel,
                                  ),
                                  _InfoRow(
                                    label: 'Email',
                                    value: email,
                                    valueColor: const Color(0xFF138E6F),
                                  ),
                                  _InfoRow(
                                    label: 'Emergency',
                                    value: emergency,
                                  ),
                                ],
                              ),
                            ),
                          if (_activeTab == _ProfileContentTab.profile) ...[
                            const SizedBox(height: 14),
                            Builder(
                              builder: (context) {
                                final earned = achievements.unlockedBadges;
                                final selectedEarned = earned
                                    .where(
                                      (badge) => selectedBadgeIds.contains(
                                        badge.badge.id,
                                      ),
                                    )
                                    .toList();
                                return _CardSection(
                                  title: 'BADGES',
                                  child: earned.isEmpty
                                      ? Text(
                                          'No badges unlocked yet. Join events and clubs to earn your first one.',
                                          style: TextStyle(
                                            color: Colors.black.withValues(
                                              alpha: 0.55,
                                            ),
                                          ),
                                        )
                                      : selectedEarned.isEmpty
                                      ? Text(
                                          "This user doesn't display any badges.",
                                          style: TextStyle(
                                            color: Colors.black.withValues(
                                              alpha: 0.55,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            for (final badge in selectedEarned)
                                              _UnlockedBadgePill(
                                                emoji: badge.badge.emoji,
                                                label: badge.badge.name,
                                              ),
                                          ],
                                        ),
                                );
                              },
                            ),
                          ],
                          if (_activeTab == _ProfileContentTab.sports) ...[
                            _CardSection(
                              title: 'SKILL LEVEL',
                              titleAction: IconButton(
                                onPressed: _showSkillLevelHelpDialog,
                                tooltip: 'About skill levels & ranks',
                                icon: Icon(
                                  Icons.help_outline,
                                  color: Colors.black.withValues(alpha: 0.45),
                                  size: 22,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _showAllSportsSkills
                                              ? 'All Sports'
                                              : 'Played Sports',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _showAllSportsSkills =
                                                !_showAllSportsSkills;
                                          });
                                        },
                                        child: Text(
                                          _showAllSportsSkills
                                              ? 'Show played only'
                                              : 'Show all sports',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _showAllSportsSkills
                                        ? 'Showing all sports. Sports without scored matches show unlock guidance below.'
                                        : 'Showing sports with activity only.',
                                    style: TextStyle(
                                      color: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...(() {
                                    final allSports = SampleData.sports;
                                    final playedSports = profile
                                        .sportSkills
                                        .entries
                                        .where((entry) {
                                          final sportName = entry.key.trim();
                                          final sportSkill = entry.value;
                                          if (sportName.isEmpty) {
                                            return false;
                                          }
                                          return sportSkill.matchesPlayed > 0;
                                        })
                                        .map((entry) => entry.key.trim())
                                        .toSet();
                                    final visibleSports = _showAllSportsSkills
                                        ? allSports
                                        : allSports
                                              .where(playedSports.contains)
                                              .toList();
                                    if (visibleSports.isEmpty) {
                                      return <Widget>[
                                        Text(
                                          'No sports played yet.',
                                          style: TextStyle(
                                            color: Colors.black.withValues(
                                              alpha: 0.55,
                                            ),
                                          ),
                                        ),
                                      ];
                                    }
                                    return [
                                      for (
                                        int i = 0;
                                        i < visibleSports.length;
                                        i++
                                      ) ...[
                                        () {
                                          final sportName = visibleSports[i];
                                          final sportSkill =
                                              profile.sportSkills[sportName] ??
                                              const SportSkillProgress();
                                          final hasPlayed =
                                              sportSkill.matchesPlayed > 0;
                                          final pointsNeeded =
                                              _pointsNeededForTier(
                                                sportSkill.tierLevel,
                                              );
                                          final progress = pointsNeeded <= 0
                                              ? 0.0
                                              : (sportSkill.tierProgress /
                                                        pointsNeeded)
                                                    .clamp(0.0, 1.0);
                                          return _SportSkillRow(
                                            sport: sportName,
                                            hasPlayed: hasPlayed,
                                            levelLabel:
                                                'Lvl ${sportSkill.tierLevel}',
                                            pointsLabel:
                                                '${sportSkill.tierProgress}/$pointsNeeded pts',
                                            progress: progress,
                                          );
                                        }(),
                                        if (i != visibleSports.length - 1)
                                          const SizedBox(height: 12),
                                      ],
                                    ];
                                  })(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SportRadarCard(profile: profile),
                            const SizedBox(height: 14),
                            _CardSection(
                              title: 'SPORTS RECOMMENDATION',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (profile.preferredSports.isEmpty)
                                    Text(
                                      'No sports selected yet.',
                                      style: TextStyle(
                                        color: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final sport
                                            in profile.preferredSports)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cs.primary.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              sport,
                                              style: TextStyle(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          _editPreferredSports(profile),
                                      child: const Text('Add / Remove Sports'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_activeTab == _ProfileContentTab.settings) ...[
                            _CardSection(
                              title: 'SETTINGS',
                              child: Column(
                                children: [
                                  const _SettingsGroupLabel('General'),
                                  _MenuRow(
                                    label: 'Stats',
                                    onTap: () {
                                      if (membership.isPremium) {
                                        Navigator.of(context).pushNamed(
                                          ProStatsHubScreen.routeName,
                                        );
                                      } else {
                                        Navigator.of(
                                          context,
                                        ).pushNamed(FreeStatsScreen.routeName);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 2),
                                  _ToggleMenuRow(
                                    label: 'Notifications',
                                    value: notificationsEnabled,
                                    activeColor: cs.primary,
                                    onChanged: (v) async {
                                      await profileRepository().saveMyProfile(
                                        profile.copyWith(
                                          notificationsEnabled: v,
                                        ),
                                      );
                                      if (mounted) {
                                        _reload();
                                      }
                                    },
                                  ),
                                  _ToggleMenuRow(
                                    label: 'Height display',
                                    subtitle: useImperialHeight
                                        ? 'Feet & inches'
                                        : 'Centimeters (cm)',
                                    value: useImperialHeight,
                                    activeColor: cs.primary,
                                    onChanged: (v) async {
                                      await heightDisplayRepository()
                                          .setUseImperial(v);
                                      if (mounted) {
                                        _reload();
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  const _SettingsGroupLabel('Account'),
                                  _MenuRow(
                                    label: 'Membership',
                                    trailing: membership.isPremium
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: cs.primary.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Pro',
                                                style: TextStyle(
                                                  color: cs.primary,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                        : null,
                                    onTap: () async {
                                      await Navigator.of(
                                        context,
                                      ).pushNamed(MembershipScreen.routeName);
                                      if (mounted) {
                                        _reload();
                                      }
                                    },
                                  ),
                                  _MenuRow(
                                    label: 'Edit Profile',
                                    onTap: () async {
                                      await Navigator.of(context).pushNamed(
                                        EditProfileScreen.routeName,
                                        arguments: profile,
                                      );
                                      if (mounted) {
                                        _reload();
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  const _SettingsGroupLabel('Security'),
                                  _MenuRow(
                                    label: 'Change Password',
                                    onTap: () {
                                      Navigator.of(context).pushNamed(
                                        ChangePasswordScreen.routeName,
                                      );
                                    },
                                  ),
                                  _MenuRow(
                                    label: 'Log Out',
                                    onTap: () async {
                                      final shouldLogout =
                                          await showDialog<bool>(
                                            context: context,
                                            builder: (dialogContext) =>
                                                AlertDialog(
                                                  title: const Text(
                                                    'Confirm Logout',
                                                  ),
                                                  content: const Text(
                                                    'log out from this account?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            dialogContext,
                                                          ).pop(false),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            dialogContext,
                                                          ).pop(true),
                                                      child: const Text(
                                                        'Log Out',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          ) ??
                                          false;
                                      if (!shouldLogout) {
                                        return;
                                      }
                                      final navigator = Navigator.of(context);
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      try {
                                        // Use deleteSessions() to also remove client-side cookies/session storage.
                                        // This prevents the "log out then can't log back in" issue.
                                        await AppwriteService.account
                                            .deleteSessions();
                                      } on AppwriteException catch (e) {
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e.message ?? 'Failed to log out.',
                                            ),
                                          ),
                                        );
                                      } catch (_) {
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to log out.'),
                                          ),
                                        );
                                      } finally {
                                        await SessionPersistence.clear();
                                        CurrentUser.reset();
                                      }
                                      if (!mounted) return;
                                      navigator.pushNamedAndRemoveUntil(
                                        LoginScreen.routeName,
                                        (_) => false,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _CardSection(
                              title: 'ACTIVITY TOOLS',
                              child: Column(
                                children: [
                                  _MenuRow(
                                    label: 'Daily Streak',
                                    onTap: () {
                                      Navigator.of(
                                        context,
                                      ).pushNamed(StreakScreen.routeName);
                                    },
                                  ),
                                  const Divider(height: 1),
                                  _MenuRow(
                                    label: 'Achievements',
                                    onTap: () async {
                                      await Navigator.of(
                                        context,
                                      ).pushNamed(AchievementsScreen.routeName);
                                      if (mounted) {
                                        _reload();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _CardSection(
                              title: 'DANGER ZONE',
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F0),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Permanent actions',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.red.shade700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Deactivation blocks login and requires manual reactivation.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                    const Divider(height: 14),
                                    _MenuRow(
                                      label: 'Deactivate Account',
                                      isDanger: true,
                                      showChevron: false,
                                      onTap: _onDeactivateAccount,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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

class _TopChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final String suffix;

  const _TopChip({
    required this.icon,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFEC84B)),
          const SizedBox(width: 6),
          _AnimatedCounterLabel(value: value, suffix: suffix),
        ],
      ),
    );
  }
}

class _AnimatedCounterLabel extends StatelessWidget {
  final int value;
  final String suffix;

  const _AnimatedCounterLabel({required this.value, required this.suffix});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w800,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return Text('${animated.round()} $suffix', style: textStyle);
      },
    );
  }
}

class _ProfileTopTabs extends StatelessWidget {
  final _ProfileContentTab selected;
  final ValueChanged<_ProfileContentTab> onSelect;

  const _ProfileTopTabs({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF173D70),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              _ProfileTabButton(
                label: 'Profile',
                selected: selected == _ProfileContentTab.profile,
                onTap: () => onSelect(_ProfileContentTab.profile),
              ),
              _ProfileTabButton(
                label: 'Sports',
                selected: selected == _ProfileContentTab.sports,
                onTap: () => onSelect(_ProfileContentTab.sports),
              ),
              _ProfileTabButton(
                label: 'Settings',
                selected: selected == _ProfileContentTab.settings,
                onTap: () => onSelect(_ProfileContentTab.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF35F0C8)
                        : Colors.white.withValues(alpha: 0.62),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF35F0C8) : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? titleAction;

  const _CardSection({
    required this.title,
    required this.child,
    this.titleAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6DEDC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF9CA9B0),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              if (titleAction != null) titleAction!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF5F6C78), fontSize: 16),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _UnlockedBadgePill extends StatelessWidget {
  final String emoji;
  final String label;

  const _UnlockedBadgePill({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7E5E1)),
      ),
      child: Text(
        '$emoji  $label',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF2D4A45),
        ),
      ),
    );
  }
}

class _SportSkillRow extends StatelessWidget {
  final String sport;
  final bool hasPlayed;
  final String levelLabel;
  final String pointsLabel;
  final double progress;

  const _SportSkillRow({
    required this.sport,
    required this.hasPlayed,
    required this.levelLabel,
    required this.pointsLabel,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentForSport(sport);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                sport,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            if (hasPlayed) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  levelLabel,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                pointsLabel,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ] else
              Expanded(
                flex: 2,
                child: Text(
                  _kUnlockSportSkillLevelMessage,
                  textAlign: TextAlign.end,
                  maxLines: 3,
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: hasPlayed ? progress.clamp(0.0, 1.0) : 0,
            backgroundColor: const Color(0xFFE1E5E8),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ],
    );
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
    if (key.contains('running') || key.contains('cycling')) {
      return const Color(0xFF6E7E8E);
    }
    return const Color(0xFF2E976F);
  }
}

class _SportRadarMetric {
  final String key;
  final String label;
  final double value;

  const _SportRadarMetric({
    required this.key,
    required this.label,
    required this.value,
  });
}

class _RadarAxisDefinition {
  final String key;
  final String label;
  final double Function(Map<String, double> averages) valueBuilder;

  const _RadarAxisDefinition({
    required this.key,
    required this.label,
    required this.valueBuilder,
  });
}

class _SportRadarCard extends StatefulWidget {
  final UserProfile profile;

  const _SportRadarCard({required this.profile});

  @override
  State<_SportRadarCard> createState() => _SportRadarCardState();
}

class _SportRadarCardState extends State<_SportRadarCard> {
  String? _selectedSport;
  bool _testingMode = false;
  final Map<String, double> _metricOverrides = <String, double>{};

  @override
  void didUpdateWidget(covariant _SportRadarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sports = _availableSports(widget.profile);
    if (_selectedSport != null && !sports.contains(_selectedSport)) {
      _selectedSport = null;
      _metricOverrides.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final sports = _availableSports(profile);
    final selectedSport =
        _selectedSport ?? _resolveSelectedSport(profile, sports);
    if (selectedSport == null) {
      return _CardSection(
        title: 'SPORT RADAR',
        child: Text(
          'Select a sport in Sports Recommendation and log matches to unlock your radar chart.',
          style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
        ),
      );
    }

    final metrics = _buildMetricsForSport(profile, selectedSport);

    final visibleMetrics = metrics
        .map(
          (metric) => _SportRadarMetric(
            key: metric.key,
            label: metric.label,
            value: _metricOverrides[metric.key] ?? metric.value,
          ),
        )
        .toList();

    return _CardSection(
      title: 'SPORT RADAR',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedSport,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sport',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final sport in sports)
                      DropdownMenuItem<String>(
                        value: sport,
                        child: Text(sport),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedSport = value;
                      _metricOverrides.clear();
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Switch(
                    value: _testingMode,
                    onChanged: (value) {
                      setState(() {
                        _testingMode = value;
                        if (!value) {
                          _metricOverrides.clear();
                        }
                      });
                    },
                  ),
                  const Text(
                    'Test',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Average per match stats in your selected sport.',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          if (visibleMetrics.isEmpty)
            Text(
              'No detailed stat entries for $selectedSport yet. Record scores to build your radar.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
            )
          else ...[
            SizedBox(
              height: 220,
              child: _SportRadarChart(metrics: visibleMetrics),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metric in visibleMetrics)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF3FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${metric.label}: ${metric.value.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Color(0xFF244B9A),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (_testingMode) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text(
              'Testing Controls',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 6),
            for (final metric in metrics) ...[
              _MetricEditRow(
                metric: metric,
                value: _metricOverrides[metric.key] ?? metric.value,
                onChanged: (nextValue) {
                  setState(() {
                    _metricOverrides[metric.key] = nextValue;
                  });
                },
              ),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }

  List<String> _availableSports(UserProfile profile) {
    final out = <String>[];
    final seen = <String>{};
    void addSport(String raw) {
      final sport = raw.trim();
      if (sport.isEmpty) {
        return;
      }
      final key = sport.toLowerCase();
      if (!seen.add(key)) {
        return;
      }
      out.add(sport);
    }

    final preferred = profile.preferredSports.toList()..sort();
    for (final sport in preferred) {
      addSport(sport);
    }
    final played =
        profile.sportSkills.entries
            .where(
              (entry) =>
                  entry.value.matchesPlayed > 0 && entry.key.trim().isNotEmpty,
            )
            .toList()
          ..sort(
            (a, b) => b.value.matchesPlayed.compareTo(a.value.matchesPlayed),
          );
    for (final entry in played) {
      addSport(entry.key);
    }
    for (final row in profile.matchHistory) {
      addSport(row.sport);
    }
    return out;
  }

  String? _resolveSelectedSport(UserProfile profile, List<String> sports) {
    if (_selectedSport != null) {
      return _selectedSport;
    }
    if (sports.isEmpty) {
      return null;
    }
    if (profile.preferredSports.isNotEmpty) {
      final preferred = profile.preferredSports.toList()..sort();
      final firstPreferred = preferred.first;
      if (sports.contains(firstPreferred)) {
        return firstPreferred;
      }
    }
    return sports.first;
  }

  List<_SportRadarMetric> _buildMetricsForSport(
    UserProfile profile,
    String sport,
  ) {
    final key = sport.trim().toLowerCase();
    final rows = profile.matchHistory
        .where((row) => row.sport.trim().toLowerCase() == key)
        .toList();
    if (rows.isEmpty) {
      return const [];
    }

    final statTotals = <String, double>{};
    for (final row in rows) {
      row.statValues.forEach((statKey, statValue) {
        statTotals[statKey] = (statTotals[statKey] ?? 0) + statValue.toDouble();
      });
    }
    if (statTotals.isEmpty) {
      return const [];
    }

    final statAverages = <String, double>{};
    statTotals.forEach((key, total) {
      statAverages[key] = total / rows.length;
    });

    final axisDefinitions = _axisDefinitionsForSport(sport);
    if (axisDefinitions.isNotEmpty) {
      return axisDefinitions
          .map(
            (axis) => _SportRadarMetric(
              key: axis.key,
              label: axis.label,
              value: axis.valueBuilder(statAverages).clamp(0.0, 999.0),
            ),
          )
          .toList();
    }

    final sortedEntries = statTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(6);

    return topEntries
        .map(
          (entry) => _SportRadarMetric(
            key: entry.key,
            label: _prettyMetricLabel(entry.key),
            value: entry.value / rows.length,
          ),
        )
        .toList();
  }

  List<_RadarAxisDefinition> _axisDefinitionsForSport(String sport) {
    final key = sport.trim().toLowerCase();
    double v(Map<String, double> a, String stat) => a[stat] ?? 0;

    if (key.contains('volleyball')) {
      return [
        _RadarAxisDefinition(
          key: 'dig',
          label: 'Dig',
          valueBuilder: (a) => v(a, 'digs'),
        ),
        _RadarAxisDefinition(
          key: 'spike',
          label: 'Spike',
          valueBuilder: (a) => v(a, 'points'),
        ),
        _RadarAxisDefinition(
          key: 'block',
          label: 'Block',
          valueBuilder: (a) => v(a, 'blocks'),
        ),
        _RadarAxisDefinition(
          key: 'receive',
          label: 'Receive',
          valueBuilder: (a) => v(a, 'digs') * 0.8 + v(a, 'blocks') * 0.2,
        ),
        _RadarAxisDefinition(
          key: 'serve',
          label: 'Serve',
          valueBuilder: (a) =>
              v(a, 'aces') > 0 ? v(a, 'aces') : v(a, 'points') * 0.35,
        ),
        _RadarAxisDefinition(
          key: 'set',
          label: 'Set',
          valueBuilder: (a) => v(a, 'assists'),
        ),
      ];
    }

    if (key.contains('basketball')) {
      return [
        _RadarAxisDefinition(
          key: 'scoring',
          label: 'Scoring',
          valueBuilder: (a) => v(a, 'points'),
        ),
        _RadarAxisDefinition(
          key: 'playmaking',
          label: 'Playmaking',
          valueBuilder: (a) => v(a, 'assists'),
        ),
        _RadarAxisDefinition(
          key: 'ballhandling',
          label: 'Ballhandling',
          valueBuilder: (a) =>
              (v(a, 'assists') + v(a, 'points') * 0.4) -
              v(a, 'turnovers') * 0.8,
        ),
        _RadarAxisDefinition(
          key: 'defence',
          label: 'Defence',
          valueBuilder: (a) => v(a, 'steals') + v(a, 'blocks') * 0.8,
        ),
        _RadarAxisDefinition(
          key: 'rebounding',
          label: 'Rebounding',
          valueBuilder: (a) => v(a, 'rebounds'),
        ),
        _RadarAxisDefinition(
          key: 'athleticism',
          label: 'Athleticism',
          valueBuilder: (a) =>
              v(a, 'rebounds') * 0.6 +
              v(a, 'steals') * 1.2 +
              v(a, 'blocks') * 1.1,
        ),
      ];
    }

    if (key.contains('football')) {
      return [
        _RadarAxisDefinition(
          key: 'finishing',
          label: 'Finishing',
          valueBuilder: (a) => v(a, 'goals'),
        ),
        _RadarAxisDefinition(
          key: 'creation',
          label: 'Creation',
          valueBuilder: (a) => v(a, 'assists'),
        ),
        _RadarAxisDefinition(
          key: 'distribution',
          label: 'Distribution',
          valueBuilder: (a) => v(a, 'passes') / 8,
        ),
        _RadarAxisDefinition(
          key: 'defending',
          label: 'Defending',
          valueBuilder: (a) => v(a, 'tackles'),
        ),
        _RadarAxisDefinition(
          key: 'goalkeeping',
          label: 'Goalkeeping',
          valueBuilder: (a) => v(a, 'saves'),
        ),
        _RadarAxisDefinition(
          key: 'impact',
          label: 'Impact',
          valueBuilder: (a) =>
              v(a, 'goals') + v(a, 'assists') + v(a, 'tackles') * 0.5,
        ),
      ];
    }

    if (key.contains('badminton') ||
        (key.contains('tennis') &&
            !key.contains('table tennis') &&
            !key.contains('ping pong')) ||
        key.contains('pickle') ||
        key.contains('table tennis') ||
        key.contains('ping pong')) {
      return [
        _RadarAxisDefinition(
          key: 'attack',
          label: 'Attack',
          valueBuilder: (a) => v(a, 'pointsWon'),
        ),
        _RadarAxisDefinition(
          key: 'serve',
          label: 'Serve',
          valueBuilder: (a) => v(a, 'aces'),
        ),
        _RadarAxisDefinition(
          key: 'control',
          label: 'Control',
          valueBuilder: (a) => v(a, 'gamesWon'),
        ),
        _RadarAxisDefinition(
          key: 'consistency',
          label: 'Consistency',
          valueBuilder: (a) =>
              v(a, 'gamesWon') * 0.8 + v(a, 'pointsWon') * 0.15,
        ),
        _RadarAxisDefinition(
          key: 'composure',
          label: 'Composure',
          valueBuilder: (a) => v(a, 'gamesWon') * 0.7 + v(a, 'aces') * 0.4,
        ),
        _RadarAxisDefinition(
          key: 'stamina',
          label: 'Stamina',
          valueBuilder: (a) =>
              v(a, 'pointsWon') * 0.25 + v(a, 'gamesWon') * 0.75,
        ),
      ];
    }

    return const [];
  }

  String _prettyMetricLabel(String key) {
    const labels = <String, String>{
      'goals': 'Goals',
      'assists': 'Assists',
      'passes': 'Passes',
      'tackles': 'Tackles',
      'saves': 'Saves',
      'points': 'Points',
      'rebounds': 'Rebounds',
      'steals': 'Steals',
      'blocks': 'Blocks',
      'turnovers': 'Turnovers',
      'digs': 'Digs',
      'gamesWon': 'Games Won',
      'pointsWon': 'Points Won',
      'aces': 'Aces',
      'setsWon': 'Sets Won',
    };
    return labels[key] ?? key;
  }
}

class _SportRadarChart extends StatelessWidget {
  final List<_SportRadarMetric> metrics;

  const _SportRadarChart({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final maxValue = metrics
        .map((metric) => metric.value)
        .fold<double>(0, (max, value) => value > max ? value : max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final normalized = metrics
        .map((metric) => (metric.value / safeMax).clamp(0.0, 1.0))
        .toList();

    return CustomPaint(
      painter: _RadarChartPainter(
        labels: metrics.map((metric) => metric.label).toList(),
        values: normalized,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MetricEditRow extends StatelessWidget {
  final _SportRadarMetric metric;
  final double value;
  final ValueChanged<double> onChanged;

  const _MetricEditRow({
    required this.metric,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(metric.value * 2, 10).toDouble();
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            metric.label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
        Expanded(
          flex: 6,
          child: Slider(
            value: value.clamp(0.0, maxValue).toDouble(),
            min: 0,
            max: maxValue,
            divisions: 40,
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;

  _RadarChartPainter({required this.labels, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.length < 3 || values.length != labels.length) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.33;
    final angleStep = (2 * math.pi) / labels.length;

    final gridPaint = Paint()
      ..color = const Color(0xFFD8E0EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFBCC8D6)
      ..strokeWidth = 1;
    final dataFillPaint = Paint()
      ..color = const Color(0xFF4A7BFF).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final dataStrokePaint = Paint()
      ..color = const Color(0xFF3C68D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int ring = 1; ring <= 4; ring++) {
      final ringRadius = radius * (ring / 4);
      final ringPath = Path();
      for (int i = 0; i < labels.length; i++) {
        final angle = -math.pi / 2 + i * angleStep;
        final point = Offset(
          center.dx + ringRadius * math.cos(angle),
          center.dy + ringRadius * math.sin(angle),
        );
        if (i == 0) {
          ringPath.moveTo(point.dx, point.dy);
        } else {
          ringPath.lineTo(point.dx, point.dy);
        }
      }
      ringPath.close();
      canvas.drawPath(ringPath, gridPaint);
    }

    for (int i = 0; i < labels.length; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final axisEnd = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, axisEnd, axisPaint);

      final labelOffset = Offset(
        center.dx + (radius + 20) * math.cos(angle),
        center.dy + (radius + 20) * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF556070),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 70);
      tp.paint(
        canvas,
        Offset(
          labelOffset.dx - (tp.width / 2),
          labelOffset.dy - (tp.height / 2),
        ),
      );
    }

    final dataPath = Path();
    for (int i = 0; i < labels.length; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final valueRadius = radius * values[i];
      final point = Offset(
        center.dx + valueRadius * math.cos(angle),
        center.dy + valueRadius * math.sin(angle),
      );
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(
        point,
        3.5,
        dataStrokePaint..style = PaintingStyle.fill,
      );
      dataStrokePaint.style = PaintingStyle.stroke;
    }
    dataPath.close();
    canvas.drawPath(dataPath, dataFillPaint);
    canvas.drawPath(dataPath, dataStrokePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.labels != labels || oldDelegate.values != values;
  }
}

class _MenuRow extends StatelessWidget {
  final String label;
  final bool isDanger;
  final bool showChevron;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _MenuRow({
    required this.label,
    this.isDanger = false,
    this.showChevron = true,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: isDanger ? Colors.red : const Color(0xFF2A3540),
                  fontWeight: isDanger ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (showChevron)
              const Icon(Icons.chevron_right, color: Color(0xFFBCC7CC)),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroupLabel extends StatelessWidget {
  final String label;

  const _SettingsGroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Colors.black.withValues(alpha: 0.42),
          ),
        ),
      ),
    );
  }
}

class _ToggleMenuRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _ToggleMenuRow({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF2A3540),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatarBox extends StatelessWidget {
  final String? fileId;
  const _ProfileAvatarBox({required this.fileId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (fileId == null || fileId!.isEmpty)
          ? const Center(child: Text('🏃', style: TextStyle(fontSize: 40)))
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
                  child: Text('🏃', style: TextStyle(fontSize: 40)),
                );
              },
            ),
    );
  }
}
