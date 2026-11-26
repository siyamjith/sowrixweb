-- Read-only deployment check (does not modify existing data)
SELECT p.proname AS function_name,
       has_function_privilege('authenticated','public.sowrix_employee_attendance_action(text)','EXECUTE') AS employee_rpc_granted
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='sowrix_employee_attendance_action';
