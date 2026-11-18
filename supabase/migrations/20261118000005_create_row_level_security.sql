-- ============================================================================
-- ROADIX MIGRATION 05 (REVISED): Least-Privilege RLS & Access Control
-- Requires corrected Migration 04.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Live administrator check: JWT claim AND current Auth database role.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT COALESCE(
        auth.uid() IS NOT NULL
        AND (auth.jwt() -> 'app_metadata' ->> 'user_role') = 'admin'
        AND EXISTS (
            SELECT 1
            FROM auth.users u
            WHERE u.id = auth.uid()
              AND (u.raw_app_meta_data ->> 'user_role') = 'admin'
        ),
        FALSE
    );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 1. Enable RLS on all application tables.
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

-- Drop policies from the prior draft so this revised migration can be applied
-- to a database where the earlier draft's policies were already created.
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT schemaname, tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename IN (
              'profiles','mechanic_profiles','mechanic_verifications','vehicles',
              'emergency_contacts','wallets','service_requests','dispatch_offers',
              'quotations','transactions','reviews','standard_rate_cards','admin_audit_logs'
          )
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                       r.policyname, r.schemaname, r.tablename);
    END LOOP;
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. Profiles: no global mechanic-profile visibility. Counterparties can read
-- contact details only when they share a service request.
-- ----------------------------------------------------------------------------
CREATE POLICY profiles_select_authorized ON public.profiles
FOR SELECT TO authenticated
USING (
    id = auth.uid()
    OR public.is_admin()
    OR EXISTS (
        SELECT 1
        FROM public.service_requests sr
        WHERE (sr.motorist_id = auth.uid() AND sr.mechanic_id = profiles.id)
           OR (sr.mechanic_id = auth.uid() AND sr.motorist_id = profiles.id)
    )
);

CREATE POLICY profiles_update_own ON public.profiles
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

REVOKE ALL ON public.profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.profiles TO authenticated;
GRANT UPDATE (full_name, phone, avatar_url) ON public.profiles TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. Mechanic profiles: private by default. Public discovery is through the
-- limited SECURITY DEFINER RPC in Migration 04. Location writes only via RPC.
-- ----------------------------------------------------------------------------
CREATE POLICY mechanics_select_authorized ON public.mechanic_profiles
FOR SELECT TO authenticated
USING (
    profile_id = auth.uid()
    OR public.is_admin()
    OR EXISTS (
        SELECT 1
        FROM public.service_requests sr
        WHERE sr.mechanic_id = mechanic_profiles.profile_id
          AND sr.motorist_id = auth.uid()
          AND sr.status IN ('assigned','en_route','arrived','diagnosing','quote_pending','servicing')
    )
);

CREATE POLICY mechanics_insert_own ON public.mechanic_profiles
FOR INSERT TO authenticated
WITH CHECK (
    profile_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role = 'mechanic'
    )
);

CREATE POLICY mechanics_update_own ON public.mechanic_profiles
FOR UPDATE TO authenticated
USING (profile_id = auth.uid())
WITH CHECK (
    profile_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role = 'mechanic'
    )
    AND (is_on_duty = FALSE OR is_verified = TRUE)
);

REVOKE ALL ON public.mechanic_profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.mechanic_profiles TO authenticated;
GRANT INSERT (
    profile_id, workshop_name, workshop_address, is_on_duty, specializations
) ON public.mechanic_profiles TO authenticated;
GRANT UPDATE (
    workshop_name, workshop_address, is_on_duty, specializations
) ON public.mechanic_profiles TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. Verification documents: owners may submit/update document fields; only
-- the trusted admin RPC can set verified_at / verified_by.
-- ----------------------------------------------------------------------------
CREATE POLICY mechanic_verifications_select_owner_admin ON public.mechanic_verifications
FOR SELECT TO authenticated
USING (profile_id = auth.uid() OR public.is_admin());

CREATE POLICY mechanic_verifications_insert_owner ON public.mechanic_verifications
FOR INSERT TO authenticated
WITH CHECK (
    profile_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role = 'mechanic'
    )
);

CREATE POLICY mechanic_verifications_update_owner ON public.mechanic_verifications
FOR UPDATE TO authenticated
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

REVOKE ALL ON public.mechanic_verifications FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.mechanic_verifications TO authenticated;
GRANT INSERT (
    profile_id, trade_license_number, nid_number, nid_front_url, nid_back_url
) ON public.mechanic_verifications TO authenticated;
GRANT UPDATE (
    trade_license_number, nid_number, nid_front_url, nid_back_url
) ON public.mechanic_verifications TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. User-owned tables.
-- ----------------------------------------------------------------------------
CREATE POLICY vehicles_owner_admin ON public.vehicles
FOR ALL TO authenticated
USING (profile_id = auth.uid() OR public.is_admin())
WITH CHECK (profile_id = auth.uid() OR public.is_admin());

CREATE POLICY emergency_contacts_owner_admin ON public.emergency_contacts
FOR ALL TO authenticated
USING (profile_id = auth.uid() OR public.is_admin())
WITH CHECK (profile_id = auth.uid() OR public.is_admin());

CREATE POLICY wallets_owner_admin ON public.wallets
FOR ALL TO authenticated
USING (profile_id = auth.uid() OR public.is_admin())
WITH CHECK (profile_id = auth.uid() OR public.is_admin());

REVOKE ALL ON public.vehicles, public.emergency_contacts, public.wallets FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vehicles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.emergency_contacts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wallets TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. Service requests: reads for participants; creation only through RPC;
-- status transitions controlled by the trigger and narrow column grants.
-- ----------------------------------------------------------------------------
CREATE POLICY service_requests_select_participants ON public.service_requests
FOR SELECT TO authenticated
USING (
    motorist_id = auth.uid()
    OR mechanic_id = auth.uid()
    OR public.is_admin()
);

CREATE POLICY service_requests_update_motorist ON public.service_requests
FOR UPDATE TO authenticated
USING (
    motorist_id = auth.uid()
    AND status IN ('created','searching','assigned')
)
WITH CHECK (
    motorist_id = auth.uid()
    AND status IN ('searching','cancelled')
);

CREATE POLICY service_requests_update_mechanic ON public.service_requests
FOR UPDATE TO authenticated
USING (
    mechanic_id = auth.uid()
    AND status IN ('assigned','en_route','arrived','diagnosing','quote_pending','servicing')
)
WITH CHECK (
    mechanic_id = auth.uid()
    AND status IN ('en_route','arrived','diagnosing','quote_pending','servicing','completed')
);

REVOKE ALL ON public.service_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.service_requests TO authenticated;
GRANT UPDATE (status, cancellation_reason, cancelled_at) ON public.service_requests TO authenticated;

-- ----------------------------------------------------------------------------
-- 6.1 Lifecycle and immutable-field trigger. RPC tokens are transaction-local.
-- ----------------------------------------------------------------------------
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
           OR NEW.search_radius_km NOT IN (5.00,7.50,10.00,12.50,15.00)
           OR NEW.search_radius_km <= OLD.search_radius_km
           OR NEW.search_radius_km - OLD.search_radius_km > 2.50 THEN
            RAISE EXCEPTION 'Search radius may only expand by one approved 2.5 km step through the expansion RPC.';
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
            IF NEW.status NOT IN ('cancelled','completed','searching') THEN
                RAISE EXCEPTION 'Invalid administrative target status.';
            END IF;

        ELSIF v_dispatch_token = 'accept_dispatch_offer'
              AND OLD.status = 'searching' AND NEW.status = 'assigned' THEN
            NULL;

        ELSIF v_quote_token = 'respond_to_quotation'
              AND OLD.status = 'quote_pending'
              AND NEW.status IN ('servicing','diagnosing') THEN
            NULL;

        ELSIF v_user = OLD.motorist_id THEN
            IF NEW.status = 'cancelled'
               AND OLD.status IN ('created','searching','assigned') THEN
                NULL;
            ELSE
                RAISE EXCEPTION 'Motorist cannot perform this service-request status transition.';
            END IF;

        ELSIF v_user = OLD.mechanic_id THEN
            IF (OLD.status = 'assigned' AND NEW.status = 'en_route')
               OR (OLD.status = 'en_route' AND NEW.status = 'arrived')
               OR (OLD.status = 'arrived' AND NEW.status = 'diagnosing')
               OR (OLD.status = 'diagnosing' AND NEW.status IN ('quote_pending','servicing'))
               OR (OLD.status = 'servicing' AND NEW.status = 'completed') THEN
                NULL;
            ELSE
                RAISE EXCEPTION 'Mechanic cannot perform this service-request status transition.';
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

REVOKE ALL ON FUNCTION public.check_service_request_mutation() FROM PUBLIC;

-- ----------------------------------------------------------------------------
-- 7. Dispatch offers: mechanics read only their offers. State changes only
-- through accept_dispatch_offer / reject_dispatch_offer RPCs.
-- ----------------------------------------------------------------------------
CREATE POLICY dispatch_offers_select_recipient_admin ON public.dispatch_offers
FOR SELECT TO authenticated
USING (mechanic_id = auth.uid() OR public.is_admin());

REVOKE ALL ON public.dispatch_offers FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.dispatch_offers TO authenticated;

-- ----------------------------------------------------------------------------
-- 8. Quotations: participants can read. All writes go through trusted RPCs.
-- ----------------------------------------------------------------------------
CREATE POLICY quotations_select_participants ON public.quotations
FOR SELECT TO authenticated
USING (
    mechanic_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.id = quotations.request_id
          AND sr.motorist_id = auth.uid()
    )
    OR public.is_admin()
);

REVOKE ALL ON public.quotations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.quotations TO authenticated;

-- ----------------------------------------------------------------------------
-- 9. Transactions: participants/admin can read. No client-side settlement writes.
-- ----------------------------------------------------------------------------
CREATE POLICY transactions_select_participants ON public.transactions
FOR SELECT TO authenticated
USING (
    motorist_id = auth.uid()
    OR mechanic_id = auth.uid()
    OR public.is_admin()
);

REVOKE ALL ON public.transactions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.transactions TO authenticated;

-- ----------------------------------------------------------------------------
-- 10. Reviews: public to authenticated users; only the motorist can create
-- one for their own completed request and assigned mechanic.
-- ----------------------------------------------------------------------------
CREATE POLICY reviews_select_authenticated ON public.reviews
FOR SELECT TO authenticated
USING (TRUE);

CREATE POLICY reviews_insert_motorist_completed ON public.reviews
FOR INSERT TO authenticated
WITH CHECK (
    motorist_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.service_requests sr
        WHERE sr.id = reviews.request_id
          AND sr.motorist_id = auth.uid()
          AND sr.mechanic_id = reviews.mechanic_id
          AND sr.status = 'completed'
    )
);

REVOKE ALL ON public.reviews FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.reviews TO authenticated;

-- ----------------------------------------------------------------------------
-- 11. Rate cards: readable by authenticated users; only admins can maintain.
-- ----------------------------------------------------------------------------
CREATE POLICY rate_cards_select_authenticated ON public.standard_rate_cards
FOR SELECT TO authenticated
USING (TRUE);

CREATE POLICY rate_cards_admin_write ON public.standard_rate_cards
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

REVOKE ALL ON public.standard_rate_cards FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.standard_rate_cards TO authenticated;

-- ----------------------------------------------------------------------------
-- 12. Audit logs: admins may read; inserts occur only inside trusted definer
-- functions. No UPDATE or DELETE policy or table privilege is granted.
-- ----------------------------------------------------------------------------
CREATE POLICY audit_logs_select_admin ON public.admin_audit_logs
FOR SELECT TO authenticated
USING (public.is_admin());

REVOKE ALL ON public.admin_audit_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.admin_audit_logs TO authenticated;

-- ----------------------------------------------------------------------------
-- 13. Ensure no client can directly alter protected verification fields or
-- role/verification flags. RPCs run as their owner and can update these fields.
-- ----------------------------------------------------------------------------
REVOKE ALL ON public.mechanic_profiles FROM anon;
REVOKE ALL ON public.mechanic_verifications FROM anon;
REVOKE ALL ON public.profiles FROM anon;
REVOKE ALL ON public.admin_audit_logs FROM anon;

-- End Migration 05.
