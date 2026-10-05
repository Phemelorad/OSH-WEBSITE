-- ═══════════════════════════════════════════════════════════
-- SUPABASE DELETE QUERY REFERENCE
-- Project: OSH-WEBSITE
--
-- ⚠️  ALWAYS:
--   1. SELECT COUNT(*) first to preview the impact
--   2. Use WHERE clauses (never run blanket DELETE in production)
--   3. Back up your database before bulk deletions
--   4. Test queries in a staging environment first
-- ═══════════════════════════════════════════════════════════

-- ── TEMPLATE: Preview before delete ────────────────────────
-- SELECT COUNT(*) FROM table_name WHERE <condition>;
-- SELECT id, created_at FROM table_name WHERE <condition> LIMIT 20;
-- DELETE FROM table_name WHERE <condition>;


-- ── 1. DELETE BY UUID (most precise) ────────────────────────
-- Replace the UUID with the actual record id:
DELETE FROM ohs_form_19                    WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM accident_reports               WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM accident_injured_persons       WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM injury_claims                  WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM injury_disease_reports         WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM medical_examination_reports    WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM permanent_impairment_reports   WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM workplace_inspections          WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM inspection_bookings            WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM bl_form_43_02_wages            WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM bl_form_43_04_incapacity       WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM certificate_of_insurance       WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM medical_attendance_notifications WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM claim_documents                WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM practitioner_clients           WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM workers_registry               WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM companies                      WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM user_activity_log              WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';
DELETE FROM notifications                  WHERE id = '7f1dd47e-4b11-4f9a-a9d6-68bfa3dc2007';


-- ── 2. DELETE BY REFERENCE NUMBER ─────────────────────────
-- Investigation reference numbers:
DELETE FROM ohs_form_19 WHERE inv_ref_no = 'INV-2026-0001';

-- Accident case numbers:
DELETE FROM accident_reports WHERE accident_case_number = 'ACC-2026-00007';

-- Claim numbers / worker IDs:
DELETE FROM injury_claims WHERE claim_id = 'CLM-2026-00123';


-- ── 3. DELETE BY DATE RANGE ───────────────────────────────
-- Delete old entries (created before a date):
-- SELECT COUNT(*) FROM ohs_form_19 WHERE created_at < '2025-01-01';
DELETE FROM ohs_form_19             WHERE created_at < '2025-01-01'::timestamp;
DELETE FROM accident_reports        WHERE created_at < '2025-01-01'::timestamp;
DELETE FROM injury_claims           WHERE created_at < '2025-01-01'::timestamp;
DELETE FROM injury_disease_reports  WHERE created_at < '2025-01-01'::timestamp;
DELETE FROM medical_examination_reports WHERE created_at < '2025-01-01'::timestamp;
DELETE FROM permanent_impairment_reports  WHERE created_at < '2025-01-01'::timestamp;
DELETE FROM workplace_inspections   WHERE created_at < '2025-01-01'::timestamp;

-- Delete entries within a date range:
DELETE FROM accident_reports
WHERE accident_date >= '2024-01-01'
  AND accident_date <  '2025-01-01';


-- ── 4. DELETE BY STATUS ────────────────────────────────────
-- Clean up draft records:
-- SELECT COUNT(*) FROM accident_reports WHERE status = 'draft';
DELETE FROM accident_reports WHERE status = 'draft';
DELETE FROM injury_claims      WHERE status = 'draft';

-- Delete investigations with a specific status:
DELETE FROM ohs_form_19 WHERE inv_status = 'open'
  AND created_at < '2025-01-01'::timestamp;


-- ── 5. DELETE BY SUBMITTING USER ──────────────────────────
-- Remove all entries submitted by a specific auth user:
-- SELECT COUNT(*) FROM ohs_form_19 WHERE submitted_by = 'auth-uid-here';
DELETE FROM ohs_form_19            WHERE submitted_by = 'auth-uid-here';
DELETE FROM accident_reports        WHERE submitted_by = 'auth-uid-here';
DELETE FROM injury_claims           WHERE user_id = 'auth-uid-here';
DELETE FROM injury_disease_reports  WHERE submitted_by = 'auth-uid-here';


-- ── 6. DELETE TEST DATA (wipe all form submissions) ───────
-- ⚠️  ONLY RUN IN STAGING OR WHEN YOU WANT TO PURGE ALL DATA
-- Run SELECT COUNT(*) on each table first to confirm
DELETE FROM ohs_form_19;
DELETE FROM accident_reports;
DELETE FROM accident_injured_persons;
DELETE FROM injury_claims;
DELETE FROM injury_disease_reports;
DELETE FROM medical_examination_reports;
DELETE FROM permanent_impairment_reports;
DELETE FROM workplace_inspections;
DELETE FROM inspection_bookings;
DELETE FROM bl_form_43_02_wages;
DELETE FROM bl_form_43_04_incapacity;
DELETE FROM certificate_of_insurance;
DELETE FROM medical_attendance_notifications;
DELETE FROM claim_documents;
DELETE FROM practitioner_clients;
DELETE FROM workers_registry;
DELETE FROM companies;
DELETE FROM user_activity_log;
DELETE FROM login_history;
DELETE FROM notifications;


-- ── 7. DELETE RELATED TABLES (order matters for FK refs) ─
-- If you get FK errors, delete child tables before parent tables:
DELETE FROM claim_documents;
DELETE FROM practitioner_clients;
DELETE FROM workers_registry;
DELETE FROM companies;
DELETE FROM accident_injured_persons;
DELETE FROM accident_reports;
DELETE FROM injury_claims;
DELETE FROM injury_disease_reports;
DELETE FROM ohs_form_19;
DELETE FROM medical_examination_reports;
DELETE FROM permanent_impairment_reports;
DELETE FROM bl_form_43_02_wages;
DELETE FROM bl_form_43_04_incapacity;
DELETE FROM certificate_of_insurance;
DELETE FROM medical_attendance_notifications;
DELETE FROM workplace_inspections;
DELETE FROM inspection_bookings;
DELETE FROM user_activity_log;
DELETE FROM notifications;
