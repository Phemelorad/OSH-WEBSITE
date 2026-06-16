-- ============================================================
-- Migration: Add accident_injured_persons table
-- Allows multiple injured persons per accident report
-- ============================================================

CREATE TABLE IF NOT EXISTS public.accident_injured_persons (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    accident_report_id uuid NOT NULL REFERENCES public.accident_reports(id) ON DELETE CASCADE,

    -- Person details
    full_name text NOT NULL,
    age_years integer,
    sex text CHECK (sex IN ('Male','Female')),
    id_number text,
    occupation_at_accident text,
    usual_occupation text,
    experience_level text,
    email text,

    -- Per-person injury details
    injury_fatal text CHECK (injury_fatal IN ('Fatal','Non-fatal')),
    disabled_three_days text CHECK (disabled_three_days IN ('Yes','No')),
    hourly_pay numeric(10,2),
    medical_practitioner text,

    -- Ordering
    sort_order integer DEFAULT 0,

    -- Tracking
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.accident_injured_persons ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Users can select injured persons on their reports"
    ON public.accident_injured_persons FOR SELECT
    USING (
        accident_report_id IN (
            SELECT id FROM public.accident_reports
            WHERE submitted_by = auth.uid()
        )
    );

CREATE POLICY "Users can insert injured persons on their reports"
    ON public.accident_injured_persons FOR INSERT
    WITH CHECK (
        accident_report_id IN (
            SELECT id FROM public.accident_reports
            WHERE submitted_by = auth.uid()
        )
    );

CREATE POLICY "Users can update injured persons on their reports"
    ON public.accident_injured_persons FOR UPDATE
    USING (
        accident_report_id IN (
            SELECT id FROM public.accident_reports
            WHERE submitted_by = auth.uid()
        )
    );

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_accident_injured_persons_report
    ON public.accident_injured_persons(accident_report_id);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION public.update_accident_injured_persons_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_accident_injured_persons_updated_at
    ON public.accident_injured_persons;

CREATE TRIGGER trg_accident_injured_persons_updated_at
    BEFORE UPDATE ON public.accident_injured_persons
    FOR EACH ROW
    EXECUTE FUNCTION public.update_accident_injured_persons_updated_at();
