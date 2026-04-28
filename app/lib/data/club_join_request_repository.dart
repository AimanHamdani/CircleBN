import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../models/club.dart';
import 'club_member_repository.dart';
import 'club_repository.dart';

class ClubJoinRequestRepository {
  bool get _isConfigured =>
      AppwriteService.isConfigured &&
      AppwriteConfig.databaseId.isNotEmpty &&
      AppwriteConfig.clubsCollectionId.isNotEmpty;

  Future<Club> _requireClub(String clubId) async {
    final club = await clubRepository().getClub(clubId);
    if (club == null) {
      throw AppwriteException('Club not found.', 404);
    }
    return club;
  }

  bool _isPrivateWithApproval(Club club) {
    return club.privacy.trim().toLowerCase() == 'private';
  }

  Future<void> requestToJoin({
    required String clubId,
    required String userId,
  }) async {
    final trimmedClubId = clubId.trim();
    final trimmedUserId = userId.trim();
    if (!_isConfigured || trimmedClubId.isEmpty || trimmedUserId.isEmpty) {
      return;
    }

    final club = await _requireClub(trimmedClubId);
    if (!_isPrivateWithApproval(club)) {
      await clubMemberRepository().joinAsMember(
        clubId: trimmedClubId,
        userId: trimmedUserId,
        role: ClubMemberRole.member,
      );
      return;
    }

    final alreadyMember = await clubMemberRepository().isMember(
      clubId: trimmedClubId,
      userId: trimmedUserId,
    );
    if (alreadyMember) {
      return;
    }

    final existing = club.pendingJoinRequestUserIds.toSet();
    if (existing.contains(trimmedUserId)) {
      return;
    }
    final next = <String>[...existing, trimmedUserId];
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.clubsCollectionId,
      documentId: trimmedClubId,
      data: {'pendingJoinRequestUserIds': next},
    );
  }

  Future<void> approveJoinRequest({
    required String clubId,
    required String userId,
  }) async {
    final trimmedClubId = clubId.trim();
    final trimmedUserId = userId.trim();
    if (!_isConfigured || trimmedClubId.isEmpty || trimmedUserId.isEmpty) {
      return;
    }

    final club = await _requireClub(trimmedClubId);
    final next = club.pendingJoinRequestUserIds
        .where((id) => id != trimmedUserId)
        .toList();
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.clubsCollectionId,
      documentId: trimmedClubId,
      data: {'pendingJoinRequestUserIds': next},
    );
    await clubMemberRepository().joinAsMember(
      clubId: trimmedClubId,
      userId: trimmedUserId,
      role: ClubMemberRole.member,
    );
  }

  Future<void> rejectJoinRequest({
    required String clubId,
    required String userId,
  }) async {
    final trimmedClubId = clubId.trim();
    final trimmedUserId = userId.trim();
    if (!_isConfigured || trimmedClubId.isEmpty || trimmedUserId.isEmpty) {
      return;
    }

    final club = await _requireClub(trimmedClubId);
    final next = club.pendingJoinRequestUserIds
        .where((id) => id != trimmedUserId)
        .toList();
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.clubsCollectionId,
      documentId: trimmedClubId,
      data: {'pendingJoinRequestUserIds': next},
    );
  }
}

ClubJoinRequestRepository clubJoinRequestRepository() =>
    ClubJoinRequestRepository();
