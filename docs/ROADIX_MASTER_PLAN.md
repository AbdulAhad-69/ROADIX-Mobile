# ROADIX — Master Engineering Plan & Production Roadmap

**Product:** ROADIX  
**Tagline:** HELP WHEN THE ROAD DOESN'T.  
**Team / Studio:** Studio Paradox  
**Initial Market:** Dhaka, Bangladesh  
**Architecture Baseline:** Flutter Mobile (Client) + Supabase (PostgreSQL, PostGIS, Auth, RLS, Realtime, Storage, Edge Functions)  
**Document Version:** 1.0.0 (Phase 0 Baseline)  

---

## 1. Executive Vision & Core Principles

ROADIX is a location-aware, emergency-first roadside assistance and mechanic dispatch platform built specifically for the traffic and infrastructure realities of Bangladesh, beginning in the Dhaka metropolitan area. 

### Core Product Principles
1. **Emergency-First Motorist Experience:** High-contrast, minimal-friction UI. A stranded motorist in a live highway lane must be able to request verified triage assistance within seconds without mandatory upfront multi-step account registration.
2. **Real Location-Aware Mechanic Matching:** Algorithmic matching using PostGIS spatial queries, candidate ranking, weighted heuristics, and dynamic radius expansion (5 km initial -> 2.5 km expansion steps).
3. **Verified Field Mechanics:** Mechanics are credentialed professionals (NID and workshop verification by Platform Administrators), operating on an on-duty/off-duty dispatch queue.
4. **Transparent & Enforced Quotations:** Transparent diagnostic estimates based on standard rate cards. Motorist must explicitly approve quotations before service commencement.
5. **Auditable Security & Data Isolation:** Complete Row Level Security (RLS) enforcement on all PostgreSQL tables. Zero exposure of privileged service-role keys to clients.
6. **Fault Tolerance under Unstable Connectivity:** Resilient local storage, automatic reconnection handling, and atomic database state transitions.
7. **Strict Zero-Budget Development Policy:** Zero paid SDKs, APIs, subscriptions, or paid hosting during development. Retain MapLibre & OpenFreeMap; modular simulated OTP delivery and mock MFS payment workflows.

---

## 2. Strategic Direction & Requirements Baseline

### 2.1 Strategy Reconciliation
- **Mobile-First Delivery:** supersedes earlier capstone/proposal drafts that envisioned web-first motorist interfaces. Emergency roadside triage requires native GPS, continuous location tracking, mobile network resilience, and telephony integration.
- **Unified Flutter Codebase:** One maintainable client application supporting role-aware navigation (Motorist, Mechanic, Administrator).
- **Supabase-First Backend:** Replaces ad-hoc custom servers with Supabase managed PostgreSQL, PostGIS spatial indexing, Supabase Auth, Row Level Security, Edge Functions, and Realtime channels.

### 2.2 User Roles
1. **Motorists:** Stranded drivers requesting help, tracking mechanics, approving quotes, and recording payments.
2. **Field Mechanics:** On-duty technicians receiving dispatch offers within a 45-second acceptance window, navigating to vehicles, and creating diagnostic quotes.
3. **Platform Administrators:** Operational staff verifying mechanic credentials (NID/trade license), monitoring city-wide radar, overseeing disputes, and configuring rates.

---

## 3. Engineering Phase Roadmap

Development is strictly phase-gated. Each phase requires verification and explicit approval before the next phase commences.

