import 'package:shared_preferences/shared_preferences.dart';

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

  Future<MembershipStatus> getStatus() async {
    final uid = currentUserId.trim();
    if (uid.isEmpty) {
      return MembershipStatus.none();
    }
    final prefs = await SharedPreferences.getInstance();
    final expiresStr = prefs.getString(_expKey(uid));
    final plan = prefs.getString(_planKey(uid));
    if (expiresStr == null || plan == null) {
      return MembershipStatus.none();
    }
    final expires = DateTime.tryParse(expiresStr);
    if (expires == null || !expires.isAfter(DateTime.now())) {
      await _clear(uid);
      return MembershipStatus.none();
    }
    return MembershipStatus(
      isPremium: true,
      planId: plan,
      renewsAt: expires,
    );
  }

  /// Simulates checkout delay, then activates a rolling subscription window.
  Future<void> subscribeMock({required String planId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 850));
    final uid = currentUserId.trim();
    if (uid.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final expires = planId == 'yearly'
        ? now.add(const Duration(days: 365))
        : now.add(const Duration(days: 30));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planKey(uid), planId);
    await prefs.setString(_expKey(uid), expires.toIso8601String());
  }

  /// Simulates cancel; access ends immediately in this mock (simple model).
  Future<void> cancelMock() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final uid = currentUserId.trim();
    if (uid.isEmpty) {
      return;
    }
    await _clear(uid);
  }

  Future<void> _clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_expKey(uid));
    await prefs.remove(_planKey(uid));
  }

  String _expKey(String uid) => '${_prefix}${uid}_exp';

  String _planKey(String uid) => '${_prefix}${uid}_plan';
}

MembershipRepository membershipRepository() {
  return MembershipRepository();
}
