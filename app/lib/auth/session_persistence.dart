import 'package:shared_preferences/shared_preferences.dart';

import '../appwrite/appwrite_service.dart';

/// Persists the Appwrite session id so email/password login survives app/browser restarts.
class SessionPersistence {
  static const _key = 'circlebn_appwrite_session_id';

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    if (id != null && id.trim().isNotEmpty) {
      AppwriteService.applySessionId(id.trim());
    }
  }

  static Future<void> save(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, sessionId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
