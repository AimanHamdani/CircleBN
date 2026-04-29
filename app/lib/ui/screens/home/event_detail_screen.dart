import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../utils/web_storage.dart';
import '../../../data/event_repository.dart';
import '../../../data/event_chat_repository.dart';
import '../../../data/club_repository.dart';
import '../../../data/event_invite_repository.dart';
import '../../../data/event_registration_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../data/membership_repository.dart';
import '../../../data/notification_repository.dart';
import '../../../models/app_notification.dart';
import '../../../models/event.dart';
import '../../../models/event_chat_message.dart';
import '../../../models/event_privacy.dart';
import '../../../models/user_profile.dart';
import '../../../services/attendance_service.dart';
import '../../../services/ticket_service.dart';
import '../profile/user_profile_view_screen.dart';
import 'create_event_screen.dart';
import 'event_scoring_screen.dart';
import 'scan_qr_screen.dart';
import '../../theme/app_theme.dart';

class EventDetailArgs {
  final Event event;
  final bool showRegisterButton;
  final bool allowCreatorActions;
  final DateTime? chatEnabledUntil;
  const EventDetailArgs({
    required this.event,
    this.showRegisterButton = true,
    this.allowCreatorActions = true,
    this.chatEnabledUntil,
  });
}

enum _EventDetailTab { details, chat, participants }

class _ParticipantItem {
  final String userId;
  final String username;
  final Color color;
  final String? avatarFileId;
  final bool isAttended;
  final bool isHostVerified;

  const _ParticipantItem({
    required this.userId,
    required this.username,
    required this.color,
    this.avatarFileId,
    this.isAttended = false,
    this.isHostVerified = false,
  });
}

class EventDetailScreen extends StatefulWidget {
  static const routeName = '/event';
  const EventDetailScreen({super.key});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  _EventDetailTab _tab = _EventDetailTab.details;
  final _composerCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _isDeleting = false;
  Event? _eventOverride;
  EventDetailArgs? _argsOverride;
  String? _activeEventId;
  bool? _isRegisteredByMe;
  bool _isAttendedByMe = false;
  int? _joinedCount;
  List<_ParticipantItem>? _participants;
  final _eventChatRepo = eventChatRepository();
  List<EventChatMessage> _chatMessages = const <EventChatMessage>[];
  Timer? _chatPollTimer;
  RealtimeSubscription? _chatRealtimeSubscription;
  String? _chatSubscribedEventId;
  bool _isChatLoading = false;
  bool _isChatSending = false;
  String? _chatError;
  String? _chatSenderName;

  bool _didTryReloadAfterRefresh = false;
  bool _didTryInitialRouteRefresh = false;

  static const String _storageKey = 'circlebn_last_event_detail';

  @override
  void dispose() {
    _chatPollTimer?.cancel();
    _chatRealtimeSubscription?.close();
    _composerCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;

    // Persist the current detail screen context for web refresh.
    if (args is EventDetailArgs) {
      _persistDetailArgs(args);
    } else if (args is Event) {
      _persistDetailArgs(EventDetailArgs(event: args));
    }

    // Refresh once for the current route's event id so we always read latest
    // registration/joined state instead of stale navigation args.
    if (!_didTryInitialRouteRefresh && args != null) {
      _didTryInitialRouteRefresh = true;
      final initialId = (args is EventDetailArgs
          ? args.event.id
          : (args is Event ? args.id : null));
      if (initialId != null) {
        _refreshEvent(eventId: initialId);
      }
    }

    // If we refreshed the browser, route args are lost; reload from last stored event id.
    if (!_didTryReloadAfterRefresh && args == null) {
      _didTryReloadAfterRefresh = true;
      final stored = _loadStoredArgs();
      if (stored != null) {
        _argsOverride = stored;
        _refreshEvent(eventId: stored.event.id);
      }
    }

    _chatPollTimer ??= Timer.periodic(const Duration(seconds: 20), (_) {
      _loadChatMessages(silent: true);
    });
    _ensureChatRealtimeSubscription();
    _loadChatMessages(silent: _chatMessages.isNotEmpty);
  }

  EventDetailArgs _argsFromRoute(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is EventDetailArgs) return args;
    if (args is Event) return EventDetailArgs(event: args);

    // Web refresh fallback: try restore stored event detail flags and event id.
    if (_argsOverride != null) {
      return _argsOverride!;
    }

