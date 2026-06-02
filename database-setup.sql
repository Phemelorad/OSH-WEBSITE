-- ============================================
-- OSH WEBSITE DATABASE SETUP
-- Supabase SQL Script
-- ============================================

-- ============================================
-- 1. USER PROFILES TABLE
-- Stores additional user information beyond auth
-- ============================================

CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    first_name TEXT NOT NULL,
    surname TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    department TEXT NOT NULL CHECK (department IN (
        'immigration',
        'corporate',
        'civil',
        'osh',
        'labour',
        'employment',
        'archives',
        'library'
    )),
    location TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add comment to table
COMMENT ON TABLE user_profiles IS 'Stores extended user profile information for OSH system users';

-- Add comments to columns
COMMENT ON COLUMN user_profiles.user_id IS 'References the auth.users table';
COMMENT ON COLUMN user_profiles.department IS 'User department code';
COMMENT ON COLUMN user_profiles.location IS 'User physical location or station';
COMMENT ON COLUMN user_profiles.is_active IS 'Whether the user account is active';

-- ============================================
-- 2. DEPARTMENTS REFERENCE TABLE (Optional)
-- For better data management and reporting
-- ============================================

CREATE TABLE IF NOT EXISTS departments (
    id SERIAL PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert department data
INSERT INTO departments (code, name, description) VALUES
    ('immigration', 'Dept. of Immigration and Citizenship', 'Handles immigration and citizenship services'),
    ('corporate', 'Dept. of Corporate Services', 'Manages corporate services and administration'),
    ('civil', 'Dept. of Civil and National Registration', 'Civil registration and national identification'),
    ('osh', 'Dept. of Occupational Health and Safety', 'Workplace health and safety regulations'),
    ('labour', 'Dept. of Labour and Social Security', 'Labor relations and social security'),
    ('employment', 'Dept. of Employment Services', 'Employment services and job placement'),
    ('archives', 'Botswana National Archives and Records Services', 'National archives and records management'),
    ('library', 'Botswana National Library Services', 'National library services')
ON CONFLICT (code) DO NOTHING;

-- ============================================
-- 3. USER LOGIN HISTORY TABLE
-- Track login attempts and sessions
-- ============================================

CREATE TABLE IF NOT EXISTS login_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    login_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    logout_time TIMESTAMP WITH TIME ZONE,
    ip_address INET,
    user_agent TEXT,
    login_successful BOOLEAN DEFAULT true,
    session_duration INTERVAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE login_history IS 'Tracks user login/logout activity and sessions';

-- ============================================
-- 4. PASSWORD RESET REQUESTS TABLE
-- Track password reset requests
-- ============================================

CREATE TABLE IF NOT EXISTS password_reset_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    ip_address INET,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired', 'cancelled'))
);

COMMENT ON TABLE password_reset_requests IS 'Tracks password reset requests for audit purposes';

-- ============================================
-- 5. USER ACTIVITY LOG TABLE
-- General activity logging
-- ============================================

CREATE TABLE IF NOT EXISTS user_activity_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL,
    activity_description TEXT,
    metadata JSONB,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE user_activity_log IS 'General purpose activity logging for users';

-- ============================================
-- 6. INDEXES FOR PERFORMANCE
-- ============================================

-- User profiles indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_department ON user_profiles(department);
CREATE INDEX IF NOT EXISTS idx_user_profiles_active ON user_profiles(is_active);

-- Login history indexes
CREATE INDEX IF NOT EXISTS idx_login_history_user_id ON login_history(user_id);
CREATE INDEX IF NOT EXISTS idx_login_history_login_time ON login_history(login_time DESC);
CREATE INDEX IF NOT EXISTS idx_login_history_successful ON login_history(login_successful);

-- Password reset indexes
CREATE INDEX IF NOT EXISTS idx_password_reset_user_id ON password_reset_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_status ON password_reset_requests(status);
CREATE INDEX IF NOT EXISTS idx_password_reset_requested_at ON password_reset_requests(requested_at DESC);

