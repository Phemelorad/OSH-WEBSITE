-- ============================================================
-- WORKPLACE INSPECTIONS TABLE
-- Captures data from the OSH Inspection Report form
-- Matches the Q1 Report Excel structure exactly
-- ============================================================

-- Ensure updated_at trigger function exists (shared with injury_claims)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================g
-- MAIN TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS workplace_inspections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- ── Identification ──────────────────────────────────────
    file_number         TEXT NOT NULL,
    inspection_date     DATE NOT NULL,
    date_report_sent    DATE,
    days_to_respond     INTEGER,        -- working days between inspection and report sent

    factory_name        TEXT NOT NULL,
    location            TEXT NOT NULL,
    nature_of_work      TEXT NOT NULL,

    -- ── Classification ──────────────────────────────────────
    industry_type       TEXT NOT NULL
        CHECK (industry_type IN (
            'Manufacturing','Services','Construction',
            'Agriculture','Transport','Retail','Government','Parastatal'
        )),
    registration_status TEXT NOT NULL
        CHECK (registration_status IN ('Yes','No','N/A')),
    inspection_type     TEXT NOT NULL
        CHECK (inspection_type IN ('Routine','Follow-up','Query','First Time')),

    -- ── Employees ───────────────────────────────────────────
    employees_male      INTEGER NOT NULL DEFAULT 0 CHECK (employees_male   >= 0),
    employees_female    INTEGER NOT NULL DEFAULT 0 CHECK (employees_female >= 0),

    -- ── Inspector ───────────────────────────────────────────
    inspector_name      TEXT NOT NULL,

    -- ── Common Contraventions (S9, S13-S18, S41-S42, S46-S49, S52-S53, S62, S66-S67)
    -- Each column is TRUE when the section was found NON-COMPLIANT
    s9  BOOLEAN DEFAULT FALSE,   -- Registration of Factories
    s13 BOOLEAN DEFAULT FALSE,   -- Fencing of Machinery
    s14 BOOLEAN DEFAULT FALSE,   -- Construction & Maintenance of Fencing
    s15 BOOLEAN DEFAULT FALSE,   -- Operations near unfenced machinery
    s16 BOOLEAN DEFAULT FALSE,   -- Cleaning moving machinery
    s18 BOOLEAN DEFAULT FALSE,   -- Safe working on machinery
    s41 BOOLEAN DEFAULT FALSE,   -- General safety of buildings
    s42 BOOLEAN DEFAULT FALSE,   -- Floors, passages & stairs
    s46 BOOLEAN DEFAULT FALSE,   -- Precautions in case of fire
    s47 BOOLEAN DEFAULT FALSE,   -- Fire equipment
    s48 BOOLEAN DEFAULT FALSE,   -- Means of escape
    s49 BOOLEAN DEFAULT FALSE,   -- Fire drills & notices
    s52 BOOLEAN DEFAULT FALSE,   -- Welfare facilities
    s53 BOOLEAN DEFAULT FALSE,   -- Washing facilities
    s62 BOOLEAN DEFAULT FALSE,   -- First aid
    s66 BOOLEAN DEFAULT FALSE,   -- Protective clothing & equipment
    s67 BOOLEAN DEFAULT FALSE,   -- Safety officer & committee

    -- ── Other Contraventions (S17, S23, S29-S32, S34, S37-S39, S51, S54, S57-S58)
    s17 BOOLEAN DEFAULT FALSE,   -- Explosive / Highly flammable substances
    s23 BOOLEAN DEFAULT FALSE,   -- Chain, ropes & lifting gear
    s29 BOOLEAN DEFAULT FALSE,   -- Lifting machines
    s30 BOOLEAN DEFAULT FALSE,   -- Cranes & hoists
    s31 BOOLEAN DEFAULT FALSE,   -- Boilers & steam receivers
    s32 BOOLEAN DEFAULT FALSE,   -- Air receivers
    s34 BOOLEAN DEFAULT FALSE,   -- Electrical installations
    s37 BOOLEAN DEFAULT FALSE,   -- Dangerous substances
    s38 BOOLEAN DEFAULT FALSE,   -- Reporting of accidents
    s39 BOOLEAN DEFAULT FALSE,   -- Notification of occupational diseases
    s51 BOOLEAN DEFAULT FALSE,   -- Sanitary conveniences
    s54 BOOLEAN DEFAULT FALSE,   -- Accommodation for clothing
    s57 BOOLEAN DEFAULT FALSE,   -- Lighting
    s58 BOOLEAN DEFAULT FALSE,   -- Ventilation

    -- ── Compliance Totals (computed/stored at insert time) ──
    total_contraventions  INTEGER NOT NULL DEFAULT 0,
    non_compliance_pct    INTEGER NOT NULL DEFAULT 0 CHECK (non_compliance_pct BETWEEN 0 AND 100),
    compliance_level      INTEGER NOT NULL DEFAULT 100 CHECK (compliance_level BETWEEN 0 AND 100),

    -- Raw array for flexibility (stores section IDs e.g. '{S9,S13,S46}')
    contraventions        TEXT[],

    -- ── Plant & Machinery ────────────────────────────────────
    -- Stored as JSONB array: [{desc, sn, status, notes}, ...]
    plant_machinery       JSONB,

    -- ── Action & Follow-up ───────────────────────────────────
    action_taken          TEXT NOT NULL
        CHECK (action_taken IN (
            'Advised to Comply','Warned','Compliance Satisfactory',
            'Prohibition Notice Issued','Improvement Notice Issued',
            'Prosecution Recommended'
        )),
    follow_up_required    BOOLEAN NOT NULL DEFAULT FALSE,
    follow_up_date        DATE,

    -- ── Narrative Fields ─────────────────────────────────────
    summary_findings      TEXT,
    non_compliances       TEXT,
    recommendations       TEXT,

    -- ── Metadata ─────────────────────────────────────────────
    submitted_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status                TEXT NOT NULL DEFAULT 'completed'
        CHECK (status IN ('draft','completed','reviewed','closed')),
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at            TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE workplace_inspections IS
    'OSH workplace inspection reports — matches Q1 Excel Inspection Report structure';

