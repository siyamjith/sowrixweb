-- Read-only only. Do not call user-scoped functions as superuser to infer policy.
SELECT p.proname, p.prosecdef AS security_definer,
  has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
  has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('sowrix_r463_hr_snapshot','sowrix_r463_client_snapshot')
ORDER BY p.proname;
