import 'package:flutter/material.dart';

import '../../../data/sample_clubs.dart';
import '../../../models/signup_draft.dart';
import 'recommended_clubs_screen.dart';

class ChooseSportsScreen extends StatefulWidget {
  static const routeName = '/signup/choose-sports';
  const ChooseSportsScreen({super.key});

  @override
  State<ChooseSportsScreen> createState() => _ChooseSportsScreenState();
}

class _ChooseSportsScreenState extends State<ChooseSportsScreen> {
  late SignUpDraft _draft;
  late Set<String> _selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    _draft = args is SignUpDraft ? args : const SignUpDraft();
    _selected = {..._draft.sports};
  }

  void _next({required bool skipped}) {
    final next = _draft.copyWith(sports: _selected);
    Navigator.of(context).pushNamed(
      RecommendedClubsScreen.routeName,
      arguments: RecommendedClubsArgs(
        draft: next,
        skippedSports: skipped,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _selected.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          TextButton(
            onPressed: () => _next(skipped: true),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose your sports',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick at least one (or Skip)',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              const Text(
                'STEP 2 OF 3',
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
                  itemCount: SampleData.sports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final sport = SampleData.sports[idx];
                    final selected = _selected.contains(sport);
                    return InkWell(
                      onTap: () => setState(() {
                        if (selected) {
                          _selected.remove(sport);
                        } else {
                          _selected.add(sport);
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
                              child: Text(
                                sport,
                                style: const TextStyle(fontWeight: FontWeight.w700),
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
                onPressed: canProceed ? () => _next(skipped: false) : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

