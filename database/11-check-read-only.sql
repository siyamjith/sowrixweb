-- SOWRIX R27: Supabase SQL Editor preflight for migration 11.
-- STRICTLY READ ONLY. It does not install or modify anything.
-- Use on the intended Supabase staging project; check project identity first.
BEGIN TRANSACTION READ ONLY;
SELECT
  to_regprocedure('public.sowrix_secure_session_allowed()') IS NOT NULL AS release_10_foundation_present,
  to_regclass('public.clients') IS NOT NULL AS clients_foundation_present,
  to_regclass('public.sowrix_def_orgs') IS NOT NULL AS migration_11_orgs_present,
  to_regclass('public.sowrix_def_sessions') IS NOT NULL AS migration_11_sessions_present,
  to_regclass('public.sowrix_def_devices') IS NOT NULL AS migration_11_devices_present,
  to_regprocedure('public.sowrix_def_request(text,uuid,jsonb)') IS NOT NULL AS migration_11_rpc_present,
  to_regprocedure('public.sowrix_def_collector(text,text,jsonb)') IS NOT NULL AS migration_11_collector_rpc_present,
  to_regprocedure('public.sowrix_def_internal_request(text,uuid,jsonb)') IS NOT NULL AS later_hardening_r13_present;
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename IN
  ('sowrix_def_orgs','sowrix_def_sessions','sowrix_def_devices','sowrix_def_members')
ORDER BY tablename;
COMMIT;
-- If migration 11 is already present, NEVER blindly rerun it: newer releases
-- modify/restrict RPC functions, and a rerun could roll back security hardening.
