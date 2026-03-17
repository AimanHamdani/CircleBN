import 'package:flutter/material.dart';

import '../../../data/sample_clubs.dart';
import '../../../models/club.dart';
import '../../../models/signup_draft.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final raw = ModalRoute.of(context)?.settings.arguments;
    _args = raw is RecommendedClubsArgs ? raw : const RecommendedClubsArgs(draft: SignUpDraft(), skippedSports: true);
    _selectedClubIds = {..._args.draft.clubIds};
  }

  List<Club> _recommendedClubs() {
    final pickedSports = _args.draft.sports;
    if (pickedSports.isEmpty) return SampleData.clubs;
    return SampleData.clubs
        .where((c) => c.sports.any(pickedSports.contains))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _finish() async {
    final finalDraft = _args.draft.copyWith(clubIds: _selectedClubIds);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sign up complete (mock).\nSports: ${finalDraft.sports.isEmpty ? 'none' : finalDraft.sports.join(', ')}\nClubs: ${finalDraft.clubIds.isEmpty ? 'none' : finalDraft.clubIds.length}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(HomeScreen.routeName, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final clubs = _recommendedClubs();
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
                'Pick clubs to follow (mock)',
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
                child: ListView.separated(
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
                                    club.sports.join(' • '),
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _finish,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

