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
    );

    await _migrateLegacyThumbnailField(docs.documents);

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

  Future<void> _migrateLegacyThumbnailField(List<dynamic> documents) async {
    final updates = <Future<void>>[];

    for (final d in documents) {
      final data = Map<String, dynamic>.from(d.data);
      final legacy = data['imageUrl'] ?? data['image_url'];
      final current = data['thumbnailFileId'] ?? data['thumbnail_file_id'];
      if ((current == null || current.toString().isEmpty) &&
          legacy != null &&
          legacy.toString().isNotEmpty) {
        updates.add(
          AppwriteService.updateDocument(
            collectionId: AppwriteConfig.eventsCollectionId,
            documentId: d.$id,
            data: {...data, 'thumbnailFileId': legacy.toString()},
          ).then((_) {}),
        );
      }
    }

    if (updates.isNotEmpty) {
      await Future.wait(updates);
    }
  }
}

EventRepository eventRepository() {
  if (!AppwriteConfig.isConfigured) {
    return SampleEventRepository();
  }

  return AppwriteEventRepository();
}
