import 'package:shared_preferences/shared_preferences.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import 'streak_repository.dart';

class BadgeDisplayRepository {
  static const String _prefix = 'display_badges_v1_';
  static const String _remoteField = 'displayBadgeIds';
  static SyncSource _lastReadSource = SyncSource.unknown;
  static SyncSource _lastWriteSource = SyncSource.unknown;

  SyncSource get lastReadSource {
    return _lastReadSource;
  }

  SyncSource get lastWriteSource {
    return _lastWriteSource;
  }

  Future<Set<String>> getSelectedBadgeIds(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return const <String>{};
    }

    final remote = await _loadRemoteBadgeIds(normalizedUserId);
    if (remote != null) {
      await _saveLocalBadgeIds(normalizedUserId, remote);
      _lastReadSource = SyncSource.remote;
      return remote;
    }

    _lastReadSource = SyncSource.local;
    return _loadLocalBadgeIds(normalizedUserId);
  }

  Future<Set<String>?> _loadRemoteBadgeIds(String userId) async {
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
      final raw = doc.data[_remoteField];
      if (raw is! List) {
        return const <String>{};
      }
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    } catch (_) {
      return null;
    }
  }

  Future<Set<String>> _loadLocalBadgeIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_prefix$userId') ?? const <String>[];
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<void> saveSelectedBadgeIds({
    required String userId,
    required Set<String> badgeIds,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }
    await _saveLocalBadgeIds(normalizedUserId, badgeIds);
    await _saveRemoteBadgeIds(normalizedUserId, badgeIds);
  }

  Future<void> _saveLocalBadgeIds(String userId, Set<String> badgeIds) async {
    final prefs = await SharedPreferences.getInstance();
    final list =
        badgeIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          ..sort();
    await prefs.setStringList('$_prefix$userId', list);
  }

  Future<void> _saveRemoteBadgeIds(String userId, Set<String> badgeIds) async {
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.profilesCollectionId.isEmpty) {
      return;
    }
    try {
      await AppwriteService.updateDocument(
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
        data: {_remoteField: badgeIds.toList()..sort()},
      );
      _lastWriteSource = SyncSource.remote;
    } catch (_) {
      // Keep local persistence as fallback when profile schema/permissions are missing.
      _lastWriteSource = SyncSource.local;
    }
  }
}

BadgeDisplayRepository badgeDisplayRepository() {
  return BadgeDisplayRepository();
}
