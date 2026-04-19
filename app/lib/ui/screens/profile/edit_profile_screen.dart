import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appwrite/appwrite.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../data/height_display_repository.dart';
import '../../../data/profile_repository.dart';
import '../../../models/user_profile.dart';
import '../../../utils/height_display.dart';

class EditProfileScreen extends StatefulWidget {
  static const routeName = '/profile/edit';

  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _heightCmCtrl;
  late final TextEditingController _heightFeetCtrl;
  late final TextEditingController _heightInchesCtrl;
  late final TextEditingController _emergencyCtrl;
  late final TextEditingController _bioCtrl;

  UserProfile? _profile;
  String _skillLevel = 'Beginner';
  bool? _useImperialHeight;
  bool _hasInit = false;
  bool _isSaving = false;
  Uint8List? _avatarPreviewBytes;
  String? _avatarFileId;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasInit) return;
    _hasInit = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    _nameCtrl = TextEditingController();
    _heightCmCtrl = TextEditingController();
    _heightFeetCtrl = TextEditingController();
    _heightInchesCtrl = TextEditingController();
    _emergencyCtrl = TextEditingController();
    _bioCtrl = TextEditingController();

    if (args is UserProfile) {
      _profile = args;
      _nameCtrl.text = args.username;
      _heightCmCtrl.text = args.heightCm?.toString() ?? '';
      _emergencyCtrl.text = args.emergencyContact;
      _bioCtrl.text = args.bio;
      _skillLevel = _normalizeSkillLevelLabel(args.skillLevel);
      _avatarFileId = args.avatarFileId;
      unawaited(_applyHeightPreferenceFromProfile(args));
    } else {
      unawaited(_load());
    }
  }

  Future<void> _applyHeightPreferenceFromProfile(UserProfile p) async {
    final imperial = await heightDisplayRepository().getUseImperial();
    if (!mounted) {
      return;
    }
    if (imperial && p.heightCm != null) {
      final parts = cmToFeetInchParts(p.heightCm!);
      _heightFeetCtrl.text = '${parts.feet}';
      _heightInchesCtrl.text = '${parts.inches}';
    }
    setState(() => _useImperialHeight = imperial);
  }

  Future<void> _load() async {
    final p = await profileRepository().getMyProfile();
    final imperial = await heightDisplayRepository().getUseImperial();
    if (!mounted) {
      return;
    }
    setState(() => _profile = p);
    _nameCtrl.text = p.username;
    _heightCmCtrl.text = p.heightCm?.toString() ?? '';
    _emergencyCtrl.text = p.emergencyContact;
    _bioCtrl.text = p.bio;
    _avatarFileId = p.avatarFileId;
    _skillLevel = _normalizeSkillLevelLabel(p.skillLevel);
    if (imperial && p.heightCm != null) {
      final parts = cmToFeetInchParts(p.heightCm!);
      _heightFeetCtrl.text = '${parts.feet}';
      _heightInchesCtrl.text = '${parts.inches}';
    } else {
      _heightFeetCtrl.clear();
      _heightInchesCtrl.clear();
    }
    setState(() => _useImperialHeight = imperial);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCmCtrl.dispose();
    _heightFeetCtrl.dispose();
    _heightInchesCtrl.dispose();
    _emergencyCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: _pickAvatar,
                  child: _AvatarPreviewCircle(
                    bytes: _avatarPreviewBytes,
                    fileId: _avatarFileId ?? _profile?.avatarFileId,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Username', style: TextStyle(color: Color(0xFF4A5A66), fontSize: 16)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your username' : null,
              ),
              const SizedBox(height: 14),
              ..._buildHeightSection(),
              const Text('Skill Level', style: TextStyle(color: Color(0xFF4A5A66), fontSize: 16)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _isSaving
                    ? null
                    : () async {
                        final chosen = await showModalBottomSheet<String>(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final o in _skillLevelOptions)
                                  ListTile(
                                    title: Text(o),
                                    onTap: () => Navigator.pop(ctx, o),
                                  ),
                              ],
                            ),
                          ),
                        );
                        if (chosen != null && mounted) {
                          setState(() => _skillLevel = chosen);
                        }
                      },
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _skillLevel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Emergency Contact', style: TextStyle(color: Color(0xFF4A5A66), fontSize: 16)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emergencyCtrl,
                decoration: const InputDecoration(hintText: '+673 XXXXXX'),
              ),
              const SizedBox(height: 14),
              const Text('Bio', style: TextStyle(color: Color(0xFF4A5A66), fontSize: 16)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bioCtrl,
                decoration: const InputDecoration(hintText: 'Describe Yourself'),
                minLines: 4,
                maxLines: 5,
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed:
                    _isSaving || _useImperialHeight == null ? null : _onEdit,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Edit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const TextStyle _heightLabelStyle = TextStyle(
    color: Color(0xFF4A5A66),
    fontSize: 16,
  );

  List<Widget> _buildHeightSection() {
    if (_useImperialHeight == null) {
      return [
        const Text('Height', style: _heightLabelStyle),
        const SizedBox(height: 6),
        const SizedBox(
          height: 52,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        const SizedBox(height: 14),
      ];
    }
    if (_useImperialHeight!) {
      return [
        const Text('Height (ft / in)', style: _heightLabelStyle),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _heightFeetCtrl,
                decoration: const InputDecoration(hintText: 'ft'),
                keyboardType: TextInputType.number,
                validator: _validateFeetInchesPair,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _heightInchesCtrl,
                decoration: const InputDecoration(hintText: 'in'),
                keyboardType: TextInputType.number,
                validator: _validateFeetInchesPair,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ];
    }
    return [
      const Text('Height (cm)', style: _heightLabelStyle),
      const SizedBox(height: 6),
      TextFormField(
        controller: _heightCmCtrl,
        decoration: const InputDecoration(hintText: 'e.g. 175'),
        keyboardType: TextInputType.number,
        validator: _validateHeightCm,
      ),
      const SizedBox(height: 14),
    ];
  }

  String? _validateHeightCm(String? v) {
    final txt = (v ?? '').trim();
    if (txt.isEmpty) {
      return null;
    }
    final n = int.tryParse(txt);
    if (n == null) {
      return 'Invalid height';
    }
    if (n < 50 || n > 250) {
      return '50–250';
    }
    return null;
  }

  String? _validateFeetInchesPair(String? _) {
    final ft = _heightFeetCtrl.text.trim();
    final inch = _heightInchesCtrl.text.trim();
    if (ft.isEmpty && inch.isEmpty) {
      return null;
    }
    final fi = int.tryParse(ft);
    final ii = int.tryParse(inch);
    if (fi == null || ii == null) {
      return 'Enter feet and inches (whole numbers)';
    }
    if (ii < 0 || ii > 11) {
      return 'Inches must be 0–11';
    }
    final cm = feetInchPartsToCm(fi, ii);
    if (cm == null || cm < 50 || cm > 250) {
      return 'Height must be between 50 and 250 cm';
    }
    return null;
  }

  int? _resolveHeightCmForSave() {
    if (_useImperialHeight != true) {
      final t = _heightCmCtrl.text.trim();
      if (t.isEmpty) {
        return null;
      }
      return int.tryParse(t);
    }
    final ft = _heightFeetCtrl.text.trim();
    final inch = _heightInchesCtrl.text.trim();
    if (ft.isEmpty && inch.isEmpty) {
      return null;
    }
    final fi = int.tryParse(ft);
    final ii = int.tryParse(inch);
    if (fi == null || ii == null) {
      return null;
    }
    return feetInchPartsToCm(fi, ii);
  }

  Future<void> _onEdit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final base = _profile ?? await profileRepository().getMyProfile();
    final updated = base.copyWith(
      username: _nameCtrl.text.trim(),
      heightCm: _resolveHeightCmForSave(),
      skillLevel: _skillLevel,
      emergencyContact: _emergencyCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      avatarFileId: _avatarFileId ?? base.avatarFileId,
    );

    setState(() => _isSaving = true);
    try {
      await profileRepository().saveMyProfile(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save profile to Appwrite. Check attributes/permissions.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose Photo'),
              onTap: () => Navigator.of(ctx).pop('pick'),
            ),
            if ((_avatarFileId ?? _profile?.avatarFileId)?.isNotEmpty == true)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove Photo'),
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
          ],
        ),
      ),
    );

    if (action == 'remove') {
      setState(() {
        _avatarFileId = '';
        _avatarPreviewBytes = null;
      });
      return;
    }
    if (action != 'pick') {
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 720,
    );
    if (picked == null) {
      return;
    }

    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _avatarPreviewBytes = bytes);
      final uploadFilename = _normalizeImageFileName(picked.name);

      final uploaded = await AppwriteService.uploadFile(
        bucketId: AppwriteConfig.profileImagesBucketId,
        path: picked.path,
        bytes: bytes,
        filename: uploadFilename,
      );
      if (!mounted) return;
      setState(() => _avatarFileId = uploaded.$id);
    } on AppwriteException catch (e) {
      if (!mounted) return;
      final message = e.message?.toLowerCase() ?? '';
      final extensionHint = message.contains('extension')
          ? ' Allowed file types in your Appwrite bucket may not include this image type.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${e.message ?? 'Failed to upload profile photo.'}$extensionHint Bucket: ${AppwriteConfig.profileImagesBucketId}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to upload profile photo. Bucket: ${AppwriteConfig.profileImagesBucketId}',
          ),
        ),
      );
    }
  }

  String _normalizeImageFileName(String originalName) {
    var name = originalName.trim();
    if (name.isEmpty) {
      name = 'profile_photo.jpg';
    }
    final lastDot = name.lastIndexOf('.');
    if (lastDot <= 0 || lastDot == name.length - 1) {
      name = '$name.jpg';
    }
    return name;
  }
}

