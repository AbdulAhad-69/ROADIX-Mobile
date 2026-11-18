-- ============================================================================
-- ROADIX MIGRATION 02: Profiles, Mechanics, Vehicles, Wallets & Contacts
-- Baseline: Phase 04 Database Implementation (Hardened Security)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Profiles Table (Central identity linked 1:1 with auth.users)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'motorist' CHECK (role IN ('motorist', 'mechanic', 'admin')),
    full_name TEXT NOT NULL,
    phone TEXT UNIQUE,
    avatar_url TEXT,
    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
    is_nid_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone);

-- ----------------------------------------------------------------------------
-- 2. Mechanic Profiles Table (Operational technician profile & PostGIS telemetry)
-- Sensitive government NID and trade license scans are isolated in mechanic_verifications
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mechanic_profiles (
    profile_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    workshop_name TEXT NOT NULL,
    workshop_address TEXT NOT NULL,
    current_location GEOGRAPHY(Point, 4326),
    is_on_duty BOOLEAN NOT NULL DEFAULT FALSE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    rating NUMERIC(3, 2) NOT NULL DEFAULT 5.00 CHECK (rating >= 1.00 AND rating <= 5.00),
    total_rescues INTEGER NOT NULL DEFAULT 0 CHECK (total_rescues >= 0),
    specializations TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- GiST Spatial Index for sub-millisecond distance calculation in dispatch
CREATE INDEX IF NOT EXISTS idx_mechanics_location ON public.mechanic_profiles USING GIST(current_location);
CREATE INDEX IF NOT EXISTS idx_mechanics_duty_verified ON public.mechanic_profiles(is_on_duty, is_verified);

-- ----------------------------------------------------------------------------
-- 3. Mechanic Verifications Table (Isolated government NID & trade license credentials)
-- Strictly accessible ONLY by the technician themselves and Platform Admins
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mechanic_verifications (
    profile_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    trade_license_number TEXT,
    nid_number TEXT,
    nid_front_url TEXT,
    nid_back_url TEXT,
    verified_at TIMESTAMPTZ,
    verified_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_mechanic_verifications_verified ON public.mechanic_verifications(verified_at);

-- ----------------------------------------------------------------------------
-- 4. Vehicles Table (Digital Garage for Motorists)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    model TEXT NOT NULL,
    plate TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('Sedan', 'SUV', 'Motorcycle', 'Commercial')),
    fuel TEXT NOT NULL CHECK (fuel IN ('Octane', 'Petrol', 'Diesel', 'CNG', 'EV')),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_profile_plate UNIQUE (profile_id, plate)
);

CREATE INDEX IF NOT EXISTS idx_vehicles_profile ON public.vehicles(profile_id);

-- ----------------------------------------------------------------------------
-- 5. Emergency Contacts Table (SOS Broadcast Recipients)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    relationship TEXT,
    is_sos_recipient BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_emergency_contacts_profile ON public.emergency_contacts(profile_id);

-- ----------------------------------------------------------------------------
-- 6. Wallets Table (MFS Payment Accounts)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider TEXT NOT NULL CHECK (provider IN ('bKash', 'Nagad', 'Rocket')),
    account_number TEXT NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_wallets_profile ON public.wallets(profile_id);
