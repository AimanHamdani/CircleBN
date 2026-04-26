import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../models/attendance.dart';

class AttendanceService {
  static const List<String> _fallbackCollectionIds = <String>[
    'attendance',
    'event_attendance',
    'event_attendances',
    'attendances',
  ];

  static const List<_AttendancePayloadKeySet> _payloadKeySets =
      <_AttendancePayloadKeySet>[
        _AttendancePayloadKeySet(
          event: 'eventId',
          ticket: 'ticketId',
          user: 'userId',
          markedAt: 'markedAt',
          scanner: 'scannerUserId',
        ),
        _AttendancePayloadKeySet(
          event: 'eventid',
          ticket: 'ticketid',
          user: 'userid',
          markedAt: 'markedat',
          scanner: 'scanneruserid',
        ),
        _AttendancePayloadKeySet(
          event: 'event_id',
          ticket: 'ticket_id',
          user: 'user_id',
          markedAt: 'marked_at',
          scanner: 'scanner_user_id',
        ),
        _AttendancePayloadKeySet(
          event: 'eventId',
          ticket: 'ticketId',
          user: 'userId',
          markedAt: 'checkedInAt',
          scanner: 'scannerUserId',
        ),
        _AttendancePayloadKeySet(
          event: 'event_id',
          ticket: 'ticket_id',
          user: 'user_id',
          markedAt: 'checked_in_at',
          scanner: 'scanner_user_id',
        ),
        _AttendancePayloadKeySet(
          event: 'eventId',
          ticket: 'ticketId',
          user: 'participantId',
          markedAt: 'markedAt',
          scanner: 'scannerUserId',
        ),
        _AttendancePayloadKeySet(
          event: 'event_id',
          ticket: 'ticket_id',
          user: 'participant_id',
          markedAt: 'marked_at',
          scanner: 'scanner_user_id',
        ),
        _AttendancePayloadKeySet(
          event: 'eventId',
          ticket: 'ticketId',
          user: 'attendeeId',
          markedAt: 'markedAt',
          scanner: 'scannerUserId',
        ),
        _AttendancePayloadKeySet(
          event: 'event_id',
          ticket: 'ticket_id',
          user: 'attendee_id',
          markedAt: 'marked_at',
          scanner: 'scanner_user_id',
        ),
      ];

  static const List<String> _eventQueryFields = <String>[
    'eventId',
    'eventid',
    'event_id',
    'event',
  ];

  static String? _resolvedCollectionId;

  /// Check if attendance is configured in Appwrite
  static bool get _isConfigured =>
      AppwriteService.isConfigured &&
      AppwriteConfig.databaseId.isNotEmpty &&
      _collectionCandidates.isNotEmpty;

