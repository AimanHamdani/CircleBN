import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../utils/web_storage.dart';
import '../../../data/event_repository.dart';
import '../../../data/event_registration_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/event.dart';
import '../../../models/user_profile.dart';
import 'create_event_screen.dart';
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

  const _ParticipantItem({
    required this.userId,
    required this.username,
    required this.color,
    this.avatarFileId,
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
  bool _isDeleting = false;
  Event? _eventOverride;
  EventDetailArgs? _argsOverride;
  String? _activeEventId;
  bool? _isRegisteredByMe;
  int? _joinedCount;
  List<_ParticipantItem>? _participants;

  bool _didTryReloadAfterRefresh = false;
  bool _didTryInitialRouteRefresh = false;

  static const String _storageKey = 'circlebn_last_event_detail';

  @override
  void dispose() {
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
      final initialId = (args is EventDetailArgs ? args.event.id : (args is Event ? args.id : null));
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
    final canSendChat = args.chatEnabledUntil == null || DateTime.now().isBefore(args.chatEnabledUntil!);
    final messages = _sampleMessagesFor(e.id);
    final isRegisteredByMe = _isRegisteredByMe ?? e.joinedByMe;
    final joinedCount = (_joinedCount ?? e.joined).clamp(0, e.capacity > 0 ? e.capacity : 999999);
    final participants = _participants ?? _participantsFromProfiles(_buildParticipantProfilesFromEvent(e));

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
                        colors: [
                          Color(0xFFEDE9FE),
                          Color(0xFFF5F3FF),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    child: e.thumbnailFileId != null && e.thumbnailFileId!.isNotEmpty
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
                              return Icon(Icons.image_outlined, color: Colors.black.withValues(alpha: 0.35), size: 56);
                            },
                          )
                        : Icon(Icons.image_outlined, color: Colors.black.withValues(alpha: 0.35), size: 56),
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
                        if (e.creatorId != null && e.creatorId == currentUserId && args.allowCreatorActions) ...[
                          const SizedBox(width: 8),
                          _RoundIconButton(
                            icon: Icons.edit_outlined,
                            onTap: () => _onEditEvent(e),
                          ),
                          const SizedBox(width: 8),
                          _RoundIconButton(
                            icon: _isDeleting ? Icons.hourglass_top : Icons.delete_outline,
                            onTap: _isDeleting ? () {} : () => _confirmDeleteEvent(e),
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
                onSelect: (t) => setState(() => _tab = t),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _tab == _EventDetailTab.details
                    ? _DetailsTab(
                        key: const ValueKey('details'),
                        event: e.copyWith(
                          joined: joinedCount,
                          joinedByMe: isRegisteredByMe,
                        ),
                      )
                    : _tab == _EventDetailTab.chat
                        ? _ChatTab(
                        key: const ValueKey('chat'),
                        eventTitle: e.title,
                        messages: messages,
                      )
                        : _ParticipantsTab(
                            key: const ValueKey('participants'),
                            participants: participants,
                          ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _tab == _EventDetailTab.details
          ? ((args.showRegisterButton && (e.creatorId == null || e.creatorId != currentUserId))
              ? _registerBar(
                  context,
                  isRegistered: isRegisteredByMe,
                  joinedCount: joinedCount,
                  capacity: e.capacity,
                  onTap: () => _toggleRegistration(e),
                )
              : null)
          : (_tab == _EventDetailTab.chat ? _chatComposerBar(context, canSendChat: canSendChat) : null),
      ),
    );
  }

  Widget _registerBar(
    BuildContext context, {
    required bool isRegistered,
    required int joinedCount,
    required int capacity,
    required VoidCallback onTap,
  }) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isFull = capacity > 0 && joinedCount >= capacity;
    final label = isRegistered ? 'Cancel Registration' : (isFull ? 'Event Full' : 'Register');
    final counterText = capacity > 0 ? '$joinedCount / $capacity joined' : '$joinedCount joined';
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
            FilledButton(
              onPressed: (!isRegistered && isFull) ? null : onTap,
              style: FilledButton.styleFrom(
                backgroundColor: isRegistered ? Colors.white : AppTheme.eventPurple,
                foregroundColor: isRegistered ? Colors.black87 : Colors.white,
                side: isRegistered ? const BorderSide(color: Color(0xFFE3E7EE)) : null,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onEditEvent(Event event) async {
    final result = await Navigator.of(context).pushNamed(
      CreateEventScreen.routeName,
      arguments: event,
    );

    if (!mounted) {
      return;
    }

    if (result == 'updated' || result == 'created' || result == true) {
      await _refreshEvent(eventId: event.id);
    }
  }

  Widget _chatComposerBar(BuildContext context, {required bool canSendChat}) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottomInset),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _composerCtrl,
                enabled: canSendChat,
                decoration: const InputDecoration(
                  hintText: 'Message (mock)',
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: canSendChat ? (_) => _sendMock() : (_) {},
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: canSendChat ? _sendMock : null,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.send, color: canSendChat ? Colors.white : Colors.white.withValues(alpha: 0.45)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMock() {
    final args = _argsFromRoute(context);
    final canSendChat = args.chatEnabledUntil == null || DateTime.now().isBefore(args.chatEnabledUntil!);
    if (!canSendChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messaging is locked for this event.')),
      );
      return;
    }
    final txt = _composerCtrl.text.trim();
    _composerCtrl.clear();
    if (txt.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message sent (mock). Not stored yet.')),
    );
  }

  Future<void> _confirmDeleteEvent(Event event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Cancel this event by deleting it? This cannot be undone.'),
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
          const SnackBar(content: Text('Could not delete: event was not found (it may already be deleted).')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete event.')),
      );
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
      final chatEnabledUntil = chatEnabledUntilRaw == null || chatEnabledUntilRaw.isEmpty
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
    if (_activeEventId == event.id && _isRegisteredByMe != null && _joinedCount != null && _participants != null) {
      return;
    }
    _activeEventId = event.id;
    _isRegisteredByMe = event.joinedByMe;
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

  List<_ParticipantItem> _participantsFromProfiles(List<UserProfile> profiles) {
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
      final username = profile.username.trim().isNotEmpty ? profile.username.trim() : 'user';
      items.add(
        _ParticipantItem(
          userId: profile.userId,
          username: username,
          color: palette[i % palette.length],
          avatarFileId: profile.avatarFileId,
        ),
      );
    }
    return items;
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
      if (!mounted || _activeEventId != event.id) {
        return;
      }
      setState(() {
        _participants = _participantsFromProfiles(profiles);
      });
    } catch (_) {
      // Keep fallback participants if profile fetch fails.
    }
  }

  Future<void> _reloadRegistrationState(Event event) async {
    try {
      final repo = eventRegistrationRepository();
      final ids = await repo.listParticipantUserIds(event.id);
      if (!mounted || _activeEventId != event.id) {
        return;
      }
      final isRegistered = ids.contains(currentUserId);
      final count = ids.length;

      List<_ParticipantItem> items;
      if (ids.isEmpty) {
        items = const [];
      } else {
        final profiles = await profileRepository().getProfilesByIds(ids);
        if (!mounted || _activeEventId != event.id) {
          return;
        }
        items = _participantsFromProfiles(profiles);
      }

      if (!mounted || _activeEventId != event.id) {
        return;
      }
      setState(() {
        _isRegisteredByMe = isRegistered;
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

    if (!currentRegistered) {
      final allowed = await _canRegisterForEvent(event);
      if (!allowed) {
        return;
      }
    }

    if (!currentRegistered && currentJoined >= maxCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event is full.')),
      );
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
      final provisionalProfiles = currentParticipantIds.map((id) => UserProfile.empty(id)).toList();
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

    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentRegistered ? 'Registration cancelled.' : 'Registered successfully.'),
        ),
      );
    }
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
          data: {
            'joined': joined,
          },
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
    final requiredSkillLevel = normalize(_normalizeSkillLevelLabel(event.skillLevel));

    final requiresGender = requiredGender.isNotEmpty && requiredGender != 'any';
    final requiresAgeGroup = requiredAgeGroup.isNotEmpty && requiredAgeGroup != 'any';
    final requiresSkillLevel = requiredSkillLevel.isNotEmpty &&
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
        const SnackBar(content: Text('Could not load your profile. Please try again.')),
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
          const SnackBar(content: Text('You must set your gender in Profile to join this event.')),
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
          const SnackBar(content: Text('You must set your age in Profile to join this event.')),
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
          const SnackBar(content: Text('You must set your skill level in Profile to join this event.')),
        );
        return false;
      }

      final myRank = _skillRank(mySkill);
      final requiredRank = _skillRank(requiredSkillLevel);
      if (myRank < requiredRank) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This event requires ${_titleSkill(requiredSkillLevel)} skill level.')),
        );
        return false;
      }
    }

    // Host role is informational only; no restriction.
    return true;
  }

  // Gender / Age Group have restrictions; Host Role is display-only.
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
  const _TabButton({required this.label, required this.selected, required this.onTap});

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

