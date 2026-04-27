class Attendance {
  final String eventId;
  final int ticketId;
  final String userId;
  final DateTime markedAt;
  final String? scannerUserId;

  const Attendance({
    required this.eventId,
    required this.ticketId,
    required this.userId,
    required this.markedAt,
    this.scannerUserId,
  });

  factory Attendance.fromMap(Map<String, dynamic> data) {
    final markedAtRaw = _stringFromKeys(data, const <String>[
      'markedAt',
      'markedat',
      'marked_at',
      'checkedInAt',
      'checkedinat',
      'checked_in_at',
      'scannedAt',
      'scannedat',
      'scanned_at',
    ]);

    final markedAtEpoch = _intFromKeys(data, const <String>[
      'markedAt',
      'markedat',
      'marked_at',
      'checkedInAt',
      'checkedinat',
      'checked_in_at',
      'scannedAt',
      'scannedat',
      'scanned_at',
    ]);

    return Attendance(
      eventId: _stringFromKeys(data, const <String>[
        'eventId',
        'eventid',
        'event_id',
        'event',
      ]),
      ticketId: _ticketIdFromMap(data),
      userId: _stringFromKeys(data, const <String>[
        'userId',
        'userid',
        'user_id',
        'participantId',
        'participantid',
        'participant_id',
        'attendeeId',
        'attendeeid',
        'attendee_id',
        'user',
      ]),
      markedAt: _resolveMarkedAt(
        markedAtRaw: markedAtRaw,
        markedAtEpoch: markedAtEpoch,
      ),
      scannerUserId: _nullableStringFromKeys(data, const <String>[
        'scannerUserId',
        'scanneruserid',
        'scanner_user_id',
        'scannedByUserId',
        'scannedbyuserid',
        'scanned_by_user_id',
        'scannerId',
        'scannerid',
        'scanner_id',
      ]),
    );
  }

  static int _ticketIdFromMap(Map<String, dynamic> data) {
    final value = _valueFromKeys(data, const <String>[
      'ticketId',
      'ticketid',
      'ticket_id',
      'ticket',
      'ticketNumber',
      'ticketnumber',
      'ticket_number',
    ]);
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static DateTime _resolveMarkedAt({
    required String markedAtRaw,
    required int? markedAtEpoch,
  }) {
    if (markedAtRaw.isNotEmpty) {
      final parsedIso = DateTime.tryParse(markedAtRaw);
      if (parsedIso != null) {
        return parsedIso;
      }
    }

    if (markedAtEpoch != null && markedAtEpoch > 0) {
      final asMs = markedAtEpoch > 9999999999
          ? markedAtEpoch
          : markedAtEpoch * 1000;
      return DateTime.fromMillisecondsSinceEpoch(asMs);
    }

    return DateTime.now();
  }

  static String _stringFromKeys(Map<String, dynamic> data, List<String> keys) {
    final value = _valueFromKeys(data, keys);
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  static String? _nullableStringFromKeys(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    final value = _valueFromKeys(data, keys);
    if (value == null) {
      return null;
    }
    final asString = value.toString().trim();
    return asString.isEmpty ? null : asString;
  }

  static int? _intFromKeys(Map<String, dynamic> data, List<String> keys) {
    final value = _valueFromKeys(data, keys);
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static dynamic _valueFromKeys(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (data.containsKey(key)) {
        return data[key];
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'ticketId': ticketId,
      'userId': userId,
      'markedAt': markedAt.toIso8601String(),
      if (scannerUserId != null) 'scannerUserId': scannerUserId,
    };
  }
}
