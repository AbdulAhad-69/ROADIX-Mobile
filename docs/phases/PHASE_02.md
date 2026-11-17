# Phase 02 — Final Architecture and Technical Design

**Phase Status:** COMPLETED (Awaiting Approval to proceed to Phase 3)  
**Executed Date:** November 17, 2026  
**Lead Architect:** Lead Software Architect & Technical Project Manager  
**Primary Deliverables:** ARCHITECTURE.md, DATABASE_DESIGN.md, SECURITY_MODEL.md, API_AND_BACKEND.md, DISPATCH_ENGINE.md, REALTIME_AND_NOTIFICATIONS.md, DECISIONS.md  

---

## 1. Objective
Establish a complete, internally consistent, production-oriented technical design for ROADIX based on the approved mobile-first, multi-role (Motorist, Mechanic, Admin), Supabase-first direction. Deliver the complete database schema, security rules, state machines, and dispatch algorithms without modifying any application source code.

---

## 2. Completed Work & Design Deliverables

### 2.1 System Architecture ([`docs/ARCHITECTURE.md`](../ARCHITECTURE.md))
- Designed the layered **Feature-First Architecture** (`presentation`, `application`, `domain`, `data`) under `lib/src/features/`.
- Selected **`flutter_riverpod`** for state management and dependency injection, replacing the unused `flutter_bloc` and `get_it`.
- Designed declarative **`go_router`** navigation with role-based redirect guards (Motorist, Unverified Mechanic, Verified Mechanic, Administrator).
- Formulated the central state preservation pattern to eliminate the Phase 1 GPS/triage notes drop bugs.

### 2.2 Database Design & PostGIS Schema ([`docs/DATABASE_DESIGN.md`](../DATABASE_DESIGN.md))
- Produced the complete Mermaid Entity-Relationship Diagram (12 entities).
- Drafted production-ready SQL DDL with primary keys, foreign keys, CHECK constraints, and generated columns.
- Configured **PostGIS GiST spatial indexing** on `mechanic_profiles.current_location` and `service_requests.breakdown_location`.
- Authored the stored function `find_eligible_mechanics` for radial distance queries via `ST_DWithin`.

### 2.3 Security Model & RLS Policies ([`docs/SECURITY_MODEL.md`](../SECURITY_MODEL.md))
- Designed **Anonymous Motorist Sessions** (`supabase.auth.signInAnonymously()`) enabling zero-friction breakdown requests with late phone linking.
- Authored production-ready Row Level Security (RLS) policies for 100% of tables.
- Defined storage bucket access policies for `diagnostic_photos` and `mechanic_documents`.
- Specified compile-time secret injection (`--dart-define-from-file=.env`) to eliminate hardcoded credentials in source code.

### 2.4 Backend & API Contracts ([`docs/API_AND_BACKEND.md`](../API_AND_BACKEND.md))
- Defined the client vs. server responsibility matrix.
- Authored atomic PostgreSQL stored procedures (`create_service_request`, `accept_dispatch_offer`, `update_mechanic_location`).
- Designed Supabase Edge Functions (`dispatch-orchestrator`, `payment-webhook`, `push-notifier`).

### 2.5 Dispatch Engine Specification ([`docs/DISPATCH_ENGINE.md`](../DISPATCH_ENGINE.md))
- Formalized the SRS 4-factor candidate suitability formula:
  $$S = (0.40 \times P) + (0.25 \times E) + (0.15 \times T) + (0.20 \times A)$$
- Designed radial search expansion: 5.0 km initial -> +2.5 km expansion steps up to 15.0 km ceiling.
- Designed the authoritative 45-second deadline countdown and concurrency-safe pessimistic row locking (`SELECT FOR UPDATE`).

### 2.6 Request Lifecycle State Machine ([`docs/REALTIME_AND_NOTIFICATIONS.md`](../REALTIME_AND_NOTIFICATIONS.md))
- Defined the authoritative 10-state lifecycle: `created` -> `searching` -> `assigned` -> `en_route` -> `arrived` -> `diagnosing` -> `quote_pending` -> `servicing` -> `completed` (or `cancelled`).
- Designed Supabase Realtime channel topology for sub-second mechanic GPS tracking.
- Designed dual-channel fallback to high-priority FCM v1 / APNs push notifications when mobile apps are backgrounded.

### 2.7 Architecture Decision Records ([`docs/DECISIONS.md`](../DECISIONS.md))
- Documented ADR-001 through ADR-009 covering all core trade-offs.

---

## 3. Files Created or Modified

