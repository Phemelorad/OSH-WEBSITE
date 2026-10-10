-- ─────────────────────────────────────────────────────────────────────────────
-- Storage: Form 19 investigation evidence bucket
--
-- Fixes the HTTP 400 that every evidence upload returns from OHS_Form19_Full.html:
--
--   POST /storage/v1/object/form-19-evidence/... -> 400 (Bad Request)
--   "Bucket not found"
--
-- The page uploaded to this bucket but nothing in the project ever created it
-- (it was never in any .sql file). A missing bucket is reported by Supabase
-- Storage as a plain 400, which is why it looked like a client-side failure.
--
-- The bucket is PRIVATE on purpose: OHS_Form19_Full.html stores only the object
-- path and mints short-lived signed URLs when a file is opened, so accident
-- photos and injury details are readable by signed-in officers only. There is
-- deliberately NO public read policy below - do not add one.
--
-- Idempotent: safe to run repeatedly. Run in Supabase -> SQL Editor -> New query.
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ── 1. The bucket ────────────────────────────────────────────────────────────
-- file_size_limit: 25 MiB (26214400 bytes).
-- allowed_mime_types is left NULL (accept anything) so a legitimate file type
-- never turns into a confusing 400. To restrict uploads to the types the page's
-- file picker offers, replace NULL with:
--   ARRAY['image/jpeg','image/png','image/gif','image/webp','application/pdf',
--         'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
--         'text/plain','application/zip']
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('form-19-evidence', 'form-19-evidence', false, 26214400, NULL)
ON CONFLICT (id) DO UPDATE
    SET public          = false,
        file_size_limit = EXCLUDED.file_size_limit;

-- ── 2. Access policies on storage.objects ────────────────────────────────────
-- Role rules copied from fix_rls_policies.sql for ohs_form_19: Form 19 is worked
-- on by admin / super_admin / officer accounts.

DROP POLICY IF EXISTS "Form 19 evidence: officers can read"   ON storage.objects;
DROP POLICY IF EXISTS "Form 19 evidence: officers can upload" ON storage.objects;
DROP POLICY IF EXISTS "Form 19 evidence: officers can update" ON storage.objects;
DROP POLICY IF EXISTS "Form 19 evidence: officers can delete" ON storage.objects;

CREATE POLICY "Form 19 evidence: officers can read"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'form-19-evidence'
    AND EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_id = auth.uid()
          AND role IN ('admin', 'super_admin', 'officer')
    )
);

CREATE POLICY "Form 19 evidence: officers can upload"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'form-19-evidence'
    AND EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_id = auth.uid()
          AND role IN ('admin', 'super_admin', 'officer')
    )
);

-- Uploads use  upsert: false, but keep UPDATE so a re-upload over an existing
-- path is not silently blocked if that changes.
CREATE POLICY "Form 19 evidence: officers can update"
ON storage.objects FOR UPDATE TO authenticated
USING (
    bucket_id = 'form-19-evidence'
    AND EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_id = auth.uid()
          AND role IN ('admin', 'super_admin', 'officer')
    )
)
WITH CHECK (
    bucket_id = 'form-19-evidence'
    AND EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_id = auth.uid()
          AND role IN ('admin', 'super_admin', 'officer')
    )
);

CREATE POLICY "Form 19 evidence: officers can delete"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'form-19-evidence'
    AND EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_id = auth.uid()
          AND role IN ('admin', 'super_admin', 'officer')
    )
);

COMMIT;

-- ── Verify ───────────────────────────────────────────────────────────────────
-- Expect: form-19-evidence | public = false | 4 policies
--
--   SELECT id, public, file_size_limit FROM storage.buckets WHERE id = 'form-19-evidence';
--
--   SELECT policyname, cmd FROM pg_policies
--   WHERE schemaname = 'storage' AND tablename = 'objects'
--     AND policyname LIKE 'Form 19 evidence%'
--   ORDER BY policyname;
