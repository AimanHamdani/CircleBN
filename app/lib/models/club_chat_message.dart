class ClubChatMessage {
  final String id;
  final String clubId;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageFileId;
  final String messageType;
  final String? targetEventId;
  final String? eventTitle;
  final DateTime? eventStartAt;
  final DateTime? eventEndAt;
  final String? eventLocation;
  final bool isPinned;
  final DateTime? pinnedAt;
  final DateTime createdAt;
  final DateTime? editedAt;

  const ClubChatMessage({
    required this.id,
    required this.clubId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.imageFileId,
    this.messageType = 'text',
    this.targetEventId,
    this.eventTitle,
    this.eventStartAt,
    this.eventEndAt,
    this.eventLocation,
    this.isPinned = false,
    this.pinnedAt,
    required this.createdAt,
    this.editedAt,
  });

  factory ClubChatMessage.fromMap(
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
    return ClubChatMessage(
      id: id,
      clubId: (data['clubId'] ?? data['clubid'] ?? '').toString(),
      senderId: (data['senderId'] ?? data['senderid'] ?? '').toString(),
      senderName: (data['senderName'] ?? data['sendername'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      imageFileId: (data['imageFileId'] ?? data['imagefileid'])?.toString(),
      messageType: (data['messageType'] ?? data['messagetype'] ?? 'text')
          .toString(),
      targetEventId: (data['targetEventId'] ?? data['targeteventid'])
          ?.toString(),
      eventTitle: (data['eventTitle'] ?? data['eventtitle'])?.toString(),
      eventStartAt: DateTime.tryParse(
        (data['eventStartAt'] ?? data['eventstartat'] ?? '').toString(),
      ),
      eventEndAt: DateTime.tryParse(
        (data['eventEndAt'] ?? data['eventendat'] ?? '').toString(),
      ),
      eventLocation: (data['eventLocation'] ?? data['eventlocation'])
          ?.toString(),
      isPinned: data['isPinned'] == true || data['ispinned'] == true,
      pinnedAt: DateTime.tryParse(
        (data['pinnedAt'] ?? data['pinnedat'] ?? '').toString(),
      ),
      createdAt: createdAt,
      editedAt:
          updatedAt != null &&
              updatedAt.isAfter(createdAt.add(const Duration(seconds: 1)))
          ? updatedAt
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clubId': clubId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'imageFileId': imageFileId,
      'messageType': messageType,
      'targetEventId': targetEventId,
      'eventTitle': eventTitle,
      'eventStartAt': eventStartAt?.toIso8601String(),
      'eventEndAt': eventEndAt?.toIso8601String(),
      'eventLocation': eventLocation,
      'isPinned': isPinned,
      'pinnedAt': pinnedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
