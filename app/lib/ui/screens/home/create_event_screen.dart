import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../data/club_member_repository.dart';
import '../../../data/club_repository.dart';
import '../../../data/event_invite_repository.dart';
import '../../../data/sample_clubs.dart';
import '../../../models/club.dart';
import '../../../models/event.dart';
import 'map_picker_screen.dart';

class CreateEventScreen extends StatefulWidget {
  static const routeName = '/create-event';

  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  static const _draftPrefsKey = 'create_event_draft_v3';
  static _CreateEventDraft? _lastDraft;

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _participantsCtrl = TextEditingController(text: '1');
  final _dateTimeDisplayCtrl = TextEditingController();
  final _durationDisplayCtrl = TextEditingController();
  final _feeCtrl = TextEditingController(text: 'Free');

  Event? _initialEvent;
  bool _hasPrefilled = false;
  bool _didPromptDraftChoice = false;

  String? _sport;
  String? _category;
  String? _privacy;
  DateTime? _dateTime;
  String? _duration;
  String? _skillLevel;
  String? _gender;
  String? _ageGroup;
  String? _hostRole;
  String? _cancellationFreeze;
  String? _thumbnailFileId;
  Uint8List? _thumbnailPreviewBytes;
  bool _isSubmitting = false;
  String? _participantSuggestionHint;

  /// Clubs where the current user is an admin (loaded once).
  late final Future<List<Club>> _adminClubsFuture;

  /// When true, the event is linked to [clubId] for a club-hosted listing.
  bool _hostAsClub = false;

  /// Selected club id when [_hostAsClub]; must be one of the user’s admin clubs.
  String? _hostClubId;

  bool get _isEditMode => _initialEvent != null;

  @override
  void initState() {
    super.initState();
    _adminClubsFuture = _loadAdminClubs();
  }

