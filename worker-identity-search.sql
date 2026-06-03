-- ============================================================
-- WORKER IDENTITY SEARCH — Supabase setup
-- Run this entire script in: Supabase Dashboard → SQL Editor
--
-- Prepares the database for worker profile lookup by:
--   • Name (full / partial)
--   • Omang (national ID)
--   • Passport number (same TEXT field as Omang on forms)
--
-- Includes: column docs, uppercase normalization, search indexes,
--           and RPC search_workers_by_identity() for the app.
-- ============================================================

-- ── 1. Extensions (fast partial / ilike search) ───────────────
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ── 2. Column documentation (identity fields) ───────────────
COMMENT ON COLUMN accident_reports.injured_id_number IS
    'Worker Omang or passport — searchable; stored UPPER(TRIM); links to workers_registry.id_number';

COMMENT ON COLUMN injury_disease_reports.worker_id_number IS
    'Worker Omang or passport — searchable; stored UPPER(TRIM); links to workers_registry.id_number';

COMMENT ON COLUMN injury_claims.claimant_id_number IS
    'Claimant Omang or passport — searchable; stored UPPER(TRIM)';

COMMENT ON COLUMN workers_registry.id_number IS
    'Primary identity key: Omang or passport — unique, searchable, UPPER(TRIM)';

COMMENT ON COLUMN workers_registry.id_type IS
    'Omang = national ID citizen; Passport = foreign national — set at registration';

