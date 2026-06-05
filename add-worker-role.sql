-- ============================================================
-- ADD WORKER ROLE TO DATABASE
-- Run this in Supabase SQL Editor
-- ============================================================

-- ── Update the role check constraint to include 'worker' ────
ALTER TABLE user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_role_check;

ALTER TABLE user_profiles
    ADD CONSTRAINT user_profiles_role_check
    CHECK (role IN ('viewer', 'officer', 'admin', 'super_admin', 'company', 'worker'));

-- ── Update the department constraint for workers ────────────
-- Worker departments can be 'general' (already allowed)

-- ── Update comment ─────────────────────────────────────────
COMMENT ON COLUMN user_profiles.role IS 'User role: viewer, worker, officer, admin, super_admin, or company';

-- ── Verify ─────────────────────────────────────────────────
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'user_profiles' AND column_name = 'role';

SELECT
    connamespace::regnamespace::text as schema,
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_def
FROM pg_constraint
WHERE conrelid = 'user_profiles'::regclass
AND conname = 'user_profiles_role_check';

SELECT '✅ Worker role added successfully!' AS status;
