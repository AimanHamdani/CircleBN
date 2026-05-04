import 'dart:async';

import 'package:appwrite/appwrite.dart';

import 'appwrite_config.dart';
import 'appwrite_service.dart';

/// Listens to club and DM message collections so circle unread badges can update
/// when someone else sends a message, without bumping [AppwriteService.dataVersion]
/// (which would reload every list screen).
class CircleUnreadRealtimeSync {
  CircleUnreadRealtimeSync._();

  static RealtimeSubscription? _subscription;
  static StreamSubscription<RealtimeMessage>? _streamSubscription;
  static Timer? _debounce;
  static void Function()? _onRemoteActivity;

  static const Duration _debounceDelay = Duration(milliseconds: 350);

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

  /// [onRemoteActivity] should be lightweight (e.g. refresh unread futures only).
  static void start(void Function() onRemoteActivity) {
    stop();
    if (!AppwriteService.isConfigured) {
      return;
    }
    _onRemoteActivity = onRemoteActivity;

    final channels = <String>{
      _documentsChannel(AppwriteConfig.clubMessagesCollectionId),
      _documentsChannel(AppwriteConfig.directMessagesCollectionId),
    }..removeWhere((c) => c.isEmpty);

    if (channels.isEmpty) {
      _onRemoteActivity = null;
      return;
    }

    try {
      _subscription = AppwriteService.realtime.subscribe(channels.toList());
      _streamSubscription = _subscription!.stream.listen(
        (_) => _scheduleDebouncedCallback(),
        onError: (_) {},
      );
    } catch (_) {
      stop();
    }
  }

  static void _scheduleDebouncedCallback() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      _debounce = null;
      _onRemoteActivity?.call();
    });
  }

  static void stop() {
    _debounce?.cancel();
    _debounce = null;
    unawaited(_streamSubscription?.cancel());
    _streamSubscription = null;
    _subscription?.close();
    _subscription = null;
    _onRemoteActivity = null;
  }
}
