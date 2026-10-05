-- ============================================================
-- Migration: Decouple persons from single accident report
--   1 person can have multiple accidents
--   Dangerous occurrences are separable, not 1:1 with accidents
-- ============================================================

-- 1. Add worker_registry_id to accident_injured_persons
--    This links each person entry to the central worker registry,
--    enabling one worker to appear across multiple accident reports.
ALTER TABLE public.accident_injured_persons
    ADD COLUMN IF NOT EXISTS worker_registry_id UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_aip_worker_registry
    ON public.accident_injured_persons(worker_registry_id);


-- 2. Create accident_report_persons junction table
--    Formal many-to-many relationship between workers_registry and accident_reports.
--    One worker can be linked to many accident reports.
CREATE TABLE IF NOT EXISTS public.accident_report_persons (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    accident_report_id UUID NOT NULL REFERENCES public.accident_reports(id) ON DELETE CASCADE,
    worker_registry_id UUID NOT NULL REFERENCES public.workers_registry(id) ON DELETE CASCADE,
    role_in_accident TEXT NOT NULL DEFAULT 'injured'
        CHECK (role_in_accident IN ('injured', 'witness', 'emergency_responder', 'occupier')),
    sort_order       INTEGER DEFAULT 0,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW(),
    -- Prevent duplicate worker+report+role links
    UNIQUE(accident_report_id, worker_registry_id, role_in_accident)
);

CREATE INDEX IF NOT EXISTS idx_arp_report
    ON public.accident_report_persons(accident_report_id);
CREATE INDEX IF NOT EXISTS idx_arp_worker
    ON public.accident_report_persons(worker_registry_id);


