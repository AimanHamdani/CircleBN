import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
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

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile> _future;
  late Future<AchievementSnapshot> _achievementFuture;
  late Future<Set<String>> _displayBadgeIdsFuture;
  late Future<List<Object?>> _pageFuture;
  static List<Object?>? _cachedPageData;
  bool _showAllSportsSkills = false;

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
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      child: Column(
                        children: [
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
                                _InfoRow(label: 'Emergency', value: emergency),
                              ],
                            ),
                          ),
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
                          const SizedBox(height: 14),
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
                                    color: Colors.black.withValues(alpha: 0.55),
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
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
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
                          const SizedBox(height: 14),
                          _CardSection(
                            title: 'SETTINGS',
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Notification',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                    Switch(
                                      value: notificationsEnabled,
                                      activeThumbColor: Colors.white,
                                      activeTrackColor: cs.primary,
                                      onChanged: (v) async {
                                        await profileRepository().saveMyProfile(
                                          profile.copyWith(
                                            notificationsEnabled: v,
                                          ),
                                        );
                                        if (mounted) _reload();
                                      },
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Height display',
                                            style: TextStyle(fontSize: 18),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            useImperialHeight
                                                ? 'Feet & inches'
                                                : 'Centimeters (cm)',
                                            style: TextStyle(
                                              color: Colors.black.withValues(
                                                alpha: 0.5,
                                              ),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: useImperialHeight,
                                      activeThumbColor: Colors.white,
                                      activeTrackColor: cs.primary,
                                      onChanged: (v) async {
                                        await heightDisplayRepository()
                                            .setUseImperial(v);
                                        if (mounted) {
                                          _reload();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
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
                                const Divider(height: 1),
                                _MenuRow(
                                  label: 'Membership',
                                  trailing: membership.isPremium
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
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
                                    await Navigator.of(context).pushNamed(
                                      MembershipScreen.routeName,
                                    );
                                    if (mounted) {
                                      _reload();
                                    }
                                  },
                                ),
                                const Divider(height: 1),
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
                                const Divider(height: 1),
                                _MenuRow(
                                  label: 'Change Password',
                                  onTap: () {
                                    Navigator.of(
                                      context,
                                    ).pushNamed(ChangePasswordScreen.routeName);
                                  },
                                ),
                                const Divider(height: 1),
                                _MenuRow(
                                  label: 'Log Out',
                                  onTap: () async {
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
                                const Divider(height: 1),
                                const _MenuRow(
                                  label: 'Delete Account',
                                  isDanger: true,
                                  showChevron: false,
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
