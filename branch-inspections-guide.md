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
| `company-branches.html` | **Compliance** column per branch + company figure in the subtitle + a **View** action that opens that branch's compliance detail (its rating, its inspections, and a link to each full report) |
| `company-view.html` | Compliance stat/gauge = average of branch ratings, with the basis shown |
| `company-inspections.html` | **Branch / Premises** column; company stat uses the branch average |
| `company-monitoring.html` | **Branch / Premises** column on the inspection list |
| `company-bookings.html` | **Branch / Premises** column, so a booking's branch is visible |
| `OHS_Form_36_Factories_Inspection.html` | **renders the form itself** — fetches `inspection.html`, keeps its stylesheet and its `#inspectionForm`, fills it from the record, locks it, and prints it; the branch appears in the bar and in the form's Branch / Premises field (see §3c) |

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

## 3b. Booking lifecycle: attach an inspection, close the booking

**The bug.** `booking-system-migration.sql` installed a state machine that only
allowed `scheduled -> completed`, and `inspection.html` swallowed the failure
(`catch (e) { console.warn(...) }`). So an inspection submitted against a booking
that was still `pending` or `assigned` **could not complete it**: the booking
stayed open and kept appearing in the "link a booking" dropdown, letting the
same booking be attached to inspection after inspection.

**The fix, in two parts.**

1. `booking-completion-migration.sql` — replaces
   `guard_inspection_booking_transition()` so `completed` may come from
   **any open state** (`pending` / `assigned` / `scheduled`). The inspection
   record is the evidence the visit happened, so requiring an officer to first
   assign and then schedule a booking they have already inspected was not a
   safeguard, it was the defect. Closed bookings stay closed and new bookings
   must still start as `pending`.
2. `inspection.html` + `common.js` — attaching an inspection now completes the
   booking (`completeLinkedBooking`, status-filtered so a closed booking is left
   untouched) and **reports what happened**: the confirmation names the booking
   that was closed, and if it could not be closed the officer gets a warning
   naming this migration rather than silence.

**A completed booking is never offered again.** The link dropdown only lists
`pending`/`assigned`/`scheduled`; the submit path re-checks the booking and drops
the link if it is already closed; and `inspection.html?booking=<id>` refuses a
closed booking too (company details are still prefilled, so a fresh unlinked
inspection can be recorded). The rule itself is `bookingAttachable()` in
`common.js`, a pure function so it is directly testable.

**Not changed deliberately:** the officer Bookings page still offers its manual
"Complete" step only for scheduled bookings — the automatic path is the one that
had to accept any open state.

**Related risk found while investigating (not fixed):** the RLS policy
`"Officers can update bookings"` allows *any* user whose role is `company`,
`officer`, `admin` or `super_admin` to update *any* booking row — there is no
ownership check, so a company account can modify another company's booking.
Tightening it needs a product decision (should a company be able to cancel its
own booking?), so it is left as-is and flagged here.

## 3c. The inspection record view is the form

`OHS_Form_36_Factories_Inspection.html` (opened as `?id=<uuid>&view=1` from every
"View Report" link) used to be a **second, hand-copied OHS Form 36** — the old
paper layout with blank ruled lines — so the record looked nothing like the form
officers fill in, and stopped matching it the moment the form changed.

It now renders the form from the form:

1. fetch `inspection.html`;
2. take its `<style>` and its `#inspectionForm`;
3. build the contravention grids from that file's own `COMMON_SECTIONS` /
   `OTHER_SECTIONS`; rebuild the plant rows from the record; fill every control
   by its `name` (which is its column), normalising timestamps for date inputs,
   appending an option when a stored value is no longer in a dropdown, and
   keeping the form's blank for anything the record does not carry;
4. lock it — `readonly`, `tabindex="-1"`, `pointer-events: none`, submit
   blocked — and drop what only makes sense while filling it in (Reset/Submit,
   Add/Remove row, the booking-link row).

