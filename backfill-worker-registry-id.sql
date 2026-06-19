-- ============================================================
-- Backfill: accident_reports.worker_registry_id
-- Purpose: Populate worker_registry_id on existing accident
--          reports by joining through accident_injured_persons
--          and workers_registry via id_number.
--
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- Step 1: Preview the records that will be updated
-- (Run this first to see how many rows will be affected)
SELECT
  ar.id AS report_id,
  ar.accident_case_number,
  ar.injured_name,
  wr.id AS registry_id,
  wr.full_name AS worker_name,
  wr.id_number
FROM accident_reports ar
INNER JOIN accident_injured_persons aip ON aip.accident_report_id = ar.id
INNER JOIN workers_registry wr ON UPPER(TRIM(wr.id_number)) = UPPER(TRIM(aip.id_number))
WHERE ar.worker_registry_id IS NULL;

-- Step 2: Backfill worker_registry_id
-- Updates accident_reports by matching id_number through the
-- accident_injured_persons join table to workers_registry
UPDATE accident_reports ar
SET worker_registry_id = wr.id
FROM accident_injured_persons aip
INNER JOIN workers_registry wr ON UPPER(TRIM(wr.id_number)) = UPPER(TRIM(aip.id_number))
WHERE aip.accident_report_id = ar.id
  AND ar.worker_registry_id IS NULL;

-- Step 3: Verify the update
-- (Run this to confirm the rows were updated)
SELECT
  COUNT(*) AS updated_count
FROM accident_reports
WHERE worker_registry_id IS NOT NULL;
