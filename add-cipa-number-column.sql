-- ============================================================
-- ADD CIPA REGISTRATION NUMBER TO COMPANIES TABLE
-- Run this in Supabase SQL Editor to add the CIPA field
-- ============================================================

-- ── 1. Add cipa_number column ───────────────────────────────
ALTER TABLE companies
    ADD COLUMN IF NOT EXISTS cipa_number TEXT;

COMMENT ON COLUMN companies.cipa_number IS 'CIPA (Companies and Intellectual Property Authority) registration number';

-- ── 2. Verify ───────────────────────────────────────────────
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'companies'
ORDER BY ordinal_position;
