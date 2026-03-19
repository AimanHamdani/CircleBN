import 'package:flutter/material.dart';

import '../../../models/signup_draft.dart';
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'About you',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Fill in your personal details',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              const Text(
                'STEP 1 OF 3',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 18),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _fullNameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Full Name', hintText: 'Your full name'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _usernameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username/Nickname (optional)',
                        hintText: '@username',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emergencyCtrl,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Emergency Contact (optional)',
                        hintText: '+673 XXXXXX',
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickDob,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date of Birth'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _dob == null ? 'DD / MM / YYYY' : '${_dob!.day.toString().padLeft(2, '0')} / ${_dob!.month.toString().padLeft(2, '0')} / ${_dob!.year}',
                                style: TextStyle(color: _dob == null ? Colors.black45 : Colors.black87),
                              ),
                            ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Gender', style: Theme.of(context).textTheme.labelLarge),
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
                    TextFormField(
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Height (cm)', hintText: 'e.g. 175'),
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
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFD39E)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Color(0xFFB25B00)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Once you enter your information you cannot change it anymore (mock copy).',
                              style: TextStyle(color: Color(0xFF7A3E00)),
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
                child: const Text('Next'),
              ),
              const SizedBox(height: 10),
              Text(
                base.email == null ? '' : 'Signing up as ${base.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.black38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.transparent : const Color(0xFFE3E7EE)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

