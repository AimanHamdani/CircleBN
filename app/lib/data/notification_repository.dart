import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:shared_preferences/shared_preferences.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  static const _storagePrefix = 'app_notifications_v1_';

  bool get _isConfigured =>
      AppwriteService.isConfigured &&
      AppwriteConfig.databaseId.isNotEmpty &&
      AppwriteConfig.notificationsCollectionId.isNotEmpty;

  String _keyForUser(String userId) {
    return '$_storagePrefix$userId';
  }

  Future<List<AppNotification>> listForUser(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) {
      return const <AppNotification>[];
    }
    if (_isConfigured) {
      try {
        final remote = await _listRemote(uid);
        if (remote.isNotEmpty) {
          return remote;
        }
      } catch (_) {}
    }
    return _listLocal(uid);
  }

  Future<void> upsertMany(
    String userId,
    List<AppNotification> notifications,
  ) async {
    final uid = userId.trim();
    if (uid.isEmpty || notifications.isEmpty) {
      return;
    }

    if (_isConfigured) {
      try {
        for (final item in notifications) {
          if (item.userId.trim() != uid) {
            continue;
          }
          await AppwriteService.createOrUpdateDocument(
            collectionId: AppwriteConfig.notificationsCollectionId,
            documentId: item.id,
            data: _toRemoteMap(item),
          );
        }
      } catch (_) {}
    }

    final existing = await _listLocal(uid);
    final byId = <String, AppNotification>{for (final n in existing) n.id: n};
    for (final item in notifications) {
      if (item.userId.trim() != uid) {
        continue;
      }
      final previous = byId[item.id];
      byId[item.id] = item.copyWith(isRead: previous?.isRead ?? item.isRead);
    }
    await _saveLocal(uid, byId.values.toList());
  }

  Future<void> markRead({
    required String userId,
    required String notificationId,
  }) async {
    final uid = userId.trim();
    final nid = notificationId.trim();
    if (uid.isEmpty || nid.isEmpty) {
      return;
    }

    if (_isConfigured) {
      try {
        final existing = await AppwriteService.getDocument(
          collectionId: AppwriteConfig.notificationsCollectionId,
          documentId: nid,
        );
        final data = Map<String, dynamic>.from(existing.data);
        data['isRead'] = true;
        await AppwriteService.updateDocument(
          collectionId: AppwriteConfig.notificationsCollectionId,
          documentId: nid,
          data: data,
        );
      } catch (_) {}
    }

    final list = await _listLocal(uid);
    final next = list
        .map((n) => n.id == nid ? n.copyWith(isRead: true) : n)
        .toList();
    await _saveLocal(uid, next);
  }

  Future<void> markAllRead(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) {
      return;
    }

    if (_isConfigured) {
      try {
        final docs = await AppwriteService.listDocuments(
          collectionId: AppwriteConfig.notificationsCollectionId,
          queries: [
            Query.equal('userId', uid),
            Query.equal('isRead', false),
            Query.limit(5000),
          ],
        );
        for (final doc in docs.documents) {
          final data = Map<String, dynamic>.from(doc.data);
          data['isRead'] = true;
          await AppwriteService.updateDocument(
            collectionId: AppwriteConfig.notificationsCollectionId,
            documentId: doc.$id,
            data: data,
          );
        }
      } catch (_) {}
    }

    final list = await _listLocal(uid);
    final next = list.map((n) => n.copyWith(isRead: true)).toList();
    await _saveLocal(uid, next);
  }

  Future<List<AppNotification>> _listRemote(String userId) async {
    final docs = await AppwriteService.listDocuments(
      collectionId: AppwriteConfig.notificationsCollectionId,
      queries: [
        Query.equal('userId', userId),
        Query.limit(5000),
      ],
    );
    final items = docs.documents
        .map((doc) => _fromRemoteDoc(doc))
        .where((item) => item.id.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await _saveLocal(userId, items);
    return items;
  }

  AppNotification _fromRemoteDoc(models.Document doc) {
    final data = Map<String, dynamic>.from(doc.data);
    return AppNotification(
      id: doc.$id,
      userId: (data['userId'] ?? '').toString(),
      type: appNotificationTypeFromString((data['type'] ?? '').toString()),
      title: (data['title'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      isRead: data['isRead'] == true,
      targetEventId: data['targetEventId']?.toString(),
    );
  }

  Map<String, dynamic> _toRemoteMap(AppNotification item) {
    return {
      'userId': item.userId,
      'type': appNotificationTypeToString(item.type),
      'title': item.title,
      'message': item.message,
      'createdAt': item.createdAt.toIso8601String(),
      'isRead': item.isRead,
      'targetEventId': item.targetEventId,
    };
  }

  Future<List<AppNotification>> _listLocal(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForUser(userId));
    if (raw == null || raw.trim().isEmpty) {
      return const <AppNotification>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <AppNotification>[];
      }
      final items = decoded
          .whereType<Map>()
          .map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return const <AppNotification>[];
    }
  }

  Future<void> _saveLocal(
    String userId,
    List<AppNotification> notifications,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(notifications.map((n) => n.toMap()).toList());
    await prefs.setString(_keyForUser(userId), raw);
  }
}

NotificationRepository notificationRepository() => NotificationRepository();
