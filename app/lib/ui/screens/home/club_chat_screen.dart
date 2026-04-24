import 'dart:async';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../data/club_chat_repository.dart';
import '../../../data/club_member_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/club.dart';
import '../../../models/club_chat_message.dart';
import '../../../models/event.dart';
import 'club_info_screen.dart';
import 'event_detail_screen.dart';

/// Club group chat. Tapping the app bar (icon + name) opens [ClubInfoScreen].
class ClubChatScreen extends StatefulWidget {
  static const routeName = '/club-chat';

  const ClubChatScreen({super.key});

  @override
  State<ClubChatScreen> createState() => _ClubChatScreenState();
}

enum _ChatListTab { all, pinned }

class _ClubChatScreenState extends State<ClubChatScreen> {
  final _composerCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<ClubChatMessage> _messages = <ClubChatMessage>[];
  final _chatRepo = clubChatRepository();
  static const _teal = Color(0xFF14B8A6);
  static const _mint = Color(0xFFF0FDFA);
  bool _isLoading = true;
  bool _isSending = false;
  String? _loadError;
  Timer? _pollTimer;
  RealtimeSubscription? _realtimeSubscription;
  String? _displayName;
  int? _membersCount;
  _ChatListTab _activeTab = _ChatListTab.all;
  bool _canPinAnyMessage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _loadMembersCount();
      _resolvePinPrivileges();
      _startRealtimeSubscription();
      _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _loadMessages(silent: true);
      });
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _realtimeSubscription?.close();
    _composerCtrl.dispose();
    super.dispose();
  }

  void _startRealtimeSubscription() {
    final clubId = _clubFromRoute(context).id.trim();
    if (clubId.isEmpty ||
        !AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.clubMessagesCollectionId.isEmpty) {
      return;
    }
    _realtimeSubscription?.close();
    _realtimeSubscription = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.clubMessagesCollectionId}.documents',
    ]);
    _realtimeSubscription?.stream.listen((event) {
      final payload = event.payload;
      final eventClubId = payload['clubId']?.toString() ?? '';
      if (eventClubId == clubId) {
        _loadMessages(silent: true);
      }
    });
  }

  Club _clubFromRoute(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Club) {
      return args;
    }
    return const Club(
      id: 'unknown',
      name: 'Club',
      description: '',
      sports: {'Other'},
    );
  }

  int _mockMembers(Club c) => 20 + (c.id.hashCode.abs() % 80);

  Future<void> _loadMembersCount() async {
    final club = _clubFromRoute(context);
    if (club.id.trim().isEmpty) {
      return;
    }
    if (club.membersCount != null && mounted) {
      setState(() {
        _membersCount = club.membersCount;
      });
    }
    try {
      final members = await clubMemberRepository().listMembers(clubId: club.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _membersCount = members.length;
      });
    } catch (_) {}
  }

  Future<void> _resolvePinPrivileges() async {
    final club = _clubFromRoute(context);
    final isCreator = (club.creatorId ?? '').trim() == currentUserId.trim();
    if (isCreator) {
      if (mounted) {
        setState(() {
          _canPinAnyMessage = true;
        });
      }
      return;
    }
    try {
      final isAdmin = await clubMemberRepository().isAdmin(
        clubId: club.id,
        userId: currentUserId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _canPinAnyMessage = isAdmin;
      });
    } catch (_) {}
  }

  Future<String> _resolveDisplayName() async {
    if (_displayName != null && _displayName!.trim().isNotEmpty) {
      return _displayName!;
    }
    try {
      final profile = await profileRepository().getMyProfile();
      final realName = profile.realName.trim();
      if (realName.isNotEmpty && realName.toLowerCase() != 'name') {
        _displayName = realName;
        return realName;
      }
      final username = profile.username.trim();
      if (username.isNotEmpty && username.toLowerCase() != 'username') {
        _displayName = username;
        return username;
      }
    } catch (_) {}
    _displayName = 'Member';
    return _displayName!;
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final clubId = _clubFromRoute(context).id.trim();
    if (clubId.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = 'Invalid club.';
      });
      return;
    }
    if (!silent) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final items = await _chatRepo.listForClub(clubId);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages
          ..clear()
          ..addAll(items);
        _isLoading = false;
        _loadError = null;
      });
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
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load chat.';
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_activeTab == _ChatListTab.pinned) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Switch to All tab to send messages.')),
        );
      }
      return;
    }
    final text = _composerCtrl.text.trim();
    if (text.isEmpty) {
      return;
    }
    if (_isSending) {
      return;
    }
    final clubId = _clubFromRoute(context).id.trim();
    if (clubId.isEmpty) {
      return;
    }
    final senderId = currentUserId.trim();
    final senderName = await _resolveDisplayName();
    setState(() {
      _isSending = true;
    });
    try {
      await _chatRepo.sendMessage(
        clubId: clubId,
        senderId: senderId,
        senderName: senderName,
        text: text,
      );
      _composerCtrl.clear();
      await _loadMessages(silent: true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message.')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _editMessage(ClubChatMessage message) async {
    final existing = message.text.trim();
    final controller = TextEditingController(text: existing);
    final newText = await showDialog<String>(
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
    if (newText == null || newText.trim().isEmpty || newText.trim() == existing) {
      return;
    }
    try {
      await _chatRepo.editMessage(messageId: message.id, newText: newText);
      await _loadMessages(silent: true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to edit message.')),
      );
    }
  }

  Future<void> _togglePin(ClubChatMessage message) async {
    final isMine = message.senderId.trim() == currentUserId.trim();
    if (!_canPinAnyMessage && !isMine) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only club creator/admin can pin others messages.'),
          ),
        );
      }
      return;
    }
    try {
      await _chatRepo.setPinned(
        messageId: message.id,
        isPinned: !message.isPinned,
      );
      await _loadMessages(silent: true);
    } on AppwriteException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to update pin.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update pin.')),
      );
    }
  }

  Future<void> _showMessageActions(ClubChatMessage message) async {
    final isMine = message.senderId.trim() == currentUserId.trim();
    final canPinThisMessage = _canPinAnyMessage || isMine;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine && message.messageType != 'event_pinned')
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () => Navigator.of(ctx).pop('edit'),
              ),
            if (canPinThisMessage)
              ListTile(
                leading: Icon(
                  message.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(message.isPinned ? 'Unpin message' : 'Pin message'),
                onTap: () => Navigator.of(ctx).pop('pin'),
              ),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      await _editMessage(message);
      return;
    }
    if (action == 'pin') {
      await _togglePin(message);
    }
  }

  Future<void> _sendImageMessage() async {
    if (_activeTab == _ChatListTab.pinned) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Switch to All tab to send messages.')),
        );
      }
      return;
    }
    if (_isSending) {
      return;
    }
    final clubId = _clubFromRoute(context).id.trim();
    if (clubId.isEmpty) {
      return;
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
      );
      if (picked == null) {
        return;
      }
      setState(() {
        _isSending = true;
      });
      final senderId = currentUserId.trim();
      final senderName = await _resolveDisplayName();
      final Uint8List bytes = await picked.readAsBytes();
      final uploaded = await AppwriteService.uploadFile(
        bucketId: AppwriteConfig.storageBucketId,
        path: picked.path,
        bytes: bytes,
        filename: picked.name,
      );
      await _chatRepo.sendMessage(
        clubId: clubId,
        senderId: senderId,
        senderName: senderName,
        text: _composerCtrl.text.trim(),
        imageFileId: uploaded.$id,
      );
      _composerCtrl.clear();
      await _loadMessages(silent: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send image.')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
      });
    }
  }

  Widget _buildChatItem(BuildContext context, ClubChatMessage message) {
    final isMine = message.senderId.trim() == currentUserId.trim();
    final content =
        message.messageType == 'event_pinned'
        ? _PinnedEventCard(
            title: message.eventTitle?.trim().isNotEmpty == true
                ? message.eventTitle!
                : 'Event',
            location: message.eventLocation ?? '',
            startAt: message.eventStartAt ?? message.createdAt,
            onView: () => _openPinnedEvent(message),
          )
        : isMine
        ? _OutgoingBubble(
            text: message.text,
            imageFileId: message.imageFileId,
            sentAt: message.editedAt ?? message.createdAt,
            isEdited: message.editedAt != null,
            primary: _teal,
          )
        : _IncomingBubble(
            name: message.senderName.trim().isEmpty
                ? 'Member'
                : message.senderName,
            avatarColor: const Color(0xFF2196F3),
            avatarIcon: Icons.person_outline,
            text: message.text,
            imageFileId: message.imageFileId,
            sentAt: message.editedAt ?? message.createdAt,
            isEdited: message.editedAt != null,
          );
    return GestureDetector(
      onLongPress: () => _showMessageActions(message),
      child: content,
    );
  }

  List<ClubChatMessage> _visibleMessages() {
    if (_activeTab == _ChatListTab.pinned) {
      final pinned = _messages.where((m) => m.isPinned).toList()
        ..sort((a, b) {
          final aTime = a.pinnedAt ?? a.createdAt;
          final bTime = b.pinnedAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });
      return pinned;
    }
    return _messages;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  String _dateSeparatorLabel(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) {
      return 'Today';
    }
    if (diff == 1) {
      return 'Yesterday';
    }
    return '${local.month}/${local.day}/${local.year}';
  }

  Widget _buildDateSeparator(DateTime d) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _teal.withValues(alpha: 0.35)),
        ),
        child: Text(
          _dateSeparatorLabel(d),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        ),
      ),
    );
  }

  Future<void> _openPinnedEvent(ClubChatMessage message) async {
    final eventId = message.targetEventId?.trim() ?? '';
    if (eventId.isEmpty) {
      return;
    }
    try {
      final doc = await AppwriteService.getDocument(
        collectionId: AppwriteConfig.eventsCollectionId,
        documentId: eventId,
      );
      if (!mounted) {
        return;
      }
      final event = Event.fromMap(Map<String, dynamic>.from(doc.data), id: doc.$id);
      await Navigator.of(context).pushNamed(
        EventDetailScreen.routeName,
        arguments: EventDetailArgs(event: event),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this event.')),
      );
    }
  }

  void _openInfo(Club club) {
    // On web, stacked post-frame callbacks can wait for another pointer event.
    // Use next event-loop turn so navigation happens immediately after tap.
    Future<void>.delayed(Duration.zero, () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: ClubInfoScreen.routeName,
            arguments: club,
          ),
          builder: (context) => const ClubInfoScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final club = _clubFromRoute(context);
    final members = _membersCount ?? club.membersCount ?? _mockMembers(club);

    return Scaffold(
      backgroundColor: _mint,
      appBar: AppBar(
        backgroundColor: _teal,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        // Web/AppBar: avoid LayoutBuilder + flex in the title slot (constraints can be
        // loose/unbounded briefly). Use MediaQuery for a finite width every frame.
        title: Builder(
          builder: (context) {
            final screenW = MediaQuery.sizeOf(context).width;
            final titleW = screenW > 0
                ? (screenW - 72).clamp(160.0, 1200.0)
                : 280.0;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openInfo(club),
              child: SizedBox(
                width: titleW,
                height: kToolbarHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ClubChatThumb(club: club, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            club.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$members members',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _ChatTabChip(
                  label: 'All',
                  selected: _activeTab == _ChatListTab.all,
                  onTap: () => setState(() => _activeTab = _ChatListTab.all),
                ),
                const SizedBox(width: 8),
                _ChatTabChip(
                  label: 'Pinned',
                  selected: _activeTab == _ChatListTab.pinned,
                  onTap: () => setState(() => _activeTab = _ChatListTab.pinned),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Text(
                      _loadError!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : _visibleMessages().isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet. Start the conversation.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: _visibleMessages().length,
                    itemBuilder: (context, index) {
                      final items = _visibleMessages();
                      final item = items[index];
                      final showDateHeader =
                          _activeTab == _ChatListTab.all &&
                          (index == 0 ||
                              !_isSameDate(
                                items[index - 1].createdAt,
                                item.createdAt,
                              ));
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == items.length - 1 ? 0 : 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateHeader) ...[
                              _buildDateSeparator(item.createdAt),
                              const SizedBox(height: 10),
                            ],
                            _buildChatItem(context, item),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _teal.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composerCtrl,
                        decoration: InputDecoration(
                          hintText: 'Message ${club.name}...',
                          filled: true,
                          fillColor: _mint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide(
                              color: _teal.withValues(alpha: 0.45),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide(
                              color: _teal.withValues(alpha: 0.45),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: const BorderSide(
                              color: _teal,
                              width: 1.4,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        enabled: _activeTab == _ChatListTab.all,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: _teal.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: (_isSending || _activeTab == _ChatListTab.pinned)
                            ? null
                            : _sendImageMessage,
                        borderRadius: BorderRadius.circular(999),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: Color(0xFF0F5549),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: _teal,
                      borderRadius: BorderRadius.circular(999),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: (_isSending || _activeTab == _ChatListTab.pinned)
                            ? null
                            : _sendMessage,
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 20,
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

class _ClubChatThumb extends StatelessWidget {
  final Club club;
  final double size;

  const _ClubChatThumb({required this.club, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          ],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: club.thumbnailFileId != null && club.thumbnailFileId!.isNotEmpty
          ? FutureBuilder(
              future: AppwriteService.getFileViewBytes(
                bucketId: AppwriteConfig.storageBucketId,
                fileId: club.thumbnailFileId!,
              ),
              builder: (context, snap) {
                final bytes = snap.data;
                if (snap.connectionState == ConnectionState.done &&
                    bytes != null &&
                    bytes.isNotEmpty) {
                  return Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                  );
                }
                if (snap.connectionState == ConnectionState.waiting ||
                    snap.connectionState == ConnectionState.active) {
                  return Center(
                    child: SizedBox(
                      width: size * 0.45,
                      height: size * 0.45,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }
                return Icon(
                  Icons.sports_soccer,
                  color: Theme.of(context).colorScheme.primary,
                  size: size * 0.5,
                );
              },
            )
          : Icon(
              Icons.sports_soccer,
              color: Theme.of(context).colorScheme.primary,
              size: size * 0.5,
            ),
    );
  }
}

class _IncomingBubble extends StatelessWidget {
  final String name;
  final Color avatarColor;
  final IconData avatarIcon;
  final String text;
  final String? imageFileId;
  final DateTime sentAt;
  final bool isEdited;

  const _IncomingBubble({
    required this.name,
    required this.avatarColor,
    required this.avatarIcon,
    required this.text,
    this.imageFileId,
    required this.sentAt,
    this.isEdited = false,
  });

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);
    const green = Color(0xFF0F5549);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: Icon(avatarIcon, color: avatarColor, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  border: Border.all(color: teal.withValues(alpha: 0.65)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (imageFileId != null && imageFileId!.trim().isNotEmpty)
                      _ChatImage(fileId: imageFileId!),
                    if (imageFileId != null &&
                        imageFileId!.trim().isNotEmpty &&
                        text.trim().isNotEmpty)
                      const SizedBox(height: 8),
                    if (text.trim().isNotEmpty)
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isEdited) ...[
                          Text(
                            'edited',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black.withValues(alpha: 0.45),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _formatChatTime(sentAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutgoingBubble extends StatelessWidget {
  final String text;
  final String? imageFileId;
  final DateTime sentAt;
  final bool isEdited;
  final Color primary;

  const _OutgoingBubble({
    required this.text,
    this.imageFileId,
    required this.sentAt,
    this.isEdited = false,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0F5549);
    final screenW = MediaQuery.sizeOf(context).width;
    final maxBubbleW = screenW > 0 ? screenW * 0.78 : 320.0;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxBubbleW),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: green,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageFileId != null && imageFileId!.trim().isNotEmpty)
              _ChatImage(fileId: imageFileId!),
            if (imageFileId != null &&
                imageFileId!.trim().isNotEmpty &&
                text.trim().isNotEmpty)
              const SizedBox(height: 8),
            if (text.trim().isNotEmpty)
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEdited) ...[
                  Text(
                    'edited',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _formatChatTime(sentAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatChatTime(DateTime dt) {
  final t = dt.toLocal();
  final hour12 = ((t.hour + 11) % 12) + 1;
  final minute = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $ampm';
}

class _PinnedEventCard extends StatelessWidget {
  final String title;
  final String location;
  final DateTime startAt;
  final VoidCallback onView;

  const _PinnedEventCard({
    required this.title,
    required this.location,
    required this.startAt,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);
    const mint = Color(0xFFF0FDFA);
    const green = Color(0xFF0F5549);
    String two(int n) => n.toString().padLeft(2, '0');
    final month = two(startAt.month);
    final day = two(startAt.day);
    final h = startAt.hour;
    final hour12 = ((h + 11) % 12) + 1;
    final ampm = h >= 12 ? 'pm' : 'am';
    final min = two(startAt.minute);
    final when = '$month/$day ${hour12}:$min$ampm';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: teal.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.push_pin, size: 16, color: Colors.red.shade400),
              const SizedBox(width: 6),
              Text(
                'EVENT PINNED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$when${location.trim().isNotEmpty ? ' · $location' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: onView,
              style: FilledButton.styleFrom(
                foregroundColor: green,
                backgroundColor: teal.withValues(alpha: 0.14),
              ),
              child: const Text(
                'View Event',
                style: TextStyle(fontWeight: FontWeight.w800, color: green),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChatTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? teal.withValues(alpha: 0.16) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? teal : teal.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFF0F5549),
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ChatImage extends StatelessWidget {
  final String fileId;

  const _ChatImage({required this.fileId});

  @override
  Widget build(BuildContext context) {
    void openPreview(Uint8List bytes) {
      Future<void> downloadImage() async {
        try {
          final uri = AppwriteService.getFileDownloadUri(
            bucketId: AppwriteConfig.storageBucketId,
            fileId: fileId,
          );
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }

      showDialog<void>(
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
                  onPressed: downloadImage,
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
      child: FutureBuilder(
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

