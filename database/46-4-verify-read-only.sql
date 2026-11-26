-- R46.4 read-only verification. Does not open private records or write data.
SELECT p.proname,has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_may_execute,
       NOT has_function_privilege('anon',p.oid,'EXECUTE') AS anon_denied
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname LIKE 'sowrix_r464_%' ORDER BY p.proname;
SELECT c.relname,c.relrowsecurity AS rls_enabled,
       NOT has_table_privilege('authenticated',c.oid,'SELECT') AS authenticated_direct_select_denied
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN ('sowrix_r464_knowledge','sowrix_r464_feedback','sowrix_r464_proposals');
-- Operators must separately test with TWO independent organizations and an anonymous JWT.
