-- =============================================================================
-- Data Architecture Fixes
-- Run this in Supabase SQL Editor AFTER master-setup.sql
-- =============================================================================
BEGIN;

-- PART A: Add missing FK columns
ALTER TABLE bl_form_43_02_wages ADD COLUMN IF NOT EXISTS claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL;
ALTER TABLE bl_form_43_02_wages ADD COLUMN IF NOT EXISTS worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL;
ALTER TABLE bl_form_43_02_wages ADD COLUMN IF NOT EXISTS accident_id UUID REFERENCES accident_reports(id) ON DELETE SET NULL;

ALTER TABLE bl_form_43_04_incapacity ADD COLUMN IF NOT EXISTS claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL;
ALTER TABLE bl_form_43_04_incapacity ADD COLUMN IF NOT EXISTS worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL;
ALTER TABLE bl_form_43_04_incapacity ADD COLUMN IF NOT EXISTS accident_id UUID REFERENCES accident_reports(id) ON DELETE SET NULL;

ALTER TABLE certificate_of_insurance ADD COLUMN IF NOT EXISTS claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL;
ALTER TABLE certificate_of_insurance ADD COLUMN IF NOT EXISTS worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL;
ALTER TABLE certificate_of_insurance ADD COLUMN IF NOT EXISTS accident_id UUID REFERENCES accident_reports(id) ON DELETE SET NULL;

ALTER TABLE medical_attendance_notifications ADD COLUMN IF NOT EXISTS claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL;
ALTER TABLE medical_attendance_notifications ADD COLUMN IF NOT EXISTS worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL;
ALTER TABLE medical_attendance_notifications ADD COLUMN IF NOT EXISTS accident_id UUID REFERENCES accident_reports(id) ON DELETE SET NULL;

ALTER TABLE workplace_inspections ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES companies(id) ON DELETE SET NULL;

ALTER TABLE ohs_form_19 ADD COLUMN IF NOT EXISTS accident_id UUID REFERENCES accident_reports(id) ON DELETE SET NULL;
ALTER TABLE ohs_form_19 ADD COLUMN IF NOT EXISTS submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE permanent_impairment_reports ADD COLUMN IF NOT EXISTS claim_id UUID REFERENCES injury_claims(id) ON DELETE SET NULL;
ALTER TABLE permanent_impairment_reports ADD COLUMN IF NOT EXISTS worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL;

-- PART B: Auto-generate file numbers (ACC-YYYY-NNNN, INSP-YYYY-NNNN)
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
CREATE TRIGGER trg_accident_file_number
  BEFORE INSERT ON accident_reports
  FOR EACH ROW EXECUTE FUNCTION generate_accident_file_number();

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
CREATE TRIGGER trg_inspection_file_number
  BEFORE INSERT ON workplace_inspections
  FOR EACH ROW EXECUTE FUNCTION generate_inspection_file_number();

-- PART C: Auto-populate workers_registry from accident submissions
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
CREATE TRIGGER trg_auto_register_worker
  AFTER INSERT ON accident_reports
  FOR EACH ROW EXECUTE FUNCTION auto_register_worker();

COMMIT;
