-- =============================================================================
-- Accident Case Number Auto-Generate
-- -----------------------------------------------------------------------------
-- Enforces the standard format: OHS/ACC/{YY}/{XXXXX}
-- (e.g. OHS/ACC/26/00006)
--
-- This file consolidates the case-number fixes:
--   1. Drops the conflicting old trigger/function that produced "ACC-YYYY-XXXX"
--   2. (Re)creates the correct sequence, function, and trigger
--   3. Backfills existing rows that have the old format
--
-- Run in Supabase SQL Editor. SAFE to run multiple times (all DROP/ALTER
-- use IF EXISTS / IF NOT EXISTS guards).
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. SEQUENCE — shared counter for the 5-digit serial portion
-- =============================================================================
CREATE SEQUENCE IF NOT EXISTS public.accident_case_number_seq
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

-- =============================================================================
-- 2. GENERATE function — produces 'OHS/ACC/{YY}/{XXXXX}'
-- =============================================================================
CREATE OR REPLACE FUNCTION public.generate_accident_case_number()
RETURNS TEXT
LANGUAGE plpgsql
VOLATILE
SET search_path = public
AS $$
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

COMMENT ON FUNCTION public.generate_accident_case_number() IS
  'Generates the OHS/ACC/{YY}/{XXXXX} case-number standard.';

-- =============================================================================
-- 3. TRIGGER wrapper — assigns the number on INSERT when column is empty
-- =============================================================================
CREATE OR REPLACE FUNCTION public.trg_assign_accident_case_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.accident_case_number IS NULL THEN
    NEW.accident_case_number := public.generate_accident_case_number();
  END IF;
  RETURN NEW;
END;
$$;

-- =============================================================================
-- 4. REMOVE the old conflicting trigger / function / sequence
--     (these produced "ACC-{YYYY}-{XXXX}" and won the race because
--      trg_accident_file_number fires alphabetically before
--      trg_assign_accident_case, and the correct trigger skips
--      assignment when the column is already non-NULL)
-- =============================================================================
DROP TRIGGER IF EXISTS trg_accident_file_number ON public.accident_reports;
DROP FUNCTION IF EXISTS public.generate_accident_file_number();
DROP SEQUENCE IF EXISTS public.accident_file_number_seq;

-- =============================================================================
-- 5. ATTACH the correct trigger (drop-then-recreate for idempotency)
-- =============================================================================
DROP TRIGGER IF EXISTS trg_assign_accident_case ON public.accident_reports;

CREATE TRIGGER trg_assign_accident_case
  BEFORE INSERT ON public.accident_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_assign_accident_case_number();

-- =============================================================================
-- 6. BACKFILL — correct existing rows that were auto-numbered with the
--     old "ACC-{YYYY}-{XXXX}" format, and fill any remaining NULLs
-- =============================================================================
UPDATE public.accident_reports
SET    accident_case_number = public.generate_accident_case_number()
WHERE  accident_case_number IS NULL
   OR accident_case_number LIKE 'ACC-%';

-- Ensure a unique index exists for the corrected column
DROP INDEX IF EXISTS idx_accident_reports_case_number_old;
CREATE UNIQUE INDEX IF NOT EXISTS idx_accident_reports_case_number
  ON public.accident_reports(accident_case_number)
  WHERE accident_case_number IS NOT NULL;

COMMENT ON COLUMN public.accident_reports.accident_case_number IS
  'Auto-generated: OHS/ACC/{YY}/{XXXXX}';

COMMIT;

-- =============================================================================
-- Verification helper — run a SELECT to see sample case numbers after applying:
--
--   SELECT id, accident_case_number, created_at
--   FROM public.accident_reports
--   ORDER BY created_at DESC
--   LIMIT 10;
-- =============================================================================
