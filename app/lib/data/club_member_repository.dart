import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';

enum ClubMemberRole {
  admin,
  member,
}

class ClubMember {
  final String clubId;
  final String userId;
  final ClubMemberRole role;
  final DateTime joinedAt;

  const ClubMember({
    required this.clubId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });
}

class ClubMemberRepository {
  bool get _isConfigured =>
      AppwriteService.isConfigured &&
      AppwriteConfig.databaseId.isNotEmpty &&
      AppwriteConfig.clubMembersCollectionId.isNotEmpty;

  String _hash8(String input) {
    var hash = 0x811C9DC5;
    const prime = 0x01000193;
    const mask32 = 0xFFFFFFFF;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * prime) & mask32;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _docId(String clubId, String userId) {
    final clubHash = _hash8(clubId);
    final userHash = _hash8(userId);
    return 'cm_${clubHash}_$userHash';
  }

  ClubMemberRole _roleFromData(Map<String, dynamic> data) {
    final rawRole =
        (data['role'] ?? data['memberRole'] ?? data['member_role'] ?? 'member')
            .toString()
            .toLowerCase()
            .trim();
    if (rawRole == 'admin') return ClubMemberRole.admin;
    return ClubMemberRole.member;
  }

  DateTime _parseJoinedAt(Object? v) {
    if (v is DateTime) return v;
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _clubIdFromData(Map<String, dynamic> data) =>
      (data['clubId'] ?? data['club_id'] ?? '').toString();

  String _userIdFromData(Map<String, dynamic> data) =>
      (data['userId'] ?? data['userid'] ?? data['user_id'] ?? '').toString();

  Future<ClubMember?> getMember({
    required String clubId,
    required String userId,
  }) async {
    if (!_isConfigured || clubId.trim().isEmpty || userId.trim().isEmpty) {
      return null;
    }

    final docId = _docId(clubId, userId);
    try {
      final doc = await AppwriteService.getDocument(
        collectionId: AppwriteConfig.clubMembersCollectionId,
        documentId: docId,
      );
      final data = Map<String, dynamic>.from(doc.data);
      final role = _roleFromData(data);
      return ClubMember(
        clubId: _clubIdFromData(data).isNotEmpty ? _clubIdFromData(data) : clubId,
        userId: _userIdFromData(data).isNotEmpty ? _userIdFromData(data) : userId,
        role: role,
        joinedAt: _parseJoinedAt(data['joinedAt'] ?? data['joined_at'] ?? data['joinedat']),
      );
    } catch (_) {
      // Query fallback for schema variations / if doc id strategy differs.
    }

    try {
      final docs = await AppwriteService.listDocuments(
        collectionId: AppwriteConfig.clubMembersCollectionId,
        queries: [
          Query.equal('clubId', clubId),
          Query.equal('userId', userId),
          Query.limit(2),
        ],
      );
      if (docs.documents.isEmpty) return null;
      final data = Map<String, dynamic>.from(docs.documents.first.data);
      return ClubMember(
        clubId: _clubIdFromData(data).isNotEmpty ? _clubIdFromData(data) : clubId,
        userId: _userIdFromData(data).isNotEmpty ? _userIdFromData(data) : userId,
        role: _roleFromData(data),
        joinedAt: _parseJoinedAt(data['joinedAt'] ?? data['joined_at'] ?? data['joinedat']),
      );
    } on AppwriteException catch (_) {
      // Try lowercase keys.
      try {
        final docs = await AppwriteService.listDocuments(
          collectionId: AppwriteConfig.clubMembersCollectionId,
          queries: [
            Query.equal('clubid', clubId),
            Query.equal('userid', userId),
            Query.limit(2),
          ],
        );
        if (docs.documents.isEmpty) return null;
        final data = Map<String, dynamic>.from(docs.documents.first.data);
        return ClubMember(
          clubId: _clubIdFromData(data).isNotEmpty ? _clubIdFromData(data) : clubId,
          userId: _userIdFromData(data).isNotEmpty ? _userIdFromData(data) : userId,
          role: _roleFromData(data),
          joinedAt: _parseJoinedAt(data['joinedAt'] ?? data['joined_at'] ?? data['joinedat']),
        );
      } catch (_) {
        return null;
      }
    }
  }

  Future<List<ClubMember>> listMembers({
    required String clubId,
    int limit = 1000,
  }) async {
    if (!_isConfigured || clubId.trim().isEmpty) {
      return const <ClubMember>[];
    }

    final docs = await AppwriteService.listDocuments(
      collectionId: AppwriteConfig.clubMembersCollectionId,
      queries: [
        Query.equal('clubId', clubId),
        Query.limit(limit),
      ],
    ).catchError((_) async {
      // Lowercase fallback.
      return await AppwriteService.listDocuments(
        collectionId: AppwriteConfig.clubMembersCollectionId,
        queries: [
          Query.equal('clubid', clubId),
          Query.limit(limit),
        ],
      );
    });

    return docs.documents.map((d) {
      final data = Map<String, dynamic>.from(d.data);
      final memberClubId = _clubIdFromData(data).isNotEmpty ? _clubIdFromData(data) : clubId;
      final memberUserId = _userIdFromData(data).isNotEmpty ? _userIdFromData(data) : '';
      final role = _roleFromData(data);
      return ClubMember(
        clubId: memberClubId,
        userId: memberUserId,
        role: role,
        joinedAt: _parseJoinedAt(data['joinedAt'] ?? data['joined_at'] ?? data['joinedat']),
      );
    }).where((m) => m.userId.trim().isNotEmpty).toList();
  }

  /// All club memberships for a user (for calendars, “my clubs” filters, etc.).
  Future<List<ClubMember>> listMembershipsForUser({
    required String userId,
    int limit = 500,
  }) async {
    if (!_isConfigured || userId.trim().isEmpty) {
      return const <ClubMember>[];
    }

    List<ClubMember> mapDocs(dynamic docList) {
      return docList.documents.map<ClubMember>((d) {
        final data = Map<String, dynamic>.from(d.data);
        final memberClubId = _clubIdFromData(data);
        final memberUserId = _userIdFromData(data);
        final role = _roleFromData(data);
        return ClubMember(
          clubId: memberClubId,
          userId: memberUserId,
          role: role,
          joinedAt: _parseJoinedAt(data['joinedAt'] ?? data['joined_at'] ?? data['joinedat']),
        );
      }).where((m) => m.clubId.trim().isNotEmpty && m.userId.trim().isNotEmpty).toList();
    }

    try {
      final docs = await AppwriteService.listDocuments(
        collectionId: AppwriteConfig.clubMembersCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.limit(limit),
        ],
      );
      return mapDocs(docs);
    } catch (_) {
      try {
        final docs = await AppwriteService.listDocuments(
          collectionId: AppwriteConfig.clubMembersCollectionId,
          queries: [
            Query.equal('userid', userId),
            Query.limit(limit),
          ],
        );
        return mapDocs(docs);
      } catch (_) {
        return const <ClubMember>[];
      }
    }
  }

