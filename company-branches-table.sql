-- ============================================================
--  company_branches — register a company's branch locations
--  Run in Supabase Dashboard → SQL Editor
--  Idempotent (safe to run multiple times).
-- ============================================================

-- ── 1. Table ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.company_branches (
    id             uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id     uuid        NOT NULL,
    branch_no      text        NOT NULL,
    branch_name    text        NOT NULL,
    plot_number    text,
    street_name    text,
    physical_address text,
    is_active      boolean     NOT NULL DEFAULT true,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT company_branches_pkey PRIMARY KEY (id),
    CONSTRAINT company_branches_company_id_fkey
        FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE,

    -- A company can't have two branches with the same branch_no
    CONSTRAINT company_branches_company_branch_no_key
        UNIQUE (company_id, branch_no)
);

-- ── 2. Indexes ────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_company_branches_company_id
    ON public.company_branches(company_id);
CREATE INDEX IF NOT EXISTS idx_company_branches_is_active
    ON public.company_branches(is_active) WHERE is_active = true;

-- ── 3. Auto-update updated_at ─────────────────────────────
CREATE OR REPLACE FUNCTION public.touch_company_branch()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_touch_company_branch ON public.company_branches;
CREATE TRIGGER trg_touch_company_branch
    BEFORE UPDATE ON public.company_branches
    FOR EACH ROW
    EXECUTE FUNCTION public.touch_company_branch();

-- ── 4. RLS ────────────────────────────────────────────────
ALTER TABLE public.company_branches ENABLE ROW LEVEL SECURITY;

-- 4a. View: company users see branches of their own company,
--     admin/officer/super_admin see all.
CREATE POLICY "company_branches_select"
    ON public.company_branches FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.user_id = auth.uid()
              AND up.role IN ('admin','super_admin','officer')
        )
        OR company_id = (
            SELECT company_id FROM public.user_profiles
            WHERE user_id = auth.uid() LIMIT 1
        )
    );

-- 4b. Insert: company users may only insert branches for their
--     own company; admin/officer/super_admin may insert for any.
CREATE POLICY "company_branches_insert"
    ON public.company_branches FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.user_id = auth.uid()
              AND up.role IN ('admin','super_admin','officer')
        )
        OR company_id = (
            SELECT company_id FROM public.user_profiles
            WHERE user_id = auth.uid() LIMIT 1
        )
    );

-- 4c. Update: same scope as insert
CREATE POLICY "company_branches_update"
    ON public.company_branches FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.user_id = auth.uid()
              AND up.role IN ('admin','super_admin','officer')
        )
        OR company_id = (
            SELECT company_id FROM public.user_profiles
            WHERE user_id = auth.uid() LIMIT 1
        )
    );

-- 4d. Delete: admin/officer/super_admin only (companies can
--     "soft-delete" by setting is_active = false instead)
CREATE POLICY "company_branches_delete"
    ON public.company_branches FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.user_id = auth.uid()
              AND up.role IN ('admin','super_admin','officer')
        )
    );

-- ── 5. Grants ─────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON public.company_branches TO authenticated;

-- ── 6. Comments ───────────────────────────────────────────
COMMENT ON TABLE public.company_branches IS
    'Branch locations registered by a company. One company can have many branches across the country.';

COMMENT ON COLUMN public.company_branches.branch_no IS
    'Branch number / code (e.g. B001, HQ, Gaborone Branch). Unique per company.';

COMMENT ON COLUMN public.company_branches.branch_name IS
    'Descriptive branch name (e.g. Gaborone Office, Francistown Depot).';

COMMENT ON COLUMN public.company_branches.plot_number IS
    'Plot number of the branch premises.';

COMMENT ON COLUMN public.company_branches.street_name IS
    'Street name of the branch premises.';

COMMENT ON COLUMN public.company_branches.physical_address IS
    'Full physical address of the branch.';

COMMENT ON COLUMN public.company_branches.is_active IS
    'Soft-delete flag. Company users set this to false instead of deleting.';
