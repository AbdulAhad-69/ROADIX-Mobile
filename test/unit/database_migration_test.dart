import 'dart:io';
import 'package:test/test.dart';
import 'package:roadix_mobile/screens/vehicle_select_screen.dart';
import 'package:roadix_mobile/widgets/vehicle_editor_sheet.dart';

void main() {
  group('Database Migration Structure Tests', () {
    test('all 6 ordered SQL migration files exist and are populated', () {
      final migrationFiles = [
        'supabase/migrations/20261118000001_create_extensions_and_enums.sql',
        'supabase/migrations/20261118000002_create_profiles_and_mechanics.sql',
        'supabase/migrations/20261118000003_create_service_requests_and_dispatch.sql',
        'supabase/migrations/20261118000004_create_functions_and_procedures.sql',
        'supabase/migrations/20261118000005_create_row_level_security.sql',
        'supabase/migrations/20261118000007_fix_dispatch_scoring.sql',
      ];

      for (final path in migrationFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path must exist on disk');
        final content = file.readAsStringSync();
        expect(content.trim().length, greaterThan(100),
            reason: '$path must contain valid SQL DDL');
      }
    });

    test('seed.sql exists and contains valid development seed records', () {
      final file = File('supabase/seed.sql');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('standard_rate_cards'));
      expect(content, contains('Gulshan Auto Clinic'));
      expect(content, contains('Dhanmondi Rapid Fix'));
      expect(content, contains('Uttara Highway Rescue'));
      expect(content, contains('Mirpur Motor Works'));
      expect(content, contains('mechanic_verifications'));
      expect(content, contains('instance_id'));
      expect(content, contains('ST_SetSRID'));
    });
  });

  group('PostGIS and Spatial Schema Verification', () {
    test('migration 1 enables postgis, uuid-ossp, and pgcrypto', () {
      final content = File(
              'supabase/migrations/20261118000001_create_extensions_and_enums.sql')
          .readAsStringSync();
      expect(content, contains('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'));
      expect(content, contains('CREATE EXTENSION IF NOT EXISTS "pgcrypto"'));
      expect(content, contains('CREATE EXTENSION IF NOT EXISTS "postgis"'));
    });

    test('migration 2 isolates government NID verifications from mechanic telemetry', () {
      final content = File(
              'supabase/migrations/20261118000002_create_profiles_and_mechanics.sql')
          .readAsStringSync();
      expect(content, contains('GEOGRAPHY(Point, 4326)'));
      expect(content, contains('USING GIST(current_location)'));
      expect(content, contains('TABLE IF NOT EXISTS public.mechanic_verifications'));
      expect(content, contains('trade_license_number'));
      expect(content, contains('nid_number'));
      expect(content, contains('idx_mechanics_duty_verified'));
    });

    test('migration 3 enforces approved discrete search radius progression up to 15 km', () {
      final content = File(
              'supabase/migrations/20261118000003_create_service_requests_and_dispatch.sql')
          .readAsStringSync();
      expect(content, contains('breakdown_location GEOGRAPHY(Point, 4326)'));
      expect(content, contains('USING GIST(breakdown_location)'));
      expect(content, contains('search_radius_km IN (5.00, 7.50, 10.00, 12.50, 15.00)'),
          reason: 'Search radius must strictly enforce approved discrete progression');
      expect(content, contains("INTERVAL '45 seconds'"));
      expect(content, contains('GENERATED ALWAYS AS (inspection_fee + labor_fee + parts_fee) STORED'));
      expect(content, contains('idx_dispatch_offers_expires'));
    });
  });

  group('Stored Procedures and Security Hardening Verification', () {
    test('functions enforce search_path, caller validation, and atomic row locking', () {
      final content = File(
              'supabase/migrations/20261118000004_create_functions_and_procedures.sql')
          .readAsStringSync();

      expect(content, contains('SET search_path = public, pg_temp'));
      expect(content, contains('FUNCTION public.find_eligible_mechanics'));
      expect(content, contains('FUNCTION public.create_service_request'));
      expect(content, contains('FUNCTION public.accept_dispatch_offer'));
      expect(content, contains('FUNCTION public.update_mechanic_location'));
      expect(content, contains('FUNCTION public.calculate_dispatch_score'));
      expect(content, contains('FUNCTION public.handle_new_user'));
      expect(content, contains('FUNCTION public.expand_dispatch_radius'));
      expect(content, contains('FUNCTION public.respond_to_quotation'));
      expect(content, contains('FUNCTION public.admin_override_service_request'));

      // Validate coordinate validation
      expect(content, contains('p_breakdown_lat NOT BETWEEN -90 AND 90'));
      expect(content, contains('15000'), reason: 'find_eligible_mechanics must clamp to 15km');

      // Discrete +2.50 km expansion logic
      expect(content, contains('LEAST(v_req.search_radius_km + 2.50, 15.00)'));

      // Quotation response procedure checks
      expect(content, contains("p_decision NOT IN ('approved','rejected')"));
      expect(content, contains('v_req.motorist_id <> v_user'));
      expect(content, contains('v_req.mechanic_id IS DISTINCT FROM v_quote.mechanic_id'));

      // Concurrency locking
      expect(content, contains('FOR UPDATE'));
      expect(content, contains('v_offer.expires_at <= now()'));
      expect(content, contains("v_request.status <> 'searching'"));
      expect(content, contains("status = 'accepted'"));
      expect(content, contains("status = 'cancelled'"));

      // Execution privileges
      expect(content, contains('REVOKE ALL ON FUNCTION public.create_service_request('));
      expect(content, contains('GRANT EXECUTE ON FUNCTION public.create_service_request('));
      expect(content, contains('REVOKE ALL ON FUNCTION public.expand_dispatch_radius(UUID) FROM PUBLIC'));
      expect(content, contains('GRANT EXECUTE ON FUNCTION public.expand_dispatch_radius(UUID) TO authenticated'));
      expect(content, contains('REVOKE ALL ON FUNCTION public.respond_to_quotation(UUID, TEXT) FROM PUBLIC'));
      expect(content, contains('GRANT EXECUTE ON FUNCTION public.respond_to_quotation(UUID, TEXT) TO authenticated'));
    });
  });

  group('Row-Level Security (RLS) Policy Coverage & Hardening Verification', () {
    test('migration 5 enables RLS on all 13 entities, enforces quotation trigger, and gates location', () {
      final content = File(
              'supabase/migrations/20261118000005_create_row_level_security.sql')
          .readAsStringSync();

      final requiredTables = [
        'public.profiles',
        'public.mechanic_profiles',
        'public.mechanic_verifications',
        'public.vehicles',
        'public.emergency_contacts',
        'public.wallets',
        'public.service_requests',
        'public.dispatch_offers',
        'public.quotations',
        'public.transactions',
        'public.reviews',
        'public.standard_rate_cards',
        'public.admin_audit_logs',
      ];

      for (final table in requiredTables) {
        expect(content, contains('ALTER TABLE $table ENABLE ROW LEVEL SECURITY;'),
            reason: '$table must have RLS explicitly enabled');
      }

      // Verify active session location-sharing gate
      expect(content, contains("sr.status IN ('assigned','en_route','arrived','diagnosing','quote_pending','servicing')"),
          reason: 'Mechanic location must only be accessible during active service sessions');

      // Verify government NID document protection
      expect(content, contains('mechanic_verifications_select_owner_admin'));

      // Verify quotation least-privilege & anti-tampering access control
      expect(content, contains('CREATE POLICY quotations_select_participants ON public.quotations'));
      expect(content, contains('REVOKE ALL ON public.quotations FROM PUBLIC, anon, authenticated;'));
      expect(content, contains('GRANT SELECT ON public.quotations TO authenticated;'));

      // Verify service request state machine & radius protection trigger
      expect(content, contains('trg_validate_service_request_mutation'));
      expect(content, contains('FUNCTION public.check_service_request_mutation()'));
      expect(content, contains('REVOKE ALL ON public.service_requests FROM PUBLIC, anon, authenticated;'));
      expect(content, contains('GRANT UPDATE (status, cancellation_reason, cancelled_at) ON public.service_requests TO authenticated;'));
      expect(content, contains("v_dispatch_token IS DISTINCT FROM 'expand_dispatch_radius'"));
      expect(content, contains('NEW.search_radius_km IS DISTINCT FROM OLD.search_radius_km'));
      expect(content, contains('NEW.search_radius_km <= OLD.search_radius_km'));
      expect(content, contains('NEW.search_radius_km - OLD.search_radius_km > 2.50'));

      // Verify elimination of recursive RLS subquery and generic admin UPDATE policy
      final srMechanicPolicyStart = content.indexOf('CREATE POLICY service_requests_update_mechanic');
      final srMechanicPolicyEnd = content.indexOf(';', srMechanicPolicyStart);
      final srMechanicPolicy = content.substring(srMechanicPolicyStart, srMechanicPolicyEnd);
      expect(srMechanicPolicy, isNot(contains('SELECT')),
          reason: 'service_requests_update_mechanic must not contain recursive self-referencing subqueries');
      expect(content, isNot(contains('WHERE sr.id = service_requests.id')),
          reason: 'service_requests must not have self-referencing WHERE sr.id = service_requests.id');
      expect(content, isNot(contains('"service_requests_update_admin"')),
          reason: 'Generic service_requests_update_admin policy must be removed in favor of auditable RPC');

      // Verify unconditional protection of all immutable fields before status transition check
      expect(content, contains('NEW.id IS DISTINCT FROM OLD.id'));
      expect(content, contains('NEW.request_code IS DISTINCT FROM OLD.request_code'));
      expect(content, contains('NEW.motorist_id IS DISTINCT FROM OLD.motorist_id'));
      expect(content, contains('NEW.created_at IS DISTINCT FROM OLD.created_at'));
      expect(content, contains('NEW.breakdown_location IS DISTINCT FROM OLD.breakdown_location'));
      expect(content, contains('NEW.breakdown_address IS DISTINCT FROM OLD.breakdown_address'));
      expect(content, contains('NEW.vehicle_snapshot IS DISTINCT FROM OLD.vehicle_snapshot'));
      expect(content, contains('NEW.fault_type IS DISTINCT FROM OLD.fault_type'));
      expect(content, contains('NEW.search_radius_km IS DISTINCT FROM OLD.search_radius_km'));
      expect(content, contains('NEW.mechanic_id IS DISTINCT FROM OLD.mechanic_id'));

      final triggerStart = content.indexOf('FUNCTION public.check_service_request_mutation()');
      final triggerEnd = content.indexOf('trg_validate_service_request_mutation');
      final triggerBody = content.substring(triggerStart, triggerEnd);
      final statusCheckIndex = triggerBody.indexOf('IF NEW.status IS DISTINCT FROM OLD.status THEN');

      expect(triggerBody.indexOf('NEW.id IS DISTINCT FROM OLD.id'), lessThan(statusCheckIndex));
      expect(triggerBody.indexOf('NEW.request_code IS DISTINCT FROM OLD.request_code'), lessThan(statusCheckIndex));
      expect(triggerBody.indexOf('NEW.motorist_id IS DISTINCT FROM OLD.motorist_id'), lessThan(statusCheckIndex));
      expect(triggerBody.indexOf('NEW.created_at IS DISTINCT FROM OLD.created_at'), lessThan(statusCheckIndex));
      expect(triggerBody.indexOf('NEW.breakdown_location IS DISTINCT FROM OLD.breakdown_location'), lessThan(statusCheckIndex));
      expect(triggerBody.indexOf('NEW.breakdown_address IS DISTINCT FROM OLD.breakdown_address'), lessThan(statusCheckIndex));
      expect(triggerBody.indexOf('NEW.vehicle_snapshot IS DISTINCT FROM OLD.vehicle_snapshot'), lessThan(statusCheckIndex));
      expect(triggerBody.indexOf('NEW.fault_type IS DISTINCT FROM OLD.fault_type'), lessThan(statusCheckIndex));
      expect(triggerBody.indexOf('NEW.search_radius_km IS DISTINCT FROM OLD.search_radius_km'), lessThan(statusCheckIndex));
      expect(triggerBody.indexOf('NEW.mechanic_id IS DISTINCT FROM OLD.mechanic_id'), lessThan(statusCheckIndex));

      // Verify actor-specific state machine rules
      expect(content, contains('v_user = OLD.motorist_id'));
      expect(content, contains('Motorist cannot perform this service-request status transition.'));
      expect(content, contains('v_user = OLD.mechanic_id'));
      expect(content, contains('Mechanic cannot perform this service-request status transition.'));
      expect(content, contains("OLD.status = 'assigned' AND NEW.status = 'en_route'"));
      expect(content, contains("OLD.status = 'servicing' AND NEW.status = 'completed'"));

      // Verify anti-self-elevation checks and instantaneous admin check with SECURITY DEFINER
      expect(content, contains('GRANT UPDATE (full_name, phone, avatar_url) ON public.profiles TO authenticated;'));
      expect(content, contains('FUNCTION public.is_admin()'));
      expect(content, contains('SECURITY DEFINER'));
      expect(content, contains("raw_app_meta_data ->> 'user_role') = 'admin'"));
      expect(content, contains('GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role;'));
    });
  });

  group('Dispatch Engine & Attack Prevention Verification', () {
    test('expansion requires exhausting unoffered mechanics and blocks direct 15km searches', () {
      final m4 = File(
              'supabase/migrations/20261118000004_create_functions_and_procedures.sql')
          .readAsStringSync();

      // Verify find_eligible_mechanics execution revoked from public
      expect(m4, contains('REVOKE ALL ON FUNCTION public.find_eligible_mechanics(GEOGRAPHY, DOUBLE PRECISION, TEXT) FROM PUBLIC;'));
      expect(m4, contains('GRANT EXECUTE ON FUNCTION public.find_eligible_mechanics(GEOGRAPHY, DOUBLE PRECISION, TEXT) TO postgres, service_role;'));

      // Verify authoritative find_eligible_mechanics_for_request
      expect(m4, contains('FUNCTION public.find_eligible_mechanics_for_request'));
      expect(m4, contains('v_req.search_radius_km * 1000.0'));
      expect(m4, contains('GRANT EXECUTE ON FUNCTION public.find_eligible_mechanics_for_request(UUID) TO authenticated, service_role;'));

      // Verify dispatch_next_candidate sequential offer issuance
      expect(m4, contains('FUNCTION public.dispatch_next_candidate'));
      expect(m4, contains('NOT EXISTS ('));
      expect(m4, contains('o.mechanic_id = c.mechanic_id'));
      expect(m4, contains("ORDER BY c.dispatch_score DESC, c.distance_meters ASC"));
      expect(m4, contains("INTERVAL '45 seconds'"));
      expect(m4, contains('GRANT EXECUTE ON FUNCTION public.dispatch_next_candidate(UUID) TO authenticated, service_role;'));

      // Verify expand_dispatch_radius guards against unoffered candidates
      expect(m4, contains('v_unoffered > 0'));
      expect(m4, contains('Cannot expand: % eligible mechanic(s) have not yet received an offer.'));
      expect(m4, contains("set_config('roadix.internal_dispatch_caller', 'expand_dispatch_radius', TRUE)"));

      // Verify single active assignment constraint and concurrent offer prevention
      expect(m4, contains('Mechanic already has an active service assignment.'));
      final m3 = File(
              'supabase/migrations/20261118000003_create_service_requests_and_dispatch.sql')
          .readAsStringSync();
      expect(m3, contains('uq_mechanic_single_active_request'));
      expect(m3, contains('uq_request_mechanic_offer'));

      // Verify administrator role elevation & revocation procedure
      expect(m4, contains('FUNCTION public.set_user_role'));
      expect(m4, contains('UPDATE public.profiles'));
      expect(m4, contains('SET role = p_new_role'));
      expect(m4, contains('DELETE FROM auth.refresh_tokens WHERE user_id = p_target_user_id;'));
      expect(m4, contains('INSERT INTO public.admin_audit_logs'));

      // Verify dedicated administrator override procedure
      expect(m4, contains('FUNCTION public.admin_override_service_request'));
      expect(m4, contains('NOT public.is_admin()'));
      expect(m4, contains("set_config('roadix.internal_admin_caller', 'admin_override_service_request', TRUE)"));
      expect(m4, contains("'ADMIN_OVERRIDE_' || upper(p_action)"));
      expect(m4, contains('GRANT EXECUTE ON FUNCTION public.admin_override_service_request(UUID, TEXT, TEXT, JSONB) TO authenticated, service_role;'));
    });
  });

  group('Migration 07 (Forward Migration) DDL & Schema Security Tests', () {
    late String m7;

    setUpAll(() {
      final file = File('supabase/migrations/20261118000007_fix_dispatch_scoring.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration 07 must exist on disk');
      m7 = file.readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('migration 07 enforces exact three SRS vehicle categories in vehicles & rate cards', () {
      expect(m7, contains('ADD CONSTRAINT vehicles_type_check'));
      expect(m7, contains("CHECK (type IN ('Passenger Car', 'Motorcycle', 'Light Commercial'))"));

      expect(m7, contains('ADD CONSTRAINT standard_rate_cards_vehicle_type_check'));
      expect(m7, contains("CHECK (vehicle_type IN ('Passenger Car', 'Motorcycle', 'Light Commercial'))"));
    });

    test('migration 07 adds vehicle_specializations to mechanic_profiles with RLS & column grants', () {
      expect(m7, contains('COLUMN IF NOT EXISTS vehicle_specializations TEXT[] NOT NULL DEFAULT \'{}\''));
      expect(m7, contains('ADD CONSTRAINT mechanic_vehicle_specializations_check'));
      expect(m7, contains("ARRAY[\n            'Passenger Car',\n            'Motorcycle',\n            'Light Commercial'\n        ]::TEXT[]"));

      // Column-level privileges allowing authenticated mechanics to manage their own specialization
      expect(m7, contains('GRANT INSERT (vehicle_specializations)\n    ON public.mechanic_profiles TO authenticated;'));
      expect(m7, contains('GRANT UPDATE (vehicle_specializations)\n    ON public.mechanic_profiles TO authenticated;'));
    });

    test('migration 07 validates snapshot vehicle category and protects service_requests', () {
      expect(m7, contains('FUNCTION public.roadix_vehicle_type_from_snapshot'));
      expect(m7, contains('FUNCTION public.validate_service_request_vehicle_snapshot()'));
      expect(m7, contains('CREATE TRIGGER trg_validate_service_request_vehicle_snapshot'));
      expect(m7, contains('BEFORE INSERT OR UPDATE ON public.service_requests'));

      expect(m7, contains('REVOKE ALL ON FUNCTION public.roadix_vehicle_type_from_snapshot(JSONB)'));
      expect(m7, contains('GRANT EXECUTE ON FUNCTION public.roadix_vehicle_type_from_snapshot(JSONB)\n    TO postgres, service_role;'));
    });

    test('migration 07 drops obsolete function overloads so no caller uses legacy path', () {
      expect(m7, contains('DROP FUNCTION IF EXISTS public.find_eligible_mechanics(\n    GEOGRAPHY, DOUBLE PRECISION, TEXT\n);'));
      expect(m7, contains('DROP FUNCTION IF EXISTS public.calculate_dispatch_score(\n    DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT[], NUMERIC, INTEGER\n);'));
    });

    test('migration 07 updates all dependent dispatch functions to pass vehicle category', () {
      // 4-argument discovery function
      expect(m7, contains('FUNCTION public.find_eligible_mechanics('));
      expect(m7, contains('p_breakdown_location GEOGRAPHY'));
      expect(m7, contains('p_radius_meters DOUBLE PRECISION'));
      expect(m7, contains('p_fault_type TEXT'));
      expect(m7, contains('p_vehicle_type TEXT'));

      // dispatch_next_candidate extracts vehicle_type and calls 4-arg discovery
      expect(m7, contains('FUNCTION public.dispatch_next_candidate(p_request_id UUID)'));
      expect(m7, contains('v_vehicle_type :=\n        public.roadix_vehicle_type_from_snapshot(v_req.vehicle_snapshot);'));
      expect(m7, contains('public.find_eligible_mechanics(\n        v_req.breakdown_location,\n        v_req.search_radius_km * 1000.0,\n        v_req.fault_type,\n        v_vehicle_type\n    )'));

      // expand_dispatch_radius extracts vehicle_type and calls 4-arg discovery
      expect(m7, contains('FUNCTION public.expand_dispatch_radius(p_request_id UUID)'));

      // find_eligible_mechanics_for_request extracts vehicle_type and calls 4-arg discovery
      expect(m7, contains('FUNCTION public.find_eligible_mechanics_for_request('));

      // Execution privileges
      expect(m7, contains('GRANT EXECUTE ON FUNCTION public.dispatch_next_candidate(UUID) TO authenticated, service_role;'));
      expect(m7, contains('GRANT EXECUTE ON FUNCTION public.expand_dispatch_radius(UUID) TO authenticated, service_role;'));
      expect(m7, contains('GRANT EXECUTE ON FUNCTION public.find_eligible_mechanics_for_request(UUID) TO authenticated, service_role;'));
      expect(m7, contains('GRANT EXECUTE ON FUNCTION public.find_eligible_mechanics(\n    GEOGRAPHY, DOUBLE PRECISION, TEXT, TEXT\n) TO postgres, service_role;'));
    });
  });

  group('SRS Vehicle Category UI Mapping Tests', () {
    test('VehicleSelectScreen maps UI categories to canonical SRS categories', () {
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Sedan / Hatch'), equals('Passenger Car'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('SUV / Micro'), equals('Passenger Car'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Sedan'), equals('Passenger Car'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('SUV'), equals('Passenger Car'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Motorcycle'), equals('Motorcycle'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Commercial'), equals('Light Commercial'));
      expect(VehicleSelectScreen.mapUiCategoryToSrs('Light Commercial'), equals('Light Commercial'));
    });

    test('VehicleEditorSheet normalizes legacy garage types to SRS categories', () {
      expect(VehicleEditorSheet.normalizeToSrsCategory('Sedan'), equals('Passenger Car'));
      expect(VehicleEditorSheet.normalizeToSrsCategory('SUV'), equals('Passenger Car'));
      expect(VehicleEditorSheet.normalizeToSrsCategory('Motorcycle'), equals('Motorcycle'));
      expect(VehicleEditorSheet.normalizeToSrsCategory('Commercial'), equals('Light Commercial'));
      expect(VehicleEditorSheet.normalizeToSrsCategory('Light Commercial'), equals('Light Commercial'));
      expect(VehicleEditorSheet.normalizeToSrsCategory(null), equals('Passenger Car'));
    });
  });

  group('Finalized SRS Dispatch Scoring Formula Verification (40/25/15/20)', () {
    double calculateSrsScore({
      required double distanceMeters,
      required double radiusMeters,
      required String vehicleType,
      required List<String> vehicleSpecializations,
      double? averageRating,
      int reviewCount = 0,
      double? acceptanceRate,
    }) {
      // 1. Proximity (40%)
      final proximity = radiusMeters <= 0
          ? 0.0
          : ((1.0 - (distanceMeters / radiusMeters)) * 100.0).clamp(0.0, 100.0);

      // 2. Vehicle-class Specialization (25%)
      double vehicleMatch;
      if (vehicleSpecializations.contains(vehicleType)) {
        vehicleMatch = 100.0;
      } else if (vehicleSpecializations.isEmpty) {
        vehicleMatch = 50.0; // Neutral until configured
      } else {
        vehicleMatch = 0.0; // Mismatch
      }

      // 3. Rating / Trust (15%) with Bayesian shrinkage towards neutral 3.0 / 50%
      final rating = (averageRating ?? 3.0).clamp(1.0, 5.0);
      final confidence = (reviewCount / 5.0).clamp(0.0, 1.0);
      final trust = (((rating - 1.0) / 4.0) * 100.0 * confidence) + (50.0 * (1.0 - confidence));

      // 4. Availability / Historical Performance (20%)
      final performance = (acceptanceRate ?? 50.0).clamp(0.0, 100.0);

      final total = (0.40 * proximity) +
          (0.25 * vehicleMatch) +
          (0.15 * trust) +
          (0.20 * performance);

      return double.parse(total.toStringAsFixed(2));
    }

    test('SRS weights evaluate to exact 100.00 for ideal candidate and 0.00 for worst candidate', () {
      final idealScore = calculateSrsScore(
        distanceMeters: 0,
        radiusMeters: 5000,
        vehicleType: 'Passenger Car',
        vehicleSpecializations: ['Passenger Car', 'Motorcycle'],
        averageRating: 5.0,
        reviewCount: 10,
        acceptanceRate: 100.0,
      );
      expect(idealScore, equals(100.00));

      final worstScore = calculateSrsScore(
        distanceMeters: 5000,
        radiusMeters: 5000,
        vehicleType: 'Light Commercial',
        vehicleSpecializations: ['Passenger Car', 'Motorcycle'], // Does not support Light Commercial
        averageRating: 1.0,
        reviewCount: 10,
        acceptanceRate: 0.0,
      );
      expect(worstScore, equals(0.00));
    });

    test('neutral baseline applies for new mechanics with missing reviews and missing offers', () {
      // Halfway within radius (2500 / 5000) -> 50% proximity
      // No vehicle specializations specified -> 50% neutral match
      // No reviews (0 count) -> 50% neutral trust
      // No prior offers (acceptanceRate is null) -> 50% neutral performance
      final neutralScore = calculateSrsScore(
        distanceMeters: 2500,
        radiusMeters: 5000,
        vehicleType: 'Passenger Car',
        vehicleSpecializations: [],
        averageRating: null,
        reviewCount: 0,
        acceptanceRate: null,
      );
      expect(neutralScore, equals(50.00));
    });

    test('vehicle category specialization significantly impacts ranking (25% weight)', () {
      final matchedScore = calculateSrsScore(
        distanceMeters: 2000,
        radiusMeters: 5000,
        vehicleType: 'Motorcycle',
        vehicleSpecializations: ['Motorcycle'],
        averageRating: 4.5,
        reviewCount: 5,
        acceptanceRate: 80.0,
      );

      final mismatchedScore = calculateSrsScore(
        distanceMeters: 2000,
        radiusMeters: 5000,
        vehicleType: 'Motorcycle',
        vehicleSpecializations: ['Passenger Car'], // No motorcycle capability
        averageRating: 4.5,
        reviewCount: 5,
        acceptanceRate: 80.0,
      );

      // 25% of 100 is exactly 25.0 points difference
      expect(matchedScore - mismatchedScore, closeTo(25.0, 0.01));
    });

    test('review confidence smoothly adjusts trust towards neutral when count is small', () {
      // 5-star rating with only 1 review (confidence = 0.2)
      // trust = (100 * 0.2) + (50 * 0.8) = 20 + 40 = 60
      final oneReviewScore = calculateSrsScore(
        distanceMeters: 0,
        radiusMeters: 5000,
        vehicleType: 'Passenger Car',
        vehicleSpecializations: ['Passenger Car'],
        averageRating: 5.0,
        reviewCount: 1,
        acceptanceRate: 100.0,
      );

      // 5-star rating with 5 reviews (confidence = 1.0)
      // trust = 100
      final fiveReviewsScore = calculateSrsScore(
        distanceMeters: 0,
        radiusMeters: 5000,
        vehicleType: 'Passenger Car',
        vehicleSpecializations: ['Passenger Car'],
        averageRating: 5.0,
        reviewCount: 5,
        acceptanceRate: 100.0,
      );

      expect(oneReviewScore, lessThan(fiveReviewsScore));
      // Difference in trust: (100 - 60) * 0.15 = 6.00 points
      expect((fiveReviewsScore - oneReviewScore).toStringAsFixed(2), equals('6.00'));
    });

    test('vehicle-class specialization is separate from fault-type specialization', () {
      // In the database function find_eligible_mechanics:
      // Vehicle specialization is calculated in calculate_dispatch_score (25% score weight)
      // Fault specialization is used as a tie-breaker in ORDER BY (p_fault_type = ANY(m.specializations))
      final m7 = File('supabase/migrations/20261118000007_fix_dispatch_scoring.sql').readAsStringSync();
      expect(m7, contains('(p_fault_type = ANY(m.specializations)) DESC'));
      expect(m7, contains('p_vehicle_type = ANY(COALESCE(p_vehicle_specializations'));
    });
  });
}
