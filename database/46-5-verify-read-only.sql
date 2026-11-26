-- After staging migration; expect RLS TRUE, direct SELECT denied, anonymous EXECUTE denied.
SELECT c.relname,c.relrowsecurity AS rls_on,
 NOT has_table_privilege('authenticated',c.oid,'SELECT') AS direct_read_denied
FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid
WHERE n.nspname='public' AND c.relname IN
 ('sowrix_r465_documents','sowrix_r465_document_versions','sowrix_r465_staff_requests');
SELECT p.proname,has_function_privilege('authenticated',p.oid,'EXECUTE') AS allowed_for_signed_in,
 NOT has_function_privilege('anon',p.oid,'EXECUTE') AS anonymous_denied
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname LIKE 'sowrix_r465_%' ORDER BY p.proname;
-- Mandatory manual verification: two tenants, direct PostgREST/Storage denials, revoked
-- session, client vs HR data, self-approval, versions and documents expiration.
