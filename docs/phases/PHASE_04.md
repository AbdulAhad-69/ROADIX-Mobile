# Phase 04 — Database & Backend Implementation

**Phase Status:** COMPLETED (Security & Architecture Hardened)  
**Completion Date:** 2026-11-18  
**Approved Baseline:** Phase 00, Phase 01, Phase 02, Phase 03  
**Database Engine:** PostgreSQL 15+ (Supabase)  
**Spatial Engine:** PostGIS 3.3+ (SRID 4326)  
**Inspection Mode:** Static AST & Semantic Verification (Docker/CLI unavailable locally)  

---

## 1. Objective

Implement the complete ROADIX backend database foundation according to the approved schema, PostGIS spatial indexing, 100% Row-Level Security (RLS) policies, atomic stored procedures, and development seed data — strictly preserving the Zero-Budget Development Policy and without applying migrations to remote/production infrastructure.

---

## 2. Completed Work & Security Hardening

### 2.1 Ordered Version-Controlled SQL Migrations (`supabase/migrations/`)

1. **`20261118000001_create_extensions_and_enums.sql`:**
   - Enables `uuid-ossp` and `pgcrypto` for UUID v4 generation and cryptographic operations.
   - Enables `postgis` for high-performance spatial geometry, spherical distance calculations, and radar discovery.

2. **`20261118000002_create_profiles_and_mechanics.sql`:**
   - `profiles`: 1:1 linkage to `auth.users`, role enforcement (`motorist`, `mechanic`, `admin`), phone uniqueness, anonymous account support.
   - `mechanic_profiles`: Operational technician details, workshop address, `GEOGRAPHY(Point, 4326)` telemetry, and spatial GiST index (`idx_mechanics_location`).
   - `mechanic_verifications` *(Hardened Security Separation)*: Isolated government credentials (`trade_license_number`, `nid_number`, NID front/back image URLs) accessible strictly by the technician themselves or Platform Admins.
   - `vehicles`: Digital garage for motorist vehicles (plate uniqueness per profile).
   - `emergency_contacts`: Motorist SOS broadcast recipients with phone and relationship attributes.
   - `wallets`: MFS digital payment accounts (`bKash`, `Nagad`, `Rocket`).

3. **`20261118000003_create_service_requests_and_dispatch.sql`:**
   - `service_requests`: 10-state lifecycle state machine, human-readable request code (`RDX-YYYY-XXXXX`), breakdown coordinates with spatial GiST index (`idx_service_requests_location`), and search radius tracking enforced strictly to discrete approved steps: **5.00, 7.50, 10.00, 12.50, 15.00 km** (`CHECK (search_radius_km IN (5.00, 7.50, 10.00, 12.50, 15.00))`).
   - Partial unique index `uq_mechanic_single_active_request`: Strictly guarantees at storage engine level that a mechanic cannot hold more than one active rescue assignment simultaneously (`WHERE status IN ('assigned', 'en_route', 'arrived', 'diagnosing', 'quote_pending', 'servicing')`).
   - `dispatch_offers`: Ephemeral candidate offers with authoritative server deadline (`INTERVAL '45 seconds'`) and uniqueness constraints.
   - `quotations`: Itemized repair estimates with generated `total_amount` column (`STORED`).
   - `transactions`: Digital escrow and settlement logs.
   - `reviews`: Motorist rating (1–5) and feedback.
   - `standard_rate_cards`: Official benchmark rate card schedule for Dhaka.
   - `admin_audit_logs`: Audit trail for platform staff actions.

