import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../appwrite/appwrite_config.dart';
import '../../appwrite/appwrite_service.dart';
import '../../models/event.dart';

/// Large top thumbnail for event cards (matches All Events list style).
class EventThumbnailHeader extends StatelessWidget {
  final Event event;
  final double height;

  const EventThumbnailHeader({
    super.key,
    required this.event,
    this.height = 165,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: _buildContent(context, cs),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme cs) {
    final fileId = event.thumbnailFileId;
    if (fileId == null || fileId.isEmpty) {
      return _placeholder(cs);
    }

    return FutureBuilder<Uint8List>(
      future: AppwriteService.getFileViewBytes(
        bucketId: AppwriteConfig.eventImagesBucketId,
        fileId: fileId,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          return _placeholder(cs);
        }
        if (snap.connectionState == ConnectionState.waiting ||
            snap.connectionState == ConnectionState.active) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: cs.primary.withValues(alpha: 0.08),
            alignment: Alignment.center,
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
            ),
          );
        }
        final bytes = snap.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        }
        return _placeholder(cs);
      },
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.20),
            const Color(0xFFFFFFFF),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: Colors.black.withValues(alpha: 0.35), size: 44),
    );
  }
}
