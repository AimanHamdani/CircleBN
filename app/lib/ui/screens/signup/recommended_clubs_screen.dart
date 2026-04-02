import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';

import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../auth/session_persistence.dart';
import '../../../data/club_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../data/sample_clubs.dart';
import '../../../models/club.dart';
import '../../../models/signup_draft.dart';
import '../../../models/user_profile.dart';
import '../home/home_screen.dart';

class RecommendedClubsArgs {
  final SignUpDraft draft;
  final bool skippedSports;
  const RecommendedClubsArgs({required this.draft, required this.skippedSports});
}

class RecommendedClubsScreen extends StatefulWidget {
  static const routeName = '/signup/recommended-clubs';
  const RecommendedClubsScreen({super.key});

  @override
  State<RecommendedClubsScreen> createState() => _RecommendedClubsScreenState();
}

class _RecommendedClubsScreenState extends State<RecommendedClubsScreen> {
  late RecommendedClubsArgs _args;
  late Set<String> _selectedClubIds;
  bool _isSubmitting = false;
  late final Future<List<Club>> _clubsFuture = clubRepository()
      .listClubs()
      .catchError((Object _) => SampleData.clubs);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final raw = ModalRoute.of(context)?.settings.arguments;
    _args = raw is RecommendedClubsArgs ? raw : const RecommendedClubsArgs(draft: SignUpDraft(), skippedSports: true);
    _selectedClubIds = {..._args.draft.clubIds};
  }

  List<Club> _filterRecommended(List<Club> all) {
    final pickedSports = _args.draft.sports;
    if (pickedSports.isEmpty) {
      return List<Club>.from(all)..sort((a, b) => a.name.compareTo(b.name));
    }
    return all.where((c) => c.sports.any(pickedSports.contains)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  String _clubListSubtitle(Club club) {
    if (club.sports.isNotEmpty) {
      return club.sports.join(' • ');
    }
    final d = club.description.trim();
    if (d.isEmpty) {
      return '';
    }
    return d.length > 80 ? '${d.substring(0, 80)}…' : d;
  }

  Future<void> _finish() async {
    if (_isSubmitting) return;
    final finalDraft = _args.draft.copyWith(clubIds: _selectedClubIds);
    final email = finalDraft.email?.trim() ?? '';
    final password = finalDraft.password ?? '';
    final userName = finalDraft.fullName?.trim().isNotEmpty == true
        ? finalDraft.fullName!.trim()
        : (finalDraft.username?.trim().isNotEmpty == true ? finalDraft.username!.trim() : 'User');

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing email/password from signup flow.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      try {
        await AppwriteService.account.create(
          userId: ID.unique(),
          email: email,
          password: password,
          name: userName,
        );
      } on AppwriteException catch (e) {
        // If account already exists, continue with login flow.
        if (e.code != 409) {
          rethrow;
        }
      }

      try {
        final session = await AppwriteService.account.createEmailPasswordSession(
          email: email,
          password: password,
        );
        await SessionPersistence.save(session.$id);
      } on AppwriteException catch (e) {
        // If already logged in, session creation can fail; continue.
        if (e.code != 401 && e.code != 409) {
          rethrow;
        }
      }

      await CurrentUser.init();

      if (currentUserId == 'current_user_placeholder') {
        throw AppwriteException(
          'No active Appwrite session after signup. Check Auth permissions/settings.',
          401,
        );
      }

      final profile = UserProfile(
        userId: currentUserId,
        username: finalDraft.username?.trim().isNotEmpty == true ? finalDraft.username!.trim() : userName,
        realName: finalDraft.fullName?.trim().isNotEmpty == true ? finalDraft.fullName!.trim() : userName,
        email: email,
        age: _calcAge(finalDraft.dateOfBirth),
        gender: finalDraft.gender ?? 'Male',
        heightCm: finalDraft.heightCm,
        preferredSports: finalDraft.sports,
        emergencyContact: finalDraft.emergencyContact ?? '',
        bio: '',
        notificationsEnabled: true,
      );
      try {
        await profileRepository().saveMyProfile(profile);
      } on AppwriteException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account created, but profile save failed: ${e.message ?? 'check profiles schema/permissions'}',
            ),
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created, but profile save failed. Check profiles schema/permissions.'),
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign up completed.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(HomeScreen.routeName, (_) => false);
    } on AppwriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign up: ${e.message ?? 'unknown error'}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to sign up. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = _args.skippedSports || _args.draft.sports.isEmpty
        ? 'Recommended Clubs'
        : 'Recommended Clubs for ${_args.draft.sports.join(', ')}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                header,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick clubs to follow',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              const Text(
                'STEP 3 OF 3',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: FutureBuilder<List<Club>>(
                  future: _clubsFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final clubs = _filterRecommended(snap.data ?? const <Club>[]);
                    if (clubs.isEmpty) {
                      return const Center(child: Text('No clubs match your sports yet.'));
                    }
                    return ListView.separated(
                      itemCount: clubs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final club = clubs[idx];
                        final selected = _selectedClubIds.contains(club.id);
                        return InkWell(
                          onTap: () => setState(() {
                            if (selected) {
                              _selectedClubIds.remove(club.id);
                            } else {
                              _selectedClubIds.add(club.id);
                            }
                          }),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.55)
                                    : const Color(0xFFE3E7EE),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? Theme.of(context).colorScheme.primary
                                          : const Color(0xFFB8C0CC),
                                      width: 2,
                                    ),
                                    color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        club.name,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _clubListSubtitle(club),
                                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isSubmitting ? null : _finish,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int? _calcAge(DateTime? dob) {
  if (dob == null) return null;
  final now = DateTime.now();
  var age = now.year - dob.year;
  final hadBirthday = now.month > dob.month || (now.month == dob.month && now.day >= dob.day);
  if (!hadBirthday) {
    age -= 1;
  }
  return age;
}

