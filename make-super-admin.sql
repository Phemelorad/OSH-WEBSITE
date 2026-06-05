-- Upgrade user to super_admin
-- Run this in your Supabase SQL Editor

UPDATE user_profiles
SET role = 'super_admin'
WHERE email = 'phemelorad@gmail.com';

-- Verify the update
SELECT id, email, first_name, surname, role, created_at
FROM user_profiles
WHERE email = 'phemelorad@gmail.com';
