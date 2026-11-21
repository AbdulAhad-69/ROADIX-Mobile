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
    ('Flat Tire / Wheel Replacement', 'Passenger Car', 300.00, 150.00, 350.00),
    ('Flat Tire / Wheel Replacement', 'Motorcycle', 200.00, 100.00, 250.00),
    ('Flat Tire / Wheel Replacement', 'Light Commercial', 500.00, 300.00, 600.00),
    ('Battery Jumpstart / Dead Cell', 'Passenger Car', 300.00, 200.00, 300.00),
    ('Battery Jumpstart / Dead Cell', 'Motorcycle', 200.00, 100.00, 200.00),
    ('Battery Jumpstart / Dead Cell', 'Light Commercial', 450.00, 250.00, 450.00),
    ('Engine Overheating / Coolant', 'Passenger Car', 350.00, 300.00, 600.00),
    ('Engine Overheating / Coolant', 'Motorcycle', 250.00, 150.00, 400.00),
    ('Engine Overheating / Coolant', 'Light Commercial', 500.00, 350.00, 750.00),
    ('Emergency Fuel Run (5 Liters)', 'Passenger Car', 300.00, 100.00, 200.00),
    ('Emergency Fuel Run (5 Liters)', 'Motorcycle', 200.00, 50.00, 150.00),
    ('Emergency Fuel Run (5 Liters)', 'Light Commercial', 350.00, 100.00, 250.00),
    ('Towing / Flatbed Recovery', 'Passenger Car', 1200.00, 300.00, 1000.00),
    ('Towing / Flatbed Recovery', 'Motorcycle', 800.00, 200.00, 600.00),
    ('Towing / Flatbed Recovery', 'Light Commercial', 1800.00, 400.00, 1500.00),
    ('General Automotive Breakdown', 'Passenger Car', 300.00, 250.00, 400.00),
    ('General Automotive Breakdown', 'Motorcycle', 200.00, 150.00, 250.00),
    ('General Automotive Breakdown', 'Light Commercial', 450.00, 300.00, 550.00),
    ('Brake Failure / Fluid Leak', 'Passenger Car', 350.00, 250.00, 500.00),
    ('Brake Failure / Fluid Leak', 'Motorcycle', 200.00, 150.00, 300.00),
    ('Brake Failure / Fluid Leak', 'Light Commercial', 500.00, 350.00, 650.00)
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
    'Passenger Car',
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
    is_on_duty, is_verified, rating, total_rescues, specializations, vehicle_specializations
) VALUES (
    '00000000-0000-0000-0000-000000000011',
    'Gulshan Auto Clinic',
    'Plot 14, Road 45, Gulshan 2, Dhaka',
    ST_SetSRID(ST_MakePoint(90.4078, 23.7925), 4326)::geography, -- Gulshan 2 Circle
    TRUE,
    TRUE,
    4.92,
    148,
    ARRAY['Engine Overheating / Coolant', 'Battery Jumpstart / Dead Cell', 'General Automotive Breakdown'],
    ARRAY['Passenger Car', 'Motorcycle']
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
    is_on_duty, is_verified, rating, total_rescues, specializations, vehicle_specializations
) VALUES (
    '00000000-0000-0000-0000-000000000012',
    'Dhanmondi Rapid Fix',
    'House 12, Road 27 (Old), Dhanmondi, Dhaka',
    ST_SetSRID(ST_MakePoint(90.3742, 23.7540), 4326)::geography, -- Dhanmondi 27
    TRUE,
    TRUE,
    4.85,
    92,
    ARRAY['Flat Tire / Wheel Replacement', 'Brake Failure / Fluid Leak', 'General Automotive Breakdown'],
    ARRAY['Passenger Car', 'Motorcycle']
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
    is_on_duty, is_verified, rating, total_rescues, specializations, vehicle_specializations
) VALUES (
    '00000000-0000-0000-0000-000000000013',
    'Uttara Highway Rescue',
    'Sector 3, Jasimuddin Road, Uttara, Dhaka',
    ST_SetSRID(ST_MakePoint(90.3986, 23.8698), 4326)::geography, -- Uttara Jasimuddin
    TRUE,
    TRUE,
    4.78,
    64,
    ARRAY['General Automotive Breakdown', 'Towing / Flatbed Recovery', 'Emergency Fuel Run (5 Liters)'],
    ARRAY['Passenger Car', 'Light Commercial']
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
    is_on_duty, is_verified, rating, total_rescues, specializations, vehicle_specializations
) VALUES (
    '00000000-0000-0000-0000-000000000014',
    'Mirpur Motor Works',
    'Roundabout Corner, Mirpur 10, Dhaka',
    ST_SetSRID(ST_MakePoint(90.3686, 23.8070), 4326)::geography, -- Mirpur 10 Golchokkor
    TRUE,
    TRUE,
    4.88,
    110,
    ARRAY['Battery Jumpstart / Dead Cell', 'Engine Overheating / Coolant', 'General Automotive Breakdown'],
    ARRAY['Passenger Car', 'Motorcycle']
) ON CONFLICT (profile_id) DO NOTHING;

