-- =============================================================================
-- RLS Policies: BL Form 43/03 & 43/11 — Medical Practitioner Access
-- Run this in Supabase SQL Editor
--
-- Form 43/03 → medical_examination_reports
--   INSERT policy already exists and covers medical_practitioner.
--   Adding UPDATE and SELECT policies so practitioners can edit & view
--   their own submissions.
--
-- Form 43/11 → medical_attendance_notifications
--   Table has NO policies at all — adding full CRUD for practitioners
--   plus read/manage access for admin/super_admin.
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- FORM 43/03 — medical_examination_reports
-- INSERT already covered. Add SELECT + UPDATE for practitioners.
-- ─────────────────────────────────────────────────────────────────────────────

-- SELECT: practitioners see their own records; admins/officers see all
DROP POLICY IF EXISTS "Users can view medical reports" ON public.medical_examination_reports;
CREATE POLICY "Users can view medical reports"
ON public.medical_examination_reports FOR SELECT TO authenticated
USING (
  submitted_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'super_admin', 'officer')
  )
);

-- UPDATE: practitioners can edit only their own records; admins edit all
DROP POLICY IF EXISTS "Medical practitioners can update own reports" ON public.medical_examination_reports;
CREATE POLICY "Medical practitioners can update own reports"
ON public.medical_examination_reports FOR UPDATE TO authenticated
USING (
  submitted_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'super_admin')
  )
)
WITH CHECK (
  submitted_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'super_admin')
  )
);


-- ─────────────────────────────────────────────────────────────────────────────
-- FORM 43/11 — medical_attendance_notifications
-- No policies exist. Enable RLS and create full set.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.medical_attendance_notifications ENABLE ROW LEVEL SECURITY;

-- SELECT: practitioners see their own; admins/officers see all
DROP POLICY IF EXISTS "Users can view medical attendance notifications" ON public.medical_attendance_notifications;
CREATE POLICY "Users can view medical attendance notifications"
ON public.medical_attendance_notifications FOR SELECT TO authenticated
USING (
  submitted_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'super_admin', 'officer')
  )
);

-- INSERT: practitioners, admins, super_admins can create records
DROP POLICY IF EXISTS "Medical practitioners can insert attendance notifications" ON public.medical_attendance_notifications;
CREATE POLICY "Medical practitioners can insert attendance notifications"
ON public.medical_attendance_notifications FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_id = auth.uid()
    AND role IN ('medical_practitioner', 'admin', 'super_admin')
  )
);

-- UPDATE: practitioners edit their own; admins edit all
DROP POLICY IF EXISTS "Medical practitioners can update own attendance notifications" ON public.medical_attendance_notifications;
CREATE POLICY "Medical practitioners can update own attendance notifications"
ON public.medical_attendance_notifications FOR UPDATE TO authenticated
USING (
  submitted_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'super_admin')
  )
)
WITH CHECK (
  submitted_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'super_admin')
  )
);

-- DELETE: admins and super_admins only
DROP POLICY IF EXISTS "Admins can delete attendance notifications" ON public.medical_attendance_notifications;
CREATE POLICY "Admins can delete attendance notifications"
ON public.medical_attendance_notifications FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'super_admin')
  )
);

-- Ensure authenticated role has table-level permissions
GRANT SELECT, INSERT, UPDATE ON public.medical_attendance_notifications TO authenticated;

COMMIT;
