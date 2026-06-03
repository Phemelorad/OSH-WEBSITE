-- ============================================================
-- Auto claim file number: OHS/COMP/{id}/{seq}/{YY}
-- Example: OHS/COMP/113224608/249/26
--   OHS/COMP  — fixed prefix
--   id        — claimant Omang or passport (uppercase)
--   seq       — nth claim for that claimant in the database (1, 2, … 249)
--   YY        — 2-digit year when the claim is filed (26 = 2026)
-- Run in Supabase SQL Editor
-- ============================================================

CREATE OR REPLACE FUNCTION public.normalize_claimant_id(p TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN p IS NULL OR btrim(p) = '' THEN NULL
        ELSE upper(btrim(p))
    END;
$$;

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
    IF v_id IS NULL THEN
        RETURN 1;
    END IF;

    SELECT COUNT(*)::INTEGER
    INTO v_count
    FROM injury_claims
    WHERE public.normalize_claimant_id(claimant_id_number) = v_id
      AND status NOT IN ('draft', 'cancelled');

    RETURN v_count + 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.format_comp_claim_file_number(
    p_claimant_id TEXT,
    p_sequence    INTEGER,
    p_when        DATE DEFAULT CURRENT_DATE
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT format(
        'OHS/COMP/%s/%s/%s',
        public.normalize_claimant_id(p_claimant_id),
        p_sequence::TEXT,
        to_char(COALESCE(p_when, CURRENT_DATE), 'YY')
    );
$$;

COMMENT ON FUNCTION public.format_comp_claim_file_number(TEXT, INTEGER, DATE) IS
    'Builds OHS/COMP/{claimant_id}/{sequence}/{YY} claim file number';

-- Preview next number (safe to call from the form; does not reserve a slot)
CREATE OR REPLACE FUNCTION public.preview_comp_claim_file_number(p_claimant_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    IF public.normalize_claimant_id(p_claimant_id) IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN public.format_comp_claim_file_number(
        p_claimant_id,
        public.comp_claim_sequence_for(p_claimant_id),
        CURRENT_DATE
    );
END;
$$;

-- Allocate number on insert (advisory lock per claimant avoids duplicate seq)
CREATE OR REPLACE FUNCTION public.generate_comp_claim_file_number(p_claimant_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id TEXT := public.normalize_claimant_id(p_claimant_id);
    v_seq INTEGER;
BEGIN
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Claimant Omang or passport number is required for file number';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('osh_comp_' || v_id));

    v_seq := public.comp_claim_sequence_for(v_id);

    RETURN public.format_comp_claim_file_number(v_id, v_seq, CURRENT_DATE);
END;
$$;

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

GRANT EXECUTE ON FUNCTION public.preview_comp_claim_file_number(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_comp_claim_file_number(TEXT) TO authenticated;

COMMENT ON COLUMN injury_claims.file_number IS
    'Auto: OHS/COMP/{claimant_id}/{sequence}/{YY} — sequence = claim count for that ID';

-- Test (optional):
-- SELECT public.preview_comp_claim_file_number('113224608');
