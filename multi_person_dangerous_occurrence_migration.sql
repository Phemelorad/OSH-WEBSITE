-- ============================================================
-- Migration: Multi-person accidents + decoupled dangerous occurrences
--
-- Goals:
--   1. One worker (person) can appear in MULTIPLE accident reports
--      (many-to-many via accident_report_persons junction table)
--   2. Dangerous occurrences are NOT 1:1 with accidents
--      (standalone dangerous_occurrence_reports table, optionally
--       linked to an accident_report_id but can exist independently)
--   3. Workers can be linked to multiple dangerous occurrences
--      (many-to-many via dangerous_occurrence_persons junction table)
--
-- Run in Supabase Dashboard → SQL Editor
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Link accident_injured_persons to workers_registry
--    This is the per-report person record. The worker_registry_id
--    column enables backward/forward tracing to the central worker
--    registry, so the same worker can appear across many reports.
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.accident_injured_persons
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID
        REFERENCES public.workers_registry(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_aip_worker_registry
    ON public.accident_injured_persons(worker_registry_id);

-- ────────────────────────────────────────────────────────────
-- 2. Junction table: accident_report_persons
--    Formal many-to-many between workers_registry and accident_reports.
--    One worker can be linked to MANY accident reports.
--    A person can play different roles (injured, witness, etc.)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.accident_report_persons (
    id                 UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    accident_report_id UUID NOT NULL
        REFERENCES public.accident_reports(id) ON DELETE CASCADE,
    worker_registry_id UUID NOT NULL
        REFERENCES public.workers_registry(id) ON DELETE CASCADE,
    role_in_accident   TEXT NOT NULL DEFAULT 'injured'
        CHECK (role_in_accident IN
            ('injured','witness','emergency_responder','occupier')),
    sort_order         INTEGER DEFAULT 0,
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ DEFAULT NOW(),
    -- Prevent duplicate worker+report+role links
    UNIQUE(accident_report_id, worker_registry_id, role_in_accident)
);

CREATE INDEX IF NOT EXISTS idx_arp_report  ON public.accident_report_persons(accident_report_id);
CREATE INDEX IF NOT EXISTS idx_arp_worker  ON public.accident_report_persons(worker_registry_id);

-- ────────────────────────────────────────────────────────────
-- 3. Standalone table: dangerous_occurrence_reports
--    NOT 1:1 with accident_reports. Can exist independently
--    (accident_report_id IS NULL) or optionally link to an
--    accident report (when report_type = 'both').
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.dangerous_occurrence_reports (
    id                      UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    -- Optional link to an accident report.
    -- NULL = standalone dangerous occurrence (no associated accident)
    accident_report_id      UUID REFERENCES public.accident_reports(id) ON DELETE SET NULL,

    -- Reporter / location fields
    occupier_name           TEXT NOT NULL,
    premises_address        TEXT NOT NULL,
    nature_of_industry      TEXT NOT NULL,
    industry_sector         TEXT NOT NULL
        CHECK (industry_sector IN
            ('Manufacturing','Services','Construction','Agriculture','Transport','Retail','Government','Parastatal')),

    -- Dangerous occurrence details
    outside_persons_injured TEXT,
    dangerous_date          DATE,
    dangerous_time          TIME,
    dangerous_place         TEXT,
    dangerous_description   TEXT,
    dangerous_damage        TEXT,
    employees_injured       TEXT CHECK (employees_injured IN ('Yes','No')),
    notification_submitted  TEXT CHECK (notification_submitted IN ('Yes','No')),

    -- Administrative fields
    report_date             DATE NOT NULL DEFAULT CURRENT_DATE,
    reporter_name           TEXT NOT NULL,
    reporter_designation    TEXT,
    causation_number        TEXT,
    investigation_status    TEXT DEFAULT 'Pending'
        CHECK (investigation_status IN ('Pending','In Progress','Completed','Closed')),
    official_action         TEXT,
    submitted_by            UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status                  TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('submitted','under_review','investigated','closed')),
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dor_accident   ON public.dangerous_occurrence_reports(accident_report_id);
CREATE INDEX IF NOT EXISTS idx_dor_date       ON public.dangerous_occurrence_reports(dangerous_date DESC);
CREATE INDEX IF NOT EXISTS idx_dor_status     ON public.dangerous_occurrence_reports(status);
CREATE INDEX IF NOT EXISTS idx_dor_investig   ON public.dangerous_occurrence_reports(investigation_status);

-- ────────────────────────────────────────────────────────────
-- 4. Junction table: dangerous_occurrence_persons
--    Links workers to specific dangerous occurrence reports.
--    Many-to-many: one worker can be in many dangerous occurrences,
--    one dangerous occurrence can involve many workers.
--    worker_registry_id can be NULL when the person is not in the
--    central registry (e.g., outside person).
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.dangerous_occurrence_persons (
    id                            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    dangerous_occurrence_report_id UUID NOT NULL
        REFERENCES public.dangerous_occurrence_reports(id) ON DELETE CASCADE,
    worker_registry_id            UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    full_name                     TEXT NOT NULL,
    id_number                     TEXT,
    injury_fatal                  TEXT CHECK (injury_fatal IN ('Fatal','Non-fatal')),
    sort_order                    INTEGER DEFAULT 0,
    created_at                    TIMESTAMPTZ DEFAULT NOW(),
    updated_at                    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dop_report ON public.dangerous_occurrence_persons(dangerous_occurrence_report_id);
CREATE INDEX IF NOT EXISTS idx_dop_worker ON public.dangerous_occurrence_persons(worker_registry_id);

-- ────────────────────────────────────────────────────────────
-- 5. Enable Row Level Security on all new tables
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.accident_report_persons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dangerous_occurrence_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dangerous_occurrence_persons ENABLE ROW LEVEL SECURITY;

-- ────────────────────────────────────────────────────────────
-- 6. RLS Policies
--    Pattern follows the existing accident_reports / workers_registry
--    model in COMPILED_DATABASE.sql:
--      - Officers and above can view everything
--      - Users can view their own submissions
-- └─ accident_injured_persons already has:
--      "Users can view their own or linked persons"
-- ────────────────────────────────────────────────────────────

-- accident_report_persons:
-- Persons visible if the user owns the accident report OR is an officer/admin/super_admin
DROP POLICY IF EXISTS "arp_select"     ON public.accident_report_persons;
DROP POLICY IF EXISTS "arp_insert"     ON public.accident_report_persons;
DROP POLICY IF EXISTS "arp_update"     ON public.accident_report_persons;
DROP POLICY IF EXISTS "arp_delete"     ON public.accident_report_persons;

CREATE POLICY "arp_select"
    ON public.accident_report_persons FOR SELECT TO authenticated
    USING (
        accident_report_id IN (
            SELECT id FROM public.accident_reports
            WHERE submitted_by = auth.uid()
               OR EXISTS (SELECT 1 FROM public.user_profiles
                          WHERE user_id = auth.uid()
                          AND role IN ('admin','super_admin','officer'))
        )
    );

CREATE POLICY "arp_insert"
    ON public.accident_report_persons FOR INSERT TO authenticated
    WITH CHECK (
        accident_report_id IN (
            SELECT id FROM public.accident_reports
            WHERE submitted_by = auth.uid()
        )
    );

CREATE POLICY "arp_update"
    ON public.accident_report_persons FOR UPDATE TO authenticated
    USING (
        accident_report_id IN (
            SELECT id FROM public.accident_reports
            WHERE submitted_by = auth.uid()
               OR EXISTS (SELECT 1 FROM public.user_profiles
                          WHERE user_id = auth.uid()
                          AND role IN ('admin','super_admin','officer'))
        )
    );

CREATE POLICY "arp_delete"
    ON public.accident_report_persons FOR DELETE TO authenticated
    USING (
        accident_report_id IN (
            SELECT id FROM public.accident_reports
            WHERE submitted_by = auth.uid()
        )
    );

-- dangerous_occurrence_reports:
-- Users can view all (like accident_reports), insert if officer+, update own or if admin
DROP POLICY IF EXISTS "dor_select"     ON public.dangerous_occurrence_reports;
DROP POLICY IF EXISTS "dor_insert"     ON public.dangerous_occurrence_reports;
DROP POLICY IF EXISTS "dor_update"     ON public.dangerous_occurrence_reports;

CREATE POLICY "dor_select"
    ON public.dangerous_occurrence_reports FOR SELECT TO authenticated
    USING (
        (accident_report_id IN (
            SELECT id FROM public.accident_reports
            WHERE submitted_by = auth.uid()
               OR EXISTS (SELECT 1 FROM public.user_profiles
                          WHERE user_id = auth.uid()
                          AND role IN ('admin','super_admin','officer'))
        ))
        OR submitted_by = auth.uid()
        OR EXISTS (SELECT 1 FROM public.user_profiles
                   WHERE user_id = auth.uid()
                   AND role IN ('admin','super_admin','officer'))
    );

CREATE POLICY "dor_insert"
    ON public.dangerous_occurrence_reports FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.user_profiles
                WHERE user_id = auth.uid()
                AND role IN ('officer','admin','super_admin'))
    );

