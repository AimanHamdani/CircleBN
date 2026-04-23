import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../utils/password_rules.dart';
import '../../widgets/password_requirement_hints.dart';

class ChangePasswordScreen extends StatefulWidget {
  static const routeName = '/profile/change-password';

  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _newCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!AppwriteConfig.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appwrite is not configured.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final oldPw = _currentCtrl.text;
      await AppwriteService.account.updatePassword(
        password: _newCtrl.text,
        oldPassword: oldPw.trim().isEmpty ? null : oldPw,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
      Navigator.of(context).pop();
    } on AppwriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not update password.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update password.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Change password'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Use your current password and choose a new one. If you use email login, current password is required.',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _currentCtrl,
                  obscureText: _obscureCurrent,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      icon: Icon(_obscureCurrent ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newCtrl,
                  obscureText: _obscureNew,
                  textInputAction: TextInputAction.next,
                  maxLength: PasswordRules.maxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) {
                    final m = maxLength ?? PasswordRules.maxLength;
                    final near = PasswordRules.isNearMaxLength(_newCtrl.text);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$currentLength / $m',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: near
                                ? const Color(0xFFB8860B)
                                : Colors.black.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    );
                  },
                  decoration: InputDecoration(
                    labelText: 'New password',
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) {
                    final value = v ?? '';
                    if (value.isEmpty) return 'Enter a new password';
                    final rule = PasswordRules.validate(value);
                    if (rule != null) return rule;
                    if (value == _currentCtrl.text) {
                      return 'New password must differ from current';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'Confirm your new password';
                    if (v != _newCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!_submitting) {
                      _submit();
                    }
                  },
                ),
                PasswordRequirementHints(password: _newCtrl.text, brandGreen: accent),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Update password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
