-- ============================================================
-- Expand workers_registry — Tier 1/2 fields used across all forms
-- Run in Supabase SQL Editor after workers-registry-table.sql
-- ============================================================

ALTER TABLE workers_registry
    ADD COLUMN IF NOT EXISTS usual_occupation   TEXT,
    ADD COLUMN IF NOT EXISTS experience_level   TEXT,
    ADD COLUMN IF NOT EXISTS employer_fax       TEXT,
    ADD COLUMN IF NOT EXISTS age_years          INTEGER
        CHECK (age_years IS NULL OR (age_years > 0 AND age_years < 120));

COMMENT ON COLUMN workers_registry.usual_occupation IS 'Normal/usual occupation (Form 60)';
COMMENT ON COLUMN workers_registry.experience_level IS 'Experience at time of incident (Form 60)';
COMMENT ON COLUMN workers_registry.employer_fax IS 'Employer fax (Form 43/10)';
COMMENT ON COLUMN workers_registry.age_years IS 'Last known age in years when DOB not available';

CREATE INDEX IF NOT EXISTS idx_wr_usual_occupation ON workers_registry(usual_occupation);
CREATE INDEX IF NOT EXISTS idx_wr_age_years ON workers_registry(age_years);

SELECT 'workers_registry expanded' AS status;
