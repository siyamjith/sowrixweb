-- Database-owner only. Read-only inventory, no user identities or record contents.
BEGIN TRANSACTION READ ONLY;
SELECT r.role::text AS role, count(*) AS accounts FROM public.user_roles r GROUP BY 1 ORDER BY 1;
SELECT c.module_key,c.actions,c.admin_only,c.allow_wide,
 count(DISTINCT g.user_id) FILTER (WHERE r.role::text='admin') AS admin_accounts_with_explicit_grants
 FROM public.sowrix_permission_catalog c LEFT JOIN public.sowrix_action_grants g USING(module_key)
 LEFT JOIN public.user_roles r ON r.user_id=g.user_id GROUP BY 1,2,3,4 ORDER BY 1;
-- Candidates, not proof of a vulnerability: functions may have additional checks.
SELECT p.oid::regprocedure AS function_signature,p.prosecdef AS security_definer,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prokind='f' AND (
 p.prosrc ILIKE '%sowrix_access_admin(%' OR p.prosrc ILIKE '%''admin''%''super_admin''%' OR p.prosrc ILIKE '%''super_admin''%''admin''%') ORDER BY 1;
SELECT tablename,policyname,cmd,permissive FROM pg_policies WHERE schemaname='public' AND
 (coalesce(qual,'')||coalesce(with_check,'')) ~* '(sowrix_access_admin|super_admin)' ORDER BY 1,2;
ROLLBACK;