-- Activity log indexes
CREATE INDEX IF NOT EXISTS idx_activity_log_user_id ON user_activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_created_at ON user_activity_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_log_activity_type ON user_activity_log(activity_type);

-- ============================================
-- 7. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE login_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE password_reset_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

-- User Profiles Policies
-- Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON user_profiles
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own profile during signup
CREATE POLICY "Users can insert own profile"
    ON user_profiles
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON user_profiles
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Login History Policies
-- Users can view their own login history
CREATE POLICY "Users can view own login history"
    ON login_history
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own login records
CREATE POLICY "Users can insert own login history"
    ON login_history
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Password Reset Policies
-- Users can view their own password reset requests
CREATE POLICY "Users can view own password reset requests"
    ON password_reset_requests
    FOR SELECT
    USING (auth.uid() = user_id);

-- Anyone can insert password reset requests (for forgot password)
CREATE POLICY "Anyone can request password reset"
    ON password_reset_requests
    FOR INSERT
    WITH CHECK (true);

-- Activity Log Policies
-- Users can view their own activity
CREATE POLICY "Users can view own activity"
    ON user_activity_log
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own activity
CREATE POLICY "Users can insert own activity"
    ON user_activity_log
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Departments Policies (Read-only for all authenticated users)
CREATE POLICY "Authenticated users can view departments"
    ON departments
    FOR SELECT
    TO authenticated
    USING (true);

-- ============================================
-- 8. TRIGGERS AND FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for user_profiles
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate session duration on logout
CREATE OR REPLACE FUNCTION calculate_session_duration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.logout_time IS NOT NULL AND OLD.logout_time IS NULL THEN
        NEW.session_duration = NEW.logout_time - NEW.login_time;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for login_history
DROP TRIGGER IF EXISTS calculate_login_session_duration ON login_history;
CREATE TRIGGER calculate_login_session_duration
    BEFORE UPDATE ON login_history
    FOR EACH ROW
    EXECUTE FUNCTION calculate_session_duration();

-- Function to automatically expire old password reset requests
CREATE OR REPLACE FUNCTION expire_old_password_resets()
RETURNS void AS $$
BEGIN
    UPDATE password_reset_requests
    SET status = 'expired'
    WHERE status = 'pending'
    AND requested_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 9. VIEWS FOR REPORTING (Optional)
-- ============================================

-- Active users view
CREATE OR REPLACE VIEW active_users_summary AS
SELECT 
    up.department,
    d.name as department_name,
    COUNT(*) as total_users,
    COUNT(CASE WHEN up.is_active THEN 1 END) as active_users
FROM user_profiles up
LEFT JOIN departments d ON up.department = d.code
GROUP BY up.department, d.name;

-- Recent login activity view
CREATE OR REPLACE VIEW recent_login_activity AS
SELECT 
    lh.id,
    up.first_name || ' ' || up.surname as full_name,
    up.email,
    up.department,
    lh.login_time,
    lh.logout_time,
    lh.session_duration,
    lh.login_successful
FROM login_history lh
JOIN user_profiles up ON lh.user_id = up.user_id
ORDER BY lh.login_time DESC
LIMIT 100;

-- ============================================
-- 10. GRANT PERMISSIONS
-- ============================================

-- Grant usage on sequences
GRANT USAGE ON SEQUENCE departments_id_seq TO authenticated;

-- Grant permissions on tables
GRANT SELECT, INSERT, UPDATE ON user_profiles TO authenticated;
GRANT SELECT, INSERT ON login_history TO authenticated;
GRANT SELECT, INSERT ON password_reset_requests TO authenticated;
GRANT SELECT, INSERT ON user_activity_log TO authenticated;
GRANT SELECT ON departments TO authenticated;

-- ============================================
-- SETUP COMPLETE!
-- ============================================

-- Verify setup
SELECT 'Database setup completed successfully!' as status;

-- Check created tables
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_profiles', 'departments', 'login_history', 'password_reset_requests', 'user_activity_log')
ORDER BY table_name;
