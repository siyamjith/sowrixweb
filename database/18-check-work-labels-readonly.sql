-- SOWRIX R31 - READ ONLY - inspect RPC required by Client/CRM assigned staff labels.
-- Never apply historical migrations simply because PostgREST cache misses a function.
SELECT to_regprocedure('public.sowrix_work_labels(text,uuid[])') AS expected_rpc;
SELECT p.oid::regprocedure AS signature, p.prosecdef AS is_security_definer
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='sowrix_work_labels';
-- Also confirm 'authenticated' has EXECUTE permission according to existing policy.
SELECT has_function_privilege('authenticated','public.sowrix_work_labels(text,uuid[])','EXECUTE') AS authenticated_can_execute
WHERE to_regprocedure('public.sowrix_work_labels(text,uuid[])') IS NOT NULL;
