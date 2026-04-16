import 'dart:async';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

import '../data/event_registration_repository.dart';
import '../models/event.dart';
import '../models/user_profile.dart';

class TicketService {
  static final EventRegistrationRepository _registrationRepo =
      EventRegistrationRepository();

  /// Generate a sequential ticket ID (0-99999) based on registration order.
  /// Lower index = earlier registrant.
  ///
  /// Returns -1 if user is not found in registrations (error case).
  static Future<int> generateTicketId({
    required String eventId,
    required String userId,
  }) async {
    try {
      final participantIds = await _registrationRepo.listParticipantUserIds(
        eventId,
      );

      // Find the index of the current user in the registration order
      final userIndex = participantIds.indexOf(userId);

      if (userIndex == -1) {
        throw Exception('User not registered for this event');
      }

      // Ticket ID = index (0-based)
      return userIndex;
    } catch (e) {
      throw Exception('Failed to generate ticket ID: $e');
    }
  }

  /// Generate a PDF ticket with QR code.
  ///
  /// Returns the PDF as Uint8List.
  static Future<Uint8List> generateTicketPdf({
    required Event event,
    required UserProfile user,
    required int ticketId,
  }) async {
    final pdf = pw.Document();

    final qrImageData = await generateQrCodeImage(ticketId.toString());

    final attendeeName = user.realName.trim().isEmpty
        ? 'N/A'
        : user.realName.trim();
    final eventDate = _formatTemplateDate(event.startAt);
    final eventTime = _formatTemplateTime(event.startAt);
    final location = event.location.trim().isEmpty
        ? 'TBA'
        : event.location.trim();
    final ticketCode = ticketId.toString().padLeft(5, '0');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Container(
            color: PdfColors.black,
            alignment: pw.Alignment.center,
            child: pw.ConstrainedBox(
              constraints: const pw.BoxConstraints(maxWidth: 440),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(28),
                        topRight: pw.Radius.circular(28),
                        bottomLeft: pw.Radius.circular(28),
                        bottomRight: pw.Radius.circular(28),
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Container(
                          height: 52,
                          color: const PdfColor(0, 0.45, 0.14),
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            'CIRCLE.BN',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 20,
                              letterSpacing: 1.2,
                              fontWeight: pw.FontWeight.normal,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.fromLTRB(16, 34, 16, 34),
                          child: pw.Text(
                            event.title.toUpperCase(),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              color: PdfColors.black,
                              fontSize: 40,
                              letterSpacing: 0.8,
                              fontWeight: pw.FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: _buildDashedTearLine(),
                  ),

                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(28),
                        topRight: pw.Radius.circular(28),
                        bottomLeft: pw.Radius.circular(28),
                        bottomRight: pw.Radius.circular(28),
                      ),
                    ),
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                child: _buildTicketField(
                                  'NAME',
                                  attendeeName,
                                  leftAligned: true,
                                ),
                              ),
                              pw.SizedBox(width: 18),
                              pw.Expanded(
                                child: _buildTicketField(
                                  'DATE',
                                  eventDate,
                                  leftAligned: true,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 26),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                child: _buildTicketField(
                                  'TICKET ID',
                                  ticketCode,
                                  leftAligned: true,
                                ),
                              ),
                              pw.SizedBox(width: 18),
                              pw.Expanded(
                                child: _buildTicketField(
                                  'TIME',
                                  eventTime,
                                  leftAligned: true,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 26),
                          pw.Center(
                            child: pw.Image(
                              qrImageData,
                              width: 220,
                              height: 220,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Container(height: 2, color: PdfColors.black),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Present this QR code at the entrance',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.SizedBox(height: 20),
                          pw.Text(
                            'LOCATION',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 13,
                              color: PdfColors.grey700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            location.toUpperCase(),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 19,
                              color: PdfColors.black,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTicketField(
    String label,
    String value, {
    required bool leftAligned,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.normal,
            color: PdfColors.grey700,
            letterSpacing: 0.3,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          textAlign: leftAligned ? pw.TextAlign.left : pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  static pw.Widget _buildDashedTearLine() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: List<pw.Widget>.generate(
        44,
        (index) => pw.Container(
          width: 7,
          height: 2,
          margin: const pw.EdgeInsets.symmetric(horizontal: 2),
          color: PdfColors.grey700,
        ),
      ),
    );
  }

  static String _formatTemplateDate(DateTime dt) {
    const months = <String>[
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];

    return '${_ordinalDay(dt.day)} ${months[dt.month - 1]} ${dt.year}';
  }

  static String _formatTemplateTime(DateTime dt) {
    final hour12 = ((dt.hour + 11) % 12) + 1;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }

  static String _ordinalDay(int day) {
    if (day >= 11 && day <= 13) {
      return '${day}th';
    }

    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  /// Generate a QR code image as PdfImage.
  ///
  /// Uses qr_flutter to generate the QR code and converts it to bytes.
  static Future<pw.ImageProvider> generateQrCodeImage(String data) async {
    final qrImage = await QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: false,
    ).toImageData(200.0);

    final qrBytes = qrImage!.buffer.asUint8List();

    return pw.MemoryImage(qrBytes);
  }
}
