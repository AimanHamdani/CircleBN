import 'package:flutter_web_plugins/url_strategy.dart';

/// Use path URLs (`/path?x=1`) instead of hash (`/#/path?x=1`) so Appwrite recovery query params are visible to [Uri.base].
void configureAppUrlStrategy() {
  usePathUrlStrategy();
}
