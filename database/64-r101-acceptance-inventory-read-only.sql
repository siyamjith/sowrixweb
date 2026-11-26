-- R101 Stage 7: final-state inventory, not a migration or runtime authorization test.
-- Run as database owner on isolated staging only. No business rows or credentials returned.
BEGIN TRANSACTION READ ONLY;
WITH expected(sig,marker) AS (VALUES
 ('public.sowrix_has_permission(text,text)','R101.6B recruitment and business content grants'),
 ('public.sowrix_user_permission(uuid,text,text)','R101.6B recruitment and business content grants'),
 ('public.sowrix_set_account_enabled(uuid,boolean,text)','R101.2 privileged target guard'),
 ('public.sowrix_save_team_access(uuid,text,jsonb,text,boolean,bigint,text,text)','Super Admin access required'),
 ('public.sowrix_team_access_v4()','Super Admin access required'),
 ('public.sowrix_list_team_access()','Super Admin access required'),
 ('public.sowrix_r465_document_list()','R101.6B'),
 ('public.sowrix_r465_document_create(text,text,text,text,uuid,date)','R101.6B'),
 ('public.sowrix_r465_document_version(uuid,text)','R101.6B'),
 ('public.sowrix_r465_document_approve(uuid)','R101.6B'),
 ('public.sowrix_r467_board(text)','R101.6C summary guard'),
 ('public.sowrix_r467_apply(text,jsonb)','R101.6B'),
 ('public.sowrix_cms_admin(text,text,text,jsonb)','R101.6B'),
 ('public.sowrix_r462_admin_pulse()','R101.6C summary guard'),
 ('public.sowrix_r462_activity()','R101.6C summary guard'),
 ('public.sowrix_r464_admin_overview()','R101.6C summary guard'),
 ('public.sowrix_r463_hr_snapshot()','R101.6C summary guard'),
 ('public.sowrix_set_staff_scope(uuid,uuid,text,boolean,text)','R101.6D'),
 ('public.sowrix_set_event_recipient(text,uuid,boolean)','R101.6D'),
 ('public.sowrix_retry_business_mail(uuid)','R101.6D'),
 ('public.sowrix_business_delivery_status()','R101.6D'),
 ('public.sowrix_work_admin_settings()','R101.6D'),
 ('public.sowrix_r462_configure(boolean,boolean)','R101.6D'),
 ('public.sowrix_r462_pool_member(uuid,boolean)','R101.6D'),
 ('public.sowrix_early_access_admin(text,jsonb)','R101.6D'),
 ('public.sowrix_manage_dw_interest(text,jsonb)','R101.6D'))
SELECT sig, to_regprocedure(sig) IS NOT NULL AS exists_now,
 coalesce(strpos(pg_get_functiondef(to_regprocedure(sig)),marker)>0,false) AS marker_present FROM expected ORDER BY sig;
SELECT module_key,actions,admin_only FROM public.sowrix_permission_catalog ORDER BY module_key;
SELECT n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','storage') AND c.relkind IN ('r','p') ORDER BY 1,2;
SELECT schemaname,tablename,policyname,permissive,cmd,roles,qual,with_check FROM pg_policies WHERE schemaname IN ('public','storage') ORDER BY 1,2,3;
SELECT id,public FROM storage.buckets WHERE id IN ('sowrix-private','resumes');
SELECT has_table_privilege('authenticated','public.sowrix_early_access_requests','UPDATE') AS direct_update_still_granted;
-- Review callable privileged routines; presence alone does not establish a vulnerability.
SELECT p.oid::regprocedure AS routine, has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anonymous_execute
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef ORDER BY 1;
ROLLBACK;
