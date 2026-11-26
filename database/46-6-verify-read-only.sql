-- Read-only post-migration structural checks. Run in SQL editor after R46.6 migration.
SELECT n.nspname AS schema_name,c.relname AS object_name,c.relrowsecurity AS rls_enabled
FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid
WHERE n.nspname='public' AND c.relname LIKE 'sowrix_r466_%' AND c.relkind='r'
ORDER BY c.relname;
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer,
       p.proconfig AS function_options
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname LIKE 'sowrix_r466_%'
ORDER BY p.proname;
SELECT table_name,privilege_type,grantee FROM information_schema.role_table_grants
WHERE table_schema='public' AND table_name LIKE 'sowrix_r466_%'
  AND grantee IN ('anon','authenticated','PUBLIC') ORDER BY table_name;
-- Should return 0 for direct table privileges to anon/authenticated.
-- Test actual tenant A/B users with normal authenticated JWTs (not service-role) separately.
