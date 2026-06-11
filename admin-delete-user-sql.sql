-- =============================================================================
-- Database function: delete_user_account
-- Call from frontend: supabaseClient.rpc('delete_user_account', { p_user_id: userId })
--
-- SECURITY DEFINER: runs with creator's privileges (bypasses RLS)
--
-- Handles ALL 17 FOREIGN KEY references to auth.users(id) that use RESTRICT
-- (no ON DELETE CASCADE/SET NULL in the actual database schema)
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

  -- =================================================================
  -- STEP 1: DELETE audit/history rows tied to this user
  -- =================================================================
  DELETE FROM public.role_change_log WHERE user_id = p_user_id;
  DELETE FROM public.role_change_log WHERE changed_by = p_user_id;
  DELETE FROM public.login_history WHERE user_id = p_user_id;
  DELETE FROM public.password_reset_requests WHERE user_id = p_user_id;
  DELETE FROM public.user_activity_log WHERE user_id = p_user_id;

  -- =================================================================
  -- STEP 2: SET NULL on submitted_by in business records
  --         (preserves the records, just removes the user reference)
  -- =================================================================
  UPDATE public.injury_claims SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.workplace_inspections SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.accident_reports SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.injury_disease_reports SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.inspection_bookings SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.medical_examination_reports SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.permanent_impairment_reports SET submitted_by = NULL WHERE submitted_by = p_user_id;

  -- =================================================================
  -- STEP 3: SET NULL on created_by/updated_by in workers_registry
  -- =================================================================
  UPDATE public.workers_registry SET created_by = NULL WHERE created_by = p_user_id;
  UPDATE public.workers_registry SET updated_by = NULL WHERE updated_by = p_user_id;

  -- =================================================================
  -- STEP 4: DELETE practitioner-client relationships
  -- =================================================================
  DELETE FROM public.practitioner_clients WHERE practitioner_id = p_user_id;

  -- =================================================================
  -- STEP 5: DELETE the user profile
  -- =================================================================
  DELETE FROM public.user_profiles WHERE user_id = p_user_id;

  -- =================================================================
  -- STEP 6: DELETE from auth.users (now nothing blocks it)
  -- =================================================================
  DELETE FROM auth.users WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'User deleted successfully',
    'profile_name', v_profile_name
  );
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_user_account TO authenticated;
