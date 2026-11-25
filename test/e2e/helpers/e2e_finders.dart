import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/widgets/brand_logo.dart';
import 'package:roadix_mobile/widgets/wallet_editor_sheet.dart';

/// Semantic Finder Library for ROADIX Mobile Requirement-Driven Tests
class E2EFinders {
  const E2EFinders._();

  // =========================================================================
  // R1: Map & Live Tracking Finders
  // =========================================================================
  static Finder get recenterButton => find.byIcon(Icons.my_location);
  static Finder get gpsLockBadge => find.text('GPS LOCK');
  static Finder get breakdownMarker => find.text('BREAKDOWN POSITION');
  static Finder get confirmLocationButton =>
      find.widgetWithText(ElevatedButton, 'CONFIRM LOCATION');
  static Finder get addressPinIcon => find.byIcon(Icons.pin_drop);

  static Finder quickZoneChip(String label) => find.text(label);

  // =========================================================================
  // R2: Branding & Payment Logos Finders
  // =========================================================================
  static Finder get brandLogoType => find.byType(BrandLogo);

  static Finder brandLogo(String brandName) => find.byWidgetPredicate(
        (widget) =>
            widget is BrandLogo &&
            widget.brand.toLowerCase().trim() == brandName.toLowerCase().trim(),
        description: 'BrandLogo with brand matching "$brandName"',
      );

  static Finder get walletEditorSheet => find.byType(WalletEditorSheet);
  static Finder get addWalletButton => find.widgetWithText(ElevatedButton, 'Add');
  static Finder get primaryBadge => find.text('Primary authorization');
  static Finder get deleteWalletIcon => find.byIcon(Icons.delete_outline);

  // =========================================================================
  // R3: Screen Redesign & Visual Polish Finders
  // =========================================================================
  // Emergency Home
  static Finder get sosHomeButton => find.text('SOS');
  static Finder get pressForHelpText => find.text('TAP FOR HELP');
  static Finder get triageSectionTitle => find.text('What do you need help with?');
  static Finder get activeRescueBanner => find.text('ACTIVE RESCUE IN PROGRESS');
  static Finder get profileAvatarHeader => find.byType(CircleAvatar);

  static Finder breakdownCategory(String name) => find.text(name);

  // SOS Screen
  static Finder get tapToCancelButton => find.textContaining('TAP TO CANCEL');
  static Finder get sosActiveBadge => find.text('EMERGENCY SOS ACTIVE');
  static Finder get sosCancelledBanner => find.text('CANCELLED');
  static Finder get highwayPatrolCard => find.text('CALL HIGHWAY PATROL');
  static Finder get nationalAmbulanceCard => find.text('CALL AMBULANCE');

  // Vehicle Classification
  static Finder get motorcycleCard => find.text('Motorcycle');
  static Finder get sedanCard => find.text('Sedan / Hatch');
  static Finder get suvCard => find.text('SUV / Micro');
  static Finder get commercialCard => find.text('Commercial');
  static Finder get continueToFaultButton =>
      find.widgetWithText(ElevatedButton, 'CONTINUE TO FAULT DETAILS');

  // Fault Details
  static Finder get heroFaultSummaryCard => find.text('Fault Diagnostics');
  static Finder get liveLaneHazardSwitch => find.byWidgetPredicate(
        (widget) => widget is Switch,
        description: 'Live highway lane hazard toggle switch',
      );
  static Finder get requestMechanicButton =>
      find.widgetWithText(ElevatedButton, 'FIND NEARBY MECHANICS');

  // Login Screen
  static Finder get googleSignInButton =>
      find.widgetWithText(OutlinedButton, 'Continue with Google');
  static Finder get motoristRoleTab => find.byKey(const Key('signup_role_motorist'));
  static Finder get mechanicRoleTab => find.byKey(const Key('signup_role_technician'));
  static Finder get motoristDemoButton => find.byKey(const Key('demo_motorist_btn'));
  static Finder get mechanicDemoButton => find.byKey(const Key('demo_technician_btn'));

  // Profile Screen
  static Finder get editProfileButton => find.byIcon(Icons.edit);
  static Finder get logoutButton =>
      find.widgetWithText(TextButton, 'Log Out & Return to Login');
  static Finder get digitalGarageHeader => find.text('Digital Garage');
  static Finder get linkedWalletsHeader => find.text('Payment Wallets');
  static Finder get emergencyContactsHeader => find.text('Emergency Contacts');
}
