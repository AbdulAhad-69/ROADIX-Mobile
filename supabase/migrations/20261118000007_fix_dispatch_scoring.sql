-- ============================================================================
-- ROADIX MIGRATION 07 (CORRECTED): Vehicle-aware dispatch scoring
-- Apply after Migrations 01-05.
--
-- This replaces the earlier draft of Migration 07.
-- It preserves the SRS vehicle classes and updates EVERY dispatch caller to
-- use the new four-argument mechanic-discovery function.
--
-- Vehicle snapshot contract:
--   A top-level JSON property named vehicle_type, vehicle_class, vehicleType,
--   vehicleClass, or type must contain one of:
--     Passenger Car | Motorcycle | Light Commercial
--   Legacy values Sedan/SUV/Commercial are normalized for compatibility.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Normalize the vehicle classes in the saved-vehicle table to the SRS.
-- ----------------------------------------------------------------------------
ALTER TABLE public.vehicles
    DROP CONSTRAINT IF EXISTS vehicles_type_check;

UPDATE public.vehicles
SET type = CASE
    WHEN type IN ('Sedan', 'SUV') THEN 'Passenger Car'
    WHEN type = 'Commercial' THEN 'Light Commercial'
    ELSE type
END;

ALTER TABLE public.vehicles
    ADD CONSTRAINT vehicles_type_check
    CHECK (type IN ('Passenger Car', 'Motorcycle', 'Light Commercial'));

-- Keep rate-card vehicle classes consistent. If legacy rows collide after
-- normalization (e.g. Sedan and SUV both become Passenger Car), retain one
-- deterministic row: prefer an already-canonical row, then the newest row.
WITH normalized AS (
    SELECT
        id,
        row_number() OVER (
            PARTITION BY fault_type,
                CASE
                    WHEN vehicle_type IN ('Sedan', 'SUV') THEN 'Passenger Car'
                    WHEN vehicle_type = 'Commercial' THEN 'Light Commercial'
                    ELSE vehicle_type
                END
            ORDER BY
                (vehicle_type IN ('Passenger Car', 'Motorcycle', 'Light Commercial')) DESC,
                updated_at DESC,
                id
        ) AS rn
    FROM public.standard_rate_cards
)
DELETE FROM public.standard_rate_cards r
USING normalized n
WHERE r.id = n.id
  AND n.rn > 1;

UPDATE public.standard_rate_cards
SET vehicle_type = CASE
    WHEN vehicle_type IN ('Sedan', 'SUV') THEN 'Passenger Car'
    WHEN vehicle_type = 'Commercial' THEN 'Light Commercial'
    ELSE vehicle_type
END;

ALTER TABLE public.standard_rate_cards
    DROP CONSTRAINT IF EXISTS standard_rate_cards_vehicle_type_check;

ALTER TABLE public.standard_rate_cards
    ADD CONSTRAINT standard_rate_cards_vehicle_type_check
    CHECK (vehicle_type IN ('Passenger Car', 'Motorcycle', 'Light Commercial'));

-- ----------------------------------------------------------------------------
-- 2. Store mechanic vehicle capabilities separately from fault capabilities.
-- Empty array means "not yet provided"; it is not an assertion that the
-- mechanic supports every vehicle class.
-- ----------------------------------------------------------------------------
ALTER TABLE public.mechanic_profiles
    ADD COLUMN IF NOT EXISTS vehicle_specializations TEXT[] NOT NULL DEFAULT '{}';

ALTER TABLE public.mechanic_profiles
    DROP CONSTRAINT IF EXISTS mechanic_vehicle_specializations_check;

ALTER TABLE public.mechanic_profiles
    ADD CONSTRAINT mechanic_vehicle_specializations_check
    CHECK (
        vehicle_specializations <@
        ARRAY[
            'Passenger Car',
            'Motorcycle',
            'Light Commercial'
        ]::TEXT[]
    );

-- Existing RLS policy mechanics_insert_own / mechanics_update_own already
-- restricts writes to the mechanic's own row. Add column-level privileges.
GRANT INSERT (vehicle_specializations)
    ON public.mechanic_profiles TO authenticated;
GRANT UPDATE (vehicle_specializations)
    ON public.mechanic_profiles TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. Normalize the vehicle class from a request snapshot.
