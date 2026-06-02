-- ============================================================
-- WORKERS REGISTRY TABLE
-- Central identity store keyed on Omang / Passport number
-- Used for autofill across all claim, accident & injury forms
-- ============================================================

CREATE TABLE IF NOT EXISTS workers_registry (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- ── Identity (unique key) ────────────────────────────────
    id_number       TEXT NOT NULL UNIQUE,   -- Omang or Passport number
    id_type         TEXT NOT NULL DEFAULT 'Omang'
                    CHECK (id_type IN ('Omang','Passport')),

    -- ── Personal details ─────────────────────────────────────
    full_name       TEXT NOT NULL,
    date_of_birth   DATE,
    sex             TEXT CHECK (sex IN ('Male','Female')),
    nationality     TEXT,
    address         TEXT,

    -- ── Employment details ────────────────────────────────────
    occupation      TEXT,
    employer_name   TEXT,
    employer_address TEXT,
    employer_telephone TEXT,

    -- ── Metadata ─────────────────────────────────────────────
    created_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE workers_registry IS
    'Central worker identity registry keyed on Omang/Passport — used for autofill across all forms';
COMMENT ON COLUMN workers_registry.id_number IS
    'Omang (national ID) for citizens or Passport number for foreigners — must be unique';

-- ── Indexes ───────────────────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS idx_wr_id_number  ON workers_registry(id_number);
CREATE INDEX IF NOT EXISTS idx_wr_full_name         ON workers_registry(full_name);
CREATE INDEX IF NOT EXISTS idx_wr_employer          ON workers_registry(employer_name);
CREATE INDEX IF NOT EXISTS idx_wr_created_at        ON workers_registry(created_at DESC);

-- Full-text search index on name
CREATE INDEX IF NOT EXISTS idx_wr_name_trgm
    ON workers_registry USING GIN (to_tsvector('english', full_name));

-- ── Updated-at trigger ────────────────────────────────────────
DROP TRIGGER IF EXISTS update_workers_registry_updated_at ON workers_registry;
CREATE TRIGGER update_workers_registry_updated_at
    BEFORE UPDATE ON workers_registry
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE workers_registry ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view (needed for lookup/autofill)
CREATE POLICY "All authenticated users can view workers registry"
    ON workers_registry FOR SELECT
    TO authenticated USING (true);

-- Officers and above can insert new workers
CREATE POLICY "Officers and above can insert workers"
    ON workers_registry FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('officer','admin','super_admin')
        )
    );

-- Officers can update workers they created; admins can update any
CREATE POLICY "Officers update own workers, admins update all"
    ON workers_registry FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = created_by
        OR EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('admin','super_admin')
        )
    );

-- ── Add id_number columns to existing form tables ─────────────
-- (Ensures all form records can reference back to the registry)

ALTER TABLE accident_reports
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID
        REFERENCES workers_registry(id) ON DELETE SET NULL;

ALTER TABLE injury_disease_reports
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID
        REFERENCES workers_registry(id) ON DELETE SET NULL;

ALTER TABLE injury_claims
    ADD COLUMN IF NOT EXISTS claimant_id_number  TEXT,
    ADD COLUMN IF NOT EXISTS worker_registry_id  UUID
        REFERENCES workers_registry(id) ON DELETE SET NULL;

-- Indexes for the new FK columns
CREATE INDEX IF NOT EXISTS idx_ar_worker_reg    ON accident_reports(worker_registry_id);
CREATE INDEX IF NOT EXISTS idx_idr_worker_reg   ON injury_disease_reports(worker_registry_id);
CREATE INDEX IF NOT EXISTS idx_ic_worker_reg    ON injury_claims(worker_registry_id);
CREATE INDEX IF NOT EXISTS idx_ic_id_number     ON injury_claims(claimant_id_number);

-- ── Grants ───────────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE ON workers_registry TO authenticated;

-- ── Verify ───────────────────────────────────────────────────
SELECT 'workers_registry table created and existing tables updated!' AS status;

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'workers_registry'
ORDER BY ordinal_position;