-- Column comments for key fields
COMMENT ON COLUMN workplace_inspections.file_number         IS 'OSH file number e.g. OSH-SPRO 4102 I';
COMMENT ON COLUMN workplace_inspections.contraventions      IS 'Array of contravened section IDs e.g. {S9,S13,S46}';
COMMENT ON COLUMN workplace_inspections.total_contraventions IS 'Count of non-compliant sections (a)';
COMMENT ON COLUMN workplace_inspections.non_compliance_pct  IS 'Non-compliance % = total/17 * 100';
COMMENT ON COLUMN workplace_inspections.compliance_level    IS '100 - non_compliance_pct';
COMMENT ON COLUMN workplace_inspections.plant_machinery     IS 'JSON array of plant/machinery with serial numbers';
COMMENT ON COLUMN workplace_inspections.days_to_respond     IS 'Working days between inspection date and report sent date';

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_wi_file_number      ON workplace_inspections(file_number);
CREATE INDEX IF NOT EXISTS idx_wi_inspection_date  ON workplace_inspections(inspection_date DESC);
CREATE INDEX IF NOT EXISTS idx_wi_factory_name     ON workplace_inspections(factory_name);
CREATE INDEX IF NOT EXISTS idx_wi_industry_type    ON workplace_inspections(industry_type);
CREATE INDEX IF NOT EXISTS idx_wi_inspection_type  ON workplace_inspections(inspection_type);
CREATE INDEX IF NOT EXISTS idx_wi_inspector        ON workplace_inspections(inspector_name);
CREATE INDEX IF NOT EXISTS idx_wi_submitted_by     ON workplace_inspections(submitted_by);
CREATE INDEX IF NOT EXISTS idx_wi_status           ON workplace_inspections(status);
CREATE INDEX IF NOT EXISTS idx_wi_compliance       ON workplace_inspections(compliance_level);
CREATE INDEX IF NOT EXISTS idx_wi_created_at       ON workplace_inspections(created_at DESC);

-- GIN index for array search on contraventions
CREATE INDEX IF NOT EXISTS idx_wi_contraventions   ON workplace_inspections USING GIN(contraventions);

