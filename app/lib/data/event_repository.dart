import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../auth/current_user.dart';
import '../models/event.dart';
import '../models/event_privacy.dart';
import 'event_registration_repository.dart';
import 'sample_events.dart';

abstract class EventRepository {
  Future<List<Event>> listEvents();
}

class SampleEventRepository implements EventRepository {
  @override
  Future<List<Event>> listEvents() async {
    return SampleEvents.all;
  }
}

class AppwriteEventRepository implements EventRepository {
  bool _canViewEvent({
    required Event event,
    required String currentUserId,
    required Set<String> myEventIds,
  }) {
    if (!EventPrivacy.hidesFromPublicBrowse(event.privacy)) {
      return true;
    }
    if ((event.creatorId ?? '').trim() == currentUserId) {
      return true;
    }
    if (myEventIds.contains(event.id)) {
      return true;
    }
    return event.invitedUserIds.contains(currentUserId);
  }

  @override
  Future<List<Event>> listEvents() async {
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.eventsCollectionId.isEmpty) {
      return SampleEvents.all;
    }

    final docs = await AppwriteService.listDocuments(
      collectionId: AppwriteConfig.eventsCollectionId,
      queries: [Query.limit(5000)],
    );

    final events =
        docs.documents
            .map(
              (d) =>
                  Event.fromMap(Map<String, dynamic>.from(d.data), id: d.$id),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    final myId = currentUserId;
    if (myId.trim().isEmpty) {
      return events
          .where((e) => !EventPrivacy.hidesFromPublicBrowse(e.privacy))
          .toList();
    }
    final myEventIds = await eventRegistrationRepository()
        .listMyRegisteredEventIds(myId);
    return events
        .map((e) => e.copyWith(joinedByMe: myEventIds.contains(e.id)))
        .where(
          (e) => _canViewEvent(
            event: e,
            currentUserId: myId,
            myEventIds: myEventIds,
          ),
        )
        .toList();
  }
}

EventRepository eventRepository() {
  if (!AppwriteConfig.isConfigured) {
    return SampleEventRepository();
  }

  return AppwriteEventRepository();
}
