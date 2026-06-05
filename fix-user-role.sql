-- ============================================================
-- FIX USER ROLE MANUALLY
-- Run these queries in Supabase SQL Editor
--
-- Use this IF the user can't log in (forgotten password, etc.)
-- and the signIn auto-fix can't run.
-- ============================================================

-- ── 1. Find the user by email ────────────────────────────
-- Replace 'user@example.com' with the actual email
SELECT user_id, first_name, surname, email, role, department
FROM user_profiles
WHERE email = 'user@example.com';

-- ── 2. Fix the role ───────────────────────────────────────
-- Replace the email and role as needed
UPDATE user_profiles
SET role = 'company'
WHERE email = 'user@example.com'
  AND role != 'company';

-- ── 3. Verify the change ─────────────────────────────────
SELECT user_id, first_name, surname, email, role
FROM user_profiles
WHERE email = 'user@example.com';

-- ── 4. Also check all users by role (to see what's registered) ─
SELECT role, COUNT(*) as count
FROM user_profiles
GROUP BY role
ORDER BY role;

SELECT '✅ Done!' AS status;
