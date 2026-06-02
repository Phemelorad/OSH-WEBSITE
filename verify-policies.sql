-- ============================================
-- VERIFY ALL RLS POLICIES
-- Check if all policies are correctly set up
-- ============================================

-- Check policies on injury_claims table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as operation,
    qual as using_clause,
    with_check
FROM pg_policies
WHERE tablename = 'injury_claims'
ORDER BY cmd, policyname;

-- Check if RLS is enabled
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'injury_claims';

-- Test if table exists and has data
SELECT 
    COUNT(*) as total_claims,
    COUNT(DISTINCT status) as unique_statuses,
    COUNT(DISTINCT industry) as unique_industries
FROM injury_claims;