-- GIN index for JSONB plant_machinery search
CREATE INDEX IF NOT EXISTS idx_wi_plant            ON workplace_inspections USING GIN(plant_machinery);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================

DROP TRIGGER IF EXISTS update_workplace_inspections_updated_at ON workplace_inspections;
CREATE TRIGGER update_workplace_inspections_updated_at
    BEFORE UPDATE ON workplace_inspections
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE workplace_inspections ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view all inspections
CREATE POLICY "All users can view inspections"
    ON workplace_inspections FOR SELECT
    TO authenticated
    USING (true);

-- Officers and above can insert inspections
CREATE POLICY "Officers and above can insert inspections"
    ON workplace_inspections FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('officer','admin','super_admin')
        )
        AND auth.uid() = submitted_by
    );

-- Officers can update their own inspections; admins can update any
CREATE POLICY "Officers can update own, admins update all"
    ON workplace_inspections FOR UPDATE
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

-- Admins can delete inspections
CREATE POLICY "Admins can delete inspections"
    ON workplace_inspections FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('admin','super_admin')
        )
    );

-- ============================================================
-- VIEWS
-- ============================================================

-- Full inspection list with submitter name (for entries page)
CREATE OR REPLACE VIEW inspection_report_view AS
SELECT
    wi.id,
    wi.file_number,
    wi.inspection_date,
    wi.date_report_sent,
    wi.days_to_respond,
    wi.factory_name,
    wi.location,
    wi.nature_of_work,
    wi.industry_type,
    wi.registration_status,
    wi.inspection_type,
    wi.employees_male,
    wi.employees_female,
    (wi.employees_male + wi.employees_female) AS total_employees,
    wi.inspector_name,
    wi.total_contraventions,
    wi.non_compliance_pct,
    wi.compliance_level,
    wi.contraventions,
    wi.action_taken,
    wi.follow_up_required,
    wi.follow_up_date,
    wi.status,
    wi.created_at,
    up.first_name || ' ' || up.surname AS submitted_by_name
FROM workplace_inspections wi
LEFT JOIN user_profiles up ON wi.submitted_by = up.user_id
ORDER BY wi.inspection_date DESC;

-- Monthly summary (mirrors the Excel Inspection Summary sheet)
CREATE OR REPLACE VIEW inspection_monthly_summary AS
SELECT
    TO_CHAR(inspection_date, 'YYYY-MM')         AS month,
    TO_CHAR(inspection_date, 'Month YYYY')       AS month_label,
    industry_type,
    COUNT(*)                                     AS total_inspections,
    COUNT(*) FILTER (WHERE inspection_type = 'Routine')    AS routine,
    COUNT(*) FILTER (WHERE inspection_type = 'Follow-up')  AS follow_up,
    COUNT(*) FILTER (WHERE inspection_type = 'Query')      AS query,
    SUM(employees_male)                          AS total_male,
    SUM(employees_female)                        AS total_female,
    SUM(employees_male + employees_female)       AS total_employees,
    ROUND(AVG(compliance_level), 1)              AS avg_compliance_pct,
    SUM(total_contraventions)                    AS total_contraventions,
    COUNT(*) FILTER (WHERE registration_status = 'Yes') AS registered,
    COUNT(*) FILTER (WHERE registration_status = 'No')  AS not_registered
FROM workplace_inspections
GROUP BY TO_CHAR(inspection_date, 'YYYY-MM'),
         TO_CHAR(inspection_date, 'Month YYYY'),
         industry_type
ORDER BY month DESC, industry_type;

-- Inspector performance view
CREATE OR REPLACE VIEW inspection_inspector_summary AS
SELECT
    inspector_name,
    TO_CHAR(inspection_date, 'YYYY-MM') AS month,
    industry_type,
    COUNT(*) AS total_inspections,
    ROUND(AVG(compliance_level), 1) AS avg_compliance_pct
FROM workplace_inspections
GROUP BY inspector_name, TO_CHAR(inspection_date, 'YYYY-MM'), industry_type
ORDER BY month DESC, inspector_name;

