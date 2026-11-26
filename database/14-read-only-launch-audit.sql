-- Read-only inspection. Do not treat a clean result as a complete security audit.
SELECT p.proname, p.prosecdef AS security_definer,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE') AS service_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN
 ('sowrix_def_request','sowrix_def_request_v12','sowrix_def_internal_request',
 'sowrix_def_collector','sowrix_def_collector_v11','sowrix_def_bootstrap')
ORDER BY p.proname;

SELECT c.relname,c.relrowsecurity,
 has_table_privilege('anon',c.oid,'SELECT') AS anon_read,
 has_table_privilege('authenticated',c.oid,'INSERT,UPDATE,DELETE') AS browser_mutation
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='r' AND c.relname LIKE 'sowrix_def_%'
ORDER BY c.relname;

SELECT organization_id,lower(btrim(name)) AS normalized_name,count(*) AS records
FROM public.sowrix_def_sites GROUP BY organization_id,lower(btrim(name)) HAVING count(*)>1;

SELECT conname,pg_get_constraintdef(oid) AS definition FROM pg_constraint
WHERE conrelid='public.user_roles'::regclass AND contype='c';