class _DetailsTab extends StatelessWidget {
  final Event event;
  const _DetailsTab({super.key, required this.event});

  Future<void> _openLocationInGoogleMaps(BuildContext context) async {
    final lat = event.lat;
    final lng = event.lng;
    final query = (lat != null && lng != null) ? '$lat,$lng' : Uri.encodeComponent(event.location.trim());
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
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
    final genderLabel = (event.gender == null || event.gender!.trim().isEmpty) ? 'Any' : event.gender!.trim();
    final ageGroupLabel = (event.ageGroup == null || event.ageGroup!.trim().isEmpty) ? 'Any' : event.ageGroup!.trim();
    final hostRoleLabel = (event.hostRole == null || event.hostRole!.trim().isEmpty) ? 'Host only' : event.hostRole!.trim();
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
              _InfoRow(icon: Icons.schedule, label: _fmtDuration(event.duration)),
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
              const Expanded(
                child: _MetricTile(
                  title: 'PRIVACY',
                  value: 'Public',
                  accentBorder: Color(0xFF94A3B8),
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
                _PolicyRow(label: "Host's role", value: hostRoleLabel),
                const Divider(height: 1, color: Color(0xFFE3E7EE)),
                _PolicyRow(label: 'Cancellation freeze', value: event.cancellationFreeze),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(event.description, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _ParticipantsTab extends StatelessWidget {
  final List<_ParticipantItem> participants;
  const _ParticipantsTab({super.key, required this.participants});

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Center(
        child: Text('No participants yet.'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final p = participants[index];
        final initial = p.username.isNotEmpty ? p.username[0].toUpperCase() : '?';
        return Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.color.withValues(alpha: 0.2),
              ),
              clipBehavior: Clip.antiAlias,
              child: (p.avatarFileId != null && p.avatarFileId!.isNotEmpty)
                  ? FutureBuilder<Uint8List>(
                      future: AppwriteService.getFileViewBytes(
                        bucketId: AppwriteConfig.profileImagesBucketId,
                        fileId: p.avatarFileId!,
                      ),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.done &&
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
          ],
        );
      },
    );
  }
}

class _PolicyRow extends StatelessWidget {
  final String label;
  final String value;
  const _PolicyRow({required this.label, required this.value});

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
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTab extends StatelessWidget {
  final String eventTitle;
  final List<_ChatMessage> messages;
  const _ChatTab({super.key, required this.eventTitle, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text('No messages yet (mock).'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final m = messages[idx];
        final bubble = _MessageBubble(
          text: m.text,
          isMe: m.isMe,
        );

        return Row(
          mainAxisAlignment: m.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: bubble,
            ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  const _MessageBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final bg = isMe ? c.primary.withValues(alpha: 0.12) : Colors.white;
    final border = isMe ? c.primary.withValues(alpha: 0.25) : const Color(0xFFE3E7EE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
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
              decoration: isLink ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
        if (isLink) ...[
          const SizedBox(width: 8),
          Icon(Icons.open_in_new, size: 16, color: Theme.of(context).colorScheme.primary),
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
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w800)),
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

class _ChatMessage {
  final bool isMe;
  final String text;
  const _ChatMessage({required this.isMe, required this.text});
}

List<_ChatMessage> _sampleMessagesFor(String eventId) {
  final map = <String, List<_ChatMessage>>{
    'lets_go_volley': const [
      _ChatMessage(isMe: false, text: 'Hi everyone! Court is confirmed.'),
      _ChatMessage(isMe: true, text: 'Nice, what time should we arrive?'),
      _ChatMessage(isMe: false, text: 'Try to be there 15 mins earlier for warm-up.'),
    ],
    'badminton_meet': const [
      _ChatMessage(isMe: false, text: 'Hi! Please bring a dark shirt if possible.'),
      _ChatMessage(isMe: true, text: 'Got it. Are shuttlecocks provided?'),
      _ChatMessage(isMe: false, text: 'Yes, we will bring them.'),
    ],
    'fun_run': const [
      _ChatMessage(isMe: false, text: 'Welcome! Route will be shared soon.'),
      _ChatMessage(isMe: true, text: 'Thanks! Looking forward to it.'),
    ],
  };
  return map[eventId] ?? const [];
}

