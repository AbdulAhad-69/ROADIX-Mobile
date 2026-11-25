-- ============================================================================
-- ROADIX Migration 09: Security Hardening, RLS Convergence & Contract Fixes
-- ============================================================================
-- Targets: remote PostgreSQL / Supabase (Post-08 live state) AND clean local
-- replay. Preserves existing data while closing all anon/authenticated RLS
-- and SECURITY DEFINER escalation paths, adding storage.objects policies,
-- restoring state-machine/scoring/review triggers, and seeding rate cards.
-- ============================================================================

-- 1. Drop unsafe legacy / overloaded RPCs discovered on remote (never called by app)
DROP FUNCTION IF EXISTS public.accept_dispatch_offer(UUID, UUID, UUID);
DROP FUNCTION IF EXISTS public.submit_quotation(UUID, NUMERIC, NUMERIC, NUMERIC, JSONB, UUID);
DROP FUNCTION IF EXISTS public.respond_to_quotation(UUID, TEXT, UUID);
DROP FUNCTION IF EXISTS public.respond_to_dispatch_offer(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.update_mechanic_job_progress(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.submit_mechanic_quote(UUID, UUID, NUMERIC, NUMERIC, NUMERIC, JSONB);
DROP FUNCTION IF EXISTS public.respond_to_quote(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_get_active_dispatches();
DROP FUNCTION IF EXISTS public.admin_get_audit_logs();
DROP FUNCTION IF EXISTS public.admin_get_mechanics_review_queue();
DROP FUNCTION IF EXISTS public.admin_verify_mechanic(UUID, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.create_guest_sos_request(TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT, TEXT);

-- 2. Normalize relational constraints & columns without touching existing data
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.wallets'::regclass AND conname = 'wallets_provider_check'
    ) THEN
        ALTER TABLE public.wallets
            ADD CONSTRAINT wallets_provider_check
            CHECK (provider IN ('bKash', 'Nagad', 'Rocket', 'Upay', 'NexusPay', 'Ucash'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.vehicles'::regclass AND conname = 'vehicles_type_check'
    ) THEN
        ALTER TABLE public.vehicles
            ADD CONSTRAINT vehicles_type_check
            CHECK (type IN ('Passenger Car', 'Motorcycle', 'Light Commercial'));
    END IF;
END $$;

ALTER TABLE public.dispatch_offers
    DROP CONSTRAINT IF EXISTS uq_request_mechanic;

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_offer_per_mechanic
    ON public.dispatch_offers (request_id, mechanic_id)
    WHERE status = 'offered';

CREATE UNIQUE INDEX IF NOT EXISTS uq_mechanic_single_active_request
    ON public.service_requests (mechanic_id)
    WHERE mechanic_id IS NOT NULL
      AND status IN ('assigned', 'en_route', 'arrived', 'diagnosing', 'quote_pending', 'servicing');

CREATE UNIQUE INDEX IF NOT EXISTS uq_wallets_single_primary_per_profile
    ON public.wallets (profile_id)
    WHERE is_primary = TRUE;

-- Keep emergency_contacts relation <-> relationship bidirectional in sync
UPDATE public.emergency_contacts
SET relationship = COALESCE(NULLIF(btrim(relationship), ''), relation),
    relation     = COALESCE(NULLIF(btrim(relation), ''), NULLIF(btrim(relationship), ''), 'Family')
WHERE relationship IS NULL OR btrim(relationship) = '' OR relation IS NULL OR btrim(relation) = '';

CREATE OR REPLACE FUNCTION public.sync_emergency_contact_relation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.relationship IS NOT NULL AND btrim(NEW.relationship) <> '' THEN
        NEW.relationship := btrim(NEW.relationship);
        NEW.relation := COALESCE(NULLIF(btrim(NEW.relation), ''), NEW.relationship);
        IF TG_OP = 'UPDATE' AND NEW.relationship IS DISTINCT FROM OLD.relationship THEN
            NEW.relation := NEW.relationship;
        END IF;
    END IF;
    IF NEW.relation IS NOT NULL AND btrim(NEW.relation) <> '' THEN
        NEW.relation := btrim(NEW.relation);
        IF NEW.relationship IS NULL OR btrim(NEW.relationship) = '' OR (TG_OP = 'UPDATE' AND NEW.relation IS DISTINCT FROM OLD.relation AND NEW.relationship IS NOT DISTINCT FROM OLD.relationship) THEN
            NEW.relationship := NEW.relation;
        END IF;
    END IF;
    NEW.relation := COALESCE(NULLIF(btrim(NEW.relation), ''), 'Family');
    NEW.relationship := COALESCE(NULLIF(btrim(NEW.relationship), ''), NEW.relation);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_emergency_contact_relation ON public.emergency_contacts;
CREATE TRIGGER trg_sync_emergency_contact_relation
BEFORE INSERT OR UPDATE ON public.emergency_contacts
FOR EACH ROW EXECUTE FUNCTION public.sync_emergency_contact_relation();

-- 3. Authoritative admin helper & counterparty helper (non-recursive)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_uid UUID := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    IF (auth.jwt() -> 'app_metadata' ->> 'user_role') = 'admin'
       OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin' THEN
        RETURN TRUE;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM auth.users u
        WHERE u.id = v_uid
          AND (
              (u.raw_app_meta_data ->> 'user_role') = 'admin'
              OR (u.raw_app_meta_data ->> 'role') = 'admin'
          )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.is_service_counterparty(p_counterparty_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID := auth.uid();
BEGIN
    IF v_uid IS NULL OR p_counterparty_id IS NULL OR v_uid = p_counterparty_id THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.service_requests sr
        WHERE (
            (sr.motorist_id = v_uid AND sr.mechanic_id = p_counterparty_id)
            OR (sr.mechanic_id = v_uid AND sr.motorist_id = p_counterparty_id)
        )
          AND sr.status IN (
              'assigned', 'en_route', 'arrived', 'diagnosing',
              'quote_pending', 'servicing', 'completed'
          )
    );
END;
$$;

-- 4. Drop ALL public policies cleanly & rebuild least-privilege RLS + column grants
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', pol.policyname, pol.tablename);
    END LOOP;
END $$;

DO $$
DECLARE
    tbl TEXT;
    all_tables TEXT[] := ARRAY[
        'profiles', 'mechanic_profiles', 'mechanic_verifications',
        'vehicles', 'emergency_contacts', 'wallets', 'rescue_tickets',
        'service_requests', 'dispatch_offers', 'quotations',
        'transactions', 'reviews', 'standard_rate_cards', 'admin_audit_logs'
    ];
BEGIN
    FOREACH tbl IN ARRAY all_tables LOOP
        IF to_regclass('public.' || tbl) IS NOT NULL THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
            EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated;', tbl);
        END IF;
    END LOOP;
END $$;

-- 4.1 PROFILES (role / NID / is_active protected by column grant + trigger)
CREATE POLICY profiles_select_authorized
ON public.profiles FOR SELECT TO authenticated
USING (
    id = (SELECT auth.uid())
    OR public.is_admin()
    OR public.is_service_counterparty(id)
);

CREATE POLICY profiles_insert_own
ON public.profiles FOR INSERT TO authenticated
WITH CHECK (
    id = (SELECT auth.uid())
    AND (user_id IS NULL OR user_id = (SELECT auth.uid()))
    AND role = 'motorist'::public.user_role
    AND COALESCE(is_nid_verified, FALSE) = FALSE
    AND is_active = TRUE
);

CREATE POLICY profiles_update_own_or_admin
ON public.profiles FOR UPDATE TO authenticated
USING (id = (SELECT auth.uid()) OR public.is_admin())
WITH CHECK (id = (SELECT auth.uid()) OR public.is_admin());

GRANT SELECT ON public.profiles TO authenticated;
GRANT INSERT (id, user_id, full_name, phone, avatar_url) ON public.profiles TO authenticated;
GRANT UPDATE (full_name, phone, avatar_url) ON public.profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_requested_role TEXT := lower(COALESCE(NULLIF(btrim(NEW.raw_user_meta_data ->> 'role'), ''), 'motorist'));
    v_safe_role public.user_role := CASE
        WHEN v_requested_role IN ('mechanic', 'technician') THEN 'mechanic'::public.user_role
        ELSE 'motorist'::public.user_role
    END;
    v_avatar TEXT := COALESCE(
        NULLIF(btrim(NEW.raw_user_meta_data ->> 'avatar_url'), ''),
        NULLIF(btrim(NEW.raw_user_meta_data ->> 'picture'), '')
    );
BEGIN
    INSERT INTO public.profiles (id, user_id, full_name, phone, avatar_url, role)
    VALUES (
        NEW.id,
        NEW.id,
        COALESCE(
            NULLIF(btrim(NEW.raw_user_meta_data ->> 'full_name'), ''),
            NULLIF(btrim(NEW.raw_user_meta_data ->> 'name'), ''),
            CASE WHEN v_safe_role = 'mechanic'::public.user_role THEN 'Technician' ELSE 'Motorist' END
        ),
        NEW.phone,
        v_avatar,
        v_safe_role
    )
    ON CONFLICT (id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        avatar_url = COALESCE(public.profiles.avatar_url, EXCLUDED.avatar_url),
        updated_at = now();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.protect_profile_privileged_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION 'Unauthorized: Non-admin users cannot change profile role.';
        END IF;
        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Unauthorized: Profile ID cannot be modified.';
        END IF;
        IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
            RAISE EXCEPTION 'Unauthorized: User ID cannot be modified.';
        END IF;
        IF NEW.is_nid_verified IS DISTINCT FROM OLD.is_nid_verified THEN
            RAISE EXCEPTION 'Unauthorized: Non-admin users cannot alter NID verification status.';
        END IF;
        IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
            RAISE EXCEPTION 'Unauthorized: Non-admin users cannot alter account active status.';
        END IF;
        IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            RAISE EXCEPTION 'Unauthorized: Created timestamp cannot be modified.';
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

-- 4.2 MECHANIC_PROFILES (no client self-verification, no unverified on-duty, no rating/location forgery)
CREATE OR REPLACE FUNCTION public.protect_mechanic_privileged_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF public.is_admin()
       OR current_setting('roadix.internal_mechanic_sync', TRUE) = 'on' THEN
        RETURN NEW;
    END IF;

    IF NEW.profile_id IS DISTINCT FROM OLD.profile_id THEN
        RAISE EXCEPTION 'Unauthorized: mechanic profile ID cannot change.';
    END IF;
    IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
        RAISE EXCEPTION 'Unauthorized: only administrators can alter mechanic verification status.';
    END IF;
    IF NEW.rating IS DISTINCT FROM OLD.rating OR NEW.total_rescues IS DISTINCT FROM OLD.total_rescues THEN
        RAISE EXCEPTION 'Unauthorized: mechanic trust metrics are server-managed.';
    END IF;
    IF NEW.is_on_duty = TRUE AND COALESCE(NEW.is_verified, FALSE) = FALSE THEN
        RAISE EXCEPTION 'Verified NID and trade license approval are required before going on duty.';
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_mechanic_privileged_fields ON public.mechanic_profiles;
CREATE TRIGGER trg_protect_mechanic_privileged_fields
BEFORE UPDATE ON public.mechanic_profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_mechanic_privileged_fields();

CREATE POLICY mechanics_select_authorized
ON public.mechanic_profiles FOR SELECT TO authenticated
USING (
    profile_id = (SELECT auth.uid())
    OR public.is_admin()
    OR EXISTS (
        SELECT 1
        FROM public.service_requests sr
        WHERE sr.mechanic_id = mechanic_profiles.profile_id
          AND sr.motorist_id = (SELECT auth.uid())
          AND sr.status IN (
              'assigned', 'en_route', 'arrived', 'diagnosing',
              'quote_pending', 'servicing', 'completed'
          )
    )
);

CREATE POLICY mechanics_insert_own
ON public.mechanic_profiles FOR INSERT TO authenticated
WITH CHECK (
    profile_id = (SELECT auth.uid())
    AND is_verified = FALSE
    AND is_on_duty = FALSE
    AND EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = (SELECT auth.uid()) AND p.role = 'mechanic'::public.user_role
    )
);

CREATE POLICY mechanics_update_own
ON public.mechanic_profiles FOR UPDATE TO authenticated
USING (profile_id = (SELECT auth.uid()) OR public.is_admin())
WITH CHECK (
    public.is_admin()
    OR (
        profile_id = (SELECT auth.uid())
        AND (is_on_duty = FALSE OR is_verified = TRUE)
    )
);

GRANT SELECT ON public.mechanic_profiles TO authenticated;
GRANT INSERT (profile_id, workshop_name, workshop_address, specializations, vehicle_specializations) ON public.mechanic_profiles TO authenticated;
GRANT UPDATE (workshop_name, workshop_address, is_on_duty, specializations, vehicle_specializations) ON public.mechanic_profiles TO authenticated;

-- 4.3 MECHANIC_VERIFICATIONS (private KYC docs: owner + admin only)
CREATE POLICY mechanic_verifications_select_owner_admin
ON public.mechanic_verifications FOR SELECT TO authenticated
USING (profile_id = (SELECT auth.uid()) OR public.is_admin());

CREATE POLICY mechanic_verifications_insert_owner
ON public.mechanic_verifications FOR INSERT TO authenticated
WITH CHECK (
    profile_id = (SELECT auth.uid())
    AND verified_at IS NULL
    AND verified_by IS NULL
);

CREATE POLICY mechanic_verifications_update_owner
ON public.mechanic_verifications FOR UPDATE TO authenticated
USING (profile_id = (SELECT auth.uid()) OR public.is_admin())
WITH CHECK (
    public.is_admin()
    OR (profile_id = (SELECT auth.uid()) AND verified_at IS NULL AND verified_by IS NULL)
);

GRANT SELECT ON public.mechanic_verifications TO authenticated;
GRANT INSERT (profile_id, trade_license_number, nid_number, nid_front_url, nid_back_url) ON public.mechanic_verifications TO authenticated;
GRANT UPDATE (trade_license_number, nid_number, nid_front_url, nid_back_url) ON public.mechanic_verifications TO authenticated;

-- 4.4 VEHICLES, EMERGENCY_CONTACTS, WALLETS, RESCUE_TICKETS (strict owner + admin)
CREATE POLICY vehicles_owner_or_admin
ON public.vehicles FOR ALL TO authenticated
USING (profile_id = (SELECT auth.uid()) OR public.is_admin())
WITH CHECK (profile_id = (SELECT auth.uid()) OR public.is_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vehicles TO authenticated;

CREATE POLICY emergency_contacts_owner_or_admin
ON public.emergency_contacts FOR ALL TO authenticated
USING (profile_id = (SELECT auth.uid()) OR public.is_admin())
WITH CHECK (profile_id = (SELECT auth.uid()) OR public.is_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.emergency_contacts TO authenticated;

CREATE POLICY wallets_owner_or_admin
ON public.wallets FOR ALL TO authenticated
USING (profile_id = (SELECT auth.uid()) OR public.is_admin())
WITH CHECK (profile_id = (SELECT auth.uid()) OR public.is_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wallets TO authenticated;

DO $$
BEGIN
    IF to_regclass('public.rescue_tickets') IS NOT NULL THEN
        EXECUTE 'CREATE POLICY rescue_tickets_owner_or_admin ON public.rescue_tickets FOR ALL TO authenticated USING (profile_id = (SELECT auth.uid()) OR public.is_admin()) WITH CHECK (profile_id = (SELECT auth.uid()) OR public.is_admin());';
        EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON public.rescue_tickets TO authenticated;';
    END IF;
END $$;

-- 4.5 SERVICE_REQUESTS + Lifecycle & Immutability Trigger
CREATE POLICY service_requests_select_participants
ON public.service_requests FOR SELECT TO authenticated
USING (
    motorist_id = (SELECT auth.uid())
    OR mechanic_id = (SELECT auth.uid())
    OR public.is_admin()
);

CREATE POLICY service_requests_update_motorist
ON public.service_requests FOR UPDATE TO authenticated
USING (
    motorist_id = (SELECT auth.uid())
    AND status IN ('created', 'searching', 'assigned')
)
WITH CHECK (
    motorist_id = (SELECT auth.uid())
    AND status IN ('searching', 'cancelled')
);

CREATE POLICY service_requests_update_mechanic
ON public.service_requests FOR UPDATE TO authenticated
USING (
    mechanic_id = (SELECT auth.uid())
    AND status IN ('assigned', 'en_route', 'arrived', 'diagnosing', 'quote_pending', 'servicing')
)
WITH CHECK (
    mechanic_id = (SELECT auth.uid())
    AND status IN ('en_route', 'arrived', 'diagnosing', 'quote_pending', 'servicing', 'completed')
);

GRANT SELECT ON public.service_requests TO authenticated;
GRANT UPDATE (status, cancellation_reason, cancelled_at) ON public.service_requests TO authenticated;

CREATE OR REPLACE FUNCTION public.check_service_request_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_admin_token TEXT := current_setting('roadix.internal_admin_caller', TRUE);
    v_dispatch_token TEXT := current_setting('roadix.internal_dispatch_caller', TRUE);
    v_quote_token TEXT := current_setting('roadix.internal_quotation_caller', TRUE);
    v_settlement_token TEXT := current_setting('roadix.internal_settlement_caller', TRUE);
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.request_code IS DISTINCT FROM OLD.request_code
       OR NEW.motorist_id IS DISTINCT FROM OLD.motorist_id
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
       OR NEW.breakdown_location IS DISTINCT FROM OLD.breakdown_location
       OR NEW.breakdown_address IS DISTINCT FROM OLD.breakdown_address
       OR NEW.vehicle_snapshot IS DISTINCT FROM OLD.vehicle_snapshot
       OR NEW.fault_type IS DISTINCT FROM OLD.fault_type
       OR NEW.symptoms IS DISTINCT FROM OLD.symptoms
       OR NEW.diagnostic_notes IS DISTINCT FROM OLD.diagnostic_notes
       OR NEW.photo_urls IS DISTINCT FROM OLD.photo_urls
       OR NEW.is_high_priority IS DISTINCT FROM OLD.is_high_priority THEN
        RAISE EXCEPTION 'Submitted service-request details are immutable.';
    END IF;

    IF NEW.search_radius_km IS DISTINCT FROM OLD.search_radius_km THEN
        IF v_dispatch_token IS DISTINCT FROM 'expand_dispatch_radius'
           OR NEW.search_radius_km NOT IN (5.00, 7.50, 10.00, 12.50, 15.00)
           OR NEW.search_radius_km <= OLD.search_radius_km
           OR NEW.search_radius_km - OLD.search_radius_km > 2.50 THEN
            RAISE EXCEPTION 'Search radius may only expand by one approved 2.5 km step through expansion RPC.';
        END IF;
    END IF;

    IF NEW.mechanic_id IS DISTINCT FROM OLD.mechanic_id THEN
        IF v_dispatch_token IS DISTINCT FROM 'accept_dispatch_offer'
           AND v_admin_token IS DISTINCT FROM 'admin_override_service_request' THEN
            RAISE EXCEPTION 'Mechanic assignment may only change through dispatch acceptance or admin override.';
        END IF;
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status THEN
        IF v_admin_token = 'admin_override_service_request' THEN
            IF NEW.status NOT IN ('cancelled', 'completed', 'searching') THEN
                RAISE EXCEPTION 'Invalid administrative target status.';
            END IF;

        ELSIF v_dispatch_token = 'accept_dispatch_offer'
              AND OLD.status = 'searching' AND NEW.status = 'assigned' THEN
            NEW.assigned_at := COALESCE(NEW.assigned_at, now());

        ELSIF v_quote_token = 'submit_quotation'
              AND OLD.status = 'diagnosing' AND NEW.status = 'quote_pending' THEN
            NULL;

        ELSIF v_quote_token = 'respond_to_quotation'
              AND OLD.status = 'quote_pending'
              AND NEW.status IN ('servicing', 'diagnosing') THEN
            NULL;

        ELSIF v_settlement_token = 'confirm_settlement'
              AND OLD.status = 'servicing' AND NEW.status = 'completed' THEN
            NEW.completed_at := COALESCE(NEW.completed_at, now());

        ELSIF v_user = OLD.motorist_id THEN
            IF NEW.status = 'cancelled' AND OLD.status IN ('created', 'searching', 'assigned') THEN
                NEW.cancelled_at := COALESCE(NEW.cancelled_at, now());
            ELSE
                RAISE EXCEPTION 'Motorist cannot perform this service-request status transition (% -> %).', OLD.status, NEW.status;
            END IF;

        ELSIF v_user = OLD.mechanic_id THEN
            IF (OLD.status = 'assigned' AND NEW.status = 'en_route')
               OR (OLD.status = 'en_route' AND NEW.status = 'arrived')
               OR (OLD.status = 'arrived' AND NEW.status = 'diagnosing')
               OR (OLD.status = 'diagnosing' AND NEW.status IN ('quote_pending', 'servicing'))
               OR (OLD.status = 'servicing' AND NEW.status = 'completed') THEN
                IF NEW.status = 'arrived' THEN
                    NEW.arrived_at := COALESCE(OLD.arrived_at, now());
                ELSIF NEW.status = 'completed' THEN
                    NEW.completed_at := COALESCE(OLD.completed_at, now());
                END IF;
            ELSE
                RAISE EXCEPTION 'Mechanic cannot perform this service-request status transition (% -> %).', OLD.status, NEW.status;
            END IF;
        ELSE
            RAISE EXCEPTION 'Unauthorized service-request status transition.';
        END IF;
    END IF;

    IF (NEW.cancellation_reason IS DISTINCT FROM OLD.cancellation_reason
        OR NEW.cancelled_at IS DISTINCT FROM OLD.cancelled_at)
       AND NEW.status <> 'cancelled' THEN
        RAISE EXCEPTION 'Cancellation metadata can only be changed when cancelling a request.';
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_service_request_mutation ON public.service_requests;
CREATE TRIGGER trg_validate_service_request_mutation
BEFORE UPDATE ON public.service_requests
FOR EACH ROW EXECUTE FUNCTION public.check_service_request_mutation();

-- 4.6 DISPATCH_OFFERS, QUOTATIONS, TRANSACTIONS, REVIEWS, RATE_CARDS, AUDIT_LOGS
CREATE POLICY dispatch_offers_select_recipient
ON public.dispatch_offers FOR SELECT TO authenticated
USING (mechanic_id = (SELECT auth.uid()) OR public.is_admin());
GRANT SELECT ON public.dispatch_offers TO authenticated;

CREATE POLICY quotations_select_participants
ON public.quotations FOR SELECT TO authenticated
USING (
    mechanic_id = (SELECT auth.uid())
    OR EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.id = quotations.request_id AND sr.motorist_id = (SELECT auth.uid())
    )
    OR public.is_admin()
);
GRANT SELECT ON public.quotations TO authenticated;

CREATE POLICY transactions_select_participants
ON public.transactions FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.id = transactions.request_id
          AND (sr.motorist_id = (SELECT auth.uid()) OR sr.mechanic_id = (SELECT auth.uid()))
    )
    OR public.is_admin()
);
GRANT SELECT ON public.transactions TO authenticated;

CREATE POLICY reviews_select_authenticated
ON public.reviews FOR SELECT TO authenticated
USING (TRUE);

CREATE POLICY reviews_insert_motorist
ON public.reviews FOR INSERT TO authenticated
WITH CHECK (
    motorist_id = (SELECT auth.uid())
    AND rating BETWEEN 1 AND 5
    AND EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.id = reviews.request_id
          AND sr.motorist_id = (SELECT auth.uid())
          AND sr.mechanic_id = reviews.mechanic_id
          AND sr.status = 'completed'
    )
);
GRANT SELECT, INSERT ON public.reviews TO authenticated;

CREATE POLICY rate_cards_select_all
ON public.standard_rate_cards FOR SELECT TO anon, authenticated
USING (TRUE);

CREATE POLICY rate_cards_admin_write
ON public.standard_rate_cards FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());
GRANT SELECT ON public.standard_rate_cards TO anon, authenticated;

CREATE POLICY audit_logs_select_admin
ON public.admin_audit_logs FOR SELECT TO authenticated
USING (public.is_admin());
GRANT SELECT ON public.admin_audit_logs TO authenticated;

-- 5. Derived aggregates triggers (replace unprivileged client-side metric updates)
CREATE OR REPLACE FUNCTION public.sync_reviews_to_mechanic_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM set_config('roadix.internal_mechanic_sync', 'on', TRUE);
    UPDATE public.mechanic_profiles mp
    SET rating = COALESCE((
            SELECT ROUND(AVG(r.rating)::NUMERIC, 2)
            FROM public.reviews r
            WHERE r.mechanic_id = NEW.mechanic_id
        ), 5.00),
        updated_at = now()
    WHERE mp.profile_id = NEW.mechanic_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reviews_update_mechanic_rating ON public.reviews;
CREATE TRIGGER trg_reviews_update_mechanic_rating
AFTER INSERT ON public.reviews
FOR EACH ROW EXECUTE FUNCTION public.sync_reviews_to_mechanic_rating();

CREATE OR REPLACE FUNCTION public.sync_completed_rescues_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed' AND NEW.mechanic_id IS NOT NULL THEN
        PERFORM set_config('roadix.internal_mechanic_sync', 'on', TRUE);
        UPDATE public.mechanic_profiles mp
        SET total_rescues = mp.total_rescues + 1,
            updated_at = now()
        WHERE mp.profile_id = NEW.mechanic_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_service_request_completed_rescues ON public.service_requests;
CREATE TRIGGER trg_service_request_completed_rescues
AFTER UPDATE ON public.service_requests
FOR EACH ROW EXECUTE FUNCTION public.sync_completed_rescues_count();

-- 6. Storage bucket validation & RLS Policies for avatars, fault-photos, mechanic-verifications
UPDATE storage.buckets
SET file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
WHERE id IN ('avatars', 'fault-photos');

UPDATE storage.buckets
SET file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
WHERE id = 'mechanic-verifications';

DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname
        FROM pg_policies
        WHERE schemaname = 'storage' AND tablename = 'objects'
          AND policyname LIKE 'roadix_%'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects;', pol.policyname);
    END LOOP;
END $$;

-- Avatars: public read; owner upload/update/delete inside <auth.uid()>/...
CREATE POLICY roadix_avatars_public_select
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'avatars');

CREATE POLICY roadix_avatars_owner_insert
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
);

