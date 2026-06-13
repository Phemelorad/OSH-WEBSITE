-- =============================================================================
-- Incident Chain Model Migration
-- Links: Accident → Injury/Disease Reports → Claims → Medical Eval
-- Run this ENTIRE file in Supabase SQL Editor
-- =============================================================================
BEGIN;

-- 1. Add accident_id FK to injury_disease_reports
--    Links each injury/disease report back to the accident that caused it
ALTER TABLE public.injury_disease_reports
  ADD COLUMN IF NOT EXISTS accident_id uuid REFERENCES public.accident_reports(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_injury_disease_reports_accident_id
  ON public.injury_disease_reports(accident_id);

-- 2. Add injury_report_id FK to injury_claims
--    Links each claim back to the specific injury/disease report
ALTER TABLE public.injury_claims
  ADD COLUMN IF NOT EXISTS injury_report_id uuid REFERENCES public.injury_disease_reports(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_injury_claims_injury_report_id
  ON public.injury_claims(injury_report_id);

-- 3. Add accident_id FK to medical_examination_reports
--    Links medical evals directly to accidents (in addition to claim_id)
ALTER TABLE public.medical_examination_reports
  ADD COLUMN IF NOT EXISTS accident_id uuid REFERENCES public.accident_reports(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_medical_examination_reports_accident_id
  ON public.medical_examination_reports(accident_id);

-- 4. Create the incident chain view
--    Shows the full chain: Accident → Injuries → Claims → Medical
CREATE OR REPLACE VIEW public.incident_chain_view AS
SELECT
  -- Accident level
  ar.id AS accident_id,
  ar.report_type,
  ar.occupier_name AS employer_name,
  ar.industry_sector,
  ar.accident_date,
  ar.accident_place,
  ar.accident_description,
  ar.investigation_status AS accident_investigation_status,
  ar.reporter_name,
  ar.injury_fatal,

  -- Injury/Disease level (one per injured worker)
  idr.id AS injury_report_id,
  idr.worker_name,
  idr.incident_type,
  idr.nature_of_injuries,
  idr.resulted_death,
  idr.permanent_incapacity,
  idr.temporary_incapacity,
  idr.occupation,
  idr.worker_registry_id AS injured_worker_registry_id,

  -- Claim level
  ic.id AS claim_id,
  ic.file_number,
  ic.status AS claim_status,
  ic.incapacity_percentage AS claim_incapacity,
  ic.date_of_injury AS claim_date,

  -- Medical exam level (linked through the claim, not accident, to avoid duplication)
  mer.id AS medical_exam_id,
  mer.status AS medical_status,
  mer.incapacity_percentage AS medical_incapacity,
  mer.report_date AS medical_report_date

FROM public.accident_reports ar
LEFT JOIN public.injury_disease_reports idr ON idr.accident_id = ar.id
LEFT JOIN public.injury_claims ic ON ic.injury_report_id = idr.id
LEFT JOIN public.medical_examination_reports mer ON mer.claim_id = ic.id

ORDER BY ar.accident_date DESC, idr.incident_date DESC;

COMMENT ON VIEW public.incident_chain_view IS
  'Complete incident chain: links each accident to its resulting injuries/diseases, claims, and medical evaluations.';

-- 5. Grant access
GRANT SELECT ON public.incident_chain_view TO authenticated, anon;

COMMIT;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================
-- Check the incident chain:
-- SELECT accident_id, employer_name, accident_date,
--        worker_name, incident_type,
--        claim_id, claim_status,
--        medical_exam_id, medical_status
-- FROM public.incident_chain_view
-- LIMIT 20;
