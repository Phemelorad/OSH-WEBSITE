-- ============================================================
-- Migration: Add missing accident-type columns to injury_disease_reports
--
-- The injury-disease-report.html form has checkboxes for:
--   is_factory_accident
--   is_mine_accident
--   is_road_traffic_accident
-- and the submit handler sets them to 'yes' / 'no'.
--
-- These columns were never added to the injury_disease_reports
-- table in COMPILED_DATABASE.sql or master-setup.sql, causing
-- the Supabase error:
--   "Could not find the 'is_factory_accident' column of
--    'injury_disease_reports' in the schema cache"
--
-- Run in Supabase Dashboard → SQL Editor
-- ============================================================

-- ── Add the three missing columns ──
ALTER TABLE public.injury_disease_reports
    ADD COLUMN IF NOT EXISTS is_factory_accident       TEXT
        CHECK (is_factory_accident IN ('yes', 'no')),
    ADD COLUMN IF NOT EXISTS is_mine_accident          TEXT
        CHECK (is_mine_accident IN ('yes', 'no')),
    ADD COLUMN IF NOT EXISTS is_road_traffic_accident  TEXT
        CHECK (is_road_traffic_accident IN ('yes', 'no'));

-- ── Indexes for filtering by accident type ──
CREATE INDEX IF NOT EXISTS idx_idr_is_factory
    ON public.injury_disease_reports(is_factory_accident)
    WHERE is_factory_accident = 'yes';

CREATE INDEX IF NOT EXISTS idx_idr_is_mine
    ON public.injury_disease_reports(is_mine_accident)
    WHERE is_mine_accident = 'yes';

CREATE INDEX IF NOT EXISTS idx_idr_is_road_traffic
    ON public.injury_disease_reports(is_road_traffic_accident)
    WHERE is_road_traffic_accident = 'yes';

-- ── Update existing rows to 'no' (default for existing data) ──
-- Only update rows where the column is NULL (newly added)
UPDATE public.injury_disease_reports
SET is_factory_accident = 'no'
WHERE is_factory_accident IS NULL;

UPDATE public.injury_disease_reports
SET is_mine_accident = 'no'
WHERE is_mine_accident IS NULL;

UPDATE public.injury_disease_reports
SET is_road_traffic_accident = 'no'
WHERE is_road_traffic_accident IS NULL;

-- ── Verify ──
SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE is_factory_accident IS NOT NULL)    AS factory_populated,
       COUNT(*) FILTER (WHERE is_mine_accident IS NOT NULL)       AS mine_populated,
       COUNT(*) FILTER (WHERE is_road_traffic_accident IS NOT NULL) AS road_populated
FROM public.injury_disease_reports;

COMMENT ON COLUMN public.injury_disease_reports.is_factory_accident      IS 'Whether the injury/disease is a factory accident (yes/no)';
COMMENT ON COLUMN public.injury_disease_reports.is_mine_accident         IS 'Whether the injury/disease is a mine accident (yes/no)';
COMMENT ON COLUMN public.injury_disease_reports.is_road_traffic_accident IS 'Whether the injury/disease is a road traffic accident (yes/no)';
