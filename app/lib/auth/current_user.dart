import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_service.dart';
import 'session_persistence.dart';

class CurrentUser {
  static const String _placeholderId = 'current_user_placeholder';

  static String _id = _placeholderId;

  static String get id => _id;

  /// True when Appwrite returned an active session from [init].
  static bool get isLoggedIn => _id != _placeholderId;

  static void reset() {
    _id = _placeholderId;
  }

  static Future<void> init() async {
    // Always reset before attempting to read the current session.
    // This prevents stale user IDs when the session was deleted/expired.
    reset();
    try {
      final me = await AppwriteService.account.get();
      _id = me.$id;
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        await SessionPersistence.clear();
      }
    } catch (_) {
      // No active Appwrite session yet.
    }
  }
}

String get currentUserId => CurrentUser.id;
