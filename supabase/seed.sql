-- ============================================================================
-- ROADIX DEVELOPMENT SEED DATA & ARCHITECTURAL GUIDANCE
-- ============================================================================
-- NOTE ON SUPABASE AUTH & GOTRUE RUNTIME COMPATIBILITY:
-- In Supabase hosted environments, user authentication is managed exclusively by
-- the GoTrue Auth microservice daemon. Direct SQL insertion into `auth.users`
-- has two critical limitations:
--   1. Lack of `auth.identities` records: Password-based authentication requires
--      matching provider rows in `auth.identities`. Direct SQL insertion into
--      `auth.users` alone produces orphaned accounts that cannot sign in via
--      `supabase.auth.signInWithPassword()`.
--   2. Privilege Restrictions: Remote/production PostgreSQL connection roles
--      typically do not possess direct write permissions to the internal `auth` schema.
--
-- RECOMMENDED USAGE:
--   - PART 1 (Master Data): Safe to execute anywhere (local, staging, production).
--   - PART 2 (Local Fixtures): Intended strictly for local emulator (`supabase start`)
--     or headless CI database testing. In hosted production, accounts MUST be created
--     via the Supabase Auth API (`supabase.auth.signUp()`) or Supabase Dashboard.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Standard Rate Cards (Baseline benchmark prices in BDT for Dhaka)
-- ----------------------------------------------------------------------------
INSERT INTO public.standard_rate_cards (fault_type, vehicle_type, base_callout_fee, base_inspection_fee, base_labor_fee)
VALUES
    ('Flat Tire / Wheel Replacement', 'Sedan', 300.00, 150.00, 350.00),
    ('Flat Tire / Wheel Replacement', 'SUV', 350.00, 200.00, 450.00),
    ('Flat Tire / Wheel Replacement', 'Motorcycle', 200.00, 100.00, 250.00),
    ('Flat Tire / Wheel Replacement', 'Commercial', 500.00, 300.00, 600.00),
    ('Battery Jumpstart / Dead Cell', 'Sedan', 300.00, 200.00, 300.00),
    ('Battery Jumpstart / Dead Cell', 'SUV', 350.00, 250.00, 400.00),
    ('Battery Jumpstart / Dead Cell', 'Motorcycle', 200.00, 100.00, 200.00),
    ('Engine Overheating / Coolant', 'Sedan', 350.00, 300.00, 600.00),
    ('Engine Overheating / Coolant', 'SUV', 400.00, 350.00, 750.00),
    ('Emergency Fuel Run (5 Liters)', 'Sedan', 300.00, 100.00, 200.00),
    ('Emergency Fuel Run (5 Liters)', 'SUV', 300.00, 100.00, 200.00),
    ('Emergency Fuel Run (5 Liters)', 'Motorcycle', 200.00, 50.00, 150.00),
    ('Towing / Flatbed Recovery', 'Sedan', 1200.00, 300.00, 1000.00),
    ('Towing / Flatbed Recovery', 'SUV', 1500.00, 400.00, 1200.00)
ON CONFLICT (fault_type, vehicle_type) DO UPDATE 
SET base_callout_fee = EXCLUDED.base_callout_fee,
    base_inspection_fee = EXCLUDED.base_inspection_fee,
    base_labor_fee = EXCLUDED.base_labor_fee;

-- ----------------------------------------------------------------------------
-- 2. Mock Auth Users & Profiles (Full Supabase Auth GoTrue Column Compatibility)
-- ----------------------------------------------------------------------------
-- 2.1 Demo Platform Admin
INSERT INTO auth.users (
    id, instance_id, aud, role, email, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'a0000000-0000-0000-0000-000000000099',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'admin@roadix.com.bd',
    '+8801700000099',
    '',
    '{"provider": "email", "providers": ["email"], "user_role": "admin"}'::jsonb,
    '{"full_name": "Studio Paradox Admin"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    'a0000000-0000-0000-0000-000000000099',
    'admin',
    'Studio Paradox Admin',
    '+8801700000099',
    FALSE,
    TRUE
) ON CONFLICT (id) DO UPDATE SET role = 'admin', full_name = EXCLUDED.full_name;

-- 2.2 Demo Registered Motorist
INSERT INTO auth.users (
    id, instance_id, aud, role, email, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'motorist@roadix.com.bd',
    '+8801711000001',
    '',
    '{"provider": "phone", "providers": ["phone"]}'::jsonb,
    '{"full_name": "Tanvir Ahmed"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'motorist',
    'Tanvir Ahmed',
    '+8801711000001',
    FALSE,
    TRUE
) ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name, phone = EXCLUDED.phone;

-- Motorist Primary Vehicle & Wallet
INSERT INTO public.vehicles (profile_id, model, plate, type, fuel, is_primary)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'Toyota Corolla Altis 2021',
    'DHAKA-METRO-GA-11-2026',
    'Sedan',
    'Octane',
    TRUE
) ON CONFLICT (profile_id, plate) DO NOTHING;

