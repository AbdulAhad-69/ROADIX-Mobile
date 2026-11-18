import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'mechanic_home_screen.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/vehicle_editor_sheet.dart';
import '../widgets/contact_editor_sheet.dart';
import '../widgets/wallet_editor_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _db = SupabaseService();

  bool _isLoading = true;
  String _userName = 'Loading...';
  String _userPhone = '';
  bool _isNidVerified = false;

  List<Map<String, dynamic>> _savedGarage = [];
  List<Map<String, dynamic>> _emergencyContacts = [];
  List<Map<String, dynamic>> _savedWallets = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    try {
      final profile = await _db.getProfile();
      final vehicles = await _db.getVehicles();
      final contacts = await _db.getEmergencyContacts();
      final wallets = await _db.getWallets();

      if (mounted) {
        setState(() {
          if (profile != null) {
            _userName = profile['full_name'] ?? 'Motorist';
            _userPhone = profile['phone'] ?? '';
            _isNidVerified = profile['is_nid_verified'] ?? false;
          }
          _savedGarage = vehicles;
          _emergencyContacts = contacts;
          _savedWallets = wallets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: AppColors.caliperCrimson,
          ),
        );
      }
    }
  }

  // --- Profile Identity Editor ---
  void _openEditProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileSheet(
        currentName: _userName,
        currentPhone: _userPhone,
        onProfileSaved: (newName, newPhone) async {
          setState(() {
            _userName = newName;
            _userPhone = newPhone;
          });
          await _db.updateProfile(fullName: newName, phone: newPhone);
          _loadProfileData();
        },
      ),
    );
  }

  // --- Vehicle Garage CRUD ---
  void _openVehicleEditor([Map<String, dynamic>? vehicle]) {
    final initialVehicle = vehicle != null
        ? {
            'model': vehicle['model']?.toString() ?? '',
            'plate': vehicle['plate']?.toString() ?? '',
            'type': vehicle['type']?.toString() ?? 'Passenger Car',
            'fuel': vehicle['fuel']?.toString() ?? 'Octane',
          }
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VehicleEditorSheet(
        initialVehicle: initialVehicle,
        onSave: (savedData) async {
          if (vehicle != null && vehicle['id'] != null) {
            await _db.updateVehicle(
              vehicleId: vehicle['id'],
              model: savedData['model']!,
              plate: savedData['plate']!,
              type: savedData['type']!,
              fuel: savedData['fuel']!,
            );
          } else {
            await _db.addVehicle(
              model: savedData['model']!,
              plate: savedData['plate']!,
              type: savedData['type']!,
              fuel: savedData['fuel']!,
            );
          }
          _loadProfileData();
        },
        onDelete: vehicle != null
            ? () async {
                await _db.deleteVehicle(vehicle['id']);
                _loadProfileData();
              }
            : null,
      ),
    );
  }

  // --- Emergency Contact CRUD ---
  void _openContactEditor([Map<String, dynamic>? contact]) {
    final initialContact = contact != null
        ? {
            'name': contact['name']?.toString() ?? '',
            'phone': contact['phone']?.toString() ?? '',
            'relation': contact['relation']?.toString() ?? 'Family',
          }
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContactEditorSheet(
        initialContact: initialContact,
        onSave: (savedData) async {
          if (contact != null && contact['id'] != null) {
            await _db.updateEmergencyContact(
              contactId: contact['id'],
              name: savedData['name']!,
              phone: savedData['phone']!,
              relation: savedData['relation']!,
            );
          } else {
            await _db.addEmergencyContact(
              name: savedData['name']!,
              phone: savedData['phone']!,
              relation: savedData['relation']!,
            );
          }
          _loadProfileData();
        },
        onDelete: contact != null
            ? () async {
                await _db.deleteEmergencyContact(contact['id']);
                _loadProfileData();
              }
            : null,
      ),
    );
  }

  // --- MFS Wallet Switcher ---
  void _openWalletEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WalletEditorSheet(
        wallets: _savedWallets
            .map(
              (w) => {
                'id': w['id'],
                'provider': w['provider'],
                'number': w['account_number'],
                'isPrimary': w['is_primary'] == true,
              },
            )
            .toList(),
        onWalletsChanged: (updated) async {
          final primary = updated.firstWhere(
            (w) => w['isPrimary'] == true,
            orElse: () => {},
          );
          if (primary.isNotEmpty && primary['id'] != null) {
            await _db.setPrimaryWallet(primary['id']);
          }
          _loadProfileData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.porcelainBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.caliperCrimson),
        ),
      );
    }

    final primaryWallet = _savedWallets.firstWhere(
      (w) => w['is_primary'] == true,
      orElse: () => _savedWallets.isNotEmpty
          ? _savedWallets.first
          : {'provider': 'bKash', 'account_number': 'None linked'},
    );

    return Scaffold(
      backgroundColor: AppColors.porcelainBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Motorist Profile',
                style: TextStyle(
                  color: AppColors.chassisText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Cloud-synced verification, garage, and emergency dispatch',
                style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Profile Identity Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slateBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.crimsonLight,
                      child: const Icon(
                        Icons.person,
                        color: AppColors.caliperCrimson,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.chassisText,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (_isNidVerified) ...[
                                const SizedBox(width: 5),
                                const Icon(
                                  Icons.verified,
                                  color: AppColors.emeraldGps,
                                  size: 15,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userPhone,
                            style: const TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _isNidVerified
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _isNidVerified
                                  ? 'NID VERIFIED MOTORIST'
                                  : 'UNVERIFIED MOTORIST',
                              style: TextStyle(
                                color: _isNidVerified
                                    ? const Color(0xFF475569)
                                    : AppColors.caliperCrimson,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.slateMuted,
                        size: 20,
                      ),
                      onPressed: _openEditProfile,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Digital Garage Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DIGITAL GARAGE (VEHICLES)',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  InkWell(
                    onTap: () => _openVehicleEditor(),
                    child: const Text(
                      '+ Add Vehicle',
                      style: TextStyle(
                        color: AppColors.caliperCrimson,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_savedGarage.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slateBorder),
                  ),
                  child: const Center(
                    child: Text(
                      'No vehicles saved in garage yet.',
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              else
                ..._savedGarage.map((car) {
                  final isMotorcycle = car['type'] == 'Motorcycle';
                  return InkWell(
                    onTap: () => _openVehicleEditor(car),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slateBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.porcelainBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isMotorcycle
                                  ? Icons.two_wheeler
                                  : Icons.directions_car,
                              color: AppColors.caliperCrimson,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  car['model'] ?? 'Unknown Vehicle',
                                  style: const TextStyle(
                                    color: AppColors.chassisText,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${car['plate']} • ${car['fuel']}',
                                  style: const TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.edit_outlined,
                            color: AppColors.slateMuted,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              // Emergency Broadcast Contacts Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'EMERGENCY BROADCAST CONTACTS',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  InkWell(
                    onTap: () => _openContactEditor(),
                    child: const Text(
                      '+ Add Contact',
                      style: TextStyle(
                        color: AppColors.caliperCrimson,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Automatically alerted with live GPS during 999 panic calls',
                style: TextStyle(color: AppColors.slateMuted, fontSize: 10.5),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.slateBorder),
                ),
                child: Column(
                  children: _emergencyContacts.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final contact = entry.value;
                    final bool isLast = idx == _emergencyContacts.length - 1;
                    final contactName =
                        contact['name']?.toString() ?? 'Contact';

                    return Column(
                      children: [
                        ListTile(
                          onTap: () => _openContactEditor(contact),
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.crimsonLight,
                            child: Text(
                              contactName.isNotEmpty ? contactName[0] : '?',
                              style: const TextStyle(
                                color: AppColors.caliperCrimson,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            contactName,
                            style: const TextStyle(
                              color: AppColors.chassisText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            contact['phone']?.toString() ?? '',
                            style: const TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  contact['relation']?.toString() ?? 'Family',
                                  style: const TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.edit_outlined,
                                color: AppColors.slateMuted,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          const Divider(
                            color: AppColors.slateBorder,
                            height: 1,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // Payment Wallets
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PAYMENT & MFS WALLETS',
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  InkWell(
                    onTap: _openWalletEditor,
                    child: const Text(
                      'Manage Wallets',
                      style: TextStyle(
                        color: AppColors.caliperCrimson,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              InkWell(
                onTap: _openWalletEditor,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.slateBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2136E).withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                (primaryWallet['provider']?.toString() ?? 'bK')
                                    .substring(0, 2),
                                style: const TextStyle(
                                  color: Color(0xFFE2136E),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${primaryWallet['provider']} (${primaryWallet['account_number']})',
                                style: const TextStyle(
                                  color: AppColors.chassisText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Primary authorization method',
                                style: TextStyle(
                                  color: AppColors.slateMuted,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.emeraldGps,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Mechanic Workshop Mode Switcher Card
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MechanicHomeScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.slateBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.caliperCrimson.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.build,
                              color: AppColors.caliperCrimson,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Technician Console',
                                style: TextStyle(
                                  color: AppColors.chassisText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'On-duty toggle, specializations & offers',
                                style: TextStyle(
                                  color: AppColors.slateMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.slateMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Log Out Action
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    await _db.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.logout,
                    color: AppColors.caliperCrimson,
                    size: 16,
                  ),
                  label: const Text(
                    'Log Out & Return to Login',
                    style: TextStyle(
                      color: AppColors.caliperCrimson,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
