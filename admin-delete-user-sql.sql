-- =============================================================================
-- Database function: delete_user_account
-- Call from frontend: supabaseClient.rpc('delete_user_account', { p_user_id: userId })
--
-- SECURITY DEFINER: runs with creator's privileges (bypasses RLS)
-- Fixes 409 error: deletes from role_change_log first (has RESTRICT FKs)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.delete_user_account(p_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_exists boolean;
  v_profile_name text;
BEGIN
  -- Check if user exists in auth.users
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id) INTO v_user_exists;
  
  IF NOT v_user_exists THEN
    RETURN jsonb_build_object('success', false, 'message', 'User not found in auth system');
  END IF;

  -- Get profile name for logging
  SELECT (first_name || ' ' || surname) INTO v_profile_name 
  FROM public.user_profiles WHERE user_id = p_user_id;

  -- 🔴 Must delete from role_change_log FIRST because its FK to auth.users
  --    has NO ON DELETE CASCADE (defaults to RESTRICT, which blocks the delete)
  DELETE FROM public.role_change_log WHERE user_id = p_user_id;
  DELETE FROM public.role_change_log WHERE changed_by = p_user_id;

  -- Delete from auth.users — this cascades ON DELETE CASCADE to:
  --   user_profiles, workers_registry, accident_reports, injury_disease_reports,
  --   medical_examination_reports, permanent_impairment_reports, etc.
  DELETE FROM auth.users WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'User deleted successfully',
    'profile_name', v_profile_name
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_user_account TO authenticated;