INSERT INTO public.wallets (profile_id, provider, account_number, is_primary)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'bKash',
    '+8801711000001',
    TRUE
) ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. Synthetic Verified Field Mechanics Stationed at Dhaka Hotspots
-- ----------------------------------------------------------------------------
-- 3.1 Gulshan 2 Mechanic (Master Electrical & Engine Specialist)
INSERT INTO auth.users (
    id, instance_id, aud, role, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    '+8801811000011',
    '',
    '{"provider": "phone", "providers": ["phone"]}'::jsonb,
    '{"full_name": "Rahim Uddin (Gulshan Auto Clinic)"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    '00000000-0000-0000-0000-000000000011',
    'mechanic',
    'Rahim Uddin',
    '+8801811000011',
    FALSE,
    TRUE
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.mechanic_profiles (
    profile_id, workshop_name, workshop_address, current_location,
    is_on_duty, is_verified, rating, total_rescues, specializations
) VALUES (
    '00000000-0000-0000-0000-000000000011',
    'Gulshan Auto Clinic',
    'Plot 14, Road 45, Gulshan 2, Dhaka',
    ST_SetSRID(ST_MakePoint(90.4078, 23.7925), 4326)::geography, -- Gulshan 2 Circle
    TRUE,
    TRUE,
    4.92,
    148,
    ARRAY['Engine Overheating / Coolant', 'Battery Jumpstart / Dead Cell', 'General Automotive Breakdown']
) ON CONFLICT (profile_id) DO NOTHING;

INSERT INTO public.mechanic_verifications (
    profile_id, trade_license_number, nid_number, verified_at
) VALUES (
    '00000000-0000-0000-0000-000000000011',
    'TRAD/DNCC/012948/2021',
    '19852691234567890',
    now()
) ON CONFLICT DO NOTHING;

-- 3.2 Dhanmondi 27 Mechanic (Tire & Suspension Specialist)
INSERT INTO auth.users (
    id, instance_id, aud, role, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000012',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    '+8801811000012',
    '',
    '{"provider": "phone", "providers": ["phone"]}'::jsonb,
    '{"full_name": "Belal Hossain (Dhanmondi Rapid Fix)"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    '00000000-0000-0000-0000-000000000012',
    'mechanic',
    'Belal Hossain',
    '+8801811000012',
    FALSE,
    TRUE
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.mechanic_profiles (
    profile_id, workshop_name, workshop_address, current_location,
    is_on_duty, is_verified, rating, total_rescues, specializations
) VALUES (
    '00000000-0000-0000-0000-000000000012',
    'Dhanmondi Rapid Fix',
    'House 12, Road 27 (Old), Dhanmondi, Dhaka',
    ST_SetSRID(ST_MakePoint(90.3742, 23.7540), 4326)::geography, -- Dhanmondi 27
    TRUE,
    TRUE,
    4.85,
    92,
    ARRAY['Flat Tire / Wheel Replacement', 'Brake Failure / Fluid Leak', 'General Automotive Breakdown']
) ON CONFLICT (profile_id) DO NOTHING;

INSERT INTO public.mechanic_verifications (
    profile_id, trade_license_number, nid_number, verified_at
) VALUES (
    '00000000-0000-0000-0000-000000000012',
    'TRAD/DSCC/034912/2022',
    '19892697891234567',
    now()
) ON CONFLICT DO NOTHING;

-- 3.3 Uttara Sector 3 Mechanic (All-Round Recovery Specialist)
INSERT INTO auth.users (
    id, instance_id, aud, role, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000013',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    '+8801811000013',
    '',
    '{"provider": "phone", "providers": ["phone"]}'::jsonb,
    '{"full_name": "Sumon Mia (Uttara Highway Rescue)"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    '00000000-0000-0000-0000-000000000013',
    'mechanic',
    'Sumon Mia',
    '+8801811000013',
    FALSE,
    TRUE
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.mechanic_profiles (
    profile_id, workshop_name, workshop_address, current_location,
    is_on_duty, is_verified, rating, total_rescues, specializations
) VALUES (
    '00000000-0000-0000-0000-000000000013',
    'Uttara Highway Rescue',
    'Sector 3, Jasimuddin Road, Uttara, Dhaka',
    ST_SetSRID(ST_MakePoint(90.3986, 23.8698), 4326)::geography, -- Uttara Jasimuddin
    TRUE,
    TRUE,
    4.78,
    64,
    ARRAY['General Automotive Breakdown', 'Towing / Flatbed Recovery', 'Emergency Fuel Run (5 Liters)']
) ON CONFLICT (profile_id) DO NOTHING;

INSERT INTO public.mechanic_verifications (
    profile_id, trade_license_number, nid_number, verified_at
) VALUES (
    '00000000-0000-0000-0000-000000000013',
    'TRAD/DNCC/087123/2020',
    '19912694567891234',
    now()
) ON CONFLICT DO NOTHING;

-- 3.4 Mirpur 10 Mechanic (Battery & Starter Motor Specialist)
INSERT INTO auth.users (
    id, instance_id, aud, role, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000014',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    '+8801811000014',
    '',
    '{"provider": "phone", "providers": ["phone"]}'::jsonb,
    '{"full_name": "Kader Ali (Mirpur Motor Works)"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    '00000000-0000-0000-0000-000000000014',
    'mechanic',
    'Kader Ali',
    '+8801811000014',
    FALSE,
    TRUE
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.mechanic_profiles (
    profile_id, workshop_name, workshop_address, current_location,
    is_on_duty, is_verified, rating, total_rescues, specializations
) VALUES (
    '00000000-0000-0000-0000-000000000014',
    'Mirpur Motor Works',
    'Roundabout Corner, Mirpur 10, Dhaka',
    ST_SetSRID(ST_MakePoint(90.3686, 23.8070), 4326)::geography, -- Mirpur 10 Golchokkor
    TRUE,
    TRUE,
    4.88,
    110,
    ARRAY['Battery Jumpstart / Dead Cell', 'Engine Overheating / Coolant', 'General Automotive Breakdown']
) ON CONFLICT (profile_id) DO NOTHING;

INSERT INTO public.mechanic_verifications (
    profile_id, trade_license_number, nid_number, verified_at
) VALUES (
    '00000000-0000-0000-0000-000000000014',
    'TRAD/DNCC/056789/2023',
    '19872696543219876',
    now()
) ON CONFLICT DO NOTHING;
