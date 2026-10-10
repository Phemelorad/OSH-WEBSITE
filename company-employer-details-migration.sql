-- ─────────────────────────────────────────────────────────────────────────────
-- Companies: employer details needed by Form 19's Employer Information block
--
-- OHS_Form19_Full.html autofills the employer block from the company register.
-- companies already had company_name, cipa_number, plot_number, street_name,
-- telephone, industry, location and physical_address, but it had nowhere to keep
-- the district, city/town/village or postal address, so those Form 19 fields
-- could never be filled.
--
-- The company's own profile (company-view.html) and the signup form (index.html)
-- are updated alongside this migration to collect and maintain the new fields.
--
-- Idempotent: safe to run repeatedly. Run in Supabase -> SQL Editor -> New query.
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

ALTER TABLE public.companies
    ADD COLUMN IF NOT EXISTS district        TEXT,
    ADD COLUMN IF NOT EXISTS city_town       TEXT,
    ADD COLUMN IF NOT EXISTS postal_address  TEXT;

COMMENT ON COLUMN public.companies.district       IS 'District the employer is located in (Form 19: District)';
COMMENT ON COLUMN public.companies.city_town      IS 'City, town or village of the employer (Form 19: City/Town/Village)';
COMMENT ON COLUMN public.companies.postal_address IS 'Postal address of the employer (Form 19: Postal Address)';

COMMIT;

-- ── Verify ───────────────────────────────────────────────────────────────────
-- Expect the three new columns plus the pre-existing ones Form 19 uses:
--
--   SELECT column_name FROM information_schema.columns
--   WHERE table_schema = 'public' AND table_name = 'companies'
--     AND column_name IN ('district','city_town','postal_address','plot_number',
--                         'street_name','telephone','cipa_number','industry','location')
--   ORDER BY column_name;
