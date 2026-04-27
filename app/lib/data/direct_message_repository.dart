import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../models/direct_message.dart';

class DirectMessageRepository {
  static const Duration _editWindow = Duration(minutes: 30);
  Future<List<DirectMessage>> listConversation({
    required String userA,
    required String userB,
    int limit = 200,
  }) async {
    final a = userA.trim();
    final b = userB.trim();
    if (a.isEmpty || b.isEmpty) {
      return const <DirectMessage>[];
    }
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.directMessagesCollectionId.isEmpty) {
      return const <DirectMessage>[];
    }
    final aToB = await _listPair(senderId: a, receiverId: b, limit: limit);
    final bToA = await _listPair(senderId: b, receiverId: a, limit: limit);
    final all = <DirectMessage>[...aToB, ...bToA]
      ..sort((x, y) => x.createdAt.compareTo(y.createdAt));
    return all;
  }

  Future<List<DirectMessageThread>> listThreadsForUser({
    required String userId,
    int limit = 150,
  }) async {
    final me = userId.trim();
    if (me.isEmpty) {
      return const <DirectMessageThread>[];
    }
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.directMessagesCollectionId.isEmpty) {
      return const <DirectMessageThread>[];
    }
    final sent = await _listByField(field: 'senderId', value: me, limit: limit);
    final received = await _listByField(
      field: 'receiverId',
      value: me,
      limit: limit,
    );
    final merged = <DirectMessage>[...sent, ...received]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final seen = <String>{};
    final threads = <DirectMessageThread>[];
    for (final message in merged) {
      final other = message.senderId == me
          ? message.receiverId
          : message.senderId;
      if (other.trim().isEmpty || seen.contains(other)) {
        continue;
      }
      seen.add(other);
      final text = message.text.trim();
      final hasImage = (message.imageFileId ?? '').trim().isNotEmpty;
      threads.add(
        DirectMessageThread(
          otherUserId: other,
          previewText: text.isEmpty
              ? (hasImage ? 'Sent a photo' : 'Sent a message')
              : text,
          latestAt: message.createdAt,
          latestFromMe: message.senderId == me,
        ),
      );
    }
    return threads;
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    String text = '',
    String? imageFileId,
  }) async {
    final from = senderId.trim();
    final to = receiverId.trim();
    final body = text.trim();
    final imageId = imageFileId?.trim();
    if (from.isEmpty ||
        to.isEmpty ||
        (body.isEmpty && (imageId ?? '').isEmpty)) {
      return;
    }
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.directMessagesCollectionId.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'senderId': from,
      'receiverId': to,
      'text': body,
      if ((imageId ?? '').isNotEmpty) 'imageFileId': imageId,
      'createdAt': now.toIso8601String(),
    };
    await AppwriteService.createDocument(
      collectionId: AppwriteConfig.directMessagesCollectionId,
      data: payload,
    );
  }

  Future<void> editMessage({
    required String messageId,
    required String editorUserId,
    required String newText,
  }) async {
    final id = messageId.trim();
    final editor = editorUserId.trim();
    final text = newText.trim();
    if (id.isEmpty || editor.isEmpty || text.isEmpty) {
      return;
    }
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.directMessagesCollectionId.isEmpty) {
      return;
    }
    final doc = await AppwriteService.getDocument(
      collectionId: AppwriteConfig.directMessagesCollectionId,
      documentId: id,
    );
    final senderId = (doc.data['senderId'] ?? '').toString().trim();
    if (senderId != editor) {
      throw AppwriteException('You can only edit your own messages.', 401);
    }
    final createdAt =
        DateTime.tryParse(doc.$createdAt) ??
        DateTime.tryParse((doc.data['createdAt'] ?? '').toString());
    if (createdAt == null ||
        DateTime.now().toUtc().isAfter(createdAt.toUtc().add(_editWindow))) {
      throw AppwriteException(
        'Messages can only be edited within 30 minutes.',
        400,
      );
    }
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.directMessagesCollectionId,
      documentId: id,
      data: <String, dynamic>{'text': text},
    );
  }

  Future<List<DirectMessage>> _listPair({
    required String senderId,
    required String receiverId,
    required int limit,
  }) async {
    final docs = await AppwriteService.listDocuments(
      collectionId: AppwriteConfig.directMessagesCollectionId,
      queries: [
        Query.equal('senderId', senderId),
        Query.equal('receiverId', receiverId),
        Query.orderDesc('createdAt'),
        Query.limit(limit),
      ],
    );
    return docs.documents
        .map(
          (d) => DirectMessage.fromMap(
            Map<String, dynamic>.from(d.data),
            id: d.$id,
            documentCreatedAt: d.$createdAt,
            documentUpdatedAt: d.$updatedAt,
          ),
        )
        .toList();
  }

  Future<List<DirectMessage>> _listByField({
    required String field,
    required String value,
    required int limit,
  }) async {
    final docs = await AppwriteService.listDocuments(
      collectionId: AppwriteConfig.directMessagesCollectionId,
      queries: [
        Query.equal(field, value),
        Query.orderDesc('createdAt'),
        Query.limit(limit),
      ],
    );
    return docs.documents
        .map(
          (d) => DirectMessage.fromMap(
            Map<String, dynamic>.from(d.data),
            id: d.$id,
            documentCreatedAt: d.$createdAt,
            documentUpdatedAt: d.$updatedAt,
          ),
        )
        .toList();
  }
}

DirectMessageRepository directMessageRepository() => DirectMessageRepository();