  Future<bool> isAdmin({
    required String clubId,
    required String userId,
  }) async {
    final m = await getMember(clubId: clubId, userId: userId);
    return m?.role == ClubMemberRole.admin;
  }

  Future<bool> isMember({
    required String clubId,
    required String userId,
  }) async {
    final m = await getMember(clubId: clubId, userId: userId);
    return m != null;
  }

  Future<void> joinAsMember({
    required String clubId,
    required String userId,
    ClubMemberRole role = ClubMemberRole.member,
  }) async {
    if (!_isConfigured || clubId.trim().isEmpty || userId.trim().isEmpty) {
      return;
    }

    final docId = _docId(clubId, userId);
    final roleValue = role == ClubMemberRole.admin ? 'admin' : 'member';

    final data = <String, dynamic>{
      'clubId': clubId,
      'userId': userId,
      'role': roleValue,
      'joinedAt': DateTime.now().toIso8601String(),
    };

    try {
      await AppwriteService.createDocument(
        collectionId: AppwriteConfig.clubMembersCollectionId,
        documentId: docId,
        data: data,
      );
      return;
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        // Already exists.
        return;
      }

      // Retry with lowercase keys for compatibility.
      await AppwriteService.createDocument(
        collectionId: AppwriteConfig.clubMembersCollectionId,
        documentId: docId,
        data: <String, dynamic>{
          'clubid': clubId,
          'userid': userId,
          'role': roleValue,
          'joinedat': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  Future<void> leaveClub({
    required String clubId,
    required String userId,
  }) async {
    if (!_isConfigured || clubId.trim().isEmpty || userId.trim().isEmpty) {
      return;
    }

    final docId = _docId(clubId, userId);
    try {
      await AppwriteService.deleteDocument(
        collectionId: AppwriteConfig.clubMembersCollectionId,
        documentId: docId,
      );
      return;
    } on AppwriteException catch (e) {
      if (e.code != 404) {
        rethrow;
      }
      // Fall through to query fallback for legacy/non-deterministic IDs.
    }

    Future<String?> findDocId({required bool lowercaseKeys}) async {
      try {
        final docs = await AppwriteService.listDocuments(
          collectionId: AppwriteConfig.clubMembersCollectionId,
          queries: [
            Query.equal(lowercaseKeys ? 'clubid' : 'clubId', clubId),
            Query.equal(lowercaseKeys ? 'userid' : 'userId', userId),
            Query.limit(1),
          ],
        );
        if (docs.documents.isEmpty) {
          return null;
        }
        return docs.documents.first.$id;
      } catch (_) {
        return null;
      }
    }

    final found = await findDocId(lowercaseKeys: false) ??
        await findDocId(lowercaseKeys: true);
    if (found == null) {
      return;
    }

    await AppwriteService.deleteDocument(
      collectionId: AppwriteConfig.clubMembersCollectionId,
      documentId: found,
    );
  }

  Future<void> deleteMembersForClub(String clubId) async {
    if (!_isConfigured || clubId.trim().isEmpty) {
      return;
    }

    Future<List<dynamic>> loadDocs({required bool lowercaseKeys}) async {
      try {
        final docs = await AppwriteService.listDocuments(
          collectionId: AppwriteConfig.clubMembersCollectionId,
          queries: [
            Query.equal(lowercaseKeys ? 'clubid' : 'clubId', clubId),
            Query.limit(5000),
          ],
        );
        return docs.documents;
      } catch (_) {
        return const <dynamic>[];
      }
    }

    final docs = await loadDocs(lowercaseKeys: false);
    final fallbackDocs = docs.isEmpty ? await loadDocs(lowercaseKeys: true) : <dynamic>[];

    final toDelete = (docs.isEmpty ? fallbackDocs : docs).cast<dynamic>();
    for (final doc in toDelete) {
      try {
        await AppwriteService.deleteDocument(
          collectionId: AppwriteConfig.clubMembersCollectionId,
          documentId: (doc as dynamic).$id as String,
        );
      } catch (_) {
        // Best-effort cleanup.
      }
    }
  }

  Future<void> setRole({
    required String clubId,
    required String userId,
    required ClubMemberRole role,
  }) async {
    if (!_isConfigured || clubId.trim().isEmpty || userId.trim().isEmpty) {
      return;
    }

    final roleValue = role == ClubMemberRole.admin ? 'admin' : 'member';

    // First try deterministic doc ID update.
    final docId = _docId(clubId, userId);
    try {
      await AppwriteService.updateDocument(
        collectionId: AppwriteConfig.clubMembersCollectionId,
        documentId: docId,
        data: {'role': roleValue},
      );
      return;
    } catch (_) {}

    // Fallback: find by query and update the first match.
    Future<String?> findDocId({required bool lowercaseKeys}) async {
      try {
        final docs = await AppwriteService.listDocuments(
          collectionId: AppwriteConfig.clubMembersCollectionId,
          queries: [
            Query.equal(lowercaseKeys ? 'clubid' : 'clubId', clubId),
            Query.equal(lowercaseKeys ? 'userid' : 'userId', userId),
            Query.limit(2),
          ],
        );
        if (docs.documents.isEmpty) {
          return null;
        }
        return docs.documents.first.$id;
      } catch (_) {
        return null;
      }
    }

    final found = await findDocId(lowercaseKeys: false) ?? await findDocId(lowercaseKeys: true);
    if (found == null) {
      return;
    }
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.clubMembersCollectionId,
      documentId: found,
      data: {'role': roleValue},
    );
  }

  /// Secure promotion via Appwrite Function (Option A).
  /// The function should validate that the caller is an admin of the club.
  Future<void> promoteToAdminViaFunction({
    required String clubId,
    required String targetUserId,
  }) async {
    if (!_isConfigured ||
        AppwriteConfig.promoteClubAdminFunctionId.isEmpty ||
        clubId.trim().isEmpty ||
        targetUserId.trim().isEmpty) {
      return;
    }

    await AppwriteService.executeFunction(
      functionId: AppwriteConfig.promoteClubAdminFunctionId,
      payload: <String, dynamic>{
        'clubId': clubId,
        'targetUserId': targetUserId,
      },
    );
  }
}

ClubMemberRepository clubMemberRepository() => ClubMemberRepository();

