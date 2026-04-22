import 'package:appwrite/appwrite.dart';

import '../appwrite/appwrite_config.dart';
import '../appwrite/appwrite_service.dart';
import '../models/attendance.dart';

class AttendanceService {
  static const String _collectionId = 'attendance';

  /// Check if attendance is configured in Appwrite
  static bool get _isConfigured =>
      AppwriteService.isConfigured &&
      AppwriteConfig.databaseId.isNotEmpty &&
      _collectionId.isNotEmpty;

  /// Generate a unique document ID for attendance record
  static String _docId(String eventId, int ticketId) {
    return '${eventId}_${ticketId.toString().padLeft(5, '0')}';
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
      await AppwriteService.getDocument(
        collectionId: _collectionId,
        documentId: docId,
      );

      // If we reach here, document already exists (duplicate)
      throw Exception('Attendance already marked for this ticket');
    } on AppwriteException catch (e) {
      if (e.code != 404) {
        rethrow;
      }
      // 404 = document doesn't exist, which is good - we can create it
    }

    // Create new attendance record
    try {
      await AppwriteService.createDocument(
        collectionId: _collectionId,
        documentId: docId,
        data: {
          'eventId': eventId,
          'ticketId': ticketId,
          'userId': userId,
          'markedAt': now.toIso8601String(),
          if (scannerUserId != null) 'scannerUserId': scannerUserId,
        },
      );

      return Attendance(
        eventId: eventId,
        ticketId: ticketId,
        userId: userId,
        markedAt: now,
        scannerUserId: scannerUserId,
      );
    } catch (e) {
      throw Exception('Failed to mark attendance: $e');
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
      await AppwriteService.getDocument(
        collectionId: _collectionId,
        documentId: docId,
      );
      return true;
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
      final result = await AppwriteService.listDocuments(
        collectionId: _collectionId,
        queries: ['equal("eventId", "$eventId")'],
      );

      return result.documents
          .map((doc) => Attendance.fromMap(Map<String, dynamic>.from(doc.data)))
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
      final doc = await AppwriteService.getDocument(
        collectionId: _collectionId,
        documentId: docId,
      );

      return Attendance.fromMap(Map<String, dynamic>.from(doc.data));
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
