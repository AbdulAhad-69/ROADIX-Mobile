import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../src/core/config/app_config.dart';
import '../src/core/utils/geometry_utils.dart';
import '../src/core/utils/phone_utils.dart';
import '../src/features/emergency_triage/application/triage_controller.dart';
import 'demo_session.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  SupabaseClient get client => _client;
  String? get currentUserId => _client.auth.currentUser?.id;
  String get currentProfileId => _client.auth.currentUser?.id ?? '';
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isAuthenticated => _client.auth.currentUser != null;

  // ==========================================
  // 1. AUTHENTICATION (EMAIL, GOOGLE OAUTH, PHONE OTP & DEMO)
  // ==========================================

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    DemoSession.clear();
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String role = 'motorist',
  }) async {
    DemoSession.clear();
    final safeRole = role == 'mechanic' ? 'mechanic' : 'motorist';
    return await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
        'role': safeRole,
      },
    );
  }

  /// Guest / anonymous sign-in when enabled on Supabase Auth.
  Future<AuthResponse> signInAnonymously() async {
    return await _client.auth.signInAnonymously();
  }

  Future<void> sendPhoneOtp(String rawPhone) async {
    final normalized = PhoneUtils.normalize(rawPhone);
    if (!PhoneUtils.isValidBangladeshPhone(normalized)) {
      throw const FormatException(
        'Invalid Bangladesh mobile number. Please enter a valid 11-digit number starting with 01.',
      );
    }
    await _client.auth.signInWithOtp(phone: normalized);
  }

  Future<AuthResponse> verifyPhoneOtp({
    required String rawPhone,
    required String token,
  }) async {
    DemoSession.clear();
    final normalized = PhoneUtils.normalize(rawPhone);
    return await _client.auth.verifyOTP(
      phone: normalized,
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  Future<void> resendPhoneOtp(String rawPhone) async {
    final normalized = PhoneUtils.normalize(rawPhone);
    await _client.auth.resend(phone: normalized, type: OtpType.sms);
  }

  /// Launches Google OAuth via Supabase Auth PKCE browser flow.
  Future<bool> signInWithGoogle() async {
    DemoSession.clear();
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : AppConfig.oauthRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Explicit demo-session initializer retained only for test/demo access cards.
  Future<AuthResponse> signInWithGoogleFallback({required String role}) async {
    DemoSession.startDemo(demoRole: role);
    return AuthResponse(session: currentSession, user: currentUser);
  }

  Future<bool> signInWithApple() async {
    DemoSession.clear();
    return await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: kIsWeb ? null : AppConfig.oauthRedirectUrl,
    );
  }

  Future<void> signOut() async {
    DemoSession.clear();
    TriageController.clearCachedDraft();
    try {
      await _client.auth.signOut(scope: SignOutScope.local).timeout(
        const Duration(milliseconds: 250),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('SupabaseService.signOut error: $e');
    }
  }

  Future<String?> getUserRole() async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      return DemoSession.isActive ? DemoSession.role : null;
    }
    try {
      final res = await _client
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      return res?['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> createOrUpdateProfile({
    required String fullName,
    String? phone,
    String role = 'motorist',
    String? avatarUrl,
  }) async {
    final uid = currentProfileId;
    final normalizedPhone =
        phone != null && phone.isNotEmpty ? PhoneUtils.normalize(phone) : null;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        DemoSession.fullName = fullName;
        if (normalizedPhone != null && normalizedPhone.isNotEmpty) {
          DemoSession.phone = normalizedPhone;
        }
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          DemoSession.avatarUrl = avatarUrl;
        }
      }
      return;
    }

    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('id', uid)
        .maybeSingle();

    final updateFields = <String, dynamic>{
      'full_name': fullName,
      if (normalizedPhone != null && normalizedPhone.isNotEmpty)
        'phone': normalizedPhone,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
    };

    if (existing != null) {
      await _client.from('profiles').update(updateFields).eq('id', uid);
    } else {
      await _client.from('profiles').insert({
        'id': uid,
        'user_id': uid,
        ...updateFields,
      });
    }
  }

  // ==========================================
  // 2. MOTORIST PROFILE & AVATAR STORAGE
  // ==========================================

  Future<Map<String, dynamic>?> getProfile() async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (!DemoSession.isActive) return null;
      return {
        'id': 'demo-profile',
        'full_name': DemoSession.fullName,
        'phone': DemoSession.phone,
        'avatar_url': DemoSession.avatarUrl,
        'role': DemoSession.role,
        'is_demo': true,
      };
    }
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    String? avatarUrl,
  }) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        DemoSession.fullName = fullName;
        DemoSession.phone = phone;
        if (avatarUrl != null) DemoSession.avatarUrl = avatarUrl;
        DemoSession.notifier.value++;
      }
      return;
    }
    final updateMap = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
    };
    if (avatarUrl != null) {
      updateMap['avatar_url'] = avatarUrl;
    }
    await _client.from('profiles').update(updateMap).eq('id', uid);
  }

  Future<void> updateAvatar(String avatarUrl) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        DemoSession.avatarUrl = avatarUrl;
        DemoSession.notifier.value++;
      }
      return;
    }
    await _client
        .from('profiles')
        .update({'avatar_url': avatarUrl}).eq('id', uid);
  }

  /// Uploads profile image bytes to Supabase Storage `avatars/<uid>/...` and
  /// returns the resulting public CDN URL (or base64 data URI in Demo Mode).
  Future<String> uploadProfileAvatar(
    Uint8List bytes, {
    String fileExtension = 'jpg',
  }) async {
    final normalizedExt = fileExtension.toLowerCase().replaceAll('.', '');
    final safeExt = switch (normalizedExt) {
      'png' => 'png',
      'webp' => 'webp',
      'jpeg' || 'jpg' => 'jpg',
      _ => 'jpg',
    };
    final mimeType = switch (safeExt) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
        DemoSession.avatarUrl = dataUri;
        DemoSession.notifier.value++;
        return dataUri;
      }
      throw StateError('Sign in to upload a profile picture.');
    }

    final objectPath =
        '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    await _client.storage.from('avatars').uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );
    final publicUrl = _client.storage.from('avatars').getPublicUrl(objectPath);
    await updateAvatar(publicUrl);
    return publicUrl;
  }

  /// Uploads breakdown fault photo bytes to private `fault-photos/<uid>/...`
  /// bucket and returns a time-limited signed URL or storage path.
  Future<String?> uploadFaultPhoto(
    Uint8List bytes, {
    String fileExtension = 'jpg',
  }) async {
    final uid = currentProfileId;
    if (uid.isEmpty) return null;
    final safeExt = fileExtension.toLowerCase() == 'png' ? 'png' : 'jpg';
    final objectPath =
        '$uid/fault_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    await _client.storage.from('fault-photos').uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: safeExt == 'png' ? 'image/png' : 'image/jpeg',
            upsert: false,
          ),
        );
    return objectPath;
  }

  // ==========================================
  // 3. DIGITAL GARAGE (VEHICLES)
  // ==========================================

  Future<List<Map<String, dynamic>>> getVehicles() async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      return DemoSession.isActive
          ? List<Map<String, dynamic>>.from(DemoSession.vehicles)
          : [];
    }
    final response = await _client
        .from('vehicles')
        .select()
        .eq('profile_id', uid)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addVehicle({
    required String model,
    required String plate,
    required String type,
    required String fuel,
  }) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        DemoSession.vehicles.add({
          'id': 'demo-veh-${DateTime.now().millisecondsSinceEpoch}',
          'model': model,
          'plate': plate,
          'type': type,
          'fuel': fuel,
          'is_primary': DemoSession.vehicles.isEmpty,
        });
      }
      return;
    }
    await _client.from('vehicles').insert({
      'profile_id': uid,
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
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        final idx = DemoSession.vehicles.indexWhere((v) => v['id'] == vehicleId);
        if (idx >= 0) {
          DemoSession.vehicles[idx] = {
            ...DemoSession.vehicles[idx],
            'model': model,
            'plate': plate,
            'type': type,
            'fuel': fuel,
          };
        }
      }
      return;
    }
    await _client.from('vehicles').update({
      'model': model,
      'plate': plate,
      'type': type,
      'fuel': fuel,
    }).eq('id', vehicleId);
  }

  Future<void> deleteVehicle(String vehicleId) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        DemoSession.vehicles.removeWhere((v) => v['id'] == vehicleId);
      }
      return;
    }
    await _client.from('vehicles').delete().eq('id', vehicleId);
  }

  // ==========================================
  // 4. EMERGENCY BROADCAST CONTACTS
  // ==========================================

  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      return DemoSession.isActive
          ? List<Map<String, dynamic>>.from(DemoSession.emergencyContacts)
          : [];
    }
    final response = await _client
        .from('emergency_contacts')
        .select()
        .eq('profile_id', uid)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addEmergencyContact({
    required String name,
    required String phone,
    required String relation,
  }) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        DemoSession.emergencyContacts.add({
          'id': 'demo-contact-${DateTime.now().millisecondsSinceEpoch}',
          'name': name,
          'phone': phone,
          'relation': relation,
          'relationship': relation,
        });
      }
      return;
    }
    await _client.from('emergency_contacts').insert({
      'profile_id': uid,
      'name': name,
      'phone': phone,
      'relation': relation,
      'relationship': relation,
    });
  }

  Future<void> updateEmergencyContact({
    required String contactId,
    required String name,
    required String phone,
    required String relation,
  }) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        final idx = DemoSession.emergencyContacts
            .indexWhere((c) => c['id'] == contactId);
        if (idx >= 0) {
          DemoSession.emergencyContacts[idx] = {
            ...DemoSession.emergencyContacts[idx],
            'name': name,
            'phone': phone,
            'relation': relation,
            'relationship': relation,
          };
        }
      }
      return;
    }
    await _client.from('emergency_contacts').update({
      'name': name,
      'phone': phone,
      'relation': relation,
      'relationship': relation,
    }).eq('id', contactId);
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        DemoSession.emergencyContacts.removeWhere((c) => c['id'] == contactId);
      }
      return;
    }
    await _client.from('emergency_contacts').delete().eq('id', contactId);
  }

  // ==========================================
  // 5. PAYMENT & MFS WALLETS
  // ==========================================

  Future<List<Map<String, dynamic>>> getWallets() async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      return DemoSession.isActive
          ? List<Map<String, dynamic>>.from(DemoSession.wallets)
          : [];
    }
    final response = await _client
        .from('wallets')
        .select()
        .eq('profile_id', uid)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addWallet({
    required String provider,
    required String accountNumber,
  }) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        DemoSession.wallets.add({
          'id': 'demo-wallet-${DateTime.now().millisecondsSinceEpoch}',
          'provider': provider,
          'account_number': accountNumber,
          'is_primary': DemoSession.wallets.isEmpty,
        });
      }
      return;
    }
    await _client.from('wallets').insert({
      'profile_id': uid,
      'provider': provider,
      'account_number': accountNumber,
      'is_primary': false,
    });
  }

  Future<void> setPrimaryWallet(String walletId) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        for (final w in DemoSession.wallets) {
          w['is_primary'] = w['id'] == walletId;
        }
      }
      return;
    }
    try {
      await _client.rpc('set_primary_wallet', params: {'p_wallet_id': walletId});
    } on PostgrestException catch (e) {
      // Fallback only if M09 RPC isn't yet deployed on remote schema.
      if (e.code == 'PGRST202') {
        await _client
            .from('wallets')
            .update({'is_primary': false})
            .eq('profile_id', uid);
        await _client
            .from('wallets')
            .update({'is_primary': true})
            .eq('id', walletId);
      } else {
        rethrow;
      }
    }
  }

  Future<void> deleteWallet(String walletId) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        DemoSession.wallets.removeWhere((w) => w['id'] == walletId);
      }
      return;
    }
    await _client.from('wallets').delete().eq('id', walletId);
  }

  // ==========================================
  // 6. EMERGENCY DISPATCH & SERVICE REQUESTS
  // ==========================================

  Future<Map<String, dynamic>> createServiceRequest({
    required double breakdownLat,
    required double breakdownLng,
    required String breakdownAddress,
    required String vehicleType,
    required String licensePlate,
    required String faultType,
    List<String> symptoms = const [],
    String diagnosticNotes = '',
    List<String> photoUrls = const [],
    bool isHighPriority = false,
  }) async {
    final snapshot = {
      'vehicle_type': vehicleType,
      'plate': licensePlate,
    };
    final response = await _client.rpc(
      'create_service_request',
      params: {
        'p_breakdown_lat': breakdownLat,
        'p_breakdown_lng': breakdownLng,
        'p_breakdown_address': breakdownAddress,
        'p_vehicle_snapshot': snapshot,
        'p_fault_type': faultType,
        'p_symptoms': symptoms,
        'p_diagnostic_notes': diagnosticNotes,
        'p_photo_urls': photoUrls,
        'p_is_high_priority': isHighPriority,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> dispatchNextCandidate(String requestId) async {
    final response = await _client.rpc(
      'dispatch_next_candidate',
      params: {'p_request_id': requestId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<double> expandDispatchRadius(String requestId) async {
    final response = await _client.rpc(
      'expand_dispatch_radius',
      params: {'p_request_id': requestId},
    );
    return (response as num).toDouble();
  }

  Future<Map<String, dynamic>?> getServiceRequest(String requestId) async {
    if (currentProfileId.isEmpty) return null;
    try {
      final response = await _client
          .from('service_requests')
          .select()
          .eq('id', requestId)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getActiveServiceRequest() async {
    final userId = currentProfileId;
    if (userId.isEmpty) return null;
    try {
      final response = await _client
          .from('service_requests')
          .select()
          .eq('motorist_id', userId)
          .inFilter('status', [
            'searching',
            'assigned',
            'en_route',
            'arrived',
            'diagnosing',
            'quote_pending',
            'servicing',
          ])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getServiceRequestHistory() async {
    final userId = currentProfileId;
    if (userId.isEmpty) {
      return DemoSession.isActive
          ? List<Map<String, dynamic>>.from(DemoSession.serviceHistory)
          : [];
    }
    try {
      final response = await _client
          .from('service_requests')
          .select('*, quotations(*), transactions(*)')
          .eq('motorist_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      try {
        final response = await _client
            .from('service_requests')
            .select()
            .eq('motorist_id', userId)
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      } catch (_) {
        return [];
      }
    }
  }

  Future<void> cancelServiceRequest(
    String requestId, {
    String reason = 'Motorist cancelled',
  }) async {
    if (currentProfileId.isEmpty) return;
    await _client.from('service_requests').update({
      'status': 'cancelled',
      'cancellation_reason': reason,
      'cancelled_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  Future<Map<String, dynamic>?> getAssignedMechanic(String mechanicId) async {
    if (currentProfileId.isEmpty) return null;
    try {
      final profile = await _client
          .from('profiles')
          .select('full_name, phone, avatar_url')
          .eq('id', mechanicId)
          .maybeSingle();
      final mechanic = await _client
          .from('mechanic_profiles')
          .select(
            'workshop_name, workshop_address, rating, total_rescues, specializations, vehicle_specializations, current_location',
          )
          .eq('profile_id', mechanicId)
          .maybeSingle();
      if (profile == null && mechanic == null) return null;
      final coords =
          GeometryUtils.parsePostgisPoint(mechanic?['current_location']);
      return {
        ...profile ?? {},
        ...mechanic ?? {},
        if (coords != null) ...{
          'mechanic_lat': coords.$1,
          'mechanic_lng': coords.$2,
        },
      };
    } catch (_) {
      return null;
    }
  }

  Future<(double lat, double lng)?> getMechanicCoordinates(
      String mechanicId) async {
    if (currentProfileId.isEmpty) return null;
    try {
      final res = await _client
          .from('mechanic_profiles')
          .select('current_location')
          .eq('profile_id', mechanicId)
          .maybeSingle();
      return GeometryUtils.parsePostgisPoint(res?['current_location']);
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // 7. MECHANIC WORKFLOW & AVAILABILITY
  // ==========================================

  Future<Map<String, dynamic>?> getMechanicProfile(String profileId) async {
    if (profileId.isEmpty) {
      return DemoSession.isActive ? DemoSession.mechanicProfile : null;
    }
    try {
      final response = await _client
          .from('mechanic_profiles')
          .select()
          .eq('profile_id', profileId)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> ensureMechanicProfile({
    String? workshopName,
    String? workshopAddress,
  }) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive) {
        DemoSession.mechanicProfile ??= {
          'profile_id': 'demo-mechanic-001',
          'workshop_name': workshopName ?? 'Gulshan Auto Clinic',
          'workshop_address': workshopAddress ?? 'Dhaka, Bangladesh',
          'is_on_duty': false,
          'is_verified': true,
          'rating': 4.85,
          'total_rescues': 142,
          'vehicle_specializations': ['Passenger Car'],
          'specializations': ['General Automotive Breakdown'],
        };
        return DemoSession.mechanicProfile!;
      }
      throw StateError('Cannot create mechanic profile without active session.');
    }
    final existing = await getMechanicProfile(uid);
    if (existing != null) return existing;

    // Inserts only caller-permitted columns; defaults keep is_verified=false and is_on_duty=false.
    final inserted = await _client
        .from('mechanic_profiles')
        .insert({
          'profile_id': uid,
          'workshop_name': workshopName ?? 'Independent Auto Workshop',
          'workshop_address': workshopAddress ?? 'Dhaka, Bangladesh',
          'vehicle_specializations': ['Passenger Car'],
          'specializations': ['General Automotive Breakdown'],
        })
        .select()
        .single();

    return Map<String, dynamic>.from(inserted);
  }

  Future<Map<String, dynamic>?> getActiveMechanicRescue(
      String mechanicId) async {
    if (mechanicId.isEmpty || currentProfileId.isEmpty) return null;
    try {
      final res = await _client
          .from('service_requests')
          .select('*, motorist:motorist_id(id, full_name, phone)')
          .eq('mechanic_id', mechanicId)
          .inFilter('status', [
            'assigned',
            'en_route',
            'arrived',
            'diagnosing',
            'quote_pending',
            'servicing',
          ])
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return res;
    } catch (_) {
      try {
        final fallback = await _client
            .from('service_requests')
            .select()
            .eq('mechanic_id', mechanicId)
            .inFilter('status', [
              'assigned',
              'en_route',
              'arrived',
              'diagnosing',
              'quote_pending',
              'servicing',
            ])
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();
        return fallback;
      } catch (_) {
        return null;
      }
    }
  }

  Future<Map<String, dynamic>?> getMotoristProfile(String motoristId) async {
    if (motoristId.isEmpty || currentProfileId.isEmpty) return null;
    try {
      final res = await _client
          .from('profiles')
          .select('id, full_name, phone, avatar_url')
          .eq('id', motoristId)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> streamServiceRequest(String requestId) {
    return _client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId);
  }

  Stream<List<Map<String, dynamic>>> streamIncomingOffers(String mechanicId) {
    return _client
        .from('dispatch_offers')
        .stream(primaryKey: ['id'])
        .eq('mechanic_id', mechanicId);
  }

  Stream<List<Map<String, dynamic>>> streamQuotations(String requestId) {
    return _client
        .from('quotations')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId);
  }

  Future<void> updateMechanicSpecializations({
    required List<String> vehicleSpecializations,
    List<String>? serviceSpecializations,
  }) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive && DemoSession.mechanicProfile != null) {
        DemoSession.mechanicProfile!['vehicle_specializations'] =
            vehicleSpecializations;
        if (serviceSpecializations != null) {
          DemoSession.mechanicProfile!['specializations'] =
              serviceSpecializations;
        }
      }
      return;
    }
    final payload = <String, dynamic>{
      'vehicle_specializations': vehicleSpecializations,
    };
    if (serviceSpecializations != null) {
      payload['specializations'] = serviceSpecializations;
    }
    await _client
        .from('mechanic_profiles')
        .update(payload)
        .eq('profile_id', uid);
  }

  Future<void> updateMechanicDuty(bool isOnDuty) async {
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive && DemoSession.mechanicProfile != null) {
        DemoSession.mechanicProfile!['is_on_duty'] = isOnDuty;
      }
      return;
    }
    await _client
        .from('mechanic_profiles')
        .update({'is_on_duty': isOnDuty})
        .eq('profile_id', uid);
  }

  /// Debug/demo-only convenience toggle. Blocked in production and on hardened servers.
  Future<void> updateMechanicVerification(bool isVerified) async {
    if (AppConfig.isProduction || !kDebugMode) {
      throw StateError(
        'Mechanic verification must be approved by an administrator.',
      );
    }
    final uid = currentProfileId;
    if (uid.isEmpty) {
      if (DemoSession.isActive && DemoSession.mechanicProfile != null) {
        DemoSession.mechanicProfile!['is_verified'] = isVerified;
      }
      return;
    }
    await _client
        .from('mechanic_profiles')
        .update({'is_verified': isVerified})
        .eq('profile_id', uid);
  }

  Future<void> updateMechanicLocation({
    required double lat,
    required double lng,
  }) async {
    if (currentProfileId.isEmpty) return;
    await _client.rpc(
      'update_mechanic_location',
      params: {'p_lat': lat, 'p_lng': lng},
    );
  }

  Future<Map<String, dynamic>?> getLatestOfferForRequest(
      String requestId) async {
    if (currentProfileId.isEmpty) return null;
    try {
      final res = await _client
          .from('dispatch_offers')
          .select()
          .eq('request_id', requestId)
          .order('offered_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getIncomingOffers() async {
    final uid = currentProfileId;
    if (uid.isEmpty) return [];
    final res = await _client
        .from('dispatch_offers')
        .select('*, service_requests(*)')
        .eq('mechanic_id', uid)
        .eq('status', 'offered')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('offered_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<bool> acceptDispatchOffer({
    required String requestId,
    required String offerId,
  }) async {
    final response = await _client.rpc(
      'accept_dispatch_offer',
      params: {'p_request_id': requestId, 'p_offer_id': offerId},
    );
    return response == true;
  }

  Future<bool> rejectDispatchOffer(String offerId) async {
    final response = await _client.rpc(
      'reject_dispatch_offer',
      params: {'p_offer_id': offerId},
    );
    return response == true;
  }

  Future<void> updateServiceStatus({
    required String requestId,
    required String status,
  }) async {
    if (currentProfileId.isEmpty) return;
    await _client
        .from('service_requests')
        .update({'status': status})
        .eq('id', requestId);
  }

  // ==========================================
  // 8. QUOTATIONS & SETTLEMENT
  // ==========================================

  Future<Map<String, dynamic>> submitQuotation({
    required String requestId,
    required double diagnosticFee,
    required double laborFee,
    required double partsFee,
    Map<String, dynamic> lineItems = const {},
  }) async {
    final response = await _client.rpc(
      'submit_quotation',
      params: {
        'p_request_id': requestId,
        'p_diagnostic_fee': diagnosticFee,
        'p_labor_fee': laborFee,
        'p_parts_fee': partsFee,
        'p_line_items': lineItems,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<bool> respondToQuotation({
    required String quotationId,
    required String decision,
  }) async {
    final response = await _client.rpc(
      'respond_to_quotation',
      params: {'p_quotation_id': quotationId, 'p_decision': decision},
    );
    return response == true;
  }

  Future<Map<String, dynamic>?> getQuotationForRequest(
      String requestId) async {
    if (currentProfileId.isEmpty) return null;
    try {
      final res = await _client
          .from('quotations')
          .select()
          .eq('request_id', requestId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Records cash settlement cleanly via M09 `confirm_cash_settlement` RPC.
  Future<Map<String, dynamic>> confirmCashSettlement({
    required String requestId,
    String? quotationId,
  }) async {
    if (currentProfileId.isEmpty) {
      if (DemoSession.isActive) {
        return {'status': 'completed', 'transaction_id': 'DEMO-CASH-SETTLED'};
      }
      throw StateError('Authentication required for settlement.');
    }
    final response = await _client.rpc(
      'confirm_cash_settlement',
      params: {
        'p_request_id': requestId,
        if (quotationId != null && quotationId.isNotEmpty)
          'p_quotation_id': quotationId,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Development/demo settlement helper (never grants client-side SQL completion in prod).
  Future<Map<String, dynamic>> recordDevelopmentPayment({
    required String requestId,
    required String quotationId,
    required double amount,
    required String paymentMethod,
  }) async {
    if (DemoSession.isActive || currentProfileId.isEmpty) {
      return {
        'request_id': requestId,
        'quotation_id': quotationId,
        'amount': amount,
        'payment_method': paymentMethod,
        'status': 'completed',
        'gateway_transaction_id': 'DEMO-${DateTime.now().millisecondsSinceEpoch}',
      };
    }
    return await confirmCashSettlement(
      requestId: requestId,
      quotationId: quotationId.isEmpty ? null : quotationId,
    );
  }

  // ==========================================
  // 9. REVIEWS & RATINGS (Server-computed rating via M09 trigger)
  // ==========================================

  Future<void> submitReview({
    required String requestId,
    required String mechanicId,
    required int rating,
    String? motoristId,
    String? comment,
  }) async {
    final uid = motoristId ?? currentProfileId;
    if (uid.isEmpty) return;
    final payload = <String, dynamic>{
      'request_id': requestId,
      'motorist_id': uid,
      'mechanic_id': mechanicId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    };
    await _client.from('reviews').insert(payload);
  }
}
