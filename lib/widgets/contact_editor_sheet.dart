import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ContactEditorSheet extends StatefulWidget {
  final Map<String, String>? initialContact;
  final Function(Map<String, String> contact) onSave;
  final VoidCallback? onDelete;

  const ContactEditorSheet({
    super.key,
    this.initialContact,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends State<ContactEditorSheet> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late String _selectedRelation;

  final List<String> _relations = ['Primary', 'Family', 'Spouse', 'Roadside Buddy'];

  bool get _isEditing => widget.initialContact != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialContact?['name'] ?? '');
    _phoneController = TextEditingController(text: widget.initialContact?['phone'] ?? '');
    _selectedRelation = widget.initialContact?['relation'] ?? 'Family';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both name and contact number.'),
          backgroundColor: AppColors.caliperCrimson,
        ),
      );
      return;
    }

    widget.onSave({
      'name': name,
      'phone': phone,
      'relation': _selectedRelation,
    });
    Navigator.pop(context);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Edit Emergency Contact' : 'Add Broadcast Contact',
                    style: const TextStyle(
                      color: AppColors.chassisText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (_isEditing && widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.caliperCrimson, size: 22),
                      onPressed: () {
                        widget.onDelete!();
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'CONTACT NAME',
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
                style: const TextStyle(color: AppColors.chassisText, fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Mom, Shafin',
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
                  hintText: '+880 1711-000000',
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

              const SizedBox(height: 14),

              const Text(
                'RELATIONSHIP TAG',
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _relations.map((rel) {
                  final isSelected = _selectedRelation == rel;
                  return ChoiceChip(
                    label: Text(rel),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedRelation = rel);
                    },
                    selectedColor: AppColors.caliperCrimson,
                    backgroundColor: AppColors.porcelainBg,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.chassisText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? AppColors.caliperCrimson : AppColors.slateBorder,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.caliperCrimson,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _isEditing ? 'UPDATE CONTACT' : 'SAVE BROADCAST CONTACT',
                    style: const TextStyle(
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