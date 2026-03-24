import '../appwrite/appwrite_service.dart';

class CurrentUser {
  static String _id = 'current_user_placeholder';

  static String get id => _id;

  static void reset() {
    _id = 'current_user_placeholder';
  }

  static Future<void> init() async {
    // Always reset before attempting to read the current session.
    // This prevents stale user IDs when the session was deleted/expired.
    reset();
    try {
      final me = await AppwriteService.account.get();
      _id = me.$id;
    } catch (_) {
      // No active Appwrite session yet.
    }
  }
}

String get currentUserId => CurrentUser.id;
