import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../auth/current_user.dart';
import '../../../data/event_registration_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/event.dart';
import '../../../services/attendance_service.dart';
import '../../../services/ticket_service.dart';
import '../profile/user_profile_view_screen.dart';

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

  bool get _isHostScanner {
    final event = widget.event;
    if (event == null) {
      return false;
    }
    return (event.creatorId ?? '').trim() == currentUserId;
  }

  String get _scannerRoleLabel =>
      _isHostScanner ? 'Host scanner' : 'Helper scanner';

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
      if (!validation.isValid || validation.ticketId == null) {
        _showErrorDialog(validation.errorMessage ?? 'Invalid QR code');
        return;
      }
      final ticketId = validation.ticketId!;

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

      // Find user who owns this ticket (by registration order)
      final participantIds = await _registrationRepo.listParticipantUserIds(
        event.id,
      );
      if (ticketId < 0 || ticketId >= participantIds.length) {
        _showErrorDialog('Ticket ID does not match any registered participant');
        return;
      }

      final expectedUserId = participantIds[ticketId];
      final userId = validation.userId ?? expectedUserId;
      if (!validation.isLegacy && userId != expectedUserId) {
        _showErrorDialog(
          'This QR code does not match the registered participant',
        );
        return;
      }

      // Fetch user profile for confirmation display
      final profiles = await _profileRepo.getProfilesByIds([userId]);
      final userProfile = profiles.isNotEmpty ? profiles.first : null;

      if (!mounted) return;

      // Show confirmation dialog
      _showConfirmationDialog(
        event: event,
        ticketId: ticketId,
        userId: userId,
        userName: userProfile?.realName ?? 'Unknown',
      );
    } catch (e) {
      _showErrorDialog('Error processing ticket: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showConfirmationDialog({
    required Event event,
    required int ticketId,
    required String userId,
    required String userName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Attendance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAttendanceInfo('Event', event.title),
              const SizedBox(height: 12),
              _buildAttendanceInfo('Attendee', userName),
              const SizedBox(height: 12),
              _buildAttendanceInfo(
                'Ticket ID',
                ticketId.toString().padLeft(5, '0'),
              ),
              const SizedBox(height: 12),
              _buildAttendanceInfo('Scanner', _scannerRoleLabel),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isHostScanner
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
                  border: Border.all(
                    color: _isHostScanner
                        ? Colors.green.shade300
                        : Colors.blue.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isHostScanner
                          ? Icons.verified_rounded
                          : Icons.groups_rounded,
                      color: _isHostScanner ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isHostScanner
                            ? 'Confirm this check-in as the event host?'
                            : 'Confirm this check-in as a verified helper?',
                        style: TextStyle(
                          color: _isHostScanner
                              ? Colors.green.shade800
                              : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Attendance scan cancelled.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _markAttendance(
                  event: event,
                  ticketId: ticketId,
                  userId: userId,
                  userName: userName,
                );
              },
              child: const Text('Yes, Confirm'),
            ),
          ],
        );
      },
    );
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

      // Reset for next scan
      setState(() => _isProcessing = false);

      _showAttendanceSuccessDialog(
        ticketId: ticketId,
        userId: userId,
        userName: userName,
      );
    } catch (e) {
      _showErrorDialog('Error marking attendance: $e');
    }
  }

  void _showAttendanceSuccessDialog({
    required int ticketId,
    required String userId,
    required String userName,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Attendance Confirmed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attendee: $userName'),
              const SizedBox(height: 8),
              Text('Ticket ID: ${ticketId.toString().padLeft(5, '0')}'),
              const SizedBox(height: 8),
              Text('Scanner: $_scannerRoleLabel'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isHostScanner
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isHostScanner
                        ? Colors.green.shade300
                        : Colors.blue.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isHostScanner
                          ? Icons.verified_rounded
                          : Icons.groups_rounded,
                      color: _isHostScanner ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isHostScanner
                            ? 'Attendance successfully marked by the host.'
                            : 'Attendance successfully marked by a verified helper.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ok'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (!mounted) {
                  return;
                }
                Navigator.of(context).pushNamed(
                  UserProfileViewScreen.routeName,
                  arguments: UserProfileViewArgs(userId: userId),
                );
              },
              child: const Text('Profile'),
            ),
          ],
        );
      },
    );
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

  Widget _buildAttendanceInfo(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget? _buildScannerOverlay() {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            _isProcessing
                                ? 'Processing...'
                                : 'Align QR code within frame',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_isProcessing)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.green.shade400,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        ],
      ),
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
