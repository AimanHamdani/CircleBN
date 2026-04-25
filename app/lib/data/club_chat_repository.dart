import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../models/club_chat_message.dart';

class ClubChatRepository {
  bool get _isConfigured =>
      AppwriteService.isConfigured &&
      AppwriteConfig.databaseId.isNotEmpty &&
      AppwriteConfig.clubMessagesCollectionId.isNotEmpty;

  Future<List<ClubChatMessage>> listForClub(
    String clubId, {
    int limit = 200,
  }) async {
    final trimmedClubId = clubId.trim();
    if (trimmedClubId.isEmpty || !_isConfigured) {
      return const <ClubChatMessage>[];
    }

    try {
      final docs = await AppwriteService.listDocuments(
        collectionId: AppwriteConfig.clubMessagesCollectionId,
        queries: [
          Query.equal('clubId', trimmedClubId),
          Query.orderAsc('createdAt'),
          Query.limit(limit),
        ],
      );

      return docs.documents
          .map(
            (doc) => ClubChatMessage.fromMap(
              Map<String, dynamic>.from(doc.data),
              id: doc.$id,
              documentCreatedAt: doc.$createdAt,
              documentUpdatedAt: doc.$updatedAt,
            ),
          )
          .where(
            (message) =>
                message.clubId.isNotEmpty &&
                message.senderId.isNotEmpty &&
                (message.messageType == 'event_pinned' ||
                    message.text.trim().isNotEmpty ||
                    (message.imageFileId?.trim().isNotEmpty ?? false)),
          )
          .toList();
    } catch (_) {
      return _listForClubLowercase(trimmedClubId, limit: limit);
    }
  }

  Future<List<ClubChatMessage>> _listForClubLowercase(
    String clubId, {
    required int limit,
  }) async {
    final docs = await AppwriteService.listDocuments(
      collectionId: AppwriteConfig.clubMessagesCollectionId,
      queries: [
        Query.equal('clubid', clubId),
        Query.limit(limit),
      ],
    );
    final items = docs.documents
        .map(
          (doc) => ClubChatMessage.fromMap(
            Map<String, dynamic>.from(doc.data),
            id: doc.$id,
            documentCreatedAt: doc.$createdAt,
            documentUpdatedAt: doc.$updatedAt,
          ),
        )
        .where(
          (message) =>
              message.clubId.isNotEmpty &&
              message.senderId.isNotEmpty &&
              (message.messageType == 'event_pinned' ||
                  message.text.trim().isNotEmpty ||
                  (message.imageFileId?.trim().isNotEmpty ?? false)),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<void> sendMessage({
    required String clubId,
    required String senderId,
    required String senderName,
    required String text,
    String? imageFileId,
  }) async {
    final trimmedClubId = clubId.trim();
    final trimmedSenderId = senderId.trim();
    final trimmedText = text.trim();
    if (trimmedClubId.isEmpty ||
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
      'clubId': trimmedClubId,
      'senderId': trimmedSenderId,
      'senderName': resolvedName,
      'text': trimmedText,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (resolvedImageId != null && resolvedImageId.isNotEmpty) {
      payload['imageFileId'] = resolvedImageId;
    }
    await AppwriteService.createDocument(
      collectionId: AppwriteConfig.clubMessagesCollectionId,
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
      collectionId: AppwriteConfig.clubMessagesCollectionId,
      documentId: trimmedId,
      data: {'text': trimmedText},
    );
  }

  Future<void> sendPinnedEventMessage({
    required String clubId,
    required String senderId,
    required String senderName,
    required String eventId,
    required String eventTitle,
    required DateTime eventStartAt,
    required String eventLocation,
  }) async {
    if (!_isConfigured) {
      return;
    }
    final trimmedClubId = clubId.trim();
    final trimmedSenderId = senderId.trim();
    if (trimmedClubId.isEmpty || trimmedSenderId.isEmpty) {
      return;
    }
    final payload = <String, dynamic>{
      'clubId': trimmedClubId,
      'senderId': trimmedSenderId,
      'senderName': senderName.trim().isEmpty ? 'Member' : senderName.trim(),
      'text': '',
      'messageType': 'event_pinned',
      'targetEventId': eventId.trim(),
      'eventTitle': eventTitle.trim(),
      'eventStartAt': eventStartAt.toUtc().toIso8601String(),
      'eventLocation': eventLocation.trim(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    await AppwriteService.createDocument(
      collectionId: AppwriteConfig.clubMessagesCollectionId,
      data: payload,
      permissions: [
        Permission.read(Role.users()),
        Permission.update(Role.users()),
        Permission.delete(Role.users()),
      ],
    );
  }

  Future<void> setPinned({
    required String messageId,
    required bool isPinned,
  }) async {
    if (!_isConfigured || messageId.trim().isEmpty) {
      return;
    }
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.clubMessagesCollectionId,
      documentId: messageId.trim(),
      data: {
        'isPinned': isPinned,
        'pinnedAt': isPinned ? DateTime.now().toUtc().toIso8601String() : null,
      },
    );
  }
}

ClubChatRepository clubChatRepository() => ClubChatRepository();
