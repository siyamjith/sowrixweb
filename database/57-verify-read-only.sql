SELECT strpos(pg_get_functiondef('public.sowrix_has_permission(text,text)'::regprocedure),'R101.3 expense grant')>0 AS expense_guard_present;
SELECT module_key,actions FROM public.sowrix_permission_catalog WHERE module_key='expenses';
SELECT policyname,cmd,permissive,qual,with_check FROM pg_policies WHERE schemaname='public' AND tablename='expenses' ORDER BY policyname;
SELECT tgname,tgenabled FROM pg_trigger WHERE tgrelid='public.expenses'::regclass AND tgname IN ('sowrix_v4_approval','sowrix_r1013_expense_status');
-- Counts only: review explicit grants for existing ordinary Admins before applying.
SELECT count(*) AS admins, count(g.user_id) AS admins_with_expense_grants FROM public.user_roles r LEFT JOIN public.sowrix_action_grants g ON g.user_id=r.user_id AND g.module_key='expenses' WHERE r.role::text='admin';