-- Contraventions frequency (which sections are most commonly breached)
CREATE OR REPLACE VIEW contravention_frequency AS
SELECT
    section_id,
    COUNT(*) AS times_breached,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM workplace_inspections), 1) AS breach_rate_pct
FROM workplace_inspections,
     UNNEST(contraventions) AS section_id
GROUP BY section_id
ORDER BY times_breached DESC;

-- Inspections with follow-up pending
CREATE OR REPLACE VIEW inspections_pending_followup AS
SELECT
    id,
    file_number,
    factory_name,
    location,
    inspection_date,
    follow_up_date,
    inspector_name,
    compliance_level,
    action_taken
FROM workplace_inspections
WHERE follow_up_required = TRUE
  AND status != 'closed'
ORDER BY follow_up_date ASC NULLS LAST;

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Compute and store compliance totals automatically on insert/update
CREATE OR REPLACE FUNCTION compute_compliance_totals()
RETURNS TRIGGER AS $$
DECLARE
    total INT := 0;
BEGIN
    -- Count TRUE boolean columns (common contraventions only — 17 sections)
    total := (
        (NEW.s9 ::int) + (NEW.s13::int) + (NEW.s14::int) +
        (NEW.s15::int) + (NEW.s16::int) + (NEW.s18::int) +
        (NEW.s41::int) + (NEW.s42::int) + (NEW.s46::int) +
        (NEW.s47::int) + (NEW.s48::int) + (NEW.s49::int) +
        (NEW.s52::int) + (NEW.s53::int) + (NEW.s62::int) +
        (NEW.s66::int) + (NEW.s67::int)
    );

    NEW.total_contraventions := total;
    NEW.non_compliance_pct   := ROUND((total::NUMERIC / 17) * 100);
    NEW.compliance_level     := 100 - ROUND((total::NUMERIC / 17) * 100);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_compute_compliance ON workplace_inspections;
CREATE TRIGGER trg_compute_compliance
    BEFORE INSERT OR UPDATE ON workplace_inspections
    FOR EACH ROW
    EXECUTE FUNCTION compute_compliance_totals();

-- Statistics function (for dashboard cards)
CREATE OR REPLACE FUNCTION get_inspection_statistics()
RETURNS TABLE (
    total_inspections       BIGINT,
    inspections_this_month  BIGINT,
    inspections_this_quarter BIGINT,
    avg_compliance_pct      NUMERIC,
    follow_ups_pending      BIGINT,
    total_factories_visited BIGINT,
    total_registered        BIGINT,
    total_not_registered    BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT,
        COUNT(*) FILTER (WHERE inspection_date >= DATE_TRUNC('month',  NOW()))::BIGINT,
        COUNT(*) FILTER (WHERE inspection_date >= DATE_TRUNC('quarter', NOW()))::BIGINT,
        ROUND(AVG(compliance_level), 1),
        COUNT(*) FILTER (WHERE follow_up_required = TRUE AND status != 'closed')::BIGINT,
        COUNT(DISTINCT factory_name)::BIGINT,
        COUNT(*) FILTER (WHERE registration_status = 'Yes')::BIGINT,
        COUNT(*) FILTER (WHERE registration_status = 'No')::BIGINT
    FROM workplace_inspections;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- GRANT PERMISSIONS
-- ============================================================

GRANT SELECT, INSERT, UPDATE ON workplace_inspections         TO authenticated;
GRANT SELECT ON inspection_report_view                        TO authenticated;
GRANT SELECT ON inspection_monthly_summary                    TO authenticated;
GRANT SELECT ON inspection_inspector_summary                  TO authenticated;
GRANT SELECT ON contravention_frequency                       TO authenticated;
GRANT SELECT ON inspections_pending_followup                  TO authenticated;

-- ============================================================
-- VERIFICATION
-- ============================================================

SELECT 'workplace_inspections table created successfully!' AS status;

-- Show table structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'workplace_inspections'
ORDER BY ordinal_position;

-- Show RLS policies
SELECT policyname, cmd, roles
FROM pg_policies
WHERE tablename = 'workplace_inspections'
ORDER BY cmd;
