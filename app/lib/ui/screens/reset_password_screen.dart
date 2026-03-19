import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';

import '../../appwrite/appwrite_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  static const routeName = '/reset-password';

  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureA = true;
  bool _obscureB = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _secretCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AppwriteService.account.updateRecovery(
        userId: _userIdCtrl.text.trim(),
        secret: _secretCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful. Please log in.')),
      );
      Navigator.of(context).pop();
    } on AppwriteException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to reset password.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reset password.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Reset Password'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Paste the User ID and Secret from your recovery email link.',
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _userIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'User ID',
                    hintText: 'userId from email link',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'User ID is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _secretCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Secret',
                    hintText: 'secret from email link',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Secret is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscureA,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureA = !_obscureA),
                      icon: Icon(_obscureA ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) {
                    final value = (v ?? '');
                    if (value.isEmpty) return 'Password is required';
                    if (value.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureB,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureB = !_obscureB),
                      icon: Icon(_obscureB ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) => v != _passwordCtrl.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Reset Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

