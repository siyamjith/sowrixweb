SELECT strpos(pg_get_functiondef('public.sowrix_has_permission(text,text)'::regprocedure),'R101.6A attendance and leave grants')>0 AS actor_guard,
 strpos(pg_get_functiondef('public.sowrix_user_permission(uuid,text,text)'::regprocedure),'R101.6A attendance and leave grants')>0 AS target_guard;
SELECT module_key,actions FROM public.sowrix_permission_catalog WHERE module_key IN ('attendance','leaves') ORDER BY module_key;
SELECT tablename,policyname,cmd,permissive,qual,with_check FROM pg_policies WHERE schemaname='public' AND tablename IN ('attendance_records','leave_requests','sowrix_attendance_metadata') ORDER BY tablename,policyname;
SELECT tgname,tgenabled FROM pg_trigger WHERE tgrelid='public.leave_requests'::regclass AND NOT tgisinternal;
-- Review explicit Admin grants before enforcing the new policy on a live database.
SELECT g.module_key,g.actions,g.row_scope,count(*) FROM public.sowrix_action_grants g JOIN public.user_roles r ON r.user_id=g.user_id WHERE r.role::text='admin' AND g.module_key IN ('attendance','leaves') GROUP BY 1,2,3;
