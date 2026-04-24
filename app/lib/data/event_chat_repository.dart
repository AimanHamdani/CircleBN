import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../models/event_chat_message.dart';

class EventChatRepository {
  bool get _isConfigured =>
      AppwriteService.isConfigured &&
      AppwriteConfig.databaseId.isNotEmpty &&
      AppwriteConfig.eventMessagesCollectionId.isNotEmpty;

  Future<List<EventChatMessage>> listForEvent(String eventId) async {
    final trimmedEventId = eventId.trim();
    if (trimmedEventId.isEmpty || !_isConfigured) {
      return const <EventChatMessage>[];
    }
    try {
      final docs = await AppwriteService.listDocuments(
        collectionId: AppwriteConfig.eventMessagesCollectionId,
        queries: [
          Query.equal('eventId', trimmedEventId),
          Query.orderAsc('createdAt'),
          Query.limit(500),
        ],
      );
      return docs.documents
          .map(
            (doc) => EventChatMessage.fromMap(
              Map<String, dynamic>.from(doc.data),
              id: doc.$id,
              documentCreatedAt: doc.$createdAt,
              documentUpdatedAt: doc.$updatedAt,
            ),
          )
          .where(
            (item) =>
                item.text.trim().isNotEmpty ||
                (item.imageFileId?.trim().isNotEmpty ?? false),
          )
          .toList();
    } catch (_) {
      return _listForEventLowercase(trimmedEventId);
    }
  }

  Future<List<EventChatMessage>> _listForEventLowercase(String eventId) async {
    final docs = await AppwriteService.listDocuments(
      collectionId: AppwriteConfig.eventMessagesCollectionId,
      queries: [
        Query.equal('eventid', eventId),
        Query.limit(500),
      ],
    );
    final items = docs.documents
        .map(
          (doc) => EventChatMessage.fromMap(
            Map<String, dynamic>.from(doc.data),
            id: doc.$id,
            documentCreatedAt: doc.$createdAt,
            documentUpdatedAt: doc.$updatedAt,
          ),
        )
        .where(
          (item) =>
              item.text.trim().isNotEmpty ||
              (item.imageFileId?.trim().isNotEmpty ?? false),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<void> sendMessage({
    required String eventId,
    required String senderId,
    required String senderName,
    required String text,
    String? imageFileId,
  }) async {
    final trimmedEventId = eventId.trim();
    final trimmedSenderId = senderId.trim();
    final trimmedText = text.trim();
    if (trimmedEventId.isEmpty ||
        trimmedSenderId.isEmpty ||
        (trimmedText.isEmpty &&
            (imageFileId == null || imageFileId.trim().isEmpty)) ||
        !_isConfigured) {
      return;
    }
    final resolvedName = senderName.trim().isEmpty ? 'Member' : senderName.trim();
    final resolvedImageId = imageFileId?.trim().isEmpty == true
        ? null
        : imageFileId?.trim();
    final payload = <String, dynamic>{
      'eventId': trimmedEventId,
      'senderId': trimmedSenderId,
      'senderName': resolvedName,
      'text': trimmedText,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (resolvedImageId != null && resolvedImageId.isNotEmpty) {
      payload['imageFileId'] = resolvedImageId;
    }
    await AppwriteService.createDocument(
      collectionId: AppwriteConfig.eventMessagesCollectionId,
      data: payload,
      permissions: [
        Permission.read(Role.users()),
        Permission.update(Role.users()),
        Permission.delete(Role.users()),
      ],
    );
  }

  Future<void> editMessage({
    required String messageId,
    required String newText,
  }) async {
    final trimmedId = messageId.trim();
    final trimmedText = newText.trim();
    if (!_isConfigured || trimmedId.isEmpty || trimmedText.isEmpty) {
      return;
    }
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.eventMessagesCollectionId,
      documentId: trimmedId,
      data: {'text': trimmedText},
    );
  }
}

EventChatRepository eventChatRepository() => EventChatRepository();
