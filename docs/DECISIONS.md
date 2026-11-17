# ROADIX — Architecture Decision Records (ADR)

This document tracks all formal architectural and technical decisions made during the ROADIX engineering lifecycle.

---

## ADR-001: Mobile-First Engineering Strategy
- **Status:** APPROVED
- **Date:** 2026-11-17
- **Context:** Previous academic and capstone documents suggested a web-first deployment approach. However, ROADIX is an emergency roadside assistance platform where stranded drivers require high-accuracy GPS telemetry, offline resilience under poor cellular reception, native telephony dialer integration (999), and live tracking.
- **Decision:** ROADIX is strictly mobile-first. Flutter is the primary client technology delivering a unified mobile application for Motorists, Field Mechanics, and Administrators.
- **Consequences:** Focuses initial development on mobile device capabilities. Web application and desktop admin dashboards are positioned for responsive extensions or later phases.

---

## ADR-002: Supabase-First Backend Architecture
- **Status:** APPROVED
- **Date:** 2026-11-17
- **Context:** Building and maintaining a custom Node.js/Express or NestJS backend introduces operational overhead, custom authentication vulnerabilities, and infrastructure maintenance costs.
- **Decision:** Utilize Supabase as the unified backend infrastructure:
  - **Database:** PostgreSQL with PostGIS extension for geospatial queries and mechanic discovery.
  - **Security:** Strict Row Level Security (RLS) on all user-facing tables.
  - **Auth:** Supabase Auth supporting anonymous motorist sessions and phone-based OTP.
  - **Business Logic:** PostgreSQL stored procedures for atomic assignments, alongside Supabase Edge Functions (Deno/TypeScript) for privileged server tasks (dispatch deadlines, payment verification).
  - **Realtime:** Supabase Realtime channels for live technician telemetry and dispatch status transitions.
- **Consequences:** Eliminates external server maintenance; centralizes business rules around PostgreSQL security and transactions.

---

## ADR-003: Phase-Gated Engineering Governance
- **Status:** APPROVED
- **Date:** 2026-11-17
- **Context:** Large architectural transformations risk introducing regressions, uncontrolled scope creep, or untested assumptions.
- **Decision:** All engineering follows a strict 10-phase sequential roadmap. At the end of every phase, a standardized verification report is delivered, and execution halts until explicit user approval is granted.
- **Consequences:** Prevents runaway implementations and guarantees that each milestone is verified before proceeding.

---

## ADR-004: Preservation of Existing UI Assets and Branding
- **Status:** APPROVED
- **Date:** 2026-11-17
- **Context:** The existing mobile codebase already has a well-crafted visual identity ("Showroom Porcelain" and "Caliper Crimson") with custom styling, icons, and layout structures.
- **Decision:** Re-use and refactor existing screen layouts and UI components rather than discarding them. Focus development on fixing broken data flows, introducing domain models, and wiring real backend services.
- **Consequences:** Maximizes reuse of design work while focusing engineering effort on reliability and backend integration.

---

## ADR-005: State Management Architecture: Adoption of Riverpod
- **Status:** APPROVED
- **Date:** 2026-11-17
- **Context:** Phase 1 revealed that while `flutter_bloc` was listed in `pubspec.yaml`, it was never imported or used. The team needs an idiomatic, testable, and lightweight state management solution for the refactored architecture.
- **Alternatives Considered:**
  1. *flutter_bloc:* Highly structured, but requires heavy boilerplate (Events, States, Blocs) and separate dependency injection (`get_it`).
  2. *Provider:* Older, lacks compile-time safety for provider combinations, prone to `ProviderNotFoundException`.
  3. *flutter_riverpod:* Modern, compile-time safe, built-in dependency injection, native `AsyncValue` for loading/error states, auto-dispose of location streams and timers.
- **Decision:** Adopt `flutter_riverpod` (v2.6+) as the project-wide state management and dependency injection framework.
- **Consequences:** `flutter_bloc` and `get_it` will be removed in Phase 3. Reduces boilerplate by ~40% while enhancing testability.

