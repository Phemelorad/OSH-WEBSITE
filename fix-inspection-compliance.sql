-- ============================================================
-- FIX: Backfill compliance totals for existing inspection records
-- Run this ONCE in Supabase SQL Editor to fix old records where
-- the boolean columns were not set and totals show as 0.
-- ============================================================

-- Step 1: Set individual boolean columns from the contraventions array
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
WHERE contraventions IS NOT NULL
  AND array_length(contraventions, 1) > 0;

-- Step 2: Recompute totals from the boolean columns
-- (The trigger fires on UPDATE so after Step 1 these will be recalculated,
--  but run this as a belt-and-braces fix in case trigger didn't fire)
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

-- ── Verify the fix ────────────────────────────────────────────
SELECT
    file_number,
    factory_name,
    contraventions,
    total_contraventions,
    non_compliance_pct,
    compliance_level
FROM workplace_inspections
ORDER BY inspection_date DESC
LIMIT 20;

SELECT 'Fix applied successfully!' AS status;
