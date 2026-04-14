import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../data/club_member_repository.dart';
import '../../../data/club_repository.dart';
import '../../../data/event_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/club.dart';
import '../../../models/event.dart';
import '../../../models/user_profile.dart';
import '../profile/user_profile_view_screen.dart';
import 'create_club_screen.dart';
import 'clubs_screen.dart';
import 'event_detail_screen.dart';

String _promoteMemberErrorMessage(Object e) {
  if (e is AppwriteException) {
    final msg = (e.message ?? '').trim();
    if (msg.isEmpty) {
      return 'Could not run promote function. If Appwrite shows no execution, the request failed before it was queued (wrong function ID, permissions, or network).';
    }
    final lower = msg.toLowerCase();
    if (e.code == 404 ||
        lower.contains('function with the requested id could not be found')) {
      return 'Wrong function ID: copy the Function \$id from Appwrite and set '
          'APPWRITE_PROMOTE_CLUB_ADMIN_FUNCTION_ID (the default name is not always the real ID).';
    }
    if (e.code == 401 || e.code == 403) {
      return 'Not allowed to execute this function. In Appwrite open the function → Settings → '
          'Execution permissions, and allow your users (e.g. any user / role) to execute it.';
    }
    return msg;
  }
  final s = e.toString();
  if (s.startsWith('Exception: ')) {
    return s.substring('Exception: '.length);
  }
  return s;
}

/// Club profile / info page (opened from chat app bar).
class ClubInfoScreen extends StatefulWidget {
  static const routeName = '/club-info';

  const ClubInfoScreen({super.key});

  @override
  State<ClubInfoScreen> createState() => _ClubInfoScreenState();
}

class _ClubInfoPayload {
  final Club club;
  final List<Event> upcomingEvents;
  final int allClubEventsCount;
  final List<_ClubMemberItem> members;
  final int membersCount;
  final int adminsCount;
  final bool isCurrentUserMember;
  final bool isCurrentUserAdmin;
  final bool isCurrentUserCreator;
  final String? creatorLabel;

  const _ClubInfoPayload({
    required this.club,
    required this.upcomingEvents,
    required this.allClubEventsCount,
    required this.members,
    required this.membersCount,
    required this.adminsCount,
    required this.isCurrentUserMember,
    required this.isCurrentUserAdmin,
    required this.isCurrentUserCreator,
    required this.creatorLabel,
  });
}

class _ClubMemberItem {
  final UserProfile profile;
  final bool isAdmin;
  final bool isCreator;

  const _ClubMemberItem({
    required this.profile,
    required this.isAdmin,
    required this.isCreator,
  });
}

class _ClubInfoScreenState extends State<ClubInfoScreen> {
  Future<_ClubInfoPayload>? _payloadFuture;
  Club? _cachedClub;
  bool _isPromoting = false;

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

