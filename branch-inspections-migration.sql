-- =============================================================================
-- Branch <-> Inspection link
--
-- Lets an inspection be recorded against one of a company's registered
-- branches (company_branches), and lets a company choose the branch when it
-- books an inspection. A branch is OPTIONAL on both: an inspection with no
-- branch is a general inspection of the whole business, which is what every
-- inspection recorded so far is.
--
-- Run in Supabase Dashboard -> SQL Editor. Idempotent (safe to run twice).
--
-- After this:
--   * inspection.html shows a "Branch / Premises" dropdown under
--     Factory / Employer Name and stamps company_id + branch_id.
--   * company-book-inspection.html shows the same dropdown under Company Name
--     and stamps branch_id on the booking, so the inspection created from that
--     booking arrives pre-linked to the branch.
--   * My Branches shows a compliance rating per branch; a company's compliance
--     is the average of its branches' ratings (see computeComplianceByBranch in
--     common.js for the exact rule).
-- =============================================================================

BEGIN;

-- ── 1. Columns ────────────────────────────────────────────────────────────
ALTER TABLE public.workplace_inspections
  ADD COLUMN IF NOT EXISTS branch_id uuid;

ALTER TABLE public.inspection_bookings
  ADD COLUMN IF NOT EXISTS branch_id uuid;

-- ── 2. Foreign keys (nullable: no branch means a general inspection) ──────
-- ON DELETE SET NULL matches how booking_id is handled: deleting a branch
-- record must never delete the statutory inspection record attached to it.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'workplace_inspections_branch_id_fkey'
  ) THEN
    ALTER TABLE public.workplace_inspections
      ADD CONSTRAINT workplace_inspections_branch_id_fkey
      FOREIGN KEY (branch_id) REFERENCES public.company_branches(id)
      ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'inspection_bookings_branch_id_fkey'
  ) THEN
    ALTER TABLE public.inspection_bookings
      ADD CONSTRAINT inspection_bookings_branch_id_fkey
      FOREIGN KEY (branch_id) REFERENCES public.company_branches(id)
      ON DELETE SET NULL;
  END IF;
END;
$$;

-- ── 3. Indexes (partial: most rows have no branch) ───────────────────────
CREATE INDEX IF NOT EXISTS idx_wi_branch_id
  ON public.workplace_inspections(branch_id)
  WHERE branch_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ib_branch_id
  ON public.inspection_bookings(branch_id)
  WHERE branch_id IS NOT NULL;

-- Branch compliance is read per branch, newest first.
CREATE INDEX IF NOT EXISTS idx_wi_branch_date
  ON public.workplace_inspections(branch_id, inspection_date DESC)
  WHERE branch_id IS NOT NULL;

-- ── 4. Comments ──────────────────────────────────────────────────────────
COMMENT ON COLUMN public.workplace_inspections.branch_id IS
  'Branch this inspection was carried out at (company_branches.id). NULL = general inspection of the whole business.';

COMMENT ON COLUMN public.inspection_bookings.branch_id IS
  'Branch the company booked the inspection for (company_branches.id). NULL = booking for the business as a whole; inherited by the inspection created from this booking.';

COMMIT;

-- =============================================================================
-- 5. Verification — run these after applying.
--    Before: each count query errors with 42703 ("column ... does not exist").
--    After:  each returns HTTP 200 with a count.
-- =============================================================================
-- (Replace <ANON_KEY> with the value from supabase-config.js.)
--
--   curl -s -o /dev/null -w '%{http_code}\n' \
--     "https://<project>.supabase.co/rest/v1/workplace_inspections?select=branch_id&limit=1" \
--     -H "apikey: <ANON_KEY>" -H "Authorization: Bearer <ANON_KEY>"
--   → 200  (was 400 with 42703)
--
--   curl -s -o /dev/null -w '%{http_code}\n' \
--     "https://<project>.supabase.co/rest/v1/inspection_bookings?select=branch_id&limit=1" \
--     -H "apikey: <ANON_KEY>" -H "Authorization: Bearer <ANON_KEY>"
--   → 200  (was 400 with 42703)
--
-- Inspections already linked to a branch, and whether the branch belongs to the
-- same company (should always be 0 — the UI only offers that company's branches):
--
--   SELECT count(*) FILTER (WHERE wi.branch_id IS NOT NULL)               AS linked,
--          count(*) FILTER (WHERE b.company_id IS DISTINCT FROM wi.company_id) AS mismatched
--   FROM public.workplace_inspections wi
--   LEFT JOIN public.company_branches b ON b.id = wi.branch_id;