---

## ADR-006: Navigation Architecture: Declarative `go_router`
- **Status:** APPROVED
- **Date:** 2026-11-17
- **Context:** Current code uses imperative `Navigator.push(MaterialPageRoute(...))` chains, which caused critical data loss (dropped GPS coordinates and dropped triage notes) and makes role-based protection impossible.
- **Decision:** Adopt declarative routing using `go_router`. All navigation is governed by URL-like paths with centralized redirect guards observing the user's authentication and role status.
- **Consequences:** Guarantees that unverified mechanics cannot accept jobs, unauthenticated motorists enter anonymous emergency mode cleanly, and deep links function properly.

---

## ADR-007: Geospatial Engine & Map Display: MapLibre GL & OpenFreeMap
- **Status:** APPROVED
- **Date:** 2026-11-17
- **Context:** Google Maps SDK imposes expensive commercial billing per map load and requires proprietary API keys. Mapbox has strict commercial billing tiers.
- **Decision:** Standardize on `maplibre_gl` with OpenFreeMap vector tiles (`https://tiles.openfreemap.org/styles/liberty`) for client display, backed by PostGIS on PostgreSQL for all server-side geospatial distance queries.
- **Consequences:** Zero licensing cost, open-source vector rendering, and sub-millisecond database spatial queries via PostGIS GiST indexes.

---

## ADR-008: Concurrency & Dispatch Locking via PostgreSQL Stored Functions
- **Status:** APPROVED
- **Date:** 2026-11-17
- **Context:** In emergency dispatch, multiple mechanics might receive offers in quick succession. Without atomic locking, two mechanics could accept the same breakdown, causing conflicting dispatches.
- **Decision:** Implement atomic mechanic assignment inside the PostgreSQL stored procedure `accept_dispatch_offer` using pessimistic row locks (`SELECT ... FOR UPDATE`).
- **Consequences:** 100% concurrency-safe. The database guarantees that only one candidate can ever transition a request from `searching` to `assigned`.

---

## ADR-009: Anonymous Motorist Sessions with Post-Rescue Linking
- **Status:** APPROVED
- **Date:** 2026-11-17
- **Context:** Forcing a panicked driver with a blown tire on a highway to register an account, create a password, or verify an email creates unacceptable friction and churn.
- **Decision:** Motorists enter the app with an automatic anonymous session (`supabase.auth.signInAnonymously()`). After the rescue is resolved, the motorist can optionally link their phone number via OTP (`auth.linkIdentity()`), converting their anonymous account to permanent.
- **Consequences:** Frictionless emergency entry with zero data loss or security compromise.


---

## ADR-010: Strict Zero-Budget Development Policy
- **Status:** APPROVED
- **Date:** 2026-11-17
- **Context:** To ensure the project remains completely free, reproducible, and self-contained during development, a strict zero-budget directive has been mandated.
- **Decision:**
  1. **Map Services:** Retain the existing `maplibre_gl` and OpenFreeMap vector tile integration (`https://tiles.openfreemap.org/styles/liberty`). Never introduce Mapbox or Google Maps SDKs.
  2. **Dependencies:** Strictly prefer open-source, MIT/BSD-licensed, and self-hostable libraries. Zero paid SDKs or subscription dependencies.
  3. **SMS / Auth:** Do not require paid SMS gateways (Twilio, Greenweb) during development. Implement local simulated OTP delivery / in-app debug OTP viewing for phone authentication.
  4. **Payments:** Implement modular mock sandbox payment flows for bKash and Nagad. Keep payment interfaces decoupled so real production payment aggregators can be plugged in later without rewriting core logic.
  5. **Backend & Hosting:** Utilize Supabase Free Tier (PostgreSQL, PostGIS, Auth, Storage, Realtime, Edge Functions). Never characterize free tier limits as unlimited production capacity.
- **Consequences:** Eliminates all operating costs during development while preserving a clean, modular architecture ready for commercial expansion.
