class DirectMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String? imageFileId;
  final DateTime createdAt;
  final DateTime? editedAt;

  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.imageFileId,
    required this.createdAt,
    this.editedAt,
  });

  factory DirectMessage.fromMap(
    Map<String, dynamic> map, {
    required String id,
    String? documentCreatedAt,
    String? documentUpdatedAt,
  }) {
    final createdRaw =
        (documentCreatedAt ?? map['createdAt'] ?? map['\$createdAt'])
            .toString();
    final createdAt =
        DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now();
    final updatedAt = DateTime.tryParse(
      (documentUpdatedAt ?? '').toString(),
    )?.toLocal();
    return DirectMessage(
      id: id,
      senderId: (map['senderId'] ?? '').toString(),
      receiverId: (map['receiverId'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      imageFileId: (map['imageFileId'] ?? '').toString().trim().isEmpty
          ? null
          : (map['imageFileId'] ?? '').toString(),
      createdAt: createdAt,
      editedAt:
          updatedAt != null &&
              updatedAt.isAfter(createdAt.add(const Duration(seconds: 1)))
          ? updatedAt
          : null,
    );
  }
}

class DirectMessageThread {
  final String otherUserId;
  final String previewText;
  final DateTime latestAt;
  final bool latestFromMe;

  const DirectMessageThread({
    required this.otherUserId,
    required this.previewText,
    required this.latestAt,
    required this.latestFromMe,
  });
}
