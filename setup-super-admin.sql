-- ============================================
-- SETUP FIRST SUPER ADMIN
-- Run this to assign super_admin role to your account
-- ============================================

-- Option 1: Set super_admin by email
-- Replace 'your.email@example.com' with your actual email
UPDATE user_profiles 
SET role = 'super_admin'
WHERE email = 'your.email@example.com';

-- Option 2: Set super_admin by user_id
-- Replace 'USER_ID_HERE' with your actual user_id from auth.users
-- UPDATE user_profiles 
-- SET role = 'super_admin'
-- WHERE user_id = 'USER_ID_HERE';

-- Option 3: Set the first registered user as super_admin
-- UPDATE user_profiles 
-- SET role = 'super_admin'
-- WHERE id = (SELECT id FROM user_profiles ORDER BY created_at ASC LIMIT 1);

-- Verify the change
SELECT 
    email,
    first_name,
    surname,
    role,
    created_at
FROM user_profiles
WHERE role = 'super_admin';

SELECT '✅ Super admin assigned successfully!' as status;