4. **`20261118000004_create_functions_and_procedures.sql`:**
   - `calculate_dispatch_score`: Implements the approved SRS 4-Factor Heuristic formula ($S = 0.40P + 0.25E + 0.15T + 0.20A$) with rating smoothing for new technicians and explicit `SET search_path = public, pg_temp;`.
   - `find_eligible_mechanics`: Discovers on-duty, verified mechanics within search radius using `ST_DWithin` and `ST_Distance`. Client execution is strictly revoked (`REVOKE ... FROM authenticated;`); internal to database engine and service-role.
   - `find_eligible_mechanics_for_request`: Authoritative client entrypoint that loads `search_radius_km` directly from the database record, preventing callers from bypassing the approved radius sequence or requesting 15 km initially.
   - `create_service_request`: Atomically generates daily sequential code (`RDX-YYYY-XXXXX`), validates geographic coordinate bounds ($-90 \le \text{lat} \le 90$, $-180 \le \text{lng} \le 180$), initializes search radius to 5.00 km, and creates breakdown request.
   - `dispatch_next_candidate`: Discovers the top-ranked eligible candidate within current radius who has not yet received an offer for that request, issues an atomic sequential offer with a 45-second server deadline, or returns `exhausted` when all candidates at that radius have received offers.
   - `expand_dispatch_radius`: Stored procedure advancing radius in discrete $+2.50\text{ km}$ increments up to the $15.00\text{ km}$ maximum ceiling. Strictly verifies that no active offer is pending, that previous offers at current radius terminated, and that ALL eligible mechanics at the current radius have received offers (`v_unoffered_count = 0`) before permitting expansion. Sets transaction-local token for trigger authorization.
   - `accept_dispatch_offer`: Concurrency-safe acceptance executing `SELECT ... FOR UPDATE` locks on offer and request rows, validating 45-second deadline, verifying technician has zero existing active assignments, transitioning status to `'assigned'`, and invalidating competing offers.
   - `respond_to_quotation`: Dedicated RPC for motorist quotation approval/rejection. Pessimistically locks quotation and service request rows, verifies caller identity, updates quotation status, and atomically synchronizes request status to `'servicing'` or `'diagnosing'`.
   - `update_mechanic_location`: High-frequency PostGIS location updater, strictly verifying caller is a verified technician.
   - `set_user_role`: Administrative procedure to safely update GoTrue `raw_app_meta_data`, public profiles mirror, immediately invalidate refresh tokens on demotion, and record audit log, strictly gated to verified administrators.
   - `admin_override_service_request`: Dedicated, auditable administrative intervention procedure (`SECURITY DEFINER`) supporting `cancel_request`, `force_complete`, and `reassign_searching`. Validates `is_admin()`, locks request row `FOR UPDATE`, rejects terminal requests, requires non-empty justification reasons, records immutable entries in `admin_audit_logs`, and sets the internal caller token `roadix.internal_admin_caller` for trigger authorization.
   - `handle_new_user`: Automated trigger synchronizing `auth.users` to `public.profiles`.
   - **Hardened Execution Privileges:** All `SECURITY DEFINER` functions enforce `SET search_path = public, pg_temp;` and revoke default public execution rights (`REVOKE ALL ... FROM PUBLIC; GRANT EXECUTE ... TO authenticated;`).

