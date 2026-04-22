import 'package:shared_preferences/shared_preferences.dart';

import '../appwrite/appwrite_service.dart';
import '../auth/current_user.dart';

/// Local mock subscription state (no real store). Tied to the signed-in user id.
class MembershipStatus {
  final bool isPremium;
  final String? planId;
  final DateTime? renewsAt;

  const MembershipStatus({
    required this.isPremium,
    this.planId,
    this.renewsAt,
  });

  factory MembershipStatus.none() {
    return const MembershipStatus(isPremium: false);
  }

  String get planLabel {
    if (!isPremium || planId == null) {
      return '';
    }
    return planId == 'yearly' ? 'Yearly' : 'Monthly';
  }
}

class MembershipRepository {
  static const String _prefix = 'membership_mock_v1_';
  static const String _prefsKey = 'membershipMock';

  Future<MembershipStatus> getStatus() async {
    final uid = currentUserId.trim();
    if (uid.isEmpty || uid == 'current_user_placeholder') {
      return MembershipStatus.none();
    }
    final remote = await _readRemotePlan();
    if (remote != null && remote.trim().isNotEmpty) {
      return MembershipStatus(
        isPremium: true,
        planId: remote.trim(),
        renewsAt: null,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final plan = prefs.getString(_planKey(uid));
    if (plan == null) {
      return MembershipStatus.none();
    }
    // Permanent mock membership: active until the user explicitly cancels.
    return MembershipStatus(
      isPremium: true,
      planId: plan,
      renewsAt: null,
    );
  }

  /// Simulates checkout delay, then activates membership until manual cancel.
  Future<void> subscribeMock({required String planId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 850));
    final uid = currentUserId.trim();
    if (uid.isEmpty || uid == 'current_user_placeholder') {
      return;
    }
    await _writeRemotePlan(planId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planKey(uid), planId);
    // Remove any legacy expiry value from previous mock behavior.
    await prefs.remove(_expKey(uid));
  }

  /// Simulates cancel; access ends immediately in this mock (simple model).
  Future<void> cancelMock() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final uid = currentUserId.trim();
    if (uid.isEmpty || uid == 'current_user_placeholder') {
      return;
    }
    await _clearRemotePlan();
    await _clear(uid);
  }

  Future<void> _clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_expKey(uid));
    await prefs.remove(_planKey(uid));
  }

  String _expKey(String uid) => '$_prefix${uid}_exp';

  String _planKey(String uid) => '$_prefix${uid}_plan';

  Future<String?> _readRemotePlan() async {
    try {
      if (!AppwriteService.isConfigured) {
        return null;
      }
      final me = await AppwriteService.account.get();
      final prefsData = Map<String, dynamic>.from(me.prefs.data);
      final raw = prefsData[_prefsKey];
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final plan = map['planId']?.toString();
        if (plan != null && plan.trim().isNotEmpty) {
          return plan.trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeRemotePlan(String planId) async {
    try {
      if (!AppwriteService.isConfigured) {
        return;
      }
      final me = await AppwriteService.account.get();
      final nextPrefs = Map<String, dynamic>.from(me.prefs.data)
        ..[_prefsKey] = {
          'planId': planId,
          'active': true,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        };
      await AppwriteService.account.updatePrefs(prefs: nextPrefs);
    } catch (_) {
      // Local fallback still persists on supported platforms.
    }
  }

  Future<void> _clearRemotePlan() async {
    try {
      if (!AppwriteService.isConfigured) {
        return;
      }
      final me = await AppwriteService.account.get();
      final nextPrefs = Map<String, dynamic>.from(me.prefs.data)
        ..remove(_prefsKey);
      await AppwriteService.account.updatePrefs(prefs: nextPrefs);
    } catch (_) {
      // Best-effort clear.
    }
  }
}

MembershipRepository membershipRepository() {
  return MembershipRepository();
}
