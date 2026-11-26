-- R46.7 AFTER migration: read-only structural checks (not a substitute for tenant tests).
SELECT c.relname AS table_name,c.relrowsecurity AS rls_enabled
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname LIKE 'sowrix_r467_%' AND c.relkind='r'
ORDER BY c.relname;
SELECT p.proname AS function_name,p.prosecdef AS security_definer,p.proconfig AS function_options
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname LIKE 'sowrix_r467_%' ORDER BY p.proname;
SELECT table_name,privilege_type,grantee FROM information_schema.role_table_grants
WHERE table_schema='public' AND table_name LIKE 'sowrix_r467_%'
AND grantee IN('PUBLIC','anon','authenticated') ORDER BY table_name;
-- Expect 0 direct table grants to public, anon and authenticated.
-- ALSO test ordinary Admin, HR, Employee and TWO unrelated Client JWTs. No service-role token in browser.