  Future<_ClubInfoPayload> _load({bool refreshClub = true}) async {
    final initial = _clubFromRoute(context);
    final fresh = refreshClub
        ? (await clubRepository().getClub(initial.id) ?? initial)
        : (_cachedClub ?? initial);

    if (refreshClub) {
      _cachedClub = fresh;
    }
    final events = await eventRepository().listEvents();
    final now = DateTime.now();
    final clubEvents = events
        .where((e) => e.clubId != null && e.clubId == fresh.id)
        .toList();
    final upcoming =
        clubEvents.where((e) => e.startAt.add(e.duration).isAfter(now)).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    final clubId = fresh.id;
    var members = await clubMemberRepository().listMembers(clubId: clubId);

    // Backward-compatible fallback: if the club has a creatorId but no membership docs yet,
    // treat the creator as an admin so the UI still works for old data.
    final creatorId = fresh.creatorId?.trim();
    if (creatorId != null && creatorId.isNotEmpty) {
      final hasCreator = members.any((m) => m.userId == creatorId);
      if (!hasCreator) {
        members = [
          ...members,
          ClubMember(
            clubId: clubId,
            userId: creatorId,
            role: ClubMemberRole.admin,
            joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ];
      }
    }

    final memberUserIds = members.map((m) => m.userId).toList(growable: false);
    final memberProfiles = await profileRepository().getProfilesByIds(
      memberUserIds,
    );
    final profileById = {for (final p in memberProfiles) p.userId: p};
    final creatorProfile = creatorId == null || creatorId.isEmpty
        ? null
        : profileById[creatorId];
    final creatorLabel = creatorProfile == null
        ? (creatorId == null || creatorId.isEmpty ? null : creatorId)
        : _creatorDisplayLabel(creatorProfile);

    final memberItems = members.map((m) {
      final profile = profileById[m.userId] ?? UserProfile.empty(m.userId);
      return _ClubMemberItem(
        profile: profile,
        isAdmin: m.role == ClubMemberRole.admin,
        isCreator:
            creatorId != null && creatorId.isNotEmpty && m.userId == creatorId,
      );
    }).toList();

    final isCurrentUserMember = members.any((m) => m.userId == currentUserId);
    final isCurrentUserAdmin = members.any(
      (m) => m.userId == currentUserId && m.role == ClubMemberRole.admin,
    );
    final isCurrentUserCreator =
        creatorId != null && creatorId.isNotEmpty && creatorId == currentUserId;

    return _ClubInfoPayload(
      club: fresh,
      upcomingEvents: upcoming,
      allClubEventsCount: clubEvents.length,
      members: memberItems,
      membersCount: memberItems.length,
      adminsCount: memberItems.where((m) => m.isAdmin).length,
      isCurrentUserMember: isCurrentUserMember,
      isCurrentUserAdmin: isCurrentUserAdmin,
      isCurrentUserCreator: isCurrentUserCreator,
      creatorLabel: creatorLabel,
    );
  }

  String _creatorDisplayLabel(UserProfile profile) {
    final username = profile.username.trim();
    if (username.isNotEmpty && username.toLowerCase() != 'username') {
      return '@$username';
    }
    final real = profile.realName.trim();
    if (real.isNotEmpty && real.toLowerCase() != 'name') {
      return real;
    }
    return profile.userId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _payloadFuture ??= _load(refreshClub: true);
  }

  String _primarySport(Club c) {
    if (c.sports.isEmpty) {
      return 'Sport';
    }
    final list = c.sports.toList()..sort();
    return list.first;
  }

  String _foundedLabel(Club c) {
    final d = c.foundedAt;
    if (d != null) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return 'Founded ${months[(d.month - 1).clamp(0, 11)]} ${d.year}';
    }
    return 'Founded date not set';
  }

