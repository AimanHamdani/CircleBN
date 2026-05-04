import 'dart:async';

import 'package:appwrite/appwrite.dart';

import 'appwrite_config.dart';
import 'appwrite_service.dart';

/// Subscribes to Appwrite Realtime on shared collections so remote creates/updates/deletes
/// bump [AppwriteService.dataVersion] and list screens stay in sync without polling.
///
/// Chat message collections are omitted here so a new message does not bump
/// [dataVersion] and reload every list screen. Circle unread badges use
/// [CircleUnreadRealtimeSync] instead.
class AppwriteGlobalRealtimeSync {
  AppwriteGlobalRealtimeSync._();

  static RealtimeSubscription? _subscription;
  static StreamSubscription<RealtimeMessage>? _streamSubscription;
  static Timer? _debounce;

  static const Duration _debounceDelay = Duration(milliseconds: 450);

  static String _documentsChannel(String collectionId) {
    final trimmed = collectionId.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final db = AppwriteConfig.databaseId.trim();
    if (db.isEmpty) {
      return '';
    }
    return 'databases.$db.collections.$trimmed.documents';
  }

  /// Starts a single Realtime subscription if Appwrite is configured and not already running.
  static void start() {
    if (!AppwriteService.isConfigured || _subscription != null) {
      return;
    }
    final channels = <String>{
      _documentsChannel(AppwriteConfig.eventsCollectionId),
      _documentsChannel(AppwriteConfig.clubsCollectionId),
      _documentsChannel(AppwriteConfig.clubMembersCollectionId),
      _documentsChannel(AppwriteConfig.eventRegistrationsCollectionId),
      _documentsChannel(AppwriteConfig.notificationsCollectionId),
      _documentsChannel(AppwriteConfig.profilesCollectionId),
      _documentsChannel(AppwriteConfig.attendanceCollectionId),
    }..removeWhere((c) => c.isEmpty);

    if (channels.isEmpty) {
      return;
    }

    try {
      _subscription = AppwriteService.realtime.subscribe(channels.toList());
      _streamSubscription = _subscription!.stream.listen(
        (_) => _scheduleDebouncedNotify(),
        onError: (_) {},
      );
    } catch (_) {
      stop();
    }
  }

  static void _scheduleDebouncedNotify() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      _debounce = null;
      AppwriteService.notifyDataChanged();
    });
  }

  /// Tears down the subscription and any pending debounced notify.
  static void stop() {
    _debounce?.cancel();
    _debounce = null;
    unawaited(_streamSubscription?.cancel());
    _streamSubscription = null;
    _subscription?.close();
    _subscription = null;
  }
}