  Future<List<Club>> _loadAdminClubs() async {
    final me = currentUserId.trim();
    if (me.isEmpty) {
      return const <Club>[];
    }
    final all = await clubRepository().listClubs();
    final memberships = await clubMemberRepository().listMembershipsForUser(
      userId: me,
    );
    final adminIds = memberships
        .where((m) => m.role == ClubMemberRole.admin)
        .map((m) => m.clubId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    // Backward-compatible fallback: treat club creators as admins even when
    // club_members rows are missing or inaccessible.
    for (final c in all) {
      final creatorId = (c.creatorId ?? '').trim();
      if (creatorId.isNotEmpty && creatorId == me) {
        adminIds.add(c.id);
      }
    }
    if (adminIds.isEmpty) {
      return const <Club>[];
    }
    final list = all.where((c) => adminIds.contains(c.id)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPrefilled) {
      _restoreDraftFromPrefs();
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Event) {
        _initialEvent = args;
        _prefillFromEvent(args);
        _hasPrefilled = true;
      } else {
        _hasPrefilled = true;
      }
    }

    if (!_isEditMode && !_didPromptDraftChoice) {
      _didPromptDraftChoice = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _maybePromptDraftStartChoice();
      });
    }
  }

  Future<void> _maybePromptDraftStartChoice() async {
    final draft = _lastDraft;
    if (draft == null || draft.isEmpty) {
      return;
    }

    final choice = await showDialog<_CreateEventStartChoice>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create event'),
          content: const Text(
            'Would you like to start a new event or continue from your previous draft?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_CreateEventStartChoice.newBlank),
              child: const Text('New'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_CreateEventStartChoice.fromPrevious),
              child: const Text('From previous'),
            ),
          ],
        );
      },
    );

    if (!mounted || choice == null) {
      return;
    }

    switch (choice) {
      case _CreateEventStartChoice.newBlank:
        setState(() {
          _clearDraftAndForm();
        });
        break;
      case _CreateEventStartChoice.fromPrevious:
        setState(() {
          _applyDraftToForm(draft);
        });
        break;
    }
  }

  void _restoreDraftFromPrefs() {
    SharedPreferences.getInstance().then((prefs) {
      final raw = prefs.getString(_draftPrefsKey);
      final draft = _CreateEventDraft.tryParse(raw);
      if (draft == null || draft.isEmpty) {
        return;
      }
      _lastDraft = draft;
    });
  }

  Future<void> _saveDraftToPrefs(_CreateEventDraft? draft) async {
    final prefs = await SharedPreferences.getInstance();
    if (draft == null || draft.isEmpty) {
      await prefs.remove(_draftPrefsKey);
      return;
    }
    await prefs.setString(_draftPrefsKey, draft.encode());
  }

  void _prefillFromEvent(Event e) {
    _titleCtrl.text = e.title;
    _descriptionCtrl.text = e.description;
    _locationCtrl.text = e.location;
    _latCtrl.text = e.lat?.toString() ?? '';
    _lngCtrl.text = e.lng?.toString() ?? '';
    _sport = e.sport;
    _dateTime = e.startAt;
    _dateTimeDisplayCtrl.text =
        '${e.startAt.day}/${e.startAt.month}/${e.startAt.year.toString().substring(2)}, ${e.startAt.hour}:${e.startAt.minute.toString().padLeft(2, '0')}';
    _duration = _durationLabelFromDuration(e.duration);
    _durationDisplayCtrl.text = _duration ?? '';
    _participantsCtrl.text = e.capacity.toString();
    _participantSuggestionHint = _participantSuggestionForSport(e.sport)?.value;
    _feeCtrl.text = _normalizeFeeLabel(e.entryFeeLabel);
    _thumbnailFileId = e.thumbnailFileId;
    _skillLevel = _normalizeSkillLevelLabel(e.skillLevel);
    _gender = e.gender;
    _ageGroup = e.ageGroup;
    _hostRole = e.hostRole;
    _cancellationFreeze = e.cancellationFreeze;
    final cid = e.clubId?.trim();
    _hostAsClub = cid != null && cid.isNotEmpty;
    _hostClubId = _hostAsClub ? cid : null;
  }

  void _applyDraftToForm(_CreateEventDraft draft) {
    _titleCtrl.text = draft.title;
    _descriptionCtrl.text = draft.description;
    _locationCtrl.text = draft.location;
    _latCtrl.text = draft.latText;
    _lngCtrl.text = draft.lngText;
    _participantsCtrl.text = draft.participantsText.isEmpty
        ? '1'
        : draft.participantsText;
    _feeCtrl.text = draft.feeText.isEmpty ? 'Free' : draft.feeText;
    _sport = draft.sport;
    _participantSuggestionHint = _participantSuggestionForSport(_sport)?.value;
    _category = draft.category;
    _privacy = draft.privacy;
    _dateTime = draft.dateTime;
    _duration = draft.duration;
    _skillLevel = draft.skillLevel;
    _gender = draft.gender;
    _ageGroup = draft.ageGroup;
    _hostRole = draft.hostRole;
    _cancellationFreeze = draft.cancellationFreeze;
    _thumbnailFileId = draft.thumbnailFileId;
    _thumbnailPreviewBytes = null;
    _hostAsClub = draft.hostAsClub;
    _hostClubId = draft.hostClubId;

    final dt = draft.dateTime;
    _dateTimeDisplayCtrl.text = dt == null
        ? ''
        : '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    _durationDisplayCtrl.text = draft.duration ?? '';
  }

  _CreateEventDraft _buildDraftFromForm() {
    return _CreateEventDraft(
      title: _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      latText: _latCtrl.text.trim(),
      lngText: _lngCtrl.text.trim(),
      participantsText: _participantsCtrl.text.trim(),
      feeText: _feeCtrl.text.trim(),
      sport: _sport,
      category: _category,
      privacy: _privacy,
      dateTime: _dateTime,
      duration: _duration,
      skillLevel: _skillLevel,
      gender: _gender,
      ageGroup: _ageGroup,
      hostRole: _hostRole,
      cancellationFreeze: _cancellationFreeze,
      thumbnailFileId: _thumbnailFileId,
      hostAsClub: _hostAsClub,
      hostClubId: _hostClubId,
    );
  }

  void _clearDraftAndForm() {
    _lastDraft = null;
    _saveDraftToPrefs(null);
    _titleCtrl.clear();
    _descriptionCtrl.clear();
    _locationCtrl.clear();
    _latCtrl.clear();
    _lngCtrl.clear();
    _participantsCtrl.text = '1';
    _dateTimeDisplayCtrl.clear();
    _durationDisplayCtrl.clear();
    _feeCtrl.text = 'Free';

    _sport = null;
    _category = null;
    _privacy = null;
    _dateTime = null;
    _duration = null;
    _skillLevel = null;
    _gender = null;
    _ageGroup = null;
    _hostRole = null;
    _cancellationFreeze = null;
    _thumbnailFileId = null;
    _thumbnailPreviewBytes = null;
    _hostAsClub = false;
    _hostClubId = null;
    _participantSuggestionHint = null;
  }

  MapEntry<int, String>? _participantSuggestionForSport(String? sport) {
    final value = (sport ?? '').trim().toLowerCase();
    if (value.isEmpty) {
      return null;
    }
    if (value.contains('football') ||
        value.contains('basketball') ||
        value.contains('volleyball')) {
      return const MapEntry<int, String>(
        4,
        'Suggested team setup: 3-5 participants.',
      );
    }
    if (value.contains('badminton') ||
        value.contains('tennis') ||
        value.contains('pickleball') ||
        value.contains('table tennis')) {
      return const MapEntry<int, String>(
        4,
        'Suggested racket setup: 2-4 participants.',
      );
    }
    if (value.contains('running') ||
        value.contains('jogging') ||
        value.contains('cycling') ||
        value.contains('swimming')) {
      return const MapEntry<int, String>(
        6,
        'Suggested group setup: around 4-8 participants.',
      );
    }
    return const MapEntry<int, String>(4, 'Suggested setup: 3-5 participants.');
  }

  String? _durationLabelFromDuration(Duration d) {
    final totalMin = d.inMinutes;
    if (totalMin <= 60) return '1 Hour';
    if (totalMin <= 90) return '1.5 Hours';
    if (totalMin <= 120) return '2 Hours';
    if (totalMin <= 150) return '2.5 Hours';
    if (totalMin <= 180) return '3 Hours';
    if (totalMin <= 210) return '3.5 Hours';
    if (totalMin <= 240) return '4 Hours';
    if (totalMin <= 270) return '4.5 Hours';
    if (totalMin <= 300) return '5 Hours';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '$h Hours $m Min';
    if (h > 0) return '$h Hours';
    return '$totalMin Min';
  }

  @override
  void dispose() {
    if (!_isEditMode && !_isSubmitting) {
      final draft = _buildDraftFromForm();
      _lastDraft = draft.isEmpty ? null : draft;
      _saveDraftToPrefs(_lastDraft);
    }
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _participantsCtrl.dispose();
    _dateTimeDisplayCtrl.dispose();
    _durationDisplayCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          ),
          title: Text(
            _isEditMode ? 'Edit Event' : 'Create Event',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: AbsorbPointer(
          absorbing: _isSubmitting,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                _SectionCard(
                  title: 'SPORT DETAILS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _TapPickerField(
                              label: 'Sport',
                              value: _sport ?? 'Sport',
                              onTap: () => _showOptionPicker<String>(
                                title: 'Sport',
                                options: SampleData.sports,
                                onSelected: (v) => setState(() {
                                  _sport = v;
                                  final suggestion =
                                      _participantSuggestionForSport(v);
                                  if (suggestion != null) {
                                    _participantsCtrl.text = suggestion.key
                                        .toString();
                                    _participantSuggestionHint =
                                        suggestion.value;
                                  } else {
                                    _participantSuggestionHint = null;
                                  }
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TapPickerField(
                              label: 'Category',
                              value: _category ?? 'Category',
                              onTap: () => _showOptionPicker<String>(
                                title: 'Category',
                                options: const [
                                  'Casual',
                                  'Competition',
                                  'Training',
                                  'Social',
                                ],
                                onSelected: (v) =>
                                    setState(() => _category = v),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TapPickerField(
                        label: 'Privacy',
                        value: _privacy ?? 'Privacy',
                        onTap: () => _showOptionPicker<String>(
                          title: 'Privacy',
                          options: const [
                            'Public (anyone can join)',
                            'Private (invites only)',
                          ],
                          onSelected: (v) => setState(() => _privacy = v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FutureBuilder<List<Club>>(
                  future: _adminClubsFuture,
                  builder: (context, snap) {
                    final adminClubs = snap.data;
                    if (adminClubs == null || adminClubs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionCard(
                          title: 'HOST',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'You’re an admin of at least one club. Choose whether this event is hosted by you personally or listed under a club.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: Colors.black.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SegmentedButton<bool>(
                                style: SegmentedButton.styleFrom(
                                  selectedBackgroundColor: cs.primary
                                      .withValues(alpha: 0.18),
                                ),
                                segments: const [
                                  ButtonSegment<bool>(
                                    value: false,
                                    label: Text('Myself'),
                                    icon: Icon(Icons.person_outlined, size: 18),
                                  ),
                                  ButtonSegment<bool>(
                                    value: true,
                                    label: Text('Club'),
                                    icon: Icon(Icons.groups_outlined, size: 18),
                                  ),
                                ],
                                selected: {_hostAsClub},
                                onSelectionChanged: (Set<bool> next) {
                                  setState(() {
                                    _hostAsClub = next.first;
                                    if (_hostAsClub) {
                                      if (adminClubs.length == 1) {
                                        _hostClubId = adminClubs.first.id;
                                      } else if (_hostClubId != null &&
                                          !adminClubs.any(
                                            (c) => c.id == _hostClubId,
                                          )) {
                                        _hostClubId = null;
                                      }
                                    }
                                  });
                                },
                              ),
                              if (_hostAsClub) ...[
                                const SizedBox(height: 14),
                                if (adminClubs.length == 1)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 20,
                                        color: cs.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Listed as ${adminClubs.first.name}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Club hosting this event',
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value:
                                            _hostClubId != null &&
                                                adminClubs.any(
                                                  (c) => c.id == _hostClubId,
                                                )
                                            ? _hostClubId
                                            : null,
                                        hint: const Text('Select club'),
                                        items: [
                                          for (final c in adminClubs)
                                            DropdownMenuItem<String>(
                                              value: c.id,
                                              child: Text(
                                                c.name,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                        onChanged: (v) =>
                                            setState(() => _hostClubId = v),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    );
                  },
                ),
                _SectionCard(
                  title: 'DATE & LOCATION',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InputWithIcon(
                        icon: Icons.calendar_today,
                        iconColor: cs.primary,
                        hint: 'Date & Time',
                        readOnly: true,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (!context.mounted || date == null) {
                            return;
                          }
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (!context.mounted || time == null) {
                            return;
                          }
                          setState(() {
                            _dateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            _dateTimeDisplayCtrl.text =
                                '${_dateTime!.day}/${_dateTime!.month}/${_dateTime!.year.toString().substring(2)}, ${_dateTime!.hour}:${_dateTime!.minute.toString().padLeft(2, '0')}';
                          });
                        },
                        controller: _dateTimeDisplayCtrl,
                      ),
                      const SizedBox(height: 12),
                      _InputWithIcon(
                        icon: Icons.schedule,
                        iconColor: cs.primary,
                        hint: 'Duration',
                        readOnly: true,
                        onTap: () => _showDurationPicker(context),
                        controller: _durationDisplayCtrl,
                      ),
                      const SizedBox(height: 12),
                      _InputWithIcon(
                        icon: Icons.location_on_outlined,
                        iconColor: cs.primary,
                        hint: 'Choose Location',
                        controller: _locationCtrl,
                        readOnly: true,
                        onTap: _pickLocationFromMap,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                hintText: 'Latitude (optional)',
                              ),
                              validator: (v) {
                                final txt = (v ?? '').trim();
                                if (txt.isEmpty) return null;
                                final n = double.tryParse(txt);
                                if (n == null) return 'Invalid';
                                if (n < -90 || n > 90) return '−90 to 90';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lngCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                hintText: 'Longitude (optional)',
                              ),
                              validator: (v) {
                                final txt = (v ?? '').trim();
                                if (txt.isEmpty) return null;
                                final n = double.tryParse(txt);
                                if (n == null) return 'Invalid';
                                if (n < -180 || n > 180) return '−180 to 180';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'REQUIREMENTS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Skill Level',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _TapPickerField(
                        value: _skillLevel ?? 'Any',
                        onTap: () => _showOptionPicker<String>(
                          title: 'Skill Level',
                          options: _skillLevelOptions,
                          onSelected: (v) => setState(() => _skillLevel = v),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No. of Participants',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: _decrementParticipants,
                            icon: const Icon(Icons.remove),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              controller: _participantsCtrl,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                hintText: 'e.g. 20',
                              ),
                              onChanged: (value) {
                                final parsed = int.tryParse(value);
                                if (parsed == null) {
                                  return;
                                }
                                if (parsed < 1) {
                                  _participantsCtrl.value =
                                      const TextEditingValue(
                                        text: '1',
                                        selection: TextSelection.collapsed(
                                          offset: 1,
                                        ),
                                      );
                                }
                              },
                              validator: (v) {
                                final txt = (v ?? '').trim();
                                final n = int.tryParse(txt);
                                if (n == null || n <= 0) {
                                  return 'Enter a valid participant count';
                                }
                                if (n > 10000) {
                                  return 'Too large';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            onPressed: _incrementParticipants,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      if (_participantSuggestionHint != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _participantSuggestionHint!,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Text(
                        'Fee',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _feeCtrl,
                        decoration: const InputDecoration(hintText: 'Free'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'ABOUT THE EVENT',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Title',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Name your event',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter a title'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionCtrl,
                        decoration: const InputDecoration(
                          hintText:
                              'Explain about the event/rules and regulation/casual/Competition.',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        minLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'FILTERS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TapPickerField(
                        label: 'Gender',
                        value: _gender ?? 'Any',
                        onTap: () => _showOptionPicker<String>(
                          title: 'Gender',
                          options: const ['Any', 'Male', 'Female'],
                          onSelected: (v) => setState(() => _gender = v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TapPickerField(
                        label: 'Age Group',
                        value: _ageGroup ?? 'Any',
                        onTap: () => _showOptionPicker<String>(
                          title: 'Age Group',
                          options: const [
                            'Any',
                            'Junior (<18)',
                            'Adult (19 - 59)',
                            'Senior (60+)',
                          ],
                          onSelected: (v) => setState(() => _ageGroup = v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TapPickerField(
                        label: "Host's Role",
                        value: _hostRole ?? 'Host Only',
                        onTap: () => _showOptionPicker<String>(
                          title: "Host's Role",
                          options: const ['Host only', 'Host & Play'],
                          onSelected: (v) => setState(() => _hostRole = v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TapPickerField(
                        label: 'Cancellation Freeze',
                        value: _cancellationFreeze ?? '12 Hours',
                        onTap: () => _showOptionPicker<String>(
                          title: 'Cancellation Freeze',
                          options: const [
                            '1 Hour',
                            '2 Hour',
                            '3 Hour',
                            '4 Hour',
                            '5 Hour',
                            '6 Hour',
                            '10 Hour',
                            '12 Hour',
                          ],
                          onSelected: (v) =>
                              setState(() => _cancellationFreeze = v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'MEDIA',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onTap: _pickThumbnail,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFE3E7EE),
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildThumbnailPreview(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _pickThumbnail,
                            child: const Text('Choose Thumbnail'),
                          ),
                          const SizedBox(width: 10),
                          if (_thumbnailPreviewBytes != null ||
                              _thumbnailFileId != null)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _thumbnailFileId = null;
                                  _thumbnailPreviewBytes = null;
                                });
                              },
                              child: const Text('Remove'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _onSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEditMode ? 'Save' : 'Create'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDurationPicker(BuildContext context) async {
    final options = [
      '1 Hour',
      '1.5 Hours',
      '2 Hours',
      '2.5 Hours',
      '3 Hours',
      '3.5 Hours',
      '4 Hours',
      '4.5 Hours',
      '5 Hours',
    ];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              ListTile(title: Text(o), onTap: () => Navigator.pop(ctx, o)),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() {
        _duration = chosen;
        _durationDisplayCtrl.text = chosen;
      });
    }
  }

  Future<void> _showOptionPicker<T>({
    required String title,
    required List<T> options,
    required ValueChanged<T> onSelected,
  }) async {
    final chosen = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: options.length > 8 ? 0.55 : 0.42,
        minChildSize: 0.28,
        maxChildSize: 0.92,
        builder: (sheetCtx, scrollController) {
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final o = options[i];
                      return ListTile(
                        title: Text(
                          o.toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(ctx, o),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (chosen != null && mounted) {
      onSelected(chosen);
    }
  }

  void _onSubmit() {
    _saveToAppwrite();
  }

  Future<void> _saveToAppwrite() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSubmitting) {
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

    final startAt = _dateTime;
    final durationMinutes = _durationMinutesFromLabel(_duration);
    final title = _titleCtrl.text.trim();
    final sport = _sport?.trim() ?? '';
    final location = _locationCtrl.text.trim();
    final fee = _normalizeFeeLabel(_feeCtrl.text.trim());
    final capacity = int.tryParse(_participantsCtrl.text.trim());

    if (startAt == null ||
        durationMinutes == null ||
        sport.isEmpty ||
        location.isEmpty ||
        capacity == null ||
        capacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill Sport, Date & Time, Duration, Location, and Participants.',
          ),
        ),
      );
      return;
    }

    final selectedPrivacy = (_privacy ?? '').toLowerCase();
    final isPrivateEvent = selectedPrivacy.contains('private');

    final skillLevel =
        _skillLevel ??
        _normalizeSkillLevelLabel(_initialEvent?.skillLevel ?? '—');

    final lat = _latCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_latCtrl.text.trim());
    final lng = _lngCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_lngCtrl.text.trim());

    final adminClubs = await _adminClubsFuture;
    String? resolvedClubId;
    if (adminClubs.isNotEmpty) {
      if (_hostAsClub) {
        if (adminClubs.length == 1) {
          resolvedClubId = adminClubs.first.id;
        } else if (_hostClubId != null &&
            adminClubs.any((c) => c.id == _hostClubId)) {
          resolvedClubId = _hostClubId;
        } else {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Choose which club is hosting this event.'),
            ),
          );
          return;
        }
      } else {
        resolvedClubId = null;
      }
    } else {
      final initialCid = _initialEvent?.clubId?.trim();
      resolvedClubId = initialCid != null && initialCid.isNotEmpty
          ? initialCid
          : null;
    }

    if (isPrivateEvent &&
        (resolvedClubId == null || resolvedClubId.trim().isEmpty)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Private events currently require club hosting so members can be invited.',
          ),
        ),
      );
      return;
    }

    List<String> invitedUserIds = _isEditMode
        ? [...(_initialEvent?.invitedUserIds ?? const <String>[])]
        : const <String>[];
    List<String> rejectedInviteUserIds = _isEditMode
        ? [...(_initialEvent?.rejectedInviteUserIds ?? const <String>[])]
        : const <String>[];
    if (isPrivateEvent && resolvedClubId != null && resolvedClubId.isNotEmpty) {
      invitedUserIds = await eventInviteRepository().buildClubInviteeIds(
        clubId: resolvedClubId,
        creatorId: currentUserId,
      );
      rejectedInviteUserIds = _isEditMode
          ? [...(_initialEvent?.rejectedInviteUserIds ?? const <String>[])]
          : const <String>[];
    }

    final initialClubRaw = _initialEvent?.clubId?.trim();
    final normalizedInitialClub =
        (initialClubRaw != null && initialClubRaw.isNotEmpty)
        ? initialClubRaw
        : null;
    final clubAssociationChanged =
        (resolvedClubId ?? '') != (normalizedInitialClub ?? '');
    final validateFnId = AppwriteConfig.validateEventClubHostFunctionId.trim();
    if (validateFnId.isNotEmpty &&
        resolvedClubId != null &&
        resolvedClubId.isNotEmpty &&
        (!_isEditMode || clubAssociationChanged)) {
      try {
        await AppwriteService.executeFunction(
          functionId: validateFnId,
          payload: <String, dynamic>{'clubId': resolvedClubId},
        );
      } catch (e) {
        if (!mounted) {
          return;
        }
        final msg = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Club host validation failed.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }
    }

    final baseData = <String, dynamic>{
      'title': title,
      'sport': sport,
      'startAt': startAt.toIso8601String(),
      'durationMinutes': durationMinutes,
      'location': location,
      'lat': lat,
      'lng': lng,
      'capacity': capacity,
      'joined': _initialEvent?.joined ?? 0,
      'participantIds': _initialEvent?.participantIds ?? <String>[],
      'entryFeeLabel': fee,
      'skillLevel': skillLevel,
      'description': _descriptionCtrl.text.trim(),
      'creatorId': _initialEvent?.creatorId ?? currentUserId,
      'category': _category,
      'privacy': _privacy,
      'invitedUserIds': invitedUserIds,
      'rejectedInviteUserIds': rejectedInviteUserIds,
      'gender': _gender,
      'ageGroup': _ageGroup,
      'hostRole': _hostRole,
      'cancellationFreeze': _cancellationFreeze,
      'thumbnailFileId': _thumbnailFileId,
    };
    if (resolvedClubId != null && resolvedClubId.isNotEmpty) {
      baseData['clubId'] = resolvedClubId;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isEditMode) {
        await AppwriteService.updateDocument(
          collectionId: AppwriteConfig.eventsCollectionId,
          documentId: _initialEvent!.id,
          data: baseData,
        );
      } else {
        await AppwriteService.createDocument(
          collectionId: AppwriteConfig.eventsCollectionId,
          data: baseData,
        );
      }

      if (mounted) {
        if (!_isEditMode) {
          _lastDraft = null;
          _saveDraftToPrefs(null);
        }
        final navigator = Navigator.of(context);
        final result = _isEditMode ? 'updated' : 'created';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigator.mounted) {
            navigator.pop(result);
          }
        });
      }
    } on AppwriteException catch (e) {
      if (!mounted) {
        return;
      }
      final message = (e.message ?? '').trim();
      final hasClubIdSchemaIssue =
          message.toLowerCase().contains('clubid') &&
          (message.toLowerCase().contains('attribute') ||
              message.toLowerCase().contains('structure'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasClubIdSchemaIssue
                ? 'Event save failed: add optional "clubId" string attribute to events collection.'
                : (message.isNotEmpty
                      ? message
                      : 'Failed to save event to Appwrite. Check collection attributes/permissions.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to save event to Appwrite. Check collection attributes/permissions.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked == null) {
      return;
    }

    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() => _thumbnailPreviewBytes = bytes);
      final uploaded = await AppwriteService.uploadFile(
        bucketId: AppwriteConfig.eventImagesBucketId,
        path: picked.path,
        bytes: bytes,
        filename: picked.name,
      );
      if (!mounted) {
        return;
      }
      setState(() => _thumbnailFileId = uploaded.$id);
    } on AppwriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                'Failed to upload thumbnail. Bucket: ${AppwriteConfig.eventImagesBucketId}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to upload thumbnail. Bucket: ${AppwriteConfig.eventImagesBucketId}',
          ),
        ),
      );
    }
  }

  Future<void> _pickLocationFromMap() async {
    final picked = await Navigator.of(
      context,
    ).pushNamed(MapPickerScreen.routeName);
    if (!mounted || picked is! MapPickerResult) {
      return;
    }
    setState(() {
      _latCtrl.text = picked.lat.toStringAsFixed(6);
      _lngCtrl.text = picked.lng.toStringAsFixed(6);
      _locationCtrl.text =
          '${picked.lat.toStringAsFixed(6)}, ${picked.lng.toStringAsFixed(6)}';
    });
  }

  void _incrementParticipants() {
    final current = int.tryParse(_participantsCtrl.text.trim()) ?? 1;
    final next = (current + 1).clamp(1, 10000);
    setState(() => _participantsCtrl.text = next.toString());
  }

  void _decrementParticipants() {
    final current = int.tryParse(_participantsCtrl.text.trim()) ?? 1;
    final next = (current - 1).clamp(1, 10000);
    setState(() => _participantsCtrl.text = next.toString());
  }

  Widget _buildThumbnailPreview() {
    if (_thumbnailPreviewBytes != null) {
      return Image.memory(_thumbnailPreviewBytes!, fit: BoxFit.cover);
    }

    if (_thumbnailFileId != null && _thumbnailFileId!.isNotEmpty) {
      return FutureBuilder<Uint8List>(
        future: AppwriteService.getFileViewBytes(
          bucketId: AppwriteConfig.eventImagesBucketId,
          fileId: _thumbnailFileId!,
        ),
        builder: (context, snap) {
          if (snap.hasData) {
            return Image.memory(snap.data!, fit: BoxFit.cover);
          }
          return _buildThumbnailPlaceholder();
        },
      );
    }

    return _buildThumbnailPlaceholder();
  }

  Widget _buildThumbnailPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 40,
            color: Colors.black.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 8),
          Text(
            'Insert Thumbnail',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _CreateEventStartChoice { newBlank, fromPrevious }

class _CreateEventDraft {
  final String title;
  final String description;
  final String location;
  final String latText;
  final String lngText;
  final String participantsText;
  final String feeText;
  final String? sport;
  final String? category;
  final String? privacy;
  final DateTime? dateTime;
  final String? duration;
  final String? skillLevel;
  final String? gender;
  final String? ageGroup;
  final String? hostRole;
  final String? cancellationFreeze;
  final String? thumbnailFileId;
  final bool hostAsClub;
  final String? hostClubId;

  const _CreateEventDraft({
    required this.title,
    required this.description,
    required this.location,
    required this.latText,
    required this.lngText,
    required this.participantsText,
    required this.feeText,
    required this.sport,
    required this.category,
    required this.privacy,
    required this.dateTime,
    required this.duration,
    required this.skillLevel,
    required this.gender,
    required this.ageGroup,
    required this.hostRole,
    required this.cancellationFreeze,
    required this.thumbnailFileId,
    this.hostAsClub = false,
    this.hostClubId,
  });

  static _CreateEventDraft? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    final parts = raw.split('\u0001');
    if (parts.length < 19) {
      return null;
    }
    DateTime? asDateTime(String s) => s.isEmpty ? null : DateTime.tryParse(s);
    String? asOpt(String s) => s.isEmpty ? null : s;
    final legacyMin = int.tryParse(parts[12]);
    final legacyMax = int.tryParse(parts[13]);
    final parsedSkillLevel = legacyMin != null && legacyMax != null
        ? _skillLevelFromLegacyNumbers(legacyMin, legacyMax)
        : asOpt(parts[12]);

    // v1: length 20 — [18]=repeat, [19]=thumbnail
    // v2: length 19 — [18]=thumbnail
    // v3: length 21 — [18]=thumbnail, [19]=hostAsClub ('0'|'1'), [20]=hostClubId
    final String? thumbnail = parts.length >= 21
        ? asOpt(parts[18])
        : (parts.length >= 20 ? asOpt(parts[19]) : asOpt(parts[18]));
    final hostAsClub = parts.length >= 21 && parts[19] == '1';
    final String? hostClubIdParsed = parts.length >= 21
        ? asOpt(parts[20])
        : null;
    return _CreateEventDraft(
      title: parts[0],
      description: parts[1],
      location: parts[2],
      latText: parts[3],
      lngText: parts[4],
      participantsText: parts[5],
      feeText: parts[6],
      sport: asOpt(parts[7]),
      category: asOpt(parts[8]),
      privacy: asOpt(parts[9]),
      dateTime: asDateTime(parts[10]),
      duration: asOpt(parts[11]),
      skillLevel: parsedSkillLevel,
      gender: asOpt(parts[14]),
      ageGroup: asOpt(parts[15]),
      hostRole: asOpt(parts[16]),
      cancellationFreeze: asOpt(parts[17]),
      thumbnailFileId: thumbnail,
      hostAsClub: hostAsClub,
      hostClubId: hostClubIdParsed,
    );
  }

  String encode() {
    String s(String? v) => v ?? '';
    String d(DateTime? v) => v?.toIso8601String() ?? '';
    return [
      title,
      description,
      location,
      latText,
      lngText,
      participantsText,
      feeText,
      s(sport),
      s(category),
      s(privacy),
      d(dateTime),
      s(duration),
      s(skillLevel),
      '',
      s(gender),
      s(ageGroup),
      s(hostRole),
      s(cancellationFreeze),
      s(thumbnailFileId),
      hostAsClub ? '1' : '0',
      s(hostClubId),
    ].join('\u0001');
  }

  bool get isEmpty {
    return title.isEmpty &&
        description.isEmpty &&
        location.isEmpty &&
        latText.isEmpty &&
        lngText.isEmpty &&
        (participantsText.isEmpty || participantsText == '1') &&
        (feeText.isEmpty || feeText.toLowerCase() == 'free') &&
        sport == null &&
        category == null &&
        privacy == null &&
        dateTime == null &&
        duration == null &&
        skillLevel == null &&
        gender == null &&
        ageGroup == null &&
        hostRole == null &&
        cancellationFreeze == null &&
        (thumbnailFileId == null || thumbnailFileId!.isEmpty);
  }
}

String _skillLevelFromLegacyNumbers(int min, int max) {
  final score = max >= min ? max : min;
  if (score <= 2) {
    return 'Beginner';
  }
  if (score <= 4) {
    return 'Novice';
  }
  if (score <= 6) {
    return 'Intermediate';
  }
  if (score <= 8) {
    return 'Advanced';
  }
  return 'Pro/Master';
}

const List<String> _skillLevelOptions = <String>[
  'Any',
  'Beginner',
  'Novice',
  'Intermediate',
  'Advanced',
  'Pro/Master',
];

String _normalizeSkillLevelLabel(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text == '—') {
    return 'Any';
  }
  for (final option in _skillLevelOptions) {
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
    final min = matches.first;
    final max = matches.last;
    return _skillLevelFromLegacyNumbers(min, max);
  }
  return text;
}

String _normalizeFeeLabel(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return 'Free';
  }
  if (text.toLowerCase() == 'free') {
    return 'Free';
  }
  if (text.startsWith('\$')) {
    return text;
  }
  return '\$$text';
}

int? _durationMinutesFromLabel(String? label) {
  switch (label) {
    case '1 Hour':
      return 60;
    case '1.5 Hours':
      return 90;
    case '2 Hours':
      return 120;
    case '2.5 Hours':
      return 150;
    case '3 Hours':
      return 180;
    case '3.5 Hours':
      return 210;
    case '4 Hours':
      return 240;
    case '4.5 Hours':
      return 270;
    case '5 Hours':
      return 300;
  }
  return null;
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EE)),
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
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TapPickerField extends StatelessWidget {
  final String? label;
  final String value;
  final VoidCallback onTap;

  const _TapPickerField({required this.value, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: Text(value)),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InputWithIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String hint;
  final TextEditingController? controller;
  final bool readOnly;
  final VoidCallback? onTap;

  const _InputWithIcon({
    required this.icon,
    required this.iconColor,
    required this.hint,
    this.controller,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: readOnly ? onTap : null,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}
