-- ============================================================================
-- Fix SECURITY DEFINER Views
--
-- Supabase Database Linter flagged 19 views with SECURITY DEFINER property.
-- These views were running with the creator's permissions, bypassing RLS.
--
-- This migration switches them to SECURITY INVOKER mode so they respect
-- the calling user's Row Level Security policies.
--
-- Generated: June 13, 2026
-- ============================================================================

-- Views from master-setup.sql and schema_improvements.sql
ALTER VIEW public.active_users_summary       SET (security_invoker = true);
ALTER VIEW public.recent_login_activity      SET (security_invoker = true);
ALTER VIEW public.accident_statistics         SET (security_invoker = true);
ALTER VIEW public.injury_claims_summary       SET (security_invoker = true);
ALTER VIEW public.injury_claims_by_industry   SET (security_invoker = true);
ALTER VIEW public.recent_injury_claims        SET (security_invoker = true);
ALTER VIEW public.claims_requiring_attention  SET (security_invoker = true);
ALTER VIEW public.injury_disease_statistics   SET (security_invoker = true);
ALTER VIEW public.inspection_report_view      SET (security_invoker = true);
ALTER VIEW public.inspection_monthly_summary  SET (security_invoker = true);
ALTER VIEW public.inspection_inspector_summary SET (security_invoker = true);
ALTER VIEW public.contravention_frequency     SET (security_invoker = true);
ALTER VIEW public.inspections_pending_followup SET (security_invoker = true);
ALTER VIEW public.company_register_view       SET (security_invoker = true);
ALTER VIEW public.user_roles_view             SET (security_invoker = true);
ALTER VIEW public.inspections_by_month        SET (security_invoker = true);
ALTER VIEW public.accident_report_view        SET (security_invoker = true);
ALTER VIEW public.injury_disease_report_view  SET (security_invoker = true);
ALTER VIEW public.injury_claims_view          SET (security_invoker = true);

-- ============================================================================
-- Note: If any of these views reference other views or tables where the
-- calling user lacks direct SELECT privileges, you may need to GRANT the
-- necessary permissions. For example:
--
--   GRANT SELECT ON public.<table_name> TO <role>;
--
-- However, in most Supabase setups the anon/authenticated roles already
-- have table-level access via RLS, so this should work out of the box.
-- ============================================================================
