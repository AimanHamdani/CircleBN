import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../data/profile_repository.dart';
import '../../../data/sample_clubs.dart';
import '../../../models/user_profile.dart';
import '../home/home_screen.dart';
import '../login_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import '../../../auth/current_user.dart';
import '../../../auth/session_persistence.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';

  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile> _future;

  @override
  void initState() {
    super.initState();
    _future = profileRepository().getMyProfile();
  }

  void _reload() {
    setState(() => _future = profileRepository().getMyProfile());
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      HomeScreen.routeName,
      (_) => false,
    );
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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Events in these sports will be shown first.',
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
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
      await profileRepository().saveMyProfile(profile.copyWith(preferredSports: updated));
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
        backgroundColor: const Color(0xFFF0F4F3),
        body: FutureBuilder<UserProfile>(
        future: _future,
        builder: (context, snap) {
          final profile = snap.data;
          final username = profile?.username ?? 'Username';
          final realName = profile?.realName.trim().isNotEmpty == true ? profile!.realName.trim() : 'Name';
          final bio = profile?.bio.trim().isNotEmpty == true ? profile!.bio.trim() : 'No Description';
          final age = profile?.age != null ? '${profile!.age}' : '—';
          final gender = profile?.gender.trim().isNotEmpty == true ? profile!.gender.trim() : '—';
          final skillLevel = profile?.skillLevel.trim().isNotEmpty == true ? profile!.skillLevel.trim() : '—';
          final email = profile?.email.trim().isNotEmpty == true ? profile!.email.trim() : '—';
          final emergency = profile?.emergencyContact.trim().isNotEmpty == true ? profile!.emergencyContact.trim() : '—';
          final height = profile?.heightCm != null ? '${profile!.heightCm} cm' : '—';
          final notificationsEnabled = profile?.notificationsEnabled ?? true;

          return SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFF14856B),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
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
                              child: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ProfileAvatarBox(fileId: profile?.avatarFileId),
                      const SizedBox(height: 14),
                      Text(
                        username,
                        style: const TextStyle(color: Colors.white, fontSize: 36 / 1.6, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Bio · $bio',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      children: [
                        if (snap.connectionState != ConnectionState.done && profile == null)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        _CardSection(
                          title: 'PERSONAL INFO',
                          child: Column(
                            children: [
                              _InfoRow(label: 'Name', value: realName),
                              _InfoRow(label: 'Height', value: height),
                              _InfoRow(label: 'Age', value: age),
                              _InfoRow(label: 'Gender', value: gender),
                              _InfoRow(label: 'Skill Level', value: skillLevel),
                              _InfoRow(label: 'Email', value: email, valueColor: const Color(0xFF138E6F)),
                              _InfoRow(label: 'Emergency', value: emergency),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CardSection(
                          title: 'SKILL LEVEL',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                skillLevel,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Used for event join restrictions.',
                                style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CardSection(
                          title: 'SPORTS RECOMMENDATION',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (profile == null || profile.preferredSports.isEmpty)
                                Text(
                                  'No sports selected yet.',
                                  style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final sport in profile.preferredSports)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(999),
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
                                  onPressed: profile == null ? null : () => _editPreferredSports(profile),
                                  child: const Text('Add / Remove Sports'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CardSection(
                          title: 'OTHERS',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Expanded(child: Text('Notification', style: TextStyle(fontSize: 18))),
                                  Switch(
                                    value: notificationsEnabled,
                                    activeColor: Colors.white,
                                    activeTrackColor: cs.primary,
                                    onChanged: (v) async {
                                      if (profile == null) return;
                                      await profileRepository().saveMyProfile(profile.copyWith(notificationsEnabled: v));
                                      if (mounted) _reload();
                                    },
                                  ),
                                ],
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
                                  Navigator.of(context).pushNamed(
                                    ChangePasswordScreen.routeName,
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              _MenuRow(
                                label: 'Log Out',
                                onTap: () async {
                                  try {
                                    // Use deleteSessions() to also remove client-side cookies/session storage.
                                    // This prevents the "log out then can't log back in" issue.
                                    await AppwriteService.account.deleteSessions();
                                  } on AppwriteException catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.message ?? 'Failed to log out.')),
                                    );
                                  } catch (_) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to log out.')),
                                    );
                                  } finally {
                                    await SessionPersistence.clear();
                                    CurrentUser.reset();
                                  }
                                  if (!mounted) return;
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    LoginScreen.routeName,
                                    (_) => false,
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              const _MenuRow(label: 'Delete Account', isDanger: true, showChevron: false),
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

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _CardSection({required this.title, required this.child});

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
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9CA9B0),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
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
            Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF5F6C78), fontSize: 16))),
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

class _SkillRow extends StatelessWidget {
  final String label;
  final int value;
  const _SkillRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(1, 6).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 82, child: Text(label, style: const TextStyle(color: Color(0xFF4F5E69), fontSize: 16))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: clamped / 6.0,
                backgroundColor: const Color(0xFFE8EEED),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF1DA37E)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1D8267))),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String label;
  final bool isDanger;
  final bool showChevron;
  final VoidCallback? onTap;
  const _MenuRow({
    required this.label,
    this.isDanger = false,
    this.showChevron = true,
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
            if (showChevron) const Icon(Icons.chevron_right, color: Color(0xFFBCC7CC)),
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
                  return Image.memory(
                    snap.data!,
                    fit: BoxFit.cover,
                  );
                }
                return const Center(child: Text('🏃', style: TextStyle(fontSize: 40)));
              },
            ),
    );
  }
}

