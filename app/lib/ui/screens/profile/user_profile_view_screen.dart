import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../data/achievement_repository.dart';
import '../../../data/badge_display_repository.dart';
import '../../../data/height_display_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/user_profile.dart';
import '../../../utils/height_display.dart';

class UserProfileViewArgs {
  final String userId;

  const UserProfileViewArgs({required this.userId});
}

class UserProfileViewScreen extends StatefulWidget {
  static const routeName = '/profile/view';

  const UserProfileViewScreen({super.key});

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  Future<UserProfile>? _future;
  Future<AchievementSnapshot>? _achievementFuture;
  Future<Set<String>>? _displayBadgeIdsFuture;
  String _targetUserId = '';
  bool _isOwnProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is UserProfileViewArgs) {
      _targetUserId = args.userId.trim();
    }
    _isOwnProfile = _targetUserId == currentUserId;
    _future = profileRepository().getProfileById(_targetUserId);
    _achievementFuture = achievementRepository().getSnapshotForUser(
      _targetUserId,
    );
    _displayBadgeIdsFuture = badgeDisplayRepository().getSelectedBadgeIds(
      _targetUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    const topGradientA = Color(0xFF2C9C7E);
    const topGradientB = Color(0xFF5C62EA);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 380 ? 14.0 : 18.0;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: LayoutBuilder(
        builder: (context, viewport) {
          final contentMaxWidth = viewport.maxWidth > 860
              ? 820.0
              : double.infinity;
          return FutureBuilder<UserProfile>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done &&
                  snap.data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final profile = snap.data ?? UserProfile.empty(_targetUserId);
              final name = profile.realName.trim().isNotEmpty
                  ? profile.realName.trim()
                  : profile.username;
              final sports = profile.preferredSports.toList()..sort();
              final subtitle = sports.isEmpty
                  ? 'Sports enthusiast'
                  : sports.take(3).join(' · ');

              return SafeArea(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        14,
                        horizontalPadding,
                        24,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [topGradientA, topGradientB],
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: contentMaxWidth,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () =>
                                        Navigator.of(context).maybePop(),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _isOwnProfile
                                          ? 'My Profile'
                                          : 'User Profile',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                              const SizedBox(height: 14),
                              _UserAvatar(fileId: profile.avatarFileId),
                              const SizedBox(height: 10),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 33 / 1.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FutureBuilder<AchievementSnapshot>(
                                future: _achievementFuture,
                                builder: (context, statSnap) {
                                  final stats = statSnap.data;
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.22,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _HeaderStat(
                                            value:
                                                '${stats?.createdEventsCount ?? 0}',
                                            label: 'Events',
                                          ),
                                        ),
                                        Expanded(
                                          child: _HeaderStat(
                                            value:
                                                '${stats?.joinedClubsCount ?? 0}',
                                            label: 'Circle',
                                          ),
                                        ),
                                        Expanded(
                                          child: _HeaderStat(
                                            value:
                                                '${stats?.currentStreak ?? 0}',
                                            label: 'Streak',
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          16,
                          horizontalPadding,
                          20,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: contentMaxWidth,
                            ),
                            child: Column(
                              children: [
                                FutureBuilder<bool>(
                                  future: heightDisplayRepository()
                                      .getUseImperial(),
                                  builder: (context, imperialSnap) {
                                    final useImperial = imperialSnap.data ?? false;
                                    final heightLabel = formatHeightForDisplay(
                                      profile.heightCm,
                                      useImperial: useImperial,
                                    );
                                    return _InfoCard(
                                      title: 'PERSONAL INFO',
                                      rows: [
                                        _InfoLine(label: 'Name', value: name),
                                        _InfoLine(
                                          label: 'Age',
                                          value:
                                              profile.age?.toString() ?? '—',
                                        ),
                                        _InfoLine(
                                          label: 'Gender',
                                          value: profile.gender
                                                  .trim()
                                                  .isNotEmpty
                                              ? profile.gender
                                              : '—',
                                        ),
                                        _InfoLine(
                                          label: 'Height',
                                          value: heightLabel,
                                        ),
                                        _InfoLine(
                                          label: 'Skill Level',
                                          value: profile.skillLevel
                                                  .trim()
                                                  .isNotEmpty
                                              ? profile.skillLevel
                                              : '—',
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                _InfoCard(
                                  title: 'SPORTS',
                                  rows: [
                                    _InfoLine(
                                      label: 'Preferred',
                                      value: sports.isEmpty
                                          ? 'No sports added'
                                          : sports.join(', '),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                FutureBuilder<AchievementSnapshot>(
                                  future: _achievementFuture,
                                  builder: (context, achievementSnap) {
                                    final achievements = achievementSnap.data;
                                    if (achievements == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return FutureBuilder<Set<String>>(
                                      future: _displayBadgeIdsFuture,
                                      builder: (context, selectedSnap) {
                                        final selectedBadgeIds =
                                            selectedSnap.data ??
                                            const <String>{};
                                        final earned =
                                            achievements.unlockedBadges;
                                        final selectedEarned = earned
                                            .where(
                                              (badge) => selectedBadgeIds
                                                  .contains(badge.badge.id),
                                            )
                                            .toList();
                                        return _BadgeCard(
                                          badges: selectedEarned
                                              .map(
                                                (badge) => _BadgeVisual(
                                                  emoji: badge.badge.emoji,
                                                  label: badge.badge.name,
                                                ),
                                              )
                                              .toList(),
                                          emptyText: earned.isEmpty
                                              ? 'No badges unlocked yet. Join events and clubs to earn your first one.'
                                              : "This user doesn't display any badges.",
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    14,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFBFD4FF),
                                    ),
                                  ),
                                  child: Text(
                                    _isOwnProfile
                                        ? 'Viewing your public profile info.'
                                        : 'This is read-only profile info. You cannot edit other users.',
                                    style: const TextStyle(
                                      color: Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

class _UserAvatar extends StatelessWidget {
  final String? fileId;

  const _UserAvatar({required this.fileId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (fileId == null || fileId!.isEmpty)
          ? const Center(child: Text('🏃', style: TextStyle(fontSize: 38)))
          : FutureBuilder<Uint8List>(
              future: AppwriteService.getFileViewBytes(
                bucketId: AppwriteConfig.profileImagesBucketId,
                fileId: fileId!,
              ),
              builder: (context, snap) {
                if (snap.hasData &&
                    snap.data != null &&
                    snap.data!.isNotEmpty) {
                  return Image.memory(snap.data!, fit: BoxFit.cover);
                }
                return const Center(
                  child: Text('🏃', style: TextStyle(fontSize: 38)),
                );
              },
            ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 25 / 1.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoLine {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});
}

class _BadgeVisual {
  final String emoji;
  final String label;

  const _BadgeVisual({required this.emoji, required this.label});
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoLine> rows;

  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8DEE7)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF8A95A4),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          for (int i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stackVertically = constraints.maxWidth < 360;
                  if (stackVertically) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].label,
                          style: const TextStyle(
                            color: Color(0xFF556070),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rows[i].value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          rows[i].label,
                          style: const TextStyle(
                            color: Color(0xFF556070),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rows[i].value,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (i != rows.length - 1) const Divider(height: 1),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final List<_BadgeVisual> badges;
  final String emptyText;

  const _BadgeCard({required this.badges, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8DEE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BADGES',
            style: TextStyle(
              color: Color(0xFF8A95A4),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          if (badges.isEmpty)
            Text(
              emptyText,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final badge in badges)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F4),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD7E5E1)),
                    ),
                    child: Text(
                      '${badge.emoji}  ${badge.label}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D4A45),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
