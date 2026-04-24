class EventChatMessage {
  final String id;
  final String eventId;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageFileId;
  final DateTime createdAt;
  final DateTime? editedAt;

  const EventChatMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.imageFileId,
    required this.createdAt,
    this.editedAt,
  });

  factory EventChatMessage.fromMap(
    Map<String, dynamic> data, {
    required String id,
    String? documentCreatedAt,
    String? documentUpdatedAt,
  }) {
    final createdAt =
        DateTime.tryParse((documentCreatedAt ?? '').toString()) ??
        DateTime.tryParse(
          (data['createdAt'] ?? data['createdat'] ?? '').toString(),
        ) ??
        DateTime.now().toUtc();
    final updatedAt = DateTime.tryParse((documentUpdatedAt ?? '').toString());
    return EventChatMessage(
      id: id,
      eventId: (data['eventId'] ?? data['eventid'] ?? '').toString(),
      senderId: (data['senderId'] ?? data['senderid'] ?? '').toString(),
      senderName:
          (data['senderName'] ?? data['sendername'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      imageFileId: (data['imageFileId'] ?? data['imagefileid'])?.toString(),
      createdAt: createdAt,
      editedAt:
          updatedAt != null && updatedAt.isAfter(createdAt.add(const Duration(seconds: 1)))
          ? updatedAt
          : null,
    );
  }
}
