class DirectMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String? imageFileId;
  final DateTime createdAt;

  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.imageFileId,
    required this.createdAt,
  });

  factory DirectMessage.fromMap(Map<String, dynamic> map, {required String id}) {
    final createdRaw = (map['createdAt'] ?? map['\$createdAt']).toString();
    final createdAt = DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now();
    return DirectMessage(
      id: id,
      senderId: (map['senderId'] ?? '').toString(),
      receiverId: (map['receiverId'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      imageFileId: (map['imageFileId'] ?? '').toString().trim().isEmpty
          ? null
          : (map['imageFileId'] ?? '').toString(),
      createdAt: createdAt,
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
