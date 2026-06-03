-- ============================================================
-- Claim draft workflow — link incidents to compensation claims
-- Run in Supabase SQL Editor (after claim-file-number.sql)
-- ============================================================

-- Link claim to Form 60 or Form 43/10
ALTER TABLE injury_claims
    ADD COLUMN IF NOT EXISTS source_type TEXT
        CHECK (source_type IS NULL OR source_type IN ('accident', 'injury_disease', 'manual')),
    ADD COLUMN IF NOT EXISTS source_id UUID;

COMMENT ON COLUMN injury_claims.source_type IS 'accident | injury_disease | manual';
COMMENT ON COLUMN injury_claims.source_id IS 'UUID of accident_reports or injury_disease_reports row';

-- Drafts: no file number until submitted
ALTER TABLE injury_claims ALTER COLUMN file_number DROP NOT NULL;

-- Expand status values
ALTER TABLE injury_claims DROP CONSTRAINT IF EXISTS injury_claims_status_check;
ALTER TABLE injury_claims
    ADD CONSTRAINT injury_claims_status_check
    CHECK (status IN (
        'draft', 'pending', 'under_review', 'approved', 'rejected', 'closed', 'cancelled'
    ));

-- One open draft per incident report
CREATE UNIQUE INDEX IF NOT EXISTS idx_claim_one_draft_per_source
    ON injury_claims (source_type, source_id)
    WHERE status = 'draft' AND source_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ic_source ON injury_claims (source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_ic_draft_status ON injury_claims (status) WHERE status = 'draft';

-- Sequence counts only submitted claims (not draft/cancelled)
CREATE OR REPLACE FUNCTION public.comp_claim_sequence_for(p_claimant_id TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_id    TEXT := public.normalize_claimant_id(p_claimant_id);
    v_count INTEGER;
BEGIN
    IF v_id IS NULL THEN RETURN 1; END IF;

    SELECT COUNT(*)::INTEGER INTO v_count
    FROM injury_claims
    WHERE public.normalize_claimant_id(claimant_id_number) = v_id
      AND status NOT IN ('draft', 'cancelled');

    RETURN v_count + 1;
END;
$$;

-- Assign file number on insert/update when leaving draft
CREATE OR REPLACE FUNCTION public.injury_claims_assign_file_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.status IN ('draft', 'cancelled') THEN
        RETURN NEW;
    END IF;

    IF NEW.file_number IS NULL OR btrim(NEW.file_number) = '' THEN
        IF NEW.claimant_id_number IS NULL OR btrim(NEW.claimant_id_number) = '' THEN
            RAISE EXCEPTION 'Claimant ID is required to generate file number';
        END IF;
        NEW.file_number := public.generate_comp_claim_file_number(NEW.claimant_id_number);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_injury_claims_file_number ON injury_claims;
CREATE TRIGGER trg_injury_claims_file_number
    BEFORE INSERT OR UPDATE OF status, file_number, claimant_id_number ON injury_claims
    FOR EACH ROW
    EXECUTE FUNCTION public.injury_claims_assign_file_number();

-- RLS: update own drafts
DROP POLICY IF EXISTS "Users can update own pending claims" ON injury_claims;
CREATE POLICY "Users can update own pending claims"
    ON injury_claims FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = submitted_by
        AND status IN ('pending', 'draft')
    )
    WITH CHECK (auth.uid() = submitted_by);

DROP POLICY IF EXISTS "Officers can cancel own draft claims" ON injury_claims;
CREATE POLICY "Officers can cancel own draft claims"
    ON injury_claims FOR UPDATE
    TO authenticated
    USING (auth.uid() = submitted_by AND status = 'draft')
    WITH CHECK (status = 'cancelled');

SELECT 'claim-draft-workflow applied' AS status;
