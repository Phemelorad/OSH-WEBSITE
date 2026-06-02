-- ============================================
-- INJURY CLAIMS TABLE
-- Stores injury claim form submissions
-- ============================================

-- Drop existing table if exists
DROP TABLE IF EXISTS injury_claims CASCADE;

-- Create injury claims table
CREATE TABLE injury_claims (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Claim Information
    file_number TEXT NOT NULL UNIQUE,
    name_of_employer TEXT NOT NULL,
    industry TEXT NOT NULL,
    
    -- Claimant Information
    name_of_claimant TEXT NOT NULL,
    location TEXT NOT NULL,
    nationality TEXT NOT NULL,
    
    -- Injury Details
    date_of_injury DATE NOT NULL,
    date_reported DATE NOT NULL,
    date_received DATE NOT NULL,
    cause TEXT NOT NULL,
    nature TEXT NOT NULL,
    incapacity_percentage NUMERIC(5,2) NOT NULL CHECK (incapacity_percentage >= 0 AND incapacity_percentage <= 100),
    
    -- Metadata
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'approved', 'rejected', 'closed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add comments to table
COMMENT ON TABLE injury_claims IS 'Stores injury claim form submissions from OSH website';

-- Add comments to columns
COMMENT ON COLUMN injury_claims.file_number IS 'Unique file number for the claim';
COMMENT ON COLUMN injury_claims.incapacity_percentage IS 'Percentage of incapacity (0-100)';
COMMENT ON COLUMN injury_claims.status IS 'Current status of the claim';
COMMENT ON COLUMN injury_claims.submitted_by IS 'User who submitted the claim';

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX idx_injury_claims_file_number ON injury_claims(file_number);
CREATE INDEX idx_injury_claims_submitted_by ON injury_claims(submitted_by);
CREATE INDEX idx_injury_claims_status ON injury_claims(status);
CREATE INDEX idx_injury_claims_date_of_injury ON injury_claims(date_of_injury DESC);
CREATE INDEX idx_injury_claims_date_received ON injury_claims(date_received DESC);
CREATE INDEX idx_injury_claims_created_at ON injury_claims(created_at DESC);
CREATE INDEX idx_injury_claims_employer ON injury_claims(name_of_employer);
CREATE INDEX idx_injury_claims_industry ON injury_claims(industry);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE injury_claims ENABLE ROW LEVEL SECURITY;

-- Users can view their own submitted claims
CREATE POLICY "Users can view own claims"
    ON injury_claims FOR SELECT
    USING (auth.uid() = submitted_by);

-- Users can insert their own claims
CREATE POLICY "Users can insert own claims"
    ON injury_claims FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = submitted_by);

-- Users can update their own pending claims
CREATE POLICY "Users can update own pending claims"
    ON injury_claims FOR UPDATE
    USING (auth.uid() = submitted_by AND status = 'pending')
    WITH CHECK (auth.uid() = submitted_by);

-- Allow all authenticated users to view all claims (optional - remove if not needed)
CREATE POLICY "Authenticated users can view all claims"
    ON injury_claims FOR SELECT
    TO authenticated
    USING (true);

-- ============================================
-- TRIGGERS
-- ============================================

-- Update timestamp trigger
CREATE TRIGGER update_injury_claims_updated_at
    BEFORE UPDATE ON injury_claims
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- VIEWS FOR REPORTING
-- ============================================

-- Claims summary by status
CREATE OR REPLACE VIEW injury_claims_summary AS
SELECT 
    status,
    COUNT(*) as total_claims,
    AVG(incapacity_percentage) as avg_incapacity,
    MIN(date_of_injury) as earliest_injury,
    MAX(date_of_injury) as latest_injury
FROM injury_claims
GROUP BY status;

-- Claims by industry
CREATE OR REPLACE VIEW injury_claims_by_industry AS
SELECT 
    industry,
    COUNT(*) as total_claims,
    AVG(incapacity_percentage) as avg_incapacity,
    COUNT(CASE WHEN status = 'approved' THEN 1 END) as approved_claims,
    COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected_claims,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_claims
FROM injury_claims
GROUP BY industry
ORDER BY total_claims DESC;

-- Recent claims view
CREATE OR REPLACE VIEW recent_injury_claims AS
SELECT 
    ic.id,
    ic.file_number,
    ic.name_of_employer,
    ic.name_of_claimant,
    ic.date_of_injury,
    ic.incapacity_percentage,
    ic.status,
    ic.created_at,
    up.first_name || ' ' || up.surname as submitted_by_name
FROM injury_claims ic
LEFT JOIN user_profiles up ON ic.submitted_by = up.user_id
ORDER BY ic.created_at DESC
LIMIT 100;

-- Claims requiring attention (pending for more than 7 days)
CREATE OR REPLACE VIEW claims_requiring_attention AS
SELECT 
    ic.id,
    ic.file_number,
    ic.name_of_employer,
    ic.name_of_claimant,
    ic.date_of_injury,
    ic.status,
    ic.created_at,
    EXTRACT(DAY FROM NOW() - ic.created_at) as days_pending
FROM injury_claims ic
WHERE ic.status = 'pending'
AND ic.created_at < NOW() - INTERVAL '7 days'
ORDER BY ic.created_at ASC;

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to get claim statistics
CREATE OR REPLACE FUNCTION get_claim_statistics()
RETURNS TABLE (
    total_claims BIGINT,
    pending_claims BIGINT,
    approved_claims BIGINT,
    rejected_claims BIGINT,
    avg_incapacity NUMERIC,
    claims_this_month BIGINT,
    claims_this_year BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_claims,
        COUNT(CASE WHEN status = 'pending' THEN 1 END)::BIGINT as pending_claims,
        COUNT(CASE WHEN status = 'approved' THEN 1 END)::BIGINT as approved_claims,
        COUNT(CASE WHEN status = 'rejected' THEN 1 END)::BIGINT as rejected_claims,
        AVG(incapacity_percentage) as avg_incapacity,
        COUNT(CASE WHEN created_at >= DATE_TRUNC('month', NOW()) THEN 1 END)::BIGINT as claims_this_month,
        COUNT(CASE WHEN created_at >= DATE_TRUNC('year', NOW()) THEN 1 END)::BIGINT as claims_this_year
    FROM injury_claims;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

GRANT SELECT, INSERT, UPDATE ON injury_claims TO authenticated;
GRANT SELECT ON injury_claims_summary TO authenticated;
GRANT SELECT ON injury_claims_by_industry TO authenticated;
GRANT SELECT ON recent_injury_claims TO authenticated;
GRANT SELECT ON claims_requiring_attention TO authenticated;

-- ============================================
-- SETUP COMPLETE
-- ============================================

SELECT 'Injury claims table created successfully!' as status;

-- Show table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'injury_claims'
ORDER BY ordinal_position;
