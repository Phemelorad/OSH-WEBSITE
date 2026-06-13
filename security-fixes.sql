-- =============================================================================
-- Supabase Security Fixes
-- Generated from Database Linter warnings
-- Run this ENTIRE file in the Supabase SQL Editor
-- =============================================================================

BEGIN;

-- =============================================================================
-- PART 1: Fix function_search_path_mutable (17 functions)
-- Adds SET search_path = 'public' to prevent search_path hijacking
-- =============================================================================

-- 1. normalize_identity_id
ALTER FUNCTION public.normalize_identity_id(val TEXT) SET search_path = 'public';

-- 2. trg_normalize_injured_id_number (trigger)
ALTER FUNCTION public.trg_normalize_injured_id_number() SET search_path = 'public';

-- 3. trg_normalize_worker_id_number (trigger)
ALTER FUNCTION public.trg_normalize_worker_id_number() SET search_path = 'public';

-- 4. calculate_session_duration (trigger)
ALTER FUNCTION public.calculate_session_duration() SET search_path = 'public';

-- 5. update_updated_at_column (trigger)
ALTER FUNCTION public.update_updated_at_column() SET search_path = 'public';

-- 6. expire_old_password_resets
ALTER FUNCTION public.expire_old_password_resets() SET search_path = 'public';

-- 7. log_role_change (trigger, SECURITY DEFINER)
ALTER FUNCTION public.log_role_change() SET search_path = 'public';

-- 8. get_user_role
ALTER FUNCTION public.get_user_role(user_uuid UUID) SET search_path = 'public';

-- 9. current_user_role
ALTER FUNCTION public.current_user_role() SET search_path = 'public';

-- 10. format_comp_claim_file_number
ALTER FUNCTION public.format_comp_claim_file_number(p_claimant_id TEXT, p_sequence INTEGER, p_when DATE) SET search_path = 'public';

-- 11. trg_normalize_claimant_id_number (trigger)
ALTER FUNCTION public.trg_normalize_claimant_id_number() SET search_path = 'public';

-- 12. has_permission
ALTER FUNCTION public.has_permission(permission_name TEXT) SET search_path = 'public';

-- 13. compute_compliance_totals (trigger)
ALTER FUNCTION public.compute_compliance_totals() SET search_path = 'public';

-- 14. trg_normalize_registry_id_number (trigger)
ALTER FUNCTION public.trg_normalize_registry_id_number() SET search_path = 'public';

-- 15. get_claim_statistics
ALTER FUNCTION public.get_claim_statistics() SET search_path = 'public';

-- 16. get_inspection_statistics
ALTER FUNCTION public.get_inspection_statistics() SET search_path = 'public';

-- 17. search_workers_by_identity (also flagged by best practice)
ALTER FUNCTION public.search_workers_by_identity(search_query TEXT, result_limit INT) SET search_path = 'public';

-- 18. delete_user_account (already has SET search_path = public, keep as-is)
-- 19. generate_comp_claim_file_number
ALTER FUNCTION public.generate_comp_claim_file_number(p_claimant_id TEXT) SET search_path = 'public';

-- 20. injury_claims_assign_file_number (trigger)
ALTER FUNCTION public.injury_claims_assign_file_number() SET search_path = 'public';

-- =============================================================================
-- PART 2: Fix SECURITY DEFINER functions callable by anon
-- Switch to SECURITY INVOKER where safe, revoke EXECUTE from anon otherwise
-- =============================================================================

-- 2a. delete_user_account — VERY sensitive. Keep SECURITY DEFINER (needed to delete
--     from auth.users which requires superuser/service_role privileges).
--     Just revoke EXECUTE from anon so only authenticated users can call it.
REVOKE EXECUTE ON FUNCTION public.delete_user_account(p_user_id UUID) FROM anon;

