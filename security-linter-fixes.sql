-- =============================================================================
--  Supabase linter fixes: SECURITY DEFINER views + one unguarded table
--  Run in Supabase Dashboard → SQL Editor. Idempotent — safe to run twice.
--
--  Why: Postgres views default to SECURITY DEFINER, so they execute with the
--  permissions of the view owner and RLS on the underlying tables is skipped
--  entirely. PostgREST exposes any view the anon role may read, and the anon
--  key ships in supabase-config.js, so those views were readable by anybody.
--  security_invoker = true makes each view enforce the *querying* user's RLS.
-- =============================================================================

-- ── 1. The four views the linter reports (security_definer_view) ─────────────
ALTER VIEW public.incident_chain_view             SET (security_invoker = true);
ALTER VIEW public.accident_report_persons_view    SET (security_invoker = true);
ALTER VIEW public.dangerous_occurrence_full_view  SET (security_invoker = true);
ALTER VIEW public.functions_without_search_path   SET (security_invoker = true);

-- ── 2. Take them out of anonymous reach ─────────────────────────────────────
-- 2a. incident_chain_view is only read from signed-in pages (worker-claims.html,
--     claim-tracker.html). Verified 2026-10-11: anon could read 2 rows with
--     worker names, injuries, claim file numbers and incapacity percentages.
REVOKE SELECT ON public.incident_chain_view FROM anon;

-- 2b. functions_without_search_path is a linter diagnostic, not app
--     functionality — it was publishing 37 function names, their arguments and
--     SECURITY DEFINER flags to anyone. Dropping it removes the surface
--     entirely; if you want to keep it for audits, comment out the DROP and
--     rely on the security_invoker line above plus this REVOKE:
REVOKE ALL ON public.functions_without_search_path FROM anon, authenticated;
DROP VIEW IF EXISTS public.functions_without_search_path;

-- 2c. The two remaining views aren't used by any page (checked across all 54
--     pages) but stay for reporting; with security_invoker they now show a
--     signed-in user only what that user's RLS allows.
REVOKE SELECT ON public.accident_report_persons_view   FROM anon;
REVOKE SELECT ON public.dangerous_occurrence_full_view FROM anon;

-- ── 3. NOT flagged by the linter, but leaking today ─────────────────────────
--  accident_injured_persons is a plain table with RLS not in effect on the live
--  database. Verified 2026-10-11 with the public anon key and no session:
--  rows returned = 2, exposing full_name, id_number, age_years, sex, email,
--  injury_fatal, hourly_pay, medical_practitioner — while every other base
--  table in the schema returned 0 rows.
ALTER TABLE public.accident_injured_persons ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.accident_injured_persons FROM anon;
GRANT SELECT, INSERT, UPDATE ON public.accident_injured_persons TO authenticated;

-- Replace the three legacy policies. The new ones delegate to the parent
-- accident report: if the current user is allowed to see that accident_reports
-- row, they may see/add its injured persons. Nothing here duplicates the
-- accident_reports policies, so company/officer/submitter visibility stays
-- exactly as it is now, and it follows future changes to those policies.
DROP POLICY IF EXISTS "Users can select injured persons on their reports" ON public.accident_injured_persons;
DROP POLICY IF EXISTS "Users can insert injured persons on their reports" ON public.accident_injured_persons;
DROP POLICY IF EXISTS "Users can update injured persons on their reports" ON public.accident_injured_persons;

CREATE POLICY "Injured persons follow their accident report"
  ON public.accident_injured_persons FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.accident_reports ar
                  WHERE ar.id = accident_injured_persons.accident_report_id));

CREATE POLICY "Add injured persons to a report you can see"
  ON public.accident_injured_persons FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.accident_reports ar
                       WHERE ar.id = accident_injured_persons.accident_report_id));

CREATE POLICY "Update injured persons on a report you can see"
  ON public.accident_injured_persons FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.accident_reports ar
                  WHERE ar.id = accident_injured_persons.accident_report_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.accident_reports ar
                       WHERE ar.id = accident_injured_persons.accident_report_id));

-- ── 4. Verify afterwards ────────────────────────────────────────────────────
--  The linter should be clean, and these two commands (run from a terminal with
--  the anon key, no session) should both return 0 rows:
--
--    curl -s -D - -o /dev/null -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
--      -H "Prefer: count=exact" -H "Range: 0-0" \
--      "$SUPABASE_URL/rest/v1/accident_injured_persons?select="
--
--    curl -s -D - -o /dev/null -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
--      -H "Prefer: count=exact" -H "Range: 0-0" \
--      "$SUPABASE_URL/rest/v1/incident_chain_view?select="
--
--  Also audit every RPC, since Postgres grants EXECUTE to PUBLIC by default and
--  PostgREST exposes whatever is granted:
--
--    SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args,
--           p.prosecdef,
--           has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute
--    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--    WHERE n.nspname = 'public' AND has_function_privilege('anon', p.oid, 'EXECUTE')
--    ORDER BY p.proname;
--
--  (delete_user_account currently appears in that list and can be called
--  unauthenticated — see page-error-audit.md §B1.)
