import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/services/cloudinary_service.dart';
import 'package:roadix_mobile/widgets/brand_logo.dart';
import 'package:roadix_mobile/widgets/wallet_editor_sheet.dart';
import '../helpers/e2e_finders.dart';
import '../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await E2ETestHarness.initializeAppEnvironment();
  });

  // =========================================================================
  // FEATURE 5: R2.1 Authentic Payment Logos (6 brands)
  // =========================================================================
  group('Feature 5: R2.1 Authentic Payment Logos (SRS §R2)', () {
    testWidgets('T1.5.1: BrandLogo(brand: "bkash") renders authentic bKash origami bird vector painter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(body: Center(child: BrandLogo(brand: 'bkash', size: 48, showBadge: false))),
        ),
      );
      await tester.pump();

      expect(E2EFinders.brandLogo('bkash'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      final customPaint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
            (cp) => cp.painter is BkashOrigamiBirdPainter,
          );
      expect(customPaint.painter, isA<BkashOrigamiBirdPainter>());

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.5.2: BrandLogo(brand: "google") renders authentic Google G vector painter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(body: Center(child: BrandLogo(brand: 'google', size: 48, showBadge: false))),
        ),
      );
      await tester.pump();

      expect(E2EFinders.brandLogo('google'), findsOneWidget);
      final customPaint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
            (cp) => cp.painter is GoogleGLogoPainter,
          );
      expect(customPaint.painter, isA<GoogleGLogoPainter>());

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.5.3: BrandLogo(brand: "upay") renders authentic UPay vector painter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(body: Center(child: BrandLogo(brand: 'upay', size: 48, showBadge: false))),
        ),
      );
      await tester.pump();

      expect(E2EFinders.brandLogo('upay'), findsOneWidget);
      final customPaint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
            (cp) => cp.painter is UpayLogoPainter,
          );
      expect(customPaint.painter, isA<UpayLogoPainter>());

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.5.4: BrandLogo(brand: "rocket") renders authentic Rocket DBBL vector painter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(body: Center(child: BrandLogo(brand: 'rocket', size: 48, showBadge: false))),
        ),
      );
      await tester.pump();

      expect(E2EFinders.brandLogo('rocket'), findsOneWidget);
      final customPaint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
            (cp) => cp.painter is RocketLogoPainter,
          );
      expect(customPaint.painter, isA<RocketLogoPainter>());

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.5.5: BrandLogo(brand: "nexuspay") renders authentic NexusPay vector painter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(body: Center(child: BrandLogo(brand: 'nexuspay', size: 48, showBadge: false))),
        ),
      );
      await tester.pump();

      expect(E2EFinders.brandLogo('nexuspay'), findsOneWidget);
      final customPaint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
            (cp) => cp.painter is NexusPayLogoPainter,
          );
      expect(customPaint.painter, isA<NexusPayLogoPainter>());

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.5.6: BrandLogo(brand: "ucash") renders authentic Ucash vector painter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(body: Center(child: BrandLogo(brand: 'ucash', size: 48, showBadge: false))),
        ),
      );
      await tester.pump();

      expect(E2EFinders.brandLogo('ucash'), findsOneWidget);
      final customPaint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
            (cp) => cp.painter is UcashLogoPainter,
          );
      expect(customPaint.painter, isA<UcashLogoPainter>());

      await E2ETestHarness.cleanUp(tester);
    });

    test('T1.5.7: CloudinaryService provides authentic fallback asset paths for all brands without generic logo', () {
      final brands = ['bkash', 'google', 'upay', 'rocket', 'nexuspay', 'ucash', 'nagad'];

      for (final brand in brands) {
        final path = CloudinaryService.getLocalAssetFallback(brand);
        expect(path, isNotEmpty);
        expect(path, isNot(equals('assets/images/logo.png')),
            reason: 'Brand "$brand" must not fall back to generic app logo "logo.png"');
      }
    });
  });

  // =========================================================================
  // FEATURE 6: R2.2 Aspect Ratio & Asset Scaling
  // =========================================================================
  group('Feature 6: R2.2 Aspect Ratio & Asset Scaling (SRS §R2)', () {
    testWidgets('T1.6.1: BrandLogo enforces 1:1 AspectRatio and BoxFit.contain across tree',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(body: Center(child: BrandLogo(brand: 'bkash', size: 36))),
        ),
      );
      await tester.pump();

      final aspectRatioFinder = find.descendant(
        of: find.byType(BrandLogo),
        matching: find.byType(AspectRatio),
      );
      expect(aspectRatioFinder, findsWidgets);

      final aspectRatio = tester.widget<AspectRatio>(aspectRatioFinder.first);
      expect(aspectRatio.aspectRatio, equals(1.0));

      final fittedBoxFinder = find.descendant(
        of: find.byType(BrandLogo),
        matching: find.byType(FittedBox),
      );
      expect(fittedBoxFinder, findsWidgets);
      final fittedBox = tester.widget<FittedBox>(fittedBoxFinder.first);
      expect(fittedBox.fit, equals(BoxFit.contain));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.6.2: Sizing scales cleanly across standard dimensions (16, 24, 32, 48, 64 px)',
        (WidgetTester tester) async {
      final sizes = [16.0, 24.0, 32.0, 48.0, 64.0];

      for (final size in sizes) {
        await tester.pumpWidget(
          E2ETestHarness.wrapWithApp(
            Scaffold(body: Center(child: BrandLogo(brand: 'google', size: size, showBadge: false))),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final brandLogo = tester.widget<BrandLogo>(find.byType(BrandLogo));
        expect(brandLogo.size, equals(size));

        final renderBox = tester.renderObject<RenderBox>(find.byType(BrandLogo));
        expect(renderBox.size.width, equals(size));
        expect(renderBox.size.height, equals(size));
      }

      await E2ETestHarness.cleanUp(tester);
    });

    test('T1.6.3: Custom vector painters execute canvas painting without throwing runtime exceptions', () {
      final painters = [
        const BkashOrigamiBirdPainter(isBadgeMode: true),
        const GoogleGLogoPainter(isBadgeMode: true),
        const UpayLogoPainter(isBadgeMode: true),
        const RocketLogoPainter(isBadgeMode: true),
        const NexusPayLogoPainter(isBadgeMode: true),
        const UcashLogoPainter(isBadgeMode: true),
        const NagadLogoPainter(isBadgeMode: true),
      ];

      for (final painter in painters) {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, const Size(120, 120));
        final picture = recorder.endRecording();
        expect(picture, isNotNull);
      }
    });

    test('T1.6.4: Official brand logo asset files have valid PNG signatures (>1KB)', () {
      const knownAssets = [
        'assets/images/bkash_logo.png',
        'assets/images/google_logo.png',
        'assets/images/nagad_logo.png',
      ];

      for (final assetPath in knownAssets) {
        final file = File(assetPath);
        if (file.existsSync()) {
          expect(file.lengthSync(), greaterThan(1000));
          final bytes = file.readAsBytesSync();
          // PNG magic header: 0x89, 'P', 'N', 'G'
          expect(bytes[0], equals(0x89));
          expect(bytes[1], equals(0x50));
          expect(bytes[2], equals(0x4E));
          expect(bytes[3], equals(0x47));
        }
      }
    });

    testWidgets('T1.6.5: BrandLogo rendered in constrained parent respects bounding width without overflow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: BrandLogo(brand: 'upay', size: 24, showBadge: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final renderBox = tester.renderObject<RenderBox>(find.byType(BrandLogo));
      expect(renderBox.size.width, equals(24.0));
      expect(renderBox.size.height, equals(24.0));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.6.6: BrandLogo with showBadge: true initializes network and fallback chain safely',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: Center(child: BrandLogo(brand: 'nexuspay', size: 40, showBadge: true)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(BrandLogo), findsOneWidget);
      expect(tester.takeException(), isNull);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 7: R2.3 Wallet Provider Expansion
  // =========================================================================
  group('Feature 7: R2.3 Wallet Provider Expansion (SRS §R2)', () {
    testWidgets('T1.7.1: WalletEditorSheet lists all 6 required providers in dropdown options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: WalletEditorSheet(wallets: []),
          ),
        ),
      );
      await tester.pump();

      expect(E2EFinders.walletEditorSheet, findsOneWidget);

      // Verify the 6 providers: bKash, Nagad, Rocket, Upay, NexusPay, Ucash
      final expectedProviders = ['bKash', 'Nagad', 'Rocket', 'Upay', 'NexusPay', 'Ucash'];
      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);

      final dropdown = tester.widget<DropdownButton<String>>(dropdownFinder);
      final itemValues = dropdown.items?.map((item) => item.value).toList();
      for (final provider in expectedProviders) {
        expect(itemValues, contains(provider));
      }

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.7.2: Adding a valid bKash wallet triggers onAddWallet callback',
        (WidgetTester tester) async {
      String? addedProvider;
      String? addedNumber;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: WalletEditorSheet(
              wallets: const [],
              onAddWallet: (provider, number) async {
                addedProvider = provider;
                addedNumber = number;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Enter phone number
      await tester.enterText(find.byType(TextField), '01711223344');
      await tester.pump();

      // Tap add button
      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();

      expect(addedProvider, equals('bKash'));
      expect(addedNumber, equals('01711223344'));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.7.3: Switching provider to Upay and adding wallet passes "Upay" provider',
        (WidgetTester tester) async {
      String? addedProvider;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: WalletEditorSheet(
              wallets: const [],
              onAddWallet: (provider, number) async {
                addedProvider = provider;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap dropdown to select Upay
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upay').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '01811334455');
      await tester.pump();

      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();

      expect(addedProvider, equals('Upay'));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.7.4: Setting a wallet as primary updates badge and invokes onSetPrimaryWallet',
        (WidgetTester tester) async {
      String? primaryWalletId;
      final initialWallets = [
        {'id': 'w-1', 'provider': 'bKash', 'number': '01711000001', 'isPrimary': false},
        {'id': 'w-2', 'provider': 'Rocket', 'number': '01811000002', 'isPrimary': true},
      ];

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: WalletEditorSheet(
              wallets: initialWallets,
              onSetPrimaryWallet: (id) async {
                primaryWalletId = id;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(E2EFinders.primaryBadge, findsOneWidget);

      // Tap the radio button of the first non-primary wallet
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pump();

      expect(primaryWalletId, equals('w-1'));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.7.5: Deleting a wallet removes it from list and invokes onDeleteWallet',
        (WidgetTester tester) async {
      String? deletedId;
      final initialWallets = [
        {'id': 'w-del-1', 'provider': 'bKash', 'number': '01711000001', 'isPrimary': false},
      ];

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: WalletEditorSheet(
              wallets: initialWallets,
              onDeleteWallet: (id) async {
                deletedId = id;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('01711000001'), findsOneWidget);

      // Tap delete button
      await tester.tap(E2EFinders.deleteWalletIcon);
      await tester.pump();

      expect(deletedId, equals('w-del-1'));
      expect(find.textContaining('01711000001'), findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T1.7.6: Entering an invalid mobile number (<11 digits) displays error validation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: WalletEditorSheet(wallets: []),
          ),
        ),
      );
      await tester.pump();

      // Enter short number (6 digits)
      await tester.enterText(find.byType(TextField), '017112');
      await tester.pump();

      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();

      expect(find.textContaining('Please enter an 11-digit mobile wallet number'), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });
}