CREATE POLICY roadix_avatars_owner_update
ON storage.objects FOR UPDATE TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
)
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
);

CREATE POLICY roadix_avatars_owner_delete
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
);

-- Fault photos: owner uploads inside <auth.uid()>/...; owner, assigned mechanic, or admin reads
CREATE POLICY roadix_fault_photos_owner_insert
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'fault-photos'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
);

CREATE POLICY roadix_fault_photos_authorized_select
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'fault-photos'
    AND (
        (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
        OR public.is_admin()
        OR EXISTS (
            SELECT 1
            FROM public.service_requests sr
            WHERE sr.mechanic_id = (SELECT auth.uid())
              AND sr.motorist_id::TEXT = (storage.foldername(name))[1]
        )
    )
);

-- Mechanic verifications: owner uploads inside <auth.uid()>/...; owner or admin reads
CREATE POLICY roadix_verifications_owner_insert
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'mechanic-verifications'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
);

CREATE POLICY roadix_verifications_owner_admin_select
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'mechanic-verifications'
    AND ((storage.foldername(name))[1] = (SELECT auth.uid())::TEXT OR public.is_admin())
);

-- 7. Reconcile & Harden Core RPCs (LATERAL scoring, locks, GUC tokens, atomic wallets, cash settlement, admin)
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
    dispatch_score NUMERIC
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

    IF p_vehicle_type IS NULL OR p_vehicle_type NOT IN ('Passenger Car', 'Motorcycle', 'Light Commercial') THEN
        RAISE EXCEPTION 'A valid ROADIX vehicle class is required.';
    END IF;

    v_radius := LEAST(GREATEST(COALESCE(p_radius_meters, 5000), 5000), 15000);

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
                ELSE (op.accepted_offers::NUMERIC / op.total_decided_offers::NUMERIC) * 100
            END
        )::NUMERIC(5,2)
    FROM public.mechanic_profiles m
    JOIN public.profiles p ON p.id = m.profile_id
    LEFT JOIN LATERAL (
        SELECT AVG(r.rating)::NUMERIC AS average_rating, COUNT(*)::BIGINT AS review_count
        FROM public.reviews r
        WHERE r.mechanic_id = m.profile_id
    ) rv ON TRUE
    LEFT JOIN LATERAL (
        SELECT
            COUNT(*) FILTER (WHERE o.status = 'accepted')::BIGINT AS accepted_offers,
            COUNT(*) FILTER (WHERE o.status IN ('accepted', 'rejected', 'timed_out'))::BIGINT AS total_decided_offers
        FROM public.dispatch_offers o
        WHERE o.mechanic_id = m.profile_id
    ) op ON TRUE
    WHERE p.role = 'mechanic'::public.user_role
      AND m.is_on_duty = TRUE
      AND m.is_verified = TRUE
      AND m.current_location IS NOT NULL
      AND ST_DWithin(m.current_location, p_breakdown_location, v_radius)
      AND NOT EXISTS (
          SELECT 1
          FROM public.service_requests active_sr
          WHERE active_sr.mechanic_id = m.profile_id
            AND active_sr.status IN ('assigned', 'en_route', 'arrived', 'diagnosing', 'quote_pending', 'servicing')
      )
    ORDER BY 7 DESC, (p_fault_type = ANY(m.specializations)) DESC, 3 ASC;
