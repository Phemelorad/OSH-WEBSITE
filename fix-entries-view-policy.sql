-- ============================================
-- FIX RLS POLICY TO ALLOW VIEWING ALL CLAIMS
-- This allows the entries page to see all submitted claims
-- ============================================

-- Drop the old restrictive SELECT policy (if it exists)
DROP POLICY IF EXISTS "Users can view own claims" ON injury_claims;

-- Drop and recreate the policy to ensure it's correct
DROP POLICY IF EXISTS "Authenticated users can view all claims" ON injury_claims;

-- Create policy that allows all authenticated users to view all claims
CREATE POLICY "Authenticated users can view all claims"
    ON injury_claims 
    FOR SELECT 
    TO authenticated
    USING (true);

-- Verify the policies
SELECT 
    policyname,
    cmd as operation,
    roles,
    qual as using_clause
FROM pg_policies
WHERE tablename = 'injury_claims' AND cmd = 'SELECT';

SELECT 'Entries view policy updated successfully! All authenticated users can now view all claims.' as status;
