import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'ui/app_root.dart';
import 'utils/url_strategy_config.dart';
import 'utils/web_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppUrlStrategy();
  await initWebStorage();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // App still works without Firebase configured (mock auth flow).
  }
  runApp(const AppRoot());
}