    return _loadStoredArgs() ??
        EventDetailArgs(
          event: Event(
            id: 'missing',
            title: 'Event',
            sport: 'Sport',
            startAt: DateTime.now(),
            duration: const Duration(hours: 1),
            location: 'Location',
            joined: 0,
            capacity: 0,
            skillLevel: '—',
            entryFeeLabel: '—',
            description: 'No data (mock).',
            joinedByMe: false,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final args = _argsFromRoute(context);
    final e = _eventOverride ?? args.event;
    _syncLocalEventState(e);
    final isRegisteredByMe = _isRegisteredByMe ?? e.joinedByMe;
    final canSendChat =
        args.chatEnabledUntil == null ||
        DateTime.now().isBefore(args.chatEnabledUntil!);
    final canCurrentUserSendEventChat =
        isRegisteredByMe || (e.creatorId ?? '').trim() == currentUserId.trim();
    final canSendEventChatNow = canSendChat && canCurrentUserSendEventChat;
    final joinedCount = (_joinedCount ?? e.joined).clamp(
      0,
      e.capacity > 0 ? e.capacity : 999999,
    );
    final participants =
        _participants ??
        _participantsFromProfiles(_buildParticipantProfilesFromEvent(e));

    final isEventFull = e.capacity > 0 && joinedCount >= e.capacity;
    return Theme(
      data: AppTheme.eventFlowTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 220,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFEDE9FE), Color(0xFFF5F3FF)],
                      ),
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    child:
                        e.thumbnailFileId != null &&
                            e.thumbnailFileId!.isNotEmpty
                        ? FutureBuilder(
                            future: AppwriteService.getFileViewBytes(
                              bucketId: AppwriteConfig.eventImagesBucketId,
                              fileId: e.thumbnailFileId!,
                            ),
                            builder: (context, snap) {
                              if (snap.hasData) {
                                return Image.memory(
                                  snap.data!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                );
                              }
                              return Icon(
                                Icons.image_outlined,
                                color: Colors.black.withValues(alpha: 0.35),
                                size: 56,
                              );
                            },
                          )
                        : Icon(
                            Icons.image_outlined,
                            color: Colors.black.withValues(alpha: 0.35),
                            size: 56,
                          ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _RoundIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeroStatusBadge(isFull: isEventFull),
                        if (e.creatorId != null &&
                            e.creatorId == currentUserId &&
                            args.allowCreatorActions) ...[
                          const SizedBox(width: 8),
                          _RoundIconButton(
                            icon: Icons.qr_code_scanner,
                            onTap: () => _openScanQr(e),
                          ),
                          const SizedBox(width: 8),
                          _RoundIconButton(
                            icon: Icons.edit_outlined,
                            onTap: () => _onEditEvent(e),
                          ),
                          const SizedBox(width: 8),
                          _RoundIconButton(
                            icon: Icons.scoreboard_outlined,
                            onTap: () => _openScoreEntry(e),
                          ),
                          const SizedBox(width: 8),
                          _RoundIconButton(
                            icon: _isDeleting
                                ? Icons.hourglass_top
                                : Icons.delete_outline,
                            onTap: _isDeleting
                                ? () {}
                                : () => _confirmDeleteEvent(e),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: _TabHeader(
                  selected: _tab,
                  onSelect: (t) {
                    setState(() => _tab = t);
                    if (t == _EventDetailTab.chat) {
                      _loadChatMessages();
                    }
                  },
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _tab == _EventDetailTab.details
                      ? _DetailsTab(
                          key: ValueKey('details-${e.id}'),
                          event: e.copyWith(
                            joined: joinedCount,
                            joinedByMe: isRegisteredByMe,
                          ),
                        )
                      : _tab == _EventDetailTab.chat
                      ? _ChatTab(
                          key: const ValueKey('chat'),
                          eventTitle: e.title,
                          isLoading: _isChatLoading,
                          errorMessage: _chatError,
                          messages: _chatMessages,
                        )
                      : _ParticipantsTab(
                          key: const ValueKey('participants'),
                          participants: participants,
                          onOpenProfile: (userId) {
                            Navigator.of(context).pushNamed(
                              UserProfileViewScreen.routeName,
                              arguments: UserProfileViewArgs(userId: userId),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _tab == _EventDetailTab.chat
            ? _chatComposerBar(context, canSendChat: canSendEventChatNow)
            : _tab == _EventDetailTab.details
            ? _detailsBottomBars(
                context,
                args: args,
                event: e,
                isRegistered: isRegisteredByMe,
                joinedCount: joinedCount,
              )
            : null,
      ),
    );
  }

  Widget? _detailsBottomBars(
    BuildContext context, {
    required EventDetailArgs args,
    required Event event,
    required bool isRegistered,
    required int joinedCount,
  }) {
    final creatorId = (event.creatorId ?? '').trim();
    final isCreator = creatorId == currentUserId;
    final showJoinRequestsStrip =
        args.allowCreatorActions &&
        isCreator &&
        eventInviteRepository().isRequestJoinPrivate(event) &&
        event.pendingJoinRequestUserIds.isNotEmpty;
    final showRegisterBar =
        args.showRegisterButton && (event.creatorId == null || !isCreator);

    if (!showJoinRequestsStrip && !showRegisterBar) {
      return null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showJoinRequestsStrip)
          _JoinRequestsCreatorStrip(
            event: event,
            onChanged: () => _refreshEvent(eventId: event.id),
          ),
        if (showRegisterBar)
          _registerBar(
            context,
            isRegistered: isRegistered,
            joinedCount: joinedCount,
            capacity: event.capacity,
            onTap: () => _toggleRegistration(event),
            event: event,
            userProfile: null,
          ),
      ],
    );
  }

  Future<void> _submitJoinRequest(Event event) async {
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.eventsCollectionId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appwrite is not configured.')),
        );
      }
      return;
    }
    try {
      await eventInviteRepository().submitJoinRequest(
        eventId: event.id,
        userId: currentUserId,
      );
      final creatorId = (event.creatorId ?? '').trim();
      if (creatorId.isNotEmpty && creatorId != currentUserId) {
        final createdAt = DateTime.now();
        await notificationRepository().upsertMany(creatorId, [
          AppNotification(
            id: 'join_request_${event.id}_${currentUserId}_${createdAt.millisecondsSinceEpoch}',
            userId: creatorId,
            type: AppNotificationType.eventJoinRequest,
            title: 'New join request',
            message: 'Someone requested to join ${event.title}.',
            createdAt: createdAt,
            targetEventId: event.id,
          ),
        ]);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join request sent to the host.')),
      );
      await _refreshEvent(eventId: event.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send request: $e')));
    }
  }

  Widget _registerBar(
    BuildContext context, {
    required bool isRegistered,
    required int joinedCount,
    required int capacity,
    required VoidCallback onTap,
    required Event event,
    required UserProfile? userProfile,
  }) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isFull = capacity > 0 && joinedCount >= capacity;
    final eventEnded = _hasEventEnded(event);
    final requestMode = eventInviteRepository().isRequestJoinPrivate(event);
    final pendingRequest = event.pendingJoinRequestUserIds.contains(
      currentUserId,
    );

