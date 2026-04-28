import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../models/app_notification.dart';
import '../models/club.dart';
import 'club_member_repository.dart';
import 'notification_repository.dart';
import 'profile_repository.dart';
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

  Future<void> _notifyAdminsForJoinRequest({
    required Club club,
    required String requesterUserId,
  }) async {
    final recipients = <String>{};
    final creatorId = (club.creatorId ?? '').trim();
    if (creatorId.isNotEmpty) {
      recipients.add(creatorId);
    }
    try {
      final members = await clubMemberRepository().listMembers(clubId: club.id);
      for (final member in members) {
        if (member.role == ClubMemberRole.admin) {
          recipients.add(member.userId.trim());
        }
      }
    } catch (_) {
      // Best effort.
    }
    recipients.removeWhere((id) => id.isEmpty || id == requesterUserId);
    if (recipients.isEmpty) {
      return;
    }

    var requesterLabel = requesterUserId;
    try {
      final profile = await profileRepository().getProfileById(requesterUserId);
      final realName = profile.realName.trim();
      final username = profile.username.trim();
      if (realName.isNotEmpty && realName.toLowerCase() != 'name') {
        requesterLabel = realName;
      } else if (username.isNotEmpty && username.toLowerCase() != 'username') {
        requesterLabel = username;
      }
    } catch (_) {
      // Best effort.
    }

    final createdAt = DateTime.now();
    for (final recipientId in recipients) {
      final notification = AppNotification(
        id: 'club_join_request_${club.id}_$recipientId_${createdAt.microsecondsSinceEpoch}',
        userId: recipientId,
        type: AppNotificationType.eventJoinRequest,
        title: 'New club join request',
        message: '$requesterLabel requested to join ${club.name}.',
        createdAt: createdAt,
      );
      await notificationRepository().upsertMany(recipientId, [notification]);
    }
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
    await _notifyAdminsForJoinRequest(
      club: club,
      requesterUserId: trimmedUserId,
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
