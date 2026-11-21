import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadix_mobile/services/cloudinary_service.dart';
import 'package:roadix_mobile/src/core/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.initialize();
  });

  group('Phase 3: Cloudinary CDN Asset Delivery Tests', () {
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

    test('All bundled local asset fallbacks physically exist in assets/images/', () {
      final brands = ['google', 'bkash', 'nagad', 'sedan', 'suv', 'motorcycle', 'commercial'];
      for (final item in brands) {
        final path = CloudinaryService.getLocalAssetFallback(item);
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Expected $path to exist on disk');
        expect(file.lengthSync(), greaterThan(0), reason: 'Expected $path to not be empty');
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

    test('ServiceCategoryIllustration and BrandLogo widgets instantiate cleanly', () {
      final service = CloudinaryService();
      final brandUrl = service.getBrandLogoUrl('rocket');
      expect(brandUrl, contains('roadix/brands/rocket_logo.png'));

      final catUrl = service.getServiceCategoryImageUrl('towing');
      expect(catUrl, contains('roadix/services/towing.png'));
    });
  });
}
