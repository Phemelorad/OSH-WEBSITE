-- ============================================================
--  OSH WEBSITE — COMPILED DATABASE SETUP
--  Single file combining all 20 SQL files in execution order.
--  Generated: July 2026
--
--  RUN ORDER (idempotent — safe to re-run):
--  1. Extensions
--  2. Core tables
--  3. Feature tables
--  4. Constraints & migrations
--  5. Indexes
--  6. Triggers & functions
--  7. RLS policies
--  8. Views
--  9. Backfill data
--  10. Security fixes
-- ============================================================

BEGIN;

-- ============================================================
--  SECTION 1 — EXTENSIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
--  SECTION 2 — SHARED TRIGGER FUNCTION (needed early)
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ============================================================
--  SECTION 3 — CORE TABLES
-- ============================================================

-- 3a. Departments
CREATE TABLE IF NOT EXISTS public.departments (
    id          SERIAL PRIMARY KEY,
    code        TEXT UNIQUE NOT NULL,
    name        TEXT NOT NULL,
    description TEXT,
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.departments
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS is_active   BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS created_at  TIMESTAMPTZ DEFAULT NOW();
INSERT INTO public.departments (code, name, description)
VALUES ('osh', 'Dept. of Occupational Health and Safety', 'Workplace health and safety regulations')
ON CONFLICT (code) DO NOTHING;

-- 3b. Companies (defined before user_profiles — needed for FK)
CREATE TABLE IF NOT EXISTS public.companies (
    id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_name     TEXT NOT NULL UNIQUE,
    industry         TEXT,
    location         TEXT,
    physical_address TEXT,
    plot_number      TEXT,
    street_name      TEXT,
    telephone        TEXT,
    owner_name       TEXT,
    owner_email      TEXT,
    cipa_number      TEXT,
    is_active        BOOLEAN DEFAULT true,
    is_deleted       BOOLEAN DEFAULT false,
    deleted_at       TIMESTAMPTZ,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.companies
    ADD COLUMN IF NOT EXISTS industry         TEXT,
    ADD COLUMN IF NOT EXISTS location         TEXT,
    ADD COLUMN IF NOT EXISTS physical_address TEXT,
    ADD COLUMN IF NOT EXISTS plot_number      TEXT,
    ADD COLUMN IF NOT EXISTS street_name      TEXT,
    ADD COLUMN IF NOT EXISTS telephone        TEXT,
    ADD COLUMN IF NOT EXISTS owner_name       TEXT,
    ADD COLUMN IF NOT EXISTS owner_email      TEXT,
    ADD COLUMN IF NOT EXISTS cipa_number      TEXT,
    ADD COLUMN IF NOT EXISTS is_active        BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS is_deleted       BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS deleted_at       TIMESTAMPTZ;

-- 3c. User profiles
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    first_name      TEXT NOT NULL,
    surname         TEXT NOT NULL,
    email           TEXT NOT NULL UNIQUE,
    department      TEXT NOT NULL DEFAULT 'osh',
    location        TEXT NOT NULL,
    is_active       BOOLEAN DEFAULT true,
    role            TEXT DEFAULT 'viewer',
    company_id      UUID REFERENCES public.companies(id) ON DELETE SET NULL,
    designation     TEXT,
    last_sign_in    TIMESTAMPTZ,
    is_deleted      BOOLEAN DEFAULT false,
    deleted_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS company_id   UUID,
    ADD COLUMN IF NOT EXISTS role         TEXT DEFAULT 'viewer',
    ADD COLUMN IF NOT EXISTS designation  TEXT,
    ADD COLUMN IF NOT EXISTS last_sign_in TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS is_deleted   BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS deleted_at   TIMESTAMPTZ;
ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_department_check;
ALTER TABLE public.user_profiles
    ADD CONSTRAINT user_profiles_department_check
    CHECK (department IN ('osh','company','general','medical'));
ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_role_check;
ALTER TABLE public.user_profiles
    ADD CONSTRAINT user_profiles_role_check
    CHECK (role IN ('viewer','officer','admin','super_admin','company','worker','medical_practitioner'));
ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS fk_user_profiles_company;

-- 3d. Login history
CREATE TABLE IF NOT EXISTS public.login_history (
    id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id          UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    login_time       TIMESTAMPTZ DEFAULT NOW(),
    logout_time      TIMESTAMPTZ,
    ip_address       INET,
    user_agent       TEXT,
    login_successful BOOLEAN DEFAULT true,
    session_duration INTERVAL,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 3e. Password reset requests
CREATE TABLE IF NOT EXISTS public.password_reset_requests (
    id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email        TEXT NOT NULL,
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    ip_address   INET,
    status       TEXT DEFAULT 'pending'
        CHECK (status IN ('pending','completed','expired','cancelled'))
);

-- 3f. User activity log
CREATE TABLE IF NOT EXISTS public.user_activity_log (
    id                   UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id              UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type        TEXT NOT NULL,
    activity_description TEXT,
    metadata             JSONB,
    ip_address           INET,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

-- 3g. Role change audit log
CREATE TABLE IF NOT EXISTS public.role_change_log (
    id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    old_role   TEXT,
    new_role   TEXT,
    changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    reason     TEXT
);

-- 3h. User roles info reference
CREATE TABLE IF NOT EXISTS public.user_roles_info (
    role         TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    description  TEXT NOT NULL,
    permissions  JSONB NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO public.user_roles_info (role, display_name, description, permissions) VALUES
    ('viewer','Viewer','View only.',
     '{"view_claims":true,"submit_claims":false,"edit_claims":false,"access_admin":false,"manage_users":false}'::jsonb),
    ('worker','Worker','Submit own reports.',
     '{"view_claims":true,"submit_claims":true,"edit_claims":false,"access_admin":false,"manage_users":false}'::jsonb),
    ('medical_practitioner','Medical Practitioner','Submit medical reports.',
     '{"view_claims":true,"submit_claims":true,"edit_claims":true,"access_admin":false,"manage_users":false}'::jsonb),
    ('officer','Officer','Submit and edit own claims.',
     '{"view_claims":true,"submit_claims":true,"edit_claims":true,"access_admin":false,"manage_users":false}'::jsonb),
    ('admin','Admin','Manage all claims and users (except super admins).',
     '{"view_claims":true,"submit_claims":true,"edit_claims":true,"access_admin":true,"manage_users":true}'::jsonb),
    ('super_admin','Super Admin','Full system access.',
     '{"view_claims":true,"submit_claims":true,"edit_claims":true,"access_admin":true,"manage_users":true,"manage_super_admins":true}'::jsonb)
ON CONFLICT (role) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    permissions  = EXCLUDED.permissions;

-- ============================================================
--  SECTION 4 — WORKERS REGISTRY (before form tables — FK target)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.workers_registry (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    id_number       TEXT NOT NULL UNIQUE,
    id_type         TEXT NOT NULL DEFAULT 'Omang' CHECK (id_type IN ('Omang','Passport')),
    full_name       TEXT NOT NULL,
    date_of_birth   DATE,
    sex             TEXT CHECK (sex IN ('Male','Female')),
    nationality     TEXT,
    address         TEXT,
    email           TEXT,
    occupation      TEXT,
    usual_occupation    TEXT,
    experience_level    TEXT,
    employer_name       TEXT,
    employer_address    TEXT,
    employer_telephone  TEXT,
    employer_fax        TEXT,
    age_years           INTEGER CHECK (age_years IS NULL OR (age_years > 0 AND age_years < 120)),
    is_deleted      BOOLEAN DEFAULT false,
    deleted_at      TIMESTAMPTZ,
    created_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  SECTION 5 — FEATURE TABLES
-- ============================================================

-- 5a. Accident reports (OHS Form 60)
CREATE TABLE IF NOT EXISTS public.accident_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    accident_case_number TEXT,
    report_type TEXT NOT NULL CHECK (report_type IN ('accident','dangerous_occurrence','both')),
    occupier_name TEXT NOT NULL,
    premises_address TEXT NOT NULL,
    nature_of_industry TEXT NOT NULL,
    industry_sector TEXT NOT NULL
        CHECK (industry_sector IN ('Manufacturing','Services','Construction','Agriculture','Transport','Retail','Government','Parastatal')),
    injured_name TEXT,
    injured_age INTEGER CHECK (injured_age > 0 AND injured_age < 120),
    injured_sex TEXT CHECK (injured_sex IN ('Male','Female')),
    injured_id_number TEXT,
    occupation_at_accident TEXT,
    usual_occupation TEXT,
    experience_level TEXT,
    accident_date DATE,
    accident_time TIME,
    accident_place TEXT,
    accident_description TEXT,
    machinery_involved TEXT,
    injury_fatal TEXT CHECK (injury_fatal IN ('Fatal','Non-fatal')),
    disabled_three_days TEXT CHECK (disabled_three_days IN ('Yes','No')),
    hourly_pay NUMERIC(10,2),
    medical_practitioner TEXT,
    dangerous_date DATE,
    dangerous_time TIME,
    dangerous_place TEXT,
    dangerous_description TEXT,
    dangerous_damage TEXT,
    employees_injured TEXT CHECK (employees_injured IN ('Yes','No')),
    notification_submitted TEXT CHECK (notification_submitted IN ('Yes','No')),
    outside_persons_injured TEXT,
    employer_email TEXT,
    additional_injured JSONB,
    report_date DATE NOT NULL DEFAULT CURRENT_DATE,
    reporter_name TEXT NOT NULL,
    reporter_designation TEXT,
    causation_number TEXT,
    date_received DATE,
    investigation_status TEXT DEFAULT 'Pending'
        CHECK (investigation_status IN ('Pending','In Progress','Completed','Closed')),
    official_action TEXT,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('submitted','under_review','investigated','closed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.accident_reports
    ADD COLUMN IF NOT EXISTS accident_case_number TEXT,
    ADD COLUMN IF NOT EXISTS employer_email TEXT,
    ADD COLUMN IF NOT EXISTS additional_injured JSONB,
    ADD COLUMN IF NOT EXISTS injured_id_number TEXT,
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID;

-- 5b. Injury disease reports (BL Form 43/10)
CREATE TABLE IF NOT EXISTS public.injury_disease_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    worker_name TEXT NOT NULL,
    worker_address TEXT NOT NULL,
    occupation TEXT NOT NULL,
    worker_id_number TEXT,
    incident_date DATE NOT NULL,
    place_of_accident TEXT NOT NULL,
    incident_type TEXT NOT NULL CHECK (incident_type IN ('Injury','Disease','Both')),
    nature_of_injuries TEXT NOT NULL,
    resulted_death TEXT CHECK (resulted_death IN ('Yes','No')),
    permanent_incapacity TEXT CHECK (permanent_incapacity IN ('Yes','No')),
    temporary_incapacity TEXT CHECK (temporary_incapacity IN ('Yes','No')),
    nok_informed TEXT CHECK (nok_informed IN ('Yes','No')),
    employer_name TEXT NOT NULL,
    employer_telephone TEXT,
    employer_fax TEXT,
    report_date DATE NOT NULL DEFAULT CURRENT_DATE,
    signatory_name TEXT,
    signatory_designation TEXT,
    accident_id UUID REFERENCES public.accident_reports(id) ON DELETE SET NULL,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('submitted','under_review','processed','closed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.injury_disease_reports
    ADD COLUMN IF NOT EXISTS worker_id_number TEXT,
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID,
    ADD COLUMN IF NOT EXISTS accident_id UUID;

-- 5c. Injury claims
CREATE TABLE IF NOT EXISTS public.injury_claims (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    file_number TEXT UNIQUE,
    name_of_employer TEXT NOT NULL,
    industry TEXT NOT NULL,
    name_of_claimant TEXT NOT NULL,
    gender TEXT CHECK (gender IN ('M','F')),
    location TEXT NOT NULL,
    nationality TEXT NOT NULL,
    claimant_id_number TEXT,
    date_of_injury DATE NOT NULL,
    date_reported DATE NOT NULL,
    date_received DATE NOT NULL,
    cause TEXT NOT NULL,
    nature TEXT NOT NULL,
    incapacity_percentage NUMERIC(5,2) NOT NULL CHECK (incapacity_percentage >= 0 AND incapacity_percentage <= 100),
    source_type TEXT CHECK (source_type IS NULL OR source_type IN ('accident','injury_disease','manual')),
    source_id UUID,
    injury_report_id UUID REFERENCES public.injury_disease_reports(id) ON DELETE SET NULL,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'pending'
        CHECK (status IN ('draft','pending','under_review','approved','rejected','closed','cancelled')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.injury_claims
    ADD COLUMN IF NOT EXISTS gender TEXT,
    ADD COLUMN IF NOT EXISTS claimant_id_number TEXT,
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID,
    ADD COLUMN IF NOT EXISTS source_type TEXT,
    ADD COLUMN IF NOT EXISTS source_id UUID,
    ADD COLUMN IF NOT EXISTS injury_report_id UUID;
ALTER TABLE public.injury_claims ALTER COLUMN file_number DROP NOT NULL;

-- 5d. Workplace inspections
CREATE TABLE IF NOT EXISTS public.workplace_inspections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    file_number TEXT NOT NULL,
    inspection_date DATE NOT NULL,
    date_report_sent DATE,
    days_to_respond INTEGER,
    factory_name TEXT NOT NULL,
    location TEXT NOT NULL,
    nature_of_work TEXT NOT NULL,
    industry_type TEXT NOT NULL
        CHECK (industry_type IN ('Manufacturing','Services','Construction','Agriculture','Transport','Retail','Government','Parastatal')),
    registration_status TEXT NOT NULL CHECK (registration_status IN ('Yes','No','N/A')),
    inspection_type TEXT NOT NULL CHECK (inspection_type IN ('Routine','Follow-up','Query','First Time')),
    employees_male INTEGER NOT NULL DEFAULT 0 CHECK (employees_male >= 0),
    employees_female INTEGER NOT NULL DEFAULT 0 CHECK (employees_female >= 0),
    employees_foreign_male INTEGER NOT NULL DEFAULT 0 CHECK (employees_foreign_male >= 0),
    employees_foreign_female INTEGER NOT NULL DEFAULT 0 CHECK (employees_foreign_female >= 0),
    inspector_name TEXT NOT NULL,
    -- Common contraventions
    s9 BOOLEAN DEFAULT FALSE, s13 BOOLEAN DEFAULT FALSE, s14 BOOLEAN DEFAULT FALSE,
    s15 BOOLEAN DEFAULT FALSE, s16 BOOLEAN DEFAULT FALSE, s18 BOOLEAN DEFAULT FALSE,
    s41 BOOLEAN DEFAULT FALSE, s42 BOOLEAN DEFAULT FALSE, s46 BOOLEAN DEFAULT FALSE,
    s47 BOOLEAN DEFAULT FALSE, s48 BOOLEAN DEFAULT FALSE, s49 BOOLEAN DEFAULT FALSE,
    s52 BOOLEAN DEFAULT FALSE, s53 BOOLEAN DEFAULT FALSE, s62 BOOLEAN DEFAULT FALSE,
    s66 BOOLEAN DEFAULT FALSE, s67 BOOLEAN DEFAULT FALSE,
    -- Other contraventions
    s17 BOOLEAN DEFAULT FALSE, s23 BOOLEAN DEFAULT FALSE, s29 BOOLEAN DEFAULT FALSE,
    s30 BOOLEAN DEFAULT FALSE, s31 BOOLEAN DEFAULT FALSE, s32 BOOLEAN DEFAULT FALSE,
    s34 BOOLEAN DEFAULT FALSE, s37 BOOLEAN DEFAULT FALSE, s38 BOOLEAN DEFAULT FALSE,
    s39 BOOLEAN DEFAULT FALSE, s51 BOOLEAN DEFAULT FALSE, s54 BOOLEAN DEFAULT FALSE,
    s57 BOOLEAN DEFAULT FALSE, s58 BOOLEAN DEFAULT FALSE,
    -- Compliance
    total_contraventions INTEGER NOT NULL DEFAULT 0,
    non_compliance_pct INTEGER NOT NULL DEFAULT 0 CHECK (non_compliance_pct BETWEEN 0 AND 100),
    compliance_level INTEGER NOT NULL DEFAULT 100 CHECK (compliance_level BETWEEN 0 AND 100),
    contraventions TEXT[],
    plant_machinery JSONB,
    action_taken TEXT NOT NULL CHECK (action_taken IN (
        'Advised to Comply','Warned','Compliance Satisfactory',
        'Prohibition Notice Issued','Improvement Notice Issued','Prosecution Recommended')),
    follow_up_required BOOLEAN NOT NULL DEFAULT FALSE,
    follow_up_date DATE,
    summary_findings TEXT,
    non_compliances TEXT,
    recommendations TEXT,
    company_id UUID REFERENCES public.companies(id) ON DELETE SET NULL,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'completed'
        CHECK (status IN ('draft','completed','reviewed','closed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.workplace_inspections
    ADD COLUMN IF NOT EXISTS employees_foreign_male   INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS employees_foreign_female INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS contraventions        TEXT[],
    ADD COLUMN IF NOT EXISTS plant_machinery       JSONB,
    ADD COLUMN IF NOT EXISTS company_id            UUID,
    ADD COLUMN IF NOT EXISTS s17 BOOLEAN DEFAULT FALSE, ADD COLUMN IF NOT EXISTS s23 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s29 BOOLEAN DEFAULT FALSE, ADD COLUMN IF NOT EXISTS s30 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s31 BOOLEAN DEFAULT FALSE, ADD COLUMN IF NOT EXISTS s32 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s34 BOOLEAN DEFAULT FALSE, ADD COLUMN IF NOT EXISTS s37 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s38 BOOLEAN DEFAULT FALSE, ADD COLUMN IF NOT EXISTS s39 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s51 BOOLEAN DEFAULT FALSE, ADD COLUMN IF NOT EXISTS s54 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s57 BOOLEAN DEFAULT FALSE, ADD COLUMN IF NOT EXISTS s58 BOOLEAN DEFAULT FALSE;

-- 5e. Inspection bookings
CREATE TABLE IF NOT EXISTS public.inspection_bookings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_name TEXT NOT NULL,
    company_id UUID REFERENCES public.companies(id) ON DELETE SET NULL,
    contact_name TEXT NOT NULL,
    contact_email TEXT NOT NULL,
    contact_phone TEXT,
    preferred_date DATE,
    preferred_time TEXT,
    inspection_type TEXT NOT NULL DEFAULT 'Routine'
        CHECK (inspection_type IN ('Routine','Follow-up','First Time','Query')),
    location TEXT NOT NULL,
    nature_of_work TEXT,
    industry_type TEXT,
    notes TEXT,
    special_requirements TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','approved','scheduled','completed','cancelled')),
    assigned_inspector TEXT,
    scheduled_date DATE,
    scheduled_time TEXT,
    admin_notes TEXT,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.inspection_bookings
    ADD COLUMN IF NOT EXISTS assigned_inspector TEXT,
    ADD COLUMN IF NOT EXISTS scheduled_date DATE,
    ADD COLUMN IF NOT EXISTS scheduled_time TEXT,
    ADD COLUMN IF NOT EXISTS admin_notes TEXT;

-- 5f. Medical examination reports (BL Form 43/03)
CREATE TABLE IF NOT EXISTS public.medical_examination_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    claim_id UUID REFERENCES public.injury_claims(id) ON DELETE SET NULL,
    accident_id UUID REFERENCES public.accident_reports(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    worker_name TEXT NOT NULL,
    worker_id_number TEXT,
    claim_file_number TEXT,
    nature_of_injury_or_disease TEXT NOT NULL,
    medical_treatment_particulars TEXT NOT NULL,
    death_incapacity BOOLEAN DEFAULT FALSE,
    permanent_total_incapacity BOOLEAN DEFAULT FALSE,
    permanent_partial_incapacity BOOLEAN DEFAULT FALSE,
    temporary_incapacity BOOLEAN DEFAULT FALSE,
    temporary_probable_duration TEXT,
    incapacity_percentage NUMERIC(5,2),
    capable_light_duties TEXT CHECK (capable_light_duties IN ('Yes','No','Not applicable')),
    final_examination_necessary TEXT CHECK (final_examination_necessary IN ('Yes','No','Not applicable')),
    able_to_resume_work TEXT CHECK (able_to_resume_work IN ('Yes','No','Not applicable')),
    report_date DATE NOT NULL DEFAULT CURRENT_DATE,
    practitioner_name TEXT NOT NULL,
    practitioner_designation TEXT NOT NULL,
    worker_representative_name TEXT,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'submitted' CHECK (status IN ('draft','submitted')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.medical_examination_reports
    ADD COLUMN IF NOT EXISTS accident_id UUID;

-- 5g. Permanent impairment reports
CREATE TABLE IF NOT EXISTS public.permanent_impairment_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    claim_id UUID REFERENCES public.injury_claims(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    worker_name TEXT NOT NULL,
    wcc_ref_no TEXT, date_of_birth DATE, hospital_name_ref TEXT,
    sex TEXT CHECK (sex IN ('Male','Female')),
    report_date DATE NOT NULL DEFAULT CURRENT_DATE,
    medical_history JSONB DEFAULT '{}'::jsonb,
    physical_examination TEXT, radiological_exam TEXT, laboratory_test TEXT,
    special_therapeutic_procedures TEXT, specialists_evaluation TEXT,
    pre_existing_conditions TEXT,
    impairment_a TEXT, impairment_b TEXT, impairment_c TEXT, impairment_d TEXT, impairment_e TEXT,
    condition_a_text TEXT,
    condition_b_permanent TEXT CHECK (condition_b_permanent IN ('Yes','No')),
    condition_c_not_stabilized TEXT CHECK (condition_c_not_stabilized IN ('Yes','No')),
    unfit_pre_injury_occupation TEXT CHECK (unfit_pre_injury_occupation IN ('Yes','No')),
    unfit_reasons TEXT,
    fit_alternative_duty TEXT CHECK (fit_alternative_duty IN ('Yes','No')),
    further_harm_possible TEXT CHECK (further_harm_possible IN ('Yes','No')),
    further_harm_explanation TEXT,
    restrictions_needed TEXT CHECK (restrictions_needed IN ('Yes','No')),
    restrictions_explanation TEXT,
    incapacity_body_parts JSONB DEFAULT '[]'::jsonb,
    total_incapacity_pct NUMERIC(5,2),
    under_care_from DATE, under_care_to DATE,
    not_provided_care BOOLEAN DEFAULT FALSE, seen_patient_times INTEGER,
    practitioner_name TEXT NOT NULL, practitioner_signature TEXT, practitioner_date DATE,
    practitioner_address TEXT, practitioner_tel TEXT,
    practitioner_registered_bhpc TEXT CHECK (practitioner_registered_bhpc IN ('Yes','No')),
    practitioner_registered_as TEXT,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('draft','submitted','under_review','approved','rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5h. Practitioner clients
CREATE TABLE IF NOT EXISTS public.practitioner_clients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    practitioner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    worker_name TEXT NOT NULL,
    worker_id_number TEXT,
    last_exam_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5i. Multi-injured persons (per accident)
CREATE TABLE IF NOT EXISTS public.accident_injured_persons (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    accident_report_id UUID NOT NULL REFERENCES public.accident_reports(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    age_years INTEGER,
    sex TEXT CHECK (sex IN ('Male','Female')),
    id_number TEXT,
    occupation_at_accident TEXT,
    usual_occupation TEXT,
    experience_level TEXT,
    email TEXT,
    injury_fatal TEXT CHECK (injury_fatal IN ('Fatal','Non-fatal')),
    disabled_three_days TEXT CHECK (disabled_three_days IN ('Yes','No')),
    hourly_pay NUMERIC(10,2),
    medical_practitioner TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5j. BL Form 43/02 — Wages
CREATE TABLE IF NOT EXISTS public.bl_form_43_02_wages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    worker_name TEXT, worker_address TEXT,
    employer_name TEXT, employer_designation TEXT, employer_signature TEXT, employer_date DATE,
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
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    claim_id UUID REFERENCES public.injury_claims(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    accident_id UUID REFERENCES public.accident_reports(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5k. BL Form 43/04 — Incapacity compensation
CREATE TABLE IF NOT EXISTS public.bl_form_43_04_incapacity (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    worker_name TEXT, worker_address TEXT, employer_name TEXT, accident_date DATE,
    t_earnings_before NUMERIC, t_earnings_during NUMERIC, t_compensation NUMERIC,
    pt_earnings NUMERIC, pt_multiplier NUMERIC, pt_compensation NUMERIC,
    pp_earnings NUMERIC, pp_percentage NUMERIC, pp_multiplier NUMERIC, pp_compensation NUMERIC,
    cc_worker_name TEXT, cc_worker_address TEXT,
    signature TEXT, declaration_date DATE,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    claim_id UUID REFERENCES public.injury_claims(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    accident_id UUID REFERENCES public.accident_reports(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5l. BL Form 43/07 — Certificate of insurance
CREATE TABLE IF NOT EXISTS public.certificate_of_insurance (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    employer_name TEXT NOT NULL, employer_address TEXT,
    insurer_name TEXT, policy_number TEXT,
    coverage_period_start DATE, coverage_period_end DATE,
    signatory_status TEXT, signature TEXT, certificate_date DATE,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    claim_id UUID REFERENCES public.injury_claims(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    accident_id UUID REFERENCES public.accident_reports(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5m. BL Form 43/11 — Medical attendance notification
CREATE TABLE IF NOT EXISTS public.medical_attendance_notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    worker_name TEXT NOT NULL, worker_address TEXT, worker_id_number TEXT,
    practitioner_name TEXT NOT NULL, date_of_notice DATE,
    date_of_examination DATE, time_of_examination TIME, place_of_examination TEXT,
    signatory_name TEXT, notification_date DATE, signature TEXT,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    claim_id UUID REFERENCES public.injury_claims(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    accident_id UUID REFERENCES public.accident_reports(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5n. Notifications
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'assignment',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5o. OHS Form 19 — Accident investigation
CREATE TABLE IF NOT EXISTS public.ohs_form_19 (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    accident_id UUID REFERENCES public.accident_reports(id) ON DELETE SET NULL,
    inv_ref_no TEXT, case_no TEXT, inv_district TEXT, lead_investigator TEXT,
    date_assigned DATE, date_opened DATE, date_closed DATE, inv_status TEXT, inv_team TEXT,
    employer_name TEXT, company_reg_no TEXT, employer_district TEXT, employer_city TEXT,
    employer_plot TEXT, employer_street TEXT, employer_postal TEXT, employer_phone TEXT,
    employer_sector TEXT, nature_of_work TEXT, contact_person TEXT, contact_position TEXT,
    injured_name TEXT, injured_id TEXT, injured_dob DATE, injured_nationality TEXT,
    injured_phone TEXT, age_group TEXT, sex TEXT, marital_status TEXT,
    employment_type TEXT, injured_occupation TEXT, injured_relationship TEXT,
    injured_address TEXT, next_of_kin TEXT, next_of_kin_relationship TEXT,
    incident_location TEXT, incident_date DATE, incident_time TIME,
    incident_reported_date DATE, work_experience TEXT, job_task_performed TEXT,
    equipment_used TEXT, other_injured_count INT, first_aid_given TEXT,
    injury_result_fatal BOOLEAN DEFAULT false, injury_result_non_fatal BOOLEAN DEFAULT false,
    injury_result_occ_disease BOOLEAN DEFAULT false, injury_result_absent BOOLEAN DEFAULT false,
    injury_result_light_duty BOOLEAN DEFAULT false, injury_result_sick_leave BOOLEAN DEFAULT false,
    injury_result_dangerous BOOLEAN DEFAULT false, days_absent TEXT, days_absent_count INT,
    incident_description TEXT, incident_summary TEXT,
    cause_violence BOOLEAN DEFAULT false, cause_assault BOOLEAN DEFAULT false,
    cause_bites BOOLEAN DEFAULT false, cause_slips_trips BOOLEAN DEFAULT false,
    cause_slippery BOOLEAN DEFAULT false, cause_fall_same BOOLEAN DEFAULT false,
    cause_fall_height BOOLEAN DEFAULT false, cause_physical_exertion BOOLEAN DEFAULT false,
    cause_lifting BOOLEAN DEFAULT false, cause_overexertion BOOLEAN DEFAULT false,
    cause_jumping BOOLEAN DEFAULT false, cause_exposure BOOLEAN DEFAULT false,
    cause_asbestos BOOLEAN DEFAULT false, cause_biological BOOLEAN DEFAULT false,
    cause_chemical BOOLEAN DEFAULT false, cause_electric_shock BOOLEAN DEFAULT false,
    cause_road_traffic BOOLEAN DEFAULT false, cause_fire BOOLEAN DEFAULT false,
    cause_stress BOOLEAN DEFAULT false, cause_aggression BOOLEAN DEFAULT false,
    cause_drowning BOOLEAN DEFAULT false, cause_other BOOLEAN DEFAULT false, cause_other_detail TEXT,
    injury_fracture BOOLEAN DEFAULT false, injury_cut BOOLEAN DEFAULT false,
    injury_abrasion BOOLEAN DEFAULT false, injury_bruise BOOLEAN DEFAULT false,
    injury_sprain BOOLEAN DEFAULT false, injury_burn BOOLEAN DEFAULT false,
    injury_elec BOOLEAN DEFAULT false, injury_amputation BOOLEAN DEFAULT false,
    injury_blindness BOOLEAN DEFAULT false, injury_death BOOLEAN DEFAULT false,
    injury_multiple BOOLEAN DEFAULT false, injury_other BOOLEAN DEFAULT false, injury_other_detail TEXT,
    body_head BOOLEAN DEFAULT false, body_eye BOOLEAN DEFAULT false, body_ear BOOLEAN DEFAULT false,
    body_shoulder BOOLEAN DEFAULT false, body_arm BOOLEAN DEFAULT false, body_wrist BOOLEAN DEFAULT false,
    body_hand BOOLEAN DEFAULT false, body_fingers BOOLEAN DEFAULT false, body_back BOOLEAN DEFAULT false,
    body_chest BOOLEAN DEFAULT false, body_pelvis BOOLEAN DEFAULT false, body_knee BOOLEAN DEFAULT false,
    body_ankle BOOLEAN DEFAULT false, body_foot BOOLEAN DEFAULT false, body_toes BOOLEAN DEFAULT false,
    body_respiratory BOOLEAN DEFAULT false, body_no_injury BOOLEAN DEFAULT false, injury_description TEXT,
    immediate_unsafe_acts TEXT, immediate_unsafe_conditions TEXT,
    root_personal_factors TEXT, root_job_factors TEXT,
    factual_5w1h TEXT, factual_preventive_measures TEXT, factual_osh_systems TEXT,
    factual_remedial_actions TEXT, factual_osh_adjustments TEXT,
    analysis_immediate_causes TEXT, analysis_underlying_causes TEXT,
    analysis_root_causes TEXT, analysis_action_proposed TEXT,
    enforcement_verbal BOOLEAN DEFAULT false, enforcement_written BOOLEAN DEFAULT false,
    enforcement_improvement BOOLEAN DEFAULT false, enforcement_prohibition BOOLEAN DEFAULT false,
    enforcement_prosecution BOOLEAN DEFAULT false, enforcement_details TEXT,
    prevent_personal TEXT, prevent_job TEXT,
    action_plan_1 TEXT, action_owner_1 TEXT, action_date_1 DATE,
    action_plan_2 TEXT, action_owner_2 TEXT, action_date_2 DATE,
    action_plan_3 TEXT, action_owner_3 TEXT, action_date_3 DATE,
    action_plan_4 TEXT, action_owner_4 TEXT, action_date_4 DATE,
    action_plan_5 TEXT, action_owner_5 TEXT, action_date_5 DATE,
    witness_date_1 DATE, witness_name_1 TEXT, witness_role_1 TEXT, witness_attach_1 TEXT,
    witness_date_2 DATE, witness_name_2 TEXT, witness_role_2 TEXT, witness_attach_2 TEXT,
    witness_date_3 DATE, witness_name_3 TEXT, witness_role_3 TEXT, witness_attach_3 TEXT,
    exhibit_ref_1 TEXT, exhibit_desc_1 TEXT, exhibit_source_1 TEXT, exhibit_attach_1 TEXT,
    exhibit_ref_2 TEXT, exhibit_desc_2 TEXT, exhibit_source_2 TEXT, exhibit_attach_2 TEXT,
    exhibit_ref_3 TEXT, exhibit_desc_3 TEXT, exhibit_source_3 TEXT, exhibit_attach_3 TEXT,
    checklist_who TEXT, checklist_what TEXT, checklist_when TEXT,
    checklist_where TEXT, checklist_why TEXT, checklist_how TEXT,
    investigator_name TEXT, investigator_designation TEXT,
    investigator_signature TEXT, investigator_date DATE,
    status TEXT DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  SECTION 6 — SEQUENCES & AUTO-NUMBER FUNCTIONS
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS public.accident_case_number_seq START 1 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS public.accident_file_number_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.inspection_file_number_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.causation_number_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.ohs_form_19_inv_seq START 1;

CREATE OR REPLACE FUNCTION public.generate_accident_case_number()
RETURNS TEXT LANGUAGE plpgsql VOLATILE SET search_path = 'public' AS $$
DECLARE v_year TEXT := to_char(CURRENT_DATE,'YY'); v_seq TEXT; v_next BIGINT;
BEGIN
  v_next := nextval('public.accident_case_number_seq');
  v_seq  := LPAD(v_next::TEXT,5,'0');
  RETURN 'OHS/ACC/' || v_year || '/' || v_seq;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_assign_accident_case_number()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
BEGIN
  IF NEW.accident_case_number IS NULL THEN
    NEW.accident_case_number := public.generate_accident_case_number();
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_accident_file_number()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
DECLARE year_prefix TEXT := to_char(NOW(),'YYYY'); seq_num TEXT;
BEGIN
  IF NEW.accident_case_number IS NULL OR btrim(NEW.accident_case_number) = '' THEN
    seq_num := LPAD(nextval('public.accident_file_number_seq')::TEXT,4,'0');
    NEW.accident_case_number := 'ACC-' || year_prefix || '-' || seq_num;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_inspection_file_number()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
DECLARE year_prefix TEXT := to_char(NOW(),'YYYY'); seq_num TEXT;
BEGIN
  IF NEW.file_number IS NULL OR btrim(NEW.file_number) = '' THEN
    seq_num := LPAD(nextval('public.inspection_file_number_seq')::TEXT,4,'0');
    NEW.file_number := 'INSP-' || year_prefix || '-' || seq_num;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_causation_number()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
DECLARE year_prefix TEXT := to_char(NOW(),'YYYY'); seq_num TEXT;
BEGIN
  IF NEW.causation_number IS NULL OR btrim(NEW.causation_number) = '' THEN
    seq_num := LPAD(nextval('public.causation_number_seq')::TEXT,4,'0');
    NEW.causation_number := 'CAU-' || year_prefix || '-' || seq_num;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_ohs19_inv_ref_no()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
DECLARE year_prefix TEXT := to_char(NOW(),'YYYY'); seq_num TEXT;
BEGIN
  IF NEW.inv_ref_no IS NULL OR btrim(NEW.inv_ref_no) = '' THEN
    seq_num := LPAD(nextval('public.ohs_form_19_inv_seq')::TEXT,4,'0');
    NEW.inv_ref_no := 'INV-' || year_prefix || '-' || seq_num;
  END IF;
  RETURN NEW;
END;
$$;

-- ============================================================
--  SECTION 7 — IDENTITY & COMPLIANCE FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION public.normalize_identity_id(val TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE SET search_path = 'public' AS $$
  SELECT UPPER(TRIM(val));
$$;

CREATE OR REPLACE FUNCTION public.compute_compliance_totals()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
DECLARE total INT := 0;
BEGIN
  total := (NEW.s9::int+NEW.s13::int+NEW.s14::int+NEW.s15::int+NEW.s16::int+NEW.s18::int+
            NEW.s41::int+NEW.s42::int+NEW.s46::int+NEW.s47::int+NEW.s48::int+NEW.s49::int+
            NEW.s52::int+NEW.s53::int+NEW.s62::int+NEW.s66::int+NEW.s67::int);
  NEW.total_contraventions := total;
  NEW.non_compliance_pct   := ROUND((total::NUMERIC/17)*100);
  NEW.compliance_level     := 100 - ROUND((total::NUMERIC/17)*100);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.auto_register_worker()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
BEGIN
  IF NEW.injured_id_number IS NOT NULL AND btrim(NEW.injured_id_number) != '' THEN
    INSERT INTO public.workers_registry (id_number, full_name, age_years, sex, occupation, employer_name)
    VALUES (UPPER(TRIM(NEW.injured_id_number)), COALESCE(NEW.injured_name,'Unknown'),
            NEW.injured_age, NEW.injured_sex, NEW.occupation_at_accident, NEW.occupier_name)
    ON CONFLICT (id_number) DO UPDATE SET
      full_name = CASE WHEN workers_registry.full_name='Unknown' THEN EXCLUDED.full_name ELSE workers_registry.full_name END,
      employer_name = COALESCE(workers_registry.employer_name, EXCLUDED.employer_name);
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_role(user_uuid UUID)
RETURNS TEXT LANGUAGE sql SECURITY INVOKER SET search_path = 'public' AS $$
  SELECT role FROM public.user_profiles WHERE user_id = user_uuid;
$$;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT LANGUAGE sql SECURITY INVOKER SET search_path = 'public' AS $$
  SELECT role FROM public.user_profiles WHERE user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.has_permission(permission_name TEXT)
RETURNS BOOLEAN LANGUAGE sql SECURITY INVOKER SET search_path = 'public' AS $$
  SELECT COALESCE((permissions->permission_name)::boolean,false)
  FROM public.user_roles_info
  WHERE role = (SELECT role FROM public.user_profiles WHERE user_id = auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.log_role_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    INSERT INTO public.role_change_log (user_id, old_role, new_role, changed_by)
    VALUES (NEW.user_id, OLD.role, NEW.role, auth.uid());
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_user_account(p_user_id UUID)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_user_exists boolean;
  v_profile_name text;
  v_caller_role text;
BEGIN
  SELECT role INTO v_caller_role FROM public.user_profiles WHERE user_id = auth.uid();
  IF v_caller_role NOT IN ('admin','super_admin') AND p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success',false,'error','Unauthorized: only admins can delete other users');
  END IF;
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id) INTO v_user_exists;
  IF NOT v_user_exists THEN
    RETURN jsonb_build_object('success',false,'message','User not found in auth system');
  END IF;
  SELECT (first_name||' '||surname) INTO v_profile_name FROM public.user_profiles WHERE user_id = p_user_id;
  DELETE FROM public.role_change_log      WHERE user_id = p_user_id OR changed_by = p_user_id;
  DELETE FROM public.login_history        WHERE user_id = p_user_id;
  DELETE FROM public.password_reset_requests WHERE user_id = p_user_id;
  DELETE FROM public.user_activity_log    WHERE user_id = p_user_id;
  UPDATE public.injury_claims             SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.workplace_inspections     SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.accident_reports          SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.injury_disease_reports    SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.inspection_bookings       SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.medical_examination_reports SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.permanent_impairment_reports SET submitted_by = NULL WHERE submitted_by = p_user_id;
  UPDATE public.workers_registry SET created_by = NULL WHERE created_by = p_user_id;
  UPDATE public.workers_registry SET updated_by = NULL WHERE updated_by = p_user_id;
  DELETE FROM public.practitioner_clients WHERE practitioner_id = p_user_id;
  DELETE FROM public.user_profiles        WHERE user_id = p_user_id;
  DELETE FROM auth.users                  WHERE id = p_user_id;
  RETURN jsonb_build_object('success',true,'message','User deleted successfully','profile_name',v_profile_name);
END;
$$;

-- Normalization trigger functions
CREATE OR REPLACE FUNCTION public.trg_normalize_injured_id_number()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
BEGIN NEW.injured_id_number := public.normalize_identity_id(NEW.injured_id_number); RETURN NEW; END;
$$;
CREATE OR REPLACE FUNCTION public.trg_normalize_worker_id_number()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
BEGIN NEW.worker_id_number := public.normalize_identity_id(NEW.worker_id_number); RETURN NEW; END;
$$;
CREATE OR REPLACE FUNCTION public.trg_normalize_claimant_id_number()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
BEGIN NEW.claimant_id_number := public.normalize_identity_id(NEW.claimant_id_number); RETURN NEW; END;
$$;
CREATE OR REPLACE FUNCTION public.trg_normalize_registry_id_number()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = 'public' AS $$
BEGIN NEW.id_number := public.normalize_identity_id(NEW.id_number); RETURN NEW; END;
$$;

-- ============================================================
--  SECTION 8 — TRIGGERS
-- ============================================================

-- updated_at on all tables
DO $$ DECLARE tbl TEXT;
BEGIN FOR tbl IN SELECT unnest(ARRAY[
    'user_profiles','companies','workers_registry','injury_claims',
    'workplace_inspections','accident_reports','injury_disease_reports',
    'inspection_bookings','medical_examination_reports','permanent_impairment_reports',
    'practitioner_clients','accident_injured_persons','bl_form_43_02_wages',
    'bl_form_43_04_incapacity','certificate_of_insurance','medical_attendance_notifications',
    'ohs_form_19'
]) LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON public.%I;
    CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();', tbl, tbl);
END LOOP; END; $$;

-- Auto case numbers
DROP TRIGGER IF EXISTS trg_assign_accident_case ON public.accident_reports;
CREATE TRIGGER trg_assign_accident_case
  BEFORE INSERT ON public.accident_reports FOR EACH ROW
  EXECUTE FUNCTION public.trg_assign_accident_case_number();

DROP TRIGGER IF EXISTS trg_causation_number ON public.accident_reports;
CREATE TRIGGER trg_causation_number
  BEFORE INSERT ON public.accident_reports FOR EACH ROW
  EXECUTE FUNCTION public.generate_causation_number();

DROP TRIGGER IF EXISTS trg_inspection_file_number ON public.workplace_inspections;
CREATE TRIGGER trg_inspection_file_number
  BEFORE INSERT ON public.workplace_inspections FOR EACH ROW
  EXECUTE FUNCTION public.generate_inspection_file_number();

DROP TRIGGER IF EXISTS trg_ohs19_inv_ref_no ON public.ohs_form_19;
CREATE TRIGGER trg_ohs19_inv_ref_no
  BEFORE INSERT ON public.ohs_form_19 FOR EACH ROW
  EXECUTE FUNCTION public.generate_ohs19_inv_ref_no();

-- Auto-register worker from accident report
DROP TRIGGER IF EXISTS trg_auto_register_worker ON public.accident_reports;
CREATE TRIGGER trg_auto_register_worker
  AFTER INSERT ON public.accident_reports FOR EACH ROW
  EXECUTE FUNCTION public.auto_register_worker();

-- Compliance totals
DROP TRIGGER IF EXISTS trg_compute_compliance ON public.workplace_inspections;
CREATE TRIGGER trg_compute_compliance
  BEFORE INSERT OR UPDATE ON public.workplace_inspections FOR EACH ROW
  EXECUTE FUNCTION public.compute_compliance_totals();

-- Role change audit
DROP TRIGGER IF EXISTS role_change_trigger ON public.user_profiles;
CREATE TRIGGER role_change_trigger
  AFTER UPDATE ON public.user_profiles FOR EACH ROW
  EXECUTE FUNCTION public.log_role_change();

-- Normalize IDs
DROP TRIGGER IF EXISTS trg_normalize_injured_id ON public.accident_reports;
CREATE TRIGGER trg_normalize_injured_id
  BEFORE INSERT OR UPDATE ON public.accident_reports FOR EACH ROW
  WHEN (NEW.injured_id_number IS NOT NULL)
  EXECUTE FUNCTION public.trg_normalize_injured_id_number();

DROP TRIGGER IF EXISTS trg_normalize_worker_id ON public.injury_disease_reports;
CREATE TRIGGER trg_normalize_worker_id
  BEFORE INSERT OR UPDATE ON public.injury_disease_reports FOR EACH ROW
  WHEN (NEW.worker_id_number IS NOT NULL)
  EXECUTE FUNCTION public.trg_normalize_worker_id_number();

DROP TRIGGER IF EXISTS trg_normalize_claimant_id ON public.injury_claims;
CREATE TRIGGER trg_normalize_claimant_id
  BEFORE INSERT OR UPDATE ON public.injury_claims FOR EACH ROW
  WHEN (NEW.claimant_id_number IS NOT NULL)
  EXECUTE FUNCTION public.trg_normalize_claimant_id_number();

DROP TRIGGER IF EXISTS trg_normalize_registry_id ON public.workers_registry;
CREATE TRIGGER trg_normalize_registry_id
  BEFORE INSERT OR UPDATE ON public.workers_registry FOR EACH ROW
  EXECUTE FUNCTION public.trg_normalize_registry_id_number();

DROP TRIGGER IF EXISTS trg_accident_injured_persons_updated_at ON public.accident_injured_persons;
CREATE TRIGGER trg_accident_injured_persons_updated_at
  BEFORE UPDATE ON public.accident_injured_persons FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
--  SECTION 9 — INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_ar_occupier_date        ON public.accident_reports(occupier_name, accident_date DESC);
CREATE INDEX IF NOT EXISTS idx_ar_worker_reg            ON public.accident_reports(worker_registry_id);
CREATE INDEX IF NOT EXISTS idx_ar_submitted_by          ON public.accident_reports(submitted_by);
CREATE INDEX IF NOT EXISTS idx_ar_accident_date         ON public.accident_reports(accident_date DESC);
CREATE INDEX IF NOT EXISTS idx_ar_case_number           ON public.accident_reports(accident_case_number) WHERE accident_case_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ar_injured_id            ON public.accident_reports(injured_id_number);

CREATE INDEX IF NOT EXISTS idx_idr_employer_date        ON public.injury_disease_reports(employer_name, incident_date DESC);
CREATE INDEX IF NOT EXISTS idx_idr_worker_reg           ON public.injury_disease_reports(worker_registry_id);
CREATE INDEX IF NOT EXISTS idx_idr_accident_id          ON public.injury_disease_reports(accident_id);

CREATE INDEX IF NOT EXISTS idx_ic_claimant_id_number    ON public.injury_claims(claimant_id_number);
CREATE INDEX IF NOT EXISTS idx_ic_worker_reg            ON public.injury_claims(worker_registry_id);
CREATE INDEX IF NOT EXISTS idx_ic_injury_report_id      ON public.injury_claims(injury_report_id);
CREATE INDEX IF NOT EXISTS idx_ic_status                ON public.injury_claims(status);
CREATE INDEX IF NOT EXISTS idx_ic_submitted_by          ON public.injury_claims(submitted_by);

CREATE INDEX IF NOT EXISTS idx_wi_factory_date          ON public.workplace_inspections(factory_name, inspection_date DESC);
CREATE INDEX IF NOT EXISTS idx_wi_submitted_by          ON public.workplace_inspections(submitted_by);
CREATE UNIQUE INDEX IF NOT EXISTS idx_wr_id_number      ON public.workers_registry(id_number);
CREATE INDEX IF NOT EXISTS idx_wr_full_name             ON public.workers_registry(full_name);
CREATE INDEX IF NOT EXISTS idx_pc_worker_id_number      ON public.practitioner_clients(worker_id_number);
CREATE INDEX IF NOT EXISTS idx_ib_company_name_lookup   ON public.inspection_bookings(company_name);
CREATE INDEX IF NOT EXISTS idx_aip_report               ON public.accident_injured_persons(accident_report_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id    ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread     ON public.notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_mer_accident_id          ON public.medical_examination_reports(accident_id);
CREATE INDEX IF NOT EXISTS idx_mer_claim_id             ON public.medical_examination_reports(claim_id);

-- ============================================================
--  SECTION 10 — ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.user_profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.companies                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workers_registry           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accident_reports           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.injury_claims              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.injury_disease_reports     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workplace_inspections      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_bookings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_examination_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permanent_impairment_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practitioner_clients       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accident_injured_persons   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_change_log            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles_info            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ohs_form_19                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bl_form_43_04_incapacity   ENABLE ROW LEVEL SECURITY;

-- user_profiles
DROP POLICY IF EXISTS "All users can view profiles"          ON public.user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile"         ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update based on role"       ON public.user_profiles;
CREATE POLICY "All users can view profiles" ON public.user_profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can insert own profile" ON public.user_profiles FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update based on role" ON public.user_profiles FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin')))
  WITH CHECK (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin')));

-- companies
DROP POLICY IF EXISTS "All users can view companies" ON public.companies;
DROP POLICY IF EXISTS "Anyone can insert companies"  ON public.companies;
CREATE POLICY "All users can view companies" ON public.companies FOR SELECT TO authenticated USING (true);
CREATE POLICY "Anyone can insert companies"  ON public.companies FOR INSERT TO authenticated WITH CHECK (true);

-- workers_registry
DROP POLICY IF EXISTS "All authenticated users can view workers registry" ON public.workers_registry;
DROP POLICY IF EXISTS "Officers and above can insert workers"              ON public.workers_registry;
DROP POLICY IF EXISTS "Officers update own workers, admins update all"     ON public.workers_registry;
CREATE POLICY "All authenticated users can view workers registry" ON public.workers_registry
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "Officers and above can insert workers" ON public.workers_registry FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin')));
CREATE POLICY "Officers update own workers, admins update all" ON public.workers_registry FOR UPDATE TO authenticated
  USING (created_by = auth.uid() OR EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin')));

-- accident_reports
DROP POLICY IF EXISTS "All users can view accident reports"   ON public.accident_reports;
DROP POLICY IF EXISTS "Officers and above can insert accident reports" ON public.accident_reports;
DROP POLICY IF EXISTS "Officers update own, admins update all" ON public.accident_reports;
CREATE POLICY "All users can view accident reports" ON public.accident_reports FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer')) OR submitted_by = auth.uid());
CREATE POLICY "Officers and above can insert accident reports" ON public.accident_reports FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin')) AND auth.uid() = submitted_by);
CREATE POLICY "Officers update own, admins update all accident" ON public.accident_reports FOR UPDATE TO authenticated
  USING (auth.uid() = submitted_by OR EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin')));

-- injury_disease_reports
DROP POLICY IF EXISTS "All users can view injury disease reports" ON public.injury_disease_reports;
DROP POLICY IF EXISTS "authenticated_users_can_insert"            ON public.injury_disease_reports;
DROP POLICY IF EXISTS "authenticated_users_can_update"            ON public.injury_disease_reports;
CREATE POLICY "All users can view injury disease reports" ON public.injury_disease_reports
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer')) OR submitted_by = auth.uid());
CREATE POLICY "authenticated_users_can_insert" ON public.injury_disease_reports FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin','medical_practitioner')));
CREATE POLICY "authenticated_users_can_update" ON public.injury_disease_reports FOR UPDATE TO authenticated
  USING (submitted_by = auth.uid() OR EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin')));

-- injury_claims
DROP POLICY IF EXISTS "All users can view claims"             ON public.injury_claims;
DROP POLICY IF EXISTS "Officers and above can insert claims"  ON public.injury_claims;
DROP POLICY IF EXISTS "Officers and above can update claims"  ON public.injury_claims;
CREATE POLICY "All users can view claims" ON public.injury_claims FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer')) OR submitted_by = auth.uid());
CREATE POLICY "Officers and above can insert claims" ON public.injury_claims FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin')) AND auth.uid() = submitted_by);
CREATE POLICY "Officers and above can update claims" ON public.injury_claims FOR UPDATE TO authenticated
  USING (auth.uid() = submitted_by OR EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin')));

-- workplace_inspections
DROP POLICY IF EXISTS "All users can view inspections"        ON public.workplace_inspections;
DROP POLICY IF EXISTS "Officers and above can insert inspections" ON public.workplace_inspections;
DROP POLICY IF EXISTS "Officers can update own, admins update all" ON public.workplace_inspections;
CREATE POLICY "All users can view inspections" ON public.workplace_inspections FOR SELECT TO authenticated USING (true);
CREATE POLICY "Officers and above can insert inspections" ON public.workplace_inspections FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin')) AND auth.uid() = submitted_by);
CREATE POLICY "Officers can update own, admins update all inspections" ON public.workplace_inspections FOR UPDATE TO authenticated
  USING (auth.uid() = submitted_by OR EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin')));

-- medical_examination_reports
DROP POLICY IF EXISTS "Medical practitioners can insert" ON public.medical_examination_reports;
CREATE POLICY "Medical practitioners can insert" ON public.medical_examination_reports FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('medical_practitioner','admin','super_admin','officer')));
CREATE POLICY "Users can view medical reports" ON public.medical_examination_reports FOR SELECT TO authenticated
  USING (submitted_by = auth.uid() OR EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer')));

-- permanent_impairment_reports
DROP POLICY IF EXISTS "practitioners_can_insert" ON public.permanent_impairment_reports;
DROP POLICY IF EXISTS "practitioners_can_view"   ON public.permanent_impairment_reports;
DROP POLICY IF EXISTS "admins_can_update"         ON public.permanent_impairment_reports;
CREATE POLICY "practitioners_can_insert" ON public.permanent_impairment_reports FOR INSERT TO authenticated WITH CHECK (auth.uid() = submitted_by);
CREATE POLICY "practitioners_can_view" ON public.permanent_impairment_reports FOR SELECT TO authenticated
  USING (auth.uid() = submitted_by OR EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer')));
CREATE POLICY "admins_can_update" ON public.permanent_impairment_reports FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin')));

-- accident_injured_persons
CREATE POLICY "Users can select injured persons on their reports" ON public.accident_injured_persons FOR SELECT
  USING (accident_report_id IN (SELECT id FROM public.accident_reports WHERE submitted_by = auth.uid()));
CREATE POLICY "Users can insert injured persons on their reports" ON public.accident_injured_persons FOR INSERT
  WITH CHECK (accident_report_id IN (SELECT id FROM public.accident_reports WHERE submitted_by = auth.uid()));
CREATE POLICY "Users can update injured persons on their reports" ON public.accident_injured_persons FOR UPDATE
  USING (accident_report_id IN (SELECT id FROM public.accident_reports WHERE submitted_by = auth.uid()));

-- role_change_log
CREATE POLICY "Admins can view role changes" ON public.role_change_log FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin')));

-- user_roles_info
CREATE POLICY "All users can view role info" ON public.user_roles_info FOR SELECT TO authenticated USING (true);

-- notifications
CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Officers can insert notifications" ON public.notifications FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin')));

-- ohs_form_19
DROP POLICY IF EXISTS "Users can view form 19" ON public.ohs_form_19;
DROP POLICY IF EXISTS "Users can insert form 19" ON public.ohs_form_19;
CREATE POLICY "Users can view form 19" ON public.ohs_form_19 FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer')) OR submitted_by = auth.uid());
CREATE POLICY "Users can insert form 19" ON public.ohs_form_19 FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer')));
CREATE POLICY "Users can update form 19" ON public.ohs_form_19 FOR UPDATE TO authenticated
  USING (auth.uid() = submitted_by);

-- bl_form_43_04_incapacity
CREATE POLICY "Admins can view all bl43_04" ON public.bl_form_43_04_incapacity FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin')));
CREATE POLICY "Authenticated users can insert bl43_04" ON public.bl_form_43_04_incapacity FOR INSERT
  WITH CHECK (auth.uid() = submitted_by);
CREATE POLICY "Users can view own bl43_04 submissions" ON public.bl_form_43_04_incapacity FOR SELECT
  USING (submitted_by = auth.uid());

-- ============================================================
--  SECTION 11 — GRANTS
-- ============================================================

GRANT SELECT, INSERT, UPDATE ON public.user_profiles             TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.companies                  TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.workers_registry           TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.accident_reports           TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.injury_claims              TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.injury_disease_reports     TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.workplace_inspections      TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.inspection_bookings        TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.medical_examination_reports TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.permanent_impairment_reports TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.practitioner_clients       TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.accident_injured_persons   TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.ohs_form_19                TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notifications              TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.bl_form_43_02_wages        TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.bl_form_43_04_incapacity   TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.certificate_of_insurance   TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.medical_attendance_notifications TO authenticated;
GRANT SELECT ON public.user_roles_info TO authenticated;
GRANT SELECT ON public.role_change_log TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_account(UUID) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.delete_user_account(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_role(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.has_permission(TEXT) TO authenticated;

-- ============================================================
--  SECTION 12 — VIEWS
-- ============================================================

-- Incident chain view
CREATE OR REPLACE VIEW public.incident_chain_view AS
SELECT
  ar.id AS accident_id, ar.accident_case_number, ar.report_type,
  ar.occupier_name AS employer_name, ar.industry_sector,
  ar.accident_date, ar.accident_place, ar.accident_description,
  ar.investigation_status AS accident_investigation_status,
  ar.reporter_name, ar.injury_fatal,
  idr.id AS injury_report_id, idr.worker_name, idr.incident_type,
  idr.nature_of_injuries, idr.resulted_death, idr.permanent_incapacity,
  idr.temporary_incapacity, idr.occupation, idr.worker_registry_id AS injured_worker_registry_id,
  ic.id AS claim_id, ic.file_number, ic.status AS claim_status,
  ic.incapacity_percentage AS claim_incapacity, ic.date_of_injury AS claim_date,
  mer.id AS medical_exam_id, mer.status AS medical_status,
  mer.incapacity_percentage AS medical_incapacity, mer.report_date AS medical_report_date
FROM public.accident_reports ar
LEFT JOIN public.injury_disease_reports idr ON idr.accident_id = ar.id
LEFT JOIN public.injury_claims ic ON ic.injury_report_id = idr.id
LEFT JOIN public.medical_examination_reports mer ON mer.claim_id = ic.id
ORDER BY ar.accident_date DESC, idr.incident_date DESC;

-- Company register view
CREATE OR REPLACE VIEW public.company_register_view AS
SELECT
  c.*,
  COUNT(DISTINCT wi.id)  AS inspection_count,
  AVG(wi.compliance_level) AS avg_compliance_level,
  COUNT(DISTINCT ar.id)  AS accident_count,
  COUNT(DISTINCT idr.id) AS injury_count,
  COUNT(DISTINCT ic.id)  AS claim_count
FROM public.companies c
LEFT JOIN public.workplace_inspections wi  ON wi.factory_name    = c.company_name
LEFT JOIN public.accident_reports ar       ON ar.occupier_name   = c.company_name
LEFT JOIN public.injury_disease_reports idr ON idr.employer_name = c.company_name
LEFT JOIN public.injury_claims ic          ON ic.name_of_employer= c.company_name
GROUP BY c.id;

-- User roles view
CREATE OR REPLACE VIEW public.user_roles_view AS
SELECT role, COUNT(*) AS user_count
FROM public.user_profiles WHERE is_deleted IS DISTINCT FROM true
GROUP BY role;

-- Inspections by month
CREATE OR REPLACE VIEW public.inspections_by_month AS
SELECT DATE_TRUNC('month', inspection_date) AS month,
  COUNT(*) AS inspection_count, AVG(compliance_level) AS avg_compliance
FROM public.workplace_inspections
GROUP BY DATE_TRUNC('month', inspection_date) ORDER BY month DESC;

-- Accident report view (with company match)
CREATE OR REPLACE VIEW public.accident_report_view AS
SELECT ar.id, ar.accident_case_number, ar.report_type,
  COALESCE(c.company_name, ar.occupier_name) AS occupier_name,
  ar.premises_address, ar.nature_of_industry, ar.industry_sector,
  ar.injured_name, ar.injured_age, ar.injured_sex, ar.accident_date, ar.accident_place,
  ar.injury_fatal, ar.investigation_status, ar.causation_number,
  ar.reporter_name, ar.report_date, ar.status, ar.created_at,
  up.first_name||' '||up.surname AS submitted_by_name
FROM public.accident_reports ar
LEFT JOIN public.user_profiles up ON ar.submitted_by = up.user_id
LEFT JOIN public.companies c ON LOWER(c.company_name) = LOWER(ar.occupier_name)
ORDER BY ar.accident_date DESC NULLS LAST;

-- Injury disease report view
CREATE OR REPLACE VIEW public.injury_disease_report_view AS
SELECT idr.id, idr.worker_name, idr.occupation, idr.incident_date,
  idr.incident_type, idr.place_of_accident, idr.resulted_death,
  idr.permanent_incapacity, idr.temporary_incapacity,
  COALESCE(c.company_name, idr.employer_name) AS employer_name,
  idr.report_date, idr.status, idr.created_at,
  up.first_name||' '||up.surname AS submitted_by_name
FROM public.injury_disease_reports idr
LEFT JOIN public.user_profiles up ON idr.submitted_by = up.user_id
LEFT JOIN public.companies c ON LOWER(c.company_name) = LOWER(idr.employer_name)
ORDER BY idr.incident_date DESC NULLS LAST;

-- Injury claims view
CREATE OR REPLACE VIEW public.injury_claims_view AS
SELECT ic.*, COALESCE(c.company_name, ic.name_of_employer) AS matched_employer
FROM public.injury_claims ic
LEFT JOIN public.companies c ON LOWER(c.company_name) = LOWER(ic.name_of_employer);

-- Inspection report view
CREATE OR REPLACE VIEW public.inspection_report_view AS
SELECT wi.id, wi.file_number, wi.inspection_date, wi.date_report_sent,
  wi.days_to_respond, wi.factory_name, wi.location, wi.nature_of_work,
  wi.industry_type, wi.registration_status, wi.inspection_type,
  wi.employees_male, wi.employees_female,
  (wi.employees_male+wi.employees_female) AS total_employees,
  wi.inspector_name, wi.total_contraventions, wi.non_compliance_pct,
  wi.compliance_level, wi.contraventions, wi.action_taken,
  wi.follow_up_required, wi.follow_up_date, wi.status, wi.created_at,
  up.first_name||' '||up.surname AS submitted_by_name
FROM public.workplace_inspections wi
LEFT JOIN public.user_profiles up ON wi.submitted_by = up.user_id
ORDER BY wi.inspection_date DESC;

-- Inspections pending follow-up
CREATE OR REPLACE VIEW public.inspections_pending_followup AS
SELECT id, file_number, factory_name, location, inspection_date,
  follow_up_date, inspector_name, compliance_level, action_taken
FROM public.workplace_inspections
WHERE follow_up_required = TRUE AND status != 'closed'
ORDER BY follow_up_date ASC NULLS LAST;

-- Injury claims summary views
CREATE OR REPLACE VIEW public.injury_claims_summary AS
SELECT status, COUNT(*) AS total_claims, AVG(incapacity_percentage) AS avg_incapacity,
  MIN(date_of_injury) AS earliest_injury, MAX(date_of_injury) AS latest_injury
FROM public.injury_claims GROUP BY status;

CREATE OR REPLACE VIEW public.injury_claims_by_industry AS
SELECT industry, COUNT(*) AS total_claims, AVG(incapacity_percentage) AS avg_incapacity,
  COUNT(CASE WHEN status='approved' THEN 1 END) AS approved_claims,
  COUNT(CASE WHEN status='rejected' THEN 1 END) AS rejected_claims,
  COUNT(CASE WHEN status='pending'  THEN 1 END) AS pending_claims
FROM public.injury_claims GROUP BY industry ORDER BY total_claims DESC;

CREATE OR REPLACE VIEW public.accident_statistics AS
SELECT
  COUNT(*) AS total_reports,
  COUNT(*) FILTER (WHERE report_type='accident') AS accidents,
  COUNT(*) FILTER (WHERE report_type='dangerous_occurrence') AS dangerous_occurrences,
  COUNT(*) FILTER (WHERE injury_fatal='Fatal') AS fatalities,
  COUNT(*) FILTER (WHERE investigation_status='Pending') AS pending_investigations,
  COUNT(*) FILTER (WHERE accident_date >= DATE_TRUNC('month',NOW())) AS this_month
FROM public.accident_reports;

CREATE OR REPLACE VIEW public.injury_disease_statistics AS
SELECT
  COUNT(*) AS total_reports,
  COUNT(*) FILTER (WHERE incident_type='Injury') AS injuries,
  COUNT(*) FILTER (WHERE incident_type='Disease') AS diseases,
  COUNT(*) FILTER (WHERE resulted_death='Yes') AS fatalities,
  COUNT(*) FILTER (WHERE incident_date >= DATE_TRUNC('month',NOW())) AS this_month
FROM public.injury_disease_reports;

GRANT SELECT ON public.incident_chain_view          TO authenticated, anon;
GRANT SELECT ON public.company_register_view        TO authenticated;
GRANT SELECT ON public.user_roles_view              TO authenticated;
GRANT SELECT ON public.inspections_by_month         TO authenticated;
GRANT SELECT ON public.accident_report_view         TO authenticated;
GRANT SELECT ON public.injury_disease_report_view   TO authenticated;
GRANT SELECT ON public.injury_claims_view           TO authenticated;
GRANT SELECT ON public.inspection_report_view       TO authenticated;
GRANT SELECT ON public.inspections_pending_followup TO authenticated;
GRANT SELECT ON public.injury_claims_summary        TO authenticated;
GRANT SELECT ON public.injury_claims_by_industry    TO authenticated;
GRANT SELECT ON public.accident_statistics          TO authenticated;
GRANT SELECT ON public.injury_disease_statistics    TO authenticated;

-- ============================================================
--  SECTION 13 — SET SECURITY_INVOKER ON VIEWS
-- ============================================================

ALTER VIEW public.accident_statistics          SET (security_invoker = true);
ALTER VIEW public.injury_claims_summary        SET (security_invoker = true);
ALTER VIEW public.injury_claims_by_industry    SET (security_invoker = true);
ALTER VIEW public.injury_disease_statistics    SET (security_invoker = true);
ALTER VIEW public.inspection_report_view       SET (security_invoker = true);
ALTER VIEW public.inspections_by_month         SET (security_invoker = true);
ALTER VIEW public.accident_report_view         SET (security_invoker = true);
ALTER VIEW public.injury_disease_report_view   SET (security_invoker = true);
ALTER VIEW public.injury_claims_view           SET (security_invoker = true);
ALTER VIEW public.company_register_view        SET (security_invoker = true);
ALTER VIEW public.user_roles_view              SET (security_invoker = true);
ALTER VIEW public.inspections_pending_followup SET (security_invoker = true);
ALTER VIEW public.incident_chain_view          SET (security_invoker = true);

-- ============================================================
--  SECTION 14 — BACKFILL (one-time data fixes)
-- ============================================================

-- Normalize existing ID numbers
UPDATE public.accident_reports
  SET injured_id_number = public.normalize_identity_id(injured_id_number)
  WHERE injured_id_number IS NOT NULL
    AND injured_id_number IS DISTINCT FROM public.normalize_identity_id(injured_id_number);

UPDATE public.injury_disease_reports
  SET worker_id_number = public.normalize_identity_id(worker_id_number)
  WHERE worker_id_number IS NOT NULL
    AND worker_id_number IS DISTINCT FROM public.normalize_identity_id(worker_id_number);

UPDATE public.injury_claims
  SET claimant_id_number = public.normalize_identity_id(claimant_id_number)
  WHERE claimant_id_number IS NOT NULL
    AND claimant_id_number IS DISTINCT FROM public.normalize_identity_id(claimant_id_number);

UPDATE public.workers_registry
  SET id_number = public.normalize_identity_id(id_number)
  WHERE id_number IS DISTINCT FROM public.normalize_identity_id(id_number);

-- Backfill compliance totals from contraventions array
UPDATE public.workplace_inspections
SET s9=('S9'=ANY(contraventions)),s13=('S13'=ANY(contraventions)),s14=('S14'=ANY(contraventions)),
    s15=('S15'=ANY(contraventions)),s16=('S16'=ANY(contraventions)),s18=('S18'=ANY(contraventions)),
    s41=('S41'=ANY(contraventions)),s42=('S42'=ANY(contraventions)),s46=('S46'=ANY(contraventions)),
    s47=('S47'=ANY(contraventions)),s48=('S48'=ANY(contraventions)),s49=('S49'=ANY(contraventions)),
    s52=('S52'=ANY(contraventions)),s53=('S53'=ANY(contraventions)),s62=('S62'=ANY(contraventions)),
    s66=('S66'=ANY(contraventions)),s67=('S67'=ANY(contraventions)),
    s17=('S17'=ANY(contraventions)),s23=('S23'=ANY(contraventions)),s29=('S29'=ANY(contraventions)),
    s30=('S30'=ANY(contraventions)),s31=('S31'=ANY(contraventions)),s32=('S32'=ANY(contraventions)),
    s34=('S34'=ANY(contraventions)),s37=('S37'=ANY(contraventions)),s38=('S38'=ANY(contraventions)),
    s39=('S39'=ANY(contraventions)),s51=('S51'=ANY(contraventions)),s54=('S54'=ANY(contraventions)),
    s57=('S57'=ANY(contraventions)),s58=('S58'=ANY(contraventions))
WHERE contraventions IS NOT NULL AND array_length(contraventions,1) > 0;

-- Recompute totals
UPDATE public.workplace_inspections SET
    total_contraventions=(s9::int+s13::int+s14::int+s15::int+s16::int+s18::int+s41::int+s42::int+s46::int+s47::int+s48::int+s49::int+s52::int+s53::int+s62::int+s66::int+s67::int),
    non_compliance_pct=ROUND((s9::int+s13::int+s14::int+s15::int+s16::int+s18::int+s41::int+s42::int+s46::int+s47::int+s48::int+s49::int+s52::int+s53::int+s62::int+s66::int+s67::int)::NUMERIC/17*100),
    compliance_level=100-ROUND((s9::int+s13::int+s14::int+s15::int+s16::int+s18::int+s41::int+s42::int+s46::int+s47::int+s48::int+s49::int+s52::int+s53::int+s62::int+s66::int+s67::int)::NUMERIC/17*100);

COMMIT;

-- ============================================================
--  SETUP COMPLETE ✅
-- ============================================================
SELECT '✅ OSH Database compiled setup completed successfully!' AS status;
