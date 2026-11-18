-- ============================================================================
-- ROADIX MIGRATION 04 (REVISED): Stored Procedures, Spatial Discovery & Dispatch
-- Requires Migrations 01-03. Supabase Auth environment required for deployment.
-- Native PostgreSQL test setup: run ROADIX_LOCAL_AUTH_COMPATIBILITY.sql first.
-- ============================================================================

-- Remove public execution defaults from all functions created below.
-- Explicit signatures are used in the privilege section at the end.

-- ----------------------------------------------------------------------------
-- 1. Dispatch scoring (internal helper)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_dispatch_score(
    p_distance_meters DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION,
    p_fault_type TEXT,
    p_specializations TEXT[],
    p_rating NUMERIC,
    p_total_rescues INTEGER
)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    v_proximity NUMERIC;
    v_specialization NUMERIC;
    v_trust NUMERIC;
    v_effective_rating NUMERIC;
BEGIN
    v_proximity := CASE
        WHEN p_radius_meters IS NULL OR p_radius_meters <= 0 THEN 0
        ELSE GREATEST(0, (1 - p_distance_meters / p_radius_meters) * 100)
    END;

    IF COALESCE(p_fault_type = ANY(p_specializations), FALSE) THEN
        v_specialization := 100;
    ELSIF COALESCE('General Automotive Breakdown' = ANY(p_specializations), FALSE)
       OR COALESCE('General' = ANY(p_specializations), FALSE) THEN
        v_specialization := 50;
    ELSE
        v_specialization := 10;
    END IF;

    v_effective_rating := CASE
        WHEN COALESCE(p_total_rescues, 0) < 5 THEN 4.50
        ELSE COALESCE(p_rating, 4.50)
    END;
    v_trust := GREATEST(0, LEAST(100, ((v_effective_rating - 1) / 4) * 100));

    -- The SRS baseline currently assigns 85/100 to availability.
    RETURN ROUND(
        (0.40 * v_proximity) +
        (0.25 * v_specialization) +
        (0.15 * v_trust) +
        (0.20 * 85.0),
        2
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. Internal mechanic discovery. Busy mechanics are excluded.
-- Does not expose phone numbers, exact locations, or verification documents.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.find_eligible_mechanics(
    p_breakdown_location GEOGRAPHY,
    p_radius_meters DOUBLE PRECISION,
    p_fault_type TEXT
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

    v_radius := LEAST(GREATEST(COALESCE(p_radius_meters, 5000), 5000), 15000);

    RETURN QUERY
    SELECT
        m.profile_id,
        m.workshop_name,
        ST_Distance(m.current_location, p_breakdown_location),
        m.rating,
        m.total_rescues,
        m.specializations,
        public.calculate_dispatch_score(
            ST_Distance(m.current_location, p_breakdown_location),
            v_radius,
            p_fault_type,
            m.specializations,
            m.rating,
            m.total_rescues
        )
    FROM public.mechanic_profiles AS m
    JOIN public.profiles AS p ON p.id = m.profile_id
    WHERE p.role = 'mechanic'
      AND m.is_on_duty
      AND m.is_verified
      AND m.current_location IS NOT NULL
      AND ST_DWithin(m.current_location, p_breakdown_location, v_radius)
      AND NOT EXISTS (
          SELECT 1
          FROM public.service_requests AS active_sr
          WHERE active_sr.mechanic_id = m.profile_id
            AND active_sr.status IN (
                'assigned','en_route','arrived','diagnosing','quote_pending','servicing'
            )
      )
    ORDER BY 7 DESC, 3 ASC;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. Create service request. Clients must use this RPC; direct INSERT is revoked
-- in Migration 05. Request-code collisions are retried safely.
-- ----------------------------------------------------------------------------
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
    v_id UUID;
    v_code TEXT;
    v_result JSONB;
    v_attempt INTEGER := 0;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_breakdown_lat IS NULL OR p_breakdown_lng IS NULL
       OR p_breakdown_lat NOT BETWEEN -90 AND 90
       OR p_breakdown_lng NOT BETWEEN -180 AND 180 THEN
        RAISE EXCEPTION 'Invalid GPS coordinates.';
    END IF;

    IF p_fault_type IS NULL OR btrim(p_fault_type) = '' THEN
        RAISE EXCEPTION 'A fault category is required.';
    END IF;

    IF p_breakdown_address IS NULL OR btrim(p_breakdown_address) = '' THEN
        RAISE EXCEPTION 'A breakdown address is required.';
    END IF;

    IF jsonb_typeof(COALESCE(p_vehicle_snapshot, '{}'::jsonb)) <> 'object' THEN
        RAISE EXCEPTION 'Vehicle snapshot must be a JSON object.';
    END IF;

    IF COALESCE(array_length(p_photo_urls, 1), 0) > 3 THEN
        RAISE EXCEPTION 'A maximum of three diagnostic photos is allowed.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = v_user AND p.role = 'motorist'
    ) THEN
        RAISE EXCEPTION 'Only a motorist account can create a service request.';
    END IF;

    LOOP
        v_attempt := v_attempt + 1;
        IF v_attempt > 10 THEN
            RAISE EXCEPTION 'Could not allocate a unique request code. Please retry.';
        END IF;

        v_code := 'RDX-' || to_char(now(), 'YYYY') || '-' ||
                  lpad((floor(random() * 90000) + 10000)::INTEGER::TEXT, 5, '0');

        BEGIN
            INSERT INTO public.service_requests (
                request_code, motorist_id, breakdown_location, breakdown_address,
                vehicle_snapshot, fault_type, symptoms, diagnostic_notes,
                photo_urls, is_high_priority, status, search_radius_km
            )
            VALUES (
                v_code, v_user,
                ST_SetSRID(ST_MakePoint(p_breakdown_lng, p_breakdown_lat), 4326)::GEOGRAPHY,
                btrim(p_breakdown_address),
                COALESCE(p_vehicle_snapshot, '{}'::jsonb),
                btrim(p_fault_type),
                COALESCE(p_symptoms, '{}'::TEXT[]),
                NULLIF(btrim(p_diagnostic_notes), ''),
                COALESCE(p_photo_urls, '{}'::TEXT[]),
                COALESCE(p_is_high_priority, FALSE),
                'searching', 5.00
            )
            RETURNING id INTO v_id;

            EXIT;
        EXCEPTION WHEN unique_violation THEN
            -- Retry only the generated human-readable code collision.
            IF EXISTS (SELECT 1 FROM public.service_requests WHERE request_code = v_code) THEN
                CONTINUE;
            END IF;
            RAISE;
        END;
    END LOOP;

    SELECT jsonb_build_object(
        'id', sr.id,
        'request_code', sr.request_code,
        'status', sr.status,
        'created_at', sr.created_at,
        'search_radius_km', sr.search_radius_km
    )
    INTO v_result
    FROM public.service_requests sr
    WHERE sr.id = v_id;

    RETURN v_result;
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. Accept a dispatch offer. Mechanic-row lock serializes acceptance attempts
-- by the same mechanic; request-row lock serializes competing mechanics.
-- Invalid/expired offers return FALSE so their status updates are not rolled back.
-- ----------------------------------------------------------------------------
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
    v_request RECORD;
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

    IF EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.mechanic_id = v_user
          AND sr.status IN ('assigned','en_route','arrived','diagnosing','quote_pending','servicing')
    ) THEN
        RAISE EXCEPTION 'Mechanic already has an active service assignment.';
    END IF;

    -- Check the offer/request relationship before locking the request.
    SELECT id, request_id, mechanic_id, status, expires_at
    INTO v_offer
    FROM public.dispatch_offers
    WHERE id = p_offer_id AND mechanic_id = v_user
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Offer not found or not addressed to this mechanic.';
    END IF;

    IF v_offer.request_id <> p_request_id THEN
        RAISE EXCEPTION 'The supplied offer does not belong to the supplied request.';
    END IF;

    IF v_offer.status <> 'offered' THEN
        RETURN FALSE;
    END IF;

    IF v_offer.expires_at <= now() THEN
        UPDATE public.dispatch_offers
        SET status = 'timed_out', responded_at = now()
        WHERE id = p_offer_id AND status = 'offered';
        RETURN FALSE;
    END IF;

    SELECT id, status
    INTO v_request
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND OR v_request.status <> 'searching' THEN
        UPDATE public.dispatch_offers
        SET status = 'cancelled', responded_at = now()
        WHERE id = p_offer_id AND status = 'offered';
        RETURN FALSE;
    END IF;

    PERFORM set_config('roadix.internal_dispatch_caller', 'accept_dispatch_offer', TRUE);

    BEGIN
        UPDATE public.service_requests
        SET mechanic_id = v_user,
            status = 'assigned',
            assigned_at = now(),
            updated_at = now()
        WHERE id = p_request_id AND status = 'searching';

        IF NOT FOUND THEN
            UPDATE public.dispatch_offers
            SET status = 'cancelled', responded_at = now()
            WHERE id = p_offer_id AND status = 'offered';
            RETURN FALSE;
        END IF;
    EXCEPTION WHEN unique_violation THEN
        -- The partial unique index is the final concurrency safeguard.
        UPDATE public.dispatch_offers
        SET status = 'cancelled', responded_at = now()
        WHERE id = p_offer_id AND status = 'offered';
        RETURN FALSE;
    END;

    UPDATE public.dispatch_offers
    SET status = 'accepted', responded_at = now()
    WHERE id = p_offer_id;

    UPDATE public.dispatch_offers
    SET status = 'cancelled', responded_at = now()
    WHERE request_id = p_request_id
      AND id <> p_offer_id
      AND status = 'offered';

    RETURN TRUE;
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. Reject a dispatch offer. Direct table updates are revoked in Migration 05.
-- ----------------------------------------------------------------------------
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

    IF v_offer.expires_at <= now() THEN
        UPDATE public.dispatch_offers
        SET status = 'timed_out', responded_at = now()
        WHERE id = p_offer_id;
        RETURN FALSE;
    END IF;

    UPDATE public.dispatch_offers
    SET status = 'rejected', responded_at = now()
    WHERE id = p_offer_id;

    RETURN TRUE;
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. Verified mechanic telemetry. Direct location updates are revoked in M05.
-- ----------------------------------------------------------------------------
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

    IF p_lat IS NULL OR p_lng IS NULL
       OR p_lat NOT BETWEEN -90 AND 90
       OR p_lng NOT BETWEEN -180 AND 180 THEN
        RAISE EXCEPTION 'Invalid latitude/longitude.';
    END IF;

    UPDATE public.mechanic_profiles
    SET current_location = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::GEOGRAPHY,
        updated_at = now()
    WHERE profile_id = v_user
      AND is_verified = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'A verified mechanic profile is required for location telemetry.';
    END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. Supabase Auth trigger: create motorist profile on account creation.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, phone, role, is_anonymous)
    VALUES (
        NEW.id,
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), 'ROADIX Motorist'),
        NEW.phone,
        'motorist',
        COALESCE((NEW.raw_user_meta_data->>'is_anonymous')::BOOLEAN, FALSE)
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 8. Sequential candidate dispatch. One active offer per request at a time.
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
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT id, motorist_id, breakdown_location, search_radius_km, fault_type, status
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
        SELECT 1 FROM public.dispatch_offers o
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

    SELECT c.*
    INTO v_candidate
    FROM public.find_eligible_mechanics(
        v_req.breakdown_location,
        v_req.search_radius_km * 1000.0,
        v_req.fault_type
    ) AS c
    WHERE NOT EXISTS (
        SELECT 1 FROM public.dispatch_offers o
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

-- ----------------------------------------------------------------------------
-- 9. Expand radius only after all current-radius candidates were offered and
-- every offer is terminal. The trigger in Migration 05 validates the token.
-- ----------------------------------------------------------------------------
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
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT id, motorist_id, breakdown_location, search_radius_km, fault_type, status
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
        SELECT 1 FROM public.dispatch_offers o
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

    SELECT count(*) INTO v_unoffered
    FROM public.find_eligible_mechanics(
        v_req.breakdown_location,
        v_req.search_radius_km * 1000.0,
        v_req.fault_type
    ) c
    WHERE NOT EXISTS (
        SELECT 1 FROM public.dispatch_offers o
        WHERE o.request_id = p_request_id
          AND o.mechanic_id = c.mechanic_id
    );

    IF v_unoffered > 0 THEN
        RAISE EXCEPTION 'Cannot expand: % eligible mechanic(s) have not yet received an offer.', v_unoffered;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.dispatch_offers o
        WHERE o.request_id = p_request_id
          AND o.status NOT IN ('timed_out','rejected','cancelled')
    ) THEN
        RAISE EXCEPTION 'All previous offers must be rejected, timed out, or cancelled before expansion.';
    END IF;

    v_new_radius := LEAST(v_req.search_radius_km + 2.50, 15.00);

    PERFORM set_config('roadix.internal_dispatch_caller', 'expand_dispatch_radius', TRUE);

    UPDATE public.service_requests
    SET search_radius_km = v_new_radius,
        updated_at = now()
    WHERE id = p_request_id;

    RETURN v_new_radius;