CREATE POLICY "dor_update"
    ON public.dangerous_occurrence_reports FOR UPDATE TO authenticated
    USING (
        submitted_by = auth.uid()
        OR EXISTS (SELECT 1 FROM public.user_profiles
                   WHERE user_id = auth.uid()
                   AND role IN ('admin','super_admin'))
    );

-- dangerous_occurrence_persons:
-- Visible if the associated dangerous occurrence report is visible to the user
DROP POLICY IF EXISTS "dop_select"     ON public.dangerous_occurrence_persons;
DROP POLICY IF EXISTS "dop_insert"     ON public.dangerous_occurrence_persons;
DROP POLICY IF EXISTS "dop_update"     ON public.dangerous_occurrence_persons;

CREATE POLICY "dop_select"
    ON public.dangerous_occurrence_persons FOR SELECT TO authenticated
    USING (
        dangerous_occurrence_report_id IN (
            SELECT id FROM public.dangerous_occurrence_reports
            WHERE accident_report_id IN (
                SELECT id FROM public.accident_reports
                WHERE submitted_by = auth.uid()
                   OR EXISTS (SELECT 1 FROM public.user_profiles
                              WHERE user_id = auth.uid()
                              AND role IN ('admin','super_admin','officer'))
            )
            OR submitted_by = auth.uid()
            OR EXISTS (SELECT 1 FROM public.user_profiles
                       WHERE user_id = auth.uid()
                       AND role IN ('admin','super_admin','officer'))
        )
    );

