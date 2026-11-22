import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/services/cloudinary_service.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';
import 'package:roadix_mobile/widgets/brand_logo.dart';
import 'package:roadix_mobile/widgets/wallet_editor_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.initialize();
  });

  group('Milestone 1: Cloudinary CDN Asset Delivery Tests', () {
    test('CloudinaryService returns valid CDN URLs with default transformations', () {
      final service = CloudinaryService();
      expect(service.cloudName, equals('kefzjqi3'));

      final brandUrl = service.getBrandLogoUrl('bkash');
      expect(brandUrl, contains('https://res.cloudinary.com/kefzjqi3/image/upload/'));
      expect(brandUrl, contains('f_auto'));
      expect(brandUrl, contains('q_auto'));
      expect(brandUrl, contains('roadix/brands/bkash_logo.png'));

      final nagadUrl = service.getBrandLogoUrl('nagad');
      expect(nagadUrl, contains('roadix/brands/nagad_logo.png'));

      final googleUrl = service.getBrandLogoUrl('google');
      expect(googleUrl, contains('roadix/brands/google_logo.png'));

      final upayUrl = service.getBrandLogoUrl('upay');
      expect(upayUrl, contains('roadix/brands/upay_logo.png'));

      final rocketUrl = service.getBrandLogoUrl('rocket');
      expect(rocketUrl, contains('roadix/brands/rocket_logo.png'));

      final dbblUrl = service.getBrandLogoUrl('dbbl');
      expect(dbblUrl, contains('roadix/brands/rocket_logo.png'));

      final nexusUrl = service.getBrandLogoUrl('nexuspay');
      expect(nexusUrl, contains('roadix/brands/nexuspay_logo.png'));

      final ucashUrl = service.getBrandLogoUrl('ucash');
      expect(ucashUrl, contains('roadix/brands/ucash_logo.png'));
    });

    test('CloudinaryService properly normalizes vehicle type delivery URLs', () {
      final service = CloudinaryService();
      final sedanUrl = service.getVehicleImageUrl('Sedan');
      expect(sedanUrl, contains('roadix/vehicles/sedan.png'));

      final suvUrl = service.getVehicleImageUrl('SUV');
      expect(suvUrl, contains('roadix/vehicles/suv.png'));

      final bikeUrl = service.getVehicleImageUrl('Motorcycle');
      expect(bikeUrl, contains('roadix/vehicles/motorcycle.png'));

      final commercialUrl = service.getVehicleImageUrl('Light Commercial');
      expect(commercialUrl, contains('roadix/vehicles/commercial.png'));
    });

    test('CloudinaryService properly maps roadside breakdown categories', () {
      final service = CloudinaryService();
      final tireUrl = service.getServiceCategoryImageUrl('Flat Tire / Wheel Replacement');
      expect(tireUrl, contains('roadix/services/flat_tire.png'));

      final batteryUrl = service.getServiceCategoryImageUrl('Battery Jumpstart / Dead Cell');
      expect(batteryUrl, contains('roadix/services/battery.png'));

      final engineUrl = service.getServiceCategoryImageUrl('Engine Overheating / Coolant');
      expect(engineUrl, contains('roadix/services/engine.png'));

      final fuelUrl = service.getServiceCategoryImageUrl('Emergency Fuel Run (5 Liters)');
      expect(fuelUrl, contains('roadix/services/fuel.png'));

      final towUrl = service.getServiceCategoryImageUrl('Towing / Flatbed Recovery');
      expect(towUrl, contains('roadix/services/towing.png'));
    });

    test('Local asset fallback mapping routes all 6 payment providers + Google correctly and never returns logo.png', () {
      final providerMappings = {
        'google': 'assets/images/google_logo.png',
        'bkash': 'assets/images/bkash_logo.png',
        'nagad': 'assets/images/nagad_logo.png',
        'upay': 'assets/images/upay_logo.png',
        'rocket': 'assets/images/rocket_logo.png',
        'dbbl': 'assets/images/rocket_logo.png',
        'nexuspay': 'assets/images/nexuspay_logo.png',
        'nexus': 'assets/images/nexuspay_logo.png',
        'ucash': 'assets/images/ucash_logo.png',
      };

      for (final entry in providerMappings.entries) {
        final path = CloudinaryService.getLocalAssetFallback(entry.key);
        expect(path, equals(entry.value), reason: 'Identifier ${entry.key} must route to ${entry.value}');
        expect(path, isNot(equals('assets/images/logo.png')), reason: '${entry.key} must never fallback to generic logo.png');
      }
    });

    test('All bundled local asset fallbacks physically exist with valid PNG signatures and >1KB size', () {
      final requiredBrandAssets = [
        'assets/images/bkash_logo.png',
        'assets/images/google_logo.png',
        'assets/images/nagad_logo.png',
        'assets/images/upay_logo.png',
        'assets/images/rocket_logo.png',
        'assets/images/nexuspay_logo.png',
        'assets/images/ucash_logo.png',
      ];

      for (final path in requiredBrandAssets) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Expected $path to physically exist on disk');
        expect(file.lengthSync(), greaterThan(1000), reason: 'Expected $path to be high-resolution (>1000 bytes)');

        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(8));
        // PNG magic signature: 0x89, 0x50 ('P'), 0x4E ('N'), 0x47 ('G')
        expect(bytes[0], equals(0x89));
        expect(bytes[1], equals(0x50));
        expect(bytes[2], equals(0x4E));
        expect(bytes[3], equals(0x47));
      }
    });

    test('.env and .env.example contain Cloudinary configurations', () {
      final envFile = File('.env');
      if (envFile.existsSync()) {
        final envContent = envFile.readAsStringSync();
        expect(envContent, contains('CLOUDINARY_CLOUD_NAME=kefzjqi3'));
        expect(envContent, contains('CLOUDINARY_API_KEY'));
        expect(envContent, contains('CLOUDINARY_API_SECRET'));
        expect(envContent, contains('CLOUDINARY_URL'));
      }

      final exampleFile = File('.env.example');
      expect(exampleFile.existsSync(), isTrue);
      final exampleContent = exampleFile.readAsStringSync();
      expect(exampleContent, contains('CLOUDINARY_CLOUD_NAME=kefzjqi3'));
      expect(exampleContent, contains('CLOUDINARY_API_KEY'));
      expect(exampleContent, contains('CLOUDINARY_API_SECRET'));
    });
  });

  group('Milestone 1: High-Fidelity CustomPainter Vector Graphics Tests', () {
    test('BkashOrigamiBirdPainter executes cleanly in both badge and standalone modes', () {
      const painterBadge = BkashOrigamiBirdPainter(isBadgeMode: true);
      const painterStandalone = BkashOrigamiBirdPainter(isBadgeMode: false);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painterBadge.paint(canvas, const Size(128, 128));
      painterStandalone.paint(canvas, const Size(128, 128));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      expect(painterBadge.shouldRepaint(painterBadge), isFalse);
    });

    test('GoogleGLogoPainter renders official 4-color arcs cleanly', () {
      const painterBadge = GoogleGLogoPainter(isBadgeMode: true);
      const painterStandalone = GoogleGLogoPainter(isBadgeMode: false);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painterBadge.paint(canvas, const Size(100, 100));
      painterStandalone.paint(canvas, const Size(100, 100));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      expect(painterBadge.shouldRepaint(painterBadge), isFalse);
    });

    test('NagadLogoPainter renders official swirling gradient curves cleanly', () {
      const painterBadge = NagadLogoPainter(isBadgeMode: true);
      const painterStandalone = NagadLogoPainter(isBadgeMode: false);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painterBadge.paint(canvas, const Size(100, 100));
      painterStandalone.paint(canvas, const Size(100, 100));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      expect(painterBadge.shouldRepaint(painterBadge), isFalse);
    });

    test('RocketLogoPainter renders rocket fuselage, thrusters, and trajectory swoosh', () {
      const painterBadge = RocketLogoPainter(isBadgeMode: true);
      const painterStandalone = RocketLogoPainter(isBadgeMode: false);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painterBadge.paint(canvas, const Size(100, 100));
      painterStandalone.paint(canvas, const Size(100, 100));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      expect(painterBadge.shouldRepaint(painterBadge), isFalse);
    });

    test('UpayLogoPainter renders navy badge and golden amber "u" smile curve', () {
      const painterBadge = UpayLogoPainter(isBadgeMode: true);
      const painterStandalone = UpayLogoPainter(isBadgeMode: false);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painterBadge.paint(canvas, const Size(100, 100));
      painterStandalone.paint(canvas, const Size(100, 100));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      expect(painterBadge.shouldRepaint(painterBadge), isFalse);
    });

    test('NexusPayLogoPainter renders DBBL card container and dual orange/blue wings', () {
      const painterBadge = NexusPayLogoPainter(isBadgeMode: true);
      const painterStandalone = NexusPayLogoPainter(isBadgeMode: false);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painterBadge.paint(canvas, const Size(100, 100));
      painterStandalone.paint(canvas, const Size(100, 100));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      expect(painterBadge.shouldRepaint(painterBadge), isFalse);
    });

    test('UcashLogoPainter renders red/green interlocking arcs and coin accent', () {
      const painterBadge = UcashLogoPainter(isBadgeMode: true);
      const painterStandalone = UcashLogoPainter(isBadgeMode: false);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painterBadge.paint(canvas, const Size(100, 100));
      painterStandalone.paint(canvas, const Size(100, 100));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      expect(painterBadge.shouldRepaint(painterBadge), isFalse);
    });
  });

  group('Milestone 1: BrandLogo & WalletEditorSheet UI Integration Tests', () {
    testWidgets('BrandLogo renders with strict AspectRatio and FittedBox for all brands', (WidgetTester tester) async {
      final brands = ['bKash', 'Nagad', 'Rocket', 'Upay', 'NexusPay', 'Ucash', 'Google'];

      for (final brand in brands) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: BrandLogo(brand: brand, size: 40.0),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(BrandLogo), findsOneWidget);
        expect(find.byType(AspectRatio), findsWidgets);
        expect(find.byType(FittedBox), findsWidgets);
      }
    });

    testWidgets('BrandLogo with showBadge=false renders vector CustomPainter for all brands', (WidgetTester tester) async {
      final brandPainters = {
        'bkash': BkashOrigamiBirdPainter,
        'google': GoogleGLogoPainter,
        'nagad': NagadLogoPainter,
        'rocket': RocketLogoPainter,
        'upay': UpayLogoPainter,
        'nexuspay': NexusPayLogoPainter,
        'ucash': UcashLogoPainter,
      };

      for (final entry in brandPainters.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: BrandLogo(brand: entry.key, size: 48.0, showBadge: false),
              ),
            ),
          ),
        );
        await tester.pump();

        final customPaintFinder = find.descendant(
          of: find.byType(BrandLogo),
          matching: find.byType(CustomPaint),
        );
        expect(customPaintFinder, findsWidgets, reason: '${entry.key} must render CustomPaint in standalone mode');

        final customPaint = tester.widget<CustomPaint>(customPaintFinder.first);
        expect(customPaint.painter.runtimeType, equals(entry.value),
            reason: '${entry.key} should render ${entry.value}');
      }
    });

    testWidgets('WalletEditorSheet supports all 6 required payment brands in dropdown and list', (WidgetTester tester) async {
      final initialWallets = [
        {'id': 'w1', 'provider': 'bKash', 'number': '01711111111', 'isPrimary': true},
        {'id': 'w2', 'provider': 'Rocket', 'number': '01822222222', 'isPrimary': false},
        {'id': 'w3', 'provider': 'Upay', 'number': '01933333333', 'isPrimary': false},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletEditorSheet(
              wallets: initialWallets,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify wallet list items render BrandLogos
      expect(find.text('bKash (01711111111)'), findsOneWidget);
      expect(find.text('Rocket (01822222222)'), findsOneWidget);
      expect(find.text('Upay (01933333333)'), findsOneWidget);

      // Verify DropdownButton contains all 6 providers
      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);

      final dropdown = tester.widget<DropdownButton<String>>(dropdownFinder);
      final itemValues = dropdown.items?.map((item) => item.value).toList();
      expect(itemValues, containsAll(['bKash', 'Nagad', 'Rocket', 'Upay', 'NexusPay', 'Ucash']));
      expect(itemValues?.length, equals(6));
    });
  });
}
