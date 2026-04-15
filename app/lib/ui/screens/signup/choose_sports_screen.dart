import 'package:flutter/material.dart';

import '../../../data/sample_clubs.dart';
import '../../../models/signup_draft.dart';
import '../../theme/app_theme.dart';
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
      arguments: RecommendedClubsArgs(draft: next, skippedSports: skipped),
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = AppTheme.brandGreen;
    final canProceed = _selected.isNotEmpty;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 380 ? 16.0 : 28.0;
    return Scaffold(
      backgroundColor: const Color(0xFFEFF7F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFF7F3),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF63C8A7),
                    width: 1.2,
                  ),
                ),
                child: Icon(Icons.arrow_back, size: 18, color: green),
              ),
            ),
          ),
        ),
        titleSpacing: 4,
        title: Text(
          'Choose Sports',
          style: TextStyle(
            color: green,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _next(skipped: true),
            style: TextButton.styleFrom(
              foregroundColor: green,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            child: const Text('Skip'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF9FD7C1)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'STEP 2 OF 3',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: green,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose your sports',
                style: TextStyle(
                  fontSize: 42 / 1.6,
                  fontWeight: FontWeight.w900,
                  color: green,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick at least one (or Skip)',
                style: TextStyle(color: green, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: 2 / 3,
                  backgroundColor: const Color(0xFFBFDDD0),
                  valueColor: AlwaysStoppedAnimation<Color>(green),
                ),
              ),
              const SizedBox(height: 16),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? green.withValues(alpha: 0.55)
                                : const Color(0xFFD6D8D6),
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
                                      ? green
                                      : const Color(0xFFB8C0CC),
                                  width: 2,
                                ),
                                color: selected ? green : Colors.transparent,
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                sport,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
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
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  elevation: 2,
                ),
                child: const Text('Next →'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