  static List<String> get _collectionCandidates {
    final ids = <String>[];

    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || ids.contains(trimmed)) {
        return;
      }
      ids.add(trimmed);
    }

    add(AppwriteConfig.attendanceCollectionId);
    for (final collectionId in _fallbackCollectionIds) {
      add(collectionId);
    }

    return ids;
  }

  static bool _isCollectionNotFound(AppwriteException error) {
    final type = (error.type ?? '').toLowerCase();
    return error.code == 404 && type.contains('collection_not_found');
  }

  static bool _isInvalidStructure(AppwriteException error) {
    if (error.code != 400) {
      return false;
    }

    final type = (error.type ?? '').toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    return type.contains('document_invalid_structure') ||
        message.contains('unknown attribute') ||
        message.contains('invalid structure') ||
        message.contains('attribute');
  }

  static List<String> _attendanceDocumentPermissions() {
    return <String>[Permission.read(Role.users())];
  }

  static String _humanizeCreateAttendanceError(AppwriteException error) {
    final code = error.code;
    final type = (error.type ?? '').toLowerCase();
    final message = (error.message ?? '').trim();

    if (code == 401 || code == 403) {
      return 'Attendance write is not permitted. Update Appwrite attendance collection permissions to allow signed-in users to create and read documents.';
    }

    if (code == 404 && type.contains('collection_not_found')) {
      return 'Attendance collection was not found. Verify APPWRITE_ATTENDANCE_COLLECTION_ID matches your Appwrite collection ID.';
    }

    if (_isInvalidStructure(error)) {
      return 'Attendance collection attributes do not match expected fields. Required fields should include event ID, ticket ID, user/participant ID, and check-in time. scannerUserId is optional.';
    }

    if (message.isNotEmpty) {
      return 'Could not mark attendance: $message';
    }

    return 'Could not mark attendance right now. Please try again.';
  }

  static Future<T> _runOnAttendanceCollection<T>(
    Future<T> Function(String collectionId) operation,
  ) async {
    if (_collectionCandidates.isEmpty) {
      throw Exception('Attendance service not configured');
    }

    final preferred = _resolvedCollectionId;
    if (preferred != null && preferred.isNotEmpty) {
      try {
        return await operation(preferred);
      } on AppwriteException catch (error) {
        if (!_isCollectionNotFound(error)) {
          rethrow;
        }
        _resolvedCollectionId = null;
      }
    }

    for (final collectionId in _collectionCandidates) {
      if (collectionId == preferred) {
        continue;
      }

      try {
        final result = await operation(collectionId);
        _resolvedCollectionId = collectionId;
        return result;
      } on AppwriteException catch (error) {
        if (_isCollectionNotFound(error)) {
          continue;
        }
        rethrow;
      }
    }

    throw Exception(
      'Attendance storage is not configured. Set APPWRITE_ATTENDANCE_COLLECTION_ID to your attendance collection ID.',
    );
  }

  /// Generate a unique document ID for attendance record
  static String _docId(String eventId, int ticketId) {
    return '${eventId}_${ticketId.toString().padLeft(5, '0')}';
  }

  static List<Map<String, dynamic>> _buildAttendancePayloadCandidates({
    required String eventId,
    required int ticketId,
    required String userId,
    required DateTime markedAt,
    String? scannerUserId,
  }) {
    final payloads = <Map<String, dynamic>>[];
    final seenFingerprints = <String>{};
    final scannerId = scannerUserId?.trim();
    final markedAtIso = markedAt.toIso8601String();
    final markedAtMs = markedAt.millisecondsSinceEpoch;

    void addPayload({
      required _AttendancePayloadKeySet keys,
      required bool ticketAsString,
      required bool markedAtAsTimestamp,
      required bool includeScannerId,
    }) {
      final payload = <String, dynamic>{
        keys.event: eventId,
        keys.ticket: ticketAsString ? ticketId.toString() : ticketId,
        keys.user: userId,
        keys.markedAt: markedAtAsTimestamp ? markedAtMs : markedAtIso,
      };

      if (includeScannerId && scannerId != null && scannerId.isNotEmpty) {
        payload[keys.scanner] = scannerId;
      }

      final fingerprint = payload.entries
          .map((entry) => '${entry.key}:${entry.value}')
          .join('|');

      if (seenFingerprints.add(fingerprint)) {
        payloads.add(payload);
      }
    }

    for (final keys in _payloadKeySets) {
      for (final ticketAsString in <bool>[false, true]) {
        for (final markedAtAsTimestamp in <bool>[false, true]) {
          addPayload(
            keys: keys,
            ticketAsString: ticketAsString,
            markedAtAsTimestamp: markedAtAsTimestamp,
            includeScannerId: true,
          );
          addPayload(
            keys: keys,
            ticketAsString: ticketAsString,
            markedAtAsTimestamp: markedAtAsTimestamp,
            includeScannerId: false,
          );
        }
      }
    }

    return payloads;
  }

  static Future<void> _createAttendanceDocument({
    required String docId,
    required String eventId,
    required int ticketId,
    required String userId,
    String? scannerUserId,
    required DateTime markedAt,
  }) async {
    await _runOnAttendanceCollection((collectionId) async {
      final payloadCandidates = _buildAttendancePayloadCandidates(
        eventId: eventId,
        ticketId: ticketId,
        userId: userId,
        markedAt: markedAt,
        scannerUserId: scannerUserId,
      );

      AppwriteException? lastStructureError;

      for (final payload in payloadCandidates) {
        try {
          await AppwriteService.createDocument(
            collectionId: collectionId,
            documentId: docId,
            data: payload,
            permissions: _attendanceDocumentPermissions(),
          );
          return;
        } on AppwriteException catch (error) {
          if (error.code == 409) {
            rethrow;
          }

          if (_isInvalidStructure(error)) {
            lastStructureError = error;
            continue;
          }

          rethrow;
        }
      }

      if (lastStructureError != null) {
        throw lastStructureError;
      }

      throw Exception('Unable to create attendance record.');
    });
  }

  static Future<models.DocumentList> _listAttendanceByEvent({
    required String eventId,
  }) async {
    return await _runOnAttendanceCollection((collectionId) async {
      AppwriteException? lastStructureError;

      for (final field in _eventQueryFields) {
        try {
          return await AppwriteService.listDocuments(
            collectionId: collectionId,
            queries: [Query.equal(field, eventId), Query.limit(5000)],
          );
        } on AppwriteException catch (error) {
          if (_isInvalidStructure(error)) {
            lastStructureError = error;
            continue;
          }

          rethrow;
        }
      }

      if (lastStructureError != null) {
        // As a last resort, fetch a bounded set and filter in memory.
        return await AppwriteService.listDocuments(
          collectionId: collectionId,
          queries: [Query.limit(5000)],
        );
      }

      return await AppwriteService.listDocuments(
        collectionId: collectionId,
        queries: [Query.limit(5000)],
      );
    });
  }

  /// Mark attendance for a ticket at an event.
  ///
  /// Returns the created/updated Attendance object.
  /// Throws exception if already marked (duplicate prevention).
  static Future<Attendance> markAttendance({
    required String eventId,
    required int ticketId,
    required String userId,
    String? scannerUserId,
  }) async {
    if (!_isConfigured || eventId.trim().isEmpty) {
      throw Exception('Attendance service not configured');
    }

    final docId = _docId(eventId, ticketId);
    final now = DateTime.now();

    try {
      // Try to get existing record to prevent duplicates
      await _runOnAttendanceCollection(
        (collectionId) => AppwriteService.getDocument(
          collectionId: collectionId,
          documentId: docId,
        ),
      );

      // If we reach here, document already exists (duplicate)
      throw Exception('Attendance already marked for this ticket');
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        throw Exception('Attendance already marked for this ticket');
      }
      // 404 = document doesn't exist, which is good - we can create it
      // 401/403 may block pre-check but create can still return a definitive error.
    }

    // Create new attendance record
    try {
      await _createAttendanceDocument(
        docId: docId,
        eventId: eventId,
        ticketId: ticketId,
        userId: userId,
        scannerUserId: scannerUserId,
        markedAt: now,
      );

      return Attendance(
        eventId: eventId,
        ticketId: ticketId,
        userId: userId,
        markedAt: now,
        scannerUserId: scannerUserId,
      );
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        throw Exception('Attendance already marked for this ticket');
      }
      throw Exception(_humanizeCreateAttendanceError(e));
    } catch (e) {
      rethrow;
    }
  }

  /// Check if attendance is already marked for a ticket.
  static Future<bool> isAttendanceMarked({
    required String eventId,
    required int ticketId,
  }) async {
    if (!_isConfigured || eventId.trim().isEmpty) {
      return false;
    }

    final docId = _docId(eventId, ticketId);

    try {
      await _runOnAttendanceCollection(
        (collectionId) => AppwriteService.getDocument(
          collectionId: collectionId,
          documentId: docId,
        ),
      );
      return true;
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get all attendance records for an event.
  static Future<List<Attendance>> getAttendanceList(String eventId) async {
    if (!_isConfigured || eventId.trim().isEmpty) {
      return [];
    }

    try {
      final result = await _listAttendanceByEvent(eventId: eventId);

      return result.documents
          .map((doc) => Attendance.fromMap(Map<String, dynamic>.from(doc.data)))
          .where((item) => item.eventId.trim() == eventId.trim())
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch attendance list: $e');
    }
  }

  /// Get attendance record for a specific ticket.
  static Future<Attendance?> getAttendance({
    required String eventId,
    required int ticketId,
  }) async {
    if (!_isConfigured || eventId.trim().isEmpty) {
      return null;
    }

    final docId = _docId(eventId, ticketId);

    try {
      final doc = await _runOnAttendanceCollection(
        (collectionId) => AppwriteService.getDocument(
          collectionId: collectionId,
          documentId: docId,
        ),
      );

      return Attendance.fromMap(Map<String, dynamic>.from(doc.data));
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get count of marked attendees for an event.
  static Future<int> getAttendanceCount(String eventId) async {
    final list = await getAttendanceList(eventId);
    return list.length;
  }
}

class _AttendancePayloadKeySet {
  final String event;
  final String ticket;
  final String user;
  final String markedAt;
  final String scanner;

  const _AttendancePayloadKeySet({
    required this.event,
    required this.ticket,
    required this.user,
    required this.markedAt,
    required this.scanner,
  });
}
