import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'auth/current_user.dart';
import 'ui/app_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // App still works without Firebase configured (mock auth flow).
  }
  await CurrentUser.init();
  runApp(const AppRoot());
}
