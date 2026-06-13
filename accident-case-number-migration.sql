-- =============================================================================
-- Accident Case Number Migration
-- Adds auto-generated case numbers: OHS/ACC/YY/XXXXX
-- Run this ENTIRE file in Supabase SQL Editor
-- =============================================================================
BEGIN;

-- 1. Create sequence
CREATE SEQUENCE IF NOT EXISTS public.accident_case_number_seq
  START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

-- 2. Create function to generate case number
CREATE OR REPLACE FUNCTION public.generate_accident_case_number()
RETURNS TEXT LANGUAGE plpgsql VOLATILE SET search_path = public AS $$
DECLARE
  v_year TEXT := to_char(CURRENT_DATE, 'YY');
  v_seq  TEXT;
  v_next BIGINT;
BEGIN
  v_next := nextval('public.accident_case_number_seq');
  v_seq  := LPAD(v_next::TEXT, 5, '0');
  RETURN 'OHS/ACC/' || v_year || '/' || v_seq;
END;
$$;

COMMENT ON FUNCTION public.generate_accident_case_number() IS 'Generates OHS/ACC/{YY}/{XXXXX}';

-- 3. Add column
ALTER TABLE public.accident_reports
  ADD COLUMN IF NOT EXISTS accident_case_number TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_accident_reports_case_number
  ON public.accident_reports(accident_case_number)
  WHERE accident_case_number IS NOT NULL;

COMMENT ON COLUMN public.accident_reports.accident_case_number IS 'Auto-generated: OHS/ACC/{YY}/{XXXXX}';

-- 4. Create BEFORE INSERT trigger
CREATE OR REPLACE FUNCTION public.trg_assign_accident_case_number()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.accident_case_number IS NULL THEN
    NEW.accident_case_number := public.generate_accident_case_number();
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_assign_accident_case_number() IS 'Assigns accident_case_number on INSERT';

DROP TRIGGER IF EXISTS trg_assign_accident_case ON public.accident_reports;
CREATE TRIGGER trg_assign_accident_case
  BEFORE INSERT ON public.accident_reports
  FOR EACH ROW EXECUTE FUNCTION public.trg_assign_accident_case_number();

-- 5. Backfill existing records
DO $$
DECLARE
  r RECORD;
  v_year TEXT;
  v_seq  TEXT;
  v_next BIGINT;
BEGIN
  FOR r IN SELECT id, COALESCE(created_at, CURRENT_DATE) as dt FROM public.accident_reports WHERE accident_case_number IS NULL ORDER BY created_at LOOP
    v_year := to_char(r.dt, 'YY');
    v_next := nextval('public.accident_case_number_seq');
    v_seq  := LPAD(v_next::TEXT, 5, '0');
    UPDATE public.accident_reports SET accident_case_number = 'OHS/ACC/' || v_year || '/' || v_seq WHERE id = r.id;
  END LOOP;
END;
$$;

-- 6. Update incident_chain_view to include case number
DROP VIEW IF EXISTS public.incident_chain_view;
CREATE VIEW public.incident_chain_view AS
SELECT
  ar.id AS accident_id,
  ar.accident_case_number,
  ar.report_type, ar.occupier_name AS employer_name, ar.industry_sector,
  ar.accident_date, ar.accident_place, ar.accident_description,
  ar.investigation_status AS accident_investigation_status, ar.reporter_name, ar.injury_fatal,
  idr.id AS injury_report_id, idr.worker_name, idr.incident_type,
  idr.nature_of_injuries, idr.resulted_death, idr.permanent_incapacity,
  idr.temporary_incapacity, idr.occupation, idr.worker_registry_id AS injured_worker_registry_id,
  ic.id AS claim_id, ic.file_number, ic.status AS claim_status,
  ic.incapacity_percentage AS claim_incapacity, ic.date_of_injury AS claim_date,
  mer.id AS medical_exam_id, mer.status AS medical_status,
  mer.incapacity_percentage AS medical_incapacity, mer.report_date AS medical_report_date
FROM public.accident_reports ar
LEFT JOIN public.injury_disease_reports idr ON idr.accident_id = ar.id
LEFT JOIN public.injury_claims ic ON ic.injury_report_id = idr.id
LEFT JOIN public.medical_examination_reports mer ON mer.claim_id = ic.id
ORDER BY ar.accident_date DESC, idr.incident_date DESC;

COMMENT ON VIEW public.incident_chain_view IS 'Complete incident chain with accident_case_number';

GRANT SELECT ON public.incident_chain_view TO authenticated, anon;
COMMIT;
