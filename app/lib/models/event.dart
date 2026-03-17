class Event {
  final String id;
  final String title;
  final String sport;
  final DateTime startAt;
  final Duration duration;
  final String location;
  final int joined;
  final int capacity;
  final String skillLevel; // e.g. "1 - 4"
  final String entryFeeLabel; // e.g. "Free"
  final String description;
  final bool joinedByMe;

  // For now we keep images simple (no assets/db yet).
  final String? imageUrl;

  const Event({
    required this.id,
    required this.title,
    required this.sport,
    required this.startAt,
    required this.duration,
    required this.location,
    required this.joined,
    required this.capacity,
    required this.skillLevel,
    required this.entryFeeLabel,
    required this.description,
    required this.joinedByMe,
    this.imageUrl,
  });
}

