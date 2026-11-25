import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roadix_mobile/screens/location_confirm_screen.dart';
import 'package:roadix_mobile/screens/login_screen.dart';
import 'package:roadix_mobile/services/geocoding_service.dart';
import 'package:roadix_mobile/src/core/router/app_router.dart';
import 'package:roadix_mobile/widgets/edit_profile_sheet.dart';
import 'package:roadix_mobile/widgets/roadix_avatar.dart';
import '../e2e/helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await E2ETestHarness.initializeAppEnvironment();
  });

  group('Router Auth & Role Guards', () {
    test('computeAuthRedirect enforces auth boundaries and role separation', () {
      expect(
        computeAuthRedirect(
          currentPath: AppRoutes.root,
          isSignedIn: false,
          userRole: null,
        ),
        equals(AppRoutes.splash),
      );

      // Signed-out users can access public paths, blocked from private routes
      expect(
        computeAuthRedirect(
          currentPath: AppRoutes.login,
          isSignedIn: false,
          userRole: null,
        ),
        isNull,
      );
      expect(
        computeAuthRedirect(
          currentPath: AppRoutes.sos,
          isSignedIn: false,
          userRole: null,
        ),
        isNull,
      );
      expect(
        computeAuthRedirect(
          currentPath: AppRoutes.home,
          isSignedIn: false,
          userRole: null,
        ),
        equals(AppRoutes.login),
      );
      expect(
        computeAuthRedirect(
          currentPath: AppRoutes.mechanic,
          isSignedIn: false,
          userRole: null,
        ),
        equals(AppRoutes.login),
      );

      // Signed-in motorist redirected off login and out of mechanic console
      expect(
        computeAuthRedirect(
          currentPath: AppRoutes.login,
          isSignedIn: true,
          userRole: 'motorist',
        ),
        equals(AppRoutes.home),
      );
      expect(
        computeAuthRedirect(
          currentPath: AppRoutes.mechanic,
          isSignedIn: true,
          userRole: 'motorist',
        ),
        equals(AppRoutes.home),
      );

      // Signed-in mechanic routed to mechanic console cleanly
      expect(
        computeAuthRedirect(
          currentPath: AppRoutes.login,
          isSignedIn: true,
          userRole: 'mechanic',
        ),
        equals(AppRoutes.mechanic),
      );
      expect(
        computeAuthRedirect(
          currentPath: AppRoutes.mechanic,
          isSignedIn: true,
          userRole: 'mechanic',
        ),
        isNull,
      );
    });
  });

  group('Geocoding, Routing & Google Maps URI', () {
    test('buildGoogleMapsDirectionsUri builds exact query parameters', () {
      final withOrigin = GeocodingService.buildGoogleMapsDirectionsUri(
        destLat: 23.7985,
        destLng: 90.4143,
        originLat: 23.8759,
        originLng: 90.3795,
      );
      expect(withOrigin.scheme, equals('https'));
      expect(withOrigin.host, equals('www.google.com'));
      expect(withOrigin.path, equals('/maps/dir/'));
      expect(withOrigin.queryParameters['api'], equals('1'));
      expect(withOrigin.queryParameters['travelmode'], equals('driving'));
      expect(
        withOrigin.queryParameters['destination'],
        equals('23.798500,90.414300'),
      );
      expect(
        withOrigin.queryParameters['origin'],
        equals('23.875900,90.379500'),
      );

      final destOnly = GeocodingService.buildGoogleMapsDirectionsUri(
        destLat: 22.3569,
        destLng: 91.8215,
      );
      expect(destOnly.queryParameters.containsKey('origin'), isFalse);
      expect(
        destOnly.queryParameters['destination'],
        equals('22.356900,91.821500'),
      );
    });

    test('detectDivision rejects out-of-bounds Bangladesh coordinates', () {
      expect(GeocodingService.detectDivision(20.4, 90.0), isEmpty);
      expect(GeocodingService.detectDivision(26.8, 90.0), isEmpty);
      expect(GeocodingService.detectDivision(23.8, 87.9), isEmpty);
      expect(GeocodingService.detectDivision(23.8, 92.8), isEmpty);
      expect(GeocodingService.detectDivision(23.8103, 90.4125), equals('Dhaka'));
    });

    test('fetchDrivingRoute falls back cleanly to Haversine straight-line geometry offline', () async {
      final route = await GeocodingService.fetchDrivingRoute(
        fromLat: 23.8759,
        fromLng: 90.3795,
        toLat: 23.7985,
        toLng: 90.4143,
      );
      expect(route.isRoadRouted, isFalse);
      expect(route.points.length, equals(2));
      expect(route.distanceKm, greaterThan(5.0));
      expect(route.durationMinutes, greaterThanOrEqualTo(2));
    });
  });

  group('Avatar Resolver & Gallery Upload', () {
    test('RoadixAvatar.resolveProvider resolves memory, data URI, network, and asset sources', () {
      final transparentPng = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      ]);
      expect(
        RoadixAvatar.resolveProvider(localBytes: transparentPng),
        isA<MemoryImage>(),
      );
      final b64 = base64Encode(transparentPng);
      expect(
        RoadixAvatar.resolveProvider(avatarUrl: 'data:image/png;base64,$b64'),
        isA<MemoryImage>(),
      );
      expect(
        RoadixAvatar.resolveProvider(avatarUrl: 'https://example.com/a.jpg'),
        isA<NetworkImage>(),
      );
      expect(
        RoadixAvatar.resolveProvider(avatarUrl: 'assets/images/logo.png'),
        isA<AssetImage>(),
      );
      expect(RoadixAvatar.resolveProvider(avatarUrl: ''), isNull);
    });

    testWidgets('EditProfileSheet Gallery upload previews, uploads once, and persists uploaded URL', (WidgetTester tester) async {
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      ImageSource? requestedSource;
      String? uploadedExt;
      int uploadCalls = 0;
      int saveCalls = 0;
      String? savedAvatar;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: EditProfileSheet(
              currentName: 'Tariq Hasan',
              currentPhone: '+8801711223344',
              pickImageOverride: (source) async {
                requestedSource = source;
                return XFile.fromData(
                  pngBytes,
                  name: 'photo.png',
                  mimeType: 'image/png',
                );
              },
              onUploadPhoto: (bytes, ext) async {
                uploadCalls++;
                uploadedExt = ext;
                return 'https://cdn.example.com/avatars/u1.png';
              },
              onSave: (name, phone, avatar) {
                saveCalls++;
                savedAvatar = avatar;
              },
            ),
          ),
          physicalSize: const Size(412, 915),
          tester: tester,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Gallery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(requestedSource, equals(ImageSource.gallery));
      expect(uploadCalls, equals(1));
      expect(uploadedExt, equals('png'));
      expect(find.text('Photo uploaded cleanly.'), findsOneWidget);

      await tester.ensureVisible(find.text('SAVE CHANGES'));
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pump();

      expect(saveCalls, equals(1));
      expect(savedAvatar, equals('https://cdn.example.com/avatars/u1.png'));

      await E2ETestHarness.cleanUp(tester);
    });
  });

  group('Accessibility Guideline Checks', () {
    testWidgets('LoginScreen, EditProfileSheet, and LocationConfirmScreen meet Android tap target and contrast guidelines', (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          E2ETestHarness.wrapWithApp(
            const LoginScreen(),
            physicalSize: const Size(412, 915),
            tester: tester,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await tester.pumpWidget(
          E2ETestHarness.wrapWithApp(
            const Scaffold(
              body: EditProfileSheet(
                currentName: 'Tanvir Ahmed',
                currentPhone: '+8801711000001',
              ),
            ),
            physicalSize: const Size(412, 915),
            tester: tester,
          ),
        );
        await tester.pump();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await tester.pumpWidget(
          E2ETestHarness.wrapWithApp(
            const LocationConfirmScreen(selectedFault: 'Dead Battery'),
            physicalSize: const Size(412, 915),
            tester: tester,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        handle.dispose();
        await E2ETestHarness.cleanUp(tester);
      }
    });
  });
}