    final String label;
    final VoidCallback? effectiveOnTap;
    if (isRegistered) {
      label = 'Cancel Registration';
      effectiveOnTap = onTap;
    } else if (eventEnded) {
      label = 'Event Ended';
      effectiveOnTap = null;
    } else if (requestMode && pendingRequest) {
      label = 'Request pending';
      effectiveOnTap = null;
    } else if (requestMode && !pendingRequest) {
      label = 'Request to join';
      effectiveOnTap = () => _submitJoinRequest(event);
    } else if (isFull) {
      label = 'Event Full';
      effectiveOnTap = null;
    } else {
      label = 'Register';
      effectiveOnTap = onTap;
    }
    final counterText = capacity > 0
        ? '$joinedCount / $capacity joined'
        : '$joinedCount joined';
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                counterText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isRegistered) ...[
              ElevatedButton.icon(
                onPressed: () => _handleShareTicket(event),
                icon: const Icon(Icons.share),
                label: const Text('Share Ticket'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (_canCurrentUserScan(event)) ...[
                OutlinedButton.icon(
                  onPressed: () => _openScanQr(event),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(
                    (event.creatorId ?? '').trim() == currentUserId
                        ? 'Scan Attendance'
                        : 'Help Scan Attendance',
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            FilledButton(
              onPressed: (!isRegistered && isFull && !requestMode)
                  ? null
                  : effectiveOnTap,
              style: FilledButton.styleFrom(
                backgroundColor: isRegistered
                    ? Colors.white
                    : AppTheme.eventPurple,
                foregroundColor: isRegistered ? Colors.black87 : Colors.white,
                side: isRegistered
                    ? const BorderSide(color: Color(0xFFE3E7EE))
                    : null,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleShareTicket(Event event) async {
    try {
      // Fetch current user's profile
      final userProfile = await ProfileRepository().getMyProfile();

      if (!mounted) return;

      await _shareTicket(event, userProfile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareTicket(Event event, UserProfile userProfile) async {
    try {
      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Generating Ticket'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Please wait while we generate your ticket...'),
            ],
          ),
        ),
      );

      // Generate ticket ID
      final ticketId = await TicketService.generateTicketId(
        eventId: event.id,
        userId: currentUserId,
      );

      // Generate PDF
      final pdfBytes = await TicketService.generateTicketPdf(
        event: event,
        user: userProfile,
        ticketId: ticketId,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Share PDF using printing package
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            '${event.title}_ticket_${ticketId.toString().padLeft(5, '0')}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog if still open

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating ticket: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onEditEvent(Event event) async {
    if (!_canEditEvent(event)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Event editing is only allowed until 1 hour before start time.',
            ),
          ),
        );
      }
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(CreateEventScreen.routeName, arguments: event);

    if (!mounted) {
      return;
    }

    if (result == 'updated' || result == 'created' || result == true) {
      await _refreshEvent(eventId: event.id);
    }
  }

  Future<void> _openScoreEntry(Event event) async {
    await Navigator.of(context).pushNamed(
      EventScoringScreen.routeName,
      arguments: EventScoringArgs(event: event),
    );
    if (!mounted) {
      return;
    }
    await _refreshEvent(eventId: event.id);
  }

  Future<void> _openScanQr(Event event) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ScanQrScreen(event: event)));
  }

  bool _canCurrentUserScan(Event event) {
    return (event.creatorId ?? '').trim() == currentUserId || _isAttendedByMe;
  }

  bool _canEditEvent(Event event) {
    final editCutoff = event.startAt.subtract(const Duration(hours: 1));
    return DateTime.now().isBefore(editCutoff);
  }

  Widget _chatComposerBar(BuildContext context, {required bool canSendChat}) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + bottomInset),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _composerCtrl,
                  enabled: canSendChat,
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 10,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: canSendChat ? (_) => _sendChatMessage() : (_) {},
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: canSendChat && !_isChatSending
                    ? _sendChatImage
                    : null,
                icon: Icon(
                  Icons.image_outlined,
                  color: canSendChat
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.45),
                  size: 20,
                ),
              ),
              Material(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: canSendChat && !_isChatSending
                      ? _sendChatMessage
                      : null,
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: _isChatSending
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.send,
                              size: 18,
                              color: canSendChat
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendChatMessage() async {
    final args = _argsFromRoute(context);
    final event = _eventOverride ?? args.event;
    final canSendChat =
        args.chatEnabledUntil == null ||
        DateTime.now().isBefore(args.chatEnabledUntil!);
    final isRegisteredByMe = _isRegisteredByMe ?? event.joinedByMe;
    final canCurrentUserSendEventChat =
        isRegisteredByMe ||
        (event.creatorId ?? '').trim() == currentUserId.trim();
    if (!canCurrentUserSendEventChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only joined participants can chat in this event.'),
        ),
      );
      return;
    }
    if (!canSendChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messaging is locked for this event.')),
      );
      return;
    }
    final txt = _composerCtrl.text.trim();
    if (txt.isEmpty || _isChatSending) {
      return;
    }
    final eventId = (_eventOverride ?? args.event).id.trim();
    if (eventId.isEmpty) {
      return;
    }
    setState(() {
      _isChatSending = true;
    });
    try {
      final senderName = await _getChatSenderName();
      await _eventChatRepo.sendMessage(
        eventId: eventId,
        senderId: currentUserId,
        senderName: senderName,
        text: txt,
      );
      await _notifyEventParticipantsForMessage(
        event: event,
        senderName: senderName,
        messageText: txt,
      );
      _composerCtrl.clear();
      await _loadChatMessages(silent: true);
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
      if (!mounted) {
        return;
      }
      setState(() {
        _isChatSending = false;
      });
    }
  }

  Future<void> _sendChatImage() async {
    final args = _argsFromRoute(context);
    final event = _eventOverride ?? args.event;
    final canSendChat =
        args.chatEnabledUntil == null ||
        DateTime.now().isBefore(args.chatEnabledUntil!);
    final isRegisteredByMe = _isRegisteredByMe ?? event.joinedByMe;
    final canCurrentUserSendEventChat =
        isRegisteredByMe ||
        (event.creatorId ?? '').trim() == currentUserId.trim();
    if (!canCurrentUserSendEventChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only joined participants can chat in this event.'),
        ),
      );
      return;
    }
    if (!canSendChat || _isChatSending) {
      return;
    }
    final eventId = (_eventOverride ?? args.event).id.trim();
    if (eventId.isEmpty) {
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
        _isChatSending = true;
      });
      final senderName = await _getChatSenderName();
      final bytes = await picked.readAsBytes();
      final uploaded = await AppwriteService.uploadFile(
        bucketId: AppwriteConfig.storageBucketId,
        path: picked.path,
        bytes: bytes,
        filename: picked.name,
      );
      await _eventChatRepo.sendMessage(
        eventId: eventId,
        senderId: currentUserId,
        senderName: senderName,
        text: _composerCtrl.text.trim(),
        imageFileId: uploaded.$id,
      );
      await _notifyEventParticipantsForMessage(
        event: event,
        senderName: senderName,
        messageText: _composerCtrl.text.trim(),
        hasImage: true,
      );
      _composerCtrl.clear();
      await _loadChatMessages(silent: true);
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
      if (!mounted) {
        return;
      }
      setState(() {
        _isChatSending = false;
      });
    }
  }

  Future<String> _getChatSenderName() async {
    if (_chatSenderName != null && _chatSenderName!.trim().isNotEmpty) {
      return _chatSenderName!;
    }
    try {
      final profile = await profileRepository().getMyProfile();
      final realName = profile.realName.trim();
      if (realName.isNotEmpty && realName.toLowerCase() != 'name') {
        _chatSenderName = realName;
        return realName;
      }
      final username = profile.username.trim();
      if (username.isNotEmpty && username.toLowerCase() != 'username') {
        _chatSenderName = username;
        return username;
      }
    } catch (_) {}
    _chatSenderName = 'Member';
    return _chatSenderName!;
  }

  Future<void> _notifyEventParticipantsForMessage({
    required Event event,
    required String senderName,
    required String messageText,
    bool hasImage = false,
  }) async {
    try {
      final participantIds = await eventRegistrationRepository()
          .listParticipantUserIds(event.id);
      final recipientIds = <String>{for (final id in participantIds) id.trim()}
        ..removeWhere((id) => id.isEmpty || id == currentUserId.trim());
      final creatorId = (event.creatorId ?? '').trim();
      if (creatorId.isNotEmpty && creatorId != currentUserId.trim()) {
        recipientIds.add(creatorId);
      }
      if (recipientIds.isEmpty) {
        return;
      }
      final trimmed = messageText.trim();
      final preview = trimmed.isEmpty
          ? (hasImage ? 'sent a photo' : 'sent a message')
          : trimmed;
      final createdAt = DateTime.now();
      for (final userId in recipientIds) {
        final note = AppNotification(
          id: 'event_chat_${event.id}_${userId}_${createdAt.microsecondsSinceEpoch}',
          userId: userId,
          type: AppNotificationType.chatMessage,
          title: 'New event message',
          message: '$senderName in ${event.title}: $preview',
          createdAt: createdAt,
          targetEventId: event.id,
        );
        await notificationRepository().upsertMany(userId, [note]);
      }
    } catch (_) {
      // Best-effort write; do not block message sending.
    }
  }

  Future<void> _loadChatMessages({bool silent = false}) async {
    if (!mounted) {
      return;
    }
    final args = _argsFromRoute(context);
    final eventId = (_eventOverride ?? args.event).id.trim();
    if (eventId.isEmpty) {
      return;
    }
    if (!silent) {
      setState(() {
        _isChatLoading = true;
        _chatError = null;
      });
    }
    try {
      final items = await _eventChatRepo.listForEvent(eventId);
      if (!mounted) {
        return;
      }
      setState(() {
        _chatMessages = items;
        _isChatLoading = false;
        _chatError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isChatLoading = false;
        _chatError = 'Failed to load chat.';
      });
    }
  }

  void _ensureChatRealtimeSubscription() {
    if (!mounted) {
      return;
    }
    final args = _argsFromRoute(context);
    final eventId = (_eventOverride ?? args.event).id.trim();
    if (eventId.isEmpty ||
        eventId == _chatSubscribedEventId ||
        !AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.eventMessagesCollectionId.isEmpty) {
      return;
    }
    _chatSubscribedEventId = eventId;
    _chatRealtimeSubscription?.close();
    _chatRealtimeSubscription = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.eventMessagesCollectionId}.documents',
    ]);
    _chatRealtimeSubscription?.stream.listen((event) {
      final payload = event.payload;
      final payloadEventId = payload['eventId']?.toString() ?? '';
      if (payloadEventId == _chatSubscribedEventId) {
        _loadChatMessages(silent: true);
      }
    });
  }

  Future<void> _confirmDeleteEvent(Event event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
          'Cancel this event by deleting it? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      return;
    }

    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.eventsCollectionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appwrite is not configured yet.')),
      );
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await AppwriteService.deleteDocument(
        collectionId: AppwriteConfig.eventsCollectionId,
        documentId: event.id,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop('deleted');
    } on AppwriteException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.code == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not delete: event was not found (it may already be deleted).',
            ),
          ),
        );
        Navigator.of(context).pop('already_deleted');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to delete event.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete event.')));
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _persistDetailArgs(EventDetailArgs args) {
    webSetString(
      _storageKey,
      jsonEncode({
        'eventId': args.event.id,
        'showRegisterButton': args.showRegisterButton,
        'allowCreatorActions': args.allowCreatorActions,
        'chatEnabledUntil': args.chatEnabledUntil?.toIso8601String(),
      }),
    );
  }

  EventDetailArgs? _loadStoredArgs() {
    final raw = webGetString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final eventId = decoded['eventId']?.toString() ?? '';
      if (eventId.isEmpty) return null;

      final chatEnabledUntilRaw = decoded['chatEnabledUntil']?.toString();
      final chatEnabledUntil =
          chatEnabledUntilRaw == null || chatEnabledUntilRaw.isEmpty
          ? null
          : DateTime.tryParse(chatEnabledUntilRaw);

      final showRegisterButton = decoded['showRegisterButton'] is bool
          ? decoded['showRegisterButton'] as bool
          : true;
      final allowCreatorActions = decoded['allowCreatorActions'] is bool
          ? decoded['allowCreatorActions'] as bool
          : true;

      return EventDetailArgs(
        event: Event(
          id: eventId,
          title: 'Event',
          sport: 'Sport',
          startAt: DateTime.now(),
          duration: const Duration(hours: 1),
          location: 'Location',
          joined: 0,
          capacity: 0,
          skillLevel: '—',
          entryFeeLabel: '—',
          description: '',
          joinedByMe: false,
          creatorId: null,
          thumbnailFileId: null,
        ),
        showRegisterButton: showRegisterButton,
        allowCreatorActions: allowCreatorActions,
        chatEnabledUntil: chatEnabledUntil,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshEvent({required String eventId}) async {
    try {
      final events = await eventRepository().listEvents();
      final updated = events.where((e) => e.id == eventId).isNotEmpty
          ? events.firstWhere((e) => e.id == eventId)
          : null;
      if (updated != null && mounted) {
        setState(() {
          _eventOverride = updated;
          _activeEventId = updated.id;
          _isRegisteredByMe = updated.joinedByMe;
          _isAttendedByMe = false;
          _joinedCount = updated.joined;
          _participants = _participantsFromProfiles(
            _buildParticipantProfilesFromEvent(updated),
          );
        });
        _reloadRegistrationState(updated);
      }
    } catch (_) {
      // If refresh fails, keep showing the existing event.
    }
  }

  void _syncLocalEventState(Event event) {
    if (_activeEventId == event.id &&
        _isRegisteredByMe != null &&
        _joinedCount != null &&
        _participants != null) {
      return;
    }
    _activeEventId = event.id;
    _isRegisteredByMe = event.joinedByMe;
    _isAttendedByMe = false;
    _joinedCount = event.joined;
    _participants = _participantsFromProfiles(
      _buildParticipantProfilesFromEvent(event),
    );
    _reloadRegistrationState(event);
  }

  List<String> _resolveParticipantIds(Event event) {
    final ids = _participants != null && _participants!.isNotEmpty
        ? _participants!.map((p) => p.userId).toList()
        : [...event.participantIds];
    if (event.joinedByMe && !ids.contains(currentUserId)) {
      ids.insert(0, currentUserId);
    }
    return ids;
  }

  List<UserProfile> _buildParticipantProfilesFromEvent(Event event) {
    final ids = _resolveParticipantIds(event);
    if (ids.isEmpty) {
      return const [];
    }
    return ids.map((id) => UserProfile.empty(id)).toList();
  }

  List<_ParticipantItem> _participantsFromProfiles(
    List<UserProfile> profiles, {
    Set<String> attendedUserIds = const <String>{},
    Set<String> hostVerifiedUserIds = const <String>{},
  }) {
    final palette = <Color>[
      const Color(0xFF1AA57A),
      const Color(0xFF4A90E2),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFEF5350),
      const Color(0xFF26A69A),
      const Color(0xFF5C6BC0),
    ];
    final items = <_ParticipantItem>[];
    for (var i = 0; i < profiles.length; i++) {
      final profile = profiles[i];
      final username = profile.username.trim().isNotEmpty
          ? profile.username.trim()
          : 'user';
      items.add(
        _ParticipantItem(
          userId: profile.userId,
          username: username,
          color: palette[i % palette.length],
          avatarFileId: profile.avatarFileId,
          isAttended: attendedUserIds.contains(profile.userId),
          isHostVerified: hostVerifiedUserIds.contains(profile.userId),
        ),
      );
    }
    return items;
  }

  List<_ParticipantItem> _participantsFromUserIds(
    List<String> userIds, {
    Set<String> attendedUserIds = const <String>{},
    Set<String> hostVerifiedUserIds = const <String>{},
  }) {
    final fallbackProfiles = userIds
        .where((id) => id.trim().isNotEmpty)
        .map((id) => UserProfile.empty(id.trim()))
        .toList();
    return _participantsFromProfiles(
      fallbackProfiles,
      attendedUserIds: attendedUserIds,
      hostVerifiedUserIds: hostVerifiedUserIds,
    );
  }

  List<_ParticipantItem> _participantsWithProfileFallback({
    required List<String> userIds,
    required List<UserProfile> profiles,
    Set<String> attendedUserIds = const <String>{},
    Set<String> hostVerifiedUserIds = const <String>{},
  }) {
    final byId = <String, UserProfile>{
      for (final p in profiles)
        if (p.userId.trim().isNotEmpty) p.userId.trim(): p,
    };
    final resolved = <UserProfile>[];
    for (final id in userIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      resolved.add(byId[trimmed] ?? UserProfile.empty(trimmed));
    }
    return _participantsFromProfiles(
      resolved,
      attendedUserIds: attendedUserIds,
      hostVerifiedUserIds: hostVerifiedUserIds,
    );
  }

  Future<void> _loadParticipantsFromProfiles(Event event) async {
    final ids = _resolveParticipantIds(event);
    if (ids.isEmpty) {
      if (mounted) {
        setState(() {
          _participants = const [];
        });
      }
      return;
    }

    try {
      final profiles = await profileRepository().getProfilesByIds(ids);
      Set<String> attendedIds = <String>{};
      Set<String> hostVerifiedIds = <String>{};
      try {
        final attendance = await AttendanceService.getAttendanceList(event.id);
        attendedIds = attendance.map((a) => a.userId).toSet();
        final hostId = (event.creatorId ?? '').trim();
        hostVerifiedIds = attendance
            .where((a) => (a.scannerUserId ?? '').trim() == hostId)
            .map((a) => a.userId)
            .toSet();
      } catch (_) {
        // Attendance is optional for participant visibility.
      }
      if (!mounted || _activeEventId != event.id) {
        return;
      }
      setState(() {
        _participants = _participantsWithProfileFallback(
          userIds: ids,
          profiles: profiles,
          attendedUserIds: attendedIds,
          hostVerifiedUserIds: hostVerifiedIds,
        );
      });
    } catch (_) {
      if (!mounted || _activeEventId != event.id) {
        return;
      }
      setState(() {
        _participants = _participantsFromUserIds(ids);
      });
    }
  }

  Future<void> _reloadRegistrationState(Event event) async {
    try {
      final repo = eventRegistrationRepository();
      final ids = await repo.listParticipantUserIds(event.id);
      Set<String> attendedIds = <String>{};
      Set<String> hostVerifiedIds = <String>{};
      try {
        final attendance = await AttendanceService.getAttendanceList(event.id);
        attendedIds = attendance.map((a) => a.userId).toSet();
        final hostId = (event.creatorId ?? '').trim();
        hostVerifiedIds = attendance
            .where((a) => (a.scannerUserId ?? '').trim() == hostId)
            .map((a) => a.userId)
            .toSet();
      } catch (_) {
        // Attendance is optional for participant visibility.
      }
      if (!mounted || _activeEventId != event.id) {
        return;
      }
      final isRegistered = ids.contains(currentUserId);
      final count = ids.length;

      List<_ParticipantItem> items;
      if (ids.isEmpty) {
        items = const [];
      } else {
        try {
          final profiles = await profileRepository().getProfilesByIds(ids);
          if (!mounted || _activeEventId != event.id) {
            return;
          }
          items = _participantsWithProfileFallback(
            userIds: ids,
            profiles: profiles,
            attendedUserIds: attendedIds,
            hostVerifiedUserIds: hostVerifiedIds,
          );
        } catch (_) {
          items = _participantsFromUserIds(
            ids,
            attendedUserIds: attendedIds,
            hostVerifiedUserIds: hostVerifiedIds,
          );
        }
      }

      if (!mounted || _activeEventId != event.id) {
        return;
      }
      setState(() {
        _isRegisteredByMe = isRegistered;
        _isAttendedByMe = attendedIds.contains(currentUserId);
        _joinedCount = count;
        _participants = items;
        _eventOverride = (_eventOverride ?? event).copyWith(
          joined: count,
          joinedByMe: isRegistered,
          participantIds: ids,
        );
      });
    } catch (_) {
      // Keep fallback state if loading registrations fails.
    }
  }

  Future<void> _toggleRegistration(Event event) async {
    final currentRegistered = _isRegisteredByMe ?? event.joinedByMe;
    final currentJoined = _joinedCount ?? event.joined;
    final maxCapacity = event.capacity > 0 ? event.capacity : 999999;
    final currentParticipantIds = [..._resolveParticipantIds(event)];
    final eventEnded = _hasEventEnded(event);

    if (!currentRegistered && eventEnded) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('This event has ended.')));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(currentRegistered ? 'Leave event?' : 'Join event?'),
          content: Text(
            currentRegistered
                ? 'Are you sure you want to cancel your registration?'
                : 'Are you sure you want to join this event?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    if (!currentRegistered) {
      if (EventPrivacy.isPrivateish(event.privacy)) {
        final isInvited = event.invitedUserIds.contains(currentUserId);
        if (!isInvited) {
          final membership = await membershipRepository().getStatus();
          if (!mounted) {
            return;
          }
          if (!membership.isPremium) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Only members or invited users can join private events.',
                ),
              ),
            );
            return;
          }
        }
      }

      final canAccessPrivate = _canAccessPrivateEvent(event);
      if (!canAccessPrivate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This is a private event. Only invited users can register.',
              ),
            ),
          );
        }
        return;
      }
      final allowed = await _canRegisterForEvent(event);
      if (!mounted) {
        return;
      }
      if (!allowed) {
        return;
      }
    }

    if (!currentRegistered && currentJoined >= maxCapacity) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event is full.')));
      return;
    }

    setState(() {
      if (currentRegistered) {
        _isRegisteredByMe = false;
        _joinedCount = (currentJoined - 1).clamp(0, maxCapacity);
        currentParticipantIds.removeWhere((id) => id == currentUserId);
      } else {
        _isRegisteredByMe = true;
        _joinedCount = (currentJoined + 1).clamp(0, maxCapacity);
        if (!currentParticipantIds.contains(currentUserId)) {
          currentParticipantIds.insert(0, currentUserId);
        }
      }
      final provisionalProfiles = currentParticipantIds
          .map((id) => UserProfile.empty(id))
          .toList();
      _participants = _participantsFromProfiles(provisionalProfiles);
      _eventOverride = (_eventOverride ?? event).copyWith(
        joined: _joinedCount,
        joinedByMe: _isRegisteredByMe,
        participantIds: currentParticipantIds,
      );
    });

    final ok = await _persistRegistration(
      eventId: event.id,
      register: !currentRegistered,
    );
    if (ok) {
      _loadParticipantsFromProfiles(
        (_eventOverride ?? event).copyWith(
          participantIds: currentParticipantIds,
        ),
      );
    } else {
      if (mounted) {
        await _refreshEvent(eventId: event.id);
      }
    }

    if (!mounted || !ok) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          currentRegistered
              ? 'Registration cancelled.'
              : 'Registered successfully.',
        ),
      ),
    );
  }

  bool _canAccessPrivateEvent(Event event) {
    if (eventInviteRepository().isRequestJoinPrivate(event)) {
      return true;
    }
    final isPrivate = eventInviteRepository().isPrivate(event);
    if (!isPrivate) {
      return true;
    }
    if ((event.creatorId ?? '').trim() == currentUserId) {
      return true;
    }
    return event.invitedUserIds.contains(currentUserId);
  }

  bool _hasEventEnded(Event event) {
    final endAt = event.startAt.add(event.duration);
    return !endAt.isAfter(DateTime.now());
  }

  Future<bool> _persistRegistration({
    required String eventId,
    required bool register,
  }) async {
    final repo = eventRegistrationRepository();
    try {
      if (register) {
        await repo.register(eventId: eventId, userId: currentUserId);
      } else {
        await repo.cancel(eventId: eventId, userId: currentUserId);
      }
      final joined = await repo.getJoinedCount(eventId);
      if (AppwriteService.isConfigured &&
          AppwriteConfig.databaseId.isNotEmpty &&
          AppwriteConfig.eventsCollectionId.isNotEmpty) {
        await AppwriteService.updateDocument(
          collectionId: AppwriteConfig.eventsCollectionId,
          documentId: eventId,
          data: {'joined': joined},
        );
      }
      if (mounted && _activeEventId == eventId) {
        setState(() {
          _joinedCount = joined;
          _eventOverride = (_eventOverride)?.copyWith(joined: joined);
        });
      }
      final activeEvent = _eventOverride;
      if (activeEvent != null && activeEvent.id == eventId) {
        _reloadRegistrationState(activeEvent);
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              register
                  ? 'Register failed. Check event_registrations attributes/permissions.'
                  : 'Cancel failed. Check event_registrations permissions.',
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _canRegisterForEvent(Event event) async {
    String normalize(String? v) => (v ?? '').trim().toLowerCase();

    final requiredGender = normalize(event.gender);
    final requiredAgeGroup = normalize(event.ageGroup);
    final requiredSkillLevel = normalize(
      _normalizeSkillLevelLabel(event.skillLevel),
    );

    final requiresGender = requiredGender.isNotEmpty && requiredGender != 'any';
    final requiresAgeGroup =
        requiredAgeGroup.isNotEmpty && requiredAgeGroup != 'any';
    final requiresSkillLevel =
        requiredSkillLevel.isNotEmpty &&
        requiredSkillLevel != 'any' &&
        requiredSkillLevel != '—';

    if (!requiresGender && !requiresAgeGroup && !requiresSkillLevel) {
      return true;
    }

    UserProfile profile;
    try {
      profile = await profileRepository().getMyProfile();
    } catch (_) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load your profile. Please try again.'),
        ),
      );
      return false;
    }

    if (!mounted) {
      return false;
    }

    if (requiresGender) {
      final myGender = normalize(profile.gender);
      if (myGender.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You must set your gender in Profile to join this event.',
            ),
          ),
        );
        return false;
      }
      if (myGender != requiredGender) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This event is for ${event.gender}.')),
        );
        return false;
      }
    }

    if (requiresAgeGroup) {
      final age = profile.age;
      if (age == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You must set your age in Profile to join this event.',
            ),
          ),
        );
        return false;
      }
      final myGroup = normalize(_ageGroupFromAge(age));
      if (myGroup != requiredAgeGroup) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This event is for ${event.ageGroup}.')),
        );
        return false;
      }
    }

    if (requiresSkillLevel) {
      final mySkill = normalize(_normalizeSkillLevelLabel(profile.skillLevel));
      if (mySkill.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You must set your skill level in Profile to join this event.',
            ),
          ),
        );
        return false;
      }

      final myRank = _skillRank(mySkill);
      final requiredRank = _skillRank(requiredSkillLevel);
      if (myRank < requiredRank) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This event requires ${_titleSkill(requiredSkillLevel)} skill level.',
            ),
          ),
        );
        return false;
      }
    }

    // Host role is informational only; no restriction.
    return true;
  }

  // Gender / Age Group have restrictions; Host Role is display-only.
}

