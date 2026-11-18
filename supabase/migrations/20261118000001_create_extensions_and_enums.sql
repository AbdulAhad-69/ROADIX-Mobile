-- ============================================================================
-- ROADIX MIGRATION 01: Extensions and Core Configuration
-- Baseline: Phase 04 Database Implementation
-- Target Engine: PostgreSQL 15+ (Supabase)
-- ============================================================================

-- Enable essential extensions for UUID generation and cryptographic security
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;

-- Enable PostGIS for geospatial indexing, coordinate calculations and dispatch
CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA extensions;