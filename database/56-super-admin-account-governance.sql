-- R101 stage 2: protect privileged account lifecycle and access metadata.
-- Apply only after migration 55, on a disposable/staging database first.
-- This does not change ordinary Admin's legacy business-module privileges.
BEGIN;
DO $migration$
DECLARE fn regprocedure; definition text; marker text; guard text; sig text;
BEGIN
 FOREACH sig IN ARRAY ARRAY['public.sowrix_save_team_access(uuid,text,jsonb,text,boolean,bigint,text,text)','public.sowrix_team_access_v4()','public.sowrix_list_team_access()'] LOOP
  fn:=to_regprocedure(sig);
  IF fn IS NULL OR strpos(pg_get_functiondef(fn),'Super Admin access required')=0 THEN
   RAISE EXCEPTION 'Apply and verify migration 55 first: %',sig;
  END IF;
 END LOOP;
 fn:=to_regprocedure('public.sowrix_set_account_enabled(uuid,boolean,text)');
 IF fn IS NULL THEN RAISE EXCEPTION 'Missing account lifecycle prerequisite'; END IF;
 definition:=pg_get_functiondef(fn);
 marker:='PERFORM public.sowrix_require_secure_session(true);';
 guard:=$guard$-- R101.2 privileged target guard
 PERFORM pg_advisory_xact_lock(193740621);
 IF public.sowrix_access_role() IS DISTINCT FROM 'super_admin' AND EXISTS(
  SELECT 1 FROM public.user_roles WHERE user_id=p_user_id AND lower(role::text) IN ('admin','super_admin')
 ) THEN RAISE EXCEPTION 'Only Super Admin can change Administrator account status' USING ERRCODE='42501'; END IF;$guard$;
 IF strpos(definition,'-- R101.2 privileged target guard')=0 THEN
  IF (length(definition)-length(replace(definition,marker,'')))/length(marker)<>1 THEN
   RAISE EXCEPTION 'Unexpected account lifecycle definition; review installed version';
  END IF;
  EXECUTE replace(definition,marker,marker||E'\n '||guard);
 END IF;
END $migration$;
-- Restrictive policies are ANDed with existing permissive policies. Keep own access
-- readable for existing HR/employee/client sessions; only Super Admin may inspect others.
DO $policies$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['sowrix_action_grants','sowrix_module_access','sowrix_access_changes'] LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname=t AND c.relrowsecurity) THEN
   RAISE EXCEPTION 'Missing RLS-enabled prerequisite: %',t;
  END IF;
  EXECUTE format('DROP POLICY IF EXISTS sowrix_r1012_governance_read ON public.%I',t);
  IF t='sowrix_access_changes' THEN
   EXECUTE format('CREATE POLICY sowrix_r1012_governance_read ON public.%I AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_secure_session_allowed() AND public.sowrix_access_role() = ''super_admin'')',t);
  ELSE
   EXECUTE format('CREATE POLICY sowrix_r1012_governance_read ON public.%I AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_secure_session_allowed() AND (user_id=auth.uid() OR public.sowrix_access_role() = ''super_admin''))',t);
  END IF;
 END LOOP;
END $policies$;
COMMIT;