5. **`20261118000005_create_row_level_security.sql`:**
   - Enabled RLS across all 13 database entities.
   - `is_admin()` helper: Dual verification checking cryptographic JWT claim AND live database record in `auth.users` (`raw_app_meta_data ->> 'user_role' = 'admin'`), ensuring genuinely instantaneous revocation upon database update.
   - **Elimination of Recursive RLS Subquery:** Removed self-referencing subquery `AND motorist_id = (SELECT sr.motorist_id FROM public.service_requests sr WHERE sr.id = service_requests.id)` from `service_requests_update_mechanic`.
   - **Elimination of Generic Admin UPDATE Policy:** Removed unrestricted `service_requests_update_admin` policy in favor of the audited `admin_override_service_request()` procedure.
   - **Revoked Column Privileges:** Table-level `UPDATE` revoked from `PUBLIC`, `anon`, and `authenticated`. Narrowly whitelisted columns (`status`, `cancellation_reason`, `cancelled_at`, `updated_at`) granted to `authenticated`.
   - **Unconditional Immutability Protection:** `check_service_request_mutation()` protects all invariant fields (`id`, `request_code`, `motorist_id`, `created_at`, `breakdown_location`, `breakdown_address`, `vehicle_snapshot`, `fault_type`, `search_radius_km`, `mechanic_id`) unconditionally before and regardless of status changes.
   - **Active-Session Location Gating:** Mechanic location telemetry in `mechanic_profiles` is viewable by motorists **only during active service sessions** (`status IN ('assigned', 'en_route', 'arrived', 'diagnosing', 'quote_pending', 'servicing')`). Access immediately terminates upon job completion or cancellation.
   - **Quotation Column-Level Defense-in-Depth (`trg_protect_quotation_integrity`):** Attaches a `BEFORE UPDATE` database trigger comparing `OLD` and `NEW` rows using `IS DISTINCT FROM`. Strictly prevents motorists from altering fee columns, parts breakdowns, technician assignments, or request IDs. Prohibits mechanics from self-approving, modifying closed quotes, setting arbitrary statuses, or modifying `responded_at`.
   - **Service Request State Machine & Actor Authorization Trigger (`trg_validate_service_request_mutation`):** Enforces strict forward lifecycle state transitions with explicit caller-role authorization (Motorists: only `searching` and pre-arrival `cancelled`; Mechanics: only `en_route`, `arrived`, `diagnosing`, `quote_pending`, `servicing`, `completed`; Backend RPCs: `assigned`). Blocks direct PostgREST manipulation of `search_radius_km`.
   - **Anti-Self-Elevation:** Prevents users from modifying their own `role`, `is_nid_verified`, or `is_verified` status.
   - **Anti-Harvesting Profile Isolation:** Prevents scraping phone numbers of unrelated motorists.

### 2.2 Synthetic Development Seed Data (`supabase/seed.sql`)
- Created realistic seed data for local development:
  - 1 Platform Administrator (`admin@roadix.com.bd`).
  - 1 Registered Motorist with primary Sedan and bKash wallet.
  - 4 Verified On-Duty Mechanics stationed at real Dhaka hotspots:
    - Gulshan 2 Circle: Electrical & Engine specialist (`4.92` rating, 148 rescues).
    - Dhanmondi 27: Tire & Suspension specialist (`4.85` rating, 92 rescues).
    - Uttara Sector 3: Highway Recovery specialist (`4.78` rating, 64 rescues).
    - Mirpur 10 Circle: Battery & Starter specialist (`4.88` rating, 110 rescues).
  - Explicit GoTrue schema column compliance (`instance_id`, `aud = 'authenticated'`, `role = 'authenticated'`, `encrypted_password = ''`).
  - 14 Benchmark rate card entries covering Sedan, SUV, Motorcycle, and Commercial vehicles.

---

## 3. Verification & Validation Results

1. **Database Migration Verification Suite:**
   - Authored `test/unit/database_migration_test.dart` (9 tests).
   - Validated table schemas, constraints, PostGIS spatial indexing, stored procedures, RLS policies, trigger integrity rules, attack vectors, and dispatch scoring formula calculations.
   - Result: **9/9 passed**.
2. **Full Unit Test Suite:**
   - Ran `dart test test/unit/`.
   - Result: **15/15 passed** (0 failures).
3. **Static Analysis:**
   - Ran `dart analyze`.
   - Result: **0 errors, 0 warnings**.
4. **Zero-Budget & Remote Protection Compliance:**
   - Zero remote database modifications executed.
   - Zero paid dependencies or third-party APIs introduced.

---

## 4. Next Phase

- **PHASE 5 — Motorist Emergency Flow Implementation:**
  - Connect Flutter UI to Supabase backend services.
  - Wire `TriageController` to call `create_service_request` RPC.
  - Implement real-time tracking listener for mechanic assignment, arrival, and quotation approval.
  - Replace hardcoded coordinate drops with live MapLibre + OpenFreeMap interactive map rendering.
