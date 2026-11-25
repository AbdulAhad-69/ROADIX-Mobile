import 'package:flutter/foundation.dart';

/// Explicit local Demo/Evaluation state used ONLY when the user chooses a Demo
/// One-Tap card on [LoginScreen] and backend anonymous sign-in is disabled or
/// running offline on a test device. Never used silently for real OAuth flows.
class DemoSession {
  DemoSession._();

  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static bool isActive = false;
  static String role = 'motorist';
  static String fullName = 'Tanvir Ahmed';
  static String phone = '+8801711000001';
  static String? avatarUrl;

  static List<Map<String, dynamic>> vehicles = [];
  static List<Map<String, dynamic>> emergencyContacts = [];
  static List<Map<String, dynamic>> wallets = [];
  static Map<String, dynamic>? mechanicProfile;
  static List<Map<String, dynamic>> serviceHistory = [];

  static void startDemo({
    required String demoRole,
    String? name,
    String? phoneNumber,
  }) {
    isActive = true;
    role = demoRole;
    if (demoRole == 'mechanic') {
      fullName = name ?? 'Rahim Uddin';
      phone = phoneNumber ?? '+8801811000011';
      mechanicProfile = {
        'profile_id': 'demo-mechanic-001',
        'workshop_name': 'Gulshan Auto Clinic',
        'workshop_address': 'Plot 14, Road 45, Gulshan 2, Dhaka',
        'is_on_duty': false,
        'is_verified': true,
        'rating': 4.85,
        'total_rescues': 142,
        'specializations': [
          'Flat Tire',
          'Dead Battery',
          'Engine Trouble',
          'Out of Fuel',
          'General Automotive Breakdown',
        ],
        'vehicle_specializations': ['Passenger Car', 'Motorcycle'],
      };
    } else {
      fullName = name ?? 'Tanvir Ahmed';
      phone = phoneNumber ?? '+8801711000001';
      vehicles = [
        {
          'id': 'demo-veh-1',
          'model': 'Toyota Corolla Axio',
          'plate': 'DHAKA METRO GA-11-2034',
          'type': 'Passenger Car',
          'fuel': 'Octane',
          'is_primary': true,
        },
        {
          'id': 'demo-veh-2',
          'model': 'Yamaha FZ-S V3',
          'plate': 'DHAKA METRO LA-24-8812',
          'type': 'Motorcycle',
          'fuel': 'Petrol',
          'is_primary': false,
        },
      ];
      emergencyContacts = [
        {
          'id': 'demo-contact-1',
          'name': 'Kamal Ahmed',
          'phone': '+8801712334455',
          'relation': 'Brother',
          'relationship': 'Brother',
        },
      ];
      wallets = [
        {
          'id': 'demo-wallet-1',
          'provider': 'bKash',
          'account_number': '01711000001',
          'is_primary': true,
        },
        {
          'id': 'demo-wallet-2',
          'provider': 'Nagad',
          'account_number': '01711000001',
          'is_primary': false,
        },
      ];
      mechanicProfile = null;
    }
    notifier.value++;
  }

  static void clear() {
    if (!isActive) return;
    isActive = false;
    role = 'motorist';
    avatarUrl = null;
    vehicles = [];
    emergencyContacts = [];
    wallets = [];
    mechanicProfile = null;
    serviceHistory = [];
    notifier.value++;
  }
}
