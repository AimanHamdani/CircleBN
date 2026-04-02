import 'package:shared_preferences/shared_preferences.dart';

const String _prefsKeyPrefix = 'web_storage_kv_';

final Map<String, String> _memory = <String, String>{};

/// Loads persisted keys into memory so [webGetString] is synchronous on mobile/desktop.
Future<void> initWebStorage() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    if (!key.startsWith(_prefsKeyPrefix)) {
      continue;
    }
    final shortKey = key.substring(_prefsKeyPrefix.length);
    _memory[shortKey] = prefs.getString(key) ?? '';
  }
}

String? webGetString(String key) => _memory[key];

void webSetString(String key, String value) {
  _memory[key] = value;
  SharedPreferences.getInstance().then((prefs) {
    return prefs.setString('$_prefsKeyPrefix$key', value);
  });
}
