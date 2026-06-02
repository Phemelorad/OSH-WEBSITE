-- ============================================================
-- ACCIDENT REPORTS TABLE  (OHS Form 60)
-- Notification of Accident and/or Dangerous Occurrence
-- The Factories Act, 1973 — Section 57
-- ============================================================

CREATE TABLE IF NOT EXISTS accident_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- ── Report Classification ────────────────────────────────
    report_type         TEXT NOT NULL
        CHECK (report_type IN ('accident','dangerous_occurrence','both')),

    -- ── 1. Occupier ──────────────────────────────────────────
    occupier_name       TEXT NOT NULL,

    -- ── 2. Premises ──────────────────────────────────────────
    premises_address    TEXT NOT NULL,

    -- ── 3. Industry ──────────────────────────────────────────
    nature_of_industry  TEXT NOT NULL,
    industry_sector     TEXT NOT NULL
        CHECK (industry_sector IN (
            'Manufacturing','Services','Construction',
            'Agriculture','Transport','Retail','Government','Parastatal'
        )),

    -- ── 4. Injured / Deceased Person ─────────────────────────
    injured_name        TEXT,
    injured_age         INTEGER CHECK (injured_age > 0 AND injured_age < 120),
    injured_sex         TEXT CHECK (injured_sex IN ('Male','Female')),
    injured_id_number   TEXT,
    occupation_at_accident TEXT,
    usual_occupation    TEXT,
    experience_level    TEXT,

    -- ── 5. Accident Details ───────────────────────────────────
    accident_date       DATE,
    accident_time       TIME,
    accident_place      TEXT,
    accident_description TEXT,
    machinery_involved  TEXT,

    -- ── 6. Injury ────────────────────────────────────────────
    injury_fatal        TEXT CHECK (injury_fatal IN ('Fatal','Non-fatal')),
    disabled_three_days TEXT CHECK (disabled_three_days IN ('Yes','No')),
    hourly_pay          NUMERIC(10,2),
    medical_practitioner TEXT,

    -- ── 7. Dangerous Occurrence ──────────────────────────────
    dangerous_date      DATE,
    dangerous_time      TIME,
    dangerous_place     TEXT,
    dangerous_description TEXT,
    dangerous_damage    TEXT,
    employees_injured   TEXT CHECK (employees_injured IN ('Yes','No')),
    notification_submitted TEXT CHECK (notification_submitted IN ('Yes','No')),
    outside_persons_injured TEXT,

    -- ── Report Submission ────────────────────────────────────
    report_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    reporter_name       TEXT NOT NULL,
    reporter_designation TEXT,

    -- ── For Official Use Only ────────────────────────────────
    causation_number        TEXT,
    date_received           DATE,
    investigation_status    TEXT DEFAULT 'Pending'
        CHECK (investigation_status IN ('Pending','In Progress','Completed','Closed')),
    official_action         TEXT,

    -- ── Metadata ─────────────────────────────────────────────
    submitted_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status              TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('submitted','under_review','investigated','closed')),
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE accident_reports IS
    'OHS Form 60 — Notification of Accident and/or Dangerous Occurrence (Factories Act 1973, S.57)';

-- ── Indexes ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_ar_occupier       ON accident_reports(occupier_name);
CREATE INDEX IF NOT EXISTS idx_ar_accident_date  ON accident_reports(accident_date DESC);
CREATE INDEX IF NOT EXISTS idx_ar_report_date    ON accident_reports(report_date DESC);
CREATE INDEX IF NOT EXISTS idx_ar_report_type    ON accident_reports(report_type);
CREATE INDEX IF NOT EXISTS idx_ar_injury_fatal   ON accident_reports(injury_fatal);
CREATE INDEX IF NOT EXISTS idx_ar_inv_status     ON accident_reports(investigation_status);
CREATE INDEX IF NOT EXISTS idx_ar_submitted_by   ON accident_reports(submitted_by);
CREATE INDEX IF NOT EXISTS idx_ar_status         ON accident_reports(status);
CREATE INDEX IF NOT EXISTS idx_ar_created_at     ON accident_reports(created_at DESC);

-- ── Updated-at trigger ────────────────────────────────────────
DROP TRIGGER IF EXISTS update_accident_reports_updated_at ON accident_reports;
CREATE TRIGGER update_accident_reports_updated_at
    BEFORE UPDATE ON accident_reports
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE accident_reports ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view all reports
CREATE POLICY "All users can view accident reports"
    ON accident_reports FOR SELECT
    TO authenticated USING (true);

-- Officers and above can insert
CREATE POLICY "Officers and above can insert accident reports"
    ON accident_reports FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('officer','admin','super_admin')
        )
        AND auth.uid() = submitted_by
    );

-- Officers can update their own; admins can update any
CREATE POLICY "Officers update own, admins update all"
    ON accident_reports FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = submitted_by
        OR EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('admin','super_admin')
        )
    )
    WITH CHECK (
        auth.uid() = submitted_by
        OR EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('admin','super_admin')
        )
    );

-- ── Views ─────────────────────────────────────────────────────

-- Full report list with submitter name
CREATE OR REPLACE VIEW accident_report_view AS
SELECT
    ar.id,
    ar.report_type,
    ar.occupier_name,
    ar.premises_address,
    ar.nature_of_industry,
    ar.industry_sector,
    ar.injured_name,
    ar.injured_age,
    ar.injured_sex,
    ar.accident_date,
    ar.accident_place,
    ar.injury_fatal,
    ar.investigation_status,
    ar.causation_number,
    ar.reporter_name,
    ar.report_date,
    ar.status,
    ar.created_at,
    up.first_name || ' ' || up.surname AS submitted_by_name
FROM accident_reports ar
LEFT JOIN user_profiles up ON ar.submitted_by = up.user_id
ORDER BY ar.accident_date DESC NULLS LAST;

-- Accident statistics summary
CREATE OR REPLACE VIEW accident_statistics AS
SELECT
    COUNT(*)                                            AS total_reports,
    COUNT(*) FILTER (WHERE report_type = 'accident')           AS accidents,
    COUNT(*) FILTER (WHERE report_type = 'dangerous_occurrence') AS dangerous_occurrences,
    COUNT(*) FILTER (WHERE report_type = 'both')               AS both,
    COUNT(*) FILTER (WHERE injury_fatal = 'Fatal')             AS fatalities,
    COUNT(*) FILTER (WHERE injury_fatal = 'Non-fatal')         AS non_fatal_injuries,
    COUNT(*) FILTER (WHERE investigation_status = 'Pending')   AS pending_investigations,
    COUNT(*) FILTER (WHERE investigation_status = 'In Progress') AS investigations_in_progress,
    COUNT(*) FILTER (WHERE investigation_status = 'Completed') AS completed_investigations,
    COUNT(*) FILTER (WHERE accident_date >= DATE_TRUNC('month', NOW())) AS this_month,
    COUNT(*) FILTER (WHERE accident_date >= DATE_TRUNC('year',  NOW())) AS this_year
FROM accident_reports;

-- ── Permissions ───────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE ON accident_reports    TO authenticated;
GRANT SELECT ON accident_report_view                TO authenticated;
GRANT SELECT ON accident_statistics                 TO authenticated;

-- ── Verify ────────────────────────────────────────────────────
SELECT 'accident_reports table created successfully!' AS status;

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'accident_reports'
ORDER BY ordinal_position;
