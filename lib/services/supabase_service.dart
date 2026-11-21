import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../src/core/utils/geometry_utils.dart';
import '../src/core/utils/phone_utils.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;
  String get currentProfileId => _client.auth.currentUser?.id ?? '';
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isAuthenticated => _client.auth.currentUser != null;

  // ==========================================
  // 1. AUTHENTICATION (EMAIL/PASSWORD, GOOGLE & GUEST SOS)
  // ==========================================

  /// Email/Password Sign-In
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Email/Password Sign-Up
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  /// Guest SOS: Anonymous session preserves isolated multi-tenancy without OTP delay
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
    await _client.auth.signInWithOtp(
      phone: normalized,
    );
  }

  Future<AuthResponse> verifyPhoneOtp({
    required String rawPhone,
    required String token,
  }) async {
    final normalized = PhoneUtils.normalize(rawPhone);
    return await _client.auth.verifyOTP(
      phone: normalized,
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  Future<void> resendPhoneOtp(String rawPhone) async {
    final normalized = PhoneUtils.normalize(rawPhone);
    await _client.auth.resend(
      phone: normalized,
      type: OtpType.sms,
    );
  }

  Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.roadix://login-callback',
    );
  }

  Future<bool> signInWithApple() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: kIsWeb ? null : 'io.supabase.roadix://login-callback',
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<String?> getUserRole() async {
    try {
      final res = await _client
          .from('profiles')
          .select('role')
          .eq('id', currentProfileId)
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
  }) async {
    final uid = currentProfileId;
    final normalizedPhone =
        phone != null && phone.isNotEmpty ? PhoneUtils.normalize(phone) : null;
    await _client.from('profiles').upsert({
      'id': uid,
      'full_name': fullName,
      if (normalizedPhone != null && normalizedPhone.isNotEmpty)
        'phone': normalizedPhone,
      'role': role,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

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

  Future<void> deleteWallet(String walletId) async {
    await _client.from('wallets').delete().eq('id', walletId);
  }

  // ==========================================
  // 5. EMERGENCY DISPATCH & SERVICE REQUESTS (PHASE 4)
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
    try {
      final userId = _client.auth.currentUser?.id ?? currentProfileId;
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
    try {
      final userId = _client.auth.currentUser?.id ?? currentProfileId;
      final response = await _client
          .from('service_requests')
          .select('*, quotations(*)')
          .eq('motorist_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      try {
        final userId = _client.auth.currentUser?.id ?? currentProfileId;
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
    await _client.from('service_requests').update({
      'status': 'cancelled',
      'cancellation_reason': reason,
      'cancelled_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  Future<Map<String, dynamic>?> getAssignedMechanic(String mechanicId) async {
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
      final coords = GeometryUtils.parsePostgisPoint(mechanic?['current_location']);
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

  Future<(double lat, double lng)?> getMechanicCoordinates(String mechanicId) async {
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
  // 6. MECHANIC WORKFLOW & AVAILABILITY
  // ==========================================

  Future<Map<String, dynamic>?> getMechanicProfile(String profileId) async {
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
      throw StateError('Cannot create mechanic profile without active session.');
    }
    final existing = await getMechanicProfile(uid);
    if (existing != null) return existing;

    // Strict security rule: Verification is an explicit admin action.
    // Unverified mechanics are NEVER dispatch-eligible and cannot go on-duty.
    final inserted = await _client.from('mechanic_profiles').insert({
      'profile_id': uid,
      'workshop_name': workshopName ?? 'Independent Auto Workshop',
      'workshop_address': workshopAddress ?? 'Dhaka, Bangladesh',
      'is_on_duty': false,
      'is_verified': false,
      'rating': 5.0,
      'total_rescues': 0,
      'vehicle_specializations': ['Passenger Car'],
      'specializations': ['General Automotive Breakdown'],
    }).select().single();

    try {
      await _client.from('profiles').update({'role': 'mechanic'}).eq('id', uid);
    } catch (_) {}

    return Map<String, dynamic>.from(inserted);
  }

  SupabaseClient get client => _client;

  Future<Map<String, dynamic>?> getActiveMechanicRescue(String mechanicId) async {
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
    if (uid.isEmpty) return;
    final payload = <String, dynamic>{
      'vehicle_specializations': vehicleSpecializations,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (serviceSpecializations != null) {
      payload['specializations'] = serviceSpecializations;
    }
    await _client.from('mechanic_profiles').update(payload).eq('profile_id', uid);
  }

  Future<void> updateMechanicDuty(bool isOnDuty) async {
    final uid = currentProfileId;
    if (uid.isEmpty) return;
    await _client.from('mechanic_profiles').update({
      'is_on_duty': isOnDuty,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('profile_id', uid);
  }

  Future<void> updateMechanicVerification(bool isVerified) async {
    final uid = currentProfileId;
    if (uid.isEmpty) return;
    await _client.from('mechanic_profiles').update({
      'is_verified': isVerified,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('profile_id', uid);
  }

  Future<void> updateMechanicLocation({
    required double lat,
    required double lng,
  }) async {
    await _client.rpc(
      'update_mechanic_location',
      params: {
        'p_lat': lat,
        'p_lng': lng,
      },
    );
  }

  Future<Map<String, dynamic>?> getLatestOfferForRequest(String requestId) async {
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
      params: {
        'p_request_id': requestId,
        'p_offer_id': offerId,
      },
    );
    return response == true;
  }

  Future<bool> rejectDispatchOffer(String offerId) async {
    final response = await _client.rpc(
      'reject_dispatch_offer',
      params: {
        'p_offer_id': offerId,
      },
    );
    return response == true;
  }

  Future<void> updateServiceStatus({
    required String requestId,
    required String status,
  }) async {
    await _client.from('service_requests').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  // ==========================================
  // 7. QUOTATIONS & DEVELOPMENT PAYMENT
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
    required String decision, // 'accepted' or 'rejected'
  }) async {
    final response = await _client.rpc(
      'respond_to_quotation',
      params: {
        'p_quotation_id': quotationId,
        'p_decision': decision,
      },
    );
    return response == true;
  }

  Future<Map<String, dynamic>?> getQuotationForRequest(String requestId) async {
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

  /// Records a development-mode payment transaction.
  /// Clearly flagged in audit logs and records as simulated test payment.
  Future<Map<String, dynamic>> recordDevelopmentPayment({
    required String requestId,
    required String quotationId,
    required double amount,
    required String paymentMethod, // 'bKash', 'Nagad', 'Cash'
  }) async {
    final txId = 'DEV-TX-${DateTime.now().millisecondsSinceEpoch}';
    final res = await _client.from('transactions').insert({
      'request_id': requestId,
      'quotation_id': quotationId,
      'amount': amount,
      'payment_method': paymentMethod,
      'status': 'completed',
      'gateway_transaction_id': txId,
      'metadata': {
        'environment': 'development',
        'is_simulation': true,
        'note': 'DEVELOPMENT MODE PAYMENT SIMULATION - NO REAL MONEY CHARGED',
      },
    }).select().single();

    // Transition request status to completed
    await updateServiceStatus(requestId: requestId, status: 'completed');

    return Map<String, dynamic>.from(res);
  }

  // ==========================================
  // 8. REVIEWS & RATINGS
  // ==========================================

  Future<void> submitReview({
    required String requestId,
    required String mechanicId,
    required int rating,
    String? motoristId,
    String? comment,
  }) async {
    final uid = motoristId ?? currentProfileId;
    final payload = <String, dynamic>{
      'request_id': requestId,
      'motorist_id': uid,
      'mechanic_id': mechanicId,
      'rating': rating,
    };
    if (comment != null && comment.isNotEmpty) {
      payload['comment'] = comment;
    }
    await _client.from('reviews').insert(payload);

    try {
      // Recompute and update mechanic's trust rating
      final reviews = await _client
          .from('reviews')
          .select('rating')
          .eq('mechanic_id', mechanicId);
      if (reviews.isNotEmpty) {
        final totalStars = reviews.fold<num>(
            0, (sum, r) => sum + ((r['rating'] as num?) ?? 5));
        final avgRating = totalStars / reviews.length;
        await _client.from('mechanic_profiles').update({
          'rating': double.parse(avgRating.toStringAsFixed(2)),
          'total_rescues': reviews.length,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('profile_id', mechanicId);
      }
    } catch (_) {}
  }
}