class Attendance {
  final String eventId;
  final int ticketId;
  final String userId;
  final DateTime markedAt;
  final String? scannerUserId;

  const Attendance({
    required this.eventId,
    required this.ticketId,
    required this.userId,
    required this.markedAt,
    this.scannerUserId,
  });

  factory Attendance.fromMap(Map<String, dynamic> data) {
    return Attendance(
      eventId: (data['eventId'] ?? '') as String,
      ticketId: (data['ticketId'] ?? 0) as int,
      userId: (data['userId'] ?? '') as String,
      markedAt: data['markedAt'] is DateTime
          ? data['markedAt'] as DateTime
          : DateTime.tryParse((data['markedAt'] ?? '').toString()) ?? DateTime.now(),
      scannerUserId: data['scannerUserId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'ticketId': ticketId,
      'userId': userId,
      'markedAt': markedAt.toIso8601String(),
      if (scannerUserId != null) 'scannerUserId': scannerUserId,
    };
  }
}
