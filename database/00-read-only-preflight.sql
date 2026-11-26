-- Inspection only. Does not modify schema or records.
SELECT to_regprocedure('public.sowrix_secure_session_allowed()') AS release_10_session_guard,
       to_regprocedure('public.sowrix_def_request(text,uuid,jsonb)') AS defensowrix_rpc;
SELECT t.table_name,c.column_name,c.data_type
FROM information_schema.tables t JOIN information_schema.columns c
ON c.table_schema=t.table_schema AND c.table_name=t.table_name
WHERE t.table_schema='public' AND t.table_name IN
 ('clients','user_roles','employees','attendance_records','leave_requests','payroll_records','interviews','sowrix_org_memberships')
ORDER BY t.table_name,c.ordinal_position;
SELECT p.proname, p.prosecdef,
       has_function_privilege('anon',p.oid,'EXECUTE') AS anonymous_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname LIKE 'sowrix_def_%' ORDER BY p.proname;
