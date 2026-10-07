-- ============================================================
-- Migration: Add evidence_files jsonb column to ohs_form_19
-- Stores uploaded evidence references (photos, witness statements,
-- documentary exhibits) attached to each investigation record.
--
-- Run in Supabase SQL Editor. Safe to re-run.
-- ============================================================

ALTER TABLE public.ohs_form_19
  ADD COLUMN IF NOT EXISTS evidence_files jsonb DEFAULT '[]'::jsonb;

-- Optional: index is not useful for jsonb containment on this small table,
-- but a note for future use if filtering by evidence becomes needed.
-- CREATE INDEX IF NOT EXISTS idx_ohs19_evidence_files
--   ON public.ohs_form_19 USING GIN (evidence_files);
