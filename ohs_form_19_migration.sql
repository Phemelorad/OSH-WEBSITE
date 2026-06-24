-- OHS Form 19: Accident Investigation Report
-- Factories Act (Cap. 44:01), Section 57
-- Run this in your Supabase SQL editor

CREATE TABLE IF NOT EXISTS ohs_form_19 (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    submitted_by uuid REFERENCES auth.users(id),
    worker_registry_id uuid REFERENCES public.workers_registry(id),

    -- 1. Investigation Administration
    inv_ref_no TEXT,
    case_no TEXT,
    inv_district TEXT,
    lead_investigator TEXT,
    date_assigned DATE,
    date_opened DATE,
    date_closed DATE,
    inv_status TEXT,
    inv_team TEXT,

    -- 2. Employer Information
    employer_name TEXT,
    company_reg_no TEXT,
    employer_district TEXT,
    employer_city TEXT,
    employer_plot TEXT,
    employer_street TEXT,
    employer_postal TEXT,
    employer_phone TEXT,
    employer_sector TEXT,
    nature_of_work TEXT,
    contact_person TEXT,
    contact_position TEXT,

    -- 3. Injured/Deceased Person(s) Information
    injured_name TEXT,
    injured_id TEXT,
    injured_dob DATE,
    injured_nationality TEXT,
    injured_phone TEXT,
    age_group TEXT,
    sex TEXT,
    marital_status TEXT,
    employment_type TEXT,
    injured_occupation TEXT,
    injured_relationship TEXT,
    injured_address TEXT,
    next_of_kin TEXT,
    next_of_kin_relationship TEXT,

    -- 4. Incident Information
    incident_location TEXT,
    incident_date DATE,
    incident_time TIME,
    incident_reported_date DATE,
    work_experience TEXT,
    job_task_performed TEXT,
    equipment_used TEXT,
    other_injured_count INTEGER,
    first_aid_given TEXT,
    injury_result_fatal BOOLEAN DEFAULT false,
    injury_result_non_fatal BOOLEAN DEFAULT false,
    injury_result_occ_disease BOOLEAN DEFAULT false,
    injury_result_absent BOOLEAN DEFAULT false,
    injury_result_light_duty BOOLEAN DEFAULT false,
    injury_result_sick_leave BOOLEAN DEFAULT false,
    injury_result_dangerous BOOLEAN DEFAULT false,
    days_absent TEXT,
    days_absent_count INTEGER,
    incident_description TEXT,
    incident_summary TEXT,

    -- 5. Incident Type (Cause)
    cause_violence BOOLEAN DEFAULT false,
    cause_assault BOOLEAN DEFAULT false,
    cause_bites BOOLEAN DEFAULT false,
    cause_slips_trips BOOLEAN DEFAULT false,
    cause_slippery BOOLEAN DEFAULT false,
    cause_fall_same BOOLEAN DEFAULT false,
    cause_fall_height BOOLEAN DEFAULT false,
    cause_physical_exertion BOOLEAN DEFAULT false,
    cause_lifting BOOLEAN DEFAULT false,
    cause_overexertion BOOLEAN DEFAULT false,
    cause_jumping BOOLEAN DEFAULT false,
    cause_exposure BOOLEAN DEFAULT false,
    cause_asbestos BOOLEAN DEFAULT false,
    cause_biological BOOLEAN DEFAULT false,
    cause_chemical BOOLEAN DEFAULT false,
    cause_electric_shock BOOLEAN DEFAULT false,
    cause_road_traffic BOOLEAN DEFAULT false,
    cause_fire BOOLEAN DEFAULT false,
    cause_stress BOOLEAN DEFAULT false,
    cause_aggression BOOLEAN DEFAULT false,
    cause_drowning BOOLEAN DEFAULT false,
    cause_other BOOLEAN DEFAULT false,
    cause_other_detail TEXT,

    -- 6. Nature of Injury
    injury_fracture BOOLEAN DEFAULT false,
    injury_cut BOOLEAN DEFAULT false,
    injury_abrasion BOOLEAN DEFAULT false,
    injury_bruise BOOLEAN DEFAULT false,
    injury_sprain BOOLEAN DEFAULT false,
    injury_burn BOOLEAN DEFAULT false,
    injury_elec BOOLEAN DEFAULT false,
    injury_amputation BOOLEAN DEFAULT false,
    injury_blindness BOOLEAN DEFAULT false,
    injury_death BOOLEAN DEFAULT false,
    injury_multiple BOOLEAN DEFAULT false,
    injury_other BOOLEAN DEFAULT false,
    injury_other_detail TEXT,

    -- 7. Part of Body Affected
    body_head BOOLEAN DEFAULT false,
    body_eye BOOLEAN DEFAULT false,
    body_ear BOOLEAN DEFAULT false,
    body_shoulder BOOLEAN DEFAULT false,
    body_arm BOOLEAN DEFAULT false,
    body_wrist BOOLEAN DEFAULT false,
    body_hand BOOLEAN DEFAULT false,
    body_fingers BOOLEAN DEFAULT false,
    body_back BOOLEAN DEFAULT false,
    body_chest BOOLEAN DEFAULT false,
    body_pelvis BOOLEAN DEFAULT false,
    body_knee BOOLEAN DEFAULT false,
    body_ankle BOOLEAN DEFAULT false,
    body_foot BOOLEAN DEFAULT false,
    body_toes BOOLEAN DEFAULT false,
    body_respiratory BOOLEAN DEFAULT false,
    body_no_injury BOOLEAN DEFAULT false,
    injury_description TEXT,

    -- 8. Immediate Cause
    immediate_unsafe_acts TEXT,
    immediate_unsafe_conditions TEXT,

    -- 9. Root Cause
    root_personal_factors TEXT,
    root_job_factors TEXT,

    -- 10. Factual Report (5W1H)
    factual_5w1h TEXT,
    factual_preventive_measures TEXT,
    factual_osh_systems TEXT,
    factual_remedial_actions TEXT,
    factual_osh_adjustments TEXT,

    -- 11. Analysis & Legal Compliance
    analysis_immediate_causes TEXT,
    analysis_underlying_causes TEXT,
    analysis_root_causes TEXT,
    analysis_action_proposed TEXT,

    -- 12. Enforcement Actions
    enforcement_verbal BOOLEAN DEFAULT false,
    enforcement_written BOOLEAN DEFAULT false,
    enforcement_improvement BOOLEAN DEFAULT false,
    enforcement_prohibition BOOLEAN DEFAULT false,
    enforcement_prosecution BOOLEAN DEFAULT false,
    enforcement_details TEXT,

    -- 13. Preventative Action
    prevent_personal TEXT,
    prevent_job TEXT,

    -- 14. Remedial Action Plan
    action_plan_1 TEXT,
    action_owner_1 TEXT,
    action_date_1 DATE,
    action_plan_2 TEXT,
    action_owner_2 TEXT,
    action_date_2 DATE,
    action_plan_3 TEXT,
    action_owner_3 TEXT,
    action_date_3 DATE,
    action_plan_4 TEXT,
    action_owner_4 TEXT,
    action_date_4 DATE,
    action_plan_5 TEXT,
    action_owner_5 TEXT,
    action_date_5 DATE,

    -- 15. Appendices - Witness Register
    witness_date_1 DATE,
    witness_name_1 TEXT,
    witness_role_1 TEXT,
    witness_attach_1 TEXT,
    witness_date_2 DATE,
    witness_name_2 TEXT,
    witness_role_2 TEXT,
    witness_attach_2 TEXT,
    witness_date_3 DATE,
    witness_name_3 TEXT,
    witness_role_3 TEXT,
    witness_attach_3 TEXT,

    -- 15. Appendices - Exhibits Log
    exhibit_ref_1 TEXT,
    exhibit_desc_1 TEXT,
    exhibit_source_1 TEXT,
    exhibit_attach_1 TEXT,
    exhibit_ref_2 TEXT,
    exhibit_desc_2 TEXT,
    exhibit_source_2 TEXT,
    exhibit_attach_2 TEXT,
    exhibit_ref_3 TEXT,
    exhibit_desc_3 TEXT,
    exhibit_source_3 TEXT,
    exhibit_attach_3 TEXT,

    -- 16. 5W1H Checklist
    checklist_who TEXT,
    checklist_what TEXT,
    checklist_when TEXT,
    checklist_where TEXT,
    checklist_why TEXT,
    checklist_how TEXT,

    -- 17. Investigator Declaration
    investigator_name TEXT,
    investigator_designation TEXT,
    investigator_signature TEXT,
    investigator_date DATE,

    -- Metadata
    status TEXT DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE ohs_form_19 ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own submissions"
    ON ohs_form_19 FOR SELECT
    USING (auth.uid() = submitted_by);

CREATE POLICY "Users can insert their own submissions"
    ON ohs_form_19 FOR INSERT
    WITH CHECK (auth.uid() = submitted_by);

CREATE POLICY "Users can update their own submissions"
    ON ohs_form_19 FOR UPDATE
    USING (auth.uid() = submitted_by);

CREATE POLICY "Admins can view all submissions"
    ON ohs_form_19 FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('admin', 'super_admin')
        )
    );

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_ohs_form_19_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_ohs_form_19_updated_at
    BEFORE UPDATE ON ohs_form_19
    FOR EACH ROW
    EXECUTE FUNCTION update_ohs_form_19_updated_at();
