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
import '../../../data/club_chat_repository.dart';
import '../../../data/club_join_request_repository.dart';
import '../../../data/club_member_repository.dart';
import '../../../data/club_repository.dart';
import '../../../data/notification_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/app_notification.dart';
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
  static const Duration _editWindow = Duration(minutes: 30);
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
  bool _canSendMessages = false;
  bool _showJoinClubInAppBar = false;
  bool _hasPendingJoinRequest = false;
  bool _joinRequiresApproval = false;
  bool _isJoiningClub = false;
  final Set<String> _syncedPinnedEventIds = <String>{};

  String _chatReadKey(String clubId) {
    final me = currentUserId.trim().toLowerCase();
    return 'club_chat_last_read_${me}_${clubId.trim()}';
  }

  Future<void> _markClubRead(String clubId, List<ClubChatMessage> items) async {
    if (clubId.trim().isEmpty || currentUserId.trim().isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final latestMessageAt = items.isEmpty
        ? DateTime.now().toUtc()
        : items
              .map((message) => message.createdAt.toUtc())
              .reduce((a, b) => a.isAfter(b) ? a : b);
    await prefs.setString(
      _chatReadKey(clubId),
      latestMessageAt.toIso8601String(),
    );
  }

  Future<void> _markCurrentClubReadNow() async {
    final clubId = _clubFromRoute(context).id.trim();
    if (clubId.isEmpty || currentUserId.trim().isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chatReadKey(clubId),
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _loadMembersCount();
      _resolvePinPrivileges();
      _resolveSendPermission();
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
        _markCurrentClubReadNow();
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
      final creatorId = (club.creatorId ?? '').trim();
      final founderId = (club.founderId ?? club.creatorId ?? '').trim();
      final syntheticOwnerId = creatorId.isNotEmpty ? creatorId : founderId;
      var resolvedCount = members.length;
      if (syntheticOwnerId.isNotEmpty &&
          !members.any((member) => member.userId.trim() == syntheticOwnerId)) {
        resolvedCount += 1;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _membersCount = resolvedCount;
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

  Future<void> _resolveSendPermission() async {
    final club = _clubFromRoute(context);
    final me = currentUserId.trim();
    if (club.id.trim().isEmpty || me.isEmpty) {
      if (mounted) {
        setState(() {
          _canSendMessages = false;
          _showJoinClubInAppBar = false;
          _hasPendingJoinRequest = false;
          _joinRequiresApproval = false;
        });
      }
      return;
    }
    final isCreator = (club.creatorId ?? '').trim() == me;
    if (isCreator) {
      if (mounted) {
        setState(() {
          _canSendMessages = true;
          _showJoinClubInAppBar = false;
          _hasPendingJoinRequest = false;
          _joinRequiresApproval = false;
        });
      }
      return;
    }
    try {
      final isMember = await clubMemberRepository().isMember(
        clubId: club.id,
        userId: me,
      );
      if (!isMember) {
        final fresh = await clubRepository().getClub(club.id) ?? club;
        final pending = fresh.pendingJoinRequestUserIds
            .map((id) => id.trim())
            .contains(me);
        if (!mounted) {
          return;
        }
        setState(() {
          _canSendMessages = false;
          _showJoinClubInAppBar = true;
          _hasPendingJoinRequest = pending;
          _joinRequiresApproval =
              fresh.privacy.trim().toLowerCase() == 'private';
        });
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _showJoinClubInAppBar = false;
        _hasPendingJoinRequest = false;
        _joinRequiresApproval = false;
      });
      final rule = club.whoCanSendMessages.trim();
      if (rule == 'Admins only') {
        final isAdmin = await clubMemberRepository().isAdmin(
          clubId: club.id,
          userId: me,
        );
        if (!mounted) {
          return;
        }
        setState(() => _canSendMessages = isAdmin);
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() => _canSendMessages = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _canSendMessages = false;
          _showJoinClubInAppBar = false;
          _hasPendingJoinRequest = false;
          _joinRequiresApproval = false;
        });
      }
    }
  }

  Future<void> _joinFromChatAppBar() async {
    if (_isJoiningClub || _hasPendingJoinRequest) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final routed = _clubFromRoute(context);
    setState(() => _isJoiningClub = true);
    var usedApproval = false;
    try {
      final club = await clubRepository().getClub(routed.id) ?? routed;
      usedApproval = club.privacy.trim().toLowerCase() == 'private';
      await clubJoinRequestRepository().requestToJoin(
        clubId: club.id,
        userId: currentUserId,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to join club.')),
      );
      return;
    } finally {
      if (mounted) {
        setState(() => _isJoiningClub = false);
      }
    }
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          usedApproval
              ? 'Join request sent. Awaiting approval from the club creator.'
              : 'Joined club.',
        ),
      ),
    );
    await _resolveSendPermission();
    await _loadMembersCount();
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
      final correctedPinnedTimes = await _syncPinnedEventTimes(items);
      final afterSyncItems = correctedPinnedTimes
          ? await _chatRepo.listForClub(clubId)
          : items;
      final removedExpiredPins = await _unpinEndedEventMessages(afterSyncItems);
      final resolvedItems = removedExpiredPins
          ? await _chatRepo.listForClub(clubId)
          : afterSyncItems;
      await _markClubRead(clubId, resolvedItems);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages
          ..clear()
          ..addAll(resolvedItems);
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

  Future<bool> _syncPinnedEventTimes(List<ClubChatMessage> items) async {
    final candidates = items
        .where(
          (message) =>
              message.messageType == 'event_pinned' &&
              (message.targetEventId?.trim().isNotEmpty ?? false),
        )
        .toList();
    if (candidates.isEmpty) {
      return false;
    }

    final eventIds = candidates
        .map((message) => message.targetEventId!.trim())
        .where((id) => id.isNotEmpty && !_syncedPinnedEventIds.contains(id))
        .toSet();
    if (eventIds.isEmpty) {
      return false;
    }

    var changed = false;
    for (final eventId in eventIds) {
      try {
        final doc = await AppwriteService.getDocument(
          collectionId: AppwriteConfig.eventsCollectionId,
          documentId: eventId,
        );
        final event = Event.fromMap(
          Map<String, dynamic>.from(doc.data),
          id: doc.$id,
        );
        final expectedStartUtc = event.startAt.toUtc();
        final expectedEndUtc = event.startAt.add(event.duration).toUtc();
        final linkedMessages = candidates
            .where((message) => message.targetEventId?.trim() == eventId)
            .toList();
        for (final message in linkedMessages) {
          final actualStartUtc = message.eventStartAt?.toUtc();
          final actualEndUtc = message.eventEndAt?.toUtc();
          final startMatches =
              actualStartUtc != null &&
              actualStartUtc.difference(expectedStartUtc).inMinutes.abs() <= 1;
          final endMatches =
              actualEndUtc != null &&
              actualEndUtc.difference(expectedEndUtc).inMinutes.abs() <= 1;
          if (startMatches && endMatches) {
            continue;
          }
          await AppwriteService.updateDocument(
            collectionId: AppwriteConfig.clubMessagesCollectionId,
            documentId: message.id,
            data: <String, dynamic>{
              'eventStartAt': expectedStartUtc.toIso8601String(),
              'eventEndAt': expectedEndUtc.toIso8601String(),
            },
          );
          changed = true;
        }
      } catch (_) {
        // Best-effort correction for legacy pinned messages.
      } finally {
        _syncedPinnedEventIds.add(eventId);
      }
    }
    return changed;
  }

  Future<bool> _unpinEndedEventMessages(List<ClubChatMessage> items) async {
    final nowUtc = DateTime.now().toUtc();
    final expiredPinned = items
        .where(
          (message) =>
              message.isPinned &&
              message.messageType == 'event_pinned' &&
              message.eventEndAt != null &&
              nowUtc.isAfter(message.eventEndAt!.toUtc()),
        )
        .toList();
    if (expiredPinned.isEmpty) {
      return false;
    }
    var changed = false;
    for (final message in expiredPinned) {
      try {
        await _chatRepo.setPinned(messageId: message.id, isPinned: false);
        changed = true;
      } catch (_) {}
    }
    return changed;
  }

  Future<void> _sendMessage() async {
    if (!_canSendMessages) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join this club to send messages.')),
        );
      }
      return;
    }
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
    final club = _clubFromRoute(context);
    final clubId = club.id.trim();
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
      await _notifyClubMembersForMessage(
        club: club,
        clubId: clubId,
        senderName: senderName,
        messageText: text,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send message.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _editMessage(ClubChatMessage message) async {
    if (!_canEditMessage(message)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messages can only be edited within 30 minutes.'),
          ),
        );
      }
      return;
    }
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
    if (newText == null ||
        newText.trim().isEmpty ||
        newText.trim() == existing) {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to edit message.')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update pin.')));
    }
  }

  Future<void> _showMessageActions(ClubChatMessage message) async {
    final isMine = message.senderId.trim() == currentUserId.trim();
    final canEditThisMessage =
        isMine &&
        message.messageType != 'event_pinned' &&
        _canEditMessage(message);
    final canPinThisMessage = _canPinAnyMessage || isMine;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEditThisMessage)
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

  bool _canEditMessage(ClubChatMessage message) {
    final createdAtUtc = message.createdAt.toUtc();
    final deadline = createdAtUtc.add(_editWindow);
    return DateTime.now().toUtc().isBefore(deadline);
  }

  Future<void> _sendImageMessage() async {
    if (!_canSendMessages) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join this club to send messages.')),
        );
      }
      return;
    }
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
    final club = _clubFromRoute(context);
    final clubId = club.id.trim();
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
      await _notifyClubMembersForMessage(
        club: club,
        clubId: clubId,
        senderName: senderName,
        messageText: _composerCtrl.text.trim(),
        hasImage: true,
      );
      _composerCtrl.clear();
      await _loadMessages(silent: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send image.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _notifyClubMembersForMessage({
    required Club club,
    required String clubId,
    required String senderName,
    required String messageText,
    bool hasImage = false,
  }) async {
    try {
      final members = await clubMemberRepository().listMembers(clubId: clubId);
      final recipientIds = members
          .map((m) => m.userId.trim())
          .where((id) => id.isNotEmpty && id != currentUserId.trim())
          .toSet();
      if (recipientIds.isEmpty) {
        return;
      }
      final trimmed = messageText.trim();
      final preview = trimmed.isEmpty
          ? (hasImage ? 'sent a photo' : 'sent a message')
          : trimmed;
      final createdAt = DateTime.now();
      for (final userId in recipientIds) {
        final notification = AppNotification(
          id: 'club_chat_${club.id}_${userId}_${createdAt.microsecondsSinceEpoch}',
          userId: userId,
          type: AppNotificationType.chatMessage,
          title: 'New club message',
          message: '$senderName in ${club.name}: $preview',
          createdAt: createdAt,
        );
        await notificationRepository().upsertMany(userId, [notification]);
      }
    } catch (_) {
      // Best-effort notification write; do not block sending message.
    }
  }

  Widget _buildChatItem(BuildContext context, ClubChatMessage message) {
    final isMine = message.senderId.trim() == currentUserId.trim();
    final isEnded =
        message.messageType == 'event_pinned' &&
        message.eventEndAt != null &&
        DateTime.now().toUtc().isAfter(message.eventEndAt!.toUtc());
    final content = message.messageType == 'event_pinned'
        ? _PinnedEventCard(
            title: message.eventTitle?.trim().isNotEmpty == true
                ? message.eventTitle!
                : 'Event',
            location: message.eventLocation ?? '',
            startAt: message.eventStartAt ?? message.createdAt,
            isEnded: isEnded,
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

  DateTime _messageDateForList(ClubChatMessage message) {
    return message.createdAt;
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
      final event = Event.fromMap(
        Map<String, dynamic>.from(doc.data),
        id: doc.$id,
      );
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
        actions: [
          if (_showJoinClubInAppBar)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: _hasPendingJoinRequest
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Pending',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : FilledButton(
                        onPressed: _isJoiningClub ? null : _joinFromChatAppBar,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: _isJoiningClub
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0F766E),
                                ),
                              )
                            : Text(
                                _joinRequiresApproval ? 'Request' : 'Join',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                      ),
              ),
            ),
        ],
        title: Builder(
          builder: (context) {
            final screenW = MediaQuery.sizeOf(context).width;
            final trailingReserve = _showJoinClubInAppBar ? 112.0 : 0.0;
            final titleW = screenW > 0
                ? (screenW - 72 - trailingReserve).clamp(160.0, 1200.0)
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
                      final itemDate = _messageDateForList(item);
                      final showDateHeader =
                          index == 0 ||
                          !_isSameDate(
                            _messageDateForList(items[index - 1]),
                            itemDate,
                          );
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == items.length - 1 ? 0 : 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateHeader) ...[
                              _buildDateSeparator(itemDate),
                              const SizedBox(height: 10),
                            ],
                            _buildChatItem(context, item),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_canSendMessages)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _teal.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _composerCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Message...',
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 10,
                            ),
                          ),
                          enabled: _activeTab == _ChatListTab.all,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed:
                            (_isSending || _activeTab == _ChatListTab.pinned)
                            ? null
                            : _sendImageMessage,
                        icon: const Icon(
                          Icons.image_outlined,
                          color: Color(0xFF0F5549),
                          size: 20,
                        ),
                      ),
                      Material(
                        color: _teal,
                        borderRadius: BorderRadius.circular(999),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap:
                              (_isSending || _activeTab == _ChatListTab.pinned)
                              ? null
                              : _sendMessage,
                          borderRadius: BorderRadius.circular(999),
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
  final bool isEnded;
  final VoidCallback onView;

  const _PinnedEventCard({
    required this.title,
    required this.location,
    required this.startAt,
    required this.isEnded,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);
    const mint = Color(0xFFF0FDFA);
    const green = Color(0xFF0F5549);
    String two(int n) => n.toString().padLeft(2, '0');
    final localStartAt = startAt.toLocal();
    final month = two(localStartAt.month);
    final day = two(localStartAt.day);
    final h = localStartAt.hour;
    final hour12 = ((h + 11) % 12) + 1;
    final ampm = h >= 12 ? 'pm' : 'am';
    final min = two(localStartAt.minute);
    final when = '$month/$day $hour12:$min$ampm';
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
              if (isEnded) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'ENDED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
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
