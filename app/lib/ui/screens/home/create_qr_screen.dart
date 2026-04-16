import 'package:flutter/material.dart';

import '../../../models/event.dart';
import 'scan_qr_screen.dart';

class CreateQrScreen extends StatelessWidget {
  static const routeName = '/create-qr';

  final Event? event;

  const CreateQrScreen({
    super.key,
    this.event,
  });

  @override
  Widget build(BuildContext context) {
    // If event is not provided, show an error or entry screen
    if (event == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('QR Code Scanner'),
        ),
        body: const Center(
          child: Text('No event selected. Please select an event first.'),
        ),
      );
    }

    // Navigate directly to scan QR screen with event
    return ScanQrScreen(event: event);
  }
}
