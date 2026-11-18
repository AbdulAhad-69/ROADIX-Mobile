-- ============================================================================
-- ROADIX LOCAL-ONLY COMPATIBILITY: Native PostgreSQL 18 + PostGIS
-- NOT a Supabase replacement. Run only against roadix_local_test.
-- This creates minimal auth schema shims so Migrations 02-05 can be tested.
-- Never run this file on remote Supabase.
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN BYPASSRLS;
    END IF;
END;
$$;

CREATE SCHEMA IF NOT EXISTS auth;

-- The user may already have created this compatibility table. Add only the
-- Supabase Auth columns needed by the ROADIX migrations.
CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

ALTER TABLE auth.users
    ADD COLUMN IF NOT EXISTS instance_id UUID,
    ADD COLUMN IF NOT EXISTS aud VARCHAR(255),
    ADD COLUMN IF NOT EXISTS role VARCHAR(255),
    ADD COLUMN IF NOT EXISTS email VARCHAR(255),
    ADD COLUMN IF NOT EXISTS encrypted_password VARCHAR(255),
    ADD COLUMN IF NOT EXISTS email_confirmed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS phone VARCHAR(255),
    ADD COLUMN IF NOT EXISTS raw_user_meta_data JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS raw_app_meta_data JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE TABLE IF NOT EXISTS auth.refresh_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        NULLIF(current_setting('request.jwt.claim.sub', TRUE), '')::UUID,
        (NULLIF(current_setting('request.jwt.claims', TRUE), '')::JSONB ->> 'sub')::UUID
    );
$$;

CREATE OR REPLACE FUNCTION auth.jwt()
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        NULLIF(current_setting('request.jwt.claims', TRUE), '')::JSONB,
        '{}'::JSONB
    );
$$;

GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.jwt() TO anon, authenticated, service_role;
GRANT SELECT ON auth.users TO authenticated, service_role;
GRANT SELECT, DELETE ON auth.refresh_tokens TO service_role;

-- For local tests, set claims in the same SQL session before calling an RPC:
-- SELECT set_config('request.jwt.claim.sub', '<user-uuid>', false);
-- SELECT set_config(
--   'request.jwt.claims',
--   '{"sub":"<user-uuid>","app_metadata":{"user_role":"motorist"}}',
--   false
-- );
--
-- This shim does NOT verify JWT signatures, issue tokens, implement OTP,
-- or reproduce Supabase Auth. It is strictly a local SQL test harness.