END;
$$;

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
        SELECT 1 FROM public.dispatch_offers o
        WHERE o.request_id = p_request_id AND o.status = 'offered' AND o.expires_at > now()
    ) THEN
        RAISE EXCEPTION 'An offer is already active for this request.';
    END IF;

    UPDATE public.dispatch_offers
    SET status = 'timed_out', responded_at = now()
    WHERE request_id = p_request_id AND status = 'offered' AND expires_at <= now();

    v_vehicle_type := public.roadix_vehicle_type_from_snapshot(v_req.vehicle_snapshot);

    SELECT c.*
    INTO v_candidate
    FROM public.find_eligible_mechanics(
        v_req.breakdown_location,
        v_req.search_radius_km * 1000.0,
        v_req.fault_type,
        v_vehicle_type
    ) c
    WHERE NOT EXISTS (
        SELECT 1 FROM public.dispatch_offers o
        WHERE o.request_id = p_request_id AND o.mechanic_id = c.mechanic_id
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
        request_id, mechanic_id, offer_radius_km, score, status, offered_at, expires_at
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
RETURNS NUMERIC
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
        SELECT 1 FROM public.dispatch_offers o
        WHERE o.request_id = p_request_id AND o.status = 'offered' AND o.expires_at > now()
    ) THEN
        RAISE EXCEPTION 'Wait for the active offer to receive a response or expire.';
    END IF;

    UPDATE public.dispatch_offers
    SET status = 'timed_out', responded_at = now()
    WHERE request_id = p_request_id AND status = 'offered' AND expires_at <= now();

    v_vehicle_type := public.roadix_vehicle_type_from_snapshot(v_req.vehicle_snapshot);

    SELECT count(*) INTO v_unoffered
    FROM public.find_eligible_mechanics(
        v_req.breakdown_location,
        v_req.search_radius_km * 1000.0,
        v_req.fault_type,
        v_vehicle_type
    ) c
    WHERE NOT EXISTS (
        SELECT 1 FROM public.dispatch_offers o
        WHERE o.request_id = p_request_id AND o.mechanic_id = c.mechanic_id
    );

    IF v_unoffered > 0 THEN
        RAISE EXCEPTION 'Cannot expand: % eligible mechanic(s) have not yet received an offer.', v_unoffered;
    END IF;

    v_new_radius := LEAST(v_req.search_radius_km + 2.50, 15.00);
    PERFORM set_config('roadix.internal_dispatch_caller', 'expand_dispatch_radius', TRUE);

    UPDATE public.service_requests
    SET search_radius_km = v_new_radius, updated_at = now()
    WHERE id = p_request_id;

    RETURN v_new_radius;
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_dispatch_offer(p_request_id UUID, p_offer_id UUID)
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
          AND sr.status IN ('assigned', 'en_route', 'arrived', 'diagnosing', 'quote_pending', 'servicing')
    ) THEN
        RAISE EXCEPTION 'Finish or release your current active assignment before accepting another.';
    END IF;

    SELECT id, status, expires_at
    INTO v_offer
    FROM public.dispatch_offers
    WHERE id = p_offer_id AND request_id = p_request_id AND mechanic_id = v_user
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

    SELECT id, status
    INTO v_request
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND OR v_request.status <> 'searching' THEN
        UPDATE public.dispatch_offers
        SET status = 'cancelled', responded_at = now()
        WHERE id = p_offer_id;
        RETURN FALSE;
    END IF;

    PERFORM set_config('roadix.internal_dispatch_caller', 'accept_dispatch_offer', TRUE);

    UPDATE public.service_requests
    SET mechanic_id = v_user,
        status = 'assigned',
        assigned_at = now(),
        updated_at = now()
    WHERE id = p_request_id AND status = 'searching';

    UPDATE public.dispatch_offers
    SET status = 'accepted', responded_at = now()
    WHERE id = p_offer_id;

    UPDATE public.dispatch_offers
    SET status = 'cancelled', responded_at = now()
    WHERE request_id = p_request_id AND id <> p_offer_id AND status = 'offered';

    RETURN TRUE;
END;
$$;

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

CREATE OR REPLACE FUNCTION public.update_mechanic_location(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_verified BOOLEAN;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_lat IS NULL OR p_lng IS NULL OR p_lat < 20.0 OR p_lat > 27.0 OR p_lng < 88.0 OR p_lng > 93.0 THEN
        RAISE EXCEPTION 'Coordinates are outside supported Bangladesh bounds.';
    END IF;

    SELECT is_verified INTO v_verified
    FROM public.mechanic_profiles
    WHERE profile_id = v_user;

    IF NOT FOUND OR NOT COALESCE(v_verified, FALSE) THEN
        RAISE EXCEPTION 'Verified mechanic profile required for live telemetry.';
    END IF;

    PERFORM set_config('roadix.internal_mechanic_sync', 'on', TRUE);
    UPDATE public.mechanic_profiles
    SET current_location = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
        updated_at = now()
    WHERE profile_id = v_user;
END;
$$;

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
    v_verified BOOLEAN;
    v_quote_id UUID;
    v_total NUMERIC;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT is_verified INTO v_verified
    FROM public.mechanic_profiles
    WHERE profile_id = v_user;

    IF NOT COALESCE(v_verified, FALSE) THEN
        RAISE EXCEPTION 'Only verified mechanics can submit quotations.';
    END IF;

    IF COALESCE(p_diagnostic_fee, 0) < 0 OR COALESCE(p_labor_fee, 0) < 0 OR COALESCE(p_parts_fee, 0) < 0 THEN
        RAISE EXCEPTION 'Quotation fees cannot be negative.';
    END IF;

    SELECT id, mechanic_id, status INTO v_req
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND OR v_req.mechanic_id <> v_user THEN
        RAISE EXCEPTION 'Only the assigned mechanic can submit quotations.';
    END IF;

    IF v_req.status <> 'diagnosing' THEN
        RAISE EXCEPTION 'Quotations can only be submitted during diagnosing state (current: %).', v_req.status;
    END IF;

    UPDATE public.quotations
    SET status = 'rejected', updated_at = now()
    WHERE request_id = p_request_id AND status = 'pending';

    v_total := COALESCE(p_diagnostic_fee, 0) + COALESCE(p_labor_fee, 0) + COALESCE(p_parts_fee, 0);

    INSERT INTO public.quotations (
        request_id, mechanic_id, diagnostic_fee, labor_fee, parts_fee, total_amount, line_items, status
    )
    VALUES (
        p_request_id, v_user, p_diagnostic_fee, p_labor_fee, COALESCE(p_parts_fee, 0), v_total, COALESCE(p_line_items, '{}'::jsonb), 'pending'
    )
    RETURNING id INTO v_quote_id;

    PERFORM set_config('roadix.internal_quotation_caller', 'submit_quotation', TRUE);

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

    IF p_decision IS NULL OR p_decision NOT IN ('accepted', 'rejected') THEN
        RAISE EXCEPTION 'Decision must be accepted or rejected.';
    END IF;

    SELECT q.id, q.request_id, q.status AS quote_status, sr.motorist_id, sr.status AS req_status
    INTO v_quote
    FROM public.quotations q
    JOIN public.service_requests sr ON sr.id = q.request_id
    WHERE q.id = p_quotation_id
    FOR UPDATE OF q, sr;

    IF NOT FOUND OR v_quote.motorist_id <> v_user THEN
        RAISE EXCEPTION 'Only the requesting motorist can respond to quotations.';
    END IF;

    IF v_quote.quote_status <> 'pending' OR v_quote.req_status <> 'quote_pending' THEN
        RAISE EXCEPTION 'Quotation is no longer pending approval.';
    END IF;

    PERFORM set_config('roadix.internal_quotation_caller', 'respond_to_quotation', TRUE);

    IF p_decision = 'accepted' THEN
        UPDATE public.quotations SET status = 'accepted', updated_at = now() WHERE id = p_quotation_id;
        UPDATE public.service_requests SET status = 'servicing', updated_at = now() WHERE id = v_quote.request_id;
        RETURN TRUE;
    ELSE
        UPDATE public.quotations SET status = 'rejected', updated_at = now() WHERE id = p_quotation_id;
        UPDATE public.service_requests SET status = 'diagnosing', updated_at = now() WHERE id = v_quote.request_id;
        RETURN FALSE;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_primary_wallet(p_wallet_id UUID)
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

    IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE id = p_wallet_id AND profile_id = v_user) THEN
        RAISE EXCEPTION 'Wallet not found or unauthorized.';
    END IF;

    UPDATE public.wallets SET is_primary = FALSE WHERE profile_id = v_user AND is_primary = TRUE;
    UPDATE public.wallets SET is_primary = TRUE WHERE id = p_wallet_id AND profile_id = v_user;
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_cash_settlement(p_request_id UUID, p_quotation_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_req RECORD;
    v_quote RECORD;
    v_tx_id UUID;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT id, motorist_id, mechanic_id, status
    INTO v_req
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND OR (v_req.motorist_id <> v_user AND v_req.mechanic_id <> v_user) THEN
        RAISE EXCEPTION 'Unauthorized settlement request.';
    END IF;

    IF v_req.status NOT IN ('servicing', 'completed') THEN
        RAISE EXCEPTION 'Cash settlement requires active servicing status.';
    END IF;

    SELECT id, total_amount
    INTO v_quote
    FROM public.quotations
    WHERE request_id = p_request_id
      AND (p_quotation_id IS NULL OR id = p_quotation_id)
      AND status = 'accepted'
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Accepted quotation required for settlement.';
    END IF;

    INSERT INTO public.transactions (
        request_id, quotation_id, amount, payment_method, status, gateway_transaction_id, metadata
    )
    VALUES (
        p_request_id, v_quote.id, v_quote.total_amount, 'Cash', 'completed',
        'CASH-' || replace(gen_random_uuid()::TEXT, '-', ''),
        jsonb_build_object('confirmed_by', v_user, 'channel', 'in_person_cash')
    )
    RETURNING id INTO v_tx_id;

    IF v_req.status = 'servicing' THEN
        PERFORM set_config('roadix.internal_settlement_caller', 'confirm_settlement', TRUE);
        UPDATE public.service_requests
        SET status = 'completed', completed_at = now(), updated_at = now()
        WHERE id = p_request_id;
    END IF;

    RETURN jsonb_build_object('transaction_id', v_tx_id, 'status', 'completed');
END;
$$;

-- Hardened Admin RPCs (aligned with remote admin_audit_logs.payload column)
CREATE OR REPLACE FUNCTION public.set_user_role(p_target_user_id UUID, p_new_role TEXT)
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
    IF p_new_role IS NULL OR p_new_role NOT IN ('motorist', 'mechanic', 'admin') THEN
        RAISE EXCEPTION 'Role must be motorist, mechanic, or admin.';
    END IF;

    UPDATE auth.users
    SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::JSONB) || jsonb_build_object('user_role', p_new_role),
        updated_at = now()
    WHERE id = p_target_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Target Auth user not found.'; END IF;

    UPDATE public.profiles SET role = p_new_role::public.user_role, updated_at = now() WHERE id = p_target_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Target profile not found.'; END IF;

    IF p_new_role <> 'admin' THEN
        DELETE FROM auth.refresh_tokens WHERE user_id = p_target_user_id::TEXT;
    END IF;

    INSERT INTO public.admin_audit_logs (admin_id, action, target_entity, target_id, payload)
    VALUES (v_admin, 'SET_USER_ROLE', 'profiles', p_target_user_id, jsonb_build_object('new_role', p_new_role));
