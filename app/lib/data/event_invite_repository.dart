import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../auth/current_user.dart';
import '../models/app_notification.dart';
import '../models/event.dart';
import '../models/event_privacy.dart';
import 'club_member_repository.dart';
import 'event_registration_repository.dart';
import 'notification_repository.dart';

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

  bool isPrivate(Event event) => EventPrivacy.isPrivateish(event.privacy);

  bool isRequestJoinPrivate(Event event) =>
      EventPrivacy.isRequestJoin(event.privacy);

  bool isInviteSearchPrivate(Event event) =>
      EventPrivacy.isInviteSearch(event.privacy);

  Future<void> submitJoinRequest({
    required String eventId,
    required String userId,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty ||
        !AppwriteService.isConfigured ||
        AppwriteConfig.eventsCollectionId.isEmpty) {
      return;
    }
    final doc = await AppwriteService.getDocument(
      collectionId: AppwriteConfig.eventsCollectionId,
      documentId: eventId,
    );
    final data = Map<String, dynamic>.from(doc.data);
    final raw =
        data['pendingJoinRequestUserIds'] ??
        data['pending_join_request_user_ids'];
    final existing = _parseIdList(raw);
    if (existing.contains(uid)) {
      return;
    }
    final next = [...existing, uid];
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.eventsCollectionId,
      documentId: eventId,
      data: {'pendingJoinRequestUserIds': next},
    );
  }

  Future<void> rejectJoinRequest({
    required String eventId,
    required String userId,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty ||
        !AppwriteService.isConfigured ||
        AppwriteConfig.eventsCollectionId.isEmpty) {
      return;
    }
    final doc = await AppwriteService.getDocument(
      collectionId: AppwriteConfig.eventsCollectionId,
      documentId: eventId,
    );
    final data = Map<String, dynamic>.from(doc.data);
    final existing = _parseIdList(
      data['pendingJoinRequestUserIds'] ??
          data['pending_join_request_user_ids'],
    );
    final next = existing.where((id) => id != uid).toList();
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.eventsCollectionId,
      documentId: eventId,
      data: {'pendingJoinRequestUserIds': next},
    );
    final createdAt = DateTime.now();
    await notificationRepository().upsertMany(uid, [
      AppNotification(
        id: 'event_join_request_rejected_${eventId}_${uid}_${createdAt.microsecondsSinceEpoch}',
        userId: uid,
        type: AppNotificationType.eventJoinRequest,
        title: 'Join request declined',
        message: 'Your request to join this event was declined.',
        createdAt: createdAt,
        targetEventId: eventId,
      ),
    ]);
  }

  Future<void> approveJoinRequest({
    required String eventId,
    required String userId,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) {
      return;
    }
    await eventRegistrationRepository().register(eventId: eventId, userId: uid);
    final joined = await eventRegistrationRepository().getJoinedCount(eventId);
    final doc = await AppwriteService.getDocument(
      collectionId: AppwriteConfig.eventsCollectionId,
      documentId: eventId,
    );
    final data = Map<String, dynamic>.from(doc.data);
    final existing = _parseIdList(
      data['pendingJoinRequestUserIds'] ??
          data['pending_join_request_user_ids'],
    );
    final next = existing.where((id) => id != uid).toList();
    await AppwriteService.updateDocument(
      collectionId: AppwriteConfig.eventsCollectionId,
      documentId: eventId,
      data: {'pendingJoinRequestUserIds': next, 'joined': joined},
    );
    final createdAt = DateTime.now();
    await notificationRepository().upsertMany(uid, [
      AppNotification(
        id: 'event_join_request_approved_${eventId}_${uid}_${createdAt.microsecondsSinceEpoch}',
        userId: uid,
        type: AppNotificationType.eventJoinRequest,
        title: 'Join request approved',
        message:
            'Your request was approved. You are now registered for this event.',
        createdAt: createdAt,
        targetEventId: eventId,
      ),
    ]);
  }

  List<String> _parseIdList(Object? v) {
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    if (v is String) {
      return v
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

EventInviteRepository eventInviteRepository() => EventInviteRepository();
