import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'roadix_avatar.dart';

class EditProfileSheet extends StatefulWidget {
  final String currentName;
  final String currentPhone;
  final String? currentAvatarUrl;
  final FutureOr<void> Function(String newName, String newPhone, String? newAvatarUrl)?
      onSave;
  final FutureOr<void> Function(String newName, String newPhone)?
      onProfileSaved;
  final Future<String> Function(Uint8List bytes, String ext)? onUploadPhoto;
  final Future<XFile?> Function(ImageSource source)? pickImageOverride;

  const EditProfileSheet({
    super.key,
    required this.currentName,
    required this.currentPhone,
    this.currentAvatarUrl,
    this.onSave,
    this.onProfileSaved,
    this.onUploadPhoto,
    this.pickImageOverride,
  });

  static const List<String> avatarPresets = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
  ];

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _avatarUrlController;
  final ImagePicker _picker = ImagePicker();

  String? _selectedAvatarUrl;
  Uint8List? _localPreviewBytes;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _phoneController = TextEditingController(text: widget.currentPhone);
    _selectedAvatarUrl = widget.currentAvatarUrl;
    final displayUrl = (_selectedAvatarUrl != null &&
            !_selectedAvatarUrl!.startsWith('data:'))
        ? _selectedAvatarUrl!
        : '';
    _avatarUrlController = TextEditingController(text: displayUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    if (_isUploadingPhoto || _isSaving) return;
    HapticFeedback.selectionClick();
    setState(() {
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final picked = widget.pickImageOverride != null
          ? await widget.pickImageOverride!(source)
          : await _picker.pickImage(
              source: source,
              maxWidth: 720,
              maxHeight: 720,
              imageQuality: 84,
            );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final candidate = picked.name.isNotEmpty ? picked.name : picked.path;
      final nameParts = candidate.split('.');
      final ext = nameParts.length > 1
          ? nameParts.last.toLowerCase()
          : ((picked.mimeType?.toLowerCase().contains('png') ?? false)
              ? 'png'
              : 'jpg');

      if (mounted) {
        setState(() {
          _localPreviewBytes = bytes;
          _isUploadingPhoto = true;
          _statusMessage = 'Uploading profile photo...';
        });
      }

      final uploadedUrl = widget.onUploadPhoto != null
          ? await widget.onUploadPhoto!(bytes, ext)
          : await SupabaseService().uploadProfileAvatar(
              bytes,
              fileExtension: ext,
            );

      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = false;
        _selectedAvatarUrl = uploadedUrl;
        if (!uploadedUrl.startsWith('data:')) {
          _avatarUrlController.text = uploadedUrl;
        }
        _statusMessage = 'Photo uploaded cleanly.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = false;
        _statusMessage = null;
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('StateError: ', '');
      });
    }
  }

  void _showPhotoSourceChooser() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload Profile Photo',
                style: TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.caliperCrimson,
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.chassisText,
                ),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving || _isUploadingPhoto) return;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final urlText = _avatarUrlController.text.trim();
    final effectiveAvatar =
        urlText.isNotEmpty ? urlText : _selectedAvatarUrl;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.onSave != null) {
        await widget.onSave!(name, phone, effectiveAvatar);
      } else if (widget.onProfileSaved != null) {
        await widget.onProfileSaved!(name, phone);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.slateBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Motorist Details',
                style: TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a curated avatar, upload a photo, or update your contact phone',
                style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Profile Avatar Preview + Camera Badge
              Center(
                child: Semantics(
                  button: true,
                  label: 'Change profile picture',
                  child: GestureDetector(
                    onTap: _isUploadingPhoto ? null : _showPhotoSourceChooser,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        RoadixAvatar(
                          displayName: _nameController.text.isNotEmpty
                              ? _nameController.text
                              : widget.currentName,
                          avatarUrl: _selectedAvatarUrl,
                          localBytes: _localPreviewBytes,
                          radius: 38,
                        ),
                        if (_isUploadingPhoto)
                          const Positioned.fill(
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.caliperCrimson,
                                ),
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.caliperCrimson,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(
                      color: AppColors.emeraldDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.crimsonLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.crimsonBorder),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.crimsonHover,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),
              const Text(
                'CHOOSE AVATAR PRESET',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),

              // Preset Avatars Strip (keeps InkWell indices first for compatibility)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Reset to default monogram avatar',
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _localPreviewBytes = null;
                            _selectedAvatarUrl = null;
                            _avatarUrlController.clear();
                            _statusMessage = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.porcelainBg,
                            border: Border.all(
                              color: (_selectedAvatarUrl == null &&
                                      _localPreviewBytes == null)
                                  ? AppColors.caliperCrimson
                                  : AppColors.slateBorder,
                              width: (_selectedAvatarUrl == null &&
                                      _localPreviewBytes == null)
                                  ? 2.5
                                  : 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.person_outline,
                              size: 20,
                              color: (_selectedAvatarUrl == null &&
                                      _localPreviewBytes == null)
                                  ? AppColors.caliperCrimson
                                  : AppColors.slateMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...EditProfileSheet.avatarPresets.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final presetUrl = entry.value;
                      final isSelected = _selectedAvatarUrl == presetUrl;
                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: 'Avatar preset ${idx + 1}',
                        child: InkWell(
                          key: Key('avatar_preset_$idx'),
                          onTap: () {
                            setState(() {
                              _localPreviewBytes = null;
                              _selectedAvatarUrl = presetUrl;
                              _avatarUrlController.text = presetUrl;
                              _statusMessage = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.caliperCrimson
                                    : AppColors.slateBorder,
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.network(
                                presetUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.person,
                                  color: AppColors.slateMuted,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                'UPLOAD YOUR OWN PHOTO',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const Key('upload_avatar_gallery_btn'),
                        onPressed: _isUploadingPhoto
                            ? null
                            : () => _pickAndUploadAvatar(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const Key('upload_avatar_camera_btn'),
                        onPressed: _isUploadingPhoto
                            ? null
                            : () => _pickAndUploadAvatar(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Camera'),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Text(
                'OR AVATAR IMAGE URL',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _avatarUrlController,
                style: const TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'https://example.com/avatar.jpg',
                  isDense: true,
                  prefixIcon: Icon(Icons.link, size: 18, color: AppColors.slateMuted),
                ),
                onChanged: (val) {
                  setState(() {
                    _localPreviewBytes = null;
                    _selectedAvatarUrl =
                        val.trim().isNotEmpty ? val.trim() : null;
                  });
                },
              ),

              const SizedBox(height: 14),
              const Text(
                'MOTORIST NAME',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppColors.slateMuted,
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                'PHONE NUMBER',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: AppColors.slateMuted,
                  ),
                ),
              ),

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_isSaving || _isUploadingPhoto) ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('SAVE CHANGES'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
