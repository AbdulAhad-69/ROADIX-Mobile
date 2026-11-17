# ROADIX — Backend & API Specification

**Status:** APPROVED DESIGN BASELINE (Phase 2 Deliverable)  
**Backend Principle:** Supabase-First, Stored Procedures for Atomic Consistency, Edge Functions for Privileged Tasks  

---

## 1. Client vs. Server Responsibilities Matrix

| Operational Capability | Client Responsibility | Server Responsibility (PostgreSQL / Edge) |
| :--- | :--- | :--- |
| **Emergency Triage Creation** | Collects user fault inputs, photos, coordinates; executes client-side validation. | Inserts `service_requests` row via RPC; initializes PostGIS dispatch worker. |
| **Mechanic Discovery** | Displays radar sonar animation on UI. | Executes `find_eligible_mechanics` spatial query; ranks candidates by SRS weights. |
| **Dispatch Offer & Acceptance** | Displays 45-second animated countdown; captures "Accept" tap. | **Authoritative clock:** enforces `expires_at`; atomically sets `assigned` status via row lock. |
| **Quotation Generation** | Inputs line items against standard schedule of rates. | Calculates stored `total_amount`; sets status `pending`; verifies prices. |
| **Quotation Approval** | Motorist taps "Approve" or "Reject". | Validates authorization; transitions request state to `servicing`. |
| **Payment & MFS Verification**| Triggers bKash/Nagad SDK / Webview checkout. | **Webhook verification:** validates digital signature from MFS gateway; marks settled. |
| **Emergency SOS (999)** | **Native OS dialer:** launches `tel:999` via device telephony. | Sends broadcast SMS alert to saved emergency contacts via Edge Function. |

---

## 2. PostgreSQL Stored Procedures (RPC Contracts)

All state-altering business operations execute through atomic PostgreSQL stored procedures:

### 2.1 `create_service_request`
Atomically creates a new breakdown request and generates a human-readable request code (`RDX-YYYY-XXXXX`).
```sql
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
AS $$
DECLARE
    v_request_id UUID;
    v_code TEXT;
    v_request_record RECORD;
BEGIN
    -- Generate sequential daily code: RDX-2026-XXXXX
    v_code := 'RDX-' || to_char(now(), 'YYYY') || '-' || lpad((floor(random() * 90000) + 10000)::text, 5, '0');

    INSERT INTO public.service_requests (
        request_code,
        motorist_id,
        breakdown_location,
        breakdown_address,
        vehicle_snapshot,
        fault_type,
        symptoms,
        diagnostic_notes,
        photo_urls,
        is_high_priority,
        status,
        search_radius_km
    ) VALUES (
        v_code,
        auth.uid(),
        ST_SetSRID(ST_MakePoint(p_breakdown_lng, p_breakdown_lat), 4326)::geography,
        p_breakdown_address,
        p_vehicle_snapshot,
        p_fault_type,
        p_symptoms,
        p_diagnostic_notes,
        p_photo_urls,
        p_is_high_priority,
        'searching',
        5.00
    )
    RETURNING id INTO v_request_id;

    SELECT id, request_code, status, created_at INTO v_request_record
    FROM public.service_requests WHERE id = v_request_id;

    RETURN to_jsonb(v_request_record);
END;
$$;
```

### 2.2 `accept_dispatch_offer` (Concurrency & Race-Condition Safe)
Ensures that only one candidate can accept a job offer, eliminating duplicate assignments.
```sql
CREATE OR REPLACE FUNCTION public.accept_dispatch_offer(
    p_request_id UUID,
    p_offer_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offer RECORD;
    v_request_status TEXT;
BEGIN
    -- 1. Lock the offer row
    SELECT * INTO v_offer
    FROM public.dispatch_offers
    WHERE id = p_offer_id AND mechanic_id = auth.uid()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Offer not found or unauthorized.';
    END IF;

    -- 2. Verify 45-second deadline has not elapsed
    IF now() > v_offer.expires_at THEN
        UPDATE public.dispatch_offers SET status = 'timed_out' WHERE id = p_offer_id;
        RAISE EXCEPTION 'Offer has expired.';
    END IF;

    -- 3. Lock the service request row to prevent race conditions
    SELECT status INTO v_request_status
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF v_request_status != 'searching' THEN
        UPDATE public.dispatch_offers SET status = 'cancelled' WHERE id = p_offer_id;
        RAISE EXCEPTION 'Request is no longer available (already assigned or cancelled).';
    END IF;

    -- 4. Atomically assign mechanic
    UPDATE public.service_requests
    SET mechanic_id = auth.uid(),
        status = 'assigned',
        assigned_at = now(),
        updated_at = now()
    WHERE id = p_request_id;

    -- 5. Mark offer accepted
    UPDATE public.dispatch_offers
    SET status = 'accepted',
        responded_at = now()
    WHERE id = p_offer_id;

    -- 6. Cancel any other pending offers for this request
    UPDATE public.dispatch_offers
    SET status = 'cancelled'
    WHERE request_id = p_request_id AND id != p_offer_id AND status = 'offered';

    RETURN TRUE;
END;
$$;
```

### 2.3 `update_mechanic_location` (Sub-Second Spatial Telemetry)
```sql
CREATE OR REPLACE FUNCTION public.update_mechanic_location(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.mechanic_profiles
    SET current_location = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
        updated_at = now()
    WHERE profile_id = auth.uid();
END;
$$;
```

---

## 3. Supabase Edge Functions Architecture

Edge Functions are written in TypeScript and execute on Deno close to users:

```text
supabase/functions/
├── dispatch-orchestrator/    # Evaluates expired 45s offers, expands search radius (5 -> 7.5 -> 10km)
├── payment-webhook/          # Verifies bKash/Nagad IPN (Instant Payment Notification) callbacks
└── push-notifier/            # Dispatches high-priority push messages via FCM v1 and APNs HTTP/2
```

### 3.1 `dispatch-orchestrator` Workflow
1. Triggered via database webhook or scheduled cron every 10 seconds.
2. Identifies all `service_requests` in `searching` status with expired offers (`now() > expires_at`).
3. Marks expired offers as `timed_out`.
4. Executes `find_eligible_mechanics` for the next eligible candidate in the queue.
5. If no candidates remain within `search_radius_km`, executes atomic radius expansion:
   $$\text{search\_radius\_km} = \min(\text{search\_radius\_km} + 2.50, 15.00)$$
6. Dispatches FCM high-priority push notification to the targeted mechanic.
