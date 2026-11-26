-- Inspect the installed guard without changing records.
SELECT signature, CASE WHEN to_regprocedure(signature) IS NULL THEN false ELSE strpos(pg_get_functiondef(to_regprocedure(signature)), 'Super Admin access required') > 0 END AS guard_present
FROM (VALUES ('public.sowrix_save_team_access(uuid,text,jsonb,text,boolean,bigint,text,text)'),('public.sowrix_team_access_v4()'),('public.sowrix_list_team_access()')) AS v(signature);
