-- =============================================================================
-- RLS Policy Fixes - Security Audit
-- Run this in Supabase SQL Editor
-- =============================================================================
BEGIN;

-- Fix accident_reports RLS (was USING(true))
DROP POLICY IF EXISTS "All users can view accident reports" ON accident_reports;
DROP POLICY IF EXISTS "Users can view own company accidents" ON accident_reports;
CREATE POLICY "Users can view own company accidents"
ON accident_reports FOR SELECT TO authenticated
USING (
  EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer'))
  OR submitted_by = auth.uid()
);

-- Fix injury_claims RLS (was USING(true))
DROP POLICY IF EXISTS "All users can view claims" ON injury_claims;
DROP POLICY IF EXISTS "Users can view own claims" ON injury_claims;
CREATE POLICY "Users can view own claims"
ON injury_claims FOR SELECT TO authenticated
USING (
  EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer'))
  OR submitted_by = auth.uid()
);

-- Fix injury_disease_reports RLS
DROP POLICY IF EXISTS "Users can view own injury reports" ON injury_disease_reports;
CREATE POLICY "Users can view own injury reports"
ON injury_disease_reports FOR SELECT TO authenticated
USING (
  EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer'))
  OR submitted_by = auth.uid()
);

-- Restrict medical_examination_reports INSERT
DROP POLICY IF EXISTS "Medical practitioners can insert" ON medical_examination_reports;
CREATE POLICY "Medical practitioners can insert"
ON medical_examination_reports FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('medical_practitioner','admin','super_admin','officer'))
);

-- Add missing RLS for ohs_form_19
ALTER TABLE ohs_form_19 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view form 19" ON ohs_form_19;
CREATE POLICY "Users can view form 19"
ON ohs_form_19 FOR SELECT TO authenticated
USING (
  EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer'))
  OR submitted_by = auth.uid()
);
DROP POLICY IF EXISTS "Users can insert form 19" ON ohs_form_19;
CREATE POLICY "Users can insert form 19"
ON ohs_form_19 FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (SELECT 1 FROM user_profiles WHERE user_id = auth.uid() AND role IN ('admin','super_admin','officer'))
);

GRANT ALL ON ohs_form_19 TO authenticated;

COMMIT;
