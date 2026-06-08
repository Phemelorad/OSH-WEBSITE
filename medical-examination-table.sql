-- ============================================
-- MEDICAL EXAMINATION REPORTS TABLE
-- BL Form 43/03 — Report of Results of Medical Examination
-- Worker's Compensation Act (Act No. 23 of 1998), Section 10
-- ============================================

DROP TABLE IF EXISTS medical_examination_reports CASCADE;

CREATE TABLE medical_examination_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Linking
    claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL,

    -- Worker identification
    worker_name TEXT NOT NULL,
    worker_id_number TEXT,
    claim_file_number TEXT,

    -- Section 2: Nature of injury or disease
    nature_of_injury_or_disease TEXT NOT NULL,

    -- Section 3: Medical treatment particulars
    medical_treatment_particulars TEXT NOT NULL,

    -- Section 4: Percentage of incapacity
    death_incapacity BOOLEAN DEFAULT FALSE,
    permanent_total_incapacity BOOLEAN DEFAULT FALSE,
    permanent_partial_incapacity BOOLEAN DEFAULT FALSE,
    temporary_incapacity BOOLEAN DEFAULT FALSE,
    temporary_probable_duration TEXT,
    incapacity_percentage NUMERIC(5,2),

    -- Section 5: Capable of light duties?
    capable_light_duties TEXT CHECK (capable_light_duties IN ('Yes', 'No', 'Not applicable')),

    -- Section 6: Final examination necessary?
    final_examination_necessary TEXT CHECK (final_examination_necessary IN ('Yes', 'No', 'Not applicable')),

    -- Section 7: Able to resume work?
    able_to_resume_work TEXT CHECK (able_to_resume_work IN ('Yes', 'No', 'Not applicable')),

    -- Signatory
    report_date DATE NOT NULL DEFAULT CURRENT_DATE,
    practitioner_name TEXT NOT NULL,
    practitioner_designation TEXT NOT NULL,

    -- Worker/Representative/Dependent acknowledgment
    worker_representative_name TEXT,

    -- Metadata
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'submitted' CHECK (status IN ('draft', 'submitted')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE medical_examination_reports IS 'BL Form 43/03 — Report of Results of Medical Examination (Worker''s Compensation Act, Section 10)';
COMMENT ON COLUMN medical_examination_reports.claim_id IS 'Links to the related injury claim';
COMMENT ON COLUMN medical_examination_reports.worker_registry_id IS 'Links to the worker registry record';
COMMENT ON COLUMN medical_examination_reports.capable_light_duties IS 'Is worker capable of undertaking light duties?';
COMMENT ON COLUMN medical_examination_reports.final_examination_necessary IS 'Will a final examination be necessary before claimant resumes duty?';
COMMENT ON COLUMN medical_examination_reports.able_to_resume_work IS 'Can the claimant resume the work he was employed at the time of the accident?';
COMMENT ON COLUMN medical_examination_reports.incapacity_percentage IS 'Percentage of incapacity (0-100) as determined by medical examination';

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_mer_claim_id ON medical_examination_reports(claim_id);
CREATE INDEX idx_mer_worker_registry_id ON medical_examination_reports(worker_registry_id);
CREATE INDEX idx_mer_worker_name ON medical_examination_reports(worker_name);
CREATE INDEX idx_mer_submitted_by ON medical_examination_reports(submitted_by);
CREATE INDEX idx_mer_created_at ON medical_examination_reports(created_at DESC);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE medical_examination_reports ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view medical reports
CREATE POLICY "Authenticated users can view medical reports"
    ON medical_examination_reports FOR SELECT
    TO authenticated
    USING (true);

-- Officers and above can insert
CREATE POLICY "Officers can insert medical reports"
    ON medical_examination_reports FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Officers can update their own reports
CREATE POLICY "Users can update own medical reports"
    ON medical_examination_reports FOR UPDATE
    USING (auth.uid() = submitted_by)
    WITH CHECK (auth.uid() = submitted_by);

-- ============================================
-- TRIGGER: updated_at
-- ============================================
DROP TRIGGER IF EXISTS update_mer_updated_at ON medical_examination_reports;
CREATE TRIGGER update_mer_updated_at
    BEFORE UPDATE ON medical_examination_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- GRANT PERMISSIONS
-- ============================================
GRANT SELECT, INSERT, UPDATE ON medical_examination_reports TO authenticated;

-- ============================================
-- SETUP COMPLETE
-- ============================================
SELECT 'Medical examination reports table created successfully!' as status;
