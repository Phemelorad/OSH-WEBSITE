-- =============================================================================
-- Migration: Add medical practitioner profile columns to user_profiles
-- Run in Supabase SQL Editor
-- =============================================================================

ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS practice_name      TEXT,
    ADD COLUMN IF NOT EXISTS med_reg_number     TEXT,
    ADD COLUMN IF NOT EXISTS branch             TEXT,
    ADD COLUMN IF NOT EXISTS practitioner_address TEXT,
    ADD COLUMN IF NOT EXISTS practitioner_tel   TEXT;

-- Backfill practice_name and med_reg_number from auth metadata for existing
-- medical_practitioner accounts (only sets them if the column is still NULL)
UPDATE public.user_profiles
SET
    practice_name  = (raw_user_meta_data->>'practice_name'),
    med_reg_number = (raw_user_meta_data->>'med_reg_number')
FROM auth.users
WHERE public.user_profiles.user_id = auth.users.id
  AND public.user_profiles.role = 'medical_practitioner'
  AND public.user_profiles.practice_name IS NULL;
