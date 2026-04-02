import 'package:flutter/material.dart';

import '../auth/current_user.dart';
import '../auth/session_persistence.dart';
import '../utils/recovery_uri.dart';
import 'screens/home/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';

/// First screen: restores Appwrite session, then navigates to the real start route.
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final qp = recoveryLinkQueryParameters();
    final hasRecovery = recoveryLinkHasCredentials(qp);

    await SessionPersistence.restore();
    await CurrentUser.init();

    if (!mounted) {
      return;
    }

    if (hasRecovery) {
      Navigator.of(context).pushReplacementNamed(ResetPasswordScreen.routeName);
      return;
    }

    if (CurrentUser.isLoggedIn) {
      Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
    } else {
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