INSERT INTO public.mechanic_verifications (
    profile_id, trade_license_number, nid_number, verified_at
) VALUES (
    '00000000-0000-0000-0000-000000000014',
    'TRAD/DNCC/056789/2023',
    '19872696543219876',
    now()
) ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. Additional Verified Field Mechanics Stationed at Key Dhaka Hubs
-- ----------------------------------------------------------------------------
-- 4.1 Mohakhali Mechanic (Transmission & Mechanical Specialist)
INSERT INTO auth.users (
    id, instance_id, aud, role, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000015',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    '+8801811000015',
    '',
    '{"provider": "phone", "providers": ["phone"]}'::jsonb,
    '{"full_name": "Tariqul Islam (Mohakhali Auto Engineering)"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    '00000000-0000-0000-0000-000000000015',
    'mechanic',
    'Tariqul Islam',
    '+8801811000015',
    FALSE,
    TRUE
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.mechanic_profiles (
    profile_id, workshop_name, workshop_address, current_location,
    is_on_duty, is_verified, rating, total_rescues, specializations, vehicle_specializations
) VALUES (
    '00000000-0000-0000-0000-000000000015',
    'Mohakhali Auto Engineering',
    'TB Gate, Mohakhali C/A, Dhaka',
    ST_SetSRID(ST_MakePoint(90.4035, 23.7782), 4326)::geography, -- Mohakhali
    TRUE,
    TRUE,
    4.95,
    182,
    ARRAY['Brake Failure / Fluid Leak', 'General Automotive Breakdown', 'Engine Overheating / Coolant'],
    ARRAY['Passenger Car', 'Light Commercial']
) ON CONFLICT (profile_id) DO NOTHING;

INSERT INTO public.mechanic_verifications (
    profile_id, trade_license_number, nid_number, verified_at
) VALUES (
    '00000000-0000-0000-0000-000000000015',
    'TRAD/DNCC/078234/2019',
    '19822691122334455',
    now()
) ON CONFLICT DO NOTHING;

-- 4.2 Banani 11 Mechanic (ECU & Electrical Diagnostics)
INSERT INTO auth.users (
    id, instance_id, aud, role, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000016',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    '+8801811000016',
    '',
    '{"provider": "phone", "providers": ["phone"]}'::jsonb,
    '{"full_name": "Shah Alam (Banani Precision Mechanics)"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    '00000000-0000-0000-0000-000000000016',
    'mechanic',
    'Shah Alam',
    '+8801811000016',
    FALSE,
    TRUE
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.mechanic_profiles (
    profile_id, workshop_name, workshop_address, current_location,
    is_on_duty, is_verified, rating, total_rescues, specializations, vehicle_specializations
) VALUES (
    '00000000-0000-0000-0000-000000000016',
    'Banani Precision Mechanics',
    'Road 11, Block D, Banani, Dhaka',
    ST_SetSRID(ST_MakePoint(90.4048, 23.7937), 4326)::geography, -- Banani 11
    TRUE,
    TRUE,
    4.90,
    134,
    ARRAY['Battery Jumpstart / Dead Cell', 'General Automotive Breakdown', 'Engine Overheating / Coolant'],
    ARRAY['Passenger Car', 'Motorcycle']
) ON CONFLICT (profile_id) DO NOTHING;

INSERT INTO public.mechanic_verifications (
    profile_id, trade_license_number, nid_number, verified_at
) VALUES (
    '00000000-0000-0000-0000-000000000016',
    'TRAD/DNCC/098765/2021',
    '19862699988776655',
    now()
) ON CONFLICT DO NOTHING;

-- 4.3 Tejgaon Heavy Towing & Flatbed Recovery Specialist
INSERT INTO auth.users (
    id, instance_id, aud, role, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000017',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    '+8801811000017',
    '',
    '{"provider": "phone", "providers": ["phone"]}'::jsonb,
    '{"full_name": "Kabir Hossain (Tejgaon Recovery Hub)"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    '00000000-0000-0000-0000-000000000017',
    'mechanic',
    'Kabir Hossain',
    '+8801811000017',
    FALSE,
    TRUE
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.mechanic_profiles (
    profile_id, workshop_name, workshop_address, current_location,
    is_on_duty, is_verified, rating, total_rescues, specializations, vehicle_specializations
) VALUES (
    '00000000-0000-0000-0000-000000000017',
    'Tejgaon Recovery Hub',
    'Shaheed Tajuddin Ahmed Sarani, Tejgaon I/A, Dhaka',
    ST_SetSRID(ST_MakePoint(90.3951, 23.7639), 4326)::geography, -- Tejgaon
    TRUE,
    TRUE,
    4.82,
    76,
    ARRAY['Towing / Flatbed Recovery', 'General Automotive Breakdown', 'Brake Failure / Fluid Leak'],
    ARRAY['Passenger Car', 'Light Commercial', 'Motorcycle']
) ON CONFLICT (profile_id) DO NOTHING;

INSERT INTO public.mechanic_verifications (
    profile_id, trade_license_number, nid_number, verified_at
) VALUES (
    '00000000-0000-0000-0000-000000000017',
    'TRAD/DNCC/045612/2022',
    '19842693344556677',
    now()
) ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. Additional Realistic Demo Motorists & Diverse Garages
-- ----------------------------------------------------------------------------
-- 5.1 Motorist: Sadia Islam (SUV Owner)
INSERT INTO auth.users (
    id, instance_id, aud, role, email, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'a0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'sadia@roadix.com.bd',
    '+8801711000002',
    '',
    '{"provider": "phone", "providers": ["phone"]}'::jsonb,
    '{"full_name": "Sadia Islam"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    'a0000000-0000-0000-0000-000000000002',
    'motorist',
    'Sadia Islam',
    '+8801711000002',
    FALSE,
    TRUE
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.vehicles (profile_id, model, plate, type, fuel, is_primary)
VALUES (
    'a0000000-0000-0000-0000-000000000002',
    'Honda HR-V 2023',
    'DHAKA-METRO-GHA-14-3829',
    'Passenger Car',
    'Octane',
    TRUE
) ON CONFLICT (profile_id, plate) DO NOTHING;

INSERT INTO public.wallets (profile_id, provider, account_number, is_primary)
VALUES (
    'a0000000-0000-0000-0000-000000000002',
    'Nagad',
    '+8801711000002',
    TRUE
) ON CONFLICT DO NOTHING;

INSERT INTO public.emergency_contacts (profile_id, name, phone, relation)
VALUES (
    'a0000000-0000-0000-0000-000000000002',
    'Dr. Rafiqul Islam',
    '+8801711000092',
    'Father'
) ON CONFLICT DO NOTHING;

-- 5.2 Motorist: Kazi Farhan (Motorcycle Rider)
INSERT INTO auth.users (
    id, instance_id, aud, role, email, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'a0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'farhan@roadix.com.bd',
    '+8801711000003',
    '',
    '{"provider": "phone", "providers": ["phone"]}'::jsonb,
    '{"full_name": "Kazi Farhan"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    'a0000000-0000-0000-0000-000000000003',
    'motorist',
    'Kazi Farhan',
    '+8801711000003',
    FALSE,
    TRUE
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.vehicles (profile_id, model, plate, type, fuel, is_primary)
VALUES (
    'a0000000-0000-0000-0000-000000000003',
    'Yamaha FZS V3 Deluxe',
    'DHAKA-METRO-HA-12-8841',
    'Motorcycle',
    'Petrol',
    TRUE
) ON CONFLICT (profile_id, plate) DO NOTHING;

INSERT INTO public.wallets (profile_id, provider, account_number, is_primary)
VALUES (
    'a0000000-0000-0000-0000-000000000003',
    'bKash',
    '+8801711000003',
    TRUE
) ON CONFLICT DO NOTHING;

INSERT INTO public.emergency_contacts (profile_id, name, phone, relation)
VALUES (
    'a0000000-0000-0000-0000-000000000003',
    'Salma Begum',
    '+8801711000093',
    'Mother'
) ON CONFLICT DO NOTHING;

-- 5.3 Motorist: Mehedi Hasan (Light Commercial Fleet Driver)
INSERT INTO auth.users (
    id, instance_id, aud, role, email, phone, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'a0000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'mehedi@roadix.com.bd',
    '+8801711000004',
    '',
    '{"provider": "phone", "providers": ["phone"]}'::jsonb,
    '{"full_name": "Mehedi Hasan"}'::jsonb,
    now(),
    now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, is_anonymous, is_nid_verified)
VALUES (
    'a0000000-0000-0000-0000-000000000004',
    'motorist',
    'Mehedi Hasan',
    '+8801711000004',
    FALSE,
    TRUE
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.vehicles (profile_id, model, plate, type, fuel, is_primary)
VALUES (
    'a0000000-0000-0000-0000-000000000004',
    'Toyota HiAce Super GL',
    'DHAKA-METRO-CHA-53-1092',
    'Light Commercial',
    'Diesel',
    TRUE
) ON CONFLICT (profile_id, plate) DO NOTHING;

INSERT INTO public.wallets (profile_id, provider, account_number, is_primary)
VALUES (
    'a0000000-0000-0000-0000-000000000004',
    'bKash',
    '+8801711000004',
    TRUE
) ON CONFLICT DO NOTHING;

INSERT INTO public.emergency_contacts (profile_id, name, phone, relation)
VALUES (
    'a0000000-0000-0000-0000-000000000004',
    'Rezaul Karim',
    '+8801711000094',
    'Fleet Supervisor'
) ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 6. Rich Historical Completed Service Scenarios & Transacted Invoices
-- Covers all 7 required SRS emergency roadside scenarios across Dhaka
-- ----------------------------------------------------------------------------

-- Scenario 1: Flat Tire / Wheel Replacement at Dhanmondi
INSERT INTO public.service_requests (
    id, request_code, motorist_id, mechanic_id, status,
    breakdown_location, breakdown_address, vehicle_snapshot,
    fault_type, symptoms, is_high_priority, search_radius_km,
    assigned_at, arrived_at, completed_at, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000001',
    'RDX-DHN-8012',
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000012',
    'completed',
    ST_SetSRID(ST_MakePoint(90.3742, 23.7540), 4326)::geography,
    'Dhanmondi Road 27, Dhaka',
    '{"plate": "DHAKA-METRO-GA-11-2026", "vehicle_type": "Passenger Car"}'::jsonb,
    'Flat Tire / Wheel Replacement',
    ARRAY['Puncture in rear passenger tire', 'Spare wheel replacement required'],
    FALSE,
    5.00,
    now() - INTERVAL '5 days' + INTERVAL '3 minutes',
    now() - INTERVAL '5 days' + INTERVAL '18 minutes',
    now() - INTERVAL '5 days' + INTERVAL '45 minutes',
    now() - INTERVAL '5 days'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.quotations (
    id, request_id, mechanic_id, diagnostic_fee, labor_fee, parts_fee,
    total_amount, status, line_items, created_at
) VALUES (
    'c0000000-0000-0000-0000-000000000001',
    'b0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000012',
    200.00, 350.00, 300.00, 850.00, 'accepted',
    '{"description": "Radial tire valve replacement & hydraulic torque wheel fitting"}'::jsonb,
    now() - INTERVAL '5 days' + INTERVAL '20 minutes'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.transactions (
    request_id, quotation_id, amount, payment_method, status, gateway_transaction_id, metadata, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    850.00, 'SSLCommerz-bKash', 'completed', 'SSL-TX-998231',
    '{"invoice_ref": "INV-RDX-DHN-8012", "environment": "sandbox"}'::jsonb,
    now() - INTERVAL '5 days' + INTERVAL '45 minutes'
) ON CONFLICT DO NOTHING;

INSERT INTO public.reviews (
    request_id, motorist_id, mechanic_id, rating, comment, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000012',
    5,
    'Fast arrival within 15 minutes at Dhanmondi. Spare wheel swapped efficiently!',
    now() - INTERVAL '5 days' + INTERVAL '46 minutes'
) ON CONFLICT DO NOTHING;

-- Scenario 2: Dead Battery Jumpstart at Mirpur 10
INSERT INTO public.service_requests (
    id, request_code, motorist_id, mechanic_id, status,
    breakdown_location, breakdown_address, vehicle_snapshot,
    fault_type, symptoms, is_high_priority, search_radius_km,
    assigned_at, arrived_at, completed_at, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000002',
    'RDX-MIR-9134',
    'a0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000014',
    'completed',
    ST_SetSRID(ST_MakePoint(90.3686, 23.8070), 4326)::geography,
    'Mirpur 10 Golchokkor, Dhaka',
    '{"plate": "DHAKA-METRO-GHA-14-3829", "vehicle_type": "Passenger Car"}'::jsonb,
    'Battery Jumpstart / Dead Cell',
    ARRAY['Engine clicks but will not crank', 'Voltage drops below 10.2V'],
    FALSE,
    5.00,
    now() - INTERVAL '4 days' + INTERVAL '4 minutes',
    now() - INTERVAL '4 days' + INTERVAL '16 minutes',
    now() - INTERVAL '4 days' + INTERVAL '35 minutes',
    now() - INTERVAL '4 days'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.quotations (
    id, request_id, mechanic_id, diagnostic_fee, labor_fee, parts_fee,
    total_amount, status, line_items, created_at
) VALUES (
    'c0000000-0000-0000-0000-000000000002',
    'b0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000014',
    250.00, 350.00, 200.00, 800.00, 'accepted',
    '{"description": "Heavy booster jumpstart & alternator load health test"}'::jsonb,
    now() - INTERVAL '4 days' + INTERVAL '18 minutes'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.transactions (
    request_id, quotation_id, amount, payment_method, status, gateway_transaction_id, metadata, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000002',
    800.00, 'SSLCommerz-Nagad', 'completed', 'SSL-TX-998277',
    '{"invoice_ref": "INV-RDX-MIR-9134", "environment": "sandbox"}'::jsonb,
    now() - INTERVAL '4 days' + INTERVAL '35 minutes'
) ON CONFLICT DO NOTHING;

INSERT INTO public.reviews (
    request_id, motorist_id, mechanic_id, rating, comment, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000014',
    5,
    'Tested alternator output and got my vehicle started right away. Very professional.',
    now() - INTERVAL '4 days' + INTERVAL '36 minutes'
) ON CONFLICT DO NOTHING;

-- Scenario 3: Engine Overheating / Coolant Rupture at Mohakhali Flyover
INSERT INTO public.service_requests (
    id, request_code, motorist_id, mechanic_id, status,
    breakdown_location, breakdown_address, vehicle_snapshot,
    fault_type, symptoms, is_high_priority, search_radius_km,
    assigned_at, arrived_at, completed_at, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000003',
    'RDX-MHK-7721',
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000015',
    'completed',
    ST_SetSRID(ST_MakePoint(90.4035, 23.7782), 4326)::geography,
    'Mohakhali Flyover North Ramp, Dhaka',
    '{"plate": "DHAKA-METRO-GA-11-2026", "vehicle_type": "Passenger Car"}'::jsonb,
    'Engine Overheating / Coolant',
    ARRAY['Steam billowed from radiator cap', 'Temperature gauge pinned at red zone'],
    TRUE,
    5.00,
    now() - INTERVAL '3 days' + INTERVAL '5 minutes',
    now() - INTERVAL '3 days' + INTERVAL '17 minutes',
    now() - INTERVAL '3 days' + INTERVAL '52 minutes',
    now() - INTERVAL '3 days'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.quotations (
    id, request_id, mechanic_id, diagnostic_fee, labor_fee, parts_fee,
    total_amount, status, line_items, created_at
) VALUES (
    'c0000000-0000-0000-0000-000000000003',
    'b0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000015',
    250.00, 450.00, 550.00, 1250.00, 'accepted',
    '{"description": "Upper radiator hose emergency clamp repair & premix glycol refill"}'::jsonb,
    now() - INTERVAL '3 days' + INTERVAL '22 minutes'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.transactions (
    request_id, quotation_id, amount, payment_method, status, gateway_transaction_id, metadata, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000003',
    'c0000000-0000-0000-0000-000000000003',
    1250.00, 'SSLCommerz-bKash', 'completed', 'SSL-TX-998311',
    '{"invoice_ref": "INV-RDX-MHK-7721", "environment": "sandbox"}'::jsonb,
    now() - INTERVAL '3 days' + INTERVAL '52 minutes'
) ON CONFLICT DO NOTHING;

INSERT INTO public.reviews (
    request_id, motorist_id, mechanic_id, rating, comment, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000015',
    5,
    'Saved my engine from warping on the flyover. Rapid hose clamping and coolant refill!',
    now() - INTERVAL '3 days' + INTERVAL '54 minutes'
) ON CONFLICT DO NOTHING;

-- Scenario 4: Electrical Problems / Alternator Diode Fault at Banani 11
INSERT INTO public.service_requests (
    id, request_code, motorist_id, mechanic_id, status,
    breakdown_location, breakdown_address, vehicle_snapshot,
    fault_type, symptoms, is_high_priority, search_radius_km,
    assigned_at, arrived_at, completed_at, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000004',
    'RDX-BAN-6290',
    'a0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000016',
    'completed',
    ST_SetSRID(ST_MakePoint(90.4048, 23.7937), 4326)::geography,
    'Road 11, Block D, Banani, Dhaka',
    '{"plate": "DHAKA-METRO-GHA-14-3829", "vehicle_type": "Passenger Car"}'::jsonb,
    'General Automotive Breakdown',
    ARRAY['Headlights dimmed then all dashboard lights flashed', 'OBD-II alternator warning'],
    FALSE,
    5.00,
    now() - INTERVAL '2 days' + INTERVAL '4 minutes',
    now() - INTERVAL '2 days' + INTERVAL '19 minutes',
    now() - INTERVAL '2 days' + INTERVAL '48 minutes',
    now() - INTERVAL '2 days'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.quotations (
    id, request_id, mechanic_id, diagnostic_fee, labor_fee, parts_fee,
    total_amount, status, line_items, created_at
) VALUES (
    'c0000000-0000-0000-0000-000000000004',
    'b0000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000016',
    300.00, 400.00, 250.00, 950.00, 'accepted',
    '{"description": "ECU scanner fault triage & alternator rectifier bridge terminal bypass"}'::jsonb,
    now() - INTERVAL '2 days' + INTERVAL '24 minutes'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.transactions (
    request_id, quotation_id, amount, payment_method, status, gateway_transaction_id, metadata, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000004',
    'c0000000-0000-0000-0000-000000000004',
    950.00, 'SSLCommerz-Nagad', 'completed', 'SSL-TX-998344',
    '{"invoice_ref": "INV-RDX-BAN-6290", "environment": "sandbox"}'::jsonb,
    now() - INTERVAL '2 days' + INTERVAL '48 minutes'
) ON CONFLICT DO NOTHING;

INSERT INTO public.reviews (
    request_id, motorist_id, mechanic_id, rating, comment, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000004',
    'a0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000016',
    5,
    'Great digital scanner diagnosis. Identified the bad voltage regulator terminal in 5 mins.',
    now() - INTERVAL '2 days' + INTERVAL '50 minutes'
) ON CONFLICT DO NOTHING;

-- Scenario 5: Emergency Fuel Delivery (5 Liters) at Airport Road / Uttara
INSERT INTO public.service_requests (
    id, request_code, motorist_id, mechanic_id, status,
    breakdown_location, breakdown_address, vehicle_snapshot,
    fault_type, symptoms, is_high_priority, search_radius_km,
    assigned_at, arrived_at, completed_at, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000005',
    'RDX-UTR-5118',
    'a0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000013',
    'completed',
    ST_SetSRID(ST_MakePoint(90.3986, 23.8698), 4326)::geography,
    'Airport Road, Kawla Underpass, Uttara, Dhaka',
    '{"plate": "DHAKA-METRO-HA-12-8841", "vehicle_type": "Motorcycle"}'::jsonb,
    'Emergency Fuel Run (5 Liters)',
    ARRAY['Engine sputtered and choked on highway', 'Fuel tank empty'],
    FALSE,
    5.00,
    now() - INTERVAL '36 hours' + INTERVAL '2 minutes',
    now() - INTERVAL '36 hours' + INTERVAL '12 minutes',
    now() - INTERVAL '36 hours' + INTERVAL '25 minutes',
    now() - INTERVAL '36 hours'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.quotations (
    id, request_id, mechanic_id, diagnostic_fee, labor_fee, parts_fee,
    total_amount, status, line_items, created_at
) VALUES (
    'c0000000-0000-0000-0000-000000000005',
    'b0000000-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000013',
    100.00, 150.00, 500.00, 750.00, 'accepted',
    '{"description": "5-Liter certified high-grade octane container fuel delivery & prime"}'::jsonb,
    now() - INTERVAL '36 hours' + INTERVAL '14 minutes'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.transactions (
    request_id, quotation_id, amount, payment_method, status, gateway_transaction_id, metadata, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000005',
    'c0000000-0000-0000-0000-000000000005',
    750.00, 'SSLCommerz-bKash', 'completed', 'SSL-TX-998399',
    '{"invoice_ref": "INV-RDX-UTR-5118", "environment": "sandbox"}'::jsonb,
    now() - INTERVAL '36 hours' + INTERVAL '25 minutes'
) ON CONFLICT DO NOTHING;

INSERT INTO public.reviews (
    request_id, motorist_id, mechanic_id, rating, comment, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000005',
    'a0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000013',
    5,
    'Arrived on a motorbike with sealed 5L canister within 10 mins. Saved me from being stranded on Airport Road!',
    now() - INTERVAL '36 hours' + INTERVAL '26 minutes'
) ON CONFLICT DO NOTHING;

-- Scenario 6: Mechanical Failures / Brake Caliper Lockup at Tejgaon Industrial Area
INSERT INTO public.service_requests (
    id, request_code, motorist_id, mechanic_id, status,
    breakdown_location, breakdown_address, vehicle_snapshot,
    fault_type, symptoms, is_high_priority, search_radius_km,
    assigned_at, arrived_at, completed_at, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000006',
    'RDX-TEJ-4109',
    'a0000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000017',
    'completed',
    ST_SetSRID(ST_MakePoint(90.3951, 23.7639), 4326)::geography,
    'Shaheed Tajuddin Ahmed Sarani, Tejgaon I/A, Dhaka',
    '{"plate": "DHAKA-METRO-CHA-53-1092", "vehicle_type": "Light Commercial"}'::jsonb,
    'Brake Failure / Fluid Leak',
    ARRAY['Front left brake caliper locked up and smoking', 'Severe pedal shudder'],
    TRUE,
    5.00,
    now() - INTERVAL '20 hours' + INTERVAL '5 minutes',
    now() - INTERVAL '20 hours' + INTERVAL '22 minutes',
    now() - INTERVAL '20 hours' + INTERVAL '65 minutes',
    now() - INTERVAL '20 hours'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.quotations (
    id, request_id, mechanic_id, diagnostic_fee, labor_fee, parts_fee,
    total_amount, status, line_items, created_at
) VALUES (
    'c0000000-0000-0000-0000-000000000006',
    'b0000000-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000017',
    350.00, 600.00, 500.00, 1450.00, 'accepted',
    '{"description": "Commercial caliper piston release, guide pin lubrication & DOT4 bleeding"}'::jsonb,
    now() - INTERVAL '20 hours' + INTERVAL '26 minutes'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.transactions (
    request_id, quotation_id, amount, payment_method, status, gateway_transaction_id, metadata, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000006',
    'c0000000-0000-0000-0000-000000000006',
    1450.00, 'Cash Settlement', 'completed', 'CASH-REC-TEJ-4109',
    '{"invoice_ref": "INV-RDX-TEJ-4109", "verified_by": "mechanic"}'::jsonb,
    now() - INTERVAL '20 hours' + INTERVAL '65 minutes'
) ON CONFLICT DO NOTHING;

INSERT INTO public.reviews (
    request_id, motorist_id, mechanic_id, rating, comment, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000006',
    'a0000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000017',
    5,
    'Experienced commercial van mechanics. Freed the seized caliper without having to tow to workshop.',
    now() - INTERVAL '20 hours' + INTERVAL '68 minutes'
) ON CONFLICT DO NOTHING;

-- Scenario 7: Towing Requirements / Flatbed Recovery at Bijoy Sarani
INSERT INTO public.service_requests (
    id, request_code, motorist_id, mechanic_id, status,
    breakdown_location, breakdown_address, vehicle_snapshot,
    fault_type, symptoms, is_high_priority, search_radius_km,
    assigned_at, arrived_at, completed_at, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000007',
    'RDX-BJS-3382',
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000017',
    'completed',
    ST_SetSRID(ST_MakePoint(90.3872, 23.7663), 4326)::geography,
    'Bijoy Sarani Intersection, Tejgaon, Dhaka',
    '{"plate": "DHAKA-METRO-GA-11-2026", "vehicle_type": "Passenger Car"}'::jsonb,
    'Towing / Flatbed Recovery',
    ARRAY['Steering tie-rod snapped after pothole impact', 'Vehicle cannot roll'],
    TRUE,
    5.00,
    now() - INTERVAL '10 hours' + INTERVAL '3 minutes',
    now() - INTERVAL '10 hours' + INTERVAL '24 minutes',
    now() - INTERVAL '10 hours' + INTERVAL '70 minutes',
    now() - INTERVAL '10 hours'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.quotations (
    id, request_id, mechanic_id, diagnostic_fee, labor_fee, parts_fee,
    total_amount, status, line_items, created_at
) VALUES (
    'c0000000-0000-0000-0000-000000000007',
    'b0000000-0000-0000-0000-000000000007',
    '00000000-0000-0000-0000-000000000017',
    500.00, 3000.00, 0.00, 3500.00, 'accepted',
    '{"description": "Hydraulic flatbed winch loading & 12km transit to certified repair facility"}'::jsonb,
    now() - INTERVAL '10 hours' + INTERVAL '28 minutes'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.transactions (
    request_id, quotation_id, amount, payment_method, status, gateway_transaction_id, metadata, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000007',
    'c0000000-0000-0000-0000-000000000007',
    3500.00, 'SSLCommerz-Card', 'completed', 'SSL-TX-998490',
    '{"invoice_ref": "INV-RDX-BJS-3382", "card_brand": "VISA", "environment": "sandbox"}'::jsonb,
    now() - INTERVAL '10 hours' + INTERVAL '70 minutes'
) ON CONFLICT DO NOTHING;

INSERT INTO public.reviews (
    request_id, motorist_id, mechanic_id, rating, comment, created_at
) VALUES (
    'b0000000-0000-0000-0000-000000000007',
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000017',
    5,
    'Heavy flatbed truck safely winched the car with broken tie-rod without any body scratch. Top tier service!',
    now() - INTERVAL '10 hours' + INTERVAL '72 minutes'
) ON CONFLICT DO NOTHING;