| Phase | Title | Primary Objective | Status |
| :---: | :--- | :--- | :---: |
| **0** | **Project Hygiene & Engineering Governance** | Clean repository, configure `.gitignore`, establish documentation structure, master plan | **COMPLETED (Awaiting Approval)** |
| **1** | **Complete Project Audit & Baseline Verification** | Validate audit findings, map every Dart file, confirm bug list and tech debt | **READY FOR EXECUTION** |
| **2** | **Final Architecture & Technical Design** | Produce ER diagrams, state machines, RLS specifications, dispatch algorithm | **NOT STARTED** |
| **3** | **Flutter Foundation & Architecture Migration** | Layered feature-first structure, domain entities, routing, error handling | **NOT STARTED** |
| **4** | **Identity, Authentication & User Management** | Anonymous motorist sessions, phone OTP auth, role management, RLS | **NOT STARTED** |
| **5** | **Motorist Emergency Experience** | Telemetry-preserved 4-step wizard, real Supabase request creation, live active state | **NOT STARTED** |
| **6** | **Automated Dispatch Engine** | PostGIS discovery, candidate ranking, 45s acceptance deadline, atomic assignment | **NOT STARTED** |
| **7** | **Mechanic Operations & Live Tracking** | Field mechanic dashboard, job acceptance, Realtime location broadcast, status lifecycle | **NOT STARTED** |
| **8** | **Quotations, Payments & Trust** | Itemized quotes, approval enforcement, bKash/Nagad sandbox integration, reviews | **NOT STARTED** |
| **9** | **Administrator & Operations Center** | Verification queue, city radar, active dispatch monitoring, manual dispatch overrides | **NOT STARTED** |
| **10**| **Quality, Security & Production Readiness** | Full test coverage (unit/widget/integration), load testing, release checklists | **NOT STARTED** |

---

## 4. Current Baseline (From Technical Audit)

The repository currently contains 26 Dart source files under `lib/` representing an early UI prototype:
- **Strengths:** Attractive "Showroom Porcelain" / "Caliper Crimson" visual styling; working `geolocator` GPS permission check; initial MapLibre vector tile rendering; basic CRUD helpers in `SupabaseService`.
- **Critical Technical Debt:**
  - **Single Shared Static Profile:** All queries locked to hardcoded UUID `a0000000-0000-0000-0000-000000000001`.
  - **Severed Telemetry:** Latitude and longitude coordinates from GPS/Map are dropped between Step 1 and Step 2 of the triage wizard.
  - **Severed Notes:** Diagnostic text entered in Step 3 is dropped before Step 4.
  - **Ghost Dependencies:** 8 declared packages in `pubspec.yaml` (`flutter_bloc`, `get_it`, `drift`, `dio`, `equatable`, `sqlite3_flutter_libs`, `path_provider`, `latlong2`) have 0 imports.
  - **Simulated Core Flow:** Mechanic matching, quotation, and live tracking are client-side mock timers and static strings.
  - **SOS 999 Non-Functional:** Countdown only shows a SnackBar; phone dialer is never launched.
  - **iOS Crash Defect:** Missing `NSLocationWhenInUseUsageDescription` in `ios/Runner/Info.plist`.

---

## 5. Risk Register & Mitigation Strategy

| Risk ID | Description | Impact | Mitigation Strategy |
| :---: | :--- | :--- | :--- |
| **R-01** | Unstable mobile 3G/4G connectivity on highway corridors | High | Implement offline persistence, local caching, idempotent requests, and reconnection queues. |
| **R-02** | Security breach via hardcoded credentials or bypassed RLS | Critical | Remove hardcoded keys, move secrets to environment, enforce strict RLS on all Postgres tables. |
| **R-03** | Race conditions / duplicate mechanic assignment | High | Enforce atomic assignment using PostgreSQL functions with row-level locks (`SELECT FOR UPDATE`). |
| **R-04** | iOS platform crash on location permission prompt | High | Add required privacy strings to `ios/Runner/Info.plist` before iOS execution. |
| **R-05** | Motorist friction during emergency breakdown | High | Support secure anonymous motorist sessions so help can be dispatched without upfront registration. |

---

## 6. Engineering Governance Rules

1. **Phase-Gated Development:** Complete every phase sequentially; present verification results; obtain explicit user approval before advancing.
2. **Preserve Working UI & Assets:** Retain existing custom branding, visual identity, and functioning components.
3. **No Speculative Implementations:** Zero fake mocks presented as functional code.
4. **Security by Design:** Never expose Supabase service-role keys in Flutter; validate all sensitive actions server-side.
5. **Database Integrity:** Atomic transactions, relational foreign keys, PostGIS indexes, and server-enforced timeouts.
6. **Git Discipline:** Keep generated build artifacts, machine configs, and credentials strictly out of version control.
