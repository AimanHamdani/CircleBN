import 'package:flutter/material.dart';

import '../../../models/signup_draft.dart';
import '../../theme/app_theme.dart';
import 'choose_sports_screen.dart';

class AboutYouScreen extends StatefulWidget {
  static const routeName = '/signup/about-you';
  const AboutYouScreen({super.key});

  @override
  State<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends State<AboutYouScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  DateTime? _dob;
  String _gender = 'Male';

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emergencyCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  SignUpDraft _draftFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is SignUpDraft) return args;
    return const SignUpDraft();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, 1, 1),
      firstDate: DateTime(now.year - 90),
      lastDate: DateTime(now.year - 10),
    );
    if (picked == null) return;
    setState(() => _dob = picked);
  }

  void _next(SignUpDraft base) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final height = int.tryParse(_heightCtrl.text.trim());
    final next = base.copyWith(
      fullName: _fullNameCtrl.text.trim(),
      username: _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
      dateOfBirth: _dob,
      gender: _gender,
      heightCm: height,
      emergencyContact: _emergencyCtrl.text.trim().isEmpty ? null : _emergencyCtrl.text.trim(),
    );
    Navigator.of(context).pushNamed(
      ChooseSportsScreen.routeName,
      arguments: next,
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = _draftFromArgs(context);
    final green = AppTheme.brandGreen;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF7F3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'STEP 1 OF 3',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: green,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'About you',
                style: TextStyle(
                  fontSize: 42 / 1.6,
                  fontWeight: FontWeight.w900,
                  color: green,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fill in your details',
                style: TextStyle(
                  color: green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: 1 / 3,
                  backgroundColor: const Color(0xFFBFDDD0),
                  valueColor: AlwaysStoppedAnimation<Color>(green),
                ),
              ),
              const SizedBox(height: 18),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Full Name', style: TextStyle(fontWeight: FontWeight.w700, color: green)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fullNameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        hintText: 'Your full name',
                        green: green,
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    Text('Username', style: TextStyle(fontWeight: FontWeight.w700, color: green)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usernameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        hintText: '@username',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Date of birth', style: TextStyle(fontWeight: FontWeight.w700, color: green)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDob,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: _inputDecoration(
                          hintText: '',
                          green: green,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _dob == null ? 'DD / MM / YYYY' : '${_dob!.day.toString().padLeft(2, '0')} / ${_dob!.month.toString().padLeft(2, '0')} / ${_dob!.year}',
                                style: TextStyle(color: _dob == null ? Colors.black45 : Colors.black87),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black45),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Gender',
                        style: TextStyle(fontWeight: FontWeight.w700, color: green),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _GenderChip(
                            label: 'Male',
                            selected: _gender == 'Male',
                            onTap: () => setState(() => _gender = 'Male'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _GenderChip(
                            label: 'Female',
                            selected: _gender == 'Female',
                            onTap: () => setState(() => _gender = 'Female'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Height (cm)', style: TextStyle(fontWeight: FontWeight.w700, color: green)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: _inputDecoration(
                        hintText: 'e.g. 175',
                        green: green,
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return null;
                        final n = int.tryParse(value);
                        if (n == null) return 'Enter a number';
                        if (n < 50 || n > 260) return 'Enter a realistic height';
                        return null;
                      },
                      onFieldSubmitted: (_) => _next(base),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF63C8A7), width: 1.4),
                      ),
                      child: const Row(
                        children: [
                          Text('⚠️'),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Once submitted, this info cannot be changed.',
                              style: TextStyle(color: Color(0xFF00644D), fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => _next(base),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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

InputDecoration _inputDecoration({
  required String hintText,
  Color green = AppTheme.brandGreen,
}) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD6D8D6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: green, width: 1.8),
    ),
  );
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final green = AppTheme.brandGreen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? green : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFF63C8A7),
            width: selected ? 0 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : green,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

