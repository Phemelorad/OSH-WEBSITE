-- ============================================
-- OSH WEBSITE - CLEAN DATABASE SETUP
-- Run this if you're starting fresh or getting errors
-- ============================================

-- Drop existing tables if they exist (be careful in production!)
DROP TABLE IF EXISTS user_activity_log CASCADE;
DROP TABLE IF EXISTS password_reset_requests CASCADE;
DROP TABLE IF EXISTS login_history CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS departments CASCADE;

-- Drop existing views
DROP VIEW IF EXISTS active_users_summary;
DROP VIEW IF EXISTS recent_login_activity;

-- Drop existing functions
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS calculate_session_duration() CASCADE;
DROP FUNCTION IF EXISTS expire_old_password_resets() CASCADE;

-- ============================================
-- 1. DEPARTMENTS TABLE
-- ============================================

CREATE TABLE departments (
    id SERIAL PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert OSH department only
INSERT INTO departments (code, name, description) VALUES
    ('osh', 'Dept. of Occupational Health and Safety', 'Workplace health and safety regulations');

-- ============================================
-- 2. USER PROFILES TABLE
-- ============================================

CREATE TABLE user_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    first_name TEXT NOT NULL,
    surname TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    department TEXT NOT NULL DEFAULT 'osh' CHECK (department = 'osh'),
    location TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. LOGIN HISTORY TABLE
-- ============================================

CREATE TABLE login_history (
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

-- ============================================
-- 4. PASSWORD RESET REQUESTS TABLE
-- ============================================

CREATE TABLE password_reset_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    ip_address INET,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired', 'cancelled'))
);

-- ============================================
-- 5. USER ACTIVITY LOG TABLE
-- ============================================

CREATE TABLE user_activity_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL,
    activity_description TEXT,
    metadata JSONB,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 6. INDEXES
-- ============================================

CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_user_profiles_email ON user_profiles(email);
CREATE INDEX idx_user_profiles_department ON user_profiles(department);
CREATE INDEX idx_user_profiles_active ON user_profiles(is_active);

CREATE INDEX idx_login_history_user_id ON login_history(user_id);
CREATE INDEX idx_login_history_login_time ON login_history(login_time DESC);
CREATE INDEX idx_login_history_successful ON login_history(login_successful);

CREATE INDEX idx_password_reset_user_id ON password_reset_requests(user_id);
CREATE INDEX idx_password_reset_status ON password_reset_requests(status);
CREATE INDEX idx_password_reset_requested_at ON password_reset_requests(requested_at DESC);

CREATE INDEX idx_activity_log_user_id ON user_activity_log(user_id);
CREATE INDEX idx_activity_log_created_at ON user_activity_log(created_at DESC);
CREATE INDEX idx_activity_log_activity_type ON user_activity_log(activity_type);

-- ============================================
-- 7. ROW LEVEL SECURITY
-- ============================================

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE login_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE password_reset_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

-- User Profiles Policies
CREATE POLICY "Users can view own profile"
    ON user_profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
    ON user_profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Login History Policies
CREATE POLICY "Users can view own login history"
    ON login_history FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own login history"
    ON login_history FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Password Reset Policies
CREATE POLICY "Users can view own password reset requests"
    ON password_reset_requests FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Anyone can request password reset"
    ON password_reset_requests FOR INSERT
    WITH CHECK (true);

-- Activity Log Policies
CREATE POLICY "Users can view own activity"
    ON user_activity_log FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own activity"
    ON user_activity_log FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Departments Policies
CREATE POLICY "Authenticated users can view departments"
    ON departments FOR SELECT
    TO authenticated
    USING (true);

-- ============================================
-- 8. FUNCTIONS AND TRIGGERS
-- ============================================

-- Update timestamp function
CREATE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for user_profiles
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Session duration function
CREATE FUNCTION calculate_session_duration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.logout_time IS NOT NULL AND OLD.logout_time IS NULL THEN
        NEW.session_duration = NEW.logout_time - NEW.login_time;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for login_history
CREATE TRIGGER calculate_login_session_duration
    BEFORE UPDATE ON login_history
    FOR EACH ROW
    EXECUTE FUNCTION calculate_session_duration();

-- Expire old password resets
CREATE FUNCTION expire_old_password_resets()
RETURNS void AS $$
BEGIN
    UPDATE password_reset_requests
    SET status = 'expired'
    WHERE status = 'pending'
    AND requested_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 9. VIEWS
-- ============================================

CREATE VIEW active_users_summary AS
SELECT 
    up.department,
    d.name as department_name,
    COUNT(*) as total_users,
    COUNT(CASE WHEN up.is_active THEN 1 END) as active_users
FROM user_profiles up
LEFT JOIN departments d ON up.department = d.code
GROUP BY up.department, d.name;

CREATE VIEW recent_login_activity AS
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
-- SETUP COMPLETE!
-- ============================================

SELECT 'Database setup completed successfully!' as status;
