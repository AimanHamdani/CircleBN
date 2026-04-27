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

  static List<String> _extractRequiredAttributes(String message) {
    final matches = <String>{};

    final patterns = <RegExp>[
      RegExp(
        "required\\s+attribute\\s*:?\\s*[\"'`]([^\"'`]+)[\"'`]",
        caseSensitive: false,
      ),
      RegExp(
        "attribute\\s*:?\\s*[\"'`]([^\"'`]+)[\"'`]\\s+is\\s+required",
        caseSensitive: false,
      ),
      RegExp(
        "missing\\s+required\\s+attribute\\s*:?\\s*[\"'`]([^\"'`]+)[\"'`]",
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(message)) {
        final attribute = (match.group(1) ?? '').trim();
        if (attribute.isNotEmpty) {
          matches.add(attribute);
        }
      }
    }

    return matches.toList();
  }

  static List<String> _extractUnknownAttributes(String message) {
    final matches = <String>{};

    final patterns = <RegExp>[
      RegExp(
        "unknown\\s+attribute\\s*:?\\s*[\"'`]([^\"'`]+)[\"'`]",
        caseSensitive: false,
      ),
      RegExp(
        "attribute\\s*:?\\s*[\"'`]([^\"'`]+)[\"'`]\\s+not\\s+found",
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(message)) {
        final attribute = (match.group(1) ?? '').trim();
        if (attribute.isNotEmpty) {
          matches.add(attribute);
        }
      }
    }

    return matches.toList();
  }

  static String _normalizeAttributeName(String attribute) {
    return attribute.replaceAll('_', '').toLowerCase();
  }

  static List<String> _attributeAliases(String attribute) {
    final normalized = _normalizeAttributeName(attribute);

    switch (normalized) {
      case 'eventid':
        return <String>['eventId', 'eventid', 'event_id'];
      case 'ticketid':
        return <String>['ticketId', 'ticketid', 'ticket_id'];
      case 'userid':
        return <String>['userId', 'userid', 'user_id'];
      case 'scanneruserid':
        return <String>['scannerUserId', 'scanneruserid', 'scanner_user_id'];
      case 'markedat':
        return <String>['markedAt', 'markedat', 'marked_at'];
      case 'checkedinat':
        return <String>['checkedInAt', 'checkedinat', 'checked_in_at'];
      case 'attendancestatus':
        return <String>[
          'attendanceStatus',
          'attendancestatus',
          'attendance_status',
        ];
      default:
        return <String>[];
    }
  }

  static List<Map<String, dynamic>> _buildAliasPayloadsFromUnknownAttributes({
    required Map<String, dynamic> payload,
    required List<String> unknownAttributes,
  }) {
    final variants = <Map<String, dynamic>>[];

    for (final unknown in unknownAttributes) {
      if (!payload.containsKey(unknown)) {
        continue;
      }

      final value = payload[unknown];
      final aliases = _attributeAliases(unknown);
      for (final alias in aliases) {
        if (alias == unknown || payload.containsKey(alias)) {
          continue;
        }

        final candidate = Map<String, dynamic>.from(payload);
        candidate.remove(unknown);
        candidate[alias] = value;
        variants.add(candidate);
      }
    }

    return variants;
  }

  static Map<String, String> _extractAttributeTypeHints(String message) {
    final hints = <String, String>{};

    final patterns = <RegExp>[
      RegExp(
        "attribute\\s+[\"']([^\"']+)[\"'][^\\n\\r]*?(?:must\\s+be|expects?|expected)[^\\n\\r]*?(string|integer|int|number|double|float|boolean|bool|datetime|date|timestamp)",
        caseSensitive: false,
      ),
      RegExp(
        "(string|integer|int|number|double|float|boolean|bool|datetime|date|timestamp)[^\\n\\r]*?attribute\\s+[\"']([^\"']+)[\"']",
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(message)) {
        final first = (match.group(1) ?? '').trim();
        final second = (match.group(2) ?? '').trim();
        if (first.isEmpty || second.isEmpty) {
          continue;
        }

        final firstLooksType =
            first.contains('int') ||
            first.contains('string') ||
            first.contains('number') ||
            first.contains('double') ||
            first.contains('float') ||
            first.contains('bool') ||
            first.contains('date') ||
            first.contains('time') ||
            first.contains('timestamp');

        if (firstLooksType) {
          hints[second] = first.toLowerCase();
        } else {
          hints[first] = second.toLowerCase();
        }
      }
    }

    return hints;
  }

  static dynamic _coerceValueForType({
    required dynamic value,
    required String expectedType,
    required DateTime markedAt,
  }) {
    final type = expectedType.toLowerCase();

    if (type.contains('string')) {
      return value?.toString() ?? '';
    }

    if (type.contains('bool')) {
      if (value is bool) {
        return value;
      }
      final normalized = (value ?? '').toString().trim().toLowerCase();
      if (normalized == '1' || normalized == 'true' || normalized == 'yes') {
        return true;
      }
      if (normalized == '0' || normalized == 'false' || normalized == 'no') {
        return false;
      }
      return true;
    }

    if (type.contains('int') || type.contains('number')) {
      if (value is int) {
        return value;
      }
      if (value is double) {
        return value.toInt();
      }
      return int.tryParse((value ?? '').toString().trim()) ??
          markedAt.millisecondsSinceEpoch;
    }

    if (type.contains('double') || type.contains('float')) {
      if (value is double) {
        return value;
      }
      if (value is int) {
        return value.toDouble();
      }
      return double.tryParse((value ?? '').toString().trim()) ??
          markedAt.millisecondsSinceEpoch.toDouble();
    }

    if (type.contains('timestamp')) {
      return markedAt.millisecondsSinceEpoch;
    }

    if (type.contains('date') || type.contains('time')) {
      return markedAt.toIso8601String();
    }

    return value;
  }

  static Map<String, dynamic> _coercePayloadTypes({
    required Map<String, dynamic> payload,
    required Map<String, String> typeHints,
    required DateTime markedAt,
  }) {
    if (typeHints.isEmpty) {
      return Map<String, dynamic>.from(payload);
    }

    final coerced = Map<String, dynamic>.from(payload);
    for (final entry in typeHints.entries) {
      if (!coerced.containsKey(entry.key)) {
        continue;
      }
      coerced[entry.key] = _coerceValueForType(
        value: coerced[entry.key],
        expectedType: entry.value,
        markedAt: markedAt,
      );
    }

    return coerced;
  }

  static dynamic _guessRequiredAttributeValue({
    required String attributeName,
    required String eventId,
    required int ticketId,
    required String userId,
    required DateTime markedAt,
    String? scannerUserId,
  }) {
    final key = attributeName.toLowerCase();

    if (key.contains('event')) {
      return eventId;
    }

    if (key.contains('ticket')) {
      if (key.contains('code')) {
        return ticketId.toString().padLeft(5, '0');
      }

      if (key.contains('str')) {
        return ticketId.toString();
      }

      return ticketId;
    }

    if (key.contains('user') ||
        key.contains('participant') ||
        key.contains('attendee')) {
      if (key.contains('scanner') || key.contains('scannedby')) {
        return (scannerUserId ?? userId).trim();
      }
      return userId;
    }

    if (key.contains('mark') || key.contains('check') || key.contains('scan')) {
      if (key.contains('timestamp') ||
          key.endsWith('_ts') ||
          key.endsWith('ts')) {
        return markedAt.millisecondsSinceEpoch;
      }
      return markedAt.toIso8601String();
    }

    if (key.contains('time') || key.contains('date')) {
      return markedAt.toIso8601String();
    }

    if (key.contains('status')) {
      return 'present';
    }

    if (key.contains('comment') ||
        key.contains('remark') ||
        key.contains('note')) {
      return 'Scanned via QR gate';
    }

    if (key.startsWith('is') ||
        key.contains('flag') ||
        key.contains('checked')) {
      return true;
    }

    return 'checked_in';
  }

  static Map<String, dynamic> _augmentPayloadWithRequiredAttributes({
    required Map<String, dynamic> payload,
    required List<String> requiredAttributes,
    required String eventId,
    required int ticketId,
    required String userId,
    required DateTime markedAt,
    String? scannerUserId,
  }) {
    final augmented = Map<String, dynamic>.from(payload);

    for (final attribute in requiredAttributes) {
      if (augmented.containsKey(attribute)) {
        continue;
      }

      augmented[attribute] = _guessRequiredAttributeValue(
        attributeName: attribute,
        eventId: eventId,
        ticketId: ticketId,
        userId: userId,
        markedAt: markedAt,
        scannerUserId: scannerUserId,
      );
    }

    return augmented;
  }

  static Map<String, dynamic> _removeUnknownPayloadAttributes({
    required Map<String, dynamic> payload,
    required List<String> unknownAttributes,
  }) {
    if (unknownAttributes.isEmpty) {
      return Map<String, dynamic>.from(payload);
    }

    final stripped = Map<String, dynamic>.from(payload);
    for (final attribute in unknownAttributes) {
      stripped.remove(attribute);
    }
    return stripped;
  }

  static String _payloadFingerprint(Map<String, dynamic> payload) {
    final keys = payload.keys.toList()..sort();
    return keys.map((key) => '$key:${payload[key]}').join('|');
  }

  static Future<void> _createWithAdaptivePayload({
    required String collectionId,
    required String docId,
    required Map<String, dynamic> basePayload,
    required String eventId,
    required int ticketId,
    required String userId,
    required DateTime markedAt,
    String? scannerUserId,
  }) async {
    final queue = <Map<String, dynamic>>[
      Map<String, dynamic>.from(basePayload),
    ];
    final attempted = <String>{};
    AppwriteException? lastStructureError;
    var safetyCounter = 0;

    while (queue.isNotEmpty && safetyCounter < 10) {
      safetyCounter += 1;
      final payload = queue.removeAt(0);
      final fingerprint = _payloadFingerprint(payload);
      if (!attempted.add(fingerprint)) {
        continue;
      }

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

        if (!_isInvalidStructure(error)) {
          rethrow;
        }

        lastStructureError = error;
        final message = (error.message ?? '').trim();
        final requiredAttrs = _extractRequiredAttributes(message);
        final unknownAttrs = _extractUnknownAttributes(message);
        final typeHints = _extractAttributeTypeHints(message);

        if (requiredAttrs.isNotEmpty) {
          final augmented = _augmentPayloadWithRequiredAttributes(
            payload: payload,
            requiredAttributes: requiredAttrs,
            eventId: eventId,
            ticketId: ticketId,
            userId: userId,
            markedAt: markedAt,
            scannerUserId: scannerUserId,
          );
          queue.add(augmented);
        }

        if (unknownAttrs.isNotEmpty) {
          final stripped = _removeUnknownPayloadAttributes(
            payload: payload,
            unknownAttributes: unknownAttrs,
          );
          queue.add(stripped);

          final aliasedPayloads = _buildAliasPayloadsFromUnknownAttributes(
            payload: payload,
            unknownAttributes: unknownAttrs,
          );
          queue.addAll(aliasedPayloads);
        }

        if (typeHints.isNotEmpty) {
          final coerced = _coercePayloadTypes(
            payload: payload,
            typeHints: typeHints,
            markedAt: markedAt,
          );
          queue.add(coerced);
        }
      }
    }

    if (lastStructureError != null) {
      throw lastStructureError;
    }

    throw Exception('Unable to create attendance record.');
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
      if (message.isNotEmpty) {
        return 'Attendance collection attributes mismatch: $message';
      }
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

  static Map<String, dynamic> _buildAttendanceBasePayload({
    required String eventId,
    required int ticketId,
    required String userId,
    required DateTime markedAt,
    String? scannerUserId,
  }) {
    final payload = <String, dynamic>{
      'eventId': eventId,
      'ticketId': ticketId,
      'userId': userId,
      'markedAt': markedAt.toIso8601String(),
      'attendanceStatus': 'present',
      'comments': 'Scanned via QR gate',
    };

    final scannerId = scannerUserId?.trim();

    if (scannerId != null && scannerId.isNotEmpty) {
      payload['scannerUserId'] = scannerId;
    }

    return payload;
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
      final payload = _buildAttendanceBasePayload(
        eventId: eventId,
        ticketId: ticketId,
        userId: userId,
        markedAt: markedAt,
        scannerUserId: scannerUserId,
      );

      await _createWithAdaptivePayload(
        collectionId: collectionId,
        docId: docId,
        basePayload: payload,
        eventId: eventId,
        ticketId: ticketId,
        userId: userId,
        markedAt: markedAt,
        scannerUserId: scannerUserId,
      );
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
