import 'package:flutter/material.dart';

import '../../../models/signup_draft.dart';
import '../login_screen.dart';
import '../../theme/app_theme.dart';
import 'about_you_screen.dart';

class SignUpScreen extends StatefulWidget {
  static const routeName = '/signup';
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = SignUpDraft(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    Navigator.of(context).pushNamed(
      AboutYouScreen.routeName,
      arguments: draft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = AppTheme.brandGreen;
    return Scaffold(
      backgroundColor: const Color(0xFFEFF7F3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create account',
                style: TextStyle(
                  fontSize: 46 / 1.6,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: AppTheme.brandGreen,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Join the sports community',
                style: TextStyle(
                  color: Color(0xFF21A97A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 26),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Email', style: TextStyle(fontWeight: FontWeight.w700, color: green)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Email',
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
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Email is required';
                        if (!value.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Text('Password', style: TextStyle(fontWeight: FontWeight.w700, color: green)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Create a password',
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
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      validator: (v) {
                        final value = (v ?? '');
                        if (value.isEmpty) return 'Password is required';
                        if (value.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.w700, color: green)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Repeat your password',
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
                      ),
                      validator: (v) {
                        if ((v ?? '').isEmpty) return 'Confirm your password';
                        if (v != _passwordCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                      onFieldSubmitted: (_) => _next(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                child: const Text('Sign up'),
              ),
              const SizedBox(height: 14),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                        LoginScreen.routeName,
                        (_) => false,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: green,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Log in'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

