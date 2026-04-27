import 'dart:async';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../data/direct_message_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/direct_message.dart';
import '../../../models/user_profile.dart';

class DirectMessageArgs {
  final String otherUserId;
  final String? initialName;

  const DirectMessageArgs({required this.otherUserId, this.initialName});
}

class DirectMessageScreen extends StatefulWidget {
  static const routeName = '/direct-message';

  const DirectMessageScreen({super.key});

  @override
  State<DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends State<DirectMessageScreen> {
  final _repo = directMessageRepository();
  final _textCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _messages = <DirectMessage>[];
  RealtimeSubscription? _subscription;
  Timer? _fallbackPollTimer;
  bool _isLoading = true;
  bool _isSending = false;
  String _otherUserId = '';
  String _otherName = 'User';

  String _dmReadKey(String otherUserId) {
    final me = currentUserId.trim().toLowerCase();
    final other = otherUserId.trim().toLowerCase();
    return 'direct_dm_last_read_${me}_$other';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFromRoute();
      _loadConversation();
      _startRealtime();
    });
  }

  @override
  void dispose() {
    _markConversationRead();
    _subscription?.close();
    _fallbackPollTimer?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  void _initFromRoute() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is DirectMessageArgs) {
      _otherUserId = args.otherUserId.trim();
      final fromArgs = (args.initialName ?? '').trim();
      if (fromArgs.isNotEmpty) {
        _otherName = fromArgs;
      }
    }
    if (_otherUserId.isNotEmpty) {
      _loadOtherProfile();
      _markConversationRead();
    }
  }

  Future<void> _markConversationRead({DateTime? latestMessageAt}) async {
    final me = currentUserId.trim();
    final other = _otherUserId.trim();
    if (me.isEmpty || other.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final readAt = latestMessageAt ?? DateTime.now();
    await prefs.setString(_dmReadKey(other), readAt.toIso8601String());
  }

  Future<void> _loadOtherProfile() async {
    try {
      final profile = await profileRepository().getProfileById(_otherUserId);
      final display = _profileDisplayName(profile).trim();
      if (!mounted || display.isEmpty) {
        return;
      }
      setState(() => _otherName = display);
    } catch (_) {}
  }

  void _startRealtime() {
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.directMessagesCollectionId.isEmpty) {
      _fallbackPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        _loadConversation(silent: true);
      });
      return;
    }
    _subscription?.close();
    _subscription = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.directMessagesCollectionId}.documents',
    ]);
    _subscription?.stream.listen((_) => _loadConversation(silent: true));
  }

  Future<void> _loadConversation({bool silent = false}) async {
    final me = currentUserId.trim();
    if (me.isEmpty || _otherUserId.isEmpty) {
      return;
    }
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final items = await _repo.listConversation(
        userA: me,
        userB: _otherUserId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages
          ..clear()
          ..addAll(items);
        _isLoading = false;
      });
      final latestAt = items.isEmpty
          ? DateTime.now()
          : items
                .map((message) => message.createdAt)
                .reduce((a, b) => a.isAfter(b) ? a : b);
      await _markConversationRead(latestMessageAt: latestAt);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _send() async {
    final me = currentUserId.trim();
    final text = _textCtrl.text.trim();
    if (_isSending || me.isEmpty || _otherUserId.isEmpty || text.isEmpty) {
      return;
    }
    setState(() => _isSending = true);
    try {
      await _repo.sendMessage(
        senderId: me,
        receiverId: _otherUserId,
        text: text,
      );
      _textCtrl.clear();
      await _loadConversation(silent: true);
    } on AppwriteException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to send message.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send message.')));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendImage() async {
    final me = currentUserId.trim();
    if (_isSending || me.isEmpty || _otherUserId.isEmpty) {
      return;
    }
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
      );
      if (picked == null) {
        return;
      }
      setState(() => _isSending = true);
      final bytes = await picked.readAsBytes();
      final uploaded = await AppwriteService.uploadFile(
        bucketId: AppwriteConfig.storageBucketId,
        path: picked.path,
        bytes: bytes,
        filename: picked.name,
      );
      await _repo.sendMessage(
        senderId: me,
        receiverId: _otherUserId,
        text: _textCtrl.text.trim(),
        imageFileId: uploaded.$id,
      );
      _textCtrl.clear();
      await _loadConversation(silent: true);
    } on AppwriteException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to send image.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send image.')));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _editMessage(DirectMessage message) async {
    final me = currentUserId.trim();
    if (message.senderId.trim() != me) {
      return;
    }
    final controller = TextEditingController(text: message.text.trim());
    final nextText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          minLines: 1,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (nextText == null || nextText.trim().isEmpty) {
      return;
    }
    if (nextText.trim() == message.text.trim()) {
      return;
    }
    try {
      await _repo.editMessage(
        messageId: message.id,
        editorUserId: me,
        newText: nextText,
      );
      await _loadConversation(silent: true);
    } on AppwriteException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to edit message.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to edit message.')));
    }
  }

  Future<void> _showMessageActions(DirectMessage message) async {
    final me = currentUserId.trim();
    final isMine = message.senderId.trim() == me;
    if (!isMine) {
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit message'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      await _editMessage(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = currentUserId.trim();
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14B8A6),
        title: Text(
          _otherName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet. Say hi!',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final mine = msg.senderId.trim() == me;
                      return GestureDetector(
                        onLongPress: () => _showMessageActions(msg),
                        child: Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? const Color(0xFF0F5549)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: mine
                                    ? const Color(0xFF0F5549)
                                    : const Color(0xFFD7E8E2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.text,
                                  style: TextStyle(
                                    color: mine
                                        ? Colors.white
                                        : const Color(0xFF0F5549),
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                                if ((msg.imageFileId ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                                  if (msg.text.trim().isNotEmpty)
                                    const SizedBox(height: 8),
                                  _DmImage(fileId: msg.imageFileId!),
                                ],
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (msg.editedAt != null) ...[
                                      Text(
                                        'edited',
                                        style: TextStyle(
                                          color: mine
                                              ? Colors.white.withValues(
                                                  alpha: 0.7,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.45,
                                                ),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      _formatTime(msg.createdAt),
                                      style: TextStyle(
                                        color: mine
                                            ? Colors.white.withValues(
                                                alpha: 0.7,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.45,
                                              ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD7E8E2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textCtrl,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _isSending ? null : _sendImage,
                      icon: const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF0F5549),
                        size: 20,
                      ),
                    ),
                    Material(
                      color: const Color(0xFF14B8A6),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _isSending ? null : _send,
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: Center(
                            child: _isSending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 18,
                                  ),
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
    );
  }
}

String _profileDisplayName(UserProfile profile) {
  final realName = profile.realName.trim();
  final username = profile.username.trim();
  if (realName.isNotEmpty && realName != 'Name') {
    return realName;
  }
  if (username.isNotEmpty && username != 'Username') {
    return username;
  }
  if (realName.isNotEmpty) {
    return realName;
  }
  if (username.isNotEmpty) {
    return username;
  }
  return 'User';
}

String _formatTime(DateTime dt) {
  final t = dt.toLocal();
  final hour12 = ((t.hour + 11) % 12) + 1;
  final minute = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $ampm';
}

class _DmImage extends StatelessWidget {
  final String fileId;

  const _DmImage({required this.fileId});

  @override
  Widget build(BuildContext context) {
    Future<void> openPreview(Uint8List bytes) async {
      Future<void> download() async {
        try {
          final uri = AppwriteService.getFileDownloadUri(
            bucketId: AppwriteConfig.storageBucketId,
            fileId: fileId,
          );
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 52,
                child: IconButton(
                  onPressed: download,
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FutureBuilder<Uint8List>(
        future: AppwriteService.getFileViewBytes(
          bucketId: AppwriteConfig.storageBucketId,
          fileId: fileId,
        ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 180,
              height: 140,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final bytes = snap.data;
          if (bytes == null || bytes.isEmpty) {
            return const SizedBox(
              width: 180,
              height: 80,
              child: Center(child: Text('Image unavailable')),
            );
          }
          return InkWell(
            onTap: () => openPreview(bytes),
            child: Image.memory(
              bytes,
              width: 180,
              height: 140,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
}
