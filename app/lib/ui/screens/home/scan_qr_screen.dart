import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../auth/current_user.dart';
import '../../../data/event_registration_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/event.dart';
import '../../../services/attendance_service.dart';
import '../../../services/ticket_service.dart';

class ScanQrScreen extends StatefulWidget {
  static const routeName = '/scan-qr';

  final Event? event;

  const ScanQrScreen({super.key, this.event});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  late MobileScannerController controller;
  bool _isProcessing = false;
  bool _isCheckingAccess = true;
  bool _canScan = false;
  String? _accessMessage;
  String? _lastScannedCode;
  DateTime? _lastScanTime;

  final _registrationRepo = EventRegistrationRepository();
  final _profileRepo = ProfileRepository();

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
      detectionTimeoutMs: 1000,
      returnImage: false,
    );
    _loadScanAccess();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Ticket QR Code'),
        elevation: 0,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.on
                      ? Icons.flashlight_on
                      : Icons.flashlight_off,
                  color: state == TorchState.on ? Colors.yellow : Colors.grey,
                );
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: _isCheckingAccess
          ? const Center(child: CircularProgressIndicator())
          : !_canScan
          ? _buildErrorWidget(
              _accessMessage ??
                  'You can only scan after the host checks you in.',
            )
          : MobileScanner(
              controller: controller,
              onDetect: _handleQrDetection,
              errorBuilder: (context, error, child) {
                return _buildErrorWidget(error.toString());
              },
              placeholderBuilder: (context, child) {
                return const Center(child: CircularProgressIndicator());
              },
              overlay: _buildScannerOverlay(),
            ),
    );
  }

  Future<void> _loadScanAccess() async {
    final event = widget.event;
    if (event == null) {
      setState(() {
        _isCheckingAccess = false;
        _canScan = false;
        _accessMessage = 'Event information not available.';
      });
      return;
    }
    final isCreator = (event.creatorId ?? '').trim() == currentUserId;
    if (isCreator) {
      setState(() {
        _isCheckingAccess = false;
        _canScan = true;
      });
      return;
    }
    try {
      final attendance = await AttendanceService.getAttendanceList(event.id);
      final attendedIds = attendance.map((item) => item.userId).toSet();
      setState(() {
        _isCheckingAccess = false;
        _canScan = attendedIds.contains(currentUserId);
        _accessMessage = attendedIds.contains(currentUserId)
            ? null
            : 'You can help scan only after your own attendance is confirmed.';
      });
    } catch (_) {
      setState(() {
        _isCheckingAccess = false;
        _canScan = false;
        _accessMessage = 'Could not verify scan access right now.';
      });
    }
  }

  void _handleQrDetection(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final scannedData = barcode.rawValue ?? '';
    if (scannedData.isEmpty) return;

    // Prevent duplicate scans within 2 seconds
    final now = DateTime.now();
    if (_lastScannedCode == scannedData &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inSeconds < 2) {
      return;
    }

    _lastScannedCode = scannedData;
    _lastScanTime = now;

    setState(() => _isProcessing = true);
    _processTicket(scannedData);
  }

  Future<void> _processTicket(String ticketIdStr) async {
    try {
      if (widget.event == null) {
        _showErrorDialog('Event information not available');
        return;
      }

      final event = widget.event!;
      final validation = TicketService.validateScannedQrData(
        rawData: ticketIdStr,
        event: event,
      );
      if (!validation.isValid) {
        _showErrorDialog(validation.errorMessage ?? 'Invalid QR code');
        return;
      }

      // Find user who owns this ticket (by registration order)
      final participantIds = await _registrationRepo.listParticipantUserIds(
        event.id,
      );
      if (participantIds.isEmpty) {
        _showErrorDialog('No participants are registered for this event yet');
        return;
      }

      var ticketId = validation.ticketId;
      var userId = validation.userId?.trim();

      if (ticketId == null) {
        if (userId == null || userId.isEmpty) {
          _showErrorDialog('Invalid QR code format');
          return;
        }

        final resolvedTicketId = participantIds.indexOf(userId);
        if (resolvedTicketId < 0) {
          _showErrorDialog('This QR code is not registered for this event');
          return;
        }

        ticketId = resolvedTicketId;
      }

      if (ticketId < 0 || ticketId >= participantIds.length) {
        _showErrorDialog('Ticket ID does not match any registered participant');
        return;
      }

      final expectedUserId = participantIds[ticketId];
      if (userId == null || userId.isEmpty) {
        userId = expectedUserId;
      } else if (userId != expectedUserId) {
        _showErrorDialog(
          'This QR code does not match the registered participant',
        );
        return;
      }

      // Check if attendance already marked
      final alreadyMarked = await AttendanceService.isAttendanceMarked(
        eventId: event.id,
        ticketId: ticketId,
      );

      if (alreadyMarked) {
        _showErrorDialog(
          'This participant is already checked in for this event.',
        );
        return;
      }

      // Fetch user profile for confirmation display
      final profiles = await _profileRepo.getProfilesByIds([userId]);
      final userProfile = profiles.isNotEmpty ? profiles.first : null;

      final userName = userProfile?.realName ?? 'Unknown';
      await _markAttendance(
        event: event,
        ticketId: ticketId,
        userId: userId,
        userName: userName,
      );
    } catch (e) {
      _showErrorDialog('Error processing ticket: ${_cleanErrorMessage(e)}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _markAttendance({
    required Event event,
    required int ticketId,
    required String userId,
    required String userName,
  }) async {
    try {
      await AttendanceService.markAttendance(
        eventId: event.id,
        ticketId: ticketId,
        userId: userId,
        scannerUserId: currentUserId,
      );

      if (!mounted) return;

      await _emitSuccessFeedback();
      if (!mounted) {
        return;
      }

      final ticketCode = ticketId.toString().padLeft(5, '0');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Scan successful: $userName (Ticket $ticketCode)'),
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      _showErrorDialog('Error marking attendance: ${_cleanErrorMessage(e)}');
    }
  }

  String _cleanErrorMessage(Object error) {
    final raw = error.toString().trim();
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  Future<void> _emitSuccessFeedback() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}

    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    setState(() => _isProcessing = false);
  }

  Widget _buildScannerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = math.max(24.0, constraints.maxWidth * 0.12);
        final maxScanWidth = constraints.maxWidth - (horizontalPadding * 2);
        final maxScanHeight = constraints.maxHeight * 0.42;
        final scanSize = math.min(300.0, math.min(maxScanWidth, maxScanHeight));
        final scanRect = Rect.fromCenter(
          center: Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight * 0.45,
          ),
          width: scanSize,
          height: scanSize,
        );
        const scanBorderRadius = 14.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _ScannerMaskPainter(
                scanRect: scanRect,
                borderRadius: scanBorderRadius,
                overlayColor: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            Positioned.fromRect(
              rect: scanRect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 3),
                  borderRadius: BorderRadius.circular(scanBorderRadius),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessing)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.green.shade400,
                              ),
                            ),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          _isProcessing
                              ? 'Processing...'
                              : 'Align QR code within frame',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorWidget(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Camera Error', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

class _ScannerMaskPainter extends CustomPainter {
  const _ScannerMaskPainter({
    required this.scanRect,
    required this.borderRadius,
    required this.overlayColor,
  });

  final Rect scanRect;
  final double borderRadius;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(scanRect, Radius.circular(borderRadius)),
      );

    canvas.drawPath(maskPath, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant _ScannerMaskPainter oldDelegate) {
    return oldDelegate.scanRect != scanRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}
