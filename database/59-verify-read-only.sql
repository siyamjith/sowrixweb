SELECT strpos(pg_get_functiondef('public.sowrix_has_permission(text,text)'::regprocedure),'R101.5 people grants')>0 AS actor_guard,
 strpos(pg_get_functiondef('public.sowrix_user_permission(uuid,text,text)'::regprocedure),'R101.5 people grants')>0 AS target_guard;
SELECT module_key,actions FROM public.sowrix_permission_catalog WHERE module_key IN ('employees','payroll','amc') ORDER BY module_key;
SELECT tablename,policyname,cmd,permissive,qual,with_check FROM pg_policies WHERE schemaname='public' AND tablename IN ('employees','payroll_records','sowrix_amc_contracts','sowrix_r45_payroll_reviews') ORDER BY tablename,policyname;
-- Inventory unresolved legacy function checks (not proof of a bypass).
SELECT p.oid::regprocedure::text AS function_name,p.prosecdef AS security_definer FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f' AND p.proname LIKE 'sowrix_%' AND p.prosrc LIKE '%sowrix_access_admin(%' ORDER BY 1;
