class Ticket {
  final int ticketId;
  final String eventId;
  final String userId;
  final DateTime generatedAt;

  const Ticket({
    required this.ticketId,
    required this.eventId,
    required this.userId,
    required this.generatedAt,
  });

  factory Ticket.fromMap(Map<String, dynamic> data) {
    return Ticket(
      ticketId: (data['ticketId'] ?? 0) as int,
      eventId: (data['eventId'] ?? '') as String,
      userId: (data['userId'] ?? '') as String,
      generatedAt: data['generatedAt'] is DateTime
          ? data['generatedAt'] as DateTime
          : DateTime.tryParse((data['generatedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticketId': ticketId,
      'eventId': eventId,
      'userId': userId,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}