-- Note: The function should also be updated to check caller role internally.
-- If the current function doesn't already check that only admins can delete other users,
-- recreate it with the following pattern:
--
-- CREATE OR REPLACE FUNCTION public.delete_user_account(p_user_id UUID)
-- RETURNS jsonb
-- LANGUAGE plpgsql
-- SECURITY DEFINER
-- SET search_path = public
-- AS $
-- DECLARE
--   v_caller_role text;
-- BEGIN
--   SELECT role INTO v_caller_role FROM public.user_profiles WHERE user_id = auth.uid();
--   IF v_caller_role NOT IN ('admin', 'super_admin') AND p_user_id != auth.uid() THEN
--     RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: only admins can delete other users');
--   END IF;
--   ... existing cleanup logic ...
-- END;
-- $;

-- 2b. injury_claims_assign_file_number — Sensitive trigger function.
--     Switch to SECURITY INVOKER so it runs with caller's permissions.
ALTER FUNCTION public.injury_claims_assign_file_number() SECURITY INVOKER;
REVOKE EXECUTE ON FUNCTION public.injury_claims_assign_file_number() FROM anon;

-- 2c. injury_claims_before_insert_file_number — Same as above.
--     Note: Not found in migration files, may have been renamed/dropped.
--     If this function no longer exists, the ALTER will safely no-op.
DO $func$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'injury_claims_before_insert_file_number') THEN
    EXECUTE 'ALTER FUNCTION public.injury_claims_before_insert_file_number() SECURITY INVOKER';
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.injury_claims_before_insert_file_number() FROM anon';
  END IF;
END
$func$;

-- 2d. generate_comp_claim_file_number — generates file numbers.
--     Switch to SECURITY INVOKER so only authenticated users with proper perms can use it.
ALTER FUNCTION public.generate_comp_claim_file_number(p_claimant_id TEXT) SECURITY INVOKER;
REVOKE EXECUTE ON FUNCTION public.generate_comp_claim_file_number(p_claimant_id TEXT) FROM anon;

-- 2e. log_role_change — Logging function.
--     Keep SECURITY DEFINER (needs to insert into log table), but revoke from anon.
REVOKE EXECUTE ON FUNCTION public.log_role_change() FROM anon;

-- 2f. current_user_role — Needed for auth checks. Switch to SECURITY INVOKER
--     so it uses the caller's identity naturally.
ALTER FUNCTION public.current_user_role() SECURITY INVOKER;
-- Still grant to anon so unauthenticated pages can check if user is logged in
GRANT EXECUTE ON FUNCTION public.current_user_role() TO anon, authenticated;

-- 2g. get_user_role — Same pattern as current_user_role
ALTER FUNCTION public.get_user_role(user_uuid UUID) SECURITY INVOKER;
GRANT EXECUTE ON FUNCTION public.get_user_role(user_uuid UUID) TO anon, authenticated;

-- 2h. has_permission — Permission check function. Switch to SECURITY INVOKER.
ALTER FUNCTION public.has_permission(permission_name TEXT) SECURITY INVOKER;
GRANT EXECUTE ON FUNCTION public.has_permission(permission_name TEXT) TO authenticated;

-- =============================================================================
-- PART 3: Fix overly permissive RLS policies
-- Replaces USING (true) / WITH CHECK (true) with proper conditions
-- =============================================================================

-- 3a. companies: 'Anyone can insert companies'
--     Allow any authenticated user to register companies
DROP POLICY IF EXISTS "Anyone can insert companies" ON public.companies;
CREATE POLICY "Anyone can insert companies" ON public.companies
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- 3b. injury_disease_reports: 'authenticated_users_can_insert'
--     Allow any authenticated user with officer/admin role to insert
DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.injury_disease_reports;
CREATE POLICY "authenticated_users_can_insert" ON public.injury_disease_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
      AND up.role IN ('officer', 'admin', 'super_admin', 'medical_practitioner')
    )
  );

-- 3c. injury_disease_reports: 'authenticated_users_can_update'
--     Only allow updating records you submitted or if you have admin role
DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.injury_disease_reports;
CREATE POLICY "authenticated_users_can_update" ON public.injury_disease_reports
  FOR UPDATE
  TO authenticated
  USING (
    submitted_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
      AND up.role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    submitted_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
      AND up.role IN ('admin', 'super_admin')
    )
  );

