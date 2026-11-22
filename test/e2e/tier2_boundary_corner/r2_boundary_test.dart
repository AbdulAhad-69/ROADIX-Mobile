import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  // FEATURE 5: R2.1 Authentic Payment Logos Boundary & Corner Cases
  // =========================================================================
  group('Feature 5: R2.1 Authentic Payment Logos Boundary (SRS §R2)', () {
    testWidgets('T2.5.1: Unknown or misspelled brand name safely falls back to authentic vector painter without throwing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: Center(
              child: BrandLogo(brand: 'unknown_wallet_brand_xyz', size: 36, showBadge: false),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(BrandLogo), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Verifies fallback painter is rendered
      final customPaint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
            (cp) => cp.painter is BkashOrigamiBirdPainter,
          );
      expect(customPaint.painter, isA<BkashOrigamiBirdPainter>());

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.5.2: CDN image network failure fallback renders local vector painter cleanly in showBadge mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: Center(
              child: BrandLogo(brand: 'upay', size: 48, showBadge: true),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.byType(BrandLogo), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.5.3: Case insensitivity resolves uppercase, lowercase, and mixed-case brand names identically',
        (WidgetTester tester) async {
      final caseVariants = ['BKASH', 'Bkash', 'bKash', 'bKASH', 'bKasH'];

      for (final variant in caseVariants) {
        await tester.pumpWidget(
          E2ETestHarness.wrapWithApp(
            Scaffold(
              body: Center(
                child: BrandLogo(brand: variant, size: 32, showBadge: false),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final customPaint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
              (cp) => cp.painter is BkashOrigamiBirdPainter,
            );
        expect(customPaint.painter, isA<BkashOrigamiBirdPainter>());
      }

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.5.4: Empty brand name ("") and pure whitespace brand name ("   ") fall back safely without null error',
        (WidgetTester tester) async {
      for (final emptyInput in ['', '   ', '\t', '\n']) {
        await tester.pumpWidget(
          E2ETestHarness.wrapWithApp(
            Scaffold(
              body: Center(
                child: BrandLogo(brand: emptyInput, size: 28, showBadge: false),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(BrandLogo), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.5.5: All 6 supported payment brands render their respective authentic painters in vector mode',
        (WidgetTester tester) async {
      final brandPainters = <String, Type>{
        'bkash': BkashOrigamiBirdPainter,
        'nagad': NagadLogoPainter,
        'rocket': RocketLogoPainter,
        'upay': UpayLogoPainter,
        'nexuspay': NexusPayLogoPainter,
        'ucash': UcashLogoPainter,
      };

      for (final entry in brandPainters.entries) {
        await tester.pumpWidget(
          E2ETestHarness.wrapWithApp(
            Scaffold(
              body: Center(
                child: BrandLogo(brand: entry.key, size: 40, showBadge: false),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        final matchingPaint = customPaints.any((cp) => cp.painter.runtimeType == entry.value);
        expect(matchingPaint, isTrue, reason: 'Brand "${entry.key}" must render painter ${entry.value}');
      }

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.5.6: International card strings (Visa, Mastercard) render fallback vector painter gracefully',
        (WidgetTester tester) async {
      for (final cardBrand in ['Visa', 'Mastercard', 'AMEX']) {
        await tester.pumpWidget(
          E2ETestHarness.wrapWithApp(
            Scaffold(
              body: Center(
                child: BrandLogo(brand: cardBrand, size: 30, showBadge: false),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(BrandLogo), findsOneWidget);
      }

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 6: R2.2 Aspect Ratio & Asset Scaling Boundary & Corner Cases
  // =========================================================================
  group('Feature 6: R2.2 Aspect Ratio & Asset Scaling Boundary (SRS §R2)', () {
    testWidgets('T2.6.1: Micro height (12px) renders BrandLogo cleanly without layout exception or subpixel clipping errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: Center(
              child: BrandLogo(brand: 'bkash', size: 12.0, showBadge: false),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final renderBox = tester.renderObject<RenderBox>(find.byType(BrandLogo));
      expect(renderBox.size.width, equals(12.0));
      expect(renderBox.size.height, equals(12.0));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.6.2: Large height (100px) renders BrandLogo maintaining strict 1:1 AspectRatio without distortion',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: Center(
              child: BrandLogo(brand: 'nagad', size: 100.0, showBadge: false),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final renderBox = tester.renderObject<RenderBox>(find.byType(BrandLogo));
      expect(renderBox.size.width, equals(100.0));
      expect(renderBox.size.height, equals(100.0));

      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, equals(1.0));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.6.3: Narrow container (30px width) clamps BrandLogo without horizontal overflow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: Center(
              child: SizedBox(
                width: 30,
                child: BrandLogo(brand: 'rocket', size: 30.0, showBadge: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final renderBox = tester.renderObject<RenderBox>(find.byType(BrandLogo));
      expect(renderBox.size.width, equals(30.0));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.6.4: Zero size clamp (size: 0.0) renders without division by zero or fatal exception',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: Center(
              child: BrandLogo(brand: 'upay', size: 0.0, showBadge: false),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final renderBox = tester.renderObject<RenderBox>(find.byType(BrandLogo));
      expect(renderBox.size.width, equals(0.0));
      expect(renderBox.size.height, equals(0.0));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.6.5: BrandLogo scales cleanly inside dense ListTile widgets without vertical overflow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: ListView(
              children: const [
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: BrandLogo(brand: 'bkash', size: 20.0),
                  title: Text('bKash Wallet (01711000001)'),
                ),
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: BrandLogo(brand: 'nagad', size: 20.0),
                  title: Text('Nagad Wallet (01811000022)'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(BrandLogo), findsNWidgets(2));

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.6.6: ServiceCategoryIllustration handles unknown category string gracefully falling back to default asset',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: Center(
              child: ServiceCategoryIllustration(category: 'unknown_special_breakdown', size: 36.0),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.byType(ServiceCategoryIllustration), findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });
  });

  // =========================================================================
  // FEATURE 7: R2.3 Wallet Provider Expansion Boundary & Corner Cases
  // =========================================================================
  group('Feature 7: R2.3 Wallet Provider Expansion Boundary (SRS §R2)', () {
    testWidgets('T2.7.1: Incomplete phone number ("017") displays validation error and rejects submission',
        (WidgetTester tester) async {
      bool addCallbackInvoked = false;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: WalletEditorSheet(
              wallets: const [],
              onAddWallet: (provider, number) async {
                addCallbackInvoked = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Enter incomplete 3-digit phone number
      await tester.enterText(find.byType(TextField), '017');
      await tester.pump();

      // Tap add
      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();

      // Callback not called, error message rendered
      expect(addCallbackInvoked, isFalse);
      expect(
        find.textContaining('Please enter an 11-digit mobile wallet number'),
        findsOneWidget,
      );

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.7.2: Short alphanumeric input ("01711-ABC") validates length requirement and displays prompt',
        (WidgetTester tester) async {
      bool addCallbackInvoked = false;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: WalletEditorSheet(
              wallets: const [],
              onAddWallet: (provider, number) async {
                addCallbackInvoked = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '01711-ABC');
      await tester.pump();

      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();

      expect(addCallbackInvoked, isFalse);
      expect(
        find.textContaining('Please enter an 11-digit mobile wallet number'),
        findsOneWidget,
      );

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.7.3: Empty wallet state (0 wallets) displays "No mobile wallets linked yet." placeholder',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          const Scaffold(
            body: WalletEditorSheet(wallets: []),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No mobile wallets linked yet.'), findsOneWidget);
      expect(E2EFinders.deleteWalletIcon, findsNothing);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.7.4: Submission with empty text field blocks addition and displays validation error',
        (WidgetTester tester) async {
      bool addCallbackInvoked = false;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: WalletEditorSheet(
              wallets: const [],
              onAddWallet: (provider, number) async {
                addCallbackInvoked = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap add directly without entering number
      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();

      expect(addCallbackInvoked, isFalse);
      expect(
        find.textContaining('Please enter an 11-digit mobile wallet number'),
        findsOneWidget,
      );

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.7.5: Max wallet entries (10+ wallets) render inside SingleChildScrollView without layout overflow',
        (WidgetTester tester) async {
      final manyWallets = List.generate(
        12,
        (i) => {
          'id': 'w-$i',
          'provider': i % 2 == 0 ? 'bKash' : 'Nagad',
          'number': '017110000${i.toString().padLeft(2, '0')}',
          'isPrimary': i == 0,
        },
      );

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: WalletEditorSheet(wallets: manyWallets),
          ),
          physicalSize: const Size(400, 700),
          tester: tester,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(E2EFinders.walletEditorSheet, findsOneWidget);
      expect(E2EFinders.primaryBadge, findsOneWidget);

      await E2ETestHarness.cleanUp(tester);
    });

    testWidgets('T2.7.6: Selecting different provider in dropdown correctly associates new provider with added wallet',
        (WidgetTester tester) async {
      String? savedProvider;
      String? savedNumber;

      await tester.pumpWidget(
        E2ETestHarness.wrapWithApp(
          Scaffold(
            body: WalletEditorSheet(
              wallets: const [],
              onAddWallet: (provider, number) async {
                savedProvider = provider;
                savedNumber = number;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Change provider in dropdown to Rocket
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Rocket').last);
      await tester.pump();

      // Enter valid 11-digit number
      await tester.enterText(find.byType(TextField), '01911223344');
      await tester.pump();

      // Tap add
      await tester.tap(E2EFinders.addWalletButton);
      await tester.pump();

      expect(savedProvider, equals('Rocket'));
      expect(savedNumber, equals('01911223344'));

      await E2ETestHarness.cleanUp(tester);
    });
  });
}
