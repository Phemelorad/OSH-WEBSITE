# Page error audit — all 54 pages + 19 shared scripts

Run 2026‑10‑11 against the working tree, the live Supabase project (`qblogmmknnacaaircrlt`) and a local static server.

**How this was produced**

| pass | what it covers |
|---|---|
| [`scripts/audit-pages.mjs`](scripts/audit-pages.mjs) (new) | every page & shared script: inline‑script syntax, element‑id references, duplicate ids, inline handlers calling undefined functions, missing local assets/links, missing shared scripts, CSP, and every Supabase table / column / embedded‑resource reference checked against `database_schema.sql`. Read‑only, exit 1 when it finds something. |
| live API probes (anon key, read‑only) | column/table existence (`42703`, `PGRST204`, `PGRST205`, `PGRST200`), view row exposure, RPC callability |
| browser smoke test | 13 pages loaded over `http://127.0.0.1:8765` with console + network capture |

```
node scripts/audit-pages.mjs      # 33 findings, exit 1
```

---

## A. Bugs that break features (verified)

### A1. 🔴 The whole worker portal claim flow fails — 6 columns don't exist
[worker-portal.js:569](worker-portal.js#L569) inserts:

```js
SB.from("injury_claims").insert({
  claimant_name, claimant_id_number, claimant_email,
  incident_description, incident_date, injury_type,
  status: "pending", claimant_id })
```

Live check — `injury_claims` has none of these: `claimant_name`, `claimant_email`, `incident_description`, `incident_date`, `injury_type`, `claimant_id` all return
`42703 column injury_claims.X does not exist`. The real names are `name_of_claimant`, `date_of_injury`, `cause`/`nature`. The insert also omits the `NOT NULL` columns (`name_of_employer`, `industry`, `location`, `nationality`, `gender`, `date_reported`, `date_received`, `incapacity_percentage`), so it cannot succeed even after the renames. **"Submit claim" in the worker portal has never worked**, and the error toast is the only symptom.

### A2. 🔴 Worker portal messages: the table doesn't exist
[worker-portal.js:388](worker-portal.js#L388) and [:415](worker-portal.js#L415) read/write `case_notes` → live returns `PGRST205 Could not find the table 'public.case_notes'` (the server even suggests `companies`). No `.sql` file in the repo creates it. The inbox is always empty and "Send" always fails.

### A3. 🔴 Worker portal medical tab: two independent query errors
[worker-portal.js:236](worker-portal.js#L236):

```js
SB.from("medical_examination_reports").select("*,practitioner_clients!inner(*)")
  .order("examination_date", { ascending:false })
```

* `medical_examination_reports.examination_date` does not exist (`42703`) — the date column is `report_date`.
* `practitioner_clients!inner(*)` needs a foreign key between the two tables; there is none → `PGRST200`.

Either one makes the request 400; the surrounding `try/catch` swallows it, so the tab renders empty with no message.

### A4. 🔴 Form 19 can't be saved when an accident is linked
[OHS_Form19_Full.html:550](OHS_Form19_Full.html#L550) adds `payload.accident_id`, but `ohs_form_19.accident_id` does not exist live:

```
POST /rest/v1/ohs_form_19  {"case_no":"…","accident_id":"…"} → 400 PGRST204 "Could not find the 'accident_id' column"
POST /rest/v1/ohs_form_19  {"case_no":"…"}                   → 401 42501 (RLS only — body accepted)
```

(Also carried over from the schema review — still the single highest‑impact page bug.)

### A5. 🔴 Four "Status" buttons and one pager call functions that don't exist
Inline handlers resolve at click time; these names are defined nowhere in the page or in any script it loads:

| page | handler | where the name actually exists |
|---|---|---|
| [accident-entries.html:617](accident-entries.html#L617) | `editInvestigation()` | only [company-accidents-view.html:577](company-accidents-view.html#L577) |
| [inspection-entries.html:496](inspection-entries.html#L496) | `editRecord()` | **nowhere in the project** |
| [company-injuries-view.html:639](company-injuries-view.html#L639) | `editStatus()` | only `entries.html` / `__entries_script.js` |
| [injury-disease-entries.html:438,444,569](injury-disease-entries.html#L438) | `changePageSize()`, `goToPage()`, `editStatus()` | only `entries.html` / `__entries_script.js` |

Each click throws `Uncaught ReferenceError` and does nothing.
Root cause for three of them: [`__entries_script.js`](__entries_script.js) is **included by no page at all** — pages were meant to load it (or to keep their own copies) and didn't.

### A6. 🟠 `company-accidents-view.html` — three controls share one id
`id="filterInv"` appears three times ([lines 282, 292, 302](company-accidents-view.html#L282)), all labelled "Investigation". `getElementById`/`querySelector('#filterInv')` only ever reach the first, so the two duplicated dropdowns are dead UI and the filter reads one select. The same file also contains an entire duplicated script block: `editInvestigation`, `exportCSV`, `applyPagination`, `renderPage`, `updatePaginationControls`, `goToPage`, `changePageSize` are each defined **twice** (byte‑identical — verified by diff), so the first copies are unreachable.

### A7. 🟠 `company-injuries-view.html` — pagination UI never rendered
The page keeps `paginationInfo` / `pageSizeSelect` in its CSS and JS but never puts those elements in the markup (lines 676, 693). Result: no "Showing X–Y of Z" line, no page‑size selector, and `changePageSize()` can never run (`getElementById(...).value` would throw if it did). `editStatus` (A5) makes the Status button fail too.

---

## B. Security errors reachable from these pages

The anon key is in [supabase-config.js](supabase-config.js) and is shipped to every visitor, so "anon can call it" means "anyone on the internet can call it".

### B1. 🔴 Anyone can delete a user account
`admin.html` calls the `delete_user_account` RPC. Called **unauthenticated**, with no session:

```
POST /rest/v1/rpc/delete_user_account  {"p_user_id":"00000000-0000-0000-0000-000000000000"}
→ HTTP 200 {"message":"User not found in auth system","success":false}
```

HTTP 200 with the function's own message proves the `SECURITY DEFINER` body executed for an anonymous caller. I deliberately passed a non‑existent UUID so nothing was deleted — with a real user's id this deletes them from `auth.users`. Postgres grants `EXECUTE` to `PUBLIC` by default; the `GRANT EXECUTE … TO authenticated` in `schema_improvements.sql` never removed that.

```sql
REVOKE EXECUTE ON FUNCTION public.delete_user_account(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.delete_user_account(uuid) TO authenticated;
-- and add the role check inside the function body, since 'authenticated' is any signed-in user
```

`get_user_role(uuid)` is callable the same way (HTTP 200). Audit the rest of the RPC surface with:

```sql
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef,
       has_function_privilege('anon', p.oid, 'EXECUTE')          AS anon_can_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_can_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
ORDER BY anon_can_execute DESC, p.proname;
```

### B2. 🔴 `incident_chain_view` still leaks to anon (re‑verified today)
`content-range: 0-0/2` — two real rows with worker name, injuries, claim file number, incapacity and medical status, while every base table and the other 19 views return zero rows. Still missing from [fix_security_definer_views.sql](fix_security_definer_views.sql).

The Supabase linter independently reports the same class of defect, plus two views I had not flagged (`accident_report_persons_view`, `dangerous_occurrence_full_view`) — also SECURITY DEFINER, currently empty so nothing leaks yet. [security-linter-fixes.sql](security-linter-fixes.sql) is a ready‑to‑run, idempotent migration covering all four views, the revokes, and the table hole in §B5.

### B3. 🟠 `functions_without_search_path` is public
37 rows of function names, arguments, `SECURITY DEFINER` flags and settings, readable by anon — and it reports 3 definer functions without `search_path` (`delete_user_account`, `guard_inspection_booking_transition`, `log_role_change`).

### B4. 🟡 `company-branches.html` is the only page with no CSP
Every other Supabase‑talking page sets `default-src 'self'`, `connect-src … supabase.co`. This page has none (and its `CSP BLOCKS API` counterpart: no other page blocks the API — all 38 were checked).

### B5. 🔴 `accident_injured_persons` is readable by anyone — and the linter doesn't flag it
This is the only **base table** in the whole schema that returns rows to an unauthenticated anon request: `content-range: 0-0/2`, exposing `full_name`, `id_number`, `age_years`, `sex`, `email`, `injury_fatal`, `hourly_pay` and `medical_practitioner` — real injured‑worker records. All 28 other tables return 0. RLS is simply not in effect on it live, even though [multi-injured-migration.sql:35](multi-injured-migration.sql#L35) and `COMPILED_DATABASE.sql:1063` both enable it, so a later change dropped the protection. Covered in [security-linter-fixes.sql](security-linter-fixes.sql) §3.

---

## C. Shipped junk and dead routes

| item | detail |
|---|---|
| [injury-disease-entries - Copy.html](injury-disease-entries%20-%20Copy.html) | stale half‑copy of `injury-disease-entries.html` (16 KB vs 30 KB, 319 differing lines), doesn't load `common.js` so `handleLogout()` is undefined, missing all paging/status functions. Delete. |
| [Users·72osh websitecase-tracking.html](Users%C2%B772osh%20websitecase-tracking.html) | a 476‑byte `"Test page"` stub sitting in the web root, publicly served. Delete. |
| [debug-console.html](debug-console.html) | ships system info, auth info, Supabase config, dependency checks and an error log for anyone who opens it. Gate it behind an admin check or remove it from the deploy. |
| `BL_Form_43-*.html` (5 files) | superseded by the `form-43-*.html` set; none is linked anywhere. |
| 12 orphan pages | `claim-tracker.html`, `BL_Form_43-*` (5), `OHS_Form_1_New_Factory_Registration.html`, `Report_Medical_Evaluation_Permanent_Impairment.html`, `Users·72osh …`, `injury-disease-entries - Copy.html`, the two `email-template-*.html` (expected — used by Supabase auth). `claim-tracker` is still declared in [role-config.js:58](role-config.js#L58) but no nav entry points at it. |

---

## D. What was checked and is clean

* **Runtime smoke test** — 13 pages loaded, ~40 requests served, **zero 4xx/5xx**, zero console errors: `index`, `dashboard`, `accident-report`, `OHS_Form19_Full`, `inspection`, `entries`, `injury-disease-entries`, `worker-portal`, `accident-entries`, `inspection-entries`, `company-accidents-view`, `company-injuries-view`, `reset-password`. All icons/scripts/styles resolved 200; every authenticated page redirected to `index.html` exactly as designed once no session was found; the login form rejects empty input via native validation with no JS error. Console capture was verified working (probe message round‑trip).
* **Syntax** — every inline script and all 18 shared `.js` files parse; no page has a duplicate `<script src>`.
* **Assets/links** — no page references a missing file (the only "missing asset" hits were `${…}` template values inside JS strings and the two Handlebars email templates).
* **Schema use** — apart from A1/A3/A4, every `select()`/`filter()`/`order()` column, every table name and every embedded resource in all 54 pages + 19 scripts exists in the live database.
* **False positives confirmed benign** (listed so nobody re‑chases them): `dashboard.html`'s `stat-*` ids are generated at render time by `buildStatCard()`; `userName`/`userDepartment` in `accident-entries.html`, `checklist.html`, `accident-report.html`, `inspection-bookings.html` are injected by [header.js](header.js) which those pages do include; `worker-profile.html`'s duplicate `recCloseBtn` ids live in two alternative template strings that never coexist in the DOM; `caseNoLock` in Form 19 is always null‑guarded.

---

## E. Suggested order

1. **B1** — revoke `EXECUTE` from `PUBLIC`/`anon` on `delete_user_account` and audit the rest of the RPC surface with the query above. *(Security, one statement.)*
2. **B2/B3** — `security_invoker` on `incident_chain_view`, revoke anon, drop/revoke the diagnostics view, add `search_path` to the 3 definer functions.
3. **A4** — add `ohs_form_19.accident_id` (or strip unknown keys before insert).
4. **A1/A2/A3** — the worker portal is effectively non‑functional: fix the `injury_claims` payload, decide whether `case_notes` should exist, fix the medical query.
5. **A5/A6/A7** — restore or delete the missing handlers, add the missing pagination markup, de‑duplicate `company-accidents-view.html`.
6. **C** — delete the copy/stub pages and gate `debug-console.html`.
7. Add `node scripts/audit-pages.mjs` to whatever you run before deploying, so the next `column missing live` is caught on the commit that introduces it.

---

## F. Limits of this audit

* Everything behind the login wall could not be exercised: without a session every app page redirects to `index.html`, so errors that only occur with data loaded (RLS‑filtered queries, empty‑state rendering, submit paths) are covered by static analysis and live‑schema checks, not by clicking through them. A signed‑in pass with one account per role would close this.
* Column checks cover literal payloads and variables assigned near an insert; a payload built by a helper in another file and never assigned a literal key can still hide a mismatch.
* RLS policies, indexes, triggers and `ON DELETE` actions are not in the schema snapshot I could read, so their effect on these pages is unverified.
* The two leaked `incident_chain_view` rows and all RPC probes were read with counts/column names only; no record contents were stored, and no data was written or deleted.
