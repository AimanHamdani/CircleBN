import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';

class EventRegistrationRepository {
  bool get _isConfigured =>
      AppwriteService.isConfigured &&
      AppwriteConfig.databaseId.isNotEmpty &&
      AppwriteConfig.eventRegistrationsCollectionId.isNotEmpty;

  String _docId(String eventId, String userId) {
    final eventHash = _hash8(eventId);
    final userHash = _hash8(userId);
    return 'reg_${eventHash}_$userHash';
  }

  String _hash8(String input) {
    var hash = 0x811C9DC5;
    const prime = 0x01000193;
    const mask32 = 0xFFFFFFFF;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * prime) & mask32;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<Set<String>> listMyRegisteredEventIds(String userId) async {
    if (!_isConfigured || userId.trim().isEmpty) {
      return const <String>{};
    }
    final scoped = await _loadDataWithQueryFallback(
      () => _queryByUserId(userId),
      (data) => _userIdFromData(data) == userId,
    );
    return scoped.map(_eventIdFromData).where((id) => id.isNotEmpty).toSet();
  }

  Future<List<String>> listParticipantUserIds(String eventId) async {
    if (!_isConfigured || eventId.trim().isEmpty) {
      return const <String>[];
    }
    final scoped = await _loadDataWithQueryFallback(
      () => _queryByEventId(eventId),
      (data) => _eventIdFromData(data) == eventId,
    );

    final sorted = List<Map<String, dynamic>>.from(scoped)
      ..sort((a, b) {
        final aRegisteredAt = _registeredAtMs(a);
        final bRegisteredAt = _registeredAtMs(b);
        if (aRegisteredAt != bRegisteredAt) {
          return aRegisteredAt.compareTo(bRegisteredAt);
        }

        final aUserId = _userIdFromData(a);
        final bUserId = _userIdFromData(b);
        return aUserId.compareTo(bUserId);
      });

    final seen = <String>{};
    final orderedUserIds = <String>[];
    for (final data in sorted) {
      final userId = _userIdFromData(data).trim();
      if (userId.isEmpty || !seen.add(userId)) {
        continue;
      }
      orderedUserIds.add(userId);
    }

    return orderedUserIds;
  }

  Future<int> getJoinedCount(String eventId) async {
    final ids = await listParticipantUserIds(eventId);
    return ids.length;
  }

  Future<bool> isRegistered({
    required String eventId,
    required String userId,
  }) async {
    if (!_isConfigured || eventId.trim().isEmpty || userId.trim().isEmpty) {
      return false;
    }
    final id = _docId(eventId, userId);
    try {
      await AppwriteService.getDocument(
        collectionId: AppwriteConfig.eventRegistrationsCollectionId,
        documentId: id,
      );
      return true;
    } catch (_) {
      final all = await _safeAllData();
      return all.any(
        (data) =>
            _eventIdFromData(data) == eventId &&
            _userIdFromData(data) == userId,
      );
    }
  }

