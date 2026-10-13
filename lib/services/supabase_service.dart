import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // We use our seeded demo profile ID as the active session fallback
  static const String defaultProfileId = 'a0000000-0000-0000-0000-000000000001';

  String get currentProfileId => defaultProfileId;

  // ==========================================
  // 1. MOTORIST PROFILE
  // ==========================================

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', currentProfileId)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    await _client.from('profiles').update({
      'full_name': fullName,
      'phone': phone,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', currentProfileId);
  }

  // ==========================================
  // 2. DIGITAL GARAGE (VEHICLES)
  // ==========================================

  Future<List<Map<String, dynamic>>> getVehicles() async {
    final response = await _client
        .from('vehicles')
        .select()
        .eq('profile_id', currentProfileId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addVehicle({
    required String model,
    required String plate,
    required String type,
    required String fuel,
  }) async {
    await _client.from('vehicles').insert({
      'profile_id': currentProfileId,
      'model': model,
      'plate': plate,
      'type': type,
      'fuel': fuel,
      'is_primary': false,
    });
  }

  Future<void> updateVehicle({
    required String vehicleId,
    required String model,
    required String plate,
    required String type,
    required String fuel,
  }) async {
    await _client.from('vehicles').update({
      'model': model,
      'plate': plate,
      'type': type,
      'fuel': fuel,
    }).eq('id', vehicleId);
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await _client.from('vehicles').delete().eq('id', vehicleId);
  }

  // ==========================================
  // 3. EMERGENCY BROADCAST CONTACTS
  // ==========================================

  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final response = await _client
        .from('emergency_contacts')
        .select()
        .eq('profile_id', currentProfileId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addEmergencyContact({
    required String name,
    required String phone,
    required String relation,
  }) async {
    await _client.from('emergency_contacts').insert({
      'profile_id': currentProfileId,
      'name': name,
      'phone': phone,
      'relation': relation,
    });
  }

  Future<void> updateEmergencyContact({
    required String contactId,
    required String name,
    required String phone,
    required String relation,
  }) async {
    await _client.from('emergency_contacts').update({
      'name': name,
      'phone': phone,
      'relation': relation,
    }).eq('id', contactId);
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    await _client.from('emergency_contacts').delete().eq('id', contactId);
  }

  // ==========================================
  // 4. PAYMENT & MFS WALLETS
  // ==========================================

  Future<List<Map<String, dynamic>>> getWallets() async {
    final response = await _client
        .from('wallets')
        .select()
        .eq('profile_id', currentProfileId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addWallet({
    required String provider,
    required String accountNumber,
  }) async {
    await _client.from('wallets').insert({
      'profile_id': currentProfileId,
      'provider': provider,
      'account_number': accountNumber,
      'is_primary': false,
    });
  }

  Future<void> setPrimaryWallet(String walletId) async {
    // Demote all wallets to false first
    await _client
        .from('wallets')
        .update({'is_primary': false})
        .eq('profile_id', currentProfileId);

    // Promote the selected wallet
    await _client
        .from('wallets')
        .update({'is_primary': true})
        .eq('id', walletId);
  }
}