
-- ============================================================================
-- ROADIX MIGRATION 03: Service Requests, Dispatch Engine & Financial Entities
-- Baseline: Phase 04 Database Implementation
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Service Requests Table (Authoritative emergency lifecycle state machine)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.service_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_code TEXT UNIQUE NOT NULL,
    motorist_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    mechanic_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT,
    breakdown_location GEOGRAPHY(Point, 4326) NOT NULL,
    breakdown_address TEXT NOT NULL,
    vehicle_snapshot JSONB NOT NULL,
    fault_type TEXT NOT NULL,
    symptoms TEXT[] NOT NULL DEFAULT '{}',
    diagnostic_notes TEXT,
    photo_urls TEXT[] NOT NULL DEFAULT '{}',
    is_high_priority BOOLEAN NOT NULL DEFAULT FALSE,

    status TEXT NOT NULL DEFAULT 'created' CHECK (
        status IN (
            'created',
            'searching',
            'assigned',
            'en_route',
            'arrived',
            'diagnosing',
            'quote_pending',
            'servicing',
            'completed',
            'cancelled'
        )
    ),

    search_radius_km NUMERIC(4, 2) NOT NULL DEFAULT 5.00 CHECK (
        search_radius_km IN (5.00, 7.50, 10.00, 12.50, 15.00)
    ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_at TIMESTAMPTZ,
    arrived_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_service_requests_motorist
    ON public.service_requests(motorist_id);

CREATE INDEX IF NOT EXISTS idx_service_requests_mechanic
    ON public.service_requests(mechanic_id);

CREATE INDEX IF NOT EXISTS idx_service_requests_status
    ON public.service_requests(status);

CREATE INDEX IF NOT EXISTS idx_service_requests_location
    ON public.service_requests USING GIST(breakdown_location);

CREATE UNIQUE INDEX IF NOT EXISTS uq_mechanic_single_active_request
    ON public.service_requests(mechanic_id)
    WHERE status IN (
        'assigned',
        'en_route',
        'arrived',
        'diagnosing',
        'quote_pending',
        'servicing'
    );


-- ----------------------------------------------------------------------------
-- 2. Dispatch Offers Table (Strict sequential offers with 45s deadline)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.dispatch_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    mechanic_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    offer_radius_km NUMERIC(4, 2) NOT NULL CHECK (
        offer_radius_km IN (5.00, 7.50, 10.00, 12.50, 15.00)
    ),

    score NUMERIC(5, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'offered' CHECK (
        status IN ('offered', 'accepted', 'rejected', 'timed_out', 'cancelled')
    ),

    offered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '45 seconds'),
    responded_at TIMESTAMPTZ,

    CONSTRAINT uq_request_mechanic_offer
        UNIQUE (request_id, mechanic_id, offered_at)
);

CREATE INDEX IF NOT EXISTS idx_dispatch_offers_request
    ON public.dispatch_offers(request_id);

CREATE INDEX IF NOT EXISTS idx_dispatch_offers_mechanic_status
    ON public.dispatch_offers(mechanic_id, status);

CREATE INDEX IF NOT EXISTS idx_dispatch_offers_expires
    ON public.dispatch_offers(expires_at)
    WHERE status = 'offered';


-- ----------------------------------------------------------------------------
-- 3. Quotations Table (Itemized transparent repair estimates)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    mechanic_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,

    revision INTEGER NOT NULL DEFAULT 1,
    inspection_fee NUMERIC(10, 2) NOT NULL CHECK (inspection_fee >= 0),
    labor_fee NUMERIC(10, 2) NOT NULL CHECK (labor_fee >= 0),
    parts_fee NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (parts_fee >= 0),

    total_amount NUMERIC(10, 2)
        GENERATED ALWAYS AS (inspection_fee + labor_fee + parts_fee) STORED,

    parts_breakdown JSONB NOT NULL DEFAULT '[]'::jsonb,

    status TEXT NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'approved', 'rejected', 'superseded')
    ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,

    CONSTRAINT uq_request_revision UNIQUE (request_id, revision)
);

CREATE INDEX IF NOT EXISTS idx_quotations_request
    ON public.quotations(request_id);


-- ----------------------------------------------------------------------------
-- 4. Transactions Table (Settlement and digital escrow logs)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE RESTRICT,
    quotation_id UUID REFERENCES public.quotations(id) ON DELETE RESTRICT,
    motorist_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    mechanic_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,

    amount NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),

    method TEXT NOT NULL CHECK (method IN ('cash', 'bkash', 'nagad')),

    status TEXT NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'escrowed', 'settled', 'failed', 'refunded')
    ),

    gateway_trx_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    settled_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_transactions_request
    ON public.transactions(request_id);


-- ----------------------------------------------------------------------------
-- 5. Reviews Table (Post-rescue feedback & quality rating)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID UNIQUE NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    motorist_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    mechanic_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),

    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reviews_mechanic
    ON public.reviews(mechanic_id);


-- ----------------------------------------------------------------------------
-- 6. Standard Rate Cards Table (Benchmark reference prices for Dhaka)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.standard_rate_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fault_type TEXT NOT NULL,
    vehicle_type TEXT NOT NULL,

    base_callout_fee NUMERIC(10, 2) NOT NULL DEFAULT 300.00
        CHECK (base_callout_fee >= 0),

    base_inspection_fee NUMERIC(10, 2) NOT NULL DEFAULT 200.00
        CHECK (base_inspection_fee >= 0),

    base_labor_fee NUMERIC(10, 2) NOT NULL DEFAULT 500.00
        CHECK (base_labor_fee >= 0),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_rate_card_fault_vehicle
        UNIQUE (fault_type, vehicle_type)
);


-- ----------------------------------------------------------------------------
-- 7. Administrator Audit Logs Table (Accountability for platform staff)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,

    action TEXT NOT NULL,
    target_entity TEXT NOT NULL,
    target_id UUID,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin
    ON public.admin_audit_logs(admin_id);
