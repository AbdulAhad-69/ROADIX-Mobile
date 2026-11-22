import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EditProfileSheet extends StatefulWidget {
  final String currentName;
  final String currentPhone;
  final String? currentAvatarUrl;
  final Function(String newName, String newPhone)? onProfileSaved;
  final Function(String newName, String newPhone, String? newAvatarUrl)? onSave;

  /// Curated authentic driver and motorist profile presets
  static const List<String> avatarPresets = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
    'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150',
  ];

  const EditProfileSheet({
    super.key,
    required this.currentName,
    required this.currentPhone,
    this.currentAvatarUrl,
    this.onProfileSaved,
    this.onSave,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _avatarUrlController;
  String? _selectedAvatarUrl;

  @override
  void initState() {
    super.initState();
    _selectedAvatarUrl = widget.currentAvatarUrl;
    _nameController = TextEditingController(text: widget.currentName);
    _phoneController = TextEditingController(text: widget.currentPhone);
    _avatarUrlController = TextEditingController(text: widget.currentAvatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final customUrl = _avatarUrlController.text.trim();
    final effectiveAvatar = customUrl.isNotEmpty ? customUrl : _selectedAvatarUrl;

    if (name.isNotEmpty) {
      if (widget.onSave != null) {
        widget.onSave!(name, phone, effectiveAvatar);
      }
      if (widget.onProfileSaved != null) {
        widget.onProfileSaved!(name, phone);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameText = _nameController.text.trim();
    final initialLetter = nameText.isNotEmpty ? nameText[0].toUpperCase() : 'M';
    final hasAvatar = _selectedAvatarUrl != null && _selectedAvatarUrl!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                'Update your account identity, profile photo, and emergency phone',
                style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
              ),
              const SizedBox(height: 16),

              // Profile Avatar Section
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.crimsonLight,
                      backgroundImage: hasAvatar
                          ? (_selectedAvatarUrl!.startsWith('http')
                              ? NetworkImage(_selectedAvatarUrl!)
                              : AssetImage(_selectedAvatarUrl!) as ImageProvider)
                          : null,
                      onBackgroundImageError: hasAvatar
                          ? (e, s) {
                              // Gracefully handle image load failure
                            }
                          : null,
                      child: !hasAvatar
                          ? Text(
                              initialLetter,
                              style: const TextStyle(
                                color: AppColors.caliperCrimson,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.caliperCrimson,
                        shape: BoxShape.circle,
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
              const SizedBox(height: 14),

              const Text(
                'CHOOSE AVATAR PRESET',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              // Preset Avatars Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Reset to Default (Initials)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAvatarUrl = null;
                          _avatarUrlController.clear();
                        });
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.porcelainBg,
                          border: Border.all(
                            color: _selectedAvatarUrl == null
                                ? AppColors.caliperCrimson
                                : AppColors.slateBorder,
                            width: _selectedAvatarUrl == null ? 2.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.person_outline,
                            size: 20,
                            color: _selectedAvatarUrl == null
                                ? AppColors.caliperCrimson
                                : AppColors.slateMuted,
                          ),
                        ),
                      ),
                    ),
                    // Presets
                    ...EditProfileSheet.avatarPresets.map((presetUrl) {
                      final isSelected = _selectedAvatarUrl == presetUrl;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAvatarUrl = presetUrl;
                            _avatarUrlController.text = presetUrl;
                          });
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
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
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.person,
                                color: AppColors.slateMuted,
                                size: 20,
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
                'OR AVATAR IMAGE URL',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _avatarUrlController,
                style: const TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'https://example.com/avatar.jpg',
                  hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
                  filled: true,
                  fillColor: AppColors.porcelainBg,
                  isDense: true,
                  prefixIcon: const Icon(Icons.link, size: 18, color: AppColors.slateMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _selectedAvatarUrl = val.trim().isNotEmpty ? val.trim() : null;
                  });
                },
              ),

              const SizedBox(height: 14),

              const Text(
                'MOTORIST NAME',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.porcelainBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 14),

              const Text(
                'PHONE NUMBER',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                style: const TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.porcelainBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.slateBorder),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caliperCrimson,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'SAVE CHANGES',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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
}