END;
$$;

CREATE OR REPLACE FUNCTION public.review_mechanic_verification(p_mechanic_id UUID, p_approved BOOLEAN, p_reason TEXT)
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

    PERFORM set_config('roadix.internal_mechanic_sync', 'on', TRUE);

    UPDATE public.mechanic_verifications
    SET verified_at = CASE WHEN p_approved THEN now() ELSE NULL END,
        verified_by = v_admin,
        updated_at = now()
    WHERE profile_id = p_mechanic_id;

    UPDATE public.mechanic_profiles
    SET is_verified = p_approved,
        is_on_duty = CASE WHEN p_approved THEN is_on_duty ELSE FALSE END,
        updated_at = now()
    WHERE profile_id = p_mechanic_id;

    UPDATE public.profiles SET is_nid_verified = p_approved, updated_at = now() WHERE id = p_mechanic_id;

    INSERT INTO public.admin_audit_logs (admin_id, action, target_entity, target_id, payload)
    VALUES (v_admin, 'REVIEW_MECHANIC_VERIFICATION', 'mechanic_profiles', p_mechanic_id,
            jsonb_build_object('approved', p_approved, 'reason', p_reason));
END;
$$;

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
    IF p_action IS NULL OR p_action NOT IN ('cancel_request', 'force_complete', 'reassign_searching') THEN
        RAISE EXCEPTION 'Unsupported administrative action.';
    END IF;

    SELECT * INTO v_req FROM public.service_requests WHERE id = p_request_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Service request not found.'; END IF;
    IF v_req.status IN ('completed', 'cancelled') THEN
        RAISE EXCEPTION 'Terminal requests cannot be overridden.';
    END IF;

    PERFORM set_config('roadix.internal_admin_caller', 'admin_override_service_request', TRUE);

    IF p_action = 'cancel_request' THEN
        v_new_status := 'cancelled';
        UPDATE public.service_requests
        SET status = 'cancelled', cancellation_reason = 'Admin override: ' || btrim(p_reason),
            cancelled_at = v_now, updated_at = v_now
        WHERE id = p_request_id;
        UPDATE public.dispatch_offers SET status = 'cancelled', responded_at = v_now
        WHERE request_id = p_request_id AND status = 'offered';
    ELSIF p_action = 'force_complete' THEN
        v_new_status := 'completed';
        UPDATE public.service_requests SET status = 'completed', completed_at = v_now, updated_at = v_now
        WHERE id = p_request_id;
    ELSE
        v_new_status := 'searching';
        UPDATE public.service_requests
        SET status = 'searching', mechanic_id = NULL, assigned_at = NULL, arrived_at = NULL, updated_at = v_now
        WHERE id = p_request_id;
        UPDATE public.dispatch_offers SET status = 'cancelled', responded_at = v_now
        WHERE request_id = p_request_id AND status = 'offered';
    END IF;

    INSERT INTO public.admin_audit_logs (admin_id, action, target_entity, target_id, payload)
    VALUES (
        v_admin, 'ADMIN_OVERRIDE_' || upper(p_action), 'service_requests', p_request_id,
        jsonb_build_object('reason', btrim(p_reason), 'previous_status', v_req.status,
                           'new_status', v_new_status, 'previous_mechanic_id', v_req.mechanic_id,
                           'custom_metadata', COALESCE(p_metadata, '{}'::JSONB))
    );

    RETURN jsonb_build_object('request_id', p_request_id, 'action', p_action,
                              'previous_status', v_req.status, 'new_status', v_new_status,
                              'admin_id', v_admin, 'overridden_at', v_now);
