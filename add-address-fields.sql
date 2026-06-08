-- ============================================================
-- ADD STRUCTURED ADDRESS FIELDS TO COMPANIES TABLE
-- Run this in Supabase SQL Editor
-- ============================================================

-- ── 1. Add address columns ─────────────────────────────────
ALTER TABLE companies
    ADD COLUMN IF NOT EXISTS physical_address TEXT,
    ADD COLUMN IF NOT EXISTS plot_number TEXT,
    ADD COLUMN IF NOT EXISTS street_name TEXT;

COMMENT ON COLUMN companies.physical_address IS 'Full physical / postal address of the company';
COMMENT ON COLUMN companies.plot_number IS 'Plot number (e.g. Plot 12345, Gaborone)';
COMMENT ON COLUMN companies.street_name IS 'Street name where the company is located';
COMMENT ON COLUMN companies.location IS 'Legacy free-text location field';

-- ── 2. Verify ──────────────────────────────────────────────
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'companies'
ORDER BY ordinal_position;
