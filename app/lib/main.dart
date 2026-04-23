import 'package:flutter/material.dart';

import 'ui/app_root.dart';
import 'utils/url_strategy_config.dart';
import 'utils/web_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppUrlStrategy();
  await initWebStorage();
  runApp(const AppRoot());
}
