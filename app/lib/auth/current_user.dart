import '../appwrite/appwrite_service.dart';

class CurrentUser {
  static String _id = 'current_user_placeholder';

  static String get id => _id;

  static Future<void> init() async {
    try {
      final me = await AppwriteService.account.get();
      _id = me.$id;
    } catch (_) {
      // No active Appwrite session yet.
    }
  }
}

String get currentUserId => CurrentUser.id;
