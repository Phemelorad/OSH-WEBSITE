-- ============================================
-- ADD GENDER COLUMN TO INJURY_CLAIMS TABLE
-- Run this if you already created the table
-- ============================================

-- Add gender column
ALTER TABLE injury_claims 
ADD COLUMN IF NOT EXISTS gender TEXT CHECK (gender IN ('M', 'F'));

-- Update existing records (set a default value if needed)
-- UPDATE injury_claims SET gender = 'M' WHERE gender IS NULL;

-- Make gender required for new entries
-- ALTER TABLE injury_claims ALTER COLUMN gender SET NOT NULL;

SELECT 'Gender column added successfully!' as status;