-- Do not silently guess if the app sends an unknown or missing value.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.roadix_vehicle_type_from_snapshot(
    p_snapshot JSONB
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    v_raw TEXT;
BEGIN
    IF p_snapshot IS NULL OR jsonb_typeof(p_snapshot) <> 'object' THEN
        RAISE EXCEPTION 'Vehicle snapshot must be a JSON object.';
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

REVOKE ALL ON FUNCTION public.roadix_vehicle_type_from_snapshot(JSONB)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.roadix_vehicle_type_from_snapshot(JSONB)
    TO postgres, service_role;

-- Validate new service requests at insertion time so malformed snapshots are
-- rejected when the request is created, not later during emergency dispatch.
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

DROP TRIGGER IF EXISTS trg_validate_service_request_vehicle_snapshot
    ON public.service_requests;

CREATE TRIGGER trg_validate_service_request_vehicle_snapshot
BEFORE INSERT OR UPDATE ON public.service_requests
FOR EACH ROW
EXECUTE FUNCTION public.validate_service_request_vehicle_snapshot();

REVOKE ALL ON FUNCTION public.validate_service_request_vehicle_snapshot()
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_service_request_vehicle_snapshot()
    TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Replace the draft scoring helper.
--
-- We drop/recreate this signature because PostgreSQL does not allow input
-- parameter names to be changed with CREATE OR REPLACE FUNCTION.
--
-- 40% proximity
-- 25% vehicle-class specialization
-- 15% rating/trust (review average confidence-adjusted toward neutral 3/5)
-- 20% historical offer acceptance rate (cancelled offers excluded)
--
-- No fabricated 4.5 rating or fixed 85% performance score.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.calculate_dispatch_score(
    DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT[],
    NUMERIC, INTEGER, NUMERIC
);

CREATE FUNCTION public.calculate_dispatch_score(
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
        ELSE GREATEST(
            0,
            LEAST(100, (1 - p_distance_meters / p_radius_meters) * 100)
        )
    END;

    IF p_vehicle_type = ANY(COALESCE(p_vehicle_specializations, '{}'::TEXT[])) THEN
        v_vehicle_match := 100;
    ELSIF COALESCE(array_length(p_vehicle_specializations, 1), 0) = 0 THEN
        -- Neutral until the mechanic has entered their supported classes.
        v_vehicle_match := 50;
    ELSE
        v_vehicle_match := 0;
    END IF;

    -- New mechanics start at neutral, not at an invented five-star rating.
    v_rating := GREATEST(1, LEAST(5, COALESCE(p_average_rating, 3)));
    v_confidence := GREATEST(
        0,
        LEAST(1, GREATEST(COALESCE(p_review_count, 0), 0) / 5.0)
    );

    v_trust :=
        (((v_rating - 1) / 4) * 100 * v_confidence)
        + (50 * (1 - v_confidence));

    -- Mechanics are already filtered to verified, on-duty, and not busy.
    -- This factor therefore measures historical offer acceptance, not duty.
    v_performance := GREATEST(
        0,
        LEAST(100, COALESCE(p_acceptance_rate, 50))
    );

    RETURN ROUND(
        (0.40 * v_proximity)
        + (0.25 * v_vehicle_match)
        + (0.15 * v_trust)
        + (0.20 * v_performance),
        2
    );
END;
$$;

REVOKE ALL ON FUNCTION public.calculate_dispatch_score(
    DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT[],
    NUMERIC, INTEGER, NUMERIC
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_dispatch_score(
    DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT[],
    NUMERIC, INTEGER, NUMERIC
) TO postgres, service_role;

-- ----------------------------------------------------------------------------
-- 5. Vehicle-aware eligible mechanic discovery.
-- ST_DWithin on geography uses meters and can use the GiST spatial index.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.find_eligible_mechanics(
    GEOGRAPHY, DOUBLE PRECISION, TEXT, TEXT
);

CREATE FUNCTION public.find_eligible_mechanics(
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
BEGIN
    IF p_breakdown_location IS NULL THEN
        RAISE EXCEPTION 'Breakdown location is required.';
    END IF;

    IF p_vehicle_type IS NULL OR p_vehicle_type NOT IN (
        'Passenger Car', 'Motorcycle', 'Light Commercial'
    ) THEN
        RAISE EXCEPTION 'A valid ROADIX vehicle class is required.';
    END IF;

    v_radius := LEAST(
        GREATEST(COALESCE(p_radius_meters, 5000), 5000),
        15000
    );

    RETURN QUERY
    SELECT
        m.profile_id,
        m.workshop_name,
        ST_Distance(m.current_location, p_breakdown_location),
        COALESCE(rv.average_rating, 3.00)::NUMERIC,
        m.total_rescues,
        m.specializations,
        public.calculate_dispatch_score(
            ST_Distance(m.current_location, p_breakdown_location),
            v_radius,
            p_vehicle_type,
            m.vehicle_specializations,
            rv.average_rating,
            COALESCE(rv.review_count, 0)::INTEGER,
            CASE
                WHEN op.total_decided_offers = 0 THEN 50
                ELSE
                    (op.accepted_offers::NUMERIC / op.total_decided_offers) * 100
            END
        )::NUMERIC(5,2)
    FROM public.mechanic_profiles AS m
    JOIN public.profiles AS p
      ON p.id = m.profile_id

    LEFT JOIN LATERAL (
        SELECT
            AVG(r.rating)::NUMERIC AS average_rating,
            COUNT(*)::BIGINT AS review_count
        FROM public.reviews AS r
        WHERE r.mechanic_id = m.profile_id
    ) AS rv ON TRUE

    LEFT JOIN LATERAL (
        SELECT
            COUNT(*) FILTER (WHERE o.status = 'accepted')::BIGINT
                AS accepted_offers,
            COUNT(*) FILTER (
                WHERE o.status IN ('accepted', 'rejected', 'timed_out')
            )::BIGINT AS total_decided_offers
        FROM public.dispatch_offers AS o
        WHERE o.mechanic_id = m.profile_id
    ) AS op ON TRUE

    WHERE p.role = 'mechanic'
      AND m.is_on_duty = TRUE
      AND m.is_verified = TRUE
      AND m.current_location IS NOT NULL
      AND ST_DWithin(
          m.current_location,
          p_breakdown_location,
          v_radius
      )
      AND NOT EXISTS (
          SELECT 1
          FROM public.service_requests AS active_sr
          WHERE active_sr.mechanic_id = m.profile_id
            AND active_sr.status IN (
                'assigned', 'en_route', 'arrived', 'diagnosing',
                'quote_pending', 'servicing'
            )
      )

    -- Vehicle fit and overall score first; fault fit is a tie-breaker.
    ORDER BY
        7 DESC,
        (p_fault_type = ANY(m.specializations)) DESC,
        3 ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.find_eligible_mechanics(
    GEOGRAPHY, DOUBLE PRECISION, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.find_eligible_mechanics(
    GEOGRAPHY, DOUBLE PRECISION, TEXT, TEXT
) TO postgres, service_role;

-- ----------------------------------------------------------------------------
-- 6. Update every caller to pass the vehicle class from vehicle_snapshot.
-- ----------------------------------------------------------------------------
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

    IF v_user <> v_req.motorist_id AND NOT public.is_admin() THEN
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

    v_vehicle_type :=
        public.roadix_vehicle_type_from_snapshot(v_req.vehicle_snapshot);

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

    IF v_user <> v_req.motorist_id AND NOT public.is_admin() THEN
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

    v_vehicle_type :=
        public.roadix_vehicle_type_from_snapshot(v_req.vehicle_snapshot);

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
        RAISE EXCEPTION
            'Cannot expand: % eligible mechanic(s) have not yet received an offer.',
            v_unoffered;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.dispatch_offers o
        WHERE o.request_id = p_request_id
          AND o.status NOT IN ('timed_out', 'rejected', 'cancelled')
    ) THEN
        RAISE EXCEPTION
            'All previous offers must be rejected, timed out, or cancelled before expansion.';
    END IF;

    v_new_radius := LEAST(v_req.search_radius_km + 2.50, 15.00);

    PERFORM set_config(
        'roadix.internal_dispatch_caller',
        'expand_dispatch_radius',
        TRUE
    );

    UPDATE public.service_requests
    SET search_radius_km = v_new_radius,
        updated_at = now()
    WHERE id = p_request_id;

    RETURN v_new_radius;
END;
$$;

CREATE OR REPLACE FUNCTION public.find_eligible_mechanics_for_request(
    p_request_id UUID
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
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_req RECORD;
    v_user UUID := auth.uid();
    v_vehicle_type TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT id, motorist_id, breakdown_location, search_radius_km,
           fault_type, vehicle_snapshot, status
    INTO v_req
    FROM public.service_requests
    WHERE id = p_request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service request not found.';
    END IF;

    IF v_user <> v_req.motorist_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Not authorized to discover mechanics for this request.';
    END IF;

    IF v_req.status <> 'searching' THEN
        RAISE EXCEPTION
            'Mechanic discovery is available only while the request is searching.';
    END IF;

    v_vehicle_type :=
        public.roadix_vehicle_type_from_snapshot(v_req.vehicle_snapshot);

    RETURN QUERY
    SELECT *
    FROM public.find_eligible_mechanics(
        v_req.breakdown_location,
        v_req.search_radius_km * 1000.0,
        v_req.fault_type,
        v_vehicle_type
    );
END;
$$;

REVOKE ALL ON FUNCTION public.dispatch_next_candidate(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.dispatch_next_candidate(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.expand_dispatch_radius(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.expand_dispatch_radius(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.find_eligible_mechanics_for_request(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.find_eligible_mechanics_for_request(UUID) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 7. Remove obsolete overloads so no caller can silently keep using the old
-- fault-only scoring path.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.find_eligible_mechanics(
    GEOGRAPHY, DOUBLE PRECISION, TEXT
);

DROP FUNCTION IF EXISTS public.calculate_dispatch_score(
    DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT[], NUMERIC, INTEGER
);

COMMIT;

-- ============================================================================
-- POST-APPLY CHECKS (run separately in pgAdmin)
-- ============================================================================
-- 1) Only the new four-argument discovery function should remain:
-- SELECT p.oid::regprocedure
-- FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public'
--   AND p.proname = 'find_eligible_mechanics';
--
-- 2) Confirm mechanic vehicle specializations:
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name = 'mechanic_profiles'
--   AND column_name = 'vehicle_specializations';
--
-- 3) Confirm saved-vehicle classes:
-- SELECT DISTINCT type FROM public.vehicles ORDER BY type;
--
-- 4) Confirm all three dispatch callers use the vehicle-aware discovery
--    function by inspecting their definitions:
-- SELECT pg_get_functiondef('public.dispatch_next_candidate(uuid)'::regprocedure);
-- SELECT pg_get_functiondef('public.expand_dispatch_radius(uuid)'::regprocedure);
-- SELECT pg_get_functiondef('public.find_eligible_mechanics_for_request(uuid)'::regprocedure);
