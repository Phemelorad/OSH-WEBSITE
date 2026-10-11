# Branch-linked inspections and branch compliance

Inspections and inspection bookings can now be recorded against one of a
company's registered branches, each branch carries its own compliance rating,
and a company's compliance is the average of its branches' ratings.

A branch is **optional**. An inspection with no branch is a *general business
inspection* and still counts — nothing already recorded is invalidated.

---

## 1. Apply the migration first

`branch-inspections-migration.sql` — run it in the Supabase SQL editor. It is
idempotent (safe to run twice).

| live now | after the migration |
|---|---|
| `workplace_inspections.branch_id` — **does not exist** (`42703`) | column + FK to `company_branches(id)` + partial index |
| `inspection_bookings.branch_id` — **does not exist** (`42703`) | column + FK + partial index |

Verified against the live database before writing the migration:
`workplace_inspections?select=branch_id` and
`inspection_bookings?select=branch_id` both returned **HTTP 400 / 42703**, and
`company_branches` already exists (it returns `200 []` to an unauthenticated
call because of RLS, which is expected).

Both FKs are `ON DELETE SET NULL`, matching the existing `booking_id` link:
deleting a branch record must never delete the statutory inspection attached
to it. My Branches deactivates branches instead of deleting them anyway.

### Verify it applied

```bash
# both should print 200 (they printed 400 with 42703 before)
curl -s -o /dev/null -w '%{http_code}\n' \
  "https://<project>.supabase.co/rest/v1/workplace_inspections?select=branch_id&limit=1" \
  -H "apikey: <ANON_KEY>" -H "Authorization: Bearer <ANON_KEY>"
curl -s -o /dev/null -w '%{http_code}\n' \
  "https://<project>.supabase.co/rest/v1/inspection_bookings?select=branch_id&limit=1" \
  -H "apikey: <ANON_KEY>" -H "Authorization: Bearer <ANON_KEY>"
```

The migration file ends with a query that lists branch-linked inspections and
flags any whose branch belongs to a different company (should always be 0).

---

## 2. The compliance rule

Implemented once, in `common.js` → `computeComplianceByBranch(branches, inspections)`:

* **A branch's rating** is the average of *that branch's* inspections, rounded
  to a whole percent. A branch with no inspections is **unrated (`null`), never
  0%** — "not inspected" must not read as "0% compliant".
* **The company's rating** is the average of the branch ratings — each branch
  with at least one inspection counts once.
* **A general (branch-less) inspection** counts once each in the company figure,
  so a business with no branches registered still gets a rating, and a stray
  inspection can never be silently dropped.
* Inspections with no score on record (`compliance_level` null/empty) are
  skipped rather than counted as zero.

So for branches B001 = 85%, B002 = 60%, HQ uninspected, plus two general
inspections at 100% and 0%: company = mean(85, 60, 100, 0) = **61%**, reported
as "Average of 2 branches + 2 general".

If you would rather the general inspections form a single averaging bucket
instead of counting individually, that is a one-line change in
`computeComplianceByBranch`.

---

## 3. What changed, and where

| file | change |
|---|---|
| `branch-inspections-migration.sql` | **new** — `branch_id` on both tables, FKs, indexes, comments, verification queries |
| `common.js` | **new shared helpers** — `getCompanyBranches`, `getCompanyInspections`, `computeComplianceByBranch`, `getCompanyCompliance`, `columnExists`, `branchDisplayName`, `branchAddress` |
| `inspection.html` | "Branch / Premises" dropdown under **Factory / Employer Name**; stamps `company_id` + `branch_id`; inherits the branch from `?booking=<id>` |
| `company-book-inspection.html` | branch picker under **Company Name**; `branch_id` on the booking; fills the premises address |
| `company-branches.html` | **Compliance** column per branch + company figure in the subtitle |
| `company-view.html` | Compliance stat/gauge = average of branch ratings, with the basis shown |
| `company-inspections.html` | **Branch / Premises** column; company stat uses the branch average |
| `company-monitoring.html` | **Branch / Premises** column on the inspection list |
| `company-bookings.html` | **Branch / Premises** column, so a booking's branch is visible |
| `OHS_Form_36_Factories_Inspection.html` | "Premises: …" banner in the read-only header (statutory layout untouched) |

### Safety before the migration is applied

`company_branches` already exists live, so a company with registered branches
would otherwise be offered a branch for a column that does not exist yet and
PostgREST would reject the whole insert (`PGRST204`). Therefore:

* both forms probe the column first (`columnExists`) and **disable the branch
  picker with an explanatory hint** until it exists;
* `branch_id` is only added to a payload when a branch was actually chosen;
* `getCompanyInspections` / `getCompanyBranches` read with `select('*')` and
  return `[]` on error, so every compliance column degrades to "General" and
  every page keeps working.

The probes fail *closed*: if the check cannot be answered (network/permission
error), no branch is offered rather than risking a rejected submission.

---

## 4. Verification

`scripts/branch-compliance-check.html` — 33 checks, **0 failing**. It loads the
real `common.js` and exercises the real helpers plus the delivered page sources:

* the compliance maths, including unrated branches, unknown branch ids, missing
  scores and empty input;
* `getCompanyBranches` / `columnExists` / `getCompanyInspections` against stubs
  for success, missing table (`PGRST205`), missing column (`42703`) and
  unexpected failure;
* that the branch dropdown sits between the business name and the location
  field in both forms, that `branch_id` is payload-guarded and column-gated,
  and that no page selects `branch_id` explicitly;
* the migration's shape (two idempotent `ADD COLUMN IF NOT EXISTS`, both FKs
  with `ON DELETE SET NULL`, `BEGIN`/`COMMIT`, indexes).

The harness caught a real defect while being written: `Number(null)` is `0`, so
a null score was being averaged in as 0% compliance. Fixed in
`computeComplianceByBranch`.

Static audit (`node scripts/audit-pages.mjs`): 33 findings before, **35 after** —
the two new ones are exactly this migration's work items:

```
company-book-inspection.html  L383: inspection_bookings: payload field "branch_id" — column does not exist (PGRST204)
inspection.html               L798: workplace_inspections: payload field "branch_id" — column does not exist (PGRST204)
```

They are a static reading of the payload and cannot see the `columnExists`
guard; **both disappear once the migration is applied**. Nothing else changed.

---

## 5. Limits

* **The SQL was not executed.** There is no Postgres engine or database write
  path available here — only the anon REST key. The migration is verified
  structurally and against the live schema's current shape, not by running it.
* The UI paths were verified by the harness against the real page sources with
  stubbed sessions; they could not be clicked as a signed-in company user. After
  applying the migration, sign in as an employer, add two branches under **My
  Branches**, book an inspection against one of them, then open that branch's
  inspection from the officer side and confirm the compliance appears against
  the branch and in the company average.
* Inspections recorded before the migration have no branch and count as general
  inspections. Backfilling them onto branches would need a mapping decision
  (employer name and address are the only clues) and is not attempted here.