  Future<bool> _confirmDisbandStep1(Club club) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disband club'),
        content: Text(
          'Step 1/3: Are you sure you want to disband “${club.name}”?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<bool> _confirmDisbandStep2(Club club) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disband club'),
        content: const Text(
          'Step 2/3: This will delete the club members and linked events. This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<bool> _confirmDisbandStep3(Club club) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final confirmation'),
        content: Text('Step 3/3: Confirm again to DISBAND “${club.name}”.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disband'),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<bool> _confirmLeaveClub(Club club) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave club'),
        content: Text('Are you sure you want to leave “${club.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _leaveClub(Club club) async {
    if (!await _confirmLeaveClub(club)) {
      return;
    }

    try {
      await clubMemberRepository().leaveClub(
        clubId: club.id,
        userId: currentUserId,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to leave club.')));
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _payloadFuture = _load(refreshClub: false);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Left club.')));
  }

  Future<void> _deleteEventsForClub(String clubId) async {
    if (!AppwriteService.isConfigured ||
        AppwriteConfig.eventsCollectionId.isEmpty) {
      return;
    }

    Future<void> deleteByField(String field) async {
      final docs = await AppwriteService.listDocuments(
        collectionId: AppwriteConfig.eventsCollectionId,
        queries: [Query.equal(field, clubId), Query.limit(5000)],
      );
      for (final d in docs.documents) {
        final data = Map<String, dynamic>.from(d.data);
        final thumbId =
            data['thumbnailFileId']?.toString() ??
            data['thumbnail_file_id']?.toString() ??
            data['imageUrl']?.toString() ??
            data['image_url']?.toString();
        if (thumbId != null && thumbId.isNotEmpty) {
          await AppwriteService.deleteFile(
            bucketId: AppwriteConfig.storageBucketId,
            fileId: thumbId,
          ).catchError((_) {});
        }
        await AppwriteService.deleteDocument(
          collectionId: AppwriteConfig.eventsCollectionId,
          documentId: d.$id,
        );
      }
    }

    try {
      await deleteByField('clubId');
      return;
    } catch (_) {}

    try {
      await deleteByField('club_id');
      return;
    } catch (_) {}

    // Fallback: scan and delete best-effort (may be slow if you have many events).
    try {
      final docs = await AppwriteService.listDocuments(
        collectionId: AppwriteConfig.eventsCollectionId,
        queries: [Query.limit(5000)],
      );
      for (final d in docs.documents) {
        final data = Map<String, dynamic>.from(d.data);
        final raw =
            (data['clubId'] ??
                    data['club_id'] ??
                    data['clubid'] ??
                    data['clubID'])
                ?.toString();
        if (raw == clubId) {
          final thumbId =
              data['thumbnailFileId']?.toString() ??
              data['thumbnail_file_id']?.toString() ??
              data['imageUrl']?.toString() ??
              data['image_url']?.toString();
          if (thumbId != null && thumbId.isNotEmpty) {
            await AppwriteService.deleteFile(
              bucketId: AppwriteConfig.storageBucketId,
              fileId: thumbId,
            ).catchError((_) {});
          }
          await AppwriteService.deleteDocument(
            collectionId: AppwriteConfig.eventsCollectionId,
            documentId: d.$id,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _disbandClub(Club club) async {
    if (!await _confirmDisbandStep1(club) ||
        !await _confirmDisbandStep2(club)) {
      return;
    }
    if (!await _confirmDisbandStep3(club)) {
      return;
    }

    try {
      final clubThumbId = club.thumbnailFileId?.trim();
      if (clubThumbId != null && clubThumbId.isNotEmpty) {
        await AppwriteService.deleteFile(
          bucketId: AppwriteConfig.storageBucketId,
          fileId: clubThumbId,
        ).catchError((_) {});
      }
      await clubMemberRepository().deleteMembersForClub(club.id);
      await _deleteEventsForClub(club.id);
      await AppwriteService.deleteDocument(
        collectionId: AppwriteConfig.clubsCollectionId,
        documentId: club.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to disband club: ${e.toString()}')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Club disbanded.')));
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(ClubsScreen.routeName, (_) => false);
  }

  Future<void> _openMemberActions({
    required _ClubInfoPayload payload,
    required _ClubMemberItem member,
  }) async {
    if (!payload.isCurrentUserAdmin) {
      return;
    }
    if (member.profile.userId == currentUserId) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Icon(
                  Icons.person_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text(
                  'View profile',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.of(context).pushNamed(
                    UserProfileViewScreen.routeName,
                    arguments: UserProfileViewArgs(
                      userId: member.profile.userId,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_remove_outlined,
                  color: Color(0xFFDC2626),
                ),
                title: const Text(
                  'Remove from club',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove member'),
                      content: Text(
                        'Remove ${member.profile.username} from this club?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Remove',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) {
                    return;
                  }
                  if (!mounted) {
                    return;
                  }
                  try {
                    await clubMemberRepository().leaveClub(
                      clubId: payload.club.id,
                      userId: member.profile.userId,
                    );
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _payloadFuture = _load(refreshClub: false);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Member removed from club.'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Could not remove member: ${e.toString()}',
                        ),
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  member.isAdmin
                      ? Icons.admin_panel_settings
                      : Icons.admin_panel_settings_outlined,
                  color: member.isAdmin
                      ? const Color(0xFFEA580C)
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  member.isAdmin ? 'Remove admin' : 'Make admin',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                enabled: !_isPromoting,
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final isDemote = member.isAdmin;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(isDemote ? 'Remove admin' : 'Make admin'),
                      content: Text(
                        isDemote
                            ? 'Change ${member.profile.username} back to member?'
                            : 'Promote ${member.profile.username} to admin?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(isDemote ? 'Remove admin' : 'Make admin'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) {
                    return;
                  }

                  if (!mounted) {
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() {
                    _isPromoting = true;
                  });
                  try {
                    if (isDemote) {
                      await clubMemberRepository().setRole(
                        clubId: payload.club.id,
                        userId: member.profile.userId,
                        role: ClubMemberRole.member,
                      );
                    } else {
                      await clubMemberRepository().promoteToAdminViaFunction(
                        clubId: payload.club.id,
                        targetUserId: member.profile.userId,
                      );
                    }

                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _payloadFuture = _load(refreshClub: false);
                    });
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          isDemote
                              ? 'Admin changed to member.'
                              : 'Member promoted to admin.',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) {
                      return;
                    }
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          isDemote
                              ? 'Could not remove admin: ${e.toString()}'
                              : _promoteMemberErrorMessage(e),
                        ),
                      ),
                    );
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isPromoting = false;
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      // Web / route transition: horizontal constraints can be loose briefly; Row→Expanded
      // under SingleChildScrollView then never lays out → blank screen + mouse_tracker asserts.
      body: FutureBuilder<_ClubInfoPayload>(
        future: _payloadFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Could not load club.',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.65),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _payloadFuture = _load(refreshClub: true);
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final p = snap.data!;
          final club = p.club;
          final members = p.membersCount;
          final eventsN = p.allClubEventsCount;
          final admins = p.adminsCount;
          final sport = _primarySport(club);
          final locationText = club.location.trim().isNotEmpty
              ? club.location.trim()
              : 'Location not set';
          final desc = club.description.trim().isNotEmpty
              ? club.description.trim()
              : 'No description yet.';

          return LayoutBuilder(
            builder: (context, constraints) {
              var w = constraints.maxWidth;
              if (!w.isFinite || w <= 0) {
                w = MediaQuery.sizeOf(context).width;
              }
              if (!w.isFinite || w <= 0) {
                w = 400.0;
              }
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 200,
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned.fill(child: _ClubBanner(club: club)),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 72,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Material(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          shape: const CircleBorder(),
                                          clipBehavior: Clip.antiAlias,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.arrow_back),
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).maybePop(),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Material(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          shape: const CircleBorder(),
                                          clipBehavior: Clip.antiAlias,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.more_vert),
                                            onPressed: () {
                                              final isAdmin =
                                                  p.isCurrentUserAdmin;
                                              final isCreator =
                                                  p.isCurrentUserCreator;

                                              showModalBottomSheet<void>(
                                                context: context,
                                                backgroundColor:
                                                    Colors.transparent,
                                                builder: (sheetCtx) => Container(
                                                  decoration: const BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            20,
                                                          ),
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        20,
                                                        12,
                                                        20,
                                                        24,
                                                      ),
                                                  child: SafeArea(
                                                    top: false,
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          width: 40,
                                                          height: 4,
                                                          decoration: BoxDecoration(
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.18,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  2,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 18,
                                                        ),
                                                        if (isAdmin)
                                                          ListTile(
                                                            leading: Icon(
                                                              Icons.edit,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                            ),
                                                            title: const Text(
                                                              'Edit club',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                            ),
                                                            onTap: () {
                                                              Navigator.pop(
                                                                sheetCtx,
                                                              );
                                                              Navigator.of(
                                                                context,
                                                              ).pushNamed(
                                                                CreateClubScreen
                                                                    .routeName,
                                                                arguments: club,
                                                              );
                                                            },
                                                          ),
                                                        if (isCreator)
                                                          ListTile(
                                                            leading: const Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              color: Colors.red,
                                                            ),
                                                            title: const Text(
                                                              'Disband club',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ),
                                                            onTap: () async {
                                                              Navigator.pop(
                                                                sheetCtx,
                                                              );
                                                              await _disbandClub(
                                                                club,
                                                              );
                                                            },
                                                          ),
                                                        if (!p
                                                            .isCurrentUserMember)
                                                          ListTile(
                                                            leading: const Icon(
                                                              Icons
                                                                  .group_add_rounded,
                                                            ),
                                                            title: const Text(
                                                              'Join club',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                            ),
                                                            onTap: () async {
                                                              Navigator.pop(
                                                                sheetCtx,
                                                              );

                                                              final messenger =
                                                                  ScaffoldMessenger.of(
                                                                    context,
                                                                  );
                                                              try {
                                                                await clubMemberRepository().joinAsMember(
                                                                  clubId:
                                                                      club.id,
                                                                  userId:
                                                                      currentUserId,
                                                                  role: ClubMemberRole
                                                                      .member,
                                                                );
                                                              } catch (_) {
                                                                if (!mounted)
                                                                  return;
                                                                messenger.showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                      'Failed to join club.',
                                                                    ),
                                                                  ),
                                                                );
                                                                return;
                                                              }

                                                              if (!mounted)
                                                                return;
                                                              setState(() {
                                                                _payloadFuture =
                                                                    _load(
                                                                      refreshClub:
                                                                          false,
                                                                    );
                                                              });
                                                              messenger.showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    'Joined club.',
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        if (p
                                                            .isCurrentUserMember)
                                                          ListTile(
                                                            leading: const Icon(
                                                              Icons
                                                                  .logout_rounded,
                                                              color: Colors
                                                                  .redAccent,
                                                            ),
                                                            title: const Text(
                                                              'Leave club',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color: Colors
                                                                    .redAccent,
                                                              ),
                                                            ),
                                                            onTap: () async {
                                                              Navigator.pop(
                                                                sheetCtx,
                                                              );
                                                              await _leaveClub(
                                                                club,
                                                              );
                                                            },
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                        // stretch: give each child the full content width. With .start, the header
                        // Row can see an unbounded max width → FilledButton gets w=Infinity and crashes.
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ClubInfoAvatar(club: club),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        club.name,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            sport,
                                            style: TextStyle(
                                              color: Colors.black.withValues(
                                                alpha: 0.45,
                                              ),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cs.primary.withValues(
                                                alpha: 0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              club.privacy.isNotEmpty
                                                  ? club.privacy
                                                  : 'Public',
                                              style: TextStyle(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (p.creatorLabel != null &&
                                          p.creatorLabel!
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Created by ${p.creatorLabel}',
                                          style: TextStyle(
                                            color: Colors.black.withValues(
                                              alpha: 0.58,
                                            ),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!p.isCurrentUserMember)
                                  Flexible(
                                    fit: FlexFit.loose,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton(
                                        onPressed: () async {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          try {
                                            await clubMemberRepository()
                                                .joinAsMember(
                                                  clubId: club.id,
                                                  userId: currentUserId,
                                                  role: ClubMemberRole.member,
                                                );
                                          } catch (_) {
                                            if (!mounted) return;
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Failed to join club.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          if (!mounted) return;
                                          setState(() {
                                            _payloadFuture = _load(
                                              refreshClub: false,
                                            );
                                          });
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Joined club.'),
                                            ),
                                          );
                                        },
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Join',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4F3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE3E7EE),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _StatCell(
                                    value: '$members',
                                    label: 'Members',
                                  ),
                                  _divider(),
                                  _StatCell(value: '$eventsN', label: 'Events'),
                                  _divider(),
                                  _StatCell(value: '$admins', label: 'Admins'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'About',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              desc,
                              style: TextStyle(
                                height: 1.45,
                                color: Colors.black.withValues(alpha: 0.72),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _MetaRow(
                              icon: Icons.location_on_outlined,
                              text: locationText,
                            ),
                            const SizedBox(height: 8),
                            _MetaRow(
                              icon: Icons.calendar_today_outlined,
                              text: _foundedLabel(club),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Members ($members)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (p.members.isEmpty)
                              Text(
                                'No members found for this club yet.',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  fontSize: 13,
                                ),
                              )
                            else
                              ...p.members.map(
                                (m) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      Navigator.of(context).pushNamed(
                                        UserProfileViewScreen.routeName,
                                        arguments: UserProfileViewArgs(
                                          userId: m.profile.userId,
                                        ),
                                      );
                                    },
                                    onLongPress: p.isCurrentUserAdmin
                                        ? () => _openMemberActions(
                                            payload: p,
                                            member: m,
                                          )
                                        : null,
                                    child: _MemberProfileTile(
                                      profile: m.profile,
                                      primary: cs.primary,
                                      isAdmin: m.isAdmin,
                                      isCreator: m.isCreator,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Upcoming Events',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (p.upcomingEvents.isEmpty)
                              Text(
                                'No upcoming events linked to this club. Set a clubId field on event documents in Appwrite to list them here.',
                                style: TextStyle(
                                  height: 1.4,
                                  color: Colors.black.withValues(alpha: 0.55),
                                  fontSize: 13,
                                ),
                              )
                            else ...[
                              for (
                                var i = 0;
                                i < p.upcomingEvents.length && i < 5;
                                i++
                              ) ...[
                                if (i > 0) const SizedBox(height: 12),
                                _ClubUpcomingEventCard(
                                  event: p.upcomingEvents[i],
                                  primary: cs.primary,
                                ),
                              ],
                            ],
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: const Color(0xFFE3E7EE));
  }
}

String _fmtClubEventSubtitle(Event e) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final dt = e.startAt;
  String two(int n) => n.toString().padLeft(2, '0');
  final h = dt.hour;
  final m = two(dt.minute);
  final hour12 = ((h + 11) % 12) + 1;
  final ampm = h >= 12 ? 'PM' : 'AM';
  return '${wd[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]} · $hour12:$m $ampm · ${e.location}';
}

class _ClubUpcomingEventCard extends StatelessWidget {
  final Event event;
  final Color primary;

  const _ClubUpcomingEventCard({required this.event, required this.primary});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(
          EventDetailScreen.routeName,
          arguments: EventDetailArgs(event: event, showRegisterButton: true),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E7EE)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmtClubEventSubtitle(event),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Open',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberProfileTile extends StatelessWidget {
  final UserProfile profile;
  final Color primary;
  final bool isAdmin;
  final bool isCreator;

  const _MemberProfileTile({
    required this.profile,
    required this.primary,
    required this.isAdmin,
    required this.isCreator,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile.realName.trim().isNotEmpty
        ? profile.realName.trim()
        : profile.username;
    final sportsPreview = profile.preferredSports.toList()..sort();
    final roleLabel = isAdmin ? 'Admin' : 'Member';
    final subtitle = sportsPreview.isEmpty
        ? roleLabel
        : '$roleLabel · ${sportsPreview.take(2).join(', ')}${sportsPreview.length > 2 ? '…' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7EE)),
      ),
      child: Row(
        children: [
          _ClubMemberAvatar(
            avatarFileId: profile.avatarFileId,
            primary: primary,
            label: name,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isCreator) ...[
            _AdminPill(text: 'Creator', color: const Color(0xFF7C3AED)),
            const SizedBox(width: 6),
          ],
          if (isAdmin) _AdminPill(text: 'Admin', color: primary),
        ],
      ),
    );
  }
}

class _ClubMemberAvatar extends StatelessWidget {
  final String? avatarFileId;
  final Color primary;
  final String label;

  const _ClubMemberAvatar({
    required this.avatarFileId,
    required this.primary,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final fid = avatarFileId?.trim();
    if (fid != null && fid.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: 44,
          height: 44,
          child: FutureBuilder(
            future: AppwriteService.getFileViewBytes(
              bucketId: AppwriteConfig.profileImagesBucketId,
              fileId: fid,
            ),
            builder: (context, snap) {
              if (snap.hasData && snap.data != null && snap.data!.isNotEmpty) {
                return Image.memory(snap.data!, fit: BoxFit.cover);
              }
              return _letterFallback();
            },
          ),
        ),
      );
    }
    return _letterFallback();
  }

  Widget _letterFallback() {
    final letter = label.isNotEmpty ? label[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _ClubBanner extends StatelessWidget {
  final Club club;

  const _ClubBanner({required this.club});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (club.thumbnailFileId != null && club.thumbnailFileId!.isNotEmpty) {
      return FutureBuilder(
        future: AppwriteService.getFileViewBytes(
          bucketId: AppwriteConfig.storageBucketId,
          fileId: club.thumbnailFileId!,
        ),
        builder: (context, snap) {
          if (snap.hasError) {
            return _bannerPlaceholder(cs);
          }
          final bytes = snap.data;
          if (snap.connectionState == ConnectionState.done &&
              bytes != null &&
              bytes.isNotEmpty) {
            return SizedBox.expand(
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting ||
              snap.connectionState == ConnectionState.active) {
            return Center(
              child: CircularProgressIndicator(
                color: cs.primary,
                strokeWidth: 2,
              ),
            );
          }
          return _bannerPlaceholder(cs);
        },
      );
    }
    return _bannerPlaceholder(cs);
  }

  Widget _bannerPlaceholder(ColorScheme cs) {
    return Container(
      width: double.infinity,
      color: cs.primary.withValues(alpha: 0.12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 40,
            color: Colors.black.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 6),
          Text(
            'Club banner',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.35),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubInfoAvatar extends StatelessWidget {
  final Club club;

  const _ClubInfoAvatar({required this.club});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.45),
            cs.primary.withValues(alpha: 0.15),
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
                if (snap.hasError) {
                  return Icon(Icons.sports_soccer, color: cs.primary, size: 40);
                }
                final bytes = snap.data;
                if (snap.connectionState == ConnectionState.done &&
                    bytes != null &&
                    bytes.isNotEmpty) {
                  return Image.memory(bytes, fit: BoxFit.cover);
                }
                if (snap.connectionState == ConnectionState.waiting ||
                    snap.connectionState == ConnectionState.active) {
                  return Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    ),
                  );
                }
                return Icon(Icons.sports_soccer, color: cs.primary, size: 40);
              },
            )
          : Icon(Icons.sports_soccer, color: cs.primary, size: 40),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;

  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.45),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black.withValues(alpha: 0.45)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminPill extends StatelessWidget {
  final String text;
  final Color color;

  const _AdminPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}
