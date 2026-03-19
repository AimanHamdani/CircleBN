import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appwrite/appwrite.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../models/event.dart';
import 'map_picker_screen.dart';

class CreateEventScreen extends StatefulWidget {
  static const routeName = '/create-event';

  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
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

  String? _sport;
  String? _category;
  String? _privacy;
  DateTime? _dateTime;
  String? _duration;
  String? _fee;
  int? _skillMin;
  int? _skillMax;
  String? _gender;
  String? _ageGroup;
  String? _hostRole;
  String? _cancellationFreeze;
  String? _repeat = 'None';
  String? _thumbnailFileId;
  Uint8List? _thumbnailPreviewBytes;
  bool _isSubmitting = false;

  bool get _isEditMode => _initialEvent != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPrefilled) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Event) {
        _initialEvent = args;
        _prefillFromEvent(args);
        _hasPrefilled = true;
      } else {
        _hasPrefilled = true;
      }
    }
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
    _fee = e.entryFeeLabel;
    _feeCtrl.text = e.entryFeeLabel;
    _thumbnailFileId = e.thumbnailFileId;
    final skill = _parseSkillLevel(e.skillLevel);
    _skillMin = skill.$1;
    _skillMax = skill.$2;
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
    return '${totalMin} Min';
  }

  (int?, int?) _parseSkillLevel(String s) {
    final parts = s.split(RegExp(r'[\s\-–]+'));
    if (parts.length >= 2) {
      final a = int.tryParse(parts[0].trim());
      final b = int.tryParse(parts[1].trim());
      if (a != null && b != null) return (a, b);
    }
    final single = int.tryParse(s.trim());
    if (single != null) return (single, single);
    return (null, null);
  }

  @override
  void dispose() {
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
                            options: const [
                              'Volleyball',
                              'Badminton',
                              'Football',
                              'Basketball',
                              'Jogging / Running',
                              'Running',
                              'Cycling',
                              'Swimming',
                            ],
                            onSelected: (v) => setState(() => _sport = v),
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
                            options: const ['Casual', 'Competition', 'Training', 'Social'],
                            onSelected: (v) => setState(() => _category = v),
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
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null && mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null && mounted) {
                          setState(() {
                            _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            _dateTimeDisplayCtrl.text = '${_dateTime!.day}/${_dateTime!.month}/${_dateTime!.year.toString().substring(2)}, ${_dateTime!.hour}:${_dateTime!.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      }
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
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
                  const Text('Skill Level', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TapPickerField(
                          label: 'Min',
                          value: (_skillMin?.toString() ?? 'Min'),
                          onTap: () => _showOptionPicker<int>(
                            title: 'Min Skill',
                            options: List.generate(10, (i) => i + 1),
                            onSelected: (v) => setState(() {
                              _skillMin = v;
                              if (_skillMax != null && _skillMax! < v) {
                                _skillMax = v;
                              }
                            }),
                          ),
                        ),
                      ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
                      Expanded(
                        child: _TapPickerField(
                          label: 'Max',
                          value: (_skillMax?.toString() ?? 'Max'),
                          onTap: () => _showOptionPicker<int>(
                            title: 'Max Skill',
                            options: List.generate(10, (i) => i + 1)
                                .where((value) => _skillMin == null || value >= _skillMin!)
                                .toList(),
                            onSelected: (v) => setState(() => _skillMax = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('No. of Participants', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
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
                              _participantsCtrl.value = const TextEditingValue(
                                text: '1',
                                selection: TextSelection.collapsed(offset: 1),
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
                  const SizedBox(height: 14),
                  const Text('Fee', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _feeCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Free',
                    ),
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
                  const Text('Title', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(hintText: 'Name your event'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 14),
                  const Text('Description', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Explain about the event/rules and regulation/casual/Competition.',
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
                      options: const [
                        'Any',
                        'Male',
                        'Female',
                      ],
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
                      options: const [
                        'Host only',
                        'Host & Play',
                      ],
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
                      onSelected: (v) => setState(() => _cancellationFreeze = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Repeat',
                    style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _showRepeatPicker(context),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(_repeat ?? 'None')),
                          const Icon(Icons.keyboard_arrow_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Default is None. You can still set repeat for reference.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w600,
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
                        border: Border.all(color: const Color(0xFFE3E7EE), style: BorderStyle.solid),
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
                      if (_thumbnailPreviewBytes != null || _thumbnailFileId != null)
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
              ListTile(
                title: Text(o),
                onTap: () => Navigator.pop(ctx, o),
              ),
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

  Future<void> _showRepeatPicker(BuildContext context) async {
    const options = [
      'None',
      'Next 2 Weeks',
      'Next 3 Weeks',
      'Next 4 Weeks',
    ];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              ListTile(
                title: Text(o),
                onTap: () => Navigator.pop(ctx, o),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() => _repeat = chosen);
    }
  }

  Future<void> _showOptionPicker<T>({
    required String title,
    required List<T> options,
    required ValueChanged<T> onSelected,
  }) async {
    final chosen = await showModalBottomSheet<T>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            for (final o in options)
              ListTile(
                title: Text(o.toString()),
                onTap: () => Navigator.pop(ctx, o),
              ),
          ],
        ),
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
    final feeText = _feeCtrl.text.trim();
    final fee = feeText.isEmpty ? 'Free' : feeText;
    final capacity = int.tryParse(_participantsCtrl.text.trim());

    if (startAt == null || durationMinutes == null || sport.isEmpty || location.isEmpty || capacity == null || capacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill Sport, Date & Time, Duration, Location, and Participants.')),
      );
      return;
    }

    final skillMin = _skillMin;
    final skillMax = _skillMax;
    final skillLevel =
        (skillMin != null && skillMax != null) ? '$skillMin - $skillMax' : (_initialEvent?.skillLevel ?? '—');

    final lat = _latCtrl.text.trim().isEmpty ? null : double.tryParse(_latCtrl.text.trim());
    final lng = _lngCtrl.text.trim().isEmpty ? null : double.tryParse(_lngCtrl.text.trim());

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
      'entryFeeLabel': fee,
      'skillLevel': skillLevel,
      'description': _descriptionCtrl.text.trim(),
      'creatorId': _initialEvent?.creatorId ?? currentUserId,
      'category': _category,
      'privacy': _privacy,
      'gender': _gender,
      'ageGroup': _ageGroup,
      'hostRole': _hostRole,
      'cancellationFreeze': _cancellationFreeze,
      'repeat': _repeat,
      'repeatWeeks': 0,
      'thumbnailFileId': _thumbnailFileId,
    };

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
        final navigator = Navigator.of(context);
        final result = _isEditMode ? 'updated' : 'created';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigator.mounted) {
            navigator.pop(result);
          }
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save event to Appwrite. Check collection attributes/permissions.')),
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
    final picked = await Navigator.of(context).pushNamed(MapPickerScreen.routeName);
    if (!mounted || picked is! MapPickerResult) {
      return;
    }
    setState(() {
      _latCtrl.text = picked.lat.toStringAsFixed(6);
      _lngCtrl.text = picked.lng.toStringAsFixed(6);
      _locationCtrl.text = '${picked.lat.toStringAsFixed(6)}, ${picked.lng.toStringAsFixed(6)}';
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
      return Image.memory(
        _thumbnailPreviewBytes!,
        fit: BoxFit.cover,
      );
    }

    if (_thumbnailFileId != null && _thumbnailFileId!.isNotEmpty) {
      return FutureBuilder<Uint8List>(
        future: AppwriteService.getFileViewBytes(
          bucketId: AppwriteConfig.eventImagesBucketId,
          fileId: _thumbnailFileId!,
        ),
        builder: (context, snap) {
          if (snap.hasData) {
            return Image.memory(
              snap.data!,
              fit: BoxFit.cover,
            );
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
          Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.black.withValues(alpha: 0.35)),
          const SizedBox(height: 8),
          Text(
            'Insert Thumbnail',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
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

class _DropdownField<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final String? label;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.value,
    required this.hint,
    this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<T>(
          value: value,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          hint: Text(hint),
          items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString()))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TapPickerField extends StatelessWidget {
  final String? label;
  final String value;
  final VoidCallback onTap;

  const _TapPickerField({
    required this.value,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