-- 3d. medical_examination_reports: 'Officers can insert medical reports'
--     Restrict to medical_practitioners
DROP POLICY IF EXISTS "Officers can insert medical reports" ON public.medical_examination_reports;
CREATE POLICY "Officers can insert medical reports" ON public.medical_examination_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
      AND up.role IN ('medical_practitioner', 'admin', 'super_admin')
    )
  );

-- 3e. workers_registry: 'All authenticated users can insert workers'
--     Restrict to officer/admin/super_admin roles
DROP POLICY IF EXISTS "All authenticated users can insert workers" ON public.workers_registry;
CREATE POLICY "All authenticated users can insert workers" ON public.workers_registry
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
      AND up.role IN ('officer', 'admin', 'super_admin')
    )
  );

-- 3f. workers_registry: 'authenticated_users_can_insert' (duplicate policy)
DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.workers_registry;

-- 3g. workers_registry: 'authenticated_users_can_update'
--     Only allow updating records you created or if admin
DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.workers_registry;
CREATE POLICY "authenticated_users_can_update" ON public.workers_registry
  FOR UPDATE
  TO authenticated
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
      AND up.role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
      AND up.role IN ('admin', 'super_admin')
    )
  );

-- 3h. password_reset_requests: 'Anyone can request password reset'
--     Keep permissive — anyone (even anon) needs to request password resets.
--     Just add a rate-limit check to prevent abuse.
DROP POLICY IF EXISTS "Anyone can request password reset" ON public.password_reset_requests;
CREATE POLICY "Anyone can request password reset" ON public.password_reset_requests
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    -- Prevent more than 3 pending resets per email in the last hour
    (SELECT COUNT(*) FROM public.password_reset_requests prr
     WHERE prr.email = password_reset_requests.email
     AND prr.status = 'pending'
     AND prr.requested_at > NOW() - INTERVAL '1 hour') < 3
  );

-- =============================================================================
-- PART 4: Move pg_trgm extension out of public schema
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS extensions;
ALTER EXTENSION pg_trgm SET SCHEMA extensions;

-- Grant usage on extensions schema to authenticated users
GRANT USAGE ON SCHEMA extensions TO authenticated, anon;

-- =============================================================================
-- PART 5: Create a view to check function search_paths (for verification)
-- =============================================================================
CREATE OR REPLACE VIEW public.functions_without_search_path AS
SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  CASE WHEN p.prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END AS security,
  COALESCE(array_to_string(p.proconfig, ', '), '') AS config
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND (p.proconfig IS NULL OR NOT (p.proconfig && ARRAY['search_path']))
  AND p.proname NOT LIKE '%_temp%'
ORDER BY p.proname;

COMMIT;

-- =============================================================================
-- POST-RUN VERIFICATION QUERIES
-- =============================================================================

-- Check which functions still lack search_path:
-- SELECT * FROM public.functions_without_search_path;

-- Check which functions are still SECURITY DEFINER + callable by anon:
-- SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
-- FROM pg_proc p
-- JOIN pg_namespace n ON p.pronamespace = n.oid
-- WHERE n.nspname = 'public'
--   AND p.prosecdef = true
--   AND EXISTS (
--     SELECT 1 FROM pg_roles r
--     WHERE r.rolname = 'anon'
--     AND has_function_privilege('anon', p.oid, 'EXECUTE')
--   );

-- Check remaining permissive RLS policies:
-- SELECT schemaname, tablename, policyname, permissive, cmd, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND (qual = 'true' OR with_check = 'true')
-- ORDER BY tablename, policyname;

-- Manual step: Enable leaked password protection
-- Go to Supabase Dashboard → Authentication → Security → Leaked Password Protection → Enable
-- Or use the Management API:
-- https://supabase.com/dashboard/project/[PROJECT_REF]/auth/providers
