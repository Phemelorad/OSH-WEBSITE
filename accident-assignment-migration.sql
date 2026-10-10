-- =============================================================================
-- Accident Report Assignment Columns Migration
--
-- Adds the columns the app already reads/writes on public.accident_reports but
-- which were never created in the database:
--
--   assigned_inspector  – the OSH officer assigned to investigate the accident.
--                         Read by accident-report.html, accident-entries.html,
--                         company-accidents-view.html and OHS_Form19_Full.html
--                         (assignment dropdown, Lead Investigator prefill).
--   employer_email      – declared in master-setup.sql / COMPILED_DATABASE.sql.
--   additional_injured  – declared in master-setup.sql / COMPILED_DATABASE.sql.
--
-- Without assigned_inspector every explicit `select(...assigned_inspector)`
-- fails with PostgREST 42703 ("column ... does not exist"), returning HTTP 400
-- and breaking accident data autofill on the Form 19 page.
--
-- Idempotent: safe to run more than once.
-- Run this ENTIRE file in the Supabase SQL Editor.
-- =============================================================================
BEGIN;

ALTER TABLE public.accident_reports
  ADD COLUMN IF NOT EXISTS assigned_inspector TEXT,
  ADD COLUMN IF NOT EXISTS employer_email     TEXT,
  ADD COLUMN IF NOT EXISTS additional_injured JSONB;

-- Speeds up "my assigned cases" filters/queues.
CREATE INDEX IF NOT EXISTS idx_accident_reports_assigned_inspector
  ON public.accident_reports (assigned_inspector)
  WHERE assigned_inspector IS NOT NULL;

COMMENT ON COLUMN public.accident_reports.assigned_inspector IS
  'Display name of the OSH officer assigned to investigate this accident';
COMMENT ON COLUMN public.accident_reports.employer_email IS
  'Optional employer contact e-mail for the accident report';
COMMENT ON COLUMN public.accident_reports.additional_injured IS
  'JSON array of additional injured persons for multi-person accidents';

-- Report what was applied.
DO $$
DECLARE
  v_count INT;
BEGIN
  SELECT count(*) INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'accident_reports'
    AND column_name IN ('assigned_inspector', 'employer_email', 'additional_injured');

  RAISE NOTICE 'accident_reports now has % of 3 assignment columns', v_count;
END
$$;

SELECT '✅ accident_reports assignment columns migration completed successfully!' AS status;
COMMIT;
