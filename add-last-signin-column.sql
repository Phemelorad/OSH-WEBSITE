-- Add last_sign_in column to user_profiles
-- This is updated on every successful login so the admin panel
-- can show when each user last signed in.

ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS last_sign_in TIMESTAMPTZ;