-- Ensure registry exists (safe if already run workers-registry-table.sql)
CREATE TABLE IF NOT EXISTS workers_registry (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    id_number       TEXT NOT NULL UNIQUE,
    id_type         TEXT NOT NULL DEFAULT 'Omang'
                    CHECK (id_type IN ('Omang','Passport')),
    full_name       TEXT NOT NULL,
    date_of_birth   DATE,
    sex             TEXT CHECK (sex IN ('Male','Female')),
    nationality     TEXT,
    address         TEXT,
    occupation      TEXT,
    employer_name   TEXT,
    employer_address TEXT,
    employer_telephone TEXT,
    created_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE accident_reports
    ADD COLUMN IF NOT EXISTS injured_id_number TEXT;

ALTER TABLE injury_disease_reports
    ADD COLUMN IF NOT EXISTS worker_id_number TEXT;

ALTER TABLE injury_claims
    ADD COLUMN IF NOT EXISTS claimant_id_number TEXT;

-- ── 3. Normalize ID text on write (consistent lookups) ───────
CREATE OR REPLACE FUNCTION public.normalize_identity_id(val TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN val IS NULL OR btrim(val) = '' THEN NULL
        ELSE upper(btrim(val))
    END;
$$;

COMMENT ON FUNCTION public.normalize_identity_id(TEXT) IS
    'Trims and uppercases Omang/passport values for indexed search';

CREATE OR REPLACE FUNCTION public.trg_normalize_injured_id_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.injured_id_number := public.normalize_identity_id(NEW.injured_id_number);
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_normalize_worker_id_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.worker_id_number := public.normalize_identity_id(NEW.worker_id_number);
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_normalize_claimant_id_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.claimant_id_number := public.normalize_identity_id(NEW.claimant_id_number);
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_normalize_registry_id_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.id_number := public.normalize_identity_id(NEW.id_number);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS normalize_injured_id ON accident_reports;
CREATE TRIGGER normalize_injured_id
    BEFORE INSERT OR UPDATE OF injured_id_number ON accident_reports
    FOR EACH ROW EXECUTE FUNCTION public.trg_normalize_injured_id_number();

DROP TRIGGER IF EXISTS normalize_worker_id ON injury_disease_reports;
CREATE TRIGGER normalize_worker_id
    BEFORE INSERT OR UPDATE OF worker_id_number ON injury_disease_reports
    FOR EACH ROW EXECUTE FUNCTION public.trg_normalize_worker_id_number();

DROP TRIGGER IF EXISTS normalize_claimant_id ON injury_claims;
CREATE TRIGGER normalize_claimant_id
    BEFORE INSERT OR UPDATE OF claimant_id_number ON injury_claims
    FOR EACH ROW EXECUTE FUNCTION public.trg_normalize_claimant_id_number();

DROP TRIGGER IF EXISTS normalize_registry_id ON workers_registry;
CREATE TRIGGER normalize_registry_id
    BEFORE INSERT OR UPDATE OF id_number ON workers_registry
    FOR EACH ROW EXECUTE FUNCTION public.trg_normalize_registry_id_number();

-- Backfill existing rows (run once)
UPDATE accident_reports
SET injured_id_number = public.normalize_identity_id(injured_id_number)
WHERE injured_id_number IS NOT NULL
  AND injured_id_number IS DISTINCT FROM public.normalize_identity_id(injured_id_number);

UPDATE injury_disease_reports
SET worker_id_number = public.normalize_identity_id(worker_id_number)
WHERE worker_id_number IS NOT NULL
  AND worker_id_number IS DISTINCT FROM public.normalize_identity_id(worker_id_number);

UPDATE injury_claims
SET claimant_id_number = public.normalize_identity_id(claimant_id_number)
WHERE claimant_id_number IS NOT NULL
  AND claimant_id_number IS DISTINCT FROM public.normalize_identity_id(claimant_id_number);

UPDATE workers_registry
SET id_number = public.normalize_identity_id(id_number)
WHERE id_number IS DISTINCT FROM public.normalize_identity_id(id_number);

-- ── 4. Search indexes (name + ID / passport) ──────────────────

-- B-tree on normalized ID (exact / prefix)
CREATE INDEX IF NOT EXISTS idx_ar_injured_id_number
    ON accident_reports (injured_id_number)
    WHERE injured_id_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ar_injured_name
    ON accident_reports (injured_name)
    WHERE injured_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_idr_worker_id_number
    ON injury_disease_reports (worker_id_number)
    WHERE worker_id_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ic_claimant_id_number
    ON injury_claims (claimant_id_number)
    WHERE claimant_id_number IS NOT NULL;

-- Trigram GIN (supports ilike '%query%' from worker-profile.html)
CREATE INDEX IF NOT EXISTS idx_ar_injured_id_trgm
    ON accident_reports USING GIN (injured_id_number gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_ar_injured_name_trgm
    ON accident_reports USING GIN (injured_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_idr_worker_id_trgm
    ON injury_disease_reports USING GIN (worker_id_number gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_idr_worker_name_trgm
    ON injury_disease_reports USING GIN (worker_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_ic_claimant_id_trgm
    ON injury_claims USING GIN (claimant_id_number gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_wr_id_number_trgm
    ON workers_registry USING GIN (id_number gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_wr_full_name_trgm
    ON workers_registry USING GIN (full_name gin_trgm_ops);

-- ── 5. RPC: unified worker identity search ────────────────────
-- Call from Supabase JS:
--   supabase.rpc('search_workers_by_identity', { search_query: '123456', result_limit: 10 })
--
CREATE OR REPLACE FUNCTION public.search_workers_by_identity(
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
    match_kind      TEXT,   -- 'id' | 'name' | 'both'
    source_table    TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    q_raw   TEXT := btrim(COALESCE(search_query, ''));
    q_upper TEXT := public.normalize_identity_id(search_query);
    q_pat   TEXT;
    lim     INT := LEAST(GREATEST(COALESCE(result_limit, 15), 1), 50);
BEGIN
    IF length(q_raw) < 2 THEN
        RETURN;
    END IF;

    q_pat := '%' || q_raw || '%';

    RETURN QUERY
    WITH hits AS (
        -- Central registry
        SELECT
            COALESCE(w.id_number, w.full_name) AS worker_key,
            w.full_name,
            w.id_number,
            w.id_type::TEXT,
            w.occupation,
            w.employer_name,
            CASE
                WHEN w.id_number ILIKE q_pat THEN 'id'
                WHEN w.full_name ILIKE q_pat THEN 'name'
                ELSE 'both'
            END AS match_kind,
            'workers_registry'::TEXT AS source_table
        FROM workers_registry w
        WHERE w.full_name ILIKE q_pat
           OR w.id_number ILIKE q_pat
           OR (q_upper IS NOT NULL AND w.id_number = q_upper)

        UNION ALL

        -- Accident reports (Form 60)
        SELECT
            COALESCE(ar.injured_id_number, ar.injured_name) AS worker_key,
            ar.injured_name,
            ar.injured_id_number,
            NULL::TEXT,
            ar.occupation_at_accident,
            ar.occupier_name,
            CASE
                WHEN ar.injured_id_number ILIKE q_pat OR (q_upper IS NOT NULL AND ar.injured_id_number = q_upper) THEN 'id'
                WHEN ar.injured_name ILIKE q_pat THEN 'name'
                ELSE 'both'
            END,
            'accident_reports'::TEXT
        FROM accident_reports ar
        WHERE ar.injured_name ILIKE q_pat
           OR ar.injured_id_number ILIKE q_pat
           OR (q_upper IS NOT NULL AND ar.injured_id_number = q_upper)

        UNION ALL

        -- Injury / disease reports (Form 43/10)
        SELECT
            COALESCE(idr.worker_id_number, idr.worker_name) AS worker_key,
            idr.worker_name,
            idr.worker_id_number,
            NULL::TEXT,
            idr.occupation,
            idr.employer_name,
            CASE
                WHEN idr.worker_id_number ILIKE q_pat OR (q_upper IS NOT NULL AND idr.worker_id_number = q_upper) THEN 'id'
                WHEN idr.worker_name ILIKE q_pat THEN 'name'
                ELSE 'both'
            END,
            'injury_disease_reports'::TEXT
        FROM injury_disease_reports idr
        WHERE idr.worker_name ILIKE q_pat
           OR idr.worker_id_number ILIKE q_pat
           OR (q_upper IS NOT NULL AND idr.worker_id_number = q_upper)

        UNION ALL

        -- Injury claims (when claimant_id_number column exists)
        SELECT
            COALESCE(ic.claimant_id_number, ic.name_of_claimant) AS worker_key,
            ic.name_of_claimant,
            ic.claimant_id_number,
            NULL::TEXT,
            ic.industry,
            ic.name_of_employer,
            CASE
                WHEN ic.claimant_id_number ILIKE q_pat OR (q_upper IS NOT NULL AND ic.claimant_id_number = q_upper) THEN 'id'
                WHEN ic.name_of_claimant ILIKE q_pat THEN 'name'
                ELSE 'both'
            END,
            'injury_claims'::TEXT
        FROM injury_claims ic
        WHERE ic.name_of_claimant ILIKE q_pat
           OR ic.claimant_id_number ILIKE q_pat
           OR (q_upper IS NOT NULL AND ic.claimant_id_number = q_upper)
    ),
    ranked AS (
        SELECT DISTINCT ON (COALESCE(h.id_number, h.full_name))
            h.worker_key,
            h.full_name,
            h.id_number,
            h.id_type,
            h.occupation,
            h.employer_name,
            h.match_kind,
            h.source_table
        FROM hits h
        WHERE h.full_name IS NOT NULL OR h.id_number IS NOT NULL
        ORDER BY
            COALESCE(h.id_number, h.full_name),
            CASE h.match_kind WHEN 'id' THEN 0 WHEN 'both' THEN 1 ELSE 2 END,
            h.full_name
    )
    SELECT
        r.worker_key,
        r.full_name,
        r.id_number,
        r.id_type,
        r.occupation,
        r.employer_name,
        r.match_kind,
        r.source_table
    FROM ranked r
    LIMIT lim;
END;
$$;

COMMENT ON FUNCTION public.search_workers_by_identity(TEXT, INT) IS
    'Worker profile autocomplete: search by name, Omang, or passport across registry and report tables';

GRANT EXECUTE ON FUNCTION public.search_workers_by_identity(TEXT, INT) TO authenticated;

-- ── 6. RLS on workers_registry (if not already applied) ───────
ALTER TABLE workers_registry ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "All authenticated users can view workers registry" ON workers_registry;
CREATE POLICY "All authenticated users can view workers registry"
    ON workers_registry FOR SELECT
    TO authenticated USING (true);

GRANT SELECT ON workers_registry TO authenticated;

-- ── 7. Verify ─────────────────────────────────────────────────
SELECT 'worker-identity-search applied' AS status;

SELECT indexname, tablename
FROM pg_indexes
WHERE indexname IN (
    'idx_ar_injured_id_number',
    'idx_idr_worker_id_number',
    'idx_wr_id_number_trgm'
)
ORDER BY tablename, indexname;

-- Test RPC (replace with a real ID or name from your data):
-- SELECT * FROM public.search_workers_by_identity('smith', 5);
