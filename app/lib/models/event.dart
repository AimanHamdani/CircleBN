class Event {
  final String id;
  final String title;
  final String sport;
  final DateTime startAt;
  final Duration duration;
  final String location;
  final double? lat;
  final double? lng;
  final int joined;
  final int capacity;
  final String skillLevel; // e.g. "1 - 4"
  final String entryFeeLabel; // e.g. "Free"
  final String description;
  final bool joinedByMe;

  /// User ID of the event creator. Used to show Edit only to the creator.
  final String? creatorId;

  // File ID stored in Appwrite Storage for event thumbnail.
  final String? thumbnailFileId;

  const Event({
    required this.id,
    required this.title,
    required this.sport,
    required this.startAt,
    required this.duration,
    required this.location,
    this.lat,
    this.lng,
    required this.joined,
    required this.capacity,
    required this.skillLevel,
    required this.entryFeeLabel,
    required this.description,
    required this.joinedByMe,
    this.creatorId,
    this.thumbnailFileId,
  });

  factory Event.fromMap(Map<String, dynamic> data, {required String id}) {
    DateTime parseDateTime(Object? v) {
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    Duration parseDuration(Object? v) {
      if (v is Duration) return v;
      if (v is int) return Duration(minutes: v);
      if (v is String) {
        final n = int.tryParse(v);
        if (n != null) return Duration(minutes: n);
      }
      return const Duration(hours: 1);
    }

    int parseInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    bool parseBool(Object? v) {
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      if (v is int) return v != 0;
      return false;
    }

    double? parseDouble(Object? v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return Event(
      id: id,
      title: (data['title'] ?? data['name'] ?? 'Event').toString(),
      sport: (data['sport'] ?? 'Sport').toString(),
      startAt: parseDateTime(data['startAt'] ?? data['start_at'] ?? data['start']),
      duration: parseDuration(data['durationMinutes'] ?? data['duration_minutes'] ?? data['duration']),
      location: (data['location'] ?? 'Location').toString(),
      lat: parseDouble(data['lat'] ?? data['latitude']),
      lng: parseDouble(data['lng'] ?? data['longitude'] ?? data['lon']),
      joined: parseInt(data['joined'] ?? data['joinedCount'] ?? data['joined_count']),
      capacity: parseInt(data['capacity'] ?? data['max'] ?? data['maxParticipants'] ?? data['max_participants']),
      skillLevel: (data['skillLevel'] ?? data['skill_level'] ?? '—').toString(),
      entryFeeLabel: (data['entryFeeLabel'] ?? data['entry_fee'] ?? data['fee'] ?? '—').toString(),
      description: (data['description'] ?? '').toString(),
      joinedByMe: parseBool(data['joinedByMe'] ?? data['joined_by_me'] ?? false),
      creatorId: data['creatorId']?.toString() ?? data['creator_id']?.toString(),
      thumbnailFileId: data['thumbnailFileId']?.toString() ??
          data['thumbnail_file_id']?.toString() ??
          data['imageUrl']?.toString() ??
          data['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'sport': sport,
      'startAt': startAt.toIso8601String(),
      'durationMinutes': duration.inMinutes,
      'location': location,
      'lat': lat,
      'lng': lng,
      'joined': joined,
      'capacity': capacity,
      'skillLevel': skillLevel,
      'entryFeeLabel': entryFeeLabel,
      'description': description,
      'joinedByMe': joinedByMe,
      'creatorId': creatorId,
      'thumbnailFileId': thumbnailFileId,
    };
  }

  Event copyWith({
    String? id,
    String? title,
    String? sport,
    DateTime? startAt,
    Duration? duration,
    String? location,
    double? lat,
    double? lng,
    int? joined,
    int? capacity,
    String? skillLevel,
    String? entryFeeLabel,
    String? description,
    bool? joinedByMe,
    String? creatorId,
    String? thumbnailFileId,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      sport: sport ?? this.sport,
      startAt: startAt ?? this.startAt,
      duration: duration ?? this.duration,
      location: location ?? this.location,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      joined: joined ?? this.joined,
      capacity: capacity ?? this.capacity,
      skillLevel: skillLevel ?? this.skillLevel,
      entryFeeLabel: entryFeeLabel ?? this.entryFeeLabel,
      description: description ?? this.description,
      joinedByMe: joinedByMe ?? this.joinedByMe,
      creatorId: creatorId ?? this.creatorId,
      thumbnailFileId: thumbnailFileId ?? this.thumbnailFileId,
    );
  }
}

