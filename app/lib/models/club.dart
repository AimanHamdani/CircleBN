class Club {
  final String id;
  final String name;
  final String description;
  final Set<String> sports;

  final String privacy; // 'Public' | 'Private'
  final int memberLimit;
  final bool approvalRequired;
  final String whoCanSendMessages; // 'Everyone' | 'Admins only' | 'Admins & moderators'

  final String location; // optional but stored as empty string when unset

  // Storage file id for club photo/logo.
  final String? thumbnailFileId;

  // Used for creator-only actions.
  final String? creatorId;

  const Club({
    required this.id,
    required this.name,
    required this.description,
    required this.sports,
    this.privacy = 'Public',
    this.memberLimit = 0,
    this.approvalRequired = false,
    this.whoCanSendMessages = 'Everyone',
    this.location = '',
    this.thumbnailFileId,
    this.creatorId,
  });

  factory Club.fromMap(Map<String, dynamic> data, {required String id}) {
    final rawSports = data['sports'];
    final parsedSports = rawSports is List
        ? rawSports.map((e) => e.toString()).toSet()
        : rawSports is String
            ? rawSports
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toSet()
            : <String>{};

    int parseInt(Object? v, {int defaultValue = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? defaultValue;
      return defaultValue;
    }

    bool parseBool(Object? v, {bool defaultValue = false}) {
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      if (v is num) return v != 0;
      return defaultValue;
    }

    return Club(
      id: id,
      name: (data['name'] ?? data['title'] ?? 'Club').toString(),
      description: (data['description'] ?? '').toString(),
      sports: parsedSports,
      privacy: (data['privacy'] ?? 'Public').toString(),
      memberLimit: parseInt(data['memberLimit'] ?? data['member_limit'], defaultValue: 0),
      approvalRequired: parseBool(data['approvalRequired'] ?? data['approval_required'], defaultValue: false),
      whoCanSendMessages: (data['whoCanSendMessages'] ?? data['who_can_send_messages'] ?? 'Everyone').toString(),
      location: (data['location'] ?? '').toString(),
      thumbnailFileId: data['thumbnailFileId']?.toString() ??
          data['thumbnail_file_id']?.toString() ??
          data['imageUrl']?.toString() ??
          data['image_url']?.toString(),
      creatorId: data['creatorId']?.toString() ?? data['creator_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'sports': sports.toList(),
      'privacy': privacy,
      'memberLimit': memberLimit,
      'approvalRequired': approvalRequired,
      'whoCanSendMessages': whoCanSendMessages,
      'location': location,
      'thumbnailFileId': thumbnailFileId,
      'creatorId': creatorId,
    };
  }
}

