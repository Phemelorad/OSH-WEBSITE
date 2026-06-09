-- ============================================================
--  BACKFILL MIGRATION — One-time data fixes
--  ============================================================
--  Extracted from master-setup.sql Section 12.
--  Run this ONCE after master-setup.sql to normalize existing
--  data and backfill compliance totals.
--  Safe to run multiple times but only needs to run once.
-- ============================================================

-- ── 1. Backfill normalized ID numbers ──────────────────────
-- Trims and uppercases existing Omang/passport values for
-- consistent indexed search across all tables.
UPDATE accident_reports
SET injured_id_number = normalize_identity_id(injured_id_number)
WHERE injured_id_number IS NOT NULL
  AND injured_id_number IS DISTINCT FROM normalize_identity_id(injured_id_number);

UPDATE injury_disease_reports
SET worker_id_number = normalize_identity_id(worker_id_number)
WHERE worker_id_number IS NOT NULL
  AND worker_id_number IS DISTINCT FROM normalize_identity_id(worker_id_number);

UPDATE injury_claims
SET claimant_id_number = normalize_identity_id(claimant_id_number)
WHERE claimant_id_number IS NOT NULL
  AND claimant_id_number IS DISTINCT FROM normalize_identity_id(claimant_id_number);

UPDATE workers_registry
SET id_number = normalize_identity_id(id_number)
WHERE id_number IS DISTINCT FROM normalize_identity_id(id_number);

-- ── 2. Backfill compliance totals for workplace_inspections ──
-- Sets individual boolean columns from the contraventions array
UPDATE workplace_inspections
SET
    s9  = ('S9'  = ANY(contraventions)),
    s13 = ('S13' = ANY(contraventions)),
    s14 = ('S14' = ANY(contraventions)),
    s15 = ('S15' = ANY(contraventions)),
    s16 = ('S16' = ANY(contraventions)),
    s18 = ('S18' = ANY(contraventions)),
    s41 = ('S41' = ANY(contraventions)),
    s42 = ('S42' = ANY(contraventions)),
    s46 = ('S46' = ANY(contraventions)),
    s47 = ('S47' = ANY(contraventions)),
    s48 = ('S48' = ANY(contraventions)),
    s49 = ('S49' = ANY(contraventions)),
    s52 = ('S52' = ANY(contraventions)),
    s53 = ('S53' = ANY(contraventions)),
    s62 = ('S62' = ANY(contraventions)),
    s66 = ('S66' = ANY(contraventions)),
    s67 = ('S67' = ANY(contraventions)),
    s17 = ('S17' = ANY(contraventions)),
    s23 = ('S23' = ANY(contraventions)),
    s29 = ('S29' = ANY(contraventions)),
    s30 = ('S30' = ANY(contraventions)),
    s31 = ('S31' = ANY(contraventions)),
    s32 = ('S32' = ANY(contraventions)),
    s34 = ('S34' = ANY(contraventions)),
    s37 = ('S37' = ANY(contraventions)),
    s38 = ('S38' = ANY(contraventions)),
    s39 = ('S39' = ANY(contraventions)),
    s51 = ('S51' = ANY(contraventions)),
    s54 = ('S54' = ANY(contraventions)),
    s57 = ('S57' = ANY(contraventions)),
    s58 = ('S58' = ANY(contraventions))
WHERE contraventions IS NOT NULL AND array_length(contraventions, 1) > 0;

-- Recompute totals from boolean columns
UPDATE workplace_inspections
SET
    total_contraventions = (
        s9::int + s13::int + s14::int + s15::int + s16::int + s18::int +
        s41::int + s42::int + s46::int + s47::int + s48::int + s49::int +
        s52::int + s53::int + s62::int + s66::int + s67::int
    ),
    non_compliance_pct = ROUND(
        (s9::int + s13::int + s14::int + s15::int + s16::int + s18::int +
         s41::int + s42::int + s46::int + s47::int + s48::int + s49::int +
         s52::int + s53::int + s62::int + s66::int + s67::int)::NUMERIC / 17 * 100
    ),
    compliance_level = 100 - ROUND(
        (s9::int + s13::int + s14::int + s15::int + s16::int + s18::int +
         s41::int + s42::int + s46::int + s47::int + s48::int + s49::int +
         s52::int + s53::int + s62::int + s66::int + s67::int)::NUMERIC / 17 * 100
    );

SELECT '✅ Backfill migration completed successfully!' AS status;
