-- Inspect as database owner on staging. No records or secrets returned.
BEGIN TRANSACTION READ ONLY;
SELECT to_regprocedure('public.sowrix_set_account_enabled(uuid,boolean,text)') IS NOT NULL AS function_exists,
 coalesce(strpos(pg_get_functiondef(to_regprocedure('public.sowrix_set_account_enabled(uuid,boolean,text)')),'-- R101.2 privileged target guard')>0,false) AS guard_present;
SELECT tablename,policyname,permissive,cmd,roles,qual FROM pg_policies
 WHERE schemaname='public' AND policyname='sowrix_r1012_governance_read' ORDER BY tablename;
ROLLBACK;
