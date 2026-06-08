-- ============================================================
-- COMPANIES TABLE & COMPANY USER SETUP
-- Enables company registration and per-company data views
-- Run this in Supabase SQL Editor
-- ============================================================

-- ── 1. Companies table ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS companies (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_name    TEXT NOT NULL UNIQUE,
    industry        TEXT,
    location        TEXT,
    telephone       TEXT,
    owner_name      TEXT,
    owner_email     TEXT,
    cipa_number     TEXT,
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE companies IS 'Registered companies that can log in to view their own data';
COMMENT ON COLUMN companies.company_name IS 'Company name used to match against accident_reports.occupier_name, workplace_inspections.factory_name, etc.';

-- Index for name-based lookups (matching against report tables)
CREATE INDEX IF NOT EXISTS idx_companies_name ON companies(company_name);

-- ── 2. Add company_id to user_profiles ──────────────────────
ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS company_id UUID
        REFERENCES companies(id) ON DELETE SET NULL;

-- ── 3. Add 'company' to the role check constraint ──────────
-- Drop old constraint and recreate with 'company' included
ALTER TABLE user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_role_check;

ALTER TABLE user_profiles
    ADD CONSTRAINT user_profiles_role_check
    CHECK (role IN ('viewer', 'officer', 'admin', 'super_admin', 'company'));

-- ── 4. Update department constraint to allow company/general ─
ALTER TABLE user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_department_check;

ALTER TABLE user_profiles
    ADD CONSTRAINT user_profiles_department_check
    CHECK (department IN ('osh', 'company', 'general'));

COMMENT ON COLUMN user_profiles.company_id IS 'FK to companies table — set when user is a company representative';
COMMENT ON COLUMN user_profiles.role IS 'User role: viewer, officer, admin, super_admin, or company';

-- ── 5. Indexes ──────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_up_company_id ON user_profiles(company_id);

-- ── 6. RLS: companies table ─────────────────────────────────
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view companies (needed for auto-fill, filtering)
CREATE POLICY "All authenticated users can view companies"
    ON companies FOR SELECT
    TO authenticated USING (true);

-- Anyone can insert a company (registration)
CREATE POLICY "Anyone can insert companies"
    ON companies FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Company users can update their own company; admins can update any
CREATE POLICY "Company users can update own, admins update all"
    ON companies FOR UPDATE
    TO authenticated
    USING (
        id IN (
            SELECT company_id FROM user_profiles WHERE user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('admin', 'super_admin')
        )
    );

-- ── 7. Updated-at trigger ──────────────────────────────────
DROP TRIGGER IF EXISTS update_companies_updated_at ON companies;
CREATE TRIGGER update_companies_updated_at
    BEFORE UPDATE ON companies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 8. Grants ──────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE ON companies TO authenticated;

-- ── 9. Verify ──────────────────────────────────────────────
SELECT 'companies table created successfully!' AS status;

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'companies'
ORDER BY ordinal_position;
