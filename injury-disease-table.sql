-- ============================================================
-- INJURY AND DISEASE REPORTS TABLE  (BL Form 43/10)
-- Worker's Compensation Act, No. 23 of 1998 — Section 9(1)
-- ============================================================

CREATE TABLE IF NOT EXISTS injury_disease_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- ── Worker ───────────────────────────────────────────────
    worker_name         TEXT NOT NULL,
    worker_address      TEXT NOT NULL,
    occupation          TEXT NOT NULL,
    worker_id_number    TEXT,

    -- ── Incident ─────────────────────────────────────────────
    incident_date       DATE NOT NULL,
    place_of_accident   TEXT NOT NULL,
    incident_type       TEXT NOT NULL
        CHECK (incident_type IN ('Injury','Disease','Both')),
    nature_of_injuries  TEXT NOT NULL,

    -- ── Outcome (Yes/No) ─────────────────────────────────────
    resulted_death          TEXT CHECK (resulted_death       IN ('Yes','No')),
    permanent_incapacity    TEXT CHECK (permanent_incapacity IN ('Yes','No')),
    temporary_incapacity    TEXT CHECK (temporary_incapacity IN ('Yes','No')),
    nok_informed            TEXT CHECK (nok_informed         IN ('Yes','No')),

    -- ── Employer ─────────────────────────────────────────────
    employer_name       TEXT NOT NULL,
    employer_telephone  TEXT,
    employer_fax        TEXT,

    -- ── Submission ───────────────────────────────────────────
    report_date             DATE NOT NULL DEFAULT CURRENT_DATE,
    signatory_name          TEXT,
    signatory_designation   TEXT,

    -- ── Metadata ─────────────────────────────────────────────
    submitted_by    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status          TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('submitted','under_review','processed','closed')),
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE injury_disease_reports IS
    'BL Form 43/10 — Injury and Disease Reports under Worker''s Compensation Act No.23 of 1998';

-- ── Indexes ───────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_idr_worker_name     ON injury_disease_reports(worker_name);
CREATE INDEX IF NOT EXISTS idx_idr_incident_date   ON injury_disease_reports(incident_date DESC);
CREATE INDEX IF NOT EXISTS idx_idr_employer_name   ON injury_disease_reports(employer_name);
CREATE INDEX IF NOT EXISTS idx_idr_incident_type   ON injury_disease_reports(incident_type);
CREATE INDEX IF NOT EXISTS idx_idr_resulted_death  ON injury_disease_reports(resulted_death);
CREATE INDEX IF NOT EXISTS idx_idr_status          ON injury_disease_reports(status);
CREATE INDEX IF NOT EXISTS idx_idr_submitted_by    ON injury_disease_reports(submitted_by);
CREATE INDEX IF NOT EXISTS idx_idr_created_at      ON injury_disease_reports(created_at DESC);

-- ── Updated-at trigger ────────────────────────────────────────
DROP TRIGGER IF EXISTS update_injury_disease_reports_updated_at ON injury_disease_reports;
CREATE TRIGGER update_injury_disease_reports_updated_at
    BEFORE UPDATE ON injury_disease_reports
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE injury_disease_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "All users can view injury disease reports"
    ON injury_disease_reports FOR SELECT
    TO authenticated USING (true);

CREATE POLICY "Officers and above can insert injury disease reports"
    ON injury_disease_reports FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('officer','admin','super_admin')
        )
        AND auth.uid() = submitted_by
    );

CREATE POLICY "Officers update own, admins update all injury disease reports"
    ON injury_disease_reports FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = submitted_by
        OR EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('admin','super_admin')
        )
    );

-- ── Views ─────────────────────────────────────────────────────
CREATE OR REPLACE VIEW injury_disease_report_view AS
SELECT
    idr.id,
    idr.worker_name,
    idr.occupation,
    idr.incident_date,
    idr.incident_type,
    idr.place_of_accident,
    idr.resulted_death,
    idr.permanent_incapacity,
    idr.temporary_incapacity,
    idr.employer_name,
    idr.report_date,
    idr.status,
    idr.created_at,
    up.first_name || ' ' || up.surname AS submitted_by_name
FROM injury_disease_reports idr
LEFT JOIN user_profiles up ON idr.submitted_by = up.user_id
ORDER BY idr.incident_date DESC NULLS LAST;

CREATE OR REPLACE VIEW injury_disease_statistics AS
SELECT
    COUNT(*)                                                  AS total_reports,
    COUNT(*) FILTER (WHERE incident_type = 'Injury')         AS injuries,
    COUNT(*) FILTER (WHERE incident_type = 'Disease')        AS diseases,
    COUNT(*) FILTER (WHERE incident_type = 'Both')           AS both,
    COUNT(*) FILTER (WHERE resulted_death = 'Yes')           AS fatalities,
    COUNT(*) FILTER (WHERE permanent_incapacity = 'Yes')     AS permanent_incapacity,
    COUNT(*) FILTER (WHERE temporary_incapacity = 'Yes')     AS temporary_incapacity,
    COUNT(*) FILTER (WHERE incident_date >= DATE_TRUNC('month', NOW())) AS this_month,
    COUNT(*) FILTER (WHERE incident_date >= DATE_TRUNC('year',  NOW())) AS this_year,
    COUNT(*) FILTER (WHERE status = 'submitted')             AS pending_review
FROM injury_disease_reports;

-- ── Grants ───────────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE ON injury_disease_reports      TO authenticated;
GRANT SELECT ON injury_disease_report_view                  TO authenticated;
GRANT SELECT ON injury_disease_statistics                   TO authenticated;

-- ── Verify ───────────────────────────────────────────────────
SELECT 'injury_disease_reports table created successfully!' AS status;

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'injury_disease_reports'
ORDER BY ordinal_position;
