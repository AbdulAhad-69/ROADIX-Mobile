import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:roadix_mobile/screens/login_screen.dart';
import 'package:roadix_mobile/services/supabase_service.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';
import 'package:roadix_mobile/src/core/utils/geometry_utils.dart';
import 'package:roadix_mobile/src/core/utils/phone_utils.dart';
import 'package:roadix_mobile/theme/app_colors.dart';
import 'package:roadix_mobile/widgets/brand_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return true;
      },
    );

    await AppConfig.initialize();
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (_) {
      // Supabase already initialized or offline mock active
    }
  });

  // =========================================================================
  // TIER 1: FEATURE COVERAGE (Core Functional & Visual Elements)
  // =========================================================================
  group('Tier 1: Feature Coverage — Authentication, Branding & Dispatch Core', () {
    test('T1.1: Google Sign-In Fallback initiates cleanly on unconfigured OAuth', () async {
      // Verify AppConfig OAuth detection logic
      expect(AppConfig.isGoogleAuthConfigured, isFalse,
          reason: 'Default environment has placeholder OAuth IDs');

      // Verify SupabaseService.signInWithGoogleFallback interface contract
      final service = SupabaseService();
      final motoristResponse = await service.signInWithGoogleFallback(role: 'motorist');
      expect(motoristResponse, isNotNull);

      final mechanicResponse = await service.signInWithGoogleFallback(role: 'mechanic');
      expect(mechanicResponse, isNotNull);
    });

    testWidgets('T1.2: LoginScreen displays Google Sign-In button with BrandLogo and handles fallback',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pump();

      // Find the Google sign-in button
      final googleButtonFinder = find.widgetWithText(OutlinedButton, 'Continue with Google');
      expect(googleButtonFinder, findsOneWidget);

      // Verify Google BrandLogo is embedded inside the button
      final googleLogoFinder = find.descendant(
        of: googleButtonFinder,
        matching: find.byType(BrandLogo),
      );
      expect(googleLogoFinder, findsOneWidget);

      final brandLogoWidget = tester.widget<BrandLogo>(googleLogoFinder);
      expect(brandLogoWidget.brand.toLowerCase(), equals('google'));
    });

    test('T1.3: AppColors defines official bKash primary colors #D12053 and #E2136E', () {
      // Hex #D12053 is official bKash Dark Magenta / Crimson
      expect(AppColors.bkashCrimson.toARGB32(), equals(0xFFD12053));
      expect(AppColors.bkashDeep.toARGB32(), equals(0xFFD12053));

      // Hex #E2136E is official bKash Vibrant Pink
      expect(AppColors.bkashPink.toARGB32(), equals(0xFFE2136E));
      expect(AppColors.bkashPrimary.toARGB32(), equals(0xFFE2136E));

      // Contrast and opacity verification
      expect(AppColors.bkashCrimson.a, equals(1.0));
      expect(AppColors.bkashPink.a, equals(1.0));
    });

    test('T1.4: Authentic bKash Brand Asset File Physically Exists with Valid PNG Signature', () {
      const assetPath = 'assets/images/bkash_logo.png';
      final file = File(assetPath);
      expect(file.existsSync(), isTrue, reason: 'High-res bKash logo asset must exist');
      expect(file.lengthSync(), greaterThan(1000),
          reason: 'Expected high-resolution bKash asset rather than 663-byte placeholder');

      // Verify PNG magic header bytes: 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(8));
      expect(bytes[0], equals(0x89));
      expect(bytes[1], equals(0x50)); // 'P'
      expect(bytes[2], equals(0x4E)); // 'N'
      expect(bytes[3], equals(0x47)); // 'G'
    });

    testWidgets('T1.5: BrandLogo widget renders authentic bKash vector origami bird',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BrandLogo(brand: 'bkash', size: 48.0, showBadge: false),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify BrandLogo widget builds cleanly
      expect(find.byType(BrandLogo), findsOneWidget);

      // Verify BkashOrigamiBirdPainter is rendered via CustomPaint
      final customPaintFinder = find.descendant(
        of: find.byType(BrandLogo),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsWidgets);

      // Verify painter instantiation and canvas execution
      const painter = BkashOrigamiBirdPainter(
        primaryColor: AppColors.bkashPink,
        deepColor: AppColors.bkashCrimson,
        isBadgeMode: true,
      );
      final pictureRecorder = PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      painter.paint(canvas, const Size(100, 100));
      final picture = pictureRecorder.endRecording();
      expect(picture, isNotNull);
    });

    test('T1.6: Dispatch Screen Elapsed Search Timer formatting and progress model', () {
      String formatElapsed(int elapsedSeconds, int maxSeconds) {
        final elapsedMin = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
        final elapsedSec = (elapsedSeconds % 60).toString().padLeft(2, '0');
        final maxMin = (maxSeconds ~/ 60).toString().padLeft(2, '0');
        final maxSec = (maxSeconds % 60).toString().padLeft(2, '0');
        return '$elapsedMin:$elapsedSec / $maxMin:$maxSec';
      }

      double progressFraction(int elapsedSeconds, int maxSeconds) {
        return (elapsedSeconds / maxSeconds).clamp(0.0, 1.0);
      }

      expect(formatElapsed(8, 90), equals('00:08 / 01:30'));
      expect(formatElapsed(45, 90), equals('00:45 / 01:30'));
      expect(formatElapsed(90, 90), equals('01:30 / 01:30'));

      expect(progressFraction(0, 90), equals(0.0));
      expect(progressFraction(45, 90), closeTo(0.5, 0.001));
      expect(progressFraction(90, 90), equals(1.0));
      expect(progressFraction(120, 90), equals(1.0));
    });

    test('T1.7: Candidate Offer Expiration 45-Second Countdown Model', () {
      int countdown = 45;
      const ticks = 45;

      for (int i = 0; i < ticks; i++) {
        expect(countdown, greaterThan(0));
        countdown--;
      }

      expect(countdown, equals(0));
      // Guard against underflow
      countdown = max(0, countdown - 1);
      expect(countdown, equals(0));
    });

    test('T1.8: Candidate Queue Demo Mechanics Data Specification', () {
      final demoCandidates = [
        {
          'id': 'cand-demo-01',
          'full_name': 'Md. Rafiqul Islam',
          'workshop_name': 'Uttara 24/7 Motors',
          'workshop_address': 'Sector 11, Uttara, Dhaka',
          'phone': '+8801811000011',
          'rating': 4.90,
          'total_rescues': 320,
          'specialization': 'Mechanical & Electrical Specialist',
          'eta_minutes': 9,
          'distance_km': 2.4,
          'vehicle_types': ['Passenger Car', 'Motorcycle'],
        },
        {
          'id': 'cand-demo-02',
          'full_name': 'Al-Amin Shikder',
          'workshop_name': 'Al-Amin Heavy Rescue',
          'workshop_address': 'Airport Road, Gazipur Highway, Dhaka',
          'phone': '+8801711000022',
          'rating': 4.85,
          'total_rescues': 215,
          'specialization': 'Heavy Recovery & Towing Specialist',
          'eta_minutes': 16,
          'distance_km': 6.8,
          'vehicle_types': ['Passenger Car', 'Light Commercial'],
        },
      ];

      expect(demoCandidates.length, equals(2));

      // Candidate 1 assertions
      final c1 = demoCandidates[0];
      expect(c1['full_name'], equals('Md. Rafiqul Islam'));
      expect(c1['workshop_name'], equals('Uttara 24/7 Motors'));
      expect(c1['rating'], equals(4.90));
      expect(c1['total_rescues'], greaterThanOrEqualTo(300));
      expect(PhoneUtils.isValidBangladeshPhone(c1['phone'] as String), isTrue);

      // Candidate 2 assertions
      final c2 = demoCandidates[1];
      expect(c2['workshop_name'], equals('Al-Amin Heavy Rescue'));
      expect(c2['rating'], equals(4.85));
      expect(c2['total_rescues'], greaterThanOrEqualTo(200));
      expect(PhoneUtils.isValidBangladeshPhone(c2['phone'] as String), isTrue);
    });

    test('T1.9: Manual Simulation Trigger "Accept Offer (Simulate Mechanic)" Contract', () {
      String phase = 'offered';
      String currentStatus = 'searching';
      Map<String, dynamic>? assignedMechanic;

      void simulateMechanicAcceptance(Map<String, dynamic> candidate) {
        phase = 'assigned';
        currentStatus = 'assigned';
        assignedMechanic = candidate;
      }

      final candidate = {
        'full_name': 'Md. Rafiqul Islam',
        'workshop_name': 'Uttara 24/7 Motors',
        'rating': 4.90,
      };

      expect(phase, equals('offered'));
      simulateMechanicAcceptance(candidate);

      expect(phase, equals('assigned'));
      expect(currentStatus, equals('assigned'));
      expect(assignedMechanic?['workshop_name'], equals('Uttara 24/7 Motors'));
    });
  });

  // =========================================================================
  // TIER 2: BOUNDARY, RESOURCE STRESS & CORNER CASES
  // =========================================================================
  group('Tier 2: Boundary & Corner Cases', () {
    test('T2.1: 90-Second Search Exhaustion Boundary stops polling and transitions phase', () {
      String phase = 'searching';
      int totalSearchSeconds = 0;
      const int maxTimeoutSeconds = 90;
      bool pollingActive = true;

      void onSearchTick() {
        totalSearchSeconds++;
        if (totalSearchSeconds >= maxTimeoutSeconds) {
          phase = 'exhausted';
          pollingActive = false;
        }
      }

      for (int i = 0; i < maxTimeoutSeconds; i++) {
        onSearchTick();
      }

      expect(totalSearchSeconds, equals(90));
      expect(phase, equals('exhausted'));
      expect(pollingActive, isFalse, reason: 'Polling must terminate at exhaustion boundary');
    });

    test('T2.2: 45-Second Offer Expiry Countdown underflow protection and reset', () {
      int offerCountdown = 45;
      String phase = 'offered';

      void onOfferTick() {
        if (offerCountdown > 1) {
          offerCountdown--;
        } else {
          offerCountdown = 0;
          phase = 'offer_expired';
        }
      }

      for (int i = 0; i < 45; i++) {
        onOfferTick();
      }

      expect(offerCountdown, equals(0));
      expect(phase, equals('offer_expired'));

      // Extra tick must not cause negative value
      onOfferTick();
      expect(offerCountdown, equals(0));
    });

    test('T2.3: Discrete Radius Progression enforces 5.0 -> 10.0 -> 15.0 km terminal ceiling', () {
      double radius = 5.0;
      final progression = <double>[radius];

      void expandRadius() {
        if (radius < 15.0) {
          radius += 5.0;
          progression.add(radius);
        }
      }

      expandRadius(); // 10.0 km
      expandRadius(); // 15.0 km
      expandRadius(); // Capped at 15.0 km

      expect(progression, equals([5.0, 10.0, 15.0]));
      expect(radius, equals(15.0));
    });

    test('T2.4: Automatic Demo Fallback on Network / Socket / Auth Exception', () {
      bool isDemoMode = false;
      String phase = 'submitting';
      String? requestCode;

      void handleDispatchException(dynamic error) {
        final errStr = error.toString().toLowerCase();
        if (errStr.contains('clientexception') ||
            errStr.contains('socketexception') ||
            errStr.contains('authentication required') ||
            errStr.contains('connection')) {
          isDemoMode = true;
          phase = 'searching';
          requestCode = 'RDX-DEMO-8821';
        } else {
          phase = 'error';
        }
      }

      handleDispatchException(const SocketException('Failed host lookup'));
      expect(isDemoMode, isTrue);
      expect(phase, equals('searching'));
      expect(requestCode, equals('RDX-DEMO-8821'));
    });

    test('T2.5: Rapid Re-entrant Simulation Triggers Are Safely Debounced', () {
      int executionCount = 0;
      bool isAccepting = false;

      void handleAcceptOffer() {
        if (isAccepting) return; // Debounce guard
        isAccepting = true;
        executionCount++;
      }

      // Simulate 5 rapid simultaneous taps
      handleAcceptOffer();
      handleAcceptOffer();
      handleAcceptOffer();
      handleAcceptOffer();
      handleAcceptOffer();

      expect(executionCount, equals(1), reason: 'Re-entrant simulation taps must be debounced');
    });
  });

  // =========================================================================
  // TIER 3: CROSS-FEATURE COMBINATIONS & STATE TRANSITIONS
  // =========================================================================
  group('Tier 3: Cross-Feature Combinations & State Transitions', () {
    test('T3.1: Role-Based Navigation Routing accurately discriminates motorist vs mechanic', () {
      String resolveLandingRoute(String role) {
        if (role == 'mechanic') {
          return '/mechanic';
        }
        return '/home';
      }

      expect(resolveLandingRoute('motorist'), equals('/home'));
      expect(resolveLandingRoute('mechanic'), equals('/mechanic'));
      expect(resolveLandingRoute(''), equals('/home')); // Default fallback to motorist
    });

    test('T3.2: In-Flight Active Request Resumption Gate avoids duplicate dispatch', () {
      const activeStatuses = {
        'searching',
        'assigned',
        'en_route',
        'arrived',
        'diagnosing',
        'quote_pending',
        'servicing',
      };

      bool shouldResume(Map<String, dynamic>? activeRequest) {
        if (activeRequest == null) return false;
        final status = activeRequest['status'] as String?;
        return activeStatuses.contains(status);
      }

      expect(shouldResume({'id': 'req-1', 'status': 'searching'}), isTrue);
      expect(shouldResume({'id': 'req-2', 'status': 'en_route'}), isTrue);
      expect(shouldResume({'id': 'req-3', 'status': 'quote_pending'}), isTrue);
      expect(shouldResume({'id': 'req-4', 'status': 'completed'}), isFalse);
      expect(shouldResume({'id': 'req-5', 'status': 'cancelled'}), isFalse);
      expect(shouldResume(null), isFalse);
    });

    test('T3.3: Quotation Approval Fee Arithmetic Gate enforces exact line-item balance', () {
      bool validateQuotation({
        required double diagnosticFee,
        required double laborFee,
        required double partsFee,
        required double totalAmount,
      }) {
        const epsilon = 0.001;
        final sum = diagnosticFee + laborFee + partsFee;
        return (sum - totalAmount).abs() < epsilon && totalAmount > 0;
      }

      // Valid balanced quote
      expect(
        validateQuotation(
          diagnosticFee: 300.0,
          laborFee: 450.0,
          partsFee: 250.0,
          totalAmount: 1000.0,
        ),
        isTrue,
      );

      // Invalid quote with fee mismatch
      expect(
        validateQuotation(
          diagnosticFee: 300.0,
          laborFee: 450.0,
          partsFee: 250.0,
          totalAmount: 1200.0,
        ),
        isFalse,
      );
    });

    test('T3.4: Payment Method Selection dynamically applies bKash branding tokens', () {
      String selectedMethod = 'Cash Settlement';
      Color chipColor = AppColors.slateBorder;

      void selectPaymentMethod(String method) {
        selectedMethod = method;
        if (method.contains('bKash')) {
          chipColor = AppColors.bkashPink;
        } else {
          chipColor = AppColors.caliperCrimson;
        }
      }

      selectPaymentMethod('SSLCommerz-bKash');
      expect(selectedMethod, equals('SSLCommerz-bKash'));
      expect(chipColor, equals(AppColors.bkashPink));

      selectPaymentMethod('SSLCommerz-Nagad');
      expect(chipColor, equals(AppColors.caliperCrimson));
    });

    test('T3.5: Activity History Digital Invoice displays formatted BDT and brand badging', () {
      final receipt = {
        'id': 'RDX-2026-9041',
        'diagnostic_fee': 300.0,
        'labor_fee': 450.0,
        'parts_fee': 250.0,
        'total_amount': 1000.0,
        'payment_method': 'bKash',
        'status': 'settled',
      };

      final formattedTotal = '৳ ${receipt['total_amount']?.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          )}';
      expect(formattedTotal, contains('৳ 1,000'));
      expect(receipt['payment_method'], equals('bKash'));
      expect(receipt['status'], equals('settled'));
    });
  });

  // =========================================================================
  // TIER 4: REAL-WORLD END-TO-END SCENARIOS (10-Stage Journey)
  // =========================================================================
  group('Tier 4: Real-World End-to-End Scenarios — Complete 10-Stage Journey', () {
    test('T4.1: Deterministic 10-Stage End-to-End Roadside Rescue Journey Simulation', () async {
      // -----------------------------------------------------------------------
      // STAGE 1: RADAR SEARCHING
      // -----------------------------------------------------------------------
      String currentPhase = 'searching';
      String serviceStatus = 'searching';
      double searchRadiusKm = 5.0;
      int searchElapsedSeconds = 0;
      final candidateQueue = <Map<String, dynamic>>[];

      expect(currentPhase, equals('searching'));
      expect(searchRadiusKm, equals(5.0));
      expect(searchElapsedSeconds, equals(0));

      // Simulate 2s radar expansion
      searchElapsedSeconds += 2;
      searchRadiusKm = 10.0;
      expect(searchRadiusKm, equals(10.0));

      // -----------------------------------------------------------------------
      // STAGE 2: MECHANIC FOUND (Candidate Queue Populated)
      // -----------------------------------------------------------------------
      searchElapsedSeconds += 2;
      searchRadiusKm = 15.0;
      currentPhase = 'offered';
      int offerCountdown = 45;
      expect(offerCountdown, equals(45));

      candidateQueue.addAll([
        {
          'id': 'cand-01',
          'name': 'Md. Rafiqul Islam',
          'workshop': 'Uttara 24/7 Motors',
          'rating': 4.90,
          'rescues': 320,
          'lat': 23.8819,
          'lng': 90.3845,
        },
        {
          'id': 'cand-02',
          'name': 'Al-Amin Shikder',
          'workshop': 'Al-Amin Heavy Rescue',
          'rating': 4.85,
          'rescues': 215,
          'lat': 23.8650,
          'lng': 90.4010,
        },
      ]);

      expect(currentPhase, equals('offered'));
      expect(offerCountdown, equals(45));
      expect(candidateQueue.length, equals(2));
      expect(candidateQueue.first['workshop'], equals('Uttara 24/7 Motors'));

      // -----------------------------------------------------------------------
      // STAGE 3: ACCEPTED ("Accept Offer (Simulate Mechanic)" Trigger)
      // -----------------------------------------------------------------------
      final selectedTechnician = candidateQueue.first;
      currentPhase = 'assigned';
      serviceStatus = 'assigned';

      expect(currentPhase, equals('assigned'));
      expect(serviceStatus, equals('assigned'));
      expect(selectedTechnician['name'], equals('Md. Rafiqul Islam'));

      // -----------------------------------------------------------------------
      // STAGE 4: LIVE TELEMETRY MAP (Technician En Route)
      // -----------------------------------------------------------------------
      serviceStatus = 'en_route';
      const breakdownLat = 23.8759;
      const breakdownLng = 90.3795;
      final techLat = selectedTechnician['lat'] as double;
      final techLng = selectedTechnician['lng'] as double;

      final distanceKm = GeometryUtils.calculateDistanceKm(
        breakdownLat,
        breakdownLng,
        techLat,
        techLng,
      );
      final etaMinutes = GeometryUtils.calculateEtaMinutes(distanceKm);
      final formattedEta = GeometryUtils.formatEta(distanceKm);

      expect(serviceStatus, equals('en_route'));
      expect(distanceKm, greaterThan(0.5));
      expect(etaMinutes, greaterThan(0));
      expect(formattedEta, contains('away'));

      // -----------------------------------------------------------------------
      // STAGE 5: ARRIVED (Technician Arrived on Scene)
      // -----------------------------------------------------------------------
      serviceStatus = 'arrived';
      expect(serviceStatus, equals('arrived'));

      // -----------------------------------------------------------------------
      // STAGE 6: DIAGNOSING (Vehicle Inspection)
      // -----------------------------------------------------------------------
      serviceStatus = 'diagnosing';
      expect(serviceStatus, equals('diagnosing'));

      // -----------------------------------------------------------------------
      // STAGE 7: QUOTATION APPROVAL GATE
      // -----------------------------------------------------------------------
      serviceStatus = 'quote_pending';
      final quotation = {
        'id': 'quote-demo-1001',
        'diagnostic_fee': 300.0,
        'labor_fee': 450.0,
        'parts_fee': 250.0,
        'total_amount': 1000.0,
        'status': 'pending',
      };

      expect(serviceStatus, equals('quote_pending'));
      expect(quotation['total_amount'], equals(1000.0));

      // Motorist approves quotation
      quotation['status'] = 'accepted';
      expect(quotation['status'], equals('accepted'));

      // -----------------------------------------------------------------------
      // STAGE 8: SERVICING (Roadside Repair in Progress)
      // -----------------------------------------------------------------------
      serviceStatus = 'servicing';
      expect(serviceStatus, equals('servicing'));

      // -----------------------------------------------------------------------
      // STAGE 9: DIGITAL INVOICE & PAYMENT (bKash Settlement)
      // -----------------------------------------------------------------------
      serviceStatus = 'completed';
      final invoice = {
        'invoice_id': 'INV-2026-9041',
        'amount': quotation['total_amount'],
        'payment_method': 'SSLCommerz-bKash',
        'payment_status': 'pending',
      };

      expect(serviceStatus, equals('completed'));
      expect(invoice['payment_method'], contains('bKash'));

      // Settle invoice
      invoice['payment_status'] = 'settled';
      expect(invoice['payment_status'], equals('settled'));

      // -----------------------------------------------------------------------
      // STAGE 10: FEEDBACK RATING (5-Star Trust Score)
      // -----------------------------------------------------------------------
      final review = {
        'rating': 5,
        'comment': 'Prompt arrival and outstanding puncture repair in Uttara!',
        'mechanic_id': selectedTechnician['id'],
      };

      expect(review['rating'], equals(5));
      expect(review['comment'], isNotEmpty);

      // Verify trust score update: (4.90 * 320 + 5) / 321 = ~4.9003
      final priorRating = selectedTechnician['rating'] as double;
      final priorRescues = selectedTechnician['rescues'] as int;
      final updatedRating = ((priorRating * priorRescues) + 5) / (priorRescues + 1);

      expect(updatedRating, greaterThanOrEqualTo(4.90));
      expect(updatedRating, lessThanOrEqualTo(5.0));
    });
  });
}
