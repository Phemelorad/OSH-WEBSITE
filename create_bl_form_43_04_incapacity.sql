-- Create table for BL Form 43/04B - Compensation in Cases of Incapacity
-- Run this in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS bl_form_43_04_incapacity (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- Worker & Employer Details
  worker_name TEXT,
  worker_address TEXT,
  employer_name TEXT,
  accident_date DATE,

  -- Section A: Permanent Total Incapacity
  pt_earnings NUMERIC(12,2),
  pt_multiplier INTEGER DEFAULT 60,
  pt_compensation NUMERIC(12,2),

  -- Section B: Permanent Partial Incapacity
  pp_earnings NUMERIC(12,2),
  pp_multiplier INTEGER DEFAULT 60,
  pp_percentage NUMERIC(5,2),
  pp_compensation NUMERIC(12,2),

  -- Section C: Temporary Incapacity
  t_earnings_before NUMERIC(12,2),
  t_earnings_during NUMERIC(12,2),
  t_compensation NUMERIC(12,2),

  -- Declaration & Signature
  declaration_date DATE,
  signature TEXT,

  -- CC: Worker
  cc_worker_name TEXT,
  cc_worker_address TEXT,

  -- Submitted by (OSH user)
  submitted_by UUID REFERENCES auth.users(id)
);

-- Enable Row Level Security
ALTER TABLE bl_form_43_04_incapacity ENABLE ROW LEVEL SECURITY;

-- Admins and officers can view all submissions
CREATE POLICY "Admins can view all"
  ON bl_form_43_04_incapacity FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role IN ('admin', 'super_admin')
    )
  );

-- Authenticated users can insert
CREATE POLICY "Authenticated users can insert"
  ON bl_form_43_04_incapacity FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Users can view their own submissions
CREATE POLICY "Users can view own submissions"
  ON bl_form_43_04_incapacity FOR SELECT
  USING (submitted_by = auth.uid());

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_bl_form_43_04_submitted_by
  ON bl_form_43_04_incapacity(submitted_by);

CREATE INDEX IF NOT EXISTS idx_bl_form_43_04_created_at
  ON bl_form_43_04_incapacity(created_at DESC);


-- Auto-update updated_at on row modification
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bl_form_43_04_updated_at
  BEFORE UPDATE ON bl_form_43_04_incapacity
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
