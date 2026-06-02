-- ============================================
-- FIX RLS POLICY TO ALLOW VIEWING ALL USERS
-- This allows the admin panel to see all registered users
-- ============================================

-- Drop the old restrictive SELECT policy
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;

-- Create new policy that allows all authenticated users to view all profiles
CREATE POLICY "Authenticated users can view all profiles"
    ON user_profiles 
    FOR SELECT 
    TO authenticated
    USING (true);

-- Keep other policies for INSERT and UPDATE (users can only modify their own)
-- These should already exist from previous setup

-- Verify the policy
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'user_profiles' AND cmd = 'SELECT';

SELECT 'Admin view policy updated successfully! All authenticated users can now view all profiles.' as status;