The builder is pure — `buildInspectionFormView(sourceText, record, opts)` returns
`{ css, html }` — which is why the harness can run it against the real form file.
Printing the page prints the form: the bar and any note are hidden, cards do not
break across pages, and colours (ticked sections, the compliance boxes) are kept.

**Two deliberate consequences.** The view cannot drift from the form, and it also
fails loudly rather than quietly: if the form's section lists ever change shape,
the builder returns `null` and the page says so instead of showing an empty grid.
And because the page's CSP forbids `eval`, the section lists are parsed, not
evaluated — that is the check that caught the grids rendering empty.

---

## 4. Verification

`scripts/branch-compliance-check.html` — 103 checks, **0 failing**. It loads the
real `common.js`, and for the branch detail view it extracts
`openComplianceModal()` / `closeComplianceModal()` / `esc()` **out of
company-branches.html and runs them against a parsed document**, so that part is
tested by driving the shipped function rather than by reading its source. It
exercises the real helpers plus the delivered page sources:

* the compliance maths, including unrated branches, unknown branch ids, missing
  scores and empty input;
* `branchInspections` — a branch's own records, newest first, safe on unknown
  branches and missing input — and that `getCompanyCompliance` hands back the
  inspection rows alongside the figures so the detail view needs no second query;
* `getCompanyBranches` / `columnExists` / `getCompanyInspections` against stubs
  for success, missing table (`PGRST205`), missing column (`42703`) and
  unexpected failure;
* that the branch dropdown sits between the business name and the location
  field in both forms, that `branch_id` is payload-guarded and column-gated,
  and that no page selects `branch_id` explicitly;
* that My Branches has a **View** action and detail modal, that the compliance
  figure in the table opens it, and that the detail lists that branch's
  inspections with a link to each full report;
* the detail view's live behaviour: it names the branch and its rating, lists
  only that branch's records newest-first, excludes other branches and general
  inspections, links each record to its full report, shows and closes, replaces
  (not appends) when switching branches, and renders an empty state with no fake
  0% for a branch that has never been inspected;
* the booking rules: open bookings stay linkable while completed and cancelled
  ones do not (case-insensitively, and a missing status is not a blocker);
  completion is attempted from all three open states and reports the booking it
  closed; an already-closed booking is reported rather than resurrected; a
  rejected completion comes back as a result instead of throwing; no booking id
  means no write; and the form no longer swallows the failure but names
  `booking-completion-migration.sql`;
* both migrations' shape (idempotent `ADD COLUMN IF NOT EXISTS`, FKs with
  `ON DELETE SET NULL`, the widened guard, terminal states still terminal,
  `BEGIN`/`COMMIT`, indexes, verification queries);
* the record view, by running its **real builder against the real
  `inspection.html`**: the same sections in the same order, the form's own
  stylesheet, every named field present (minus the booking-link row), no submit /
  reset / add-remove / booking-link controls, no inline handler left, values and
  narratives shown, a timestamped inspection date shown as a date, employee
  totals, a 17 + 14 section grid carrying the form's own text and highlight
  class, tick state read from both the boolean columns and the array
  (case-insensitively), stored compliance figures shown and computed the form's
  way when absent, plant rows rebuilt (one blank row when there is no plant,
  five cells, no ✕), premise shown by its branch label, the follow-up row
  revealed/hidden exactly as the form has it, a retired dropdown value still
  displayed, the **real `lockForm()`** applied to the output, print rules
  present, and `null` — not a half-rendered record — when the form's section
  lists change shape or the source carries no form.

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
* The record view was verified by rendering it in a browser against a stubbed
  record (identical markup, stylesheet and computed layout to the form), but
  **no print engine was exercised** — the print rules are asserted as present and
  the layout was checked at the width an A4 portrait page box gives (703 CSS px),
  where the form's own `max-width: 768px` rules apply, exactly as they do when
  `inspection.html` itself is printed. Add `@page { size: A4 landscape }` if a
  printed record should keep the wide on-screen grid instead.
* Inspections recorded before the migration have no branch and count as general
  inspections. Backfilling them onto branches would need a mapping decision
  (employer name and address are the only clues) and is not attempted here.
