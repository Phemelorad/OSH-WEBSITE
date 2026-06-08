-- ============================================================
-- ADD MISSING COLUMNS TO COMPANIES TABLE
-- Run this in Supabase SQL Editor if you get errors like:
--   "Could not find the 'X' column of 'companies' in the schema cache"
-- ============================================================

-- Add physical address column if missing
ALTER TABLE companies ADD COLUMN IF NOT EXISTS physical_address TEXT;

-- Add CIPA number column if missing
ALTER TABLE companies ADD COLUMN IF NOT EXISTS cipa_number TEXT;

-- Verify all expected columns exist
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'companies'
ORDER BY ordinal_position;

-- Show success message
SELECT 'Missing columns added successfully!' AS status;
