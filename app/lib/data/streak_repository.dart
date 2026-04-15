import 'package:shared_preferences/shared_preferences.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';

class DailyStreakState {
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastActiveDate;
  final bool isEligible;

  const DailyStreakState({
    required this.currentStreak,
    required this.bestStreak,
    required this.lastActiveDate,
    required this.isEligible,
  });
}

enum SyncSource { remote, local, unknown }

class StreakRepository {
  static const String _currentPrefix = 'daily_streak_current_v1_';
  static const String _bestPrefix = 'daily_streak_best_v1_';
  static const String _lastActivePrefix = 'daily_streak_last_active_v1_';
  static const String _remoteCurrentField = 'currentStreak';
  static const String _remoteBestField = 'bestStreak';
  static const String _remoteLastField = 'lastStreakDate';
  static SyncSource _lastReadSource = SyncSource.unknown;
  static SyncSource _lastWriteSource = SyncSource.unknown;

  SyncSource get lastReadSource {
    return _lastReadSource;
  }

  SyncSource get lastWriteSource {
    return _lastWriteSource;
  }

  Future<DailyStreakState> refreshForUser({
    required String userId,
    required bool hasStreakActivity,
    DateTime? now,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return const DailyStreakState(
        currentStreak: 0,
        bestStreak: 0,
        lastActiveDate: null,
        isEligible: false,
      );
    }

    final today = _dateOnly(now ?? DateTime.now());
    final remoteState = await _loadRemoteState(normalizedUserId);
    final localState = await _loadLocalState(normalizedUserId);

    var current = remoteState?.currentStreak ?? localState.currentStreak;
    var best = remoteState?.bestStreak ?? localState.bestStreak;
    final last = remoteState?.lastActiveDate ?? localState.lastActiveDate;
    _lastReadSource = remoteState == null
        ? SyncSource.local
        : SyncSource.remote;

    if (!hasStreakActivity) {
      if (last != null) {
        final dayDiff = today.difference(last).inDays;
        if (dayDiff >= 1 && current != 0) {
          current = 0;
          await _saveLocalState(
            userId: normalizedUserId,
            current: current,
            best: best,
            last: last,
          );
          await _saveRemoteState(
            userId: normalizedUserId,
            current: current,
            best: best,
            last: last,
          );
        }
      }
      return DailyStreakState(
        currentStreak: current,
        bestStreak: best,
        lastActiveDate: last,
        isEligible: false,
      );
    }

    if (last == null) {
      current = 1;
    } else {
      final dayDiff = today.difference(last).inDays;
      if (dayDiff <= 0) {
        // Same day access. Keep streak unchanged.
      } else if (dayDiff == 1) {
        current = current + 1;
      } else {
        // Missed at least one day, reset and start over today.
        current = 1;
      }
    }

    if (current > best) {
      best = current;
    }

    await _saveLocalState(
      userId: normalizedUserId,
      current: current,
      best: best,
      last: today,
    );
    await _saveRemoteState(
      userId: normalizedUserId,
      current: current,
      best: best,
      last: today,
    );

    return DailyStreakState(
      currentStreak: current,
      bestStreak: best,
      lastActiveDate: today,
      isEligible: true,
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Future<DailyStreakState?> _loadRemoteState(String userId) async {
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return null;
    }
    try {
      final doc = await AppwriteService.getDocument(
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
      );
      final current = _asInt(doc.data[_remoteCurrentField]);
      final best = _asInt(doc.data[_remoteBestField]);
      final last = _asDate(doc.data[_remoteLastField]);
      return DailyStreakState(
        currentStreak: current,
        bestStreak: best,
        lastActiveDate: last == null ? null : _dateOnly(last),
        isEligible: current > 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DailyStreakState> _loadLocalState(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('$_currentPrefix$userId') ?? 0;
    final best = prefs.getInt('$_bestPrefix$userId') ?? 0;
    final rawLast = prefs.getString('$_lastActivePrefix$userId');
    final last = rawLast == null ? null : DateTime.tryParse(rawLast);
    return DailyStreakState(
      currentStreak: current,
      bestStreak: best,
      lastActiveDate: last == null ? null : _dateOnly(last),
      isEligible: current > 0,
    );
  }

  Future<void> _saveLocalState({
    required String userId,
    required int current,
    required int best,
    required DateTime? last,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_currentPrefix$userId', current);
    await prefs.setInt('$_bestPrefix$userId', best);
    if (last == null) {
      await prefs.remove('$_lastActivePrefix$userId');
      return;
    }
    await prefs.setString('$_lastActivePrefix$userId', last.toIso8601String());
  }

  Future<void> _saveRemoteState({
    required String userId,
    required int current,
    required int best,
    required DateTime? last,
  }) async {
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return;
    }
    try {
      await AppwriteService.updateDocument(
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
        data: <String, dynamic>{
          _remoteCurrentField: current,
          _remoteBestField: best,
          _remoteLastField: last?.toIso8601String(),
        },
      );
      _lastWriteSource = SyncSource.remote;
    } catch (_) {
      // Keep local fallback when profile schema/permissions are missing.
      _lastWriteSource = SyncSource.local;
    }
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  DateTime? _asDate(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

StreakRepository streakRepository() {
  return StreakRepository();
}