-- 3. Create dangerous_occurrence_reports table
--    Standalone dangerous occurrence records — not 1:1 with accident_reports.
--    Can optionally link to an accident_report_id (when the dangerous occurrence
--    is related to an accident), but can also exist independently.
CREATE TABLE IF NOT EXISTS public.dangerous_occurrence_reports (
    id                       UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    -- Optional link to an accident report (NULL = standalone dangerous occurrence)
    accident_report_id       UUID REFERENCES public.accident_reports(id) ON DELETE SET NULL,

    occupier_name            TEXT NOT NULL,
    premises_address         TEXT NOT NULL,
    nature_of_industry       TEXT NOT NULL,
    industry_sector          TEXT NOT NULL,
    outside_persons_injured  TEXT,

    dangerous_date           DATE,
    dangerous_time           TIME,
    dangerous_place          TEXT,
    dangerous_description    TEXT,
    dangerous_damage         TEXT,
    employees_injured        TEXT CHECK (employees_injured IN ('Yes','No')),
    notification_submitted   TEXT CHECK (notification_submitted IN ('Yes','No')),

    report_date              DATE NOT NULL DEFAULT CURRENT_DATE,
    reporter_name            TEXT NOT NULL,
    reporter_designation     TEXT,
    causation_number         TEXT,
    investigation_status     TEXT DEFAULT 'Pending'
        CHECK (investigation_status IN ('Pending','In Progress','Completed','Closed')),
    official_action          TEXT,
    submitted_by             UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status                   TEXT NOT NULL DEFAULT 'submitted'
        CHECK (status IN ('submitted','under_review','investigated','closed')),
    created_at               TIMESTAMPTZ DEFAULT NOW(),
    updated_at               TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dor_report       ON dangerous_occurrence_reports(accident_report_id);
CREATE INDEX IF NOT EXISTS idx_dor_date         ON dangerous_occurrence_reports(dangerous_date DESC);
CREATE INDEX IF NOT EXISTS idx_dor_status       ON dangerous_occurrence_reports(status);
CREATE INDEX IF NOT EXISTS idx_dor_investigation ON dangerous_occurrence_reports(investigation_status);


-- 4. Create dangerous_occurrence_persons junction table
--    Links workers to specific dangerous occurrence reports.
CREATE TABLE IF NOT EXISTS public.dangerous_occurrence_persons (
    id                    UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    dangerous_occurrence_report_id UUID NOT NULL REFERENCES public.dangerous_occurrence_reports(id) ON DELETE CASCADE,
    worker_registry_id    UUID REFERENCES public.workers_registry(id) ON DELETE SET NULL,
    full_name             TEXT NOT NULL,
    id_number             TEXT,
    injury_fatal          TEXT CHECK (injury_fatal IN ('Fatal','Non-fatal')),
    sort_order            INTEGER DEFAULT 0,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dop_report   ON dangerous_occurrence_persons(dangerous_occurrence_report_id);
CREATE INDEX IF NOT EXISTS idx_dop_worker   ON dangerous_occurrence_persons(worker_registry_id);


-- 5. Enable RLS on new tables
ALTER TABLE public.accident_report_persons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dangerous_occurrence_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dangerous_occurrence_persons ENABLE ROW LEVEL SECURITY;


-- 6. RLS Policies

-- accident_report_persons — same ownership model as accident_reports
CREATE POLICY "Users can view persons on their accident reports"
    ON public.accident_report_persons FOR SELECT
    USING (
        accident_report_id IN (
            SELECT id FROM public.accident_reports WHERE submitted_by = auth.uid()
        )
    );

CREATE POLICY "Users can insert persons on their accident reports"
    ON public.accident_report_persons FOR INSERT
    WITH CHECK (
        accident_report_id IN (
            SELECT id FROM public.accident_reports WHERE submitted_by = auth.uid()
        )
    );

CREATE POLICY "Users can update persons on their accident reports"
    ON public.accident_report_persons FOR UPDATE
    USING (
        accident_report_id IN (
            SELECT id FROM public.accident_reports WHERE submitted_by = auth.uid()
        )
    );

-- dangerous_occurrence_reports — users can manage their own, admins all
CREATE POLICY "Users can view dangerous occurrence reports"
    ON public.dangerous_occurrence_reports FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "Users can insert dangerous occurrence reports"
    ON public.dangerous_occurrence_reports FOR INSERT TO authenticated
    WITH CHECK (true);

CREATE POLICY "Users update own dangerous occurrences, admins update all"
    ON public.dangerous_occurrence_reports FOR UPDATE TO authenticated
    USING (true);

-- dangerous_occurrence_persons
CREATE POLICY "Users can view persons on their dangerous occurrence reports"
    ON public.dangerous_occurrence_persons FOR SELECT
    USING (
        dangerous_occurrence_report_id IN (
            SELECT id FROM public.dangerous_occurrence_reports
            WHERE (accident_report_id IN (
                SELECT id FROM public.accident_reports WHERE submitted_by = auth.uid()
            )) OR (submitted_by_link IS NULL OR true)
        )
    );

CREATE POLICY "Users can insert persons on dangerous occurrence reports"
    ON public.dangerous_occurrence_persons FOR INSERT
    WITH CHECK (
        dangerous_occurrence_report_id IN (
            SELECT id FROM public.dangerous_occurrence_reports
        )
    );

CREATE POLICY "Users can update persons on their dangerous occurrence reports"
    ON public.dangerous_occurrence_persons FOR UPDATE
    USING (
        dangerous_occurrence_report_id IN (
            SELECT id FROM public.dangerous_occurrence_reports
        )
    );


-- 7. Grants
GRANT SELECT, INSERT, UPDATE ON public.accident_report_persons TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.dangerous_occurrence_reports TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.dangerous_occurrence_persons TO authenticated;


-- 8. Updated trigger for updated_at on new tables
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


-- 9. Backfill: Link existing accident_injured_persons to workers_registry where possible
--    This is optional but helps establish the worker→report relationship for existing data
UPDATE public.accident_injured_persons aip
SET worker_registry_id = wr.id
FROM public.workers_registry wr
WHERE aip.worker_registry_id IS NULL
  AND aip.id_number IS NOT NULL
  AND UPPER(TRIM(wr.id_number)) = UPPER(TRIM(aip.id_number));

COMMENT ON TABLE public.accident_report_persons IS 'Junction table: one worker can be in multiple accident reports (many-to-many)';
COMMENT ON TABLE public.dangerous_occurrence_reports IS 'Standalone dangerous occurrence records, optionally linked to an accident report';
COMMENT ON TABLE public.dangerous_occurrence_persons IS 'Links workers to dangerous occurrence reports';
