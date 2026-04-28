class Club {
  final String id;
  final String name;
  final String description;
  final Set<String> sports;

  final String privacy; // 'Public' | 'Private'
  final int memberLimit;
  final bool approvalRequired;
  final String whoCanSendMessages; // 'Everyone' | 'Admins only'

  final String location; // optional but stored as empty string when unset

  // Storage file id for club photo/logo.
  final String? thumbnailFileId;

  // Used for creator-only actions.
  final String? creatorId;
  final String? founderId;
  final String? coCreatorId;

  /// When set in Appwrite (e.g. `membersCount`, `memberCount`), shown on club info.
  final int? membersCount;

  /// Optional stored admin count; defaults to 1 when [creatorId] is set in UI.
  final int? adminsCount;

  /// Custom founded date from attributes, or filled from document `$createdAt` in repository.
  final DateTime? foundedAt;
  final List<String> pendingJoinRequestUserIds;

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
    this.founderId,
    this.coCreatorId,
    this.membersCount,
    this.adminsCount,
    this.foundedAt,
    this.pendingJoinRequestUserIds = const <String>[],
  });

  factory Club.fromMap(
    Map<String, dynamic> data, {
    required String id,
    DateTime? documentCreatedAt,
  }) {
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

    int? parseOptionalInt(Object? v) {
      if (v == null) {
        return null;
      }
      if (v is int) {
        return v;
      }
      if (v is num) {
        return v.toInt();
      }
      if (v is String) {
        return int.tryParse(v.trim());
      }
      return null;
    }

    DateTime? parseOptionalDate(Object? v) {
      if (v == null) {
        return null;
      }
      if (v is DateTime) {
        return v;
      }
      if (v is String && v.trim().isNotEmpty) {
        return DateTime.tryParse(v.trim());
      }
      return null;
    }

    List<String> parseStringList(Object? v) {
      if (v is List) {
        return v
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      if (v is String) {
        return v
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return const <String>[];
    }

    final foundedFromData = parseOptionalDate(
      data['foundedAt'] ??
          data['founded_at'] ??
          data['createdAt'] ??
          data['created_at'],
    );

    return Club(
      id: id,
      name: (data['name'] ?? data['title'] ?? 'Club').toString(),
      description: (data['description'] ?? '').toString(),
      sports: parsedSports,
      privacy: (data['privacy'] ?? 'Public').toString(),
      memberLimit: parseInt(
        data['memberLimit'] ?? data['member_limit'],
        defaultValue: 0,
      ),
      approvalRequired: parseBool(
        data['approvalRequired'] ?? data['approval_required'],
        defaultValue: false,
      ),
      whoCanSendMessages: (() {
        final raw =
            (data['whoCanSendMessages'] ??
                    data['who_can_send_messages'] ??
                    'Everyone')
                .toString()
                .trim();
        if (raw == 'Admins only') {
          return 'Admins only';
        }
        return 'Everyone';
      })(),
      location: (data['location'] ?? '').toString(),
      thumbnailFileId:
          data['thumbnailFileId']?.toString() ??
          data['thumbnail_file_id']?.toString() ??
          data['imageUrl']?.toString() ??
          data['image_url']?.toString(),
      creatorId:
          data['creatorId']?.toString() ?? data['creator_id']?.toString(),
      founderId:
          data['founderId']?.toString() ??
          data['founder_id']?.toString() ??
          data['originalCreatorId']?.toString() ??
          data['original_creator_id']?.toString(),
      coCreatorId:
          data['coCreatorId']?.toString() ??
          data['co_creator_id']?.toString() ??
          data['successorCreatorId']?.toString() ??
          data['successor_creator_id']?.toString(),
      membersCount: parseOptionalInt(
        data['membersCount'] ??
            data['members_count'] ??
            data['memberCount'] ??
            data['member_count'] ??
            data['members'],
      ),
      adminsCount: parseOptionalInt(
        data['adminsCount'] ??
            data['admins_count'] ??
            data['adminCount'] ??
            data['admin_count'],
      ),
      foundedAt: foundedFromData ?? documentCreatedAt,
      pendingJoinRequestUserIds: parseStringList(
        data['pendingJoinRequestUserIds'] ??
            data['pending_join_request_user_ids'],
      ),
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
      'founderId': founderId,
      'coCreatorId': coCreatorId,
      if (membersCount != null) 'membersCount': membersCount,
      if (adminsCount != null) 'adminsCount': adminsCount,
      if (foundedAt != null) 'foundedAt': foundedAt!.toIso8601String(),
      'pendingJoinRequestUserIds': pendingJoinRequestUserIds,
    };
  }
}