CREATE POLICY "dop_insert"
    ON public.dangerous_occurrence_persons FOR INSERT TO authenticated
    WITH CHECK (
        dangerous_occurrence_report_id IN (
            SELECT id FROM public.dangerous_occurrence_reports
        )
    );

CREATE POLICY "dop_update"
    ON public.dangerous_occurrence_persons FOR UPDATE TO authenticated
    USING (
        dangerous_occurrence_report_id IN (
            SELECT id FROM public.dangerous_occurrence_reports
            WHERE accident_report_id IN (
                SELECT id FROM public.accident_reports
                WHERE submitted_by = auth.uid()
                   OR EXISTS (SELECT 1 FROM public.user_profiles
                              WHERE user_id = auth.uid()
                              AND role IN ('admin','super_admin','officer'))
            )
            OR submitted_by = auth.uid()
            OR EXISTS (SELECT 1 FROM public.user_profiles
                       WHERE user_id = auth.uid()
                       AND role IN ('admin','super_admin','officer'))
        )
    );

-- ────────────────────────────────────────────────────────────
-- 7. Grants (match existing patterns)
-- ────────────────────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE ON public.accident_report_persons TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.accident_report_persons TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.dangerous_occurrence_reports TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.dangerous_occurrence_persons TO authenticated;

-- ────────────────────────────────────────────────────────────
-- 8. updated_at triggers
--    Reuses the existing public.update_timestamp() function.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_timestamp()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_arp_updated_at ON public.accident_report_persons;
CREATE TRIGGER trg_arp_updated_at
    BEFORE UPDATE ON public.accident_report_persons
    FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

