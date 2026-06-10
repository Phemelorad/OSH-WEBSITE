-- ============================================================
--  PERMANENT IMPAIRMENT EVALUATION (Medical Practitioner)
--  Table: permanent_impairment_reports
--  Run this AFTER master-setup.sql
--  Add these lines to master-setup.sql after medical_examination_reports
-- ============================================================

CREATE TABLE IF NOT EXISTS permanent_impairment_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Linked claim
    claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL,

    -- A. Demographic Details
    worker_name          TEXT NOT NULL,
    wcc_ref_no           TEXT,
    date_of_birth        DATE,
    hospital_name_ref    TEXT,
    sex                  TEXT CHECK (sex IN ('Male','Female')),
    report_date          DATE NOT NULL DEFAULT CURRENT_DATE,

    -- B. Medical History (stored as JSON)
    -- { patient: { reviewed, enclosed, description },
    --   hospital: { reviewed_y, reviewed_n, enclosed_y, enclosed_n },
    --   doctor: { reviewed_y, reviewed_n, enclosed_y, enclosed_n },
    --   other: { description } }
    medical_history      JSONB DEFAULT '{}'::jsonb,

    -- C. Clinical Evaluation
    physical_examination           TEXT,
    radiological_exam              TEXT,
    laboratory_test                TEXT,
    special_therapeutic_procedures TEXT,
    specialists_evaluation         TEXT,
    pre_existing_conditions        TEXT,
    impairment_a                   TEXT,
    impairment_b                   TEXT,
    impairment_c                   TEXT,
    impairment_d                   TEXT,
    impairment_e                   TEXT,

    -- Conditions table
    condition_a_text               TEXT,
    condition_b_permanent          TEXT CHECK (condition_b_permanent IN ('Yes','No')),
    condition_c_not_stabilized     TEXT CHECK (condition_c_not_stabilized IN ('Yes','No')),

    -- D. Disability
    unfit_pre_injury_occupation    TEXT CHECK (unfit_pre_injury_occupation IN ('Yes','No')),
    unfit_reasons                  TEXT,
    fit_alternative_duty           TEXT CHECK (fit_alternative_duty IN ('Yes','No')),
    further_harm_possible          TEXT CHECK (further_harm_possible IN ('Yes','No')),
    further_harm_explanation       TEXT,
    restrictions_needed            TEXT CHECK (restrictions_needed IN ('Yes','No')),
    restrictions_explanation       TEXT,

    -- E. Incapacity by body part (JSON array)
    -- [{ body_part: "...", percentage: 0 }]
    incapacity_body_parts          JSONB DEFAULT '[]'::jsonb,
    total_incapacity_pct           NUMERIC(5,2),

    -- F. Care timeframe
    under_care_from                DATE,
    under_care_to                  DATE,
    not_provided_care              BOOLEAN DEFAULT FALSE,
    seen_patient_times             INTEGER,

    -- G. Completed by
    practitioner_name              TEXT NOT NULL,
    practitioner_signature         TEXT,
    practitioner_date              DATE,
    practitioner_address           TEXT,
    practitioner_tel               TEXT,
    practitioner_registered_bhpc   TEXT CHECK (practitioner_registered_bhpc IN ('Yes','No')),
    practitioner_registered_as     TEXT,

    -- Metadata
    submitted_by       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status             TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('draft','submitted','under_review','approved','rejected')),
    created_at         TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at         TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE permanent_impairment_reports IS 'Report of Medical Evaluation of Permanent Impairment — completed by medical practitioners';
COMMENT ON COLUMN permanent_impairment_reports.claim_id IS 'FK to injury_claims — linked claim being evaluated';
COMMENT ON COLUMN permanent_impairment_reports.worker_registry_id IS 'FK to workers_registry — the evaluated worker';
COMMENT ON COLUMN permanent_impairment_reports.incapacity_body_parts IS 'JSON array: [{body_part, percentage}]';
COMMENT ON COLUMN permanent_impairment_reports.medical_history IS 'JSON object with history from patient, hospital, doctor, and other sources';

-- RLS
ALTER TABLE permanent_impairment_reports ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "practitioners can insert" 
    ON permanent_impairment_reports FOR INSERT 
    TO authenticated 
    WITH CHECK (auth.uid() = submitted_by);

CREATE POLICY "practitioners can view own" 
    ON permanent_impairment_reports FOR SELECT 
    TO authenticated 
    USING (
        auth.uid() = submitted_by 
        OR EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_id = auth.uid() 
            AND role IN ('admin', 'super_admin', 'officer')
        )
    );

CREATE POLICY "admins can update" 
    ON permanent_impairment_reports FOR UPDATE 
    TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_id = auth.uid() 
            AND role IN ('admin', 'super_admin')
        )
    );

-- Grants
GRANT SELECT, INSERT, UPDATE ON permanent_impairment_reports TO authenticated;

SELECT '✅ permanent_impairment_reports table created successfully!' AS status;
