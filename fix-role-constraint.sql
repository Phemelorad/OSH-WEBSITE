-- ============================================================
-- FIX ROLE CONSTRAINT & ADD MISSING COLUMNS
-- Run this in Supabase SQL Editor if company or worker
-- registrations fail to create a user profile.
-- ============================================================

-- ── 1. Add designation column if missing ───────────────────
ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS designation TEXT;

COMMENT ON COLUMN user_profiles.designation IS 'Job title or designation (e.g. Safety Officer, Employer Representative)';

-- ── 2. Fix role check constraint to include company & worker ─
ALTER TABLE user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_role_check;

ALTER TABLE user_profiles
    ADD CONSTRAINT user_profiles_role_check
    CHECK (role IN ('viewer', 'officer', 'admin', 'super_admin', 'company', 'worker'));

-- ── 3. Update comment ─────────────────────────────────────
COMMENT ON COLUMN user_profiles.role IS 'User role: viewer, worker, officer, admin, super_admin, or company';

-- ── 4. Fix department constraint if still restrictive ──────
ALTER TABLE user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_department_check;

ALTER TABLE user_profiles
    ADD CONSTRAINT user_profiles_department_check
    CHECK (department IN ('osh', 'company', 'general'));

-- ── 5. Verify ──────────────────────────────────────────────
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'user_profiles'
ORDER BY ordinal_position;

SELECT
    connamespace::regnamespace::text as schema,
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_def
FROM pg_constraint
WHERE conrelid = 'user_profiles'::regclass
AND conname IN ('user_profiles_role_check', 'user_profiles_department_check');

SELECT '✅ Fix applied — company and worker roles are now allowed!' AS status;
