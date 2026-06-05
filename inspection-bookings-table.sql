-- ============================================================
-- INSPECTION BOOKINGS TABLE
-- Companies can request/book an inspection via this table
-- ============================================================

CREATE TABLE IF NOT EXISTS inspection_bookings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Company info
    company_name        TEXT NOT NULL,
    company_id          UUID REFERENCES companies(id) ON DELETE SET NULL,
    contact_name        TEXT NOT NULL,
    contact_email       TEXT NOT NULL,
    contact_phone       TEXT,

    -- Booking details
    preferred_date      DATE,
    preferred_time      TEXT,        -- e.g. 'Morning', 'Afternoon'
    inspection_type     TEXT NOT NULL DEFAULT 'Routine'
        CHECK (inspection_type IN ('Routine','Follow-up','First Time','Query')),
    location            TEXT NOT NULL,
    nature_of_work      TEXT,
    industry_type       TEXT,

    -- Additional info
    notes               TEXT,
    special_requirements TEXT,

    -- Status
    status              TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','approved','scheduled','completed','cancelled')),
    assigned_inspector  TEXT,
    scheduled_date      DATE,
    scheduled_time      TEXT,
    admin_notes         TEXT,

    -- Metadata
    submitted_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE inspection_bookings IS 'Inspection booking requests submitted by companies';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ib_company_name   ON inspection_bookings(company_name);
CREATE INDEX IF NOT EXISTS idx_ib_status         ON inspection_bookings(status);
CREATE INDEX IF NOT EXISTS idx_ib_company_id     ON inspection_bookings(company_id);
CREATE INDEX IF NOT EXISTS idx_ib_submitted_by   ON inspection_bookings(submitted_by);

-- Updated_at trigger
DROP TRIGGER IF EXISTS update_inspection_bookings_updated_at ON inspection_bookings;
CREATE TRIGGER update_inspection_bookings_updated_at
    BEFORE UPDATE ON inspection_bookings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE inspection_bookings ENABLE ROW LEVEL SECURITY;

-- Companies can view their own bookings
CREATE POLICY "Companies can view own bookings"
    ON inspection_bookings FOR SELECT
    TO authenticated
    USING (
        submitted_by = auth.uid()
        OR EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('officer','admin','super_admin')
        )
    );

-- Companies can insert bookings
CREATE POLICY "Company users can insert bookings"
    ON inspection_bookings FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('company','officer','admin','super_admin')
        )
    );

-- Officers can update bookings
CREATE POLICY "Officers can update bookings"
    ON inspection_bookings FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('officer','admin','super_admin')
        )
    );

GRANT SELECT, INSERT ON inspection_bookings TO authenticated;
GRANT UPDATE ON inspection_bookings TO authenticated;

SELECT 'inspection_bookings table created successfully!' AS status;
