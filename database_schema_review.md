# `database_schema.sql` review — redundancies and fixes needed

Reviewed 2026‑10‑11 against the file plus the **live** Supabase project (`qblogmmknnacaaircrlt`), because the file's own header says:

> `-- WARNING: This schema is for context only and is not meant to be run.`

So it is a *snapshot*, not a migration. It is accurate about **tables and columns** (every column I probed matched it), but it does **not** carry RLS policies, indexes, triggers or `ON DELETE` referential actions.

**How the live checks were made** (repeatable, read‑only, anon key — the same key the browser app ships):

```bash
# does a column exist? 200 = yes, 42703 = no
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  "$SUPABASE_URL/rest/v1/ohs_form_19?select=accident_id&limit=1"
```

29 tables were parsed out of the file; 36 `.sql` files and every `.html`/`.js` file were cross‑checked against them.

---

## 1. Fixes needed now — verified live

### 1.1 🔴 `incident_chain_view` leaks accident data to anyone with the anon key

Every base table correctly returns nothing to anon, and 19 views return nothing — but this one returns rows:

| object | rows readable by `anon` |
|---|---|
| `companies`, `accident_reports`, `workers_registry`, `injury_claims`, `ohs_form_19`, `user_profiles` | `[]` |
| `company_register_view`, `accident_report_view`, `injury_disease_report_view`, `injury_claims_view`, `user_roles_view`, `active_users_summary`, `recent_login_activity`, … | 0 rows |
| **`incident_chain_view`** | **2 rows** (worker name, injuries, claim file number, incapacity %, medical exam status) |

