import '../appwrite/appwrite_service.dart';

const String kDeactivatedPrefsKey = 'accountDeactivated';

Future<bool> isCurrentAccountDeactivated() async {
  try {
    final me = await AppwriteService.account.get();
    final prefsData = Map<String, dynamic>.from(me.prefs.data);
    final raw = prefsData[kDeactivatedPrefsKey];
    if (raw is bool) {
      return raw;
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return map['value'] == true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

Future<void> deactivateCurrentAccount() async {
  final me = await AppwriteService.account.get();
  final prefsData = Map<String, dynamic>.from(me.prefs.data)
    ..[kDeactivatedPrefsKey] = {
      'value': true,
      'deactivatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  await AppwriteService.account.updatePrefs(prefs: prefsData);
}
