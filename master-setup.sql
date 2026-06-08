-- ============================================================
--  OSH WEBSITE — COMPLETE DATABASE MASTER SETUP
--  ============================================================
--  Run this entire script in: Supabase Dashboard → SQL Editor
--  It is idempotent (safe to run multiple times).
--  All 35 individual .sql files have been consolidated here.
-- ============================================================

-- ============================================================
--  SECTION 1 — EXTENSIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
--  SECTION 2 — CORE TABLES
-- ============================================================

-- ── 2a. Departments reference ───────────────────────────────
CREATE TABLE IF NOT EXISTS departments (
    id          SERIAL PRIMARY KEY,
    code        TEXT UNIQUE NOT NULL,
    name        TEXT NOT NULL,
    description TEXT,
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO departments (code, name, description) VALUES
    ('osh',     'Dept. of Occupational Health and Safety', 'Workplace health and safety regulations')
ON CONFLICT (code) DO NOTHING;

COMMENT ON TABLE departments IS 'Reference table for departments/divisions';

-- ── 2b. User profiles ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_profiles (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    first_name      TEXT NOT NULL,
    surname         TEXT NOT NULL,
    email           TEXT NOT NULL UNIQUE,
    department      TEXT NOT NULL DEFAULT 'osh',
    location        TEXT NOT NULL,
    is_active       BOOLEAN DEFAULT true,
    role            TEXT DEFAULT 'viewer',
    company_id      UUID,
    designation     TEXT,
    last_sign_in    TIMESTAMPTZ,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE user_profiles IS 'Stores extended user profile information for OSH system users';
COMMENT ON COLUMN user_profiles.role IS 'User role: viewer, worker, medical_practitioner, officer, admin, super_admin, or company';
COMMENT ON COLUMN user_profiles.company_id IS 'FK to companies table — set when user is a company representative';
COMMENT ON COLUMN user_profiles.designation IS 'Job title or designation (e.g. Deputy Director, Safety Officer)';
COMMENT ON COLUMN user_profiles.last_sign_in IS 'Timestamp of the most recent successful sign-in';

-- ── 2c. Login history ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS login_history (
    id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id          UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    login_time       TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    logout_time      TIMESTAMP WITH TIME ZONE,
    ip_address       INET,
    user_agent       TEXT,
    login_successful BOOLEAN DEFAULT true,
    session_duration INTERVAL,
    created_at       TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE login_history IS 'Tracks user login/logout activity and sessions';

-- ── 2d. Password reset requests ──────────────────────────────
CREATE TABLE IF NOT EXISTS password_reset_requests (
    id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email        TEXT NOT NULL,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    ip_address   INET,
    status       TEXT DEFAULT 'pending'
        CHECK (status IN ('pending', 'completed', 'expired', 'cancelled'))
);

COMMENT ON TABLE password_reset_requests IS 'Tracks password reset requests for audit purposes';

-- ── 2e. User activity log ────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_activity_log (
    id                   UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id              UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type        TEXT NOT NULL,
    activity_description TEXT,
    metadata             JSONB,
    ip_address           INET,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE user_activity_log IS 'General purpose activity logging for users';

-- ── 2f. Role change audit log ────────────────────────────────
CREATE TABLE IF NOT EXISTS role_change_log (
    id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id    UUID REFERENCES auth.users(id),
    old_role   TEXT,
    new_role   TEXT,
    changed_by UUID REFERENCES auth.users(id),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reason     TEXT
);

COMMENT ON TABLE role_change_log IS 'Audit log tracking all user role changes';

-- ── 2g. Roles info reference ─────────────────────────────────
CREATE TABLE IF NOT EXISTS user_roles_info (
    role         TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    description  TEXT NOT NULL,
    permissions  JSONB NOT NULL,
    created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO user_roles_info (role, display_name, description, permissions) VALUES
    ('viewer',              'Viewer',            'Can only view claims and entries. No edit or submit permissions.',
     '{"view_claims": true, "submit_claims": false, "edit_claims": false, "access_admin": false, "manage_users": false}'::jsonb),
    ('worker',              'Worker',            'Can submit injury/accident reports. Access to own records.',
     '{"view_claims": true, "submit_claims": true, "edit_claims": false, "access_admin": false, "manage_users": false}'::jsonb),
    ('medical_practitioner','Medical Practitioner','Can submit medical examination reports. No admin access.',
     '{"view_claims": true, "submit_claims": true, "edit_claims": true, "access_admin": false, "manage_users": false}'::jsonb),
    ('officer',             'Officer',           'Can view, submit, and edit their own claims. No admin panel access.',
     '{"view_claims": true, "submit_claims": true, "edit_claims": true, "access_admin": false, "manage_users": false}'::jsonb),
    ('admin',               'Admin',             'Can manage all claims and access admin panel. Can edit all users except super admins.',
     '{"view_claims": true, "submit_claims": true, "edit_claims": true, "access_admin": true, "manage_users": true}'::jsonb),
    ('super_admin',         'Super Admin',       'Full system access. Can manage all users including other super admins.',
     '{"view_claims": true, "submit_claims": true, "edit_claims": true, "access_admin": true, "manage_users": true, "manage_super_admins": true}'::jsonb)
ON CONFLICT (role) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    permissions  = EXCLUDED.permissions;

COMMENT ON TABLE user_roles_info IS 'Reference table mapping roles to permissions';

-- ============================================================
--  SECTION 3 — FEATURE TABLES
-- ============================================================

-- ── 3a. Companies ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS companies (
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
    created_at       TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at       TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE companies IS 'Registered companies that can log in to view their own data';
COMMENT ON COLUMN companies.company_name IS 'Company name used to match against accident_reports.occupier_name, workplace_inspections.factory_name, etc.';
COMMENT ON COLUMN companies.cipa_number IS 'CIPA (Companies and Intellectual Property Authority) registration number';
COMMENT ON COLUMN companies.physical_address IS 'Full physical / postal address of the company';
COMMENT ON COLUMN companies.plot_number IS 'Plot number (e.g. Plot 12345, Gaborone)';
COMMENT ON COLUMN companies.street_name IS 'Street name where the company is located';

-- ── 3b. Accident reports (Form 60) ──────────────────────────
CREATE TABLE IF NOT EXISTS accident_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Report Classification
    report_type         TEXT NOT NULL
        CHECK (report_type IN ('accident','dangerous_occurrence','both')),

    -- Occupier & Premises
    occupier_name        TEXT NOT NULL,
    premises_address     TEXT NOT NULL,
    nature_of_industry   TEXT NOT NULL,
    industry_sector      TEXT NOT NULL
        CHECK (industry_sector IN ('Manufacturing','Services','Construction','Agriculture','Transport','Retail','Government','Parastatal')),

    -- Injured / Deceased Person
    injured_name         TEXT,
    injured_age          INTEGER CHECK (injured_age > 0 AND injured_age < 120),
    injured_sex          TEXT CHECK (injured_sex IN ('Male','Female')),
    injured_id_number    TEXT,
    occupation_at_accident TEXT,
    usual_occupation     TEXT,
    experience_level     TEXT,

    -- Accident Details
    accident_date        DATE,
    accident_time        TIME,
    accident_place       TEXT,
    accident_description TEXT,
    machinery_involved   TEXT,

    -- Injury
    injury_fatal         TEXT CHECK (injury_fatal IN ('Fatal','Non-fatal')),
    disabled_three_days  TEXT CHECK (disabled_three_days IN ('Yes','No')),
    hourly_pay           NUMERIC(10,2),
    medical_practitioner TEXT,

    -- Dangerous Occurrence
    dangerous_date           DATE,
    dangerous_time           TIME,
    dangerous_place          TEXT,
    dangerous_description    TEXT,
    dangerous_damage         TEXT,
    employees_injured        TEXT CHECK (employees_injured IN ('Yes','No')),
    notification_submitted   TEXT CHECK (notification_submitted IN ('Yes','No')),
    outside_persons_injured  TEXT,

    -- Submission
    report_date          DATE NOT NULL DEFAULT CURRENT_DATE,
    reporter_name        TEXT NOT NULL,
    reporter_designation TEXT,

    -- Official Use
    causation_number        TEXT,
    date_received           DATE,
    investigation_status    TEXT DEFAULT 'Pending'
        CHECK (investigation_status IN ('Pending','In Progress','Completed','Closed')),
    official_action         TEXT,

    -- Metadata
    submitted_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    worker_registry_id  UUID,
    status              TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('submitted','under_review','investigated','closed')),
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE accident_reports IS 'OHS Form 60 — Notification of Accident and/or Dangerous Occurrence (Factories Act 1973, S.57)';
COMMENT ON COLUMN accident_reports.injured_id_number IS 'Worker Omang or passport — searchable; stored UPPER(TRIM); links to workers_registry.id_number';

-- ── 3c. Injury claims ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS injury_claims (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Claim Information
    file_number         TEXT UNIQUE,
    name_of_employer    TEXT NOT NULL,
    industry            TEXT NOT NULL,

    -- Claimant Information
    name_of_claimant    TEXT NOT NULL,
    gender              TEXT CHECK (gender IN ('M', 'F')),
    location            TEXT NOT NULL,
    nationality         TEXT NOT NULL,
    claimant_id_number  TEXT,

    -- Injury Details
    date_of_injury      DATE NOT NULL,
    date_reported       DATE NOT NULL,
    date_received       DATE NOT NULL,
    cause               TEXT NOT NULL,
    nature              TEXT NOT NULL,
    incapacity_percentage NUMERIC(5,2) NOT NULL CHECK (incapacity_percentage >= 0 AND incapacity_percentage <= 100),

    -- Draft workflow
    source_type         TEXT CHECK (source_type IS NULL OR source_type IN ('accident', 'injury_disease', 'manual')),
    source_id           UUID,

    -- Metadata
    submitted_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    worker_registry_id  UUID,
    status              TEXT DEFAULT 'pending'
        CHECK (status IN ('draft','pending','under_review','approved','rejected','closed','cancelled')),
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE injury_claims IS 'Stores injury claim form submissions from OSH website';
COMMENT ON COLUMN injury_claims.file_number IS 'Unique claim file number: OHS/COMP/{claimant_id}/{sequence}/{YY} (auto-generated on insert)';
COMMENT ON COLUMN injury_claims.claimant_id_number IS 'Claimant Omang or passport — searchable; stored UPPER(TRIM)';
COMMENT ON COLUMN injury_claims.source_type IS 'accident | injury_disease | manual';
COMMENT ON COLUMN injury_claims.source_id IS 'UUID of accident_reports or injury_disease_reports row';

-- ── 3d. Injury & disease reports (Form 43/10) ────────────────
CREATE TABLE IF NOT EXISTS injury_disease_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Worker
    worker_name         TEXT NOT NULL,
    worker_address      TEXT NOT NULL,
    occupation          TEXT NOT NULL,
    worker_id_number    TEXT,

    -- Incident
    incident_date       DATE NOT NULL,
    place_of_accident   TEXT NOT NULL,
    incident_type       TEXT NOT NULL
        CHECK (incident_type IN ('Injury','Disease','Both')),
    nature_of_injuries  TEXT NOT NULL,

    -- Outcome
    resulted_death          TEXT CHECK (resulted_death       IN ('Yes','No')),
    permanent_incapacity    TEXT CHECK (permanent_incapacity IN ('Yes','No')),
    temporary_incapacity    TEXT CHECK (temporary_incapacity IN ('Yes','No')),
    nok_informed            TEXT CHECK (nok_informed         IN ('Yes','No')),

    -- Employer
    employer_name       TEXT NOT NULL,
    employer_telephone  TEXT,
    employer_fax        TEXT,

    -- Submission
    report_date             DATE NOT NULL DEFAULT CURRENT_DATE,
    signatory_name          TEXT,
    signatory_designation   TEXT,

    -- Metadata
    submitted_by    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    worker_registry_id UUID,
    status          TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('submitted','under_review','processed','closed')),
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE injury_disease_reports IS 'BL Form 43/10 — Injury and Disease Reports under Worker''s Compensation Act No.23 of 1998';
COMMENT ON COLUMN injury_disease_reports.worker_id_number IS 'Worker Omang or passport — searchable; stored UPPER(TRIM); links to workers_registry.id_number';

-- ── 3e. Workplace inspections ────────────────────────────────
CREATE TABLE IF NOT EXISTS workplace_inspections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Identification
    file_number         TEXT NOT NULL,
    inspection_date     DATE NOT NULL,
    date_report_sent    DATE,
    days_to_respond     INTEGER,
    factory_name        TEXT NOT NULL,
    location            TEXT NOT NULL,
    nature_of_work      TEXT NOT NULL,

    -- Classification
    industry_type       TEXT NOT NULL
        CHECK (industry_type IN ('Manufacturing','Services','Construction','Agriculture','Transport','Retail','Government','Parastatal')),
    registration_status TEXT NOT NULL CHECK (registration_status IN ('Yes','No','N/A')),
    inspection_type     TEXT NOT NULL
        CHECK (inspection_type IN ('Routine','Follow-up','Query','First Time')),

    -- Employees
    employees_male          INTEGER NOT NULL DEFAULT 0 CHECK (employees_male          >= 0),
    employees_female        INTEGER NOT NULL DEFAULT 0 CHECK (employees_female        >= 0),
    employees_foreign_male  INTEGER NOT NULL DEFAULT 0 CHECK (employees_foreign_male  >= 0),
    employees_foreign_female INTEGER NOT NULL DEFAULT 0 CHECK (employees_foreign_female >= 0),

    -- Inspector
    inspector_name      TEXT NOT NULL,

    -- Common Contraventions (S9, S13-S18, S41-S42, S46-S49, S52-S53, S62, S66-S67)
    s9  BOOLEAN DEFAULT FALSE,  s13 BOOLEAN DEFAULT FALSE,  s14 BOOLEAN DEFAULT FALSE,
    s15 BOOLEAN DEFAULT FALSE,  s16 BOOLEAN DEFAULT FALSE,  s18 BOOLEAN DEFAULT FALSE,
    s41 BOOLEAN DEFAULT FALSE,  s42 BOOLEAN DEFAULT FALSE,  s46 BOOLEAN DEFAULT FALSE,
    s47 BOOLEAN DEFAULT FALSE,  s48 BOOLEAN DEFAULT FALSE,  s49 BOOLEAN DEFAULT FALSE,
    s52 BOOLEAN DEFAULT FALSE,  s53 BOOLEAN DEFAULT FALSE,  s62 BOOLEAN DEFAULT FALSE,
    s66 BOOLEAN DEFAULT FALSE,  s67 BOOLEAN DEFAULT FALSE,

    -- Other Contraventions (S17, S23, S29-S32, S34, S37-S39, S51, S54, S57-S58)
    s17 BOOLEAN DEFAULT FALSE,  s23 BOOLEAN DEFAULT FALSE,  s29 BOOLEAN DEFAULT FALSE,
    s30 BOOLEAN DEFAULT FALSE,  s31 BOOLEAN DEFAULT FALSE,  s32 BOOLEAN DEFAULT FALSE,
    s34 BOOLEAN DEFAULT FALSE,  s37 BOOLEAN DEFAULT FALSE,  s38 BOOLEAN DEFAULT FALSE,
    s39 BOOLEAN DEFAULT FALSE,  s51 BOOLEAN DEFAULT FALSE,  s54 BOOLEAN DEFAULT FALSE,
    s57 BOOLEAN DEFAULT FALSE,  s58 BOOLEAN DEFAULT FALSE,

    -- Compliance Totals
    total_contraventions  INTEGER NOT NULL DEFAULT 0,
    non_compliance_pct    INTEGER NOT NULL DEFAULT 0 CHECK (non_compliance_pct BETWEEN 0 AND 100),
    compliance_level      INTEGER NOT NULL DEFAULT 100 CHECK (compliance_level BETWEEN 0 AND 100),
    contraventions        TEXT[],

    -- Plant & Machinery
    plant_machinery       JSONB,

    -- Action & Follow-up
    action_taken          TEXT NOT NULL
        CHECK (action_taken IN ('Advised to Comply','Warned','Compliance Satisfactory',
                                'Prohibition Notice Issued','Improvement Notice Issued','Prosecution Recommended')),
    follow_up_required    BOOLEAN NOT NULL DEFAULT FALSE,
    follow_up_date        DATE,

    -- Narrative
    summary_findings      TEXT,
    non_compliances       TEXT,
    recommendations       TEXT,

    -- Metadata
    submitted_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status                TEXT NOT NULL DEFAULT 'completed'
        CHECK (status IN ('draft','completed','reviewed','closed')),
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at            TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE workplace_inspections IS 'OSH workplace inspection reports — matches Q1 Excel Inspection Report structure';

-- ── 3f. Workers registry ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS workers_registry (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Identity (unique key)
    id_number       TEXT NOT NULL UNIQUE,
    id_type         TEXT NOT NULL DEFAULT 'Omang'
                    CHECK (id_type IN ('Omang','Passport')),

    -- Personal details
    full_name       TEXT NOT NULL,
    date_of_birth   DATE,
    sex             TEXT CHECK (sex IN ('Male','Female')),
    nationality     TEXT,
    address         TEXT,

    -- Employment details
    occupation          TEXT,
    usual_occupation    TEXT,
    experience_level    TEXT,
    employer_name       TEXT,
    employer_address    TEXT,
    employer_telephone  TEXT,
    employer_fax          TEXT,
    age_years           INTEGER CHECK (age_years IS NULL OR (age_years > 0 AND age_years < 120)),

    -- Metadata
    created_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE workers_registry IS 'Central worker identity registry keyed on Omang/Passport — used for autofill across all forms';
COMMENT ON COLUMN workers_registry.id_number IS 'Primary identity key: Omang or passport — unique, searchable, UPPER(TRIM)';
COMMENT ON COLUMN workers_registry.id_type IS 'Omang = national ID citizen; Passport = foreign national — set at registration';

-- ── 3g. Inspection bookings ──────────────────────────────────
CREATE TABLE IF NOT EXISTS inspection_bookings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    company_name        TEXT NOT NULL,
    company_id          UUID REFERENCES companies(id) ON DELETE SET NULL,
    contact_name        TEXT NOT NULL,
    contact_email       TEXT NOT NULL,
    contact_phone       TEXT,

    preferred_date      DATE,
    preferred_time      TEXT,
    inspection_type     TEXT NOT NULL DEFAULT 'Routine'
        CHECK (inspection_type IN ('Routine','Follow-up','First Time','Query')),
    location            TEXT NOT NULL,
    nature_of_work      TEXT,
    industry_type       TEXT,

    notes               TEXT,
    special_requirements TEXT,

    status              TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','approved','scheduled','completed','cancelled')),
    assigned_inspector  TEXT,
    scheduled_date      DATE,
    scheduled_time      TEXT,
    admin_notes         TEXT,

    submitted_by        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE inspection_bookings IS 'Inspection booking requests submitted by companies';

-- ── 3h. Medical examination reports (Form 43/03) ─────────────
CREATE TABLE IF NOT EXISTS medical_examination_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    claim_id            UUID REFERENCES injury_claims(id) ON DELETE SET NULL,
    worker_registry_id  UUID REFERENCES workers_registry(id) ON DELETE SET NULL,

    worker_name         TEXT NOT NULL,
    worker_id_number    TEXT,
    claim_file_number   TEXT,

    nature_of_injury_or_disease TEXT NOT NULL,
    medical_treatment_particulars TEXT NOT NULL,

    death_incapacity              BOOLEAN DEFAULT FALSE,
    permanent_total_incapacity    BOOLEAN DEFAULT FALSE,
    permanent_partial_incapacity  BOOLEAN DEFAULT FALSE,
    temporary_incapacity          BOOLEAN DEFAULT FALSE,
    temporary_probable_duration   TEXT,
    incapacity_percentage         NUMERIC(5,2),

    capable_light_duties          TEXT CHECK (capable_light_duties IN ('Yes', 'No', 'Not applicable')),
    final_examination_necessary   TEXT CHECK (final_examination_necessary IN ('Yes', 'No', 'Not applicable')),
    able_to_resume_work           TEXT CHECK (able_to_resume_work IN ('Yes', 'No', 'Not applicable')),

    report_date              DATE NOT NULL DEFAULT CURRENT_DATE,
    practitioner_name        TEXT NOT NULL,
    practitioner_designation TEXT NOT NULL,

    worker_representative_name TEXT,

    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status       TEXT DEFAULT 'submitted' CHECK (status IN ('draft', 'submitted')),
    created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE medical_examination_reports IS 'BL Form 43/03 — Report of Results of Medical Examination (Worker''s Compensation Act, Section 10)';

-- ============================================================
--  SECTION 4 — CONSTRAINT FIXES & MIGRATIONS
--     (These are safe to run even if constraints already exist)
-- ============================================================

-- ── 4a. Department constraint ───────────────────────────────
ALTER TABLE user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_department_check;

ALTER TABLE user_profiles
    ADD CONSTRAINT user_profiles_department_check
    CHECK (department IN ('osh', 'company', 'general', 'medical'));

-- ── 4b. Role constraint ─────────────────────────────────────
ALTER TABLE user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_role_check;

ALTER TABLE user_profiles
    ADD CONSTRAINT user_profiles_role_check
    CHECK (role IN ('viewer', 'officer', 'admin', 'super_admin', 'company', 'worker', 'medical_practitioner'));

-- ── 4c. Injury claims — drop NOT NULL on file_number (for drafts) ──
ALTER TABLE injury_claims ALTER COLUMN file_number DROP NOT NULL;

-- ============================================================
--  SECTION 5 — ADD MISSING COLUMNS (belt-and-suspenders)
-- ============================================================

ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS company_id    UUID REFERENCES companies(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS role          TEXT DEFAULT 'viewer',
    ADD COLUMN IF NOT EXISTS designation   TEXT,
    ADD COLUMN IF NOT EXISTS last_sign_in  TIMESTAMPTZ;

ALTER TABLE companies
    ADD COLUMN IF NOT EXISTS industry         TEXT,
    ADD COLUMN IF NOT EXISTS location         TEXT,
    ADD COLUMN IF NOT EXISTS physical_address TEXT,
    ADD COLUMN IF NOT EXISTS plot_number      TEXT,
    ADD COLUMN IF NOT EXISTS street_name      TEXT,
    ADD COLUMN IF NOT EXISTS telephone        TEXT,
    ADD COLUMN IF NOT EXISTS owner_name       TEXT,
    ADD COLUMN IF NOT EXISTS owner_email      TEXT,
    ADD COLUMN IF NOT EXISTS cipa_number      TEXT,
    ADD COLUMN IF NOT EXISTS is_active        BOOLEAN DEFAULT true;

ALTER TABLE accident_reports
    ADD COLUMN IF NOT EXISTS injured_id_number TEXT,
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL;

ALTER TABLE injury_disease_reports
    ADD COLUMN IF NOT EXISTS worker_id_number TEXT,
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL;

ALTER TABLE injury_claims
    ADD COLUMN IF NOT EXISTS gender TEXT CHECK (gender IN ('M', 'F')),
    ADD COLUMN IF NOT EXISTS claimant_id_number TEXT,
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID REFERENCES workers_registry(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS source_type TEXT CHECK (source_type IS NULL OR source_type IN ('accident', 'injury_disease', 'manual')),
    ADD COLUMN IF NOT EXISTS source_id UUID;

-- ============================================================
--  SECTION 6 — INDEXES
-- ============================================================

-- User profiles
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id     ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_email       ON user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_department  ON user_profiles(department);
CREATE INDEX IF NOT EXISTS idx_user_profiles_active      ON user_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_user_profiles_role        ON user_profiles(role);
CREATE INDEX IF NOT EXISTS idx_up_company_id             ON user_profiles(company_id);

-- Login history
CREATE INDEX IF NOT EXISTS idx_login_history_user_id     ON login_history(user_id);
CREATE INDEX IF NOT EXISTS idx_login_history_login_time  ON login_history(login_time DESC);
CREATE INDEX IF NOT EXISTS idx_login_history_successful  ON login_history(login_successful);

-- Password reset
CREATE INDEX IF NOT EXISTS idx_password_reset_user_id      ON password_reset_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_status       ON password_reset_requests(status);
CREATE INDEX IF NOT EXISTS idx_password_reset_requested_at ON password_reset_requests(requested_at DESC);

-- Activity log
CREATE INDEX IF NOT EXISTS idx_activity_log_user_id       ON user_activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_created_at    ON user_activity_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_log_activity_type ON user_activity_log(activity_type);

-- Companies
CREATE INDEX IF NOT EXISTS idx_companies_name ON companies(company_name);

-- Accident reports
CREATE INDEX IF NOT EXISTS idx_ar_occupier       ON accident_reports(occupier_name);
CREATE INDEX IF NOT EXISTS idx_ar_accident_date  ON accident_reports(accident_date DESC);
CREATE INDEX IF NOT EXISTS idx_ar_report_date    ON accident_reports(report_date DESC);
CREATE INDEX IF NOT EXISTS idx_ar_report_type    ON accident_reports(report_type);
CREATE INDEX IF NOT EXISTS idx_ar_injury_fatal   ON accident_reports(injury_fatal);
CREATE INDEX IF NOT EXISTS idx_ar_inv_status     ON accident_reports(investigation_status);
CREATE INDEX IF NOT EXISTS idx_ar_submitted_by   ON accident_reports(submitted_by);
CREATE INDEX IF NOT EXISTS idx_ar_status         ON accident_reports(status);
CREATE INDEX IF NOT EXISTS idx_ar_created_at     ON accident_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ar_worker_reg     ON accident_reports(worker_registry_id);
CREATE INDEX IF NOT EXISTS idx_ar_injured_id_number ON accident_reports(injured_id_number) WHERE injured_id_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ar_injured_name   ON accident_reports(injured_name) WHERE injured_name IS NOT NULL;

-- Injury claims
CREATE INDEX IF NOT EXISTS idx_injury_claims_file_number   ON injury_claims(file_number);
CREATE INDEX IF NOT EXISTS idx_injury_claims_submitted_by  ON injury_claims(submitted_by);
CREATE INDEX IF NOT EXISTS idx_injury_claims_status        ON injury_claims(status);
CREATE INDEX IF NOT EXISTS idx_injury_claims_date_of_injury ON injury_claims(date_of_injury DESC);
CREATE INDEX IF NOT EXISTS idx_injury_claims_date_received ON injury_claims(date_received DESC);
CREATE INDEX IF NOT EXISTS idx_injury_claims_created_at    ON injury_claims(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_injury_claims_employer      ON injury_claims(name_of_employer);
CREATE INDEX IF NOT EXISTS idx_injury_claims_industry      ON injury_claims(industry);
CREATE INDEX IF NOT EXISTS idx_ic_worker_reg               ON injury_claims(worker_registry_id);
CREATE INDEX IF NOT EXISTS idx_ic_id_number                ON injury_claims(claimant_id_number);
CREATE INDEX IF NOT EXISTS idx_ic_claimant_id_number       ON injury_claims(claimant_id_number) WHERE claimant_id_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ic_source                   ON injury_claims (source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_ic_draft_status             ON injury_claims (status) WHERE status = 'draft';

-- Injury/disease reports
CREATE INDEX IF NOT EXISTS idx_idr_worker_name     ON injury_disease_reports(worker_name);
CREATE INDEX IF NOT EXISTS idx_idr_incident_date   ON injury_disease_reports(incident_date DESC);
CREATE INDEX IF NOT EXISTS idx_idr_employer_name   ON injury_disease_reports(employer_name);
CREATE INDEX IF NOT EXISTS idx_idr_incident_type   ON injury_disease_reports(incident_type);
CREATE INDEX IF NOT EXISTS idx_idr_resulted_death  ON injury_disease_reports(resulted_death);
CREATE INDEX IF NOT EXISTS idx_idr_status          ON injury_disease_reports(status);
CREATE INDEX IF NOT EXISTS idx_idr_submitted_by    ON injury_disease_reports(submitted_by);
CREATE INDEX IF NOT EXISTS idx_idr_created_at      ON injury_disease_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_idr_worker_reg      ON injury_disease_reports(worker_registry_id);
CREATE INDEX IF NOT EXISTS idx_idr_worker_id_number ON injury_disease_reports(worker_id_number) WHERE worker_id_number IS NOT NULL;

-- Workplace inspections
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
CREATE INDEX IF NOT EXISTS idx_wi_contraventions   ON workplace_inspections USING GIN(contraventions);
CREATE INDEX IF NOT EXISTS idx_wi_plant            ON workplace_inspections USING GIN(plant_machinery);

-- Workers registry
CREATE UNIQUE INDEX IF NOT EXISTS idx_wr_id_number  ON workers_registry(id_number);
CREATE INDEX IF NOT EXISTS idx_wr_full_name         ON workers_registry(full_name);
CREATE INDEX IF NOT EXISTS idx_wr_employer          ON workers_registry(employer_name);
CREATE INDEX IF NOT EXISTS idx_wr_created_at        ON workers_registry(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wr_usual_occupation  ON workers_registry(usual_occupation);
CREATE INDEX IF NOT EXISTS idx_wr_age_years         ON workers_registry(age_years);

-- Inspection bookings
CREATE INDEX IF NOT EXISTS idx_ib_company_name   ON inspection_bookings(company_name);
CREATE INDEX IF NOT EXISTS idx_ib_status         ON inspection_bookings(status);
CREATE INDEX IF NOT EXISTS idx_ib_company_id     ON inspection_bookings(company_id);
CREATE INDEX IF NOT EXISTS idx_ib_submitted_by   ON inspection_bookings(submitted_by);

-- Medical examination reports
CREATE INDEX IF NOT EXISTS idx_mer_claim_id           ON medical_examination_reports(claim_id);
CREATE INDEX IF NOT EXISTS idx_mer_worker_registry_id ON medical_examination_reports(worker_registry_id);
CREATE INDEX IF NOT EXISTS idx_mer_worker_name        ON medical_examination_reports(worker_name);
CREATE INDEX IF NOT EXISTS idx_mer_submitted_by       ON medical_examination_reports(submitted_by);
CREATE INDEX IF NOT EXISTS idx_mer_created_at         ON medical_examination_reports(created_at DESC);

-- Unique index: one open draft per incident source
CREATE UNIQUE INDEX IF NOT EXISTS idx_claim_one_draft_per_source
    ON injury_claims (source_type, source_id)
    WHERE status = 'draft' AND source_id IS NOT NULL;

-- Trigram indexes for worker identity search
CREATE INDEX IF NOT EXISTS idx_ar_injured_id_trgm    ON accident_reports USING GIN (injured_id_number gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_ar_injured_name_trgm  ON accident_reports USING GIN (injured_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_idr_worker_id_trgm    ON injury_disease_reports USING GIN (worker_id_number gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_idr_worker_name_trgm  ON injury_disease_reports USING GIN (worker_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_ic_claimant_id_trgm   ON injury_claims USING GIN (claimant_id_number gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_wr_id_number_trgm     ON workers_registry USING GIN (id_number gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_wr_full_name_trgm     ON workers_registry USING GIN (full_name gin_trgm_ops);

-- Full-text search index on worker name
CREATE INDEX IF NOT EXISTS idx_wr_name_trgm
    ON workers_registry USING GIN (to_tsvector('english', full_name));

-- ============================================================
--  SECTION 7 — ROW LEVEL SECURITY
-- ============================================================

-- ── 7a. Enable RLS on all tables ────────────────────────────
ALTER TABLE departments                ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE login_history              ENABLE ROW LEVEL SECURITY;
ALTER TABLE password_reset_requests    ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activity_log          ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles_info            ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_change_log            ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE accident_reports           ENABLE ROW LEVEL SECURITY;
ALTER TABLE injury_claims              ENABLE ROW LEVEL SECURITY;
ALTER TABLE injury_disease_reports     ENABLE ROW LEVEL SECURITY;
ALTER TABLE workplace_inspections      ENABLE ROW LEVEL SECURITY;
ALTER TABLE workers_registry           ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspection_bookings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE medical_examination_reports ENABLE ROW LEVEL SECURITY;

-- ── 7b. Departments ─────────────────────────────────────────
DROP POLICY IF EXISTS "Authenticated users can view departments" ON departments;
CREATE POLICY "Authenticated users can view departments"
    ON departments FOR SELECT TO authenticated USING (true);

-- ── 7c. User profiles ───────────────────────────────────────
DROP POLICY IF EXISTS "All users can view profiles" ON user_profiles;
DROP POLICY IF EXISTS "Officers can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update based on role" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;

-- All authenticated users can view profiles (for admin panel)
CREATE POLICY "Authenticated users can view all profiles"
    ON user_profiles FOR SELECT TO authenticated USING (true);

-- Role-based insert
CREATE POLICY "Users can insert own profile"
    ON user_profiles FOR INSERT
    TO authenticated, anon
    WITH CHECK (
        auth.uid() = user_id
        OR auth.role() = 'anon'
    );

-- Role-based update
CREATE POLICY "Users can update based on role"
    ON user_profiles FOR UPDATE TO authenticated
    USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    )
    WITH CHECK (
        (auth.uid() = user_id AND role = (SELECT role FROM user_profiles WHERE user_id = auth.uid()))
        OR (
            EXISTS (SELECT 1 FROM user_profiles up WHERE up.user_id = auth.uid() AND up.role = 'admin')
            AND role != 'super_admin'
            AND (SELECT role FROM user_profiles WHERE user_id = user_profiles.user_id) != 'super_admin'
        )
        OR (
            EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role = 'super_admin')
        )
    );

-- Service role insert
DROP POLICY IF EXISTS "Service role can insert profiles" ON user_profiles;
CREATE POLICY "Service role can insert profiles"
    ON user_profiles FOR INSERT TO service_role WITH CHECK (true);

-- ── 7d. Login history ────────────────────────────────────────
DROP POLICY IF EXISTS "Users can view own login history" ON login_history;
DROP POLICY IF EXISTS "Users can insert own login history" ON login_history;

CREATE POLICY "Users can view own login history"
    ON login_history FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own login history"
    ON login_history FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ── 7e. Password reset requests ─────────────────────────────
DROP POLICY IF EXISTS "Users can view own password reset requests" ON password_reset_requests;
DROP POLICY IF EXISTS "Anyone can request password reset" ON password_reset_requests;

CREATE POLICY "Users can view own password reset requests"
    ON password_reset_requests FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Anyone can request password reset"
    ON password_reset_requests FOR INSERT WITH CHECK (true);

-- ── 7f. User activity log ───────────────────────────────────
DROP POLICY IF EXISTS "Users can view own activity" ON user_activity_log;
DROP POLICY IF EXISTS "Users can insert own activity" ON user_activity_log;

CREATE POLICY "Users can view own activity"
    ON user_activity_log FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own activity"
    ON user_activity_log FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ── 7g. Roles info ───────────────────────────────────────────
DROP POLICY IF EXISTS "All users can view role info" ON user_roles_info;
CREATE POLICY "All users can view role info"
    ON user_roles_info FOR SELECT TO authenticated USING (true);

-- ── 7h. Role change log ─────────────────────────────────────
DROP POLICY IF EXISTS "Admins can view role changes" ON role_change_log;
CREATE POLICY "Admins can view role changes"
    ON role_change_log FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin', 'super_admin')));

-- ── 7i. Companies ───────────────────────────────────────────
DROP POLICY IF EXISTS "All authenticated users can view companies" ON companies;
DROP POLICY IF EXISTS "Anyone can insert companies" ON companies;
DROP POLICY IF EXISTS "Company users can update own, admins update all" ON companies;

CREATE POLICY "All authenticated users can view companies"
    ON companies FOR SELECT TO authenticated USING (true);

CREATE POLICY "Anyone can insert companies"
    ON companies FOR INSERT TO authenticated, anon WITH CHECK (true);

CREATE POLICY "Company users can update own, admins update all"
    ON companies FOR UPDATE TO authenticated
    USING (
        id IN (SELECT company_id FROM user_profiles WHERE user_id = auth.uid())
        OR EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin', 'super_admin'))
    );

-- ── 7j. Accident reports ────────────────────────────────────
DROP POLICY IF EXISTS "All users can view accident reports" ON accident_reports;
DROP POLICY IF EXISTS "Officers and above can insert accident reports" ON accident_reports;
DROP POLICY IF EXISTS "Officers update own, admins update all" ON accident_reports;

CREATE POLICY "All users can view accident reports"
    ON accident_reports FOR SELECT TO authenticated USING (true);

CREATE POLICY "Officers and above can insert accident reports"
    ON accident_reports FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin'))
        AND auth.uid() = submitted_by
    );

CREATE POLICY "Officers update own, admins update all"
    ON accident_reports FOR UPDATE TO authenticated
    USING (
        auth.uid() = submitted_by
        OR EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin'))
    )
    WITH CHECK (
        auth.uid() = submitted_by
        OR EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin'))
    );

-- ── 7k. Injury claims ───────────────────────────────────────
DROP POLICY IF EXISTS "Users can view own claims" ON injury_claims;
DROP POLICY IF EXISTS "Users can insert own claims" ON injury_claims;
DROP POLICY IF EXISTS "Users can update own pending claims" ON injury_claims;
DROP POLICY IF EXISTS "Authenticated users can view all claims" ON injury_claims;
DROP POLICY IF EXISTS "All users can view claims" ON injury_claims;
DROP POLICY IF EXISTS "Officers and above can insert claims" ON injury_claims;
DROP POLICY IF EXISTS "Officers and above can update claims" ON injury_claims;
DROP POLICY IF EXISTS "Officers can cancel own draft claims" ON injury_claims;

CREATE POLICY "All users can view claims"
    ON injury_claims FOR SELECT TO authenticated USING (true);

CREATE POLICY "Officers and above can insert claims"
    ON injury_claims FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('officer', 'admin', 'super_admin'))
        AND auth.uid() = submitted_by
    );

CREATE POLICY "Users can update own pending claims"
    ON injury_claims FOR UPDATE TO authenticated
    USING (auth.uid() = submitted_by AND status IN ('pending', 'draft'))
    WITH CHECK (auth.uid() = submitted_by);

CREATE POLICY "Officers can cancel own draft claims"
    ON injury_claims FOR UPDATE TO authenticated
    USING (auth.uid() = submitted_by AND status = 'draft')
    WITH CHECK (status = 'cancelled');

CREATE POLICY "Officers and above can update claims"
    ON injury_claims FOR UPDATE TO authenticated
    USING (
        (EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role = 'officer') AND auth.uid() = submitted_by)
        OR EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin', 'super_admin'))
    )
    WITH CHECK (
        (EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role = 'officer') AND auth.uid() = submitted_by)
        OR EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin', 'super_admin'))
    );

-- ── 7l. Injury/disease reports ──────────────────────────────
DROP POLICY IF EXISTS "All users can view injury disease reports" ON injury_disease_reports;
DROP POLICY IF EXISTS "Officers and above can insert injury disease reports" ON injury_disease_reports;
DROP POLICY IF EXISTS "Officers update own, admins update all injury disease reports" ON injury_disease_reports;

CREATE POLICY "All users can view injury disease reports"
    ON injury_disease_reports FOR SELECT TO authenticated USING (true);

CREATE POLICY "Officers and above can insert injury disease reports"
    ON injury_disease_reports FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin'))
        AND auth.uid() = submitted_by
    );

CREATE POLICY "Officers update own, admins update all injury disease reports"
    ON injury_disease_reports FOR UPDATE TO authenticated
    USING (
        auth.uid() = submitted_by
        OR EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin'))
    );

-- ── 7m. Workplace inspections ───────────────────────────────
DROP POLICY IF EXISTS "All users can view inspections" ON workplace_inspections;
DROP POLICY IF EXISTS "Officers and above can insert inspections" ON workplace_inspections;
DROP POLICY IF EXISTS "Officers can update own, admins update all" ON workplace_inspections;
DROP POLICY IF EXISTS "Admins can delete inspections" ON workplace_inspections;

CREATE POLICY "All users can view inspections"
    ON workplace_inspections FOR SELECT TO authenticated USING (true);

CREATE POLICY "Officers and above can insert inspections"
    ON workplace_inspections FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin'))
        AND auth.uid() = submitted_by
    );

CREATE POLICY "Officers can update own, admins update all"
    ON workplace_inspections FOR UPDATE TO authenticated
    USING (
        auth.uid() = submitted_by
        OR EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin'))
    )
    WITH CHECK (
        auth.uid() = submitted_by
        OR EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin'))
    );

CREATE POLICY "Admins can delete inspections"
    ON workplace_inspections FOR DELETE TO authenticated
    USING (EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin')));

-- ── 7n. Workers registry ────────────────────────────────────
DROP POLICY IF EXISTS "All authenticated users can view workers registry" ON workers_registry;
DROP POLICY IF EXISTS "Officers and above can insert workers" ON workers_registry;
DROP POLICY IF EXISTS "Officers update own workers, admins update all" ON workers_registry;

CREATE POLICY "All authenticated users can view workers registry"
    ON workers_registry FOR SELECT TO authenticated USING (true);

CREATE POLICY "Officers and above can insert workers"
    ON workers_registry FOR INSERT TO authenticated
    WITH CHECK (EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin')));

CREATE POLICY "Officers update own workers, admins update all"
    ON workers_registry FOR UPDATE TO authenticated
    USING (
        auth.uid() = created_by
        OR EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin'))
    );

-- ── 7o. Inspection bookings ─────────────────────────────────
DROP POLICY IF EXISTS "Companies can view own bookings" ON inspection_bookings;
DROP POLICY IF EXISTS "Company users can insert bookings" ON inspection_bookings;
DROP POLICY IF EXISTS "Officers can update bookings" ON inspection_bookings;

CREATE POLICY "Companies can view own bookings"
    ON inspection_bookings FOR SELECT TO authenticated
    USING (
        submitted_by = auth.uid()
        OR EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin'))
    );

CREATE POLICY "Company users can insert bookings"
    ON inspection_bookings FOR INSERT TO authenticated
    WITH CHECK (EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('company','officer','admin','super_admin')));

CREATE POLICY "Officers can update bookings"
    ON inspection_bookings FOR UPDATE TO authenticated
    USING (EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('officer','admin','super_admin')));

-- ── 7p. Medical examination reports ─────────────────────────
DROP POLICY IF EXISTS "Authenticated users can view medical reports" ON medical_examination_reports;
DROP POLICY IF EXISTS "Officers can insert medical reports" ON medical_examination_reports;
DROP POLICY IF EXISTS "Users can update own medical reports" ON medical_examination_reports;

CREATE POLICY "Authenticated users can view medical reports"
    ON medical_examination_reports FOR SELECT TO authenticated USING (true);

CREATE POLICY "Officers can insert medical reports"
    ON medical_examination_reports FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Users can update own medical reports"
    ON medical_examination_reports FOR UPDATE
    USING (auth.uid() = submitted_by)
    WITH CHECK (auth.uid() = submitted_by);

-- ============================================================
--  SECTION 8 — FUNCTIONS & TRIGGERS
-- ============================================================

-- ── 8a. Updated-at trigger (shared by many tables) ──────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to timestamped tables
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_companies_updated_at ON companies;
CREATE TRIGGER update_companies_updated_at
    BEFORE UPDATE ON companies FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_accident_reports_updated_at ON accident_reports;
CREATE TRIGGER update_accident_reports_updated_at
    BEFORE UPDATE ON accident_reports FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_injury_claims_updated_at ON injury_claims;
CREATE TRIGGER update_injury_claims_updated_at
    BEFORE UPDATE ON injury_claims FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_injury_disease_reports_updated_at ON injury_disease_reports;
CREATE TRIGGER update_injury_disease_reports_updated_at
    BEFORE UPDATE ON injury_disease_reports FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_workplace_inspections_updated_at ON workplace_inspections;
CREATE TRIGGER update_workplace_inspections_updated_at
    BEFORE UPDATE ON workplace_inspections FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_workers_registry_updated_at ON workers_registry;
CREATE TRIGGER update_workers_registry_updated_at
    BEFORE UPDATE ON workers_registry FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_inspection_bookings_updated_at ON inspection_bookings;
CREATE TRIGGER update_inspection_bookings_updated_at
    BEFORE UPDATE ON inspection_bookings FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_mer_updated_at ON medical_examination_reports;
CREATE TRIGGER update_mer_updated_at
    BEFORE UPDATE ON medical_examination_reports FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ── 8b. Session duration calculation ─────────────────────────
CREATE OR REPLACE FUNCTION calculate_session_duration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.logout_time IS NOT NULL AND OLD.logout_time IS NULL THEN
        NEW.session_duration = NEW.logout_time - NEW.login_time;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS calculate_login_session_duration ON login_history;
CREATE TRIGGER calculate_login_session_duration
    BEFORE UPDATE ON login_history FOR EACH ROW
    EXECUTE FUNCTION calculate_session_duration();

-- ── 8c. Auto-expire old password resets ──────────────────────
CREATE OR REPLACE FUNCTION expire_old_password_resets()
RETURNS void AS $$
BEGIN
    UPDATE password_reset_requests
    SET status = 'expired'
    WHERE status = 'pending' AND requested_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- ── 8d. Role change audit trigger ────────────────────────────
CREATE OR REPLACE FUNCTION log_role_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.role IS DISTINCT FROM NEW.role THEN
        INSERT INTO role_change_log (user_id, old_role, new_role, changed_by)
        VALUES (NEW.user_id, OLD.role, NEW.role, auth.uid());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS role_change_trigger ON user_profiles;
CREATE TRIGGER role_change_trigger
    AFTER UPDATE ON user_profiles FOR EACH ROW
    EXECUTE FUNCTION log_role_change();

-- ── 8e. Compliance computation (workplace inspections) ──────
CREATE OR REPLACE FUNCTION compute_compliance_totals()
RETURNS TRIGGER AS $$
DECLARE
    total INT := 0;
BEGIN
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
    BEFORE INSERT OR UPDATE ON workplace_inspections FOR EACH ROW
    EXECUTE FUNCTION compute_compliance_totals();

-- ── 8f. ID number normalization triggers ────────────────────
CREATE OR REPLACE FUNCTION normalize_identity_id(val TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN val IS NULL OR btrim(val) = '' THEN NULL
        ELSE upper(btrim(val))
    END;
$$;

COMMENT ON FUNCTION normalize_identity_id(TEXT) IS 'Trims and uppercases Omang/passport values for indexed search';

-- Normalize accident_reports.injured_id_number
CREATE OR REPLACE FUNCTION trg_normalize_injured_id_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.injured_id_number := normalize_identity_id(NEW.injured_id_number);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS normalize_injured_id ON accident_reports;
CREATE TRIGGER normalize_injured_id
    BEFORE INSERT OR UPDATE OF injured_id_number ON accident_reports FOR EACH ROW
    EXECUTE FUNCTION trg_normalize_injured_id_number();

-- Normalize injury_disease_reports.worker_id_number
CREATE OR REPLACE FUNCTION trg_normalize_worker_id_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.worker_id_number := normalize_identity_id(NEW.worker_id_number);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS normalize_worker_id ON injury_disease_reports;
CREATE TRIGGER normalize_worker_id
    BEFORE INSERT OR UPDATE OF worker_id_number ON injury_disease_reports FOR EACH ROW
    EXECUTE FUNCTION trg_normalize_worker_id_number();

-- Normalize injury_claims.claimant_id_number
CREATE OR REPLACE FUNCTION trg_normalize_claimant_id_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.claimant_id_number := normalize_identity_id(NEW.claimant_id_number);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS normalize_claimant_id ON injury_claims;
CREATE TRIGGER normalize_claimant_id
    BEFORE INSERT OR UPDATE OF claimant_id_number ON injury_claims FOR EACH ROW
    EXECUTE FUNCTION trg_normalize_claimant_id_number();

-- Normalize workers_registry.id_number
CREATE OR REPLACE FUNCTION trg_normalize_registry_id_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.id_number := normalize_identity_id(NEW.id_number);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS normalize_registry_id ON workers_registry;
CREATE TRIGGER normalize_registry_id
    BEFORE INSERT OR UPDATE OF id_number ON workers_registry FOR EACH ROW
    EXECUTE FUNCTION trg_normalize_registry_id_number();

-- ── 8g. Claim file number functions ──────────────────────────
CREATE OR REPLACE FUNCTION format_comp_claim_file_number(
    p_claimant_id TEXT,
    p_sequence    INTEGER,
    p_when        DATE DEFAULT CURRENT_DATE
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT format(
        'OHS/COMP/%s/%s/%s',
        normalize_identity_id(p_claimant_id),
        p_sequence::TEXT,
        to_char(COALESCE(p_when, CURRENT_DATE), 'YY')
    );
$$;

COMMENT ON FUNCTION format_comp_claim_file_number(TEXT, INTEGER, DATE) IS
    'Builds OHS/COMP/{claimant_id}/{sequence}/{YY} claim file number';

CREATE OR REPLACE FUNCTION comp_claim_sequence_for(p_claimant_id TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_id    TEXT := normalize_identity_id(p_claimant_id);
    v_count INTEGER;
BEGIN
    IF v_id IS NULL THEN RETURN 1; END IF;
    SELECT COUNT(*)::INTEGER INTO v_count
    FROM injury_claims
    WHERE normalize_identity_id(claimant_id_number) = v_id
      AND status NOT IN ('draft', 'cancelled');
    RETURN v_count + 1;
END;
$$;

CREATE OR REPLACE FUNCTION preview_comp_claim_file_number(p_claimant_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    IF normalize_identity_id(p_claimant_id) IS NULL THEN RETURN NULL; END IF;
    RETURN format_comp_claim_file_number(
        p_claimant_id,
        comp_claim_sequence_for(p_claimant_id),
        CURRENT_DATE
    );
END;
$$;

CREATE OR REPLACE FUNCTION generate_comp_claim_file_number(p_claimant_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id  TEXT := normalize_identity_id(p_claimant_id);
    v_seq INTEGER;
BEGIN
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Claimant Omang or passport number is required for file number';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtext('osh_comp_' || v_id));
    v_seq := comp_claim_sequence_for(v_id);
    RETURN format_comp_claim_file_number(v_id, v_seq, CURRENT_DATE);
END;
$$;

CREATE OR REPLACE FUNCTION injury_claims_assign_file_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.status IN ('draft', 'cancelled') THEN RETURN NEW; END IF;
    IF NEW.file_number IS NULL OR btrim(NEW.file_number) = '' THEN
        IF NEW.claimant_id_number IS NULL OR btrim(NEW.claimant_id_number) = '' THEN
            RAISE EXCEPTION 'Claimant ID is required to generate file number';
        END IF;
        NEW.file_number := generate_comp_claim_file_number(NEW.claimant_id_number);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_injury_claims_file_number ON injury_claims;
CREATE TRIGGER trg_injury_claims_file_number
    BEFORE INSERT OR UPDATE OF status, file_number, claimant_id_number ON injury_claims
    FOR EACH ROW
    EXECUTE FUNCTION injury_claims_assign_file_number();

-- ── 8h. Helper role/permission functions ──────────────────────
CREATE OR REPLACE FUNCTION get_user_role(user_uuid UUID)
RETURNS TEXT AS $$
    SELECT role FROM user_profiles WHERE user_id = user_uuid;
$$ LANGUAGE SQL SECURITY DEFINER;

CREATE OR REPLACE FUNCTION current_user_role()
RETURNS TEXT AS $$
    SELECT role FROM user_profiles WHERE user_id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER;

CREATE OR REPLACE FUNCTION has_permission(permission_name TEXT)
RETURNS BOOLEAN AS $$
    SELECT COALESCE((permissions->permission_name)::boolean, false)
    FROM user_roles_info
    WHERE role = (SELECT role FROM user_profiles WHERE user_id = auth.uid());
$$ LANGUAGE SQL SECURITY DEFINER;

-- ── 8i. Statistics functions ─────────────────────────────────
CREATE OR REPLACE FUNCTION get_claim_statistics()
RETURNS TABLE (
    total_claims      BIGINT,
    pending_claims    BIGINT,
    approved_claims   BIGINT,
    rejected_claims   BIGINT,
    avg_incapacity    NUMERIC,
    claims_this_month BIGINT,
    claims_this_year  BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT,
        COUNT(CASE WHEN status = 'pending' THEN 1 END)::BIGINT,
        COUNT(CASE WHEN status = 'approved' THEN 1 END)::BIGINT,
        COUNT(CASE WHEN status = 'rejected' THEN 1 END)::BIGINT,
        AVG(incapacity_percentage),
        COUNT(CASE WHEN created_at >= DATE_TRUNC('month', NOW()) THEN 1 END)::BIGINT,
        COUNT(CASE WHEN created_at >= DATE_TRUNC('year', NOW()) THEN 1 END)::BIGINT
    FROM injury_claims;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_inspection_statistics()
RETURNS TABLE (
    total_inspections        BIGINT,
    inspections_this_month   BIGINT,
    inspections_this_quarter BIGINT,
    avg_compliance_pct       NUMERIC,
    follow_ups_pending       BIGINT,
    total_factories_visited  BIGINT,
    total_registered         BIGINT,
    total_not_registered     BIGINT
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
--  SECTION 9 — VIEWS
-- ============================================================

-- ── 9a. Active users summary ────────────────────────────────
CREATE OR REPLACE VIEW active_users_summary AS
SELECT
    up.department,
    d.name as department_name,
    COUNT(*) as total_users,
    COUNT(CASE WHEN up.is_active THEN 1 END) as active_users
FROM user_profiles up
LEFT JOIN departments d ON up.department = d.code
GROUP BY up.department, d.name;

-- ── 9b. Recent login activity ───────────────────────────────
CREATE OR REPLACE VIEW recent_login_activity AS
SELECT
    lh.id,
    up.first_name || ' ' || up.surname as full_name,
    up.email,
    up.department,
    lh.login_time,
    lh.logout_time,
    lh.session_duration,
    lh.login_successful
FROM login_history lh
JOIN user_profiles up ON lh.user_id = up.user_id
ORDER BY lh.login_time DESC
LIMIT 100;

-- ── 9c. Accident report view (with submitter name) ──────────
CREATE OR REPLACE VIEW accident_report_view AS
SELECT
    ar.id, ar.report_type, ar.occupier_name, ar.premises_address,
    ar.nature_of_industry, ar.industry_sector, ar.injured_name,
    ar.injured_age, ar.injured_sex, ar.accident_date, ar.accident_place,
    ar.injury_fatal, ar.investigation_status, ar.causation_number,
    ar.reporter_name, ar.report_date, ar.status, ar.created_at,
    up.first_name || ' ' || up.surname AS submitted_by_name
FROM accident_reports ar
LEFT JOIN user_profiles up ON ar.submitted_by = up.user_id
ORDER BY ar.accident_date DESC NULLS LAST;

-- ── 9d. Accident statistics ──────────────────────────────────
CREATE OR REPLACE VIEW accident_statistics AS
SELECT
    COUNT(*)                                           AS total_reports,
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

-- ── 9e. Injury claims summary ────────────────────────────────
CREATE OR REPLACE VIEW injury_claims_summary AS
SELECT
    status,
    COUNT(*) as total_claims,
    AVG(incapacity_percentage) as avg_incapacity,
    MIN(date_of_injury) as earliest_injury,
    MAX(date_of_injury) as latest_injury
FROM injury_claims
GROUP BY status;

-- ── 9f. Claims by industry ───────────────────────────────────
CREATE OR REPLACE VIEW injury_claims_by_industry AS
SELECT
    industry,
    COUNT(*) as total_claims,
    AVG(incapacity_percentage) as avg_incapacity,
    COUNT(CASE WHEN status = 'approved' THEN 1 END) as approved_claims,
    COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected_claims,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_claims
FROM injury_claims
GROUP BY industry
ORDER BY total_claims DESC;

-- ── 9g. Recent injury claims ─────────────────────────────────
CREATE OR REPLACE VIEW recent_injury_claims AS
SELECT
    ic.id, ic.file_number, ic.name_of_employer, ic.name_of_claimant,
    ic.date_of_injury, ic.incapacity_percentage, ic.status, ic.created_at,
    up.first_name || ' ' || up.surname as submitted_by_name
FROM injury_claims ic
LEFT JOIN user_profiles up ON ic.submitted_by = up.user_id
ORDER BY ic.created_at DESC
LIMIT 100;

-- ── 9h. Claims requiring attention ───────────────────────────
CREATE OR REPLACE VIEW claims_requiring_attention AS
SELECT
    ic.id, ic.file_number, ic.name_of_employer, ic.name_of_claimant,
    ic.date_of_injury, ic.status, ic.created_at,
    EXTRACT(DAY FROM NOW() - ic.created_at) as days_pending
FROM injury_claims ic
WHERE ic.status = 'pending' AND ic.created_at < NOW() - INTERVAL '7 days'
ORDER BY ic.created_at ASC;

-- ── 9i. Injury / disease report view ─────────────────────────
CREATE OR REPLACE VIEW injury_disease_report_view AS
SELECT
    idr.id, idr.worker_name, idr.occupation, idr.incident_date,
    idr.incident_type, idr.place_of_accident, idr.resulted_death,
    idr.permanent_incapacity, idr.temporary_incapacity, idr.employer_name,
    idr.report_date, idr.status, idr.created_at,
    up.first_name || ' ' || up.surname AS submitted_by_name
FROM injury_disease_reports idr
LEFT JOIN user_profiles up ON idr.submitted_by = up.user_id
ORDER BY idr.incident_date DESC NULLS LAST;

-- ── 9j. Injury / disease statistics ──────────────────────────
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

-- ── 9k. Inspection report view ───────────────────────────────
CREATE OR REPLACE VIEW inspection_report_view AS
SELECT
    wi.id, wi.file_number, wi.inspection_date, wi.date_report_sent,
    wi.days_to_respond, wi.factory_name, wi.location, wi.nature_of_work,
    wi.industry_type, wi.registration_status, wi.inspection_type,
    wi.employees_male, wi.employees_female,
    wi.employees_foreign_male, wi.employees_foreign_female,
    (wi.employees_male + wi.employees_female + wi.employees_foreign_male + wi.employees_foreign_female) AS total_employees,
    wi.inspector_name, wi.total_contraventions, wi.non_compliance_pct,
    wi.compliance_level, wi.contraventions, wi.action_taken,
    wi.follow_up_required, wi.follow_up_date, wi.status, wi.created_at,
    up.first_name || ' ' || up.surname AS submitted_by_name
FROM workplace_inspections wi
LEFT JOIN user_profiles up ON wi.submitted_by = up.user_id
ORDER BY wi.inspection_date DESC;

-- ── 9l. Inspection monthly summary ──────────────────────────
CREATE OR REPLACE VIEW inspection_monthly_summary AS
SELECT
    TO_CHAR(inspection_date, 'YYYY-MM')          AS month,
    TO_CHAR(inspection_date, 'Month YYYY')       AS month_label,
    industry_type,
    COUNT(*)                                     AS total_inspections,
    COUNT(*) FILTER (WHERE inspection_type = 'Routine')   AS routine,
    COUNT(*) FILTER (WHERE inspection_type = 'Follow-up') AS follow_up,
    COUNT(*) FILTER (WHERE inspection_type = 'Query')     AS query,
    SUM(employees_male)                           AS total_male,
    SUM(employees_female)                         AS total_female,
    SUM(employees_foreign_male)                   AS total_foreign_male,
    SUM(employees_foreign_female)                 AS total_foreign_female,
    SUM(employees_male + employees_female + employees_foreign_male + employees_foreign_female) AS total_employees,
    ROUND(AVG(compliance_level), 1)              AS avg_compliance_pct,
    SUM(total_contraventions)                    AS total_contraventions,
    COUNT(*) FILTER (WHERE registration_status = 'Yes') AS registered,
    COUNT(*) FILTER (WHERE registration_status = 'No')  AS not_registered
FROM workplace_inspections
GROUP BY TO_CHAR(inspection_date, 'YYYY-MM'),
         TO_CHAR(inspection_date, 'Month YYYY'), industry_type
ORDER BY month DESC, industry_type;

-- ── 9m. Inspector performance summary ───────────────────────
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

-- ── 9n. Contravention frequency ─────────────────────────────
CREATE OR REPLACE VIEW contravention_frequency AS
SELECT
    section_id,
    COUNT(*) AS times_breached,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM workplace_inspections), 1) AS breach_rate_pct
FROM workplace_inspections,
     UNNEST(contraventions) AS section_id
GROUP BY section_id
ORDER BY times_breached DESC;

-- ── 9o. Inspections pending follow-up ────────────────────────
CREATE OR REPLACE VIEW inspections_pending_followup AS
SELECT
    id, file_number, factory_name, location, inspection_date,
    follow_up_date, inspector_name, compliance_level, action_taken
FROM workplace_inspections
WHERE follow_up_required = TRUE AND status != 'closed'
ORDER BY follow_up_date ASC NULLS LAST;

-- ── 9p. Company register view (aggregated) ──────────────────
CREATE OR REPLACE VIEW company_register_view AS
WITH companies AS (
    SELECT company_name AS company_name, industry AS industry
    FROM companies WHERE company_name IS NOT NULL AND company_name != ''
    UNION
    SELECT occupier_name, industry_sector
    FROM accident_reports WHERE occupier_name IS NOT NULL AND occupier_name != ''
    UNION
    SELECT factory_name, industry_type
    FROM workplace_inspections WHERE factory_name IS NOT NULL AND factory_name != ''
    UNION
    SELECT employer_name, NULL::TEXT
    FROM injury_disease_reports WHERE employer_name IS NOT NULL AND employer_name != ''
    UNION
    SELECT name_of_employer, industry
    FROM injury_claims WHERE name_of_employer IS NOT NULL AND name_of_employer != ''
)
SELECT
    c.company_name, c.industry,
    COUNT(DISTINCT ar.id)                                   AS accident_count,
    COUNT(DISTINCT ar.id) FILTER (WHERE ar.injury_fatal = 'Fatal') AS fatal_accidents,
    COUNT(DISTINCT ar.id) FILTER (WHERE ar.report_type = 'dangerous_occurrence') AS dangerous_occurrences,
    MAX(ar.accident_date)                                   AS last_accident_date,
    COUNT(DISTINCT wi.id)                                   AS inspection_count,
    ROUND(AVG(wi.compliance_level)::NUMERIC, 1)             AS avg_compliance_level,
    MAX(wi.inspection_date)                                 AS last_inspection_date,
    COUNT(DISTINCT wi.id) FILTER (WHERE wi.follow_up_required = TRUE) AS follow_ups_required,
    SUM(wi.employees_male + wi.employees_female)             AS total_employees,
    COUNT(DISTINCT idr.id)                                  AS injury_disease_count,
    COUNT(DISTINCT idr.id) FILTER (WHERE idr.incident_type = 'Disease') AS disease_count,
    COUNT(DISTINCT idr.id) FILTER (WHERE idr.resulted_death = 'Yes')    AS idr_fatalities,
    MAX(idr.incident_date)                                  AS last_idr_date,
    COUNT(DISTINCT ic.id)                                   AS claim_count,
    COUNT(DISTINCT ic.id) FILTER (WHERE ic.status = 'draft')   AS draft_claims,
    COUNT(DISTINCT ic.id) FILTER (WHERE ic.status = 'approved') AS approved_claims,
    (COUNT(DISTINCT ar.id) + COUNT(DISTINCT idr.id))        AS total_incidents,
    (COUNT(DISTINCT ar.id) FILTER (WHERE ar.injury_fatal = 'Fatal')
     + COUNT(DISTINCT idr.id) FILTER (WHERE idr.resulted_death = 'Yes')) AS total_fatalities,
    LEAST(MIN(ar.accident_date), MIN(wi.inspection_date), MIN(idr.incident_date), MIN(ic.date_of_injury)) AS first_activity_date,
    GREATEST(MAX(ar.accident_date), MAX(wi.inspection_date), MAX(idr.incident_date), MAX(ic.date_of_injury)) AS last_activity_date
FROM companies c
LEFT JOIN accident_reports ar         ON ar.occupier_name    = c.company_name
LEFT JOIN workplace_inspections wi    ON wi.factory_name     = c.company_name
LEFT JOIN injury_disease_reports idr  ON idr.employer_name   = c.company_name
LEFT JOIN injury_claims ic            ON ic.name_of_employer = c.company_name
GROUP BY c.company_name, c.industry
ORDER BY c.company_name ASC;

COMMENT ON VIEW company_register_view IS
    'Aggregated company register — combines accidents, inspections, injury/disease reports, and compensation claims per company';

-- ============================================================
--  SECTION 10 — WORKER IDENTITY SEARCH RPC
-- ============================================================

CREATE OR REPLACE FUNCTION search_workers_by_identity(
    search_query  TEXT,
    result_limit  INT DEFAULT 15
)
RETURNS TABLE (
    worker_key      TEXT,
    full_name       TEXT,
    id_number       TEXT,
    id_type         TEXT,
    occupation      TEXT,
    employer_name   TEXT,
    match_kind      TEXT,
    source_table    TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    q_raw   TEXT := btrim(COALESCE(search_query, ''));
    q_upper TEXT := normalize_identity_id(search_query);
    q_pat   TEXT;
    lim     INT := LEAST(GREATEST(COALESCE(result_limit, 15), 1), 50);
BEGIN
    IF length(q_raw) < 2 THEN RETURN; END IF;
    q_pat := '%' || q_raw || '%';

    RETURN QUERY
    WITH hits AS (
        SELECT COALESCE(w.id_number, w.full_name) AS worker_key,
               w.full_name, w.id_number, w.id_type::TEXT,
               w.occupation, w.employer_name,
               CASE WHEN w.id_number ILIKE q_pat THEN 'id'
                    WHEN w.full_name ILIKE q_pat THEN 'name' ELSE 'both' END,
               'workers_registry'::TEXT
        FROM workers_registry w
        WHERE w.full_name ILIKE q_pat OR w.id_number ILIKE q_pat OR (q_upper IS NOT NULL AND w.id_number = q_upper)
        UNION ALL
        SELECT COALESCE(ar.injured_id_number, ar.injured_name),
               ar.injured_name, ar.injured_id_number, NULL::TEXT,
               ar.occupation_at_accident, ar.occupier_name,
               CASE WHEN ar.injured_id_number ILIKE q_pat OR (q_upper IS NOT NULL AND ar.injured_id_number = q_upper) THEN 'id'
                    WHEN ar.injured_name ILIKE q_pat THEN 'name' ELSE 'both' END,
               'accident_reports'::TEXT
        FROM accident_reports ar
        WHERE ar.injured_name ILIKE q_pat OR ar.injured_id_number ILIKE q_pat OR (q_upper IS NOT NULL AND ar.injured_id_number = q_upper)
        UNION ALL
        SELECT COALESCE(idr.worker_id_number, idr.worker_name),
               idr.worker_name, idr.worker_id_number, NULL::TEXT,
               idr.occupation, idr.employer_name,
               CASE WHEN idr.worker_id_number ILIKE q_pat OR (q_upper IS NOT NULL AND idr.worker_id_number = q_upper) THEN 'id'
                    WHEN idr.worker_name ILIKE q_pat THEN 'name' ELSE 'both' END,
               'injury_disease_reports'::TEXT
        FROM injury_disease_reports idr
        WHERE idr.worker_name ILIKE q_pat OR idr.worker_id_number ILIKE q_pat OR (q_upper IS NOT NULL AND idr.worker_id_number = q_upper)
        UNION ALL
        SELECT COALESCE(ic.claimant_id_number, ic.name_of_claimant),
               ic.name_of_claimant, ic.claimant_id_number, NULL::TEXT,
               ic.industry, ic.name_of_employer,
               CASE WHEN ic.claimant_id_number ILIKE q_pat OR (q_upper IS NOT NULL AND ic.claimant_id_number = q_upper) THEN 'id'
                    WHEN ic.name_of_claimant ILIKE q_pat THEN 'name' ELSE 'both' END,
               'injury_claims'::TEXT
        FROM injury_claims ic
        WHERE ic.name_of_claimant ILIKE q_pat OR ic.claimant_id_number ILIKE q_pat OR (q_upper IS NOT NULL AND ic.claimant_id_number = q_upper)
    ),
    ranked AS (
        SELECT DISTINCT ON (COALESCE(h.id_number, h.full_name))
            h.worker_key, h.full_name, h.id_number, h.id_type, h.occupation, h.employer_name, h.match_kind, h.source_table
        FROM hits h
        WHERE h.full_name IS NOT NULL OR h.id_number IS NOT NULL
        ORDER BY COALESCE(h.id_number, h.full_name),
                 CASE h.match_kind WHEN 'id' THEN 0 WHEN 'both' THEN 1 ELSE 2 END,
                 h.full_name
    )
    SELECT r.worker_key, r.full_name, r.id_number, r.id_type, r.occupation, r.employer_name, r.match_kind, r.source_table
    FROM ranked r LIMIT lim;
END;
$$;

COMMENT ON FUNCTION search_workers_by_identity(TEXT, INT) IS
    'Worker profile autocomplete: search by name, Omang, or passport across registry and report tables';

-- ============================================================
--  SECTION 11 — GRANTS & PERMISSIONS
-- ============================================================

GRANT USAGE ON SEQUENCE departments_id_seq TO authenticated;

-- Core tables
GRANT SELECT, INSERT, UPDATE ON user_profiles              TO authenticated;
GRANT SELECT, INSERT       ON login_history                TO authenticated;
GRANT SELECT, INSERT       ON password_reset_requests      TO authenticated;
GRANT SELECT, INSERT       ON user_activity_log            TO authenticated;
GRANT SELECT               ON departments                  TO authenticated;
GRANT SELECT               ON user_roles_info              TO authenticated;
GRANT SELECT               ON role_change_log              TO authenticated;

-- Feature tables
GRANT SELECT, INSERT, UPDATE ON companies                   TO authenticated;
GRANT SELECT, INSERT, UPDATE ON accident_reports            TO authenticated;
GRANT SELECT, INSERT, UPDATE ON injury_claims               TO authenticated;
GRANT SELECT, INSERT, UPDATE ON injury_disease_reports      TO authenticated;
GRANT SELECT, INSERT, UPDATE ON workplace_inspections       TO authenticated;
GRANT SELECT, INSERT, UPDATE ON workers_registry            TO authenticated;
GRANT SELECT, INSERT       ON inspection_bookings           TO authenticated;
GRANT UPDATE               ON inspection_bookings           TO authenticated;
GRANT SELECT, INSERT, UPDATE ON medical_examination_reports TO authenticated;

-- Views
GRANT SELECT ON accident_report_view       TO authenticated;
GRANT SELECT ON accident_statistics        TO authenticated;
GRANT SELECT ON injury_claims_summary      TO authenticated;
GRANT SELECT ON injury_claims_by_industry  TO authenticated;
GRANT SELECT ON recent_injury_claims       TO authenticated;
GRANT SELECT ON claims_requiring_attention TO authenticated;
GRANT SELECT ON injury_disease_report_view TO authenticated;
GRANT SELECT ON injury_disease_statistics  TO authenticated;
GRANT SELECT ON inspection_report_view     TO authenticated;
GRANT SELECT ON inspection_monthly_summary TO authenticated;
GRANT SELECT ON inspection_inspector_summary TO authenticated;
GRANT SELECT ON contravention_frequency    TO authenticated;
GRANT SELECT ON inspections_pending_followup TO authenticated;
GRANT SELECT ON company_register_view      TO authenticated;

-- Functions
GRANT EXECUTE ON FUNCTION preview_comp_claim_file_number(TEXT)   TO authenticated;
GRANT EXECUTE ON FUNCTION generate_comp_claim_file_number(TEXT)  TO authenticated;
GRANT EXECUTE ON FUNCTION search_workers_by_identity(TEXT, INT)  TO authenticated;

-- ============================================================
--  SECTION 12 — BACKFILL SCRIPTS (One-time fixes)
--     Note: These are safe to run multiple times.
--     They update existing records to ensure data consistency
--     without affecting new records.
-- ============================================================

-- ── 12a. Backfill normalized ID numbers ────────────────────
UPDATE accident_reports
SET injured_id_number = normalize_identity_id(injured_id_number)
WHERE injured_id_number IS NOT NULL
  AND injured_id_number IS DISTINCT FROM normalize_identity_id(injured_id_number);

UPDATE injury_disease_reports
SET worker_id_number = normalize_identity_id(worker_id_number)
WHERE worker_id_number IS NOT NULL
  AND worker_id_number IS DISTINCT FROM normalize_identity_id(worker_id_number);

UPDATE injury_claims
SET claimant_id_number = normalize_identity_id(claimant_id_number)
WHERE claimant_id_number IS NOT NULL
  AND claimant_id_number IS DISTINCT FROM normalize_identity_id(claimant_id_number);

UPDATE workers_registry
SET id_number = normalize_identity_id(id_number)
WHERE id_number IS DISTINCT FROM normalize_identity_id(id_number);

-- ── 12b. Backfill compliance totals for workplace_inspections ──
-- Sets individual boolean columns from the contraventions array
UPDATE workplace_inspections
SET
    s9  = ('S9'  = ANY(contraventions)),
    s13 = ('S13' = ANY(contraventions)),
    s14 = ('S14' = ANY(contraventions)),
    s15 = ('S15' = ANY(contraventions)),
    s16 = ('S16' = ANY(contraventions)),
    s18 = ('S18' = ANY(contraventions)),
    s41 = ('S41' = ANY(contraventions)),
    s42 = ('S42' = ANY(contraventions)),
    s46 = ('S46' = ANY(contraventions)),
    s47 = ('S47' = ANY(contraventions)),
    s48 = ('S48' = ANY(contraventions)),
    s49 = ('S49' = ANY(contraventions)),
    s52 = ('S52' = ANY(contraventions)),
    s53 = ('S53' = ANY(contraventions)),
    s62 = ('S62' = ANY(contraventions)),
    s66 = ('S66' = ANY(contraventions)),
    s67 = ('S67' = ANY(contraventions)),
    s17 = ('S17' = ANY(contraventions)),
    s23 = ('S23' = ANY(contraventions)),
    s29 = ('S29' = ANY(contraventions)),
    s30 = ('S30' = ANY(contraventions)),
    s31 = ('S31' = ANY(contraventions)),
    s32 = ('S32' = ANY(contraventions)),
    s34 = ('S34' = ANY(contraventions)),
    s37 = ('S37' = ANY(contraventions)),
    s38 = ('S38' = ANY(contraventions)),
    s39 = ('S39' = ANY(contraventions)),
    s51 = ('S51' = ANY(contraventions)),
    s54 = ('S54' = ANY(contraventions)),
    s57 = ('S57' = ANY(contraventions)),
    s58 = ('S58' = ANY(contraventions))
WHERE contraventions IS NOT NULL AND array_length(contraventions, 1) > 0;

-- Recompute totals from boolean columns
UPDATE workplace_inspections
SET
    total_contraventions = (
        s9::int + s13::int + s14::int + s15::int + s16::int + s18::int +
        s41::int + s42::int + s46::int + s47::int + s48::int + s49::int +
        s52::int + s53::int + s62::int + s66::int + s67::int
    ),
    non_compliance_pct = ROUND(
        (s9::int + s13::int + s14::int + s15::int + s16::int + s18::int +
         s41::int + s42::int + s46::int + s47::int + s48::int + s49::int +
         s52::int + s53::int + s62::int + s66::int + s67::int)::NUMERIC / 17 * 100
    ),
    compliance_level = 100 - ROUND(
        (s9::int + s13::int + s14::int + s15::int + s16::int + s18::int +
         s41::int + s42::int + s46::int + s47::int + s48::int + s49::int +
         s52::int + s53::int + s62::int + s66::int + s67::int)::NUMERIC / 17 * 100
    );

-- ============================================================
--  VERIFICATION
-- ============================================================

SELECT '✅ Master setup completed successfully!' AS status;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'departments', 'user_profiles', 'login_history', 'password_reset_requests',
    'user_activity_log', 'user_roles_info', 'role_change_log',
    'companies', 'accident_reports', 'injury_claims', 'injury_disease_reports',
    'workplace_inspections', 'workers_registry', 'inspection_bookings',
    'medical_examination_reports'
  )
ORDER BY table_name;
