-- =============================================================================
-- Schema Improvements — Generated for DOSH OSH Platform
-- Run this entire file in Supabase SQL Editor (one shot)
-- =============================================================================

-- =============================================================================
-- PART 1: ON DELETE CASCADE/SET NULL for ALL foreign keys to auth.users
-- Fixes: prevents 409 errors permanently, makes delete_user_account simpler
-- =============================================================================

-- Tables that should CASCADE (user-specific data, safe to delete with user)
ALTER TABLE public.user_profiles
  DROP CONSTRAINT IF EXISTS user_profiles_user_id_fkey,
  ADD CONSTRAINT user_profiles_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.login_history
  DROP CONSTRAINT IF EXISTS login_history_user_id_fkey,
  ADD CONSTRAINT login_history_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.password_reset_requests
  DROP CONSTRAINT IF EXISTS password_reset_requests_user_id_fkey,
  ADD CONSTRAINT password_reset_requests_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.user_activity_log
  DROP CONSTRAINT IF EXISTS user_activity_log_user_id_fkey,
  ADD CONSTRAINT user_activity_log_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.role_change_log
  DROP CONSTRAINT IF EXISTS role_change_log_user_id_fkey,
  ADD CONSTRAINT role_change_log_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.role_change_log
  DROP CONSTRAINT IF EXISTS role_change_log_changed_by_fkey,
  ADD CONSTRAINT role_change_log_changed_by_fkey
    FOREIGN KEY (changed_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.practitioner_clients
  DROP CONSTRAINT IF EXISTS practitioner_clients_practitioner_id_fkey,
  ADD CONSTRAINT practitioner_clients_practitioner_id_fkey
    FOREIGN KEY (practitioner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Tables that should SET NULL (preserve business records, just remove submitter)
ALTER TABLE public.injury_claims
  DROP CONSTRAINT IF EXISTS injury_claims_submitted_by_fkey,
  ADD CONSTRAINT injury_claims_submitted_by_fkey
    FOREIGN KEY (submitted_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.workplace_inspections
  DROP CONSTRAINT IF EXISTS workplace_inspections_submitted_by_fkey,
  ADD CONSTRAINT workplace_inspections_submitted_by_fkey
    FOREIGN KEY (submitted_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.accident_reports
  DROP CONSTRAINT IF EXISTS accident_reports_submitted_by_fkey,
  ADD CONSTRAINT accident_reports_submitted_by_fkey
    FOREIGN KEY (submitted_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.injury_disease_reports
  DROP CONSTRAINT IF EXISTS injury_disease_reports_submitted_by_fkey,
  ADD CONSTRAINT injury_disease_reports_submitted_by_fkey
    FOREIGN KEY (submitted_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.inspection_bookings
  DROP CONSTRAINT IF EXISTS inspection_bookings_submitted_by_fkey,
  ADD CONSTRAINT inspection_bookings_submitted_by_fkey
    FOREIGN KEY (submitted_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.medical_examination_reports
  DROP CONSTRAINT IF EXISTS medical_examination_reports_submitted_by_fkey,
  ADD CONSTRAINT medical_examination_reports_submitted_by_fkey
    FOREIGN KEY (submitted_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.permanent_impairment_reports
  DROP CONSTRAINT IF EXISTS permanent_impairment_reports_submitted_by_fkey,
  ADD CONSTRAINT permanent_impairment_reports_submitted_by_fkey
    FOREIGN KEY (submitted_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.workers_registry
  DROP CONSTRAINT IF EXISTS workers_registry_created_by_fkey,
  ADD CONSTRAINT workers_registry_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.workers_registry
  DROP CONSTRAINT IF EXISTS workers_registry_updated_by_fkey,
  ADD CONSTRAINT workers_registry_updated_by_fkey
    FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- =============================================================================
-- PART 2: Remove duplicate FK on user_profiles.company_id
-- =============================================================================
ALTER TABLE public.user_profiles
  DROP CONSTRAINT IF EXISTS fk_user_profiles_company;

-- =============================================================================
-- PART 3: Fix contraventions column — bare ARRAY is invalid, change to TEXT[]
-- =============================================================================
ALTER TABLE public.workplace_inspections
  ALTER COLUMN contraventions TYPE TEXT[]
  USING CASE
    WHEN contraventions IS NULL THEN NULL
    ELSE contraventions::TEXT[]
  END;

-- =============================================================================
-- PART 4: updated_at trigger function + apply to all tables with updated_at
-- =============================================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Apply trigger to each table that has an updated_at column
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN
    SELECT unnest(ARRAY[
      'user_profiles',
      'injury_claims',
      'workplace_inspections',
      'accident_reports',
      'injury_disease_reports',
      'workers_registry',
      'companies',
      'inspection_bookings',
      'medical_examination_reports',
      'permanent_impairment_reports',
      'practitioner_clients'
    ])
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS set_updated_at ON public.%I;
       CREATE TRIGGER set_updated_at
         BEFORE UPDATE ON public.%I
         FOR EACH ROW
         EXECUTE FUNCTION public.update_updated_at_column();',
      tbl, tbl
    );
  END LOOP;
END;
$$;

-- =============================================================================
-- PART 5: Missing indexes for frequently queried columns
-- =============================================================================

-- practitioner_clients queries by worker_id_number for lookups
CREATE INDEX IF NOT EXISTS idx_pc_worker_id_number
  ON public.practitioner_clients(worker_id_number);

-- inspection_bookings by company_name
CREATE INDEX IF NOT EXISTS idx_ib_company_name_lookup
  ON public.inspection_bookings(company_name);

-- Combined index for accident reports by occupier + date (common query pattern)
CREATE INDEX IF NOT EXISTS idx_ar_occupier_date
  ON public.accident_reports(occupier_name, accident_date DESC);

-- Combined index for injury/disease reports by employer + date
CREATE INDEX IF NOT EXISTS idx_idr_employer_date
  ON public.injury_disease_reports(employer_name, incident_date DESC);

-- Workplace inspections by factory + date for company view queries
CREATE INDEX IF NOT EXISTS idx_wi_factory_date
  ON public.workplace_inspections(factory_name, inspection_date DESC);

-- Claims by claimant ID for fast worker lookups
CREATE INDEX IF NOT EXISTS idx_ic_claimant_id_number
  ON public.injury_claims(claimant_id_number);

-- =============================================================================
-- PART 6: Soft delete columns for major tables
-- =============================================================================
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.workers_registry
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- =============================================================================
-- PART 7: Database views for common queries (company register, dashboard stats)
-- =============================================================================

CREATE OR REPLACE VIEW public.company_register_view AS
SELECT
  c.*,
  COUNT(DISTINCT wi.id) AS inspection_count,
  AVG(wi.compliance_level) AS avg_compliance_level,
  COUNT(DISTINCT ar.id) AS accident_count,
  COUNT(DISTINCT idr.id) AS injury_count,
  COUNT(DISTINCT ic.id) AS claim_count
FROM public.companies c
LEFT JOIN public.workplace_inspections wi ON wi.factory_name = c.company_name
LEFT JOIN public.accident_reports ar ON ar.occupier_name = c.company_name
LEFT JOIN public.injury_disease_reports idr ON idr.employer_name = c.company_name
LEFT JOIN public.injury_claims ic ON ic.name_of_employer = c.company_name
GROUP BY c.id;

-- Dashboard stats view: count users by role
CREATE OR REPLACE VIEW public.user_roles_view AS
SELECT
  role,
  COUNT(*) AS user_count
FROM public.user_profiles
WHERE is_deleted IS DISTINCT FROM true
GROUP BY role;

-- Dashboard stats view: inspections by month
CREATE OR REPLACE VIEW public.inspections_by_month AS
SELECT
  DATE_TRUNC('month', inspection_date) AS month,
  COUNT(*) AS inspection_count,
  AVG(compliance_level) AS avg_compliance
FROM public.workplace_inspections
GROUP BY DATE_TRUNC('month', inspection_date)
ORDER BY month DESC;

-- =============================================================================
-- PART 8: Simplify delete_user_account function (no longer needs manual cleanup)
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
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id) INTO v_user_exists;

  IF NOT v_user_exists THEN
    RETURN jsonb_build_object('success', false, 'message', 'User not found in auth system');
  END IF;

  SELECT (first_name || ' ' || surname) INTO v_profile_name
  FROM public.user_profiles WHERE user_id = p_user_id;

  -- All child tables now cascade or set null automatically
  DELETE FROM auth.users WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'User deleted successfully',
    'profile_name', v_profile_name
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_user_account TO authenticated;
