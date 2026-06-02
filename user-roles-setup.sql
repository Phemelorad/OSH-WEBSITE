-- ============================================
-- USER ROLES AND PERMISSIONS SYSTEM
-- Roles: viewer, officer, admin, super_admin
-- ============================================

-- Add role column to user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'viewer' CHECK (role IN ('viewer', 'officer', 'admin', 'super_admin'));

-- Add index for role column
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON user_profiles(role);

-- Add comment
COMMENT ON COLUMN user_profiles.role IS 'User role: viewer, officer, admin, or super_admin';

-- ============================================
-- UPDATE RLS POLICIES FOR user_profiles
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;

-- SELECT: All authenticated users can view all profiles
CREATE POLICY "All users can view profiles"
    ON user_profiles FOR SELECT
    TO authenticated
    USING (true);

-- INSERT: Users can insert their own profile (default role is viewer)
CREATE POLICY "Users can insert own profile"
    ON user_profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- UPDATE: Complex rules based on role
CREATE POLICY "Users can update based on role"
    ON user_profiles FOR UPDATE
    TO authenticated
    USING (
        -- Users can update their own profile
        auth.uid() = user_id
        OR
        -- Admins and super_admins can update other profiles
        (
            EXISTS (
                SELECT 1 FROM user_profiles 
                WHERE user_id = auth.uid() 
                AND role IN ('admin', 'super_admin')
            )
        )
    )
    WITH CHECK (
        -- Users can update their own profile (but not their role)
        (auth.uid() = user_id AND role = (SELECT role FROM user_profiles WHERE user_id = auth.uid()))
        OR
        -- Admins can update non-super_admin profiles
        (
            EXISTS (
                SELECT 1 FROM user_profiles up
                WHERE up.user_id = auth.uid() 
                AND up.role = 'admin'
            )
            AND role != 'super_admin'
            AND (SELECT role FROM user_profiles WHERE user_id = user_profiles.user_id) != 'super_admin'
        )
        OR
        -- Super admins can update anyone (including other super admins)
        (
            EXISTS (
                SELECT 1 FROM user_profiles 
                WHERE user_id = auth.uid() 
                AND role = 'super_admin'
            )
        )
    );

-- ============================================
-- UPDATE RLS POLICIES FOR injury_claims
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Authenticated users can view all claims" ON injury_claims;
DROP POLICY IF EXISTS "Users can insert own claims" ON injury_claims;
DROP POLICY IF EXISTS "Users can update own pending claims" ON injury_claims;

-- SELECT: All authenticated users can view all claims
CREATE POLICY "All users can view claims"
    ON injury_claims FOR SELECT
    TO authenticated
    USING (true);

-- INSERT: Officers, admins, and super_admins can insert claims
CREATE POLICY "Officers and above can insert claims"
    ON injury_claims FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_id = auth.uid() 
            AND role IN ('officer', 'admin', 'super_admin')
        )
        AND auth.uid() = submitted_by
    );

-- UPDATE: Officers can update claims, admins can update any claim
CREATE POLICY "Officers and above can update claims"
    ON injury_claims FOR UPDATE
    TO authenticated
    USING (
        -- Officers can update claims they submitted
        (
            EXISTS (
                SELECT 1 FROM user_profiles 
                WHERE user_id = auth.uid() 
                AND role = 'officer'
            )
            AND auth.uid() = submitted_by
        )
        OR
        -- Admins and super_admins can update any claim
        (
            EXISTS (
                SELECT 1 FROM user_profiles 
                WHERE user_id = auth.uid() 
                AND role IN ('admin', 'super_admin')
            )
        )
    )
    WITH CHECK (
        -- Officers can only update their own claims
        (
            EXISTS (
                SELECT 1 FROM user_profiles 
                WHERE user_id = auth.uid() 
                AND role = 'officer'
            )
            AND auth.uid() = submitted_by
        )
        OR
        -- Admins and super_admins can update any claim
        (
            EXISTS (
                SELECT 1 FROM user_profiles 
                WHERE user_id = auth.uid() 
                AND role IN ('admin', 'super_admin')
            )
        )
    );