DROP TRIGGER IF EXISTS trg_dor_updated_at ON public.dangerous_occurrence_reports;
CREATE TRIGGER trg_dor_updated_at
    BEFORE UPDATE ON public.dangerous_occurrence_reports
    FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

DROP TRIGGER IF EXISTS trg_dop_updated_at ON public.dangerous_occurrence_persons;
CREATE TRIGGER trg_dop_updated_at
    BEFORE UPDATE ON public.dangerous_occurrence_persons
    FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

-- ────────────────────────────────────────────────────────────
-- 9. Backfill: link existing accident_injured_persons to
--    workers_registry via id_number matching where possible.
--    This is optional but helps establish the multi-person
--    relationship for existing data.
-- ────────────────────────────────────────────────────────────

-- Preview how many person records can be matched to workers
SELECT COUNT(*) AS matched_persons
FROM public.accident_injured_persons aip
INNER JOIN public.workers_registry wr
    ON UPPER(TRIM(wr.id_number)) = UPPER(TRIM(aip.id_number))
WHERE aip.worker_registry_id IS NULL
  AND aip.id_number IS NOT NULL;

-- Perform the backfill
UPDATE public.accident_injured_persons aip
SET worker_registry_id = wr.id
FROM public.workers_registry wr
WHERE aip.worker_registry_id IS NULL
  AND aip.id_number IS NOT NULL
  AND UPPER(TRIM(wr.id_number)) = UPPER(TRIM(aip.id_number));

-- ────────────────────────────────────────────────────────────
-- 10. Helpful views for inspection
-- ────────────────────────────────────────────────────────────

-- View: all persons who appear in accident reports (via junction + direct entries)
CREATE OR REPLACE VIEW public.accident_report_persons_view AS
SELECT
    arp.id,
    arp.accident_report_id,
    arp.worker_registry_id,
    wr.full_name,
    wr.id_number,
    wr.sex,
    wr.age_years,
    wr.occupation,
    wr.usual_occupation,
    wr.experience_level,
    wr.email,
    arp.role_in_accident,
    arp.sort_order,
    arp.created_at
FROM public.accident_report_persons arp
LEFT JOIN public.workers_registry wr ON wr.id = arp.worker_registry_id
ORDER BY arp.accident_report_id, arp.sort_order;

-- View: standalone dangerous occurrences with their linked persons
CREATE OR REPLACE VIEW public.dangerous_occurrence_full_view AS
SELECT
    dor.id                      AS dangerous_occurrence_id,
    dor.accident_report_id,
    dor.dangerous_date,
    dor.dangerous_time,
    dor.dangerous_place,
    dor.dangerous_description,
    dor.dangerous_damage,
    dor.employees_injured,
    dor.notification_submitted,
    dor.outside_persons_injured,
    dor.status,
    dor.investigation_status,
    dor.report_date,
    dor.reporter_name,
    dor.reporter_designation,
    ar.accident_case_number,
    ar.accident_date,
    ar.accident_time,
    ar.accident_place,
    ar.accident_description,
    dop.id              AS person_id,
    dop.worker_registry_id,
    dop.full_name       AS person_name,
    dop.id_number       AS person_id_number,
    dop.injury_fatal,
    dop.sort_order      AS person_sort_order
FROM public.dangerous_occurrence_reports dor
LEFT JOIN public.accident_reports ar ON ar.id = dor.accident_report_id
LEFT JOIN public.dangerous_occurrence_persons dop ON dop.dangerous_occurrence_report_id = dor.id
ORDER BY dor.dangerous_date DESC, dop.sort_order;

COMMENT ON TABLE public.accident_report_persons IS 'Junction: one worker can appear in multiple accident reports (many-to-many)';
COMMENT ON TABLE public.dangerous_occurrence_reports IS 'Standalone dangerous occurrence records, NOT 1:1 with accident_reports';
COMMENT ON TABLE public.dangerous_occurrence_persons IS 'Links workers to dangerous occurrence reports (many-to-many)';
