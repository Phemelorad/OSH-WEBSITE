-- ============================================================
--  PRE-MIGRATION: Add missing columns to existing tables
--  ============================================================
--  Run this FIRST in Supabase SQL Editor (standalone).
--  Then run master-setup.sql after.
--  Uses IF EXISTS for safety — tables that don't exist yet
--  will be created by master-setup.sql.
--  ============================================================

ALTER TABLE IF EXISTS departments
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS is_active   BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW();

ALTER TABLE IF EXISTS user_profiles
    ADD COLUMN IF NOT EXISTS company_id    UUID,
    ADD COLUMN IF NOT EXISTS role          TEXT DEFAULT 'viewer',
    ADD COLUMN IF NOT EXISTS designation   TEXT,
    ADD COLUMN IF NOT EXISTS last_sign_in  TIMESTAMPTZ;

ALTER TABLE IF EXISTS companies
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

ALTER TABLE IF EXISTS accident_reports
    ADD COLUMN IF NOT EXISTS injured_id_number TEXT,
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID;

ALTER TABLE IF EXISTS injury_disease_reports
    ADD COLUMN IF NOT EXISTS worker_id_number TEXT,
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID;

ALTER TABLE IF EXISTS injury_claims
    ADD COLUMN IF NOT EXISTS gender TEXT,
    ADD COLUMN IF NOT EXISTS claimant_id_number TEXT,
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID,
    ADD COLUMN IF NOT EXISTS source_type TEXT,
    ADD COLUMN IF NOT EXISTS source_id UUID;

-- Workplace inspections (missing employees_foreign cols, contraventions, plant_machinery, etc.)
ALTER TABLE IF EXISTS workplace_inspections
    ADD COLUMN IF NOT EXISTS employees_foreign_male   INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS employees_foreign_female INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS contraventions        TEXT[],
    ADD COLUMN IF NOT EXISTS plant_machinery       JSONB,
    ADD COLUMN IF NOT EXISTS s17 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s23 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s29 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s30 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s31 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s32 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s34 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s37 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s38 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s39 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s51 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s54 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s57 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS s58 BOOLEAN DEFAULT FALSE;

-- Inspection bookings (missing status/scheduling columns)
ALTER TABLE IF EXISTS inspection_bookings
    ADD COLUMN IF NOT EXISTS assigned_inspector  TEXT,
    ADD COLUMN IF NOT EXISTS scheduled_date      DATE,
    ADD COLUMN IF NOT EXISTS scheduled_time      TEXT,
    ADD COLUMN IF NOT EXISTS admin_notes         TEXT;

SELECT '✅ Pre-migration completed successfully!' AS status;
