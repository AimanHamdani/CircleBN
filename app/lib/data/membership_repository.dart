import 'dart:convert';

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

class MembershipBillingRecord {
  final String id;
  final String planId;
  final String status;
  final int amountCents;
  final String currency;
  final DateTime createdAt;
  final String description;

  const MembershipBillingRecord({
    required this.id,
    required this.planId,
    required this.status,
    required this.amountCents,
    required this.currency,
    required this.createdAt,
    required this.description,
  });

  factory MembershipBillingRecord.fromMap(Map<String, dynamic> map) {
    return MembershipBillingRecord(
      id: (map['id'] ?? '').toString(),
      planId: (map['planId'] ?? '').toString(),
      status: (map['status'] ?? 'paid').toString(),
      amountCents: (map['amountCents'] is int)
          ? map['amountCents'] as int
          : int.tryParse((map['amountCents'] ?? '0').toString()) ?? 0,
      currency: (map['currency'] ?? 'USD').toString(),
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      description: (map['description'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planId': planId,
      'status': status,
      'amountCents': amountCents,
      'currency': currency,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'description': description,
    };
  }
}

class MembershipRepository {
  static const String _prefix = 'membership_mock_v1_';
  static const String _prefsKey = 'membershipMock';
  static const String _billingKeyPrefix = 'membership_mock_billing_';

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
    await subscribeWithMockBilling(planId: planId);
  }

  /// Simulates a full mock billing flow and returns the created billing record.
  Future<MembershipBillingRecord> subscribeWithMockBilling({
    required String planId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final uid = currentUserId.trim();
    if (uid.isEmpty || uid == 'current_user_placeholder') {
      return MembershipBillingRecord(
        id: 'mock_invalid_user',
        planId: planId,
        status: 'failed',
        amountCents: _priceCentsForPlan(planId),
        currency: 'USD',
        createdAt: DateTime.now().toUtc(),
        description: 'Failed: no active user',
      );
    }

    final record = MembershipBillingRecord(
      id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
      planId: planId,
      status: 'paid',
      amountCents: _priceCentsForPlan(planId),
      currency: 'USD',
      createdAt: DateTime.now().toUtc(),
      description: planId == 'yearly'
          ? 'Mock yearly membership payment'
          : 'Mock monthly membership payment',
    );

    await _writeRemotePlan(planId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planKey(uid), planId);
    await _appendBillingRecord(uid, record);
    // Remove any legacy expiry value from previous mock behavior.
    await prefs.remove(_expKey(uid));
    return record;
  }

  /// Simulates cancel; access ends immediately in this mock (simple model).
  Future<void> cancelMock() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final uid = currentUserId.trim();
    if (uid.isEmpty || uid == 'current_user_placeholder') {
      return;
    }
    await _clearRemotePlan();
    await _appendBillingRecord(
      uid,
      MembershipBillingRecord(
        id: 'cancel_${DateTime.now().millisecondsSinceEpoch}',
        planId: 'cancel',
        status: 'cancelled',
        amountCents: 0,
        currency: 'USD',
        createdAt: DateTime.now().toUtc(),
        description: 'Mock membership cancellation',
      ),
    );
    await _clear(uid);
  }

  Future<List<MembershipBillingRecord>> listBillingHistory({
    int limit = 10,
  }) async {
    final uid = currentUserId.trim();
    if (uid.isEmpty || uid == 'current_user_placeholder') {
      return const <MembershipBillingRecord>[];
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_billingKey(uid));
    if (raw == null || raw.trim().isEmpty) {
      return const <MembershipBillingRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <MembershipBillingRecord>[];
      }
      final records = decoded
          .whereType<Map>()
          .map((e) => MembershipBillingRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records.take(limit).toList();
    } catch (_) {
      return const <MembershipBillingRecord>[];
    }
  }

  Future<void> _clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_expKey(uid));
    await prefs.remove(_planKey(uid));
  }

  String _expKey(String uid) => '$_prefix${uid}_exp';

  String _planKey(String uid) => '$_prefix${uid}_plan';

  String _billingKey(String uid) => '$_billingKeyPrefix$uid';

  int _priceCentsForPlan(String planId) {
    return planId == 'yearly' ? 3999 : 499;
  }

  Future<void> _appendBillingRecord(
    String uid,
    MembershipBillingRecord record,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await listBillingHistory(limit: 200);
    final updated = [record, ...existing].take(200).toList();
    await prefs.setString(
      _billingKey(uid),
      jsonEncode(updated.map((e) => e.toMap()).toList()),
    );
  }

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
