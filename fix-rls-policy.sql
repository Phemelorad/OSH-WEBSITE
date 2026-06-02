-- Fix RLS Policy for User Profiles
-- This allows users to insert their profile during signup

-- Drop the old INSERT policy
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;

-- Create new INSERT policy that works during signup
-- This allows authenticated users to insert a profile where the user_id matches their auth.uid()
CREATE POLICY "Users can insert own profile"
    ON user_profiles 
    FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Also create a policy to allow service role to insert (for admin operations)
DROP POLICY IF EXISTS "Service role can insert profiles" ON user_profiles;
CREATE POLICY "Service role can insert profiles"
    ON user_profiles 
    FOR INSERT 
    TO service_role
    WITH CHECK (true);

-- Verify the policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'user_profiles';