const List<String> _skillLevelOptions = <String>[
  'Beginner',
  'Novice',
  'Intermediate',
  'Advanced',
  'Pro/Master',
];

String _normalizeSkillLevelLabel(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text == '—') {
    return 'Beginner';
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
    final score = matches.last;
    if (score <= 2) return 'Beginner';
    if (score <= 4) return 'Novice';
    if (score <= 6) return 'Intermediate';
    if (score <= 8) return 'Advanced';
    return 'Pro/Master';
  }
  return text;
}

class _AvatarPreviewCircle extends StatelessWidget {
  final Uint8List? bytes;
  final String? fileId;

  const _AvatarPreviewCircle({required this.bytes, required this.fileId});

  @override
  Widget build(BuildContext context) {
    Widget inner;

    if (bytes != null) {
      inner = Image.memory(bytes!, fit: BoxFit.cover);
    } else if (fileId != null && fileId!.isNotEmpty) {
      inner = FutureBuilder<Uint8List>(
        future: AppwriteService.getFileViewBytes(
          bucketId: AppwriteConfig.profileImagesBucketId,
          fileId: fileId!,
        ),
        builder: (context, snap) {
          if (snap.hasData) {
            return Image.memory(snap.data!, fit: BoxFit.cover);
          }
          return const Center(child: Text('🏃', style: TextStyle(fontSize: 40)));
        },
      );
    } else {
      inner = const Center(child: Text('🏃', style: TextStyle(fontSize: 40)));
    }

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(45),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }
}