class _JoinRequestsCreatorStrip extends StatelessWidget {
  const _JoinRequestsCreatorStrip({
    required this.event,
    required this.onChanged,
  });

  final Event event;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: Material(
        color: const Color(0xFFFFF7ED),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Join requests (${event.pendingJoinRequestUserIds.length})',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<UserProfile>>(
                future: profileRepository().getProfilesByIds(
                  event.pendingJoinRequestUserIds,
                ),
                builder: (context, snap) {
                  final profiles = snap.data ?? const <UserProfile>[];
                  if (snap.connectionState != ConnectionState.done &&
                      profiles.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (profiles.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'No pending requests right now.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final p in profiles)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8E8E8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFFEDE9FE),
                                    child: Text(
                                      (p.username.trim().isNotEmpty
                                              ? p.username
                                              : p.userId)
                                          .trim()
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF6D28D9),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.username.trim().isNotEmpty
                                              ? p.username
                                              : p.userId,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          p.userId,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await eventInviteRepository()
                                            .rejectJoinRequest(
                                              eventId: event.id,
                                              userId: p.userId,
                                            );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Request declined.'),
                                            ),
                                          );
                                          onChanged();
                                        }
                                      },
                                      child: const Text('Decline'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () async {
                                        await eventInviteRepository()
                                            .approveJoinRequest(
                                              eventId: event.id,
                                              userId: p.userId,
                                            );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Player approved and added.',
                                              ),
                                            ),
                                          );
                                          onChanged();
                                        }
                                      },
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabHeader extends StatelessWidget {
  final _EventDetailTab selected;
  final ValueChanged<_EventDetailTab> onSelect;
  const _TabHeader({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabButton(
          label: 'Details',
          selected: selected == _EventDetailTab.details,
          onTap: () => onSelect(_EventDetailTab.details),
        ),
        const SizedBox(width: 14),
        _TabButton(
          label: 'Chat',
          selected: selected == _EventDetailTab.chat,
          onTap: () => onSelect(_EventDetailTab.chat),
        ),
        const SizedBox(width: 14),
        _TabButton(
          label: 'Participants',
          selected: selected == _EventDetailTab.participants,
          onTap: () => onSelect(_EventDetailTab.participants),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: selected ? Colors.black87 : Colors.black45,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: 34,
              decoration: BoxDecoration(
                color: selected ? c.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsTab extends StatefulWidget {
  final Event event;
  const _DetailsTab({super.key, required this.event});

  @override
  State<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> {
  String _hostedByLabel = '…';

  @override
  void initState() {
    super.initState();
    _resolveHostedByLabel();
  }

  @override
  void didUpdateWidget(covariant _DetailsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final o = oldWidget.event;
    final n = widget.event;
    if (o.id != n.id || o.clubId != n.clubId || o.creatorId != n.creatorId) {
      _resolveHostedByLabel();
    }
  }

  Future<void> _resolveHostedByLabel() async {
    setState(() => _hostedByLabel = '…');
    final e = widget.event;
    final clubId = e.clubId?.trim() ?? '';
    try {
      if (clubId.isNotEmpty) {
        final club = await clubRepository().getClub(clubId);
        if (!mounted) {
          return;
        }
        final name = club?.name.trim() ?? '';
        setState(() {
          _hostedByLabel = name.isNotEmpty ? name : 'Unknown club';
        });
        return;
      }
      final creatorId = e.creatorId?.trim() ?? '';
      if (creatorId.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() => _hostedByLabel = '—');
        return;
      }
      final profile = await profileRepository().getProfileById(creatorId);
      if (!mounted) {
        return;
      }
      setState(() => _hostedByLabel = _hostPersonDisplayName(profile));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _hostedByLabel = '—');
    }
  }

  Future<void> _openLocationInGoogleMaps(BuildContext context) async {
    final lat = widget.event.lat;
    final lng = widget.event.lng;
    final query = (lat != null && lng != null)
        ? '$lat,$lng'
        : Uri.encodeComponent(widget.event.location.trim());
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || ok) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Google Maps.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final privacyLabel = (() {
      final raw = event.privacy?.trim() ?? '';
      if (raw.isEmpty) {
        return 'Public';
      }
      return raw.toLowerCase().contains('private') ? 'Private' : 'Public';
    })();
    final genderLabel = (event.gender == null || event.gender!.trim().isEmpty)
        ? 'Any'
        : event.gender!.trim();
    final ageGroupLabel =
        (event.ageGroup == null || event.ageGroup!.trim().isEmpty)
        ? 'Any'
        : event.ageGroup!.trim();
    final hostRoleLabel =
        (event.hostRole == null || event.hostRole!.trim().isEmpty)
        ? 'Host only'
        : event.hostRole!.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.eventPurple,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              _InfoRow(icon: Icons.event, label: _fmtDateTime(event.startAt)),
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.schedule,
                label: _fmtDuration(event.duration),
              ),
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: event.location,
                isLink: true,
                onTap: () => _openLocationInGoogleMaps(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  title: 'SPORT',
                  value: event.sport,
                  accentBorder: AppTheme.eventPurple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  title: 'SKILL LEVEL',
                  value: _normalizeSkillLevelLabel(event.skillLevel),
                  accentBorder: Color(0xFF22C55E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  title: 'JOINED',
                  value: '${event.joined} / ${event.capacity}',
                  accentBorder: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  title: 'ENTRY FEE',
                  value: event.entryFeeLabel,
                  accentBorder: Color(0xFF14B8A6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: _MetricTile(
                  title: 'CATEGORY',
                  value: 'Casual',
                  accentBorder: Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  title: 'PRIVACY',
                  value: privacyLabel,
                  accentBorder: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  title: 'GENDER',
                  value: genderLabel,
                  accentBorder: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  title: 'AGE GROUP',
                  value: ageGroupLabel,
                  accentBorder: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE3E7EE)),
            ),
            child: Column(
              children: [
                _PolicyRow(
                  label: 'Hosted by',
                  value: _hostedByLabel,
                  valueMuted: _hostedByLabel == '…',
                ),
                const Divider(height: 1, color: Color(0xFFE3E7EE)),
                _PolicyRow(label: "Host's role", value: hostRoleLabel),
                const Divider(height: 1, color: Color(0xFFE3E7EE)),
                _PolicyRow(
                  label: 'Cancellation freeze',
                  value: event.cancellationFreeze,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Description',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

enum _ParticipantsFilter { all, attended, notAttended }

class _ParticipantsTab extends StatefulWidget {
  final List<_ParticipantItem> participants;
  final ValueChanged<String> onOpenProfile;
  const _ParticipantsTab({
    super.key,
    required this.participants,
    required this.onOpenProfile,
  });

  @override
  State<_ParticipantsTab> createState() => _ParticipantsTabState();
}

class _ParticipantsTabState extends State<_ParticipantsTab> {
  _ParticipantsFilter _filter = _ParticipantsFilter.all;

  @override
  Widget build(BuildContext context) {
    final participants = widget.participants;
    if (participants.isEmpty) {
      return const Center(child: Text('No participants yet.'));
    }

    final attendedCount = participants.where((p) => p.isAttended).length;
    final hostVerifiedCount = participants
        .where((p) => p.isAttended && p.isHostVerified)
        .length;
    final helperVerifiedCount = participants
        .where((p) => p.isAttended && !p.isHostVerified)
        .length;
    final visibleParticipants = switch (_filter) {
      _ParticipantsFilter.all => participants,
      _ParticipantsFilter.attended =>
        participants.where((p) => p.isAttended).toList(),
      _ParticipantsFilter.notAttended =>
        participants.where((p) => !p.isAttended).toList(),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 900
            ? 6
            : width >= 700
            ? 5
            : width >= 520
            ? 4
            : 3;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AttendanceSummaryChip(
                  label: 'Attended',
                  value: '$attendedCount/${participants.length}',
                  icon: Icons.check_circle_rounded,
                  tint: const Color(0xFF16A34A),
                  background: const Color(0xFFF0FDF4),
                  border: const Color(0xFF86EFAC),
                ),
                _AttendanceSummaryChip(
                  label: 'Host verified',
                  value: '$hostVerifiedCount',
                  icon: Icons.verified_rounded,
                  tint: const Color(0xFF15803D),
                  background: const Color(0xFFDCFCE7),
                  border: const Color(0xFF86EFAC),
                ),
                _AttendanceSummaryChip(
                  label: 'Helper verified',
                  value: '$helperVerifiedCount',
                  icon: Icons.groups_rounded,
                  tint: const Color(0xFF2563EB),
                  background: const Color(0xFFEFF6FF),
                  border: const Color(0xFF93C5FD),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ParticipantsFilterChip(
                  label: 'All',
                  selected: _filter == _ParticipantsFilter.all,
                  onTap: () => setState(() {
                    _filter = _ParticipantsFilter.all;
                  }),
                ),
                _ParticipantsFilterChip(
                  label: 'Attended',
                  selected: _filter == _ParticipantsFilter.attended,
                  onTap: () => setState(() {
                    _filter = _ParticipantsFilter.attended;
                  }),
                ),
                _ParticipantsFilterChip(
                  label: 'Not attended',
                  selected: _filter == _ParticipantsFilter.notAttended,
                  onTap: () => setState(() {
                    _filter = _ParticipantsFilter.notAttended;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: visibleParticipants.length,
              itemBuilder: (context, index) {
                final p = visibleParticipants[index];
                final initial = p.username.isNotEmpty
                    ? p.username[0].toUpperCase()
                    : '?';
                return Align(
                  alignment: Alignment.topCenter,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => widget.onOpenProfile(p.userId),
                    child: SizedBox(
                      width: 86,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: p.color.withValues(alpha: 0.2),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child:
                                    (p.avatarFileId != null &&
                                        p.avatarFileId!.isNotEmpty)
                                    ? FutureBuilder<Uint8List>(
                                        future:
                                            AppwriteService.getFileViewBytes(
                                              bucketId: AppwriteConfig
                                                  .profileImagesBucketId,
                                              fileId: p.avatarFileId!,
                                            ),
                                        builder: (context, snap) {
                                          if (snap.connectionState ==
                                                  ConnectionState.done &&
                                              snap.data != null &&
                                              snap.data!.isNotEmpty) {
                                            return Image.memory(
                                              snap.data!,
                                              fit: BoxFit.cover,
                                            );
                                          }
                                          return Center(
                                            child: Text(
                                              initial,
                                              style: TextStyle(
                                                color: p.color,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 20,
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Center(
                                        child: Text(
                                          initial,
                                          style: TextStyle(
                                            color: p.color,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                              ),
                              if (p.isAttended)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (p.isAttended) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: p.isHostVerified
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: p.isHostVerified
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFF60A5FA),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    p.isHostVerified
                                        ? Icons.verified_rounded
                                        : Icons.groups_rounded,
                                    size: 12,
                                    color: p.isHostVerified
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      p.isHostVerified
                                          ? 'Host verified'
                                          : 'Helper verified',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: p.isHostVerified
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _AttendanceSummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final Color background;
  final Color border;

  const _AttendanceSummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tint,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParticipantsFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ParticipantsFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.primary.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? c.primary.withValues(alpha: 0.45)
                : c.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? c.primary : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool valueMuted;
  const _PolicyRow({
    required this.label,
    required this.value,
    this.valueMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: valueMuted
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTab extends StatelessWidget {
  static const Duration _editWindow = Duration(minutes: 30);
  final String eventTitle;
  final bool isLoading;
  final String? errorMessage;
  final List<EventChatMessage> messages;
  const _ChatTab({
    super.key,
    required this.eventTitle,
    required this.isLoading,
    required this.errorMessage,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }
    if (messages.isEmpty) {
      return const Center(child: Text('No messages yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      itemCount: messages.length,
      itemBuilder: (context, idx) {
        final m = messages[idx];
        final isMe = m.senderId.trim() == currentUserId;
        final bubble = _MessageBubble(
          text: m.text,
          imageFileId: m.imageFileId,
          sentAt: m.editedAt ?? m.createdAt,
          isEdited: m.editedAt != null,
          isMe: isMe,
        );

        final showDateHeader =
            idx == 0 || !_isSameDate(messages[idx - 1].createdAt, m.createdAt);

        return Padding(
          padding: EdgeInsets.only(bottom: idx == messages.length - 1 ? 0 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDateHeader) ...[
                _DateSeparator(date: m.createdAt),
                const SizedBox(height: 10),
              ],
              Row(
                mainAxisAlignment: isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: GestureDetector(
                      onLongPress: isMe
                          ? (_canEditMessage(m)
                                ? () => _showEditDialog(
                                    context: context,
                                    messageId: m.id,
                                    currentText: m.text,
                                    createdAt: m.createdAt,
                                  )
                                : () => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Messages can only be edited within 30 minutes.',
                                      ),
                                    ),
                                  ))
                          : null,
                      child: bubble,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  bool _canEditMessage(EventChatMessage message) {
    final createdAtUtc = message.createdAt.toUtc();
    final deadline = createdAtUtc.add(_editWindow);
    return DateTime.now().toUtc().isBefore(deadline);
  }

  Future<void> _showEditDialog({
    required BuildContext context,
    required String messageId,
    required String currentText,
    required DateTime createdAt,
  }) async {
    final deadline = createdAt.toUtc().add(_editWindow);
    if (DateTime.now().toUtc().isAfter(deadline)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Messages can only be edited within 30 minutes.'),
        ),
      );
      return;
    }
    final controller = TextEditingController(text: currentText.trim());
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
    final trimmed = newText?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == currentText.trim()) {
      return;
    }
    if (DateTime.now().toUtc().isAfter(deadline)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Edit window expired while editing this message.'),
        ),
      );
      return;
    }
    try {
      await eventChatRepository().editMessage(
        messageId: messageId,
        newText: trimmed,
      );
      if (!context.mounted) {
        return;
      }
      final state = context.findAncestorStateOfType<_EventDetailScreenState>();
      await state?._loadChatMessages(silent: true);
    } on AppwriteException catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to edit message.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to edit message.')));
    }
  }
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

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.primary.withValues(alpha: 0.35)),
        ),
        child: Text(
          _dateSeparatorLabel(date),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String? imageFileId;
  final DateTime sentAt;
  final bool isEdited;
  final bool isMe;
  const _MessageBubble({
    required this.text,
    this.imageFileId,
    required this.sentAt,
    this.isEdited = false,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final bg = isMe ? c.primary.withValues(alpha: 0.12) : Colors.white;
    final border = isMe
        ? c.primary.withValues(alpha: 0.25)
        : const Color(0xFFE3E7EE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageFileId != null && imageFileId!.trim().isNotEmpty)
            _EventChatImage(fileId: imageFileId!),
          if (imageFileId != null &&
              imageFileId!.trim().isNotEmpty &&
              text.trim().isNotEmpty)
            const SizedBox(height: 8),
          if (text.trim().isNotEmpty)
            Text(
              text,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.85),
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
                _formatMessageTime(sentAt),
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
    );
  }
}

String _formatMessageTime(DateTime dt) {
  final t = dt.toLocal();
  final hour12 = ((t.hour + 11) % 12) + 1;
  final minute = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $ampm';
}

class _EventChatImage extends StatelessWidget {
  final String fileId;

  const _EventChatImage({required this.fileId});

  @override
  Widget build(BuildContext context) {
    Future<void> downloadImage() async {
      try {
        final uri = AppwriteService.getFileDownloadUri(
          bucketId: AppwriteConfig.storageBucketId,
          fileId: fileId,
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    void openPreview(Uint8List bytes) {
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLink;
  final VoidCallback? onTap;
  const _InfoRow({
    required this.icon,
    required this.label,
    this.isLink = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isLink ? Theme.of(context).colorScheme.primary : null,
              decoration: isLink
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        ),
        if (isLink) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.open_in_new,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final Color accentBorder;
  const _MetricTile({
    required this.title,
    required this.value,
    this.accentBorder = const Color(0xFF94A3B8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black45,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _HeroStatusBadge extends StatelessWidget {
  final bool isFull;
  const _HeroStatusBadge({required this.isFull});

  @override
  Widget build(BuildContext context) {
    final label = isFull ? 'Full' : 'Open';
    final fg = isFull ? const Color(0xFFEA580C) : AppTheme.eventPurple;
    final bg = isFull ? const Color(0xFFFFF7ED) : AppTheme.eventPurpleLightBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 13),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE3E7EE)),
        ),
        child: Icon(icon),
      ),
    );
  }
}

/// Prefer real name when set; otherwise username (skips placeholder defaults).
String _hostPersonDisplayName(UserProfile profile) {
  final rn = profile.realName.trim();
  final un = profile.username.trim();
  final hasReal = rn.isNotEmpty && rn != 'Name';
  final hasUser = un.isNotEmpty && un != 'Username';
  if (hasReal) {
    return rn;
  }
  if (hasUser) {
    return un;
  }
  if (rn.isNotEmpty) {
    return rn;
  }
  if (un.isNotEmpty) {
    return un;
  }
  return 'Host';
}

String _fmtDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  final month = two(dt.month);
  final day = two(dt.day);
  final year = dt.year;
  final h = dt.hour;
  final hour12 = ((h + 11) % 12) + 1;
  final ampm = h >= 12 ? 'PM' : 'AM';
  final min = two(dt.minute);
  return '$month/$day/$year, $hour12:$min $ampm';
}

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0 && m > 0) return '$h Hours $m Min';
  if (h > 0) return '$h Hours';
  return '$m Min';
}

String _ageGroupFromAge(int age) {
  if (age < 18) {
    return 'Junior (<18)';
  }
  if (age <= 59) {
    return 'Adult (19 - 59)';
  }
  return 'Senior (60+)';
}

String _normalizeSkillLevelLabel(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text == '—') {
    return 'Any';
  }

  const options = [
    'Any',
    'Beginner',
    'Novice',
    'Intermediate',
    'Advanced',
    'Pro/Master',
  ];
  for (final option in options) {
    if (text.toLowerCase() == option.toLowerCase()) {
      return option;
    }
  }
  if (text.toLowerCase() == 'novice intermediate') {
    return 'Intermediate';
  }

  final matches = RegExp(r'\d+')
      .allMatches(text)
      .map((m) => int.tryParse(m.group(0)!))
      .whereType<int>()
      .toList();
  if (matches.isNotEmpty) {
    final score = matches.last;
    if (score <= 2) return 'Beginner';
    if (score <= 4) return 'Novice';
    if (score <= 6) return 'Intermediate';
    if (score <= 8) return 'Advanced';
    return 'Pro/Master';
  }

  return text;
}

int _skillRank(String normalizedLower) {
  switch (normalizedLower) {
    case 'beginner':
      return 1;
    case 'novice':
      return 2;
    case 'intermediate':
      return 3;
    case 'advanced':
      return 4;
    case 'pro/master':
      return 5;
  }
  return 0;
}

String _titleSkill(String normalizedLower) {
  switch (normalizedLower) {
    case 'beginner':
      return 'Beginner';
    case 'novice':
      return 'Novice';
    case 'intermediate':
      return 'Intermediate';
    case 'advanced':
      return 'Advanced';
    case 'pro/master':
      return 'Pro/Master';
  }
  return normalizedLower;
}