END;
$$;

-- 8. Revoke default PUBLIC / anon execute privileges across all app RPCs & helpers
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_service_counterparty(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.roadix_vehicle_type_from_snapshot(JSONB) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.calculate_dispatch_score(DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT[], NUMERIC, INTEGER, NUMERIC) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.find_eligible_mechanics(GEOGRAPHY, DOUBLE PRECISION, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_profile_privileged_fields() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_mechanic_privileged_fields() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.check_service_request_mutation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.validate_service_request_vehicle_snapshot() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_reviews_to_mechanic_rating() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_completed_rescues_count() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_emergency_contact_relation() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.create_service_request(DOUBLE PRECISION, DOUBLE PRECISION, TEXT, JSONB, TEXT, TEXT[], TEXT, TEXT[], BOOLEAN) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.dispatch_next_candidate(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.expand_dispatch_radius(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.accept_dispatch_offer(UUID, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reject_dispatch_offer(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_mechanic_location(DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.submit_quotation(UUID, NUMERIC, NUMERIC, NUMERIC, JSONB) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.respond_to_quotation(UUID, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_primary_wallet(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.confirm_cash_settlement(UUID, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_user_role(UUID, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.review_mechanic_verification(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_override_service_request(UUID, TEXT, TEXT, JSONB) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, postgres, service_role;
GRANT EXECUTE ON FUNCTION public.is_service_counterparty(UUID) TO authenticated, postgres, service_role;
GRANT EXECUTE ON FUNCTION public.roadix_vehicle_type_from_snapshot(JSONB) TO authenticated, postgres, service_role;
GRANT EXECUTE ON FUNCTION public.calculate_dispatch_score(DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT[], NUMERIC, INTEGER, NUMERIC) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION public.find_eligible_mechanics(GEOGRAPHY, DOUBLE PRECISION, TEXT, TEXT) TO postgres, service_role;
GRANT EXECUTE ON FUNCTION public.create_service_request(DOUBLE PRECISION, DOUBLE PRECISION, TEXT, JSONB, TEXT, TEXT[], TEXT, TEXT[], BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.dispatch_next_candidate(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.expand_dispatch_radius(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.accept_dispatch_offer(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reject_dispatch_offer(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_mechanic_location(DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_quotation(UUID, NUMERIC, NUMERIC, NUMERIC, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.respond_to_quotation(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_primary_wallet(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_cash_settlement(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_user_role(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.review_mechanic_verification(UUID, BOOLEAN, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_override_service_request(UUID, TEXT, TEXT, JSONB) TO authenticated, service_role;

-- 9. Ensure Standard Rate Cards exist on remote without duplicating
INSERT INTO public.standard_rate_cards (fault_type, vehicle_type, base_diagnostic_fee, max_diagnostic_fee, currency)
VALUES
    ('Flat Tire', 'Passenger Car', 300.00, 600.00, 'BDT'),
    ('Flat Tire', 'Motorcycle', 200.00, 400.00, 'BDT'),
    ('Flat Tire', 'Light Commercial', 500.00, 1000.00, 'BDT'),
    ('Dead Battery', 'Passenger Car', 350.00, 700.00, 'BDT'),
    ('Dead Battery', 'Motorcycle', 200.00, 400.00, 'BDT'),
    ('Dead Battery', 'Light Commercial', 500.00, 1000.00, 'BDT'),
    ('Engine Trouble', 'Passenger Car', 500.00, 1200.00, 'BDT'),
    ('Engine Trouble', 'Motorcycle', 300.00, 700.00, 'BDT'),
    ('Engine Trouble', 'Light Commercial', 700.00, 1600.00, 'BDT'),
    ('Out of Fuel', 'Passenger Car', 250.00, 500.00, 'BDT'),
    ('Out of Fuel', 'Motorcycle', 150.00, 350.00, 'BDT'),
    ('Out of Fuel', 'Light Commercial', 350.00, 700.00, 'BDT'),
    ('Towing', 'Passenger Car', 1000.00, 2500.00, 'BDT'),
    ('Towing', 'Motorcycle', 500.00, 1200.00, 'BDT'),
    ('Towing', 'Light Commercial', 1500.00, 3500.00, 'BDT'),
    ('General Automotive Breakdown', 'Passenger Car', 400.00, 900.00, 'BDT'),
    ('General Automotive Breakdown', 'Motorcycle', 250.00, 550.00, 'BDT'),
    ('General Automotive Breakdown', 'Light Commercial', 600.00, 1300.00, 'BDT'),
    ('Brake Failure', 'Passenger Car', 450.00, 1000.00, 'BDT'),
    ('Brake Failure', 'Motorcycle', 250.00, 600.00, 'BDT'),
    ('Brake Failure', 'Light Commercial', 650.00, 1400.00, 'BDT')
ON CONFLICT (fault_type, vehicle_type) DO NOTHING;
