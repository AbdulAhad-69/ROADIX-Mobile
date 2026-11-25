import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/demo_session.dart';
import '../services/supabase_service.dart';
import '../src/core/config/app_config.dart';
import '../src/core/router/app_router.dart';
import 'login_screen.dart';
import 'mechanic_home_screen.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/vehicle_editor_sheet.dart';
import '../widgets/contact_editor_sheet.dart';
import '../widgets/wallet_editor_sheet.dart';
import '../widgets/brand_logo.dart';
import '../widgets/roadix_avatar.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;

  const ProfileScreen({super.key, this.showBackButton = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _db = SupabaseService();

  bool _isLoading = true;
  String _userName = '';
  String _userPhone = '';
  String? _avatarUrl;
  String _userRole = 'motorist';
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
            _userName = (profile['full_name'] as String?)?.trim().isNotEmpty == true
                ? profile['full_name'] as String
                : 'Motorist';
            _userPhone = profile['phone'] as String? ?? '';
            _avatarUrl = profile['avatar_url'] as String?;
            _userRole = profile['role'] as String? ?? 'motorist';
            _isNidVerified = profile['is_nid_verified'] ?? false;
          } else {
            _userName = DemoSession.isActive
                ? DemoSession.fullName
                : 'Guest / Demo Motorist';
            _userPhone = DemoSession.isActive ? DemoSession.phone : '';
            _avatarUrl = DemoSession.isActive ? DemoSession.avatarUrl : null;
            _userRole = DemoSession.isActive ? DemoSession.role : 'motorist';
          }
          _savedGarage = vehicles;
          _emergencyContacts = contacts;
          _savedWallets = wallets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_userName.isEmpty) _userName = 'Guest / Demo Motorist';
          _isLoading = false;
        });
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
        currentAvatarUrl: _avatarUrl,
        onSave: (newName, newPhone, newAvatarUrl) async {
          await _db.updateProfile(
            fullName: newName,
            phone: newPhone,
            avatarUrl: newAvatarUrl,
          );
          if (mounted) {
            setState(() {
              _userName = newName;
              _userPhone = newPhone;
              _avatarUrl = newAvatarUrl;
            });
          }
          await _loadProfileData();
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
        onAddWallet: (provider, number) async {
          await _db.addWallet(provider: provider, accountNumber: number);
          await _loadProfileData();
        },
        onDeleteWallet: (walletId) async {
          await _db.deleteWallet(walletId);
          await _loadProfileData();
        },
        onSetPrimaryWallet: (walletId) async {
          await _db.setPrimaryWallet(walletId);
          await _loadProfileData();
        },
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
              Row(
                children: [
                  if (widget.showBackButton && Navigator.of(context).canPop()) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.chassisText),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Motorist Profile',
                          style: TextStyle(
                            color: AppColors.chassisText,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Cloud-synced verification, garage, and emergency dispatch',
                          style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Profile Identity Card with Prominent Avatar Presentation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.slateBorder),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.caliperCrimson.withAlpha(12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _openEditProfile,
                      borderRadius: BorderRadius.circular(32),
                      child: Semantics(
                        button: true,
                        label: 'Edit profile photo and details',
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.caliperCrimson.withAlpha(60),
                                  width: 1.5,
                                ),
                              ),
                              child: RoadixAvatar(
                                displayName: _userName,
                                avatarUrl: _avatarUrl,
                                radius: 30,
                                showInitialFallback: false,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppColors.caliperCrimson,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
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
                  const Flexible(
                    child: Text(
                      'DIGITAL GARAGE (VEHICLES)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                  final bool isPrimary = car['is_primary'] == true;
                  return InkWell(
                    onTap: () => _openVehicleEditor(car),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPrimary
                              ? AppColors.caliperCrimson.withAlpha(50)
                              : AppColors.slateBorder,
                          width: isPrimary ? 1.4 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isPrimary
                                ? AppColors.caliperCrimson.withAlpha(12)
                                : Colors.black.withAlpha(4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isPrimary
                                  ? AppColors.crimsonLight
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: VehicleIllustration(
                              vehicleType: car['type']?.toString() ?? 'Sedan',
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        car['model'] ?? 'Unknown Vehicle',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.chassisText,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (isPrimary) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.caliperCrimson.withAlpha(20),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'PRIMARY',
                                          style: TextStyle(
                                            color: AppColors.caliperCrimson,
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${car['plate']} • ${car['fuel']}',
                                  style: const TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 10.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.edit_outlined,
                            color: AppColors.slateMuted,
                            size: 17,
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
                  const Flexible(
                    child: Text(
                      'EMERGENCY BROADCAST CONTACTS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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

              if (_emergencyContacts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slateBorder),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Text(
                          'No emergency broadcast contacts configured yet.',
                          style: TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _openContactEditor(),
                          child: const Text(
                            '+ Add First Family Contact',
                            style: TextStyle(
                              color: AppColors.caliperCrimson,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Material(
                  color: AppColors.cardWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.slateBorder),
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
                  const Flexible(
                    child: Text(
                      'PAYMENT & MFS WALLETS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slateBorder),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.chassisText.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: BrandLogo(
                                brand: primaryWallet['provider']?.toString() ?? 'bKash',
                                size: 34,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${primaryWallet['provider']} (${primaryWallet['account_number']})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.chassisText,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  const Text(
                                    'Primary authorization method',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.slateMuted,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.emeraldGps,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              // Mechanic Workshop Mode Switcher Card (shown for verified/registered mechanics or non-prod debug/demo)
              if (_userRole == 'mechanic' ||
                  DemoSession.isActive ||
                  (!AppConfig.isProduction && kDebugMode && !_db.isAuthenticated)) ...[
                const SizedBox(height: 20),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MechanicHomeScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slateBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.crimsonLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.build,
                                  color: AppColors.crimsonHover,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Technician Console',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.chassisText,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'On-duty toggle, specializations & offers',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.slateMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.slateMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Log Out Action
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      await _db.signOut();
                    } catch (e) {
                      debugPrint('Profile Screen signOut error: $e');
                    } finally {
                      if (context.mounted) {
                        navigateRoot(
                          context,
                          route: AppRoutes.login,
                          fallbackWidget: const LoginScreen(),
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.logout,
                    color: AppColors.crimsonHover,
                    size: 18,
                  ),
                  label: const Text(
                    'Log Out & Return to Login',
                    style: TextStyle(
                      color: AppColors.crimsonHover,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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
