-- ============================================================
-- ALLOW OFFICERS TO VIEW ALL USER PROFILES
-- Run this in Supabase SQL Editor.
-- Required for the "Assign Inspector" feature on the
-- Inspection Bookings page so officers can select other
-- OSH officers from the database.
-- ============================================================

-- Allow officers, admins, and super_admins to SELECT all user_profiles
-- This is needed so the inspection bookings page can list available
-- officers for assignment.
DROP POLICY IF EXISTS "Officers can view all profiles" ON user_profiles;
CREATE POLICY "Officers can view all profiles"
    ON user_profiles FOR SELECT
    TO authenticated
    USING (
        -- The user is an officer/admin/super_admin themselves
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('officer', 'admin', 'super_admin')
        )
    );

-- Verify the policy was created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'user_profiles'
ORDER BY policyname;

SELECT '✅ Policy created successfully!' AS status;
