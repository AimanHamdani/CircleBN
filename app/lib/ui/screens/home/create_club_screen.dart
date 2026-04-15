import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appwrite/appwrite.dart';

import '../../../appwrite/appwrite_config.dart';
import '../../../appwrite/appwrite_service.dart';
import '../../../auth/current_user.dart';
import '../../../data/club_member_repository.dart';
import '../../../data/sample_clubs.dart';
import '../../../models/club.dart';

class CreateClubScreen extends StatefulWidget {
  static const routeName = '/create-club';

  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  final _imagePicker = ImagePicker();
  Uint8List? _clubPreviewBytes;
  String? _thumbnailFileId;

  Set<String> _selectedSports = <String>{};

  String _privacy = 'Public';
  int _memberLimit = 20;
  bool _approvalRequired = true;
  String _whoCanSendMessages = 'Everyone';

  bool _isSubmitting = false;

  bool _didInitFromRoute = false;
  bool _isEditMode = false;
  bool _canEdit = true;
  bool _checkingAccess = false;
  Club? _editingClub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitFromRoute) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Club) {
      _isEditMode = true;
      _editingClub = args;
      _canEdit = args.creatorId != null && args.creatorId == currentUserId;
      _applyClubToForm(args);

      if (!_canEdit && !_checkingAccess) {
        _checkingAccess = true;
        clubMemberRepository()
            .isAdmin(clubId: args.id, userId: currentUserId)
            .then((isAdmin) {
              if (!mounted) return;
              setState(() => _canEdit = isAdmin);

              if (!isAdmin) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Only admins can edit this club.'),
                    ),
                  );
                  Navigator.of(context).pop();
                });
              }
            })
            .whenComplete(() {
              if (!mounted) return;
              setState(() => _checkingAccess = false);
            });
      }
    }

    _didInitFromRoute = true;
  }

  void _applyClubToForm(Club club) {
    _nameCtrl.text = club.name;
    _descriptionCtrl.text = club.description;
    _locationCtrl.text = club.location;
    _privacy = club.privacy.isNotEmpty ? club.privacy : 'Public';
    _memberLimit = club.memberLimit;
    _approvalRequired = club.approvalRequired;
    _whoCanSendMessages = club.whoCanSendMessages.isNotEmpty
        ? club.whoCanSendMessages
        : 'Everyone';
    _selectedSports = {...club.sports};
    _thumbnailFileId = club.thumbnailFileId;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleText = _isEditMode ? 'Edit Club' : 'Create Club';
    final submitText = _isEditMode ? 'Save Changes' : 'Create Club';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              _SectionCard(
                title: 'CLUB PHOTO',
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: (!_canEdit || _isSubmitting)
                          ? null
                          : _pickClubPhoto,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE3E7EE)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildClubPhoto(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_thumbnailFileId != null || _clubPreviewBytes != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: (!_canEdit || _isSubmitting)
                              ? null
                              : () {
                                  setState(() {
                                    _thumbnailFileId = null;
                                    _clubPreviewBytes = null;
                                  });
                                },
                          child: const Text('Remove'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'CLUB INFO',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. FC Velocity',
                      ),
                      validator: (v) {
                        final txt = (v ?? '').trim();
                        if (txt.isEmpty) return 'Club name is required';
                        return null;
                      },
                      enabled: !_isSubmitting && _canEdit,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionCtrl,
                      maxLines: 4,
                      minLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Tell people what your club is about...',
                      ),
                      enabled: !_isSubmitting && _canEdit,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: (!_canEdit || _isSubmitting)
                            ? null
                            : () => _showSportsPicker(context),
                        child: const Text('Choose Sports'),
                      ),
                    ),
                    if (_selectedSports.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedSports
                            .map(
                              (s) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'SETTINGS',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PickerRow(
                      label: 'Privacy',
                      value: _privacy,
                      onTap: (!_canEdit || _isSubmitting)
                          ? null
                          : () => _showOptionPicker<String>(
                              context,
                              'Privacy',
                              const ['Public', 'Private'],
                              (v) => setState(() => _privacy = v),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _MemberLimitRow(
                      memberLimit: _memberLimit,
                      onChanged: (!_canEdit || _isSubmitting)
                          ? (_) {}
                          : (v) => setState(() => _memberLimit = v),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      value: _approvalRequired,
                      onChanged: (!_canEdit || _isSubmitting)
                          ? null
                          : (v) => setState(() => _approvalRequired = v),
                      title: const Text('Approval required'),
                      subtitle: const Text('Members must be approved to join'),
                    ),
                    const SizedBox(height: 4),
                    _PickerRow(
                      label: 'Who can send messages',
                      value: _whoCanSendMessages,
                      onTap: (!_canEdit || _isSubmitting)
                          ? null
                          : () => _showOptionPicker<String>(
                              context,
                              'Who can send messages',
                              const [
                                'Everyone',
                                'Admins only',
                                'Admins & moderators',
                              ],
                              (v) => setState(() => _whoCanSendMessages = v),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'LOCATION (optional)',
                child: TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Home base / city',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (!_canEdit || _isSubmitting) ? null : _onCreateClub,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(submitText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClubPhoto() {
    if (_clubPreviewBytes != null) {
      return Image.memory(_clubPreviewBytes!, fit: BoxFit.cover);
    }
    if (_thumbnailFileId != null) {
      return Center(
        child: FutureBuilder<Uint8List>(
          future: AppwriteService.getFileViewBytes(
            bucketId: AppwriteConfig.storageBucketId,
            fileId: _thumbnailFileId!,
          ),
          builder: (context, snap) {
            if (snap.hasData) {
              return Image.memory(snap.data!, fit: BoxFit.cover);
            }
            return const Icon(
              Icons.image_outlined,
              size: 40,
              color: Color(0xFF9CA9B0),
            );
          },
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 40,
            color: Color(0xFF9CA9B0),
          ),
          SizedBox(height: 8),
          Text(
            'Tap to upload a club photo',
            style: TextStyle(
              color: Color(0xFF9CA9B0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickClubPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() => _clubPreviewBytes = null);

    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _clubPreviewBytes = bytes);

      final uploaded = await AppwriteService.uploadFile(
        bucketId: AppwriteConfig.storageBucketId,
        path: picked.path,
        bytes: bytes,
        filename: picked.name,
      );

      if (!mounted) return;
      setState(() => _thumbnailFileId = uploaded.$id);
    } on AppwriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to upload club photo.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload club photo.')),
      );
    }
  }

  Future<void> _showSportsPicker(BuildContext context) async {
    final selected = {..._selectedSports};
    final options = SampleData.sports;

    final chosen = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sports',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in options)
                            FilterChip(
                              label: Text(s),
                              selected: selected.contains(s),
                              onSelected: (on) {
                                setLocal(() {
                                  if (on) {
                                    selected.add(s);
                                  } else {
                                    selected.remove(s);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 320) {
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(ctx).pop(_selectedSports),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () =>
                                    Navigator.of(ctx).pop(selected),
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(_selectedSports),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(selected),
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (chosen == null || !mounted) return;
    setState(() => _selectedSports = chosen);
  }

  Future<void> _showOptionPicker<T>(
    BuildContext context,
    String title,
    List<T> options,
    ValueChanged<T> onSelected,
  ) async {
    final chosen = await showModalBottomSheet<T>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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

    if (chosen == null || !mounted) return;
    onSelected(chosen);
  }

  Future<void> _onCreateClub() async {
    if (!_formKey.currentState!.validate()) return;

    if (!AppwriteService.isConfigured ||
        AppwriteConfig.databaseId.isEmpty ||
        AppwriteConfig.clubsCollectionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Appwrite database/clubs collection is not configured.',
          ),
        ),
      );
      return;
    }

    if (_selectedSports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one sport.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'sports': _selectedSports.toList(),
        'privacy': _privacy,
        'memberLimit': _memberLimit,
        'approvalRequired': _approvalRequired,
        'whoCanSendMessages': _whoCanSendMessages,
        'location': _locationCtrl.text.trim(),
        'creatorId': _isEditMode
            ? (_editingClub?.creatorId ?? currentUserId)
            : currentUserId,
        'founderId': _isEditMode
            ? (_editingClub?.founderId ??
                  _editingClub?.creatorId ??
                  currentUserId)
            : currentUserId,
        'coCreatorId': _isEditMode ? _editingClub?.coCreatorId : null,
        'thumbnailFileId': _thumbnailFileId,
      };

      if (_isEditMode) {
        final clubId = _editingClub?.id;
        if (clubId == null || clubId.trim().isEmpty) {
          throw AppwriteException('Missing club id for update.', 400);
        }
        await AppwriteService.updateDocument(
          collectionId: AppwriteConfig.clubsCollectionId,
          documentId: clubId,
          data: data,
        );
      } else {
        final created = await AppwriteService.createDocument(
          collectionId: AppwriteConfig.clubsCollectionId,
          data: data,
        );

        try {
          await clubMemberRepository().joinAsMember(
            clubId: created.$id,
            userId: currentUserId,
            role: ClubMemberRole.admin,
          );
        } catch (_) {
          // Club creation should not fail if membership creation is temporarily blocked.
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppwriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to create club.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to create club.')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA9B0),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _PickerRow({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberLimitRow extends StatefulWidget {
  final int memberLimit;
  final ValueChanged<int> onChanged;

  const _MemberLimitRow({required this.memberLimit, required this.onChanged});

  @override
  State<_MemberLimitRow> createState() => _MemberLimitRowState();
}

class _MemberLimitRowState extends State<_MemberLimitRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.memberLimit.toString());
  }

  @override
  void didUpdateWidget(covariant _MemberLimitRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memberLimit != widget.memberLimit) {
      _ctrl.text = widget.memberLimit.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Member limit',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            IconButton.filledTonal(
              onPressed: widget.memberLimit <= 0
                  ? null
                  : () => widget.onChanged(
                      (widget.memberLimit - 1).clamp(0, 100000),
                    ),
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 120,
              child: TextFormField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  if (n == null) return;
                  widget.onChanged(n.clamp(0, 100000));
                },
              ),
            ),
            IconButton.filledTonal(
              onPressed: () =>
                  widget.onChanged((widget.memberLimit + 1).clamp(0, 100000)),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