END;
$$;

-- ----------------------------------------------------------------------------
-- 10. Safe client-facing discovery RPC. SECURITY DEFINER bypasses mechanic RLS,
-- but returns only non-sensitive workshop and suitability fields.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.find_eligible_mechanics_for_request(p_request_id UUID)
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
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT id, motorist_id, breakdown_location, search_radius_km, fault_type, status
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
        RAISE EXCEPTION 'Mechanic discovery is available only while the request is searching.';
    END IF;

    RETURN QUERY
    SELECT * FROM public.find_eligible_mechanics(
        v_req.breakdown_location,
        v_req.search_radius_km * 1000.0,
        v_req.fault_type
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 11. Mechanic submits a quotation. The request row is locked; the assigned
-- mechanic is verified; pending previous quotation is superseded atomically.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_quotation(
    p_request_id UUID,
    p_inspection_fee NUMERIC,
    p_labor_fee NUMERIC,
    p_parts_fee NUMERIC DEFAULT 0,
    p_parts_breakdown JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_req RECORD;
    v_revision INTEGER;
    v_quote_id UUID;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_inspection_fee IS NULL OR p_labor_fee IS NULL OR p_parts_fee IS NULL
       OR p_inspection_fee < 0 OR p_labor_fee < 0 OR p_parts_fee < 0 THEN
        RAISE EXCEPTION 'Quotation fees must be non-negative values.';
    END IF;

    IF jsonb_typeof(COALESCE(p_parts_breakdown, '[]'::JSONB)) <> 'array' THEN
        RAISE EXCEPTION 'Parts breakdown must be a JSON array.';
    END IF;

    SELECT id, mechanic_id, status
    INTO v_req
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service request not found.';
    END IF;

    IF v_req.mechanic_id <> v_user OR v_req.status <> 'diagnosing' THEN
        RAISE EXCEPTION 'Only the assigned mechanic can submit a quotation while diagnosing.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.mechanic_profiles mp
        WHERE mp.profile_id = v_user AND mp.is_verified
    ) THEN
        RAISE EXCEPTION 'Verified mechanic profile required.';
    END IF;

    UPDATE public.quotations
    SET status = 'superseded'
    WHERE request_id = p_request_id AND status = 'pending';

    SELECT COALESCE(MAX(q.revision), 0) + 1
    INTO v_revision
    FROM public.quotations q
    WHERE q.request_id = p_request_id;

    INSERT INTO public.quotations (
        request_id, mechanic_id, revision,
        inspection_fee, labor_fee, parts_fee, parts_breakdown, status
    )
    VALUES (
        p_request_id, v_user, v_revision,
        p_inspection_fee, p_labor_fee, p_parts_fee,
        COALESCE(p_parts_breakdown, '[]'::JSONB), 'pending'
    )
    RETURNING id INTO v_quote_id;

    UPDATE public.service_requests
    SET status = 'quote_pending', updated_at = now()
    WHERE id = p_request_id;

    RETURN (
        SELECT jsonb_build_object(
            'quotation_id', q.id,
            'request_id', q.request_id,
            'revision', q.revision,
            'inspection_fee', q.inspection_fee,
            'labor_fee', q.labor_fee,
            'parts_fee', q.parts_fee,
            'total_amount', q.total_amount,
            'parts_breakdown', q.parts_breakdown,
            'status', q.status
        )
        FROM public.quotations q WHERE q.id = v_quote_id
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 12. Motorist quotation response. The parent request must be quote_pending
-- and the quotation must belong to its currently assigned mechanic.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_to_quotation(
    p_quotation_id UUID,
    p_decision TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_quote RECORD;
    v_req RECORD;
    v_now TIMESTAMPTZ := now();
    v_new_request_status TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_decision IS NULL OR p_decision NOT IN ('approved','rejected') THEN
        RAISE EXCEPTION 'Decision must be approved or rejected.';
    END IF;

    SELECT * INTO v_quote
    FROM public.quotations
    WHERE id = p_quotation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quotation not found.';
    END IF;

    SELECT * INTO v_req
    FROM public.service_requests
    WHERE id = v_quote.request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Parent service request not found.';
    END IF;

    IF v_req.motorist_id <> v_user THEN
        RAISE EXCEPTION 'Only the requesting motorist can respond to this quotation.';
    END IF;

    IF v_req.status <> 'quote_pending'
       OR v_req.mechanic_id IS DISTINCT FROM v_quote.mechanic_id
       OR v_quote.status <> 'pending' THEN
        RAISE EXCEPTION 'Quotation is not the active pending quotation for this request.';
    END IF;

    UPDATE public.quotations
    SET status = p_decision, responded_at = v_now
    WHERE id = p_quotation_id;

    v_new_request_status := CASE
        WHEN p_decision = 'approved' THEN 'servicing'
        ELSE 'diagnosing'
    END;

    PERFORM set_config('roadix.internal_quotation_caller', 'respond_to_quotation', TRUE);

    UPDATE public.service_requests
    SET status = v_new_request_status, updated_at = v_now
    WHERE id = v_quote.request_id;

    RETURN jsonb_build_object(
        'quotation_id', p_quotation_id,
        'status', p_decision,
        'responded_at', v_now,
        'service_request_status', v_new_request_status
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 13. Administrator role management. Live app_metadata is updated and refresh
-- tokens are invalidated on demotion. Supabase Auth schema is required.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_user_role(
    p_target_user_id UUID,
    p_new_role TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_admin UUID := auth.uid();
BEGIN
    IF v_admin IS NULL OR NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only an authenticated platform administrator can change roles.';
    END IF;

    IF p_new_role IS NULL OR p_new_role NOT IN ('motorist','mechanic','admin') THEN
        RAISE EXCEPTION 'Role must be motorist, mechanic, or admin.';
    END IF;

    UPDATE auth.users
    SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::JSONB)
                            || jsonb_build_object('user_role', p_new_role),
        updated_at = now()
    WHERE id = p_target_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Target Auth user does not exist.';
    END IF;

    UPDATE public.profiles
    SET role = p_new_role, updated_at = now()
    WHERE id = p_target_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Target profile does not exist; transaction rolled back.';
    END IF;

    IF p_new_role <> 'admin' THEN
        DELETE FROM auth.refresh_tokens WHERE user_id = p_target_user_id;
    END IF;

    INSERT INTO public.admin_audit_logs (
        admin_id, action, target_entity, target_id, metadata
    )
    VALUES (
        v_admin, 'SET_USER_ROLE', 'profiles', p_target_user_id,
        jsonb_build_object('new_role', p_new_role)
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 14. Administrator mechanic-verification review. Clients cannot set verified
-- fields directly; this function updates the verification record and profile.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.review_mechanic_verification(
    p_mechanic_id UUID,
    p_approved BOOLEAN,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin UUID := auth.uid();
BEGIN
    IF v_admin IS NULL OR NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators can review mechanic verification.';
    END IF;

    IF p_approved IS NULL OR p_reason IS NULL OR btrim(p_reason) = '' THEN
        RAISE EXCEPTION 'Approval decision and review reason are required.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.mechanic_profiles mp
        WHERE mp.profile_id = p_mechanic_id
    ) THEN
        RAISE EXCEPTION 'Mechanic profile not found.';
    END IF;

    UPDATE public.mechanic_verifications
    SET verified_at = CASE WHEN p_approved THEN now() ELSE NULL END,
        verified_by = v_admin,
        updated_at = now()
    WHERE profile_id = p_mechanic_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Mechanic verification documents have not been submitted.';
    END IF;

    UPDATE public.mechanic_profiles
    SET is_verified = p_approved,
        is_on_duty = CASE WHEN p_approved THEN is_on_duty ELSE FALSE END,
        updated_at = now()
    WHERE profile_id = p_mechanic_id;

    UPDATE public.profiles
    SET is_nid_verified = p_approved, updated_at = now()
    WHERE id = p_mechanic_id;

    INSERT INTO public.admin_audit_logs (
        admin_id, action, target_entity, target_id, metadata
    )
    VALUES (
        v_admin, 'REVIEW_MECHANIC_VERIFICATION', 'mechanic_profiles',
        p_mechanic_id,
        jsonb_build_object('approved', p_approved, 'reason', p_reason)
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 15. Auditable administrative service-request override.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_override_service_request(
    p_request_id UUID,
    p_action TEXT,
    p_reason TEXT,
    p_metadata JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin UUID := auth.uid();
    v_req RECORD;
    v_new_status TEXT;
    v_now TIMESTAMPTZ := now();
BEGIN
    IF v_admin IS NULL OR NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators can override service requests.';
    END IF;

    IF p_reason IS NULL OR btrim(p_reason) = '' THEN
        RAISE EXCEPTION 'A non-empty audit reason is required.';
    END IF;

    IF p_action IS NULL OR p_action NOT IN (
        'cancel_request','force_complete','reassign_searching'
    ) THEN
        RAISE EXCEPTION 'Unsupported administrative action.';
    END IF;

    SELECT * INTO v_req
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service request not found.';
    END IF;

    IF v_req.status IN ('completed','cancelled') THEN
        RAISE EXCEPTION 'Terminal requests cannot be overridden.';
    END IF;

    PERFORM set_config('roadix.internal_admin_caller', 'admin_override_service_request', TRUE);

    IF p_action = 'cancel_request' THEN
        v_new_status := 'cancelled';
        UPDATE public.service_requests
        SET status = 'cancelled',
            cancellation_reason = 'Admin override: ' || btrim(p_reason),
            cancelled_at = v_now,
            updated_at = v_now
        WHERE id = p_request_id;

        UPDATE public.dispatch_offers
        SET status = 'cancelled', responded_at = v_now
        WHERE request_id = p_request_id AND status = 'offered';

    ELSIF p_action = 'force_complete' THEN
        IF v_req.status NOT IN (
            'assigned','en_route','arrived','diagnosing','quote_pending','servicing'
        ) THEN
            RAISE EXCEPTION 'Only an in-progress request can be force-completed.';
        END IF;

        v_new_status := 'completed';
        UPDATE public.service_requests
        SET status = 'completed', completed_at = v_now, updated_at = v_now
        WHERE id = p_request_id;

    ELSE
        IF v_req.status NOT IN (
            'assigned','en_route','arrived','diagnosing','quote_pending'
        ) THEN
            RAISE EXCEPTION 'This request state cannot be returned to searching.';
        END IF;

        v_new_status := 'searching';
        UPDATE public.service_requests
        SET status = 'searching',
            mechanic_id = NULL,
            assigned_at = NULL,
            arrived_at = NULL,
            updated_at = v_now
        WHERE id = p_request_id;

        UPDATE public.dispatch_offers
        SET status = 'cancelled', responded_at = v_now
        WHERE request_id = p_request_id AND status = 'offered';
    END IF;

    INSERT INTO public.admin_audit_logs (
        admin_id, action, target_entity, target_id, metadata
    )
    VALUES (
        v_admin, 'ADMIN_OVERRIDE_' || upper(p_action),
        'service_requests', p_request_id,
        jsonb_build_object(
            'reason', btrim(p_reason),
            'previous_status', v_req.status,
            'new_status', v_new_status,
            'previous_mechanic_id', v_req.mechanic_id,
            'custom_metadata', COALESCE(p_metadata, '{}'::JSONB)
        )
    );

    RETURN jsonb_build_object(
        'request_id', p_request_id,
        'action', p_action,
        'previous_status', v_req.status,
        'new_status', v_new_status,
        'admin_id', v_admin,
        'overridden_at', v_now
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 16. Least-privilege function execution grants (full signatures required).
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.calculate_dispatch_score(DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT[], NUMERIC, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.find_eligible_mechanics(GEOGRAPHY, DOUBLE PRECISION, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_service_request(DOUBLE PRECISION, DOUBLE PRECISION, TEXT, JSONB, TEXT, TEXT[], TEXT, TEXT[], BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.accept_dispatch_offer(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_dispatch_offer(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_mechanic_location(DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.dispatch_next_candidate(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.expand_dispatch_radius(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.find_eligible_mechanics_for_request(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_quotation(UUID, NUMERIC, NUMERIC, NUMERIC, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.respond_to_quotation(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_user_role(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.review_mechanic_verification(UUID, BOOLEAN, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_override_service_request(UUID, TEXT, TEXT, JSONB) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.calculate_dispatch_score(DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT[], NUMERIC, INTEGER) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION public.find_eligible_mechanics(GEOGRAPHY, DOUBLE PRECISION, TEXT) TO postgres, service_role;

GRANT EXECUTE ON FUNCTION public.create_service_request(DOUBLE PRECISION, DOUBLE PRECISION, TEXT, JSONB, TEXT, TEXT[], TEXT, TEXT[], BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.accept_dispatch_offer(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reject_dispatch_offer(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_mechanic_location(DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.dispatch_next_candidate(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.expand_dispatch_radius(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.find_eligible_mechanics_for_request(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_quotation(UUID, NUMERIC, NUMERIC, NUMERIC, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.respond_to_quotation(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_user_role(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.review_mechanic_verification(UUID, BOOLEAN, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_override_service_request(UUID, TEXT, TEXT, JSONB) TO authenticated, service_role;
