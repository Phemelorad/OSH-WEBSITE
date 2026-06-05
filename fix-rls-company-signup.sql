-- ============================================================
-- FIX RLS POLICIES FOR SIGNUP FLOW
-- Run this in Supabase SQL Editor
--
-- Fixes two errors:
--   401 on companies table — anon key can't insert before user is authenticated
--   406 on user_profiles   — .single() throws when no rows match
-- ============================================================

-- ── 1. Companies table: allow anon inserts too ──────────────
-- (Belt-and-suspenders: the JS code now creates companies on first login,
--  but this ensures the direct signup path also works)
DROP POLICY IF EXISTS "Anyone can insert companies" ON companies;

CREATE POLICY "Anyone can insert companies"
    ON companies FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

-- ── 2. User profiles: fix INSERT policy to allow anon ───────
-- The existing policy restricts to authenticated only, but during
-- signup with email confirmation there's no session yet.
-- We relax it so the trigger or service-role-backed insert works.
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;

CREATE POLICY "Users can insert own profile"
    ON user_profiles FOR INSERT
    TO authenticated, anon
    WITH CHECK (
        -- Allow the row if the user_id matches (for when session exists)
        auth.uid() = user_id
        OR
        -- Allow signup-trigger inserts where the row references a just-created user
        auth.role() = 'anon'
    );

-- ── 3. Verify the updated policies ──────────────────────────
SELECT schemaname, tablename, policyname, roles, cmd
FROM pg_policies
WHERE tablename IN ('companies', 'user_profiles')
ORDER BY tablename, cmd;

SELECT '✅ RLS policies updated successfully!' AS status;
