-- ============================================================================
-- ROADIX MIGRATION 08: REMOTE RECONCILIATION & PRODUCTION CONVERGENCE
-- Reconciles remote prototype tables (profiles, vehicles, contacts, wallets)
-- with production ROADIX schema (mechanic_profiles, service_requests, dispatch,
-- quotations, transactions, reviews, storage, realtime, and RLS).
-- Preserves all prototype records without destructive drops.
-- ============================================================================

-- 1. Create Core Enums if they do not exist
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE public.user_role AS ENUM ('motorist', 'mechanic', 'admin');
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'service_status') THEN
        CREATE TYPE public.service_status AS ENUM (
            'created', 'searching', 'assigned', 'en_route',
            'arrived', 'diagnosing', 'quote_pending', 'servicing',
            'completed', 'cancelled'
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dispatch_offer_status') THEN
        CREATE TYPE public.dispatch_offer_status AS ENUM (
            'offered', 'accepted', 'rejected', 'timed_out', 'cancelled'
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quotation_status') THEN
        CREATE TYPE public.quotation_status AS ENUM (
            'pending', 'accepted', 'rejected', 'expired'
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_status') THEN
        CREATE TYPE public.transaction_status AS ENUM (
            'pending', 'completed', 'failed', 'refunded'
        );
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2. Reconcile Existing Profiles Table (Additive)
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS role public.user_role NOT NULL DEFAULT 'motorist',
    ADD COLUMN IF NOT EXISTS avatar_url TEXT,
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- ----------------------------------------------------------------------------
-- 3. Reconcile Existing Emergency Contacts Table (Additive)
-- ----------------------------------------------------------------------------
ALTER TABLE public.emergency_contacts
    ADD COLUMN IF NOT EXISTS is_sos_recipient BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS relationship TEXT;

-- Sync relation into relationship if relationship is null
UPDATE public.emergency_contacts
SET relationship = relation
WHERE relationship IS NULL AND relation IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 4. Reconcile Existing Vehicles Table (Additive Constraints)
-- ----------------------------------------------------------------------------
ALTER TABLE public.vehicles
    DROP CONSTRAINT IF EXISTS vehicles_type_check;

ALTER TABLE public.vehicles
    ADD CONSTRAINT vehicles_type_check
    CHECK (type IN ('Passenger Car', 'Motorcycle', 'Light Commercial', 'Sedan', 'SUV', 'Commercial'));

-- ----------------------------------------------------------------------------
-- 5. Reconcile Existing Wallets Table (Additive Constraints)
-- ----------------------------------------------------------------------------
ALTER TABLE public.wallets
    DROP CONSTRAINT IF EXISTS wallets_provider_check;

ALTER TABLE public.wallets
    ADD CONSTRAINT wallets_provider_check
    CHECK (provider IN ('bKash', 'Nagad', 'Rocket'));

-- ----------------------------------------------------------------------------
-- 6. Create Production Tables
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
    vehicle_specializations TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_mechanics_location ON public.mechanic_profiles USING GIST(current_location);
CREATE INDEX IF NOT EXISTS idx_mechanics_duty_verified ON public.mechanic_profiles(is_on_duty, is_verified);

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

CREATE TABLE IF NOT EXISTS public.service_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_code TEXT NOT NULL UNIQUE,
    motorist_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    mechanic_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status public.service_status NOT NULL DEFAULT 'created',
    breakdown_location GEOGRAPHY(Point, 4326) NOT NULL,
    breakdown_address TEXT NOT NULL,
    vehicle_snapshot JSONB NOT NULL,
    fault_type TEXT NOT NULL,
    symptoms TEXT[] NOT NULL DEFAULT '{}',
    diagnostic_notes TEXT,
    photo_urls TEXT[] NOT NULL DEFAULT '{}',
    is_high_priority BOOLEAN NOT NULL DEFAULT FALSE,
    search_radius_km NUMERIC(4, 2) NOT NULL DEFAULT 5.00 CHECK (search_radius_km >= 5.00 AND search_radius_km <= 15.00),
    assigned_at TIMESTAMPTZ,
    arrived_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_service_requests_motorist ON public.service_requests(motorist_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_mechanic ON public.service_requests(mechanic_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_status ON public.service_requests(status);
CREATE INDEX IF NOT EXISTS idx_service_requests_location ON public.service_requests USING GIST(breakdown_location);

CREATE TABLE IF NOT EXISTS public.dispatch_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    mechanic_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status public.dispatch_offer_status NOT NULL DEFAULT 'offered',
    score NUMERIC(5, 2) NOT NULL,
    offer_radius_km NUMERIC(4, 2) NOT NULL,
    offered_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    expires_at TIMESTAMPTZ NOT NULL,
    responded_at TIMESTAMPTZ,
    CONSTRAINT uq_request_mechanic UNIQUE(request_id, mechanic_id)
);

CREATE INDEX IF NOT EXISTS idx_dispatch_offers_request ON public.dispatch_offers(request_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_offers_mechanic ON public.dispatch_offers(mechanic_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_offers_status ON public.dispatch_offers(status);

CREATE TABLE IF NOT EXISTS public.quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    mechanic_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    diagnostic_fee NUMERIC(10, 2) NOT NULL CHECK (diagnostic_fee >= 0),
    labor_fee NUMERIC(10, 2) NOT NULL CHECK (labor_fee >= 0),
    parts_fee NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (parts_fee >= 0),
    total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
    line_items JSONB NOT NULL DEFAULT '{}',
    status public.quotation_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_quotations_request ON public.quotations(request_id);
CREATE INDEX IF NOT EXISTS idx_quotations_mechanic ON public.quotations(mechanic_id);

CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    quotation_id UUID NOT NULL REFERENCES public.quotations(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
    payment_method TEXT NOT NULL,
    status public.transaction_status NOT NULL DEFAULT 'pending',
    gateway_transaction_id TEXT,
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_transactions_request ON public.transactions(request_id);

CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL UNIQUE REFERENCES public.service_requests(id) ON DELETE CASCADE,
    motorist_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    mechanic_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_reviews_mechanic ON public.reviews(mechanic_id);

CREATE TABLE IF NOT EXISTS public.standard_rate_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fault_type TEXT NOT NULL,
    vehicle_type TEXT NOT NULL CHECK (vehicle_type IN ('Passenger Car', 'Motorcycle', 'Light Commercial')),
    base_diagnostic_fee NUMERIC(10, 2) NOT NULL CHECK (base_diagnostic_fee >= 0),
    max_diagnostic_fee NUMERIC(10, 2) NOT NULL CHECK (max_diagnostic_fee >= base_diagnostic_fee),
    currency TEXT NOT NULL DEFAULT 'BDT',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_rate_cards_fault_vehicle UNIQUE(fault_type, vehicle_type)
);

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES public.profiles(id),
    action TEXT NOT NULL,
    target_entity TEXT NOT NULL,
    target_id UUID,
    payload JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 7. Functions & Procedures
-- ----------------------------------------------------------------------------

-- Extract canonical SRS vehicle class from vehicle_snapshot
CREATE OR REPLACE FUNCTION public.roadix_vehicle_type_from_snapshot(p_snapshot JSONB)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    v_raw TEXT;
BEGIN
    IF p_snapshot IS NULL OR jsonb_typeof(p_snapshot) <> 'object' THEN
        RAISE EXCEPTION
            'Vehicle snapshot must be a JSON object containing vehicle_type.';
    END IF;

    v_raw := COALESCE(
        NULLIF(btrim(p_snapshot ->> 'vehicle_type'), ''),
        NULLIF(btrim(p_snapshot ->> 'vehicle_class'), ''),
        NULLIF(btrim(p_snapshot ->> 'vehicleType'), ''),
        NULLIF(btrim(p_snapshot ->> 'vehicleClass'), ''),
        NULLIF(btrim(p_snapshot ->> 'type'), '')
    );

    IF v_raw IS NULL THEN
        RAISE EXCEPTION
            'Vehicle snapshot is missing its vehicle class. Send vehicle_type as Passenger Car, Motorcycle, or Light Commercial.';
    END IF;

    CASE lower(v_raw)
        WHEN 'passenger car', 'passenger_car', 'passengercar',
             'sedan', 'suv', 'sedan / hatch', 'suv / micro', 'sedan/hatch', 'suv/micro',
             'car', 'private car' THEN
            RETURN 'Passenger Car';
        WHEN 'motorcycle', 'bike', 'motorbike', 'scooter' THEN
            RETURN 'Motorcycle';
        WHEN 'light commercial', 'light_commercial', 'lightcommercial',
             'commercial', 'light commercial vehicle', 'pickup', 'van' THEN
            RETURN 'Light Commercial';
        ELSE
            RAISE EXCEPTION
                'Unsupported vehicle class "%". Use Passenger Car, Motorcycle, or Light Commercial.',
                v_raw;
    END CASE;
END;
$$;

-- Snapshot validation trigger on service_requests
CREATE OR REPLACE FUNCTION public.validate_service_request_vehicle_snapshot()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM public.roadix_vehicle_type_from_snapshot(NEW.vehicle_snapshot);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_service_request_vehicle_snapshot ON public.service_requests;
CREATE TRIGGER trg_validate_service_request_vehicle_snapshot
BEFORE INSERT OR UPDATE ON public.service_requests
FOR EACH ROW EXECUTE FUNCTION public.validate_service_request_vehicle_snapshot();

-- SRS Dispatch Scoring formula: 40% proximity, 25% vehicle category, 15% trust, 20% acceptance
CREATE OR REPLACE FUNCTION public.calculate_dispatch_score(
    p_distance_meters DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION,
    p_vehicle_type TEXT,
    p_vehicle_specializations TEXT[],
    p_average_rating NUMERIC,
    p_review_count INTEGER,
    p_acceptance_rate NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    v_proximity NUMERIC;
    v_vehicle_match NUMERIC;
    v_trust NUMERIC;
    v_confidence NUMERIC;
    v_rating NUMERIC;
    v_performance NUMERIC;
BEGIN
    v_proximity := CASE
        WHEN p_radius_meters IS NULL OR p_radius_meters <= 0
          OR p_distance_meters IS NULL THEN 0
        ELSE GREATEST(0, LEAST(100, (1 - p_distance_meters / p_radius_meters) * 100))
    END;

    IF p_vehicle_type = ANY(COALESCE(p_vehicle_specializations, '{}'::TEXT[])) THEN
        v_vehicle_match := 100;
    ELSIF COALESCE(array_length(p_vehicle_specializations, 1), 0) = 0 THEN
        v_vehicle_match := 50;
    ELSE
        v_vehicle_match := 0;
    END IF;

    v_rating := GREATEST(1, LEAST(5, COALESCE(p_average_rating, 3)));
    v_confidence := GREATEST(0, LEAST(1, GREATEST(COALESCE(p_review_count, 0), 0) / 5.0));

    v_trust := (((v_rating - 1) / 4) * 100 * v_confidence) + (50 * (1 - v_confidence));

    v_performance := GREATEST(0, LEAST(100, COALESCE(p_acceptance_rate, 50)));

    RETURN ROUND(
        (0.40 * v_proximity) +
        (0.25 * v_vehicle_match) +
        (0.15 * v_trust) +
        (0.20 * v_performance),
        2
    );
END;
$$;

-- Vehicle-aware eligible mechanic discovery
CREATE OR REPLACE FUNCTION public.find_eligible_mechanics(
    p_breakdown_location GEOGRAPHY,
    p_radius_meters DOUBLE PRECISION,
    p_fault_type TEXT,
    p_vehicle_type TEXT
)
RETURNS TABLE (
    mechanic_id UUID,
    workshop_name TEXT,
    distance_meters DOUBLE PRECISION,
    rating NUMERIC,
    total_rescues INTEGER,
    specializations TEXT[],
    dispatch_score NUMERIC(5,2)
)
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    v_radius DOUBLE PRECISION;
    v_canonical_vehicle TEXT;
BEGIN
    IF p_breakdown_location IS NULL THEN
        RAISE EXCEPTION 'Breakdown location is required.';
    END IF;

    v_radius := LEAST(GREATEST(COALESCE(p_radius_meters, 5000), 5000), 15000);

    CASE lower(COALESCE(p_vehicle_type, ''))
        WHEN 'passenger car', 'passenger_car', 'passengercar', 'sedan', 'suv', 'car' THEN
            v_canonical_vehicle := 'Passenger Car';
        WHEN 'motorcycle', 'bike', 'motorbike' THEN
            v_canonical_vehicle := 'Motorcycle';
        WHEN 'light commercial', 'light_commercial', 'commercial' THEN
            v_canonical_vehicle := 'Light Commercial';
        ELSE
            v_canonical_vehicle := 'Passenger Car';
    END CASE;

    RETURN QUERY
    WITH mechanic_history AS (
        SELECT
            m.profile_id,
            m.workshop_name,
            ST_Distance(m.current_location, p_breakdown_location) AS dist,
            m.rating,
            m.total_rescues,
            m.specializations,
            m.vehicle_specializations,
            COALESCE(avg(r.rating), m.rating, 3.0) AS avg_rating,
            COUNT(r.id)::INTEGER AS rev_count,
            COUNT(o.id) FILTER (WHERE o.status IN ('accepted', 'rejected', 'timed_out'))::BIGINT AS resolved_offers,
            COUNT(o.id) FILTER (WHERE o.status = 'accepted')::BIGINT AS accepted_offers
        FROM public.mechanic_profiles AS m
        JOIN public.profiles AS p ON p.id = m.profile_id
        LEFT JOIN public.reviews r ON r.mechanic_id = m.profile_id
        LEFT JOIN public.dispatch_offers o ON o.mechanic_id = m.profile_id
        WHERE p.role = 'mechanic'
          AND m.is_on_duty
          AND m.is_verified
          AND m.current_location IS NOT NULL
          AND ST_DWithin(m.current_location, p_breakdown_location, v_radius)
          AND NOT EXISTS (
              SELECT 1
              FROM public.service_requests AS active_sr
              WHERE active_sr.mechanic_id = m.profile_id
                AND active_sr.status IN ('assigned','en_route','arrived','diagnosing','quote_pending','servicing')
          )
        GROUP BY m.profile_id, m.workshop_name, m.current_location, m.rating,
                 m.total_rescues, m.specializations, m.vehicle_specializations
    )
    SELECT
        mh.profile_id,
        mh.workshop_name,
        mh.dist,
        mh.rating,
        mh.total_rescues,
        mh.specializations,
        public.calculate_dispatch_score(
            mh.dist,
            v_radius,
            v_canonical_vehicle,
            mh.vehicle_specializations,
            mh.avg_rating,
            mh.rev_count,
            CASE
                WHEN mh.resolved_offers = 0 THEN 50.0
                ELSE (mh.accepted_offers::NUMERIC / mh.resolved_offers::NUMERIC) * 100.0
            END
        )::NUMERIC(5,2) AS dispatch_score
    FROM mechanic_history mh
    ORDER BY 7 DESC, 3 ASC;
END;
$$;

-- Create service request RPC
CREATE OR REPLACE FUNCTION public.create_service_request(
    p_breakdown_lat DOUBLE PRECISION,
    p_breakdown_lng DOUBLE PRECISION,
    p_breakdown_address TEXT,
    p_vehicle_snapshot JSONB,
    p_fault_type TEXT,
    p_symptoms TEXT[],
    p_diagnostic_notes TEXT,
    p_photo_urls TEXT[],
    p_is_high_priority BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_request_id UUID;
    v_request_code TEXT;
    v_location GEOGRAPHY;
    v_attempts INTEGER := 0;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_breakdown_lat IS NULL OR p_breakdown_lng IS NULL THEN
        RAISE EXCEPTION 'Breakdown coordinates are required.';
    END IF;

    IF p_breakdown_lat < 20.0 OR p_breakdown_lat > 27.0
       OR p_breakdown_lng < 88.0 OR p_breakdown_lng > 93.0 THEN
        RAISE EXCEPTION 'Coordinates are outside the supported Bangladesh operational bounds.';
    END IF;

    IF p_fault_type IS NULL OR btrim(p_fault_type) = '' THEN
        RAISE EXCEPTION 'Fault type is required.';
    END IF;

    PERFORM public.roadix_vehicle_type_from_snapshot(p_vehicle_snapshot);

    v_location := ST_SetSRID(ST_MakePoint(p_breakdown_lng, p_breakdown_lat), 4326)::geography;

    LOOP
        v_attempts := v_attempts + 1;
        v_request_code := 'RDX-' || to_char(now(), 'YYYYMMDD') || '-' ||
                          upper(substring(replace(gen_random_uuid()::text, '-', '') FROM 1 FOR 6));

        BEGIN
            INSERT INTO public.service_requests (
                request_code, motorist_id, status, breakdown_location,
                breakdown_address, vehicle_snapshot, fault_type, symptoms,
                diagnostic_notes, photo_urls, is_high_priority, search_radius_km
            )
            VALUES (
                v_request_code, v_user, 'searching', v_location,
                COALESCE(p_breakdown_address, 'Dhaka Roadside Position'),
                p_vehicle_snapshot, p_fault_type, COALESCE(p_symptoms, '{}'),
                p_diagnostic_notes, COALESCE(p_photo_urls, '{}'),
                COALESCE(p_is_high_priority, FALSE), 5.00
            )
            RETURNING id INTO v_request_id;

            EXIT;
        EXCEPTION
            WHEN unique_violation THEN
                IF v_attempts > 5 THEN
                    RAISE EXCEPTION 'Could not generate unique request code after 5 attempts.';
                END IF;
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'id', v_request_id,
        'request_code', v_request_code,
        'status', 'searching',
        'search_radius_km', 5.00
    );
END;
$$;

-- Dispatch next candidate RPC
CREATE OR REPLACE FUNCTION public.dispatch_next_candidate(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_req RECORD;
    v_user UUID := auth.uid();
    v_candidate RECORD;
    v_offer_id UUID;
    v_expires_at TIMESTAMPTZ;
    v_vehicle_type TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT id, motorist_id, breakdown_location, search_radius_km,
           fault_type, vehicle_snapshot, status
    INTO v_req
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service request not found.';
    END IF;

    IF v_user <> v_req.motorist_id AND NOT (EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user AND role = 'admin')) THEN
        RAISE EXCEPTION 'Not authorized to dispatch this request.';
    END IF;

    IF v_req.status <> 'searching' THEN
        RAISE EXCEPTION 'Request is not in searching state.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.dispatch_offers o
        WHERE o.request_id = p_request_id
          AND o.status = 'offered'
          AND o.expires_at > now()
    ) THEN
        RAISE EXCEPTION 'An offer is already active for this request.';
    END IF;

    UPDATE public.dispatch_offers
    SET status = 'timed_out', responded_at = now()
    WHERE request_id = p_request_id
      AND status = 'offered'
      AND expires_at <= now();

    v_vehicle_type := public.roadix_vehicle_type_from_snapshot(v_req.vehicle_snapshot);

    SELECT c.*
    INTO v_candidate
    FROM public.find_eligible_mechanics(
        v_req.breakdown_location,
        v_req.search_radius_km * 1000.0,
        v_req.fault_type,
        v_vehicle_type
    ) AS c
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.dispatch_offers o
        WHERE o.request_id = p_request_id
          AND o.mechanic_id = c.mechanic_id
    )
    ORDER BY c.dispatch_score DESC, c.distance_meters ASC
    LIMIT 1;

    IF v_candidate.mechanic_id IS NULL THEN
        RETURN jsonb_build_object(
            'status', 'exhausted',
            'search_radius_km', v_req.search_radius_km,
            'can_expand', v_req.search_radius_km < 15.00,
            'message', 'No unoffered eligible mechanics remain within the current radius.'
        );
    END IF;

    v_expires_at := now() + INTERVAL '45 seconds';

    INSERT INTO public.dispatch_offers (
        request_id, mechanic_id, offer_radius_km, score,
        status, offered_at, expires_at
    )
    VALUES (
        p_request_id, v_candidate.mechanic_id, v_req.search_radius_km,
        v_candidate.dispatch_score, 'offered', now(), v_expires_at
    )
    RETURNING id INTO v_offer_id;

    RETURN jsonb_build_object(
        'status', 'offered',
        'offer_id', v_offer_id,
        'mechanic_id', v_candidate.mechanic_id,
        'workshop_name', v_candidate.workshop_name,
        'dispatch_score', v_candidate.dispatch_score,
        'search_radius_km', v_req.search_radius_km,
        'expires_at', v_expires_at
    );
END;
$$;

-- Expand radius RPC
CREATE OR REPLACE FUNCTION public.expand_dispatch_radius(p_request_id UUID)
RETURNS NUMERIC(4,2)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_req RECORD;
    v_user UUID := auth.uid();
    v_unoffered INTEGER;
    v_new_radius NUMERIC(4,2);
    v_vehicle_type TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT id, motorist_id, breakdown_location, search_radius_km,
           fault_type, vehicle_snapshot, status
    INTO v_req
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service request not found.';
    END IF;

    IF v_user <> v_req.motorist_id AND NOT (EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user AND role = 'admin')) THEN
        RAISE EXCEPTION 'Not authorized to expand this request radius.';
    END IF;

    IF v_req.status <> 'searching' THEN
        RAISE EXCEPTION 'Only searching requests can expand radius.';
    END IF;

    IF v_req.search_radius_km >= 15.00 THEN
        RETURN 15.00;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.dispatch_offers o
        WHERE o.request_id = p_request_id
          AND o.status = 'offered'
          AND o.expires_at > now()
    ) THEN
        RAISE EXCEPTION 'Wait for the active offer to receive a response or expire.';
    END IF;

    UPDATE public.dispatch_offers
    SET status = 'timed_out', responded_at = now()
    WHERE request_id = p_request_id
      AND status = 'offered'
      AND expires_at <= now();

    v_vehicle_type := public.roadix_vehicle_type_from_snapshot(v_req.vehicle_snapshot);

    SELECT count(*) INTO v_unoffered
    FROM public.find_eligible_mechanics(
        v_req.breakdown_location,
        v_req.search_radius_km * 1000.0,
        v_req.fault_type,
        v_vehicle_type
    ) AS c
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.dispatch_offers o
        WHERE o.request_id = p_request_id
          AND o.mechanic_id = c.mechanic_id
    );

    IF v_unoffered > 0 THEN
        RAISE EXCEPTION 'Cannot expand: % eligible mechanic(s) have not yet received an offer.', v_unoffered;
    END IF;

    v_new_radius := LEAST(v_req.search_radius_km + 2.50, 15.00);

    UPDATE public.service_requests
    SET search_radius_km = v_new_radius, updated_at = now()
    WHERE id = p_request_id;

    RETURN v_new_radius;
END;
$$;

-- Accept dispatch offer RPC
CREATE OR REPLACE FUNCTION public.accept_dispatch_offer(
    p_request_id UUID,
    p_offer_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_mechanic RECORD;
    v_offer RECORD;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT profile_id, is_verified, is_on_duty
    INTO v_mechanic
    FROM public.mechanic_profiles
    WHERE profile_id = v_user
    FOR UPDATE;

    IF NOT FOUND OR NOT v_mechanic.is_verified OR NOT v_mechanic.is_on_duty THEN
        RAISE EXCEPTION 'Only verified, on-duty mechanics can accept offers.';
    END IF;

    SELECT id, status, expires_at
    INTO v_offer
    FROM public.dispatch_offers
    WHERE id = p_offer_id AND request_id = p_request_id AND mechanic_id = v_user
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Offer not found or unauthorized.';
    END IF;

    IF v_offer.status <> 'offered' OR v_offer.expires_at <= now() THEN
        UPDATE public.dispatch_offers
        SET status = 'timed_out', responded_at = now()
        WHERE id = p_offer_id;
        RETURN FALSE;
    END IF;

    UPDATE public.service_requests
    SET mechanic_id = v_user,
        status = 'assigned',
        assigned_at = now(),
        updated_at = now()
    WHERE id = p_request_id AND status = 'searching';

    IF NOT FOUND THEN
        UPDATE public.dispatch_offers
        SET status = 'cancelled'
        WHERE id = p_offer_id;
        RETURN FALSE;
    END IF;

    UPDATE public.dispatch_offers
    SET status = 'accepted', responded_at = now()
    WHERE id = p_offer_id;

    UPDATE public.dispatch_offers
    SET status = 'cancelled', responded_at = now()
    WHERE request_id = p_request_id AND id <> p_offer_id AND status = 'offered';

    RETURN TRUE;
END;
$$;

-- Reject dispatch offer RPC
CREATE OR REPLACE FUNCTION public.reject_dispatch_offer(p_offer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_offer RECORD;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT id, status, expires_at
    INTO v_offer
    FROM public.dispatch_offers
    WHERE id = p_offer_id AND mechanic_id = v_user
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Offer not found or unauthorized.';
    END IF;

    IF v_offer.status <> 'offered' THEN
        RETURN FALSE;
    END IF;

    UPDATE public.dispatch_offers
    SET status = 'rejected', responded_at = now()
    WHERE id = p_offer_id;

    RETURN TRUE;
END;
$$;

-- Update mechanic live location RPC
CREATE OR REPLACE FUNCTION public.update_mechanic_location(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user UUID := auth.uid();
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_lat < 20.0 OR p_lat > 27.0 OR p_lng < 88.0 OR p_lng > 93.0 THEN
        RAISE EXCEPTION 'Coordinates are outside supported Bangladesh bounds.';
    END IF;

    UPDATE public.mechanic_profiles
    SET current_location = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
        updated_at = now()
    WHERE profile_id = v_user;
END;
$$;

-- Submit quotation RPC
CREATE OR REPLACE FUNCTION public.submit_quotation(
    p_request_id UUID,
    p_diagnostic_fee NUMERIC,
    p_labor_fee NUMERIC,
    p_parts_fee NUMERIC,
    p_line_items JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_req RECORD;
    v_quote_id UUID;
    v_total NUMERIC;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT id, mechanic_id, status INTO v_req
    FROM public.service_requests
    WHERE id = p_request_id;

    IF NOT FOUND OR v_req.mechanic_id <> v_user THEN
        RAISE EXCEPTION 'Only the assigned mechanic can submit quotations.';
    END IF;

    v_total := COALESCE(p_diagnostic_fee, 0) + COALESCE(p_labor_fee, 0) + COALESCE(p_parts_fee, 0);

    INSERT INTO public.quotations (
        request_id, mechanic_id, diagnostic_fee, labor_fee, parts_fee, total_amount, line_items, status
    )
    VALUES (
        p_request_id, v_user, p_diagnostic_fee, p_labor_fee, COALESCE(p_parts_fee, 0), v_total, COALESCE(p_line_items, '{}'), 'pending'
    )
    RETURNING id INTO v_quote_id;

    UPDATE public.service_requests
    SET status = 'quote_pending', updated_at = now()
    WHERE id = p_request_id;

    RETURN jsonb_build_object(
        'quotation_id', v_quote_id,
        'total_amount', v_total,
        'status', 'pending'
    );
END;
$$;

-- Respond to quotation RPC
CREATE OR REPLACE FUNCTION public.respond_to_quotation(
    p_quotation_id UUID,
    p_decision TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_quote RECORD;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT q.id, q.request_id, sr.motorist_id
    INTO v_quote
    FROM public.quotations q
    JOIN public.service_requests sr ON sr.id = q.request_id
    WHERE q.id = p_quotation_id;

    IF NOT FOUND OR v_quote.motorist_id <> v_user THEN
        RAISE EXCEPTION 'Only the requesting motorist can respond to quotations.';
    END IF;

    IF p_decision = 'accepted' THEN
        UPDATE public.quotations SET status = 'accepted', updated_at = now() WHERE id = p_quotation_id;
        UPDATE public.service_requests SET status = 'servicing', updated_at = now() WHERE id = v_quote.request_id;
        RETURN TRUE;
    ELSE
        UPDATE public.quotations SET status = 'rejected', updated_at = now() WHERE id = p_quotation_id;
        RETURN FALSE;
    END IF;
END;
$$;

-- Handle new user auth trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (id, user_id, full_name, phone, role)
    VALUES (
        NEW.id,
        NEW.id,
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), NULLIF(NEW.raw_user_meta_data->>'name', ''), 'Motorist'),
        NEW.phone,
        'motorist'
    )
    ON CONFLICT (id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 8. Row Level Security Policies & Role Grants
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mechanic_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mechanic_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispatch_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.standard_rate_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Drop prototype dummy policies
DO $$ DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
    END LOOP;
END $$;

-- Profiles policies
CREATE POLICY profiles_select_authorized ON public.profiles
FOR SELECT TO authenticated
USING (
    id = auth.uid()
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    OR EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE (sr.motorist_id = auth.uid() AND sr.mechanic_id = profiles.id)
           OR (sr.mechanic_id = auth.uid() AND sr.motorist_id = profiles.id)
    )
);

CREATE POLICY profiles_update_own ON public.profiles
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Mechanic profiles policies
CREATE POLICY mechanics_select_authorized ON public.mechanic_profiles
FOR SELECT TO authenticated
USING (
    profile_id = auth.uid()
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    OR EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.mechanic_id = mechanic_profiles.profile_id
          AND sr.motorist_id = auth.uid()
          AND sr.status IN ('assigned','en_route','arrived','diagnosing','quote_pending','servicing','completed')
    )
);

CREATE POLICY mechanics_insert_own ON public.mechanic_profiles
FOR INSERT TO authenticated
WITH CHECK (profile_id = auth.uid());

CREATE POLICY mechanics_update_own ON public.mechanic_profiles
FOR UPDATE TO authenticated
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

-- Vehicles, Emergency Contacts, Wallets policies
CREATE POLICY vehicles_owner_admin ON public.vehicles
FOR ALL TO authenticated
USING (profile_id = auth.uid() OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK (profile_id = auth.uid() OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

CREATE POLICY emergency_contacts_owner_admin ON public.emergency_contacts
FOR ALL TO authenticated
USING (profile_id = auth.uid() OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK (profile_id = auth.uid() OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

CREATE POLICY wallets_owner_admin ON public.wallets
FOR ALL TO authenticated
USING (profile_id = auth.uid() OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK (profile_id = auth.uid() OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- Service Requests policies
CREATE POLICY service_requests_select_participants ON public.service_requests
FOR SELECT TO authenticated
USING (
    motorist_id = auth.uid()
    OR mechanic_id = auth.uid()
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY service_requests_update_motorist ON public.service_requests
FOR UPDATE TO authenticated
USING (motorist_id = auth.uid() AND status IN ('created','searching','assigned'))
WITH CHECK (motorist_id = auth.uid() AND status IN ('searching','cancelled'));

CREATE POLICY service_requests_update_mechanic ON public.service_requests
FOR UPDATE TO authenticated
USING (mechanic_id = auth.uid() AND status IN ('assigned','en_route','arrived','diagnosing','quote_pending','servicing'))
WITH CHECK (mechanic_id = auth.uid() AND status IN ('en_route','arrived','diagnosing','quote_pending','servicing','completed'));

-- Dispatch Offers policies (mechanics can only see their own offers; motorist cannot sniff offers)
CREATE POLICY dispatch_offers_select_recipient ON public.dispatch_offers
FOR SELECT TO authenticated
USING (mechanic_id = auth.uid() OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- Quotations policies
CREATE POLICY quotations_select_participants ON public.quotations
FOR SELECT TO authenticated
USING (
    mechanic_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.service_requests sr WHERE sr.id = quotations.request_id AND sr.motorist_id = auth.uid())
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

-- Reviews policies
CREATE POLICY reviews_select_all ON public.reviews
FOR SELECT TO authenticated
USING (TRUE);

CREATE POLICY reviews_insert_motorist ON public.reviews
FOR INSERT TO authenticated
WITH CHECK (
    motorist_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.id = reviews.request_id
          AND sr.motorist_id = auth.uid()
          AND sr.status = 'completed'
    )
);

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vehicles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.emergency_contacts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wallets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mechanic_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mechanic_verifications TO authenticated;
GRANT SELECT, UPDATE ON public.service_requests TO authenticated;
GRANT SELECT ON public.dispatch_offers TO authenticated;
GRANT SELECT ON public.quotations TO authenticated;
GRANT SELECT, INSERT ON public.transactions TO authenticated;
GRANT SELECT, INSERT ON public.reviews TO authenticated;
GRANT SELECT ON public.standard_rate_cards TO authenticated;

GRANT EXECUTE ON FUNCTION public.create_service_request(DOUBLE PRECISION, DOUBLE PRECISION, TEXT, JSONB, TEXT, TEXT[], TEXT, TEXT[], BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.dispatch_next_candidate(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.expand_dispatch_radius(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.accept_dispatch_offer(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reject_dispatch_offer(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_mechanic_location(DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_quotation(UUID, NUMERIC, NUMERIC, NUMERIC, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.respond_to_quotation(UUID, TEXT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 9. Realtime Publication
-- ----------------------------------------------------------------------------
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.service_requests;
EXCEPTION WHEN duplicate_object THEN END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.dispatch_offers;
EXCEPTION WHEN duplicate_object THEN END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.quotations;
EXCEPTION WHEN duplicate_object THEN END $$;

-- ----------------------------------------------------------------------------
-- 10. Storage Buckets (mechanic-verifications, fault-photos, avatars)
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES
    ('mechanic-verifications', 'mechanic-verifications', false),
    ('fault-photos', 'fault-photos', false),
    ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;