Cause: [fix_security_definer_views.sql](fix_security_definer_views.sql) switches 19 views to `security_invoker`, and `incident_chain_view` is **not in that list** — and then [accident-case-number-migration.sql](accident-case-number-migration.sql#L74-L83) does `DROP VIEW` / `CREATE VIEW` (dropping the setting) and re‑grants `SELECT` **to `anon`**. It therefore still runs as its owner and bypasses RLS.

```sql
-- safe, idempotent
ALTER VIEW public.incident_chain_view SET (security_invoker = true);
REVOKE SELECT ON public.incident_chain_view FROM anon;
```

Supabase's own linter reports four views still SECURITY DEFINER — `incident_chain_view`, `accident_report_persons_view`, `dangerous_occurrence_full_view` and the diagnostics view `functions_without_search_path`. The two I had cleared (`accident_report_persons_view`, `dangerous_occurrence_full_view`) are indeed SECURITY DEFINER but happen to be empty right now (0 rows), so they are latent rather than leaking. And there is a worse one the linter cannot see, because it is a plain table: **`accident_injured_persons` has RLS not in effect live** — the anon key reads 2 rows of injured-worker names, ID numbers, emails and pay (all 28 other base tables return 0). [security-linter-fixes.sql](security-linter-fixes.sql) is the idempotent migration for all of it.

Also worth auditing: any future `CREATE VIEW` in this repo should be added to the `security_invoker` list in the same commit, otherwise the same bug returns.

### 1.2 🔴 A diagnostics view is public, and 3 `SECURITY DEFINER` functions still have no `search_path`

`functions_without_search_path` ([security-fixes.sql:274](security-fixes.sql#L274)) is exposed through PostgREST: **anon can read 37 rows** of `schema_name, function_name, arguments, security, config` — a ready‑made target list. Meanwhile the view itself reports **3 `SECURITY DEFINER` functions with no `search_path`**, which is a privilege‑escalation vector:

- `delete_user_account(p_user_id uuid)`
- `guard_inspection_booking_transition()`
- `log_role_change()`

[security-fixes.sql](security-fixes.sql) already contains `ALTER FUNCTION … SET search_path = 'public'` for `log_role_change()` (and 30+ others) — it evidently was not applied:

```sql
ALTER FUNCTION public.delete_user_account(uuid) SET search_path = 'public';
ALTER FUNCTION public.guard_inspection_booking_transition() SET search_path = 'public';
ALTER FUNCTION public.log_role_change() SET search_path = 'public';
-- then move the diagnostic view out of the exposed schema, or revoke it
DROP VIEW public.functions_without_search_path;   -- (or revoke from anon + authenticated)
```

### 1.3 🔴 Form 19 cannot be submitted when an accident is linked — `ohs_form_19.accident_id` does not exist

`OHS_Form19_Full.html` creates a hidden field `name="accident_id"` ([line 642-646](OHS_Form19_Full.html#L642)), the generic collector adds every `[name]` to the payload, and line 550 sets `payload.accident_id` explicitly. The form then does `from('ohs_form_19').insert([payload])` with **no column filtering** ([line 620](OHS_Form19_Full.html#L620)).

Live proof (PostgREST validates the body *before* RLS):

```
POST /rest/v1/ohs_form_19  {"case_no":"…","accident_id":"…"}  -> 400 PGRST204
     "Could not find the 'accident_id' column of 'ohs_form_19' in the schema cache"
POST /rest/v1/ohs_form_19  {"case_no":"…"}                    -> 401 42501 (RLS only)
```

So submissions **without** an accident succeed, and submissions **with** one fail with `Error: Could not find the 'accident_id' column…`. The column is declared in `COMPILED_DATABASE.sql` (187 cols vs 186 live) and expected by [form19-investigation.js:62](form19-investigation.js#L62) — the migration was simply never applied.

```sql
ALTER TABLE public.ohs_form_19
  ADD COLUMN IF NOT EXISTS accident_id uuid REFERENCES public.accident_reports(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_f19_accident ON public.ohs_form_19(accident_id);
```

Until that runs, the page should also drop unknown keys before insert rather than failing the whole submission.

### 1.4 🟠 Four BL tables are missing the columns that link them to a claim/worker/accident

Declared in `COMPILED_DATABASE.sql`, `bl_forms_migration.sql`, `fix_data_architecture_migration.sql` — **absent live**:

| table | declared but missing live |
|---|---|
| `bl_form_43_04_incapacity` | `claim_id`, `worker_registry_id`, `accident_id`, `status` |
| `certificate_of_insurance` | `status`, `updated_at` |
| `medical_attendance_notifications` | `status`, `updated_at` |
| `bl_form_43_02_wages` | `status` |

Nothing writes them today (no `name="claim_id"` etc. on any page), so there is no crash — which is exactly the problem: **BL Form 43‑04, 43‑07 and 43‑11 can never be tied to a claim, so a compensation claim has no route to its medical/insurance evidence.** The claim‑tracker flow is one‑directional. Either apply the migration or delete the dead declarations so the two files stop disagreeing.

### 1.5 🟠 Soft delete is defined but never used — and it blocks re‑use of names/IDs

`is_deleted` / `deleted_at` exist on `user_profiles`, `workers_registry`, `companies` and are referenced **zero times** in any `.html`/`.js` file. Consequences:

1. Soft‑deleted rows are still returned by every register, lookup and dropdown.
2. The `UNIQUE` constraints are unconditional (`companies.company_name`, `workers_registry.id_number`, `user_profiles.email`), so once a row is soft‑deleted the same company name or Omang **can never be registered again**.

```sql
-- allow re-use of the identity after a soft delete
DROP INDEX IF EXISTS companies_company_name_key;
CREATE UNIQUE INDEX companies_company_name_live_key
  ON public.companies (lower(company_name)) WHERE is_deleted IS NOT TRUE;
DROP INDEX IF EXISTS workers_registry_id_number_key;
CREATE UNIQUE INDEX workers_registry_id_number_live_key
  ON public.workers_registry (upper(id_number)) WHERE is_deleted IS NOT TRUE;
-- and filter reads, e.g. .eq('is_deleted', false) / a RESTRICTIVE RLS policy
```

### 1.6 🟠 `injury_claims` requires 10 values nobody can know at creation time

`name_of_employer`, `industry`, `location`, `nationality`, `date_of_injury`, `date_reported`, `date_received`, `cause`, `nature`, `gender`, `incapacity_percentage` are all `NOT NULL`. A claim auto‑created from an accident or injury report, or saved as a draft, must invent values for all of them (the form even has to fall back to `''`). These should be nullable (or defaulted) for `status = 'draft'`, otherwise drafts are unrepresentable and the "draft" status in the CHECK constraint is unreachable in practice.

### 1.7 🟠 Claim/occurrence rows can be duplicated — nothing enforces one per source

- `injury_claims` links to its source **three different ways** — `injury_report_id` (FK), `source_type`+`source_id` (**no FK at all**, polymorphic, silently orphanable) — and `file_number` is the only `UNIQUE`. There is no unique constraint on the source pair, so a retry creates a second claim for the same incident.
- `accident-report.html` always **inserts** a new `dangerous_occurrence_reports` row on submit ([line 1189](accident-report.html#L1189)) and there is no unique constraint on `accident_report_id`, so a retry duplicates it. An upsert keyed on `accident_report_id` is the fix.

### 1.8 🟡 Smaller data‑integrity items

- `medical_attendance_notifications` has **no `updated_at`** and no trigger — edits of a medical notification leave no trace (and the `updated_at` column the compiled file promises does not exist).
- `password_reset_requests.status` allows `'expired'` but there is no expiry column to base it on.
- `accident_injured_persons.worker_registry_id` is nullable while the parallel `accident_report_persons.worker_registry_id` is `NOT NULL`.
- `ohs_form_19.status`, `notifications.type`, `accident_reports.outside_persons_injured` and `dangerous_occurrence_reports.outside_persons_injured` are unconstrained free text where every neighbour has a `CHECK`.
- `accident_reports.investigation_status` defaults to `'Pending'` (capitalised) while the rest of the schema's status vocabularies are lowercase — a comparison trap.
- `company-employer-details-migration.sql` is still unrun, but all three of its columns (`district`, `city_town`, `postal_address`) are **already live** — the file is redundant.
- `schema_improvements.sql` Part 1 gives every FK to `auth.users` a delete rule **except `notifications` and `claim_documents.uploaded_by`** — deleting a user who has either will still 409.

---

## 2. Redundancies — the same fact stored in more than one place

### 2.1 Dangerous occurrence data exists twice, and different pages read different copies 🔴

`accident_reports` carries the full dangerous‑occurrence block (`dangerous_date/time/place/description/damage`, `employees_injured`, `notification_submitted`, `outside_persons_injured`) **and** there is a whole `dangerous_occurrence_reports` table holding the same fields plus `occupier_name`, `premises_address`, `nature_of_industry`, `industry_sector`, `reporter_*`, `investigation_status`, `official_action`, `status`.

On submit both are written from the same form values ([payload 1046‑1053](accident-report.html#L1046), [second insert 1172‑1188](accident-report.html#L1172)). On read:

- [accident-report.html:708](accident-report.html#L708) reads `dangerous_occurrence_reports`;
- [worker-profile.html:1227](worker-profile.html#L1227) reads `dangerous_*` **from `accident_reports`**.

Two copies, two readers, no synchronisation — they will drift the first time either side is edited. `report_type = 'dangerous_occurrence' | 'both'` is a third way of encoding the same thing. And `dangerous_occurrence_persons` (the persons table for these reports) is **referenced by no code and no SQL writer** — persons on a dangerous occurrence can never be recorded.

Pick one home (the standalone table is the better model) and make the other a view or drop it.

### 2.2 Injured persons exist in four shapes

| representation | written by app | read by app |
|---|---|---|
| `accident_reports.injured_*` (first person, denormalised) | yes ([1025‑1034](accident-report.html#L1025)) | many pages |
| `accident_injured_persons` (full per‑person rows) | yes (3 inserts) | `checklist`, `company-*-view`, `entries` |
| `accident_report_persons` (junction: `worker_registry_id`, `role_in_accident`, `sort_order`) | yes (1 insert) | only `accident-report.html` |
| `accident_reports.additional_injured` (jsonb) | **never** | **never** — dead column |

`accident_injured_persons` already stores `worker_registry_id`, so the junction duplicates the same link for the same rows while the first person is copied a third time onto the parent row.

### 2.3 Employer identity is free text in 30 columns with no link to `companies`

`injury_claims.name_of_employer`, `workplace_inspections.factory_name`, `accident_reports.occupier_name`, `injury_disease_reports.employer_name/telephone/fax`, `workers_registry.employer_name/address/telephone/fax`, `ohs_form_19.employer_*` (8 columns), `bl_form_43_02_wages.employer_*`, `bl_form_43_04_incapacity.employer_name`, `certificate_of_insurance.employer_name/address`, `inspection_bookings.company_name`, `claim_documents.employer_name`, `dangerous_occurrence_reports.occupier_name`.

Only `inspection_bookings.company_id`, `workplace_inspections.company_id` and `user_profiles.company_id` are real FKs; everything else is a spelling. The register is then rejoined by **string comparison** — `LOWER(c.company_name) = LOWER(ar.occupier_name)` in `schema_improvements.sql`'s views, and the same tolerant‑matching dance in the Form 19 employer lookup. Every "employer didn't pull through" bug traces back to this. An `accident_reports.company_id` / `injury_disease_reports.company_id` FK (nullable, with the text kept as a snapshot) removes the whole class of bug.

### 2.4 Worker identity is restated in 25 text columns next to 13 registry FKs

13 columns hold a `workers_registry` link while 25 columns restate `full_name` / `worker_name` / `injured_name` / `*_id_number` / `worker_address`. `claim_documents` is the worst case: it is keyed **only** by `worker_id_number text NOT NULL` (+ `employer_name`) and has no `worker_registry_id` at all, so documents attach to a string that RLS cannot scope.

### 2.5 `workplace_inspections` stores contraventions three ways

`contraventions text[]` (the checked section ids), `total_contraventions integer` (derivable — `array_length`), and ~30 `s9 … s67 boolean` columns (the same information again). The page writes the array and the count ([inspection.html:758‑759](inspection.html#L758)) and the entries page falls back to counting the array "if stored totals are stale". One representation plus a trigger is enough.

### 2.6 Reconcilable vocabulary splits

| concept | variants in the schema |
|---|---|
| sex | `'Male'/'Female'` (`workers_registry.sex`, `accident_injured_persons.sex`, `permanent_impairment_reports.sex`, `ohs_form_19.sex`) vs `'M'/'F'` (`injury_claims.gender`) |
| status | 17 status columns, 7 unrelated value sets (`submitted/under_review/investigated/closed`, `draft/completed/reviewed/closed`, `pending/assigned/scheduled/…`, …) |
| sector | identical value list repeated in `accident_reports.industry_sector`, `dangerous_occurrence_reports.industry_sector`, `workplace_inspections.industry_type`; plus free text in `companies.industry`, `injury_claims.industry` |
| soft delete | `is_deleted`/`deleted_at` on 3 tables; `is_active` on `companies`, `company_branches`, `departments`; `status='cancelled'` elsewhere |

Only the sex split is handled in code today ([worker-lookup.js:80‑92](worker-lookup.js#L80) maps both ways) — worth promoting to one canonical value instead of two.

### 2.7 Reference data duplicated between the database and the code

`departments` (with a `code UNIQUE` and seed rows in `master-setup.sql:36`) and `user_roles_info` (role, display name, permissions; seeded at `master-setup.sql:138`) are **never read by any page** — instead `user_profiles.department` and `user_profiles.role` carry their own hardcoded `CHECK` lists and the UI hardcodes its own arrays. Either use the tables (FK them) or drop them.

### 2.8 Other duplicates worth collapsing

- `user_profiles` has both `id uuid PRIMARY KEY` (defaulted) and `user_id uuid NOT NULL UNIQUE REFERENCES auth.users` — two identities for one row; `user_id` should be the key.
- `companies` address is spread over `location`, `physical_address`, `plot_number`, `street_name`, `district`, `city_town`, `postal_address` — and `company_branches` repeats `plot_number`, `street_name`, `physical_address` for the branch. `companies.location` is legacy (the newer columns supersede it).
- `claim_documents.uploaded_at` and `claim_documents.created_at` are the same event.
- `injury_claims.source_type`+`source_id` and `injury_claims.injury_report_id` and `injury_disease_reports.accident_id` are three routes through the same chain (`incident_chain_view` shows the intended one).
- Tables with no writer and no reader anywhere: `user_activity_log`, `login_history` (a trigger computes `session_duration`, but nothing ever inserts a row), `password_reset_requests`, `dangerous_occurrence_persons`, `departments`, `user_roles_info`.

---

## 3. The meta‑problem: four sources of truth for one schema

| file | tables it declares | note |
|---|---|---|
| [database_schema.sql](database_schema.sql) | 29 | live snapshot, "not meant to be run", no policies/indexes/triggers |
| [COMPILED_DATABASE.sql](COMPILED_DATABASE.sql) | 24 | older, but declares 8 columns that don't exist live |
| [master-setup.sql](master-setup.sql) | 19 | oldest; misses 10 tables that exist live |
| 33 other migration files | — | partly applied, no record of which |

**17 tables have drifted** between them. Concretely, live‑only columns absent from the snapshot files include `companies.district/city_town/postal_address`, `injury_disease_reports.is_factory_accident/is_mine_accident/is_road_traffic_accident`, `inspection_bookings.booking_number/status_changed_by/status_changed_at`, `workplace_inspections.s9/s17/total_contraventions/booking_id`, `accident_reports.assigned_inspector`, `user_profiles.practice_name/med_reg_number/branch/practitioner_address/practitioner_tel`, and (from the other direction) files that promise live‑missing `bl_form_43_04_incapacity.claim_id` and `ohs_form_19.accident_id`.

Before the next change: re‑run [schema-discovery.sql](schema-discovery.sql) (sections 2, 5, 8, 10) to capture columns **plus RLS policies, indexes and triggers**, and make that snapshot the single reference; mark the others as historical.

---

## 4. Suggested order

1. `incident_chain_view` → `security_invoker` + revoke `anon`; drop/revoke `functions_without_search_path`; add `search_path` to the 3 definer functions. *(security, no product impact)*
2. `ohs_form_19.accident_id` — Form 19 currently fails to save whenever an accident is linked.
3. Soft‑delete: partial unique indexes + filters, so deleted companies/workers stop appearing and names can be re‑used.
4. Decide the dangerous‑occurrence home; delete `additional_injured`; retire `dangerous_occurrence_persons` or start using it.
5. Add `company_id` FKs where the employer is currently a string (Form 19/accident/injury/claim) — kills the recurring autofill failures.
6. Links and duplication guards: `injury_claims` source uniqueness, upsert on `dangerous_occurrence_reports.accident_report_id`, BL form `claim_id` columns, `injury_claims` nullable‑until‑complete.
7. Collapse the remaining vocabulary/representation duplicates (§2.5–2.8) table by table.

Items 1 and 2 are safe to apply on their own. Items 3–7 change what the app reads or writes and should go out with the corresponding page changes.

## 5. What I could not verify

- **RLS policies and FK `ON DELETE` actions** are not in the export (it drops them), so the delete‑rule statements in §1.8 come from the `.sql` files, not from the live server. Confirm with `schema-discovery.sql` sections 4/5/10.
- No **index** information either (section 8 of `schema-discovery.sql`) — I could not check whether the 13 `worker_registry_id` / 30 employer‑text columns are indexed.
- The two leaked `incident_chain_view` rows were read as **counts and column names only**; no record contents were printed or stored.
- I did not modify the database: everything here is a recommendation, and no migration in this review has been run.
