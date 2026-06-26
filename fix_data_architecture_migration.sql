-- =============================================================================
-- DATA ARCHITECTURE FIXES - v2
-- Run in Supabase SQL Editor AFTER master-setup.sql
-- SAFE to run multiple times
-- =============================================================================

-- PART 1: CREATE MISSING TABLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS bl_form_43_02_wages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_name TEXT, worker_address TEXT,
    employer_name TEXT, employer_designation TEXT,
    employer_signature TEXT, employer_date DATE,
    basic_pay_amount NUMERIC, basic_pay_frequency TEXT,
    average_monthly_wage NUMERIC, other_remuneration_amount NUMERIC,
    month_1_name TEXT, month_1_pay NUMERIC, month_1_voucher TEXT,
    month_2_name TEXT, month_2_pay NUMERIC, month_2_voucher TEXT,
    month_3_name TEXT, month_3_pay NUMERIC, month_3_voucher TEXT,
    month_4_name TEXT, month_4_pay NUMERIC, month_4_voucher TEXT,
    month_5_name TEXT, month_5_pay NUMERIC, month_5_voucher TEXT,
    month_6_name TEXT, month_6_pay NUMERIC, month_6_voucher TEXT,
    month_7_name TEXT, month_7_pay NUMERIC, month_7_voucher TEXT,
    month_8_name TEXT, month_8_pay NUMERIC, month_8_voucher TEXT,
    month_9_name TEXT, month_9_pay NUMERIC, month_9_voucher TEXT,
    month_10_name TEXT, month_10_pay NUMERIC, month_10_voucher TEXT,
    month_11_name TEXT, month_11_pay NUMERIC, month_11_voucher TEXT,
    month_12_name TEXT, month_12_pay NUMERIC, month_12_voucher TEXT,
    submitted_by UUID,
    claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL,
    accident_id UUID REFERENCES accident_reports(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bl_form_43_04_incapacity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_name TEXT, worker_address TEXT,
    employer_name TEXT, accident_date DATE,
    t_earnings_before NUMERIC, t_earnings_during NUMERIC, t_compensation NUMERIC,
    pt_earnings NUMERIC, pt_multiplier NUMERIC, pt_compensation NUMERIC,
    pp_earnings NUMERIC, pp_percentage NUMERIC, pp_multiplier NUMERIC, pp_compensation NUMERIC,
    cc_worker_name TEXT, cc_worker_address TEXT,
    signature TEXT, declaration_date DATE,
    submitted_by UUID,
    claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL,
    accident_id UUID REFERENCES accident_reports(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS certificate_of_insurance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employer_name TEXT, employer_address TEXT,
    insurer_name TEXT, policy_number TEXT,
    coverage_period_start DATE, coverage_period_end DATE,
    signatory_status TEXT, signature TEXT, certificate_date DATE,
    submitted_by UUID,
    claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL,
    accident_id UUID REFERENCES accident_reports(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS medical_attendance_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_name TEXT, worker_address TEXT, worker_id_number TEXT,
    practitioner_name TEXT, date_of_notice DATE,
    date_of_examination DATE, time_of_examination TIME,
    place_of_examination TEXT, signatory_name TEXT,
    notification_date DATE, signature TEXT,
    submitted_by UUID,
    claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL,
    accident_id UUID REFERENCES accident_reports(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ohs_form_19 (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_no TEXT,
    company_reg_no TEXT,
    inv_ref_no TEXT,
    incident_date DATE,
    incident_time TIME,
    incident_reported_date DATE,
    incident_location TEXT,
    incident_summary TEXT,
    incident_description TEXT,
    employer_name TEXT,
    employer_sector TEXT,
    employer_plot TEXT,
    employer_street TEXT,
    employer_city TEXT,
    employer_district TEXT,
    employer_postal TEXT,
    employer_phone TEXT,
    contact_person TEXT,
    contact_position TEXT,
    injured_name TEXT,
    injured_id TEXT,
    injured_dob DATE,
    injured_occupation TEXT,
    injured_phone TEXT,
    injured_address TEXT,
    injured_nationality TEXT,
    injured_relationship TEXT,
    sex TEXT,
    marital_status TEXT,
    age_group TEXT,
    employment_type TEXT,
    work_experience TEXT,
    job_task_performed TEXT,
    equipment_used TEXT,
    days_absent TEXT,
    days_absent_count INT,
    other_injured_count INT,
    nature_of_work TEXT,
    first_aid_given TEXT,
    inv_status TEXT,
    inv_district TEXT,
    inv_team TEXT,
    lead_investigator TEXT,
    date_opened DATE,
    date_closed DATE,
    date_assigned DATE,
    investigator_name TEXT,
    investigator_designation TEXT,
    investigator_date DATE,
    investigator_signature TEXT,
    factual_5w1h TEXT,
    factual_osh_systems TEXT,
    factual_osh_adjustments TEXT,
    factual_preventive_measures TEXT,
    factual_remedial_actions TEXT,
    checklist_who TEXT, checklist_what TEXT, checklist_where TEXT,
    checklist_when TEXT, checklist_why TEXT, checklist_how TEXT,
    immediate_unsafe_acts TEXT,
    immediate_unsafe_conditions TEXT,
    cause_slips_trips BOOLEAN DEFAULT false,
    cause_fall_same BOOLEAN DEFAULT false,
    cause_fall_height BOOLEAN DEFAULT false,
    cause_lifting BOOLEAN DEFAULT false,
    cause_overexertion BOOLEAN DEFAULT false,
    cause_physical_exertion BOOLEAN DEFAULT false,
    cause_assault BOOLEAN DEFAULT false,
    cause_aggression BOOLEAN DEFAULT false,
    cause_violence BOOLEAN DEFAULT false,
    cause_stress BOOLEAN DEFAULT false,
    cause_fire BOOLEAN DEFAULT false,
    cause_slippery BOOLEAN DEFAULT false,
    cause_electric_shock BOOLEAN DEFAULT false,
    cause_road_traffic BOOLEAN DEFAULT false,
    cause_drowning BOOLEAN DEFAULT false,
    cause_asbestos BOOLEAN DEFAULT false,
    cause_chemical BOOLEAN DEFAULT false,
    cause_biological BOOLEAN DEFAULT false,
    cause_exposure BOOLEAN DEFAULT false,
    cause_bites BOOLEAN DEFAULT false,
    cause_jumping BOOLEAN DEFAULT false,
    cause_other BOOLEAN DEFAULT false,
    injury_abrasion BOOLEAN DEFAULT false,
    injury_amputation BOOLEAN DEFAULT false,
    injury_blindness BOOLEAN DEFAULT false,
    injury_bruise BOOLEAN DEFAULT false,
    injury_burn BOOLEAN DEFAULT false,
    injury_cut BOOLEAN DEFAULT false,
    injury_elec BOOLEAN DEFAULT false,
    injury_fracture BOOLEAN DEFAULT false,
    injury_sprain BOOLEAN DEFAULT false,
    injury_multiple BOOLEAN DEFAULT false,
    injury_other BOOLEAN DEFAULT false,
    injury_death BOOLEAN DEFAULT false,
    injury_result_fatal BOOLEAN DEFAULT false,
    injury_result_non_fatal BOOLEAN DEFAULT false,
    injury_result_dangerous BOOLEAN DEFAULT false,
    injury_result_occ_disease BOOLEAN DEFAULT false,
    injury_result_sick_leave BOOLEAN DEFAULT false,
    injury_result_light_duty BOOLEAN DEFAULT false,
    injury_result_absent BOOLEAN DEFAULT false,
    body_head BOOLEAN DEFAULT false,
    body_eye BOOLEAN DEFAULT false,
    body_ear BOOLEAN DEFAULT false,
    body_chest BOOLEAN DEFAULT false,
    body_back BOOLEAN DEFAULT false,
    body_shoulder BOOLEAN DEFAULT false,
    body_arm BOOLEAN DEFAULT false,
    body_hand BOOLEAN DEFAULT false,
    body_fingers BOOLEAN DEFAULT false,
    body_wrist BOOLEAN DEFAULT false,
    body_pelvis BOOLEAN DEFAULT false,
    body_knee BOOLEAN DEFAULT false,
    body_ankle BOOLEAN DEFAULT false,
    body_foot BOOLEAN DEFAULT false,
    body_toes BOOLEAN DEFAULT false,
    body_no_injury BOOLEAN DEFAULT false,
    body_respiratory BOOLEAN DEFAULT false,
    enforcement_verbal BOOLEAN DEFAULT false,
    enforcement_written BOOLEAN DEFAULT false,
    enforcement_improvement BOOLEAN DEFAULT false,
    enforcement_prohibition BOOLEAN DEFAULT false,
    enforcement_prosecution BOOLEAN DEFAULT false,
    cause_other_detail TEXT,
    injury_other_detail TEXT,
    injury_description TEXT,
    analysis_immediate_causes TEXT,
    analysis_underlying_causes TEXT,
    analysis_root_causes TEXT,
    analysis_action_proposed TEXT,
    root_job_factors TEXT,
    root_personal_factors TEXT,
    prevent_job TEXT,
    prevent_personal TEXT,
    action_plan_1 TEXT, action_owner_1 TEXT, action_date_1 DATE,
    action_plan_2 TEXT, action_owner_2 TEXT, action_date_2 DATE,
    action_plan_3 TEXT, action_owner_3 TEXT, action_date_3 DATE,
    action_plan_4 TEXT, action_owner_4 TEXT, action_date_4 DATE,
    action_plan_5 TEXT, action_owner_5 TEXT, action_date_5 DATE,
    enforcement_details TEXT,
    witness_name_1 TEXT, witness_role_1 TEXT, witness_date_1 DATE, witness_attach_1 TEXT,
    witness_name_2 TEXT, witness_role_2 TEXT, witness_date_2 DATE, witness_attach_2 TEXT,
    witness_name_3 TEXT, witness_role_3 TEXT, witness_date_3 DATE, witness_attach_3 TEXT,
    exhibit_ref_1 TEXT, exhibit_desc_1 TEXT, exhibit_source_1 TEXT, exhibit_attach_1 TEXT,
    exhibit_ref_2 TEXT, exhibit_desc_2 TEXT, exhibit_source_2 TEXT, exhibit_attach_2 TEXT,
    exhibit_ref_3 TEXT, exhibit_desc_3 TEXT, exhibit_source_3 TEXT, exhibit_attach_3 TEXT,
    submitted_by UUID,
    accident_id UUID REFERENCES accident_reports(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- PART 2: ADD FK COLUMNS TO EXISTING TABLES
ALTER TABLE workplace_inspections ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES companies(id) ON DELETE SET NULL;
ALTER TABLE permanent_impairment_reports ADD COLUMN IF NOT EXISTS claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL;
ALTER TABLE permanent_impairment_reports ADD COLUMN IF NOT EXISTS worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL;

-- ADD accident_id TO injury_disease_reports
ALTER TABLE injury_disease_reports ADD COLUMN IF NOT EXISTS accident_id UUID REFERENCES accident_reports(id) ON DELETE SET NULL;

-- PART 3: AUTO-GENERATE FILE NUMBERS
CREATE SEQUENCE IF NOT EXISTS accident_file_number_seq START 1;

CREATE OR REPLACE FUNCTION generate_accident_file_number()
RETURNS TRIGGER AS $$
DECLARE
  year_prefix TEXT := to_char(NOW(), 'YYYY');
  seq_num TEXT;
BEGIN
  IF NEW.accident_case_number IS NULL OR btrim(NEW.accident_case_number) = '' THEN
    seq_num := LPAD(nextval('accident_file_number_seq')::TEXT, 4, '0');
    NEW.accident_case_number := 'ACC-' || year_prefix || '-' || seq_num;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_accident_file_number ON accident_reports;
CREATE TRIGGER trg_accident_file_number BEFORE INSERT ON accident_reports FOR EACH ROW EXECUTE FUNCTION generate_accident_file_number();

CREATE SEQUENCE IF NOT EXISTS inspection_file_number_seq START 1;

CREATE OR REPLACE FUNCTION generate_inspection_file_number()
RETURNS TRIGGER AS $$
DECLARE
  year_prefix TEXT := to_char(NOW(), 'YYYY');
  seq_num TEXT;
BEGIN
  IF NEW.file_number IS NULL OR btrim(NEW.file_number) = '' THEN
    seq_num := LPAD(nextval('inspection_file_number_seq')::TEXT, 4, '0');
    NEW.file_number := 'INSP-' || year_prefix || '-' || seq_num;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inspection_file_number ON workplace_inspections;
CREATE TRIGGER trg_inspection_file_number BEFORE INSERT ON workplace_inspections FOR EACH ROW EXECUTE FUNCTION generate_inspection_file_number();


-- PART 4: AUTO-POPULATE WORKERS REGISTRY
CREATE OR REPLACE FUNCTION auto_register_worker()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.injured_id_number IS NOT NULL AND btrim(NEW.injured_id_number) != '' THEN
    INSERT INTO workers_registry (id_number, full_name, age_years, sex, occupation, employer_name)
    VALUES (
      UPPER(TRIM(NEW.injured_id_number)),
      COALESCE(NEW.injured_name, 'Unknown'),
      NEW.injured_age,
      NEW.injured_sex,
      NEW.occupation_at_accident,
      NEW.occupier_name
    )
    ON CONFLICT (id_number) DO UPDATE SET
      full_name = CASE WHEN workers_registry.full_name = 'Unknown' THEN EXCLUDED.full_name ELSE workers_registry.full_name END,
      employer_name = COALESCE(workers_registry.employer_name, EXCLUDED.employer_name);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_register_worker ON accident_reports;
CREATE TRIGGER trg_auto_register_worker AFTER INSERT ON accident_reports FOR EACH ROW EXECUTE FUNCTION auto_register_worker();



-- PART 5: AUTO-GENERATE CAUSATION & INVESTIGATION REFERENCE NUMBERS

-- 5a. causation_number: CAU-YYYY-NNNN on accident_reports
CREATE SEQUENCE IF NOT EXISTS causation_number_seq START 1;

CREATE OR REPLACE FUNCTION generate_causation_number()
RETURNS TRIGGER AS $$
DECLARE
  year_prefix TEXT := to_char(NOW(), 'YYYY');
  seq_num TEXT;
BEGIN
  IF NEW.causation_number IS NULL OR btrim(NEW.causation_number) = '' THEN
    seq_num := LPAD(nextval('causation_number_seq')::TEXT, 4, '0');
    NEW.causation_number := 'CAU-' || year_prefix || '-' || seq_num;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_causation_number ON accident_reports;
CREATE TRIGGER trg_causation_number BEFORE INSERT ON accident_reports FOR EACH ROW EXECUTE FUNCTION generate_causation_number();

-- 5b. inv_ref_no: INV-YYYY-NNNN on ohs_form_19
CREATE SEQUENCE IF NOT EXISTS ohs_form_19_inv_seq START 1;

CREATE OR REPLACE FUNCTION generate_ohs19_inv_ref_no()
RETURNS TRIGGER AS $$
DECLARE
  year_prefix TEXT := to_char(NOW(), 'YYYY');
  seq_num TEXT;
BEGIN
  IF NEW.inv_ref_no IS NULL OR btrim(NEW.inv_ref_no) = '' THEN
    seq_num := LPAD(nextval('ohs_form_19_inv_seq')::TEXT, 4, '0');
    NEW.inv_ref_no := 'INV-' || year_prefix || '-' || seq_num;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ohs19_inv_ref_no ON ohs_form_19;
CREATE TRIGGER trg_ohs19_inv_ref_no BEFORE INSERT ON ohs_form_19 FOR EACH ROW EXECUTE FUNCTION generate_ohs19_inv_ref_no();