-- ============================================
-- CREATE ROLES REFERENCE TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS user_roles_info (
    role TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    description TEXT NOT NULL,
    permissions JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert role information
INSERT INTO user_roles_info (role, display_name, description, permissions) VALUES
    ('viewer', 'Viewer', 'Can only view claims and entries. No edit or submit permissions.', 
     '{"view_claims": true, "submit_claims": false, "edit_claims": false, "access_admin": false, "manage_users": false}'::jsonb),
    ('officer', 'Officer', 'Can view, submit, and edit their own claims. No admin panel access.',
     '{"view_claims": true, "submit_claims": true, "edit_claims": true, "access_admin": false, "manage_users": false}'::jsonb),
    ('admin', 'Admin', 'Can manage all claims and access admin panel. Can edit all users except super admins.',
     '{"view_claims": true, "submit_claims": true, "edit_claims": true, "access_admin": true, "manage_users": true}'::jsonb),
    ('super_admin', 'Super Admin', 'Full system access. Can manage all users including other super admins.',
     '{"view_claims": true, "submit_claims": true, "edit_claims": true, "access_admin": true, "manage_users": true, "manage_super_admins": true}'::jsonb)
ON CONFLICT (role) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    permissions = EXCLUDED.permissions;

-- Enable RLS on roles table
ALTER TABLE user_roles_info ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to view roles
CREATE POLICY "All users can view role info"
    ON user_roles_info FOR SELECT
    TO authenticated
    USING (true);

-- ============================================
-- HELPER FUNCTION TO CHECK USER ROLE
-- ============================================

CREATE OR REPLACE FUNCTION get_user_role(user_uuid UUID)
RETURNS TEXT AS $$
    SELECT role FROM user_profiles WHERE user_id = user_uuid;
$$ LANGUAGE SQL SECURITY DEFINER;

CREATE OR REPLACE FUNCTION current_user_role()
RETURNS TEXT AS $$
    SELECT role FROM user_profiles WHERE user_id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER;

CREATE OR REPLACE FUNCTION has_permission(permission_name TEXT)
RETURNS BOOLEAN AS $$
    SELECT COALESCE(
        (permissions->permission_name)::boolean,
        false
    )
    FROM user_roles_info
    WHERE role = (SELECT role FROM user_profiles WHERE user_id = auth.uid());
$$ LANGUAGE SQL SECURITY DEFINER;

-- ============================================
-- CREATE AUDIT LOG FOR ROLE CHANGES
-- ============================================

CREATE TABLE IF NOT EXISTS role_change_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    old_role TEXT,
    new_role TEXT,
    changed_by UUID REFERENCES auth.users(id),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reason TEXT
);

-- Enable RLS
ALTER TABLE role_change_log ENABLE ROW LEVEL SECURITY;

-- Only admins and super_admins can view the log
CREATE POLICY "Admins can view role changes"
    ON role_change_log FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_id = auth.uid() 
            AND role IN ('admin', 'super_admin')
        )
    );

-- Create trigger to log role changes
CREATE OR REPLACE FUNCTION log_role_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.role IS DISTINCT FROM NEW.role THEN
        INSERT INTO role_change_log (user_id, old_role, new_role, changed_by)
        VALUES (NEW.user_id, OLD.role, NEW.role, auth.uid());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS role_change_trigger ON user_profiles;
CREATE TRIGGER role_change_trigger
    AFTER UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION log_role_change();

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

GRANT SELECT ON user_roles_info TO authenticated;
GRANT SELECT ON role_change_log TO authenticated;

-- ============================================
-- VERIFICATION
-- ============================================

-- Show current policies
SELECT tablename, policyname, cmd, roles 
FROM pg_policies 
WHERE tablename IN ('user_profiles', 'injury_claims')
ORDER BY tablename, cmd;

-- Show role distribution
SELECT 
    role,
    COUNT(*) as user_count
FROM user_profiles
GROUP BY role
ORDER BY 
    CASE role
        WHEN 'super_admin' THEN 1
        WHEN 'admin' THEN 2
        WHEN 'officer' THEN 3
        WHEN 'viewer' THEN 4
    END;

SELECT '✅ User roles system set up successfully!' as status;