  Future<void> register({
    required String eventId,
    required String userId,
  }) async {
    if (!_isConfigured || eventId.trim().isEmpty || userId.trim().isEmpty) {
      return;
    }
    final id = _docId(eventId, userId);
    try {
      await _createRegistrationDoc(
        id: id,
        eventId: eventId,
        userId: userId,
        lowercaseKeys: false,
      );
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        return;
      }
      // Retry with lowercase keys in case collection attributes were created that way.
      await _createRegistrationDoc(
        id: id,
        eventId: eventId,
        userId: userId,
        lowercaseKeys: true,
      );
    }
  }

  Future<void> cancel({required String eventId, required String userId}) async {
    if (!_isConfigured || eventId.trim().isEmpty || userId.trim().isEmpty) {
      return;
    }
    final id = _docId(eventId, userId);
    try {
      await AppwriteService.deleteDocument(
        collectionId: AppwriteConfig.eventRegistrationsCollectionId,
        documentId: id,
      );
      return;
    } on AppwriteException catch (e) {
      if (e.code != 404) {
        rethrow;
      }
    }

    // Fallback: if legacy/unknown doc IDs exist, delete by query match.
    final byEvent = await _queryByEventId(eventId);
    for (final doc in byEvent) {
      final data = Map<String, dynamic>.from(doc.data);
      if (_userIdFromData(data) == userId) {
        await AppwriteService.deleteDocument(
          collectionId: AppwriteConfig.eventRegistrationsCollectionId,
          documentId: doc.$id,
        );
      }
    }
  }

  Future<void> _createRegistrationDoc({
    required String id,
    required String eventId,
    required String userId,
    required bool lowercaseKeys,
  }) async {
    await AppwriteService.createDocument(
      collectionId: AppwriteConfig.eventRegistrationsCollectionId,
      documentId: id,
      data: {
        lowercaseKeys ? 'eventid' : 'eventId': eventId,
        lowercaseKeys ? 'userid' : 'userId': userId,
        'registeredAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadDataWithQueryFallback(
    Future<List<dynamic>> Function() queryLoader,
    bool Function(Map<String, dynamic>) matcher,
  ) async {
    try {
      return _toDataMaps(await queryLoader());
    } catch (_) {
      final all = await _safeAllData();
      return all.where(matcher).toList();
    }
  }

  List<Map<String, dynamic>> _toDataMaps(List<dynamic> docs) {
    return docs.map((d) => Map<String, dynamic>.from(d.data)).toList();
  }

  Future<List<Map<String, dynamic>>> _safeAllData() async {
    try {
      return _toDataMaps(await _listAllRegistrationDocs());
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<dynamic>> _listAllRegistrationDocs() async {
    final docs = await AppwriteService.listDocuments(
      collectionId: AppwriteConfig.eventRegistrationsCollectionId,
      queries: [Query.limit(5000)],
    );
    return docs.documents;
  }

  Future<List<dynamic>> _queryByEventId(String eventId) async {
    try {
      final docs = await AppwriteService.listDocuments(
        collectionId: AppwriteConfig.eventRegistrationsCollectionId,
        queries: [Query.equal('eventId', eventId), Query.limit(5000)],
      );
      return docs.documents;
    } on AppwriteException catch (_) {
      final docs = await AppwriteService.listDocuments(
        collectionId: AppwriteConfig.eventRegistrationsCollectionId,
        queries: [Query.equal('eventid', eventId), Query.limit(5000)],
      );
      return docs.documents;
    }
  }

  Future<List<dynamic>> _queryByUserId(String userId) async {
    try {
      final docs = await AppwriteService.listDocuments(
        collectionId: AppwriteConfig.eventRegistrationsCollectionId,
        queries: [Query.equal('userId', userId), Query.limit(5000)],
      );
      return docs.documents;
    } on AppwriteException catch (_) {
      final docs = await AppwriteService.listDocuments(
        collectionId: AppwriteConfig.eventRegistrationsCollectionId,
        queries: [Query.equal('userid', userId), Query.limit(5000)],
      );
      return docs.documents;
    }
  }

  String _eventIdFromData(Map<String, dynamic> data) {
    return data['eventId']?.toString() ?? data['eventid']?.toString() ?? '';
  }

  String _userIdFromData(Map<String, dynamic> data) {
    return data['userId']?.toString() ?? data['userid']?.toString() ?? '';
  }

  int _registeredAtMs(Map<String, dynamic> data) {
    final registeredAtRaw =
        data['registeredAt']?.toString() ?? data['registeredat']?.toString();
    if (registeredAtRaw == null || registeredAtRaw.trim().isEmpty) {
      return 0;
    }

    final parsed = DateTime.tryParse(registeredAtRaw.trim());
    if (parsed == null) {
      return 0;
    }

    return parsed.millisecondsSinceEpoch;
  }
}

EventRegistrationRepository eventRegistrationRepository() =>
    EventRegistrationRepository();
