-- ============================================================
-- Migration: Create claim_documents table
-- Run this in your Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- 1. Create the claim_documents table
CREATE TABLE IF NOT EXISTS claim_documents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  worker_id_number TEXT NOT NULL,
  employer_name TEXT DEFAULT '',
  item_number INTEGER NOT NULL,
  item_label TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'uploaded', 'detected')),
  -- File upload fields
  file_name TEXT,
  file_path TEXT,
  file_size BIGINT,
  content_type TEXT,
  -- Auto-detection tracking
  auto_detected BOOLEAN DEFAULT false,
  source_table TEXT,
  source_record_id UUID,
  -- Metadata
  uploaded_at TIMESTAMPTZ DEFAULT NOW(),
  uploaded_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable Row Level Security
ALTER TABLE claim_documents ENABLE ROW LEVEL SECURITY;

-- 3. Create policies
CREATE POLICY "Users can view claim documents"
  ON claim_documents FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert claim documents"
  ON claim_documents FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own documents"
  ON claim_documents FOR UPDATE
  USING (auth.uid() = uploaded_by);

-- 4. Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_claim_docs_worker ON claim_documents(worker_id_number);
CREATE INDEX IF NOT EXISTS idx_claim_docs_item ON claim_documents(worker_id_number, item_number);
