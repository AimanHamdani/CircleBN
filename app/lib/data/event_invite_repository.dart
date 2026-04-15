import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../auth/current_user.dart';
import '../models/event.dart';
import 'club_member_repository.dart';
import 'event_registration_repository.dart';

class EventInviteRepository {
  Future<List<String>> buildClubInviteeIds({
    required String clubId,
    required String creatorId,
  }) async {
    final members = await clubMemberRepository().listMembers(clubId: clubId);
    final ids =
        members
            .map((m) => m.userId.trim())
            .where((id) => id.isNotEmpty && id != creatorId)
            .toSet()
            .toList()
          ..sort();
    return ids;
  }

  Future<void> rejectInvite({
    required Event event,
    required String userId,
  }) async {
    final nextRejected = {...event.rejectedInviteUserIds, userId}.toList()
      ..sort();
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.eventsCollectionId,
      documentId: event.id,
      data: {'rejectedInviteUserIds': nextRejected},
    );
  }

  Future<void> acceptInvite({
    required Event event,
    required String userId,
  }) async {
    await eventRegistrationRepository().register(
      eventId: event.id,
      userId: userId,
    );
    final joined = await eventRegistrationRepository().getJoinedCount(event.id);
    final nextRejected = [...event.rejectedInviteUserIds]
      ..removeWhere((id) => id == userId);
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.eventsCollectionId,
      documentId: event.id,
      data: {'joined': joined, 'rejectedInviteUserIds': nextRejected},
    );
  }

  bool isInvited(Event event, {String? userId}) {
    final me = (userId ?? currentUserId).trim();
    if (me.isEmpty) {
      return false;
    }
    return event.invitedUserIds.contains(me);
  }

  bool isPrivate(Event event) {
    final privacy = (event.privacy ?? '').toLowerCase();
    return privacy.contains('private');
  }
}

EventInviteRepository eventInviteRepository() => EventInviteRepository();
