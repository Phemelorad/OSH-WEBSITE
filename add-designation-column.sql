-- ============================================================
-- ADD DESIGNATION COLUMN TO USER PROFILES
-- Stores job title / designation like "Deputy Director",
-- "Safety Officer", etc.
-- ============================================================

ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS designation TEXT;

COMMENT ON COLUMN user_profiles.designation IS
    'Job title or designation of the user (e.g. Deputy Director, Safety Officer)';

SELECT 'designation column added successfully!' AS status;

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_profiles'
ORDER BY ordinal_position;