| File Path | Action | Description |
| :--- | :--- | :--- |
| [`docs/ARCHITECTURE.md`](file:///c:/Users/aahad/ROADIX-Mobile/docs/ARCHITECTURE.md) | **Updated** | Layered feature-first architecture, Riverpod state design, go_router role hierarchy. |
| [`docs/DATABASE_DESIGN.md`](file:///c:/Users/aahad/ROADIX-Mobile/docs/DATABASE_DESIGN.md) | **Updated** | Full PostGIS ERD, 12 table DDL definitions, GiST indexes, spatial functions. |
| [`docs/SECURITY_MODEL.md`](file:///c:/Users/aahad/ROADIX-Mobile/docs/SECURITY_MODEL.md) | **Updated** | Anonymous auth, Phone OTP, comprehensive RLS policy statements, storage rules. |
| [`docs/API_AND_BACKEND.md`](file:///c:/Users/aahad/ROADIX-Mobile/docs/API_AND_BACKEND.md) | **Updated** | PostgreSQL stored procedures, Edge Functions, client/server boundary. |
| [`docs/DISPATCH_ENGINE.md`](file:///c:/Users/aahad/ROADIX-Mobile/docs/DISPATCH_ENGINE.md) | **Updated** | SRS 4-factor formula, 45s offer countdown, radial expansion rules. |
| [`docs/REALTIME_AND_NOTIFICATIONS.md`](file:///c:/Users/aahad/ROADIX-Mobile/docs/REALTIME_AND_NOTIFICATIONS.md) | **Updated** | 10-state machine, Realtime tracking channel, FCM/APNs push architecture. |
| [`docs/DECISIONS.md`](file:///c:/Users/aahad/ROADIX-Mobile/docs/DECISIONS.md) | **Updated** | Formal ADRs 001 to 009. |
| [`docs/phases/PHASE_02.md`](file:///c:/Users/aahad/ROADIX-Mobile/docs/phases/PHASE_02.md) | **Created** | Phase 2 completion report, decisions summary, and open questions. |

*Zero application source code, dependencies, or database migrations were modified.*

---

## 4. Summary of Final Architectural Decisions

1. **State Management & DI:** `flutter_riverpod` (v2.6+) adopted. Unused `flutter_bloc` and `get_it` will be pruned in Phase 3.
2. **Navigation:** Declarative `go_router` with centralized auth and role redirect guards.
3. **Map Rendering & Geolocation:** MapLibre GL with OpenFreeMap vector tiles on mobile; PostGIS on PostgreSQL for all server-side spatial calculations.
4. **Authentication:** Dual-track: Anonymous motorist sessions for immediate breakdown access with post-rescue phone linking; Phone OTP for mechanics and administrators.
5. **Concurrency & Dispatch:** Sequential 1:1 offers with 45-second server deadlines and pessimistic row locking (`SELECT FOR UPDATE`).

---

## 5. Unresolved Questions Requiring User Input

1. **SMS Gateway Provider for Bangladesh Phone OTP:**
   Supabase Auth supports Twilio, MessageBird, or custom SMS webhooks. In Bangladesh, local aggregators (e.g. Greenweb, SSL Wireless, Banglalink, Grameenphone) are often used for high OTP delivery rates. Do you intend to use standard Supabase Twilio integration or a local Bangladesh SMS aggregator webhook?
2. **MFS Payment Gateway Sandbox:**
   For Phase 8, should we prioritize bKash Tokenized Checkout API or an aggregator like SSLCommerz sandbox which bundles both bKash and Nagad in a single integration?
3. **Admin Web vs Mobile App:**
   The directive specifies a unified Flutter codebase. Do you want the Administrator operations radar to run as a responsive tablet/desktop layout inside the same Flutter app, or will a dedicated Flutter Web build be deployed for back-office operators?

---

## 6. Proposed Implementation Sequence (Phase 3 Onward)

- **Phase 3:** Establish the layered feature-first folder structure (`lib/src/`), prune unused dependencies from `pubspec.yaml`, configure compile-time environment variables, add missing iOS location strings in `Info.plist`, and build immutable domain entities.
- **Phase 4:** Implement Supabase Auth (Anonymous motorist + Phone OTP), user profiles, and apply RLS policies.
- **Phase 5:** Rebuild motorist emergency wizard with state preservation (fixing the lost GPS coordinates and dropped notes).
- **Phase 6:** Implement the PostGIS automated dispatch engine and candidate ranking.
- **Phase 7:** Implement the field mechanic portal and Realtime live tracking.
- **Phase 8:** Implement quotation approval enforcement and payment sandbox.
- **Phase 9:** Build administrator operations center.
- **Phase 10:** End-to-end verification and production release.

---

## 7. Verification & Immutability Check
- Confirmed that no `.dart` files in `lib/` were modified.
- Confirmed that `pubspec.yaml` was not modified.
- Confirmed that no database migrations were executed.
- Confirmed that all 8 required design deliverables are fully drafted, verified, and cross-referenced in `docs/`.
