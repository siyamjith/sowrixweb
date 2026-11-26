-- R101 Stage 6D: staging candidate. No business-record updates.
BEGIN;
DO $guard$
DECLARE item record; f text; guard text; anchor text;
BEGIN
 IF strpos(pg_get_functiondef('public.sowrix_r462_admin_pulse()'::regprocedure),'R101.6C summary guard')=0 THEN RAISE EXCEPTION 'Install 62 first'; END IF;
 FOR item IN SELECT * FROM (VALUES
 ('public.sowrix_set_staff_scope(uuid,uuid,text,boolean,text)',true),
 ('public.sowrix_set_event_recipient(text,uuid,boolean)',true),
 ('public.sowrix_retry_business_mail(uuid)',true),
 ('public.sowrix_business_delivery_status()',false),
 ('public.sowrix_work_admin_settings()',false),
 ('public.sowrix_r462_configure(boolean,boolean)',false),
 ('public.sowrix_r462_pool_member(uuid,boolean)',false)) v(sig,fresh) LOOP
  f:=pg_get_functiondef(to_regprocedure(item.sig));
  IF f IS NULL THEN RAISE EXCEPTION 'Missing RPC: %',item.sig; END IF;
  IF strpos(f,'R101.6D settings guard')>0 THEN CONTINUE; END IF;
  anchor:=format('PERFORM public.sowrix_require_secure_session(%s);',CASE WHEN item.fresh THEN 'true' ELSE 'false' END);
  IF (length(f)-length(replace(f,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'Unexpected RPC: %',item.sig; END IF;
  guard:=$body$ /* R101.6D settings guard */ IF public.sowrix_access_role() IS DISTINCT FROM 'super_admin' THEN RAISE EXCEPTION 'Super Admin settings permission required' USING ERRCODE='42501'; END IF;$body$;
  EXECUTE replace(f,anchor,anchor||guard);
 END LOOP;
 FOR item IN SELECT * FROM (VALUES
 ('public.sowrix_early_access_admin(text,jsonb)', 'IF p_data IS NULL OR jsonb_typeof(p_data)',false),
 ('public.sowrix_manage_dw_interest(text,jsonb)', 'IF p_action=''counts'' THEN',true)) v(sig,anchor,dw) LOOP
  f:=pg_get_functiondef(to_regprocedure(item.sig));
  IF f IS NULL THEN RAISE EXCEPTION 'Missing RPC: %',item.sig; END IF;
  IF strpos(f,'R101.6D enquiry guard')>0 THEN CONTINUE; END IF;
  anchor:=item.anchor;
  IF (length(f)-length(replace(f,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'Unexpected RPC: %',item.sig; END IF;
  guard:=$body$ /* R101.6D enquiry guard */
  PERFORM public.sowrix_require_secure_session(false);
  IF public.sowrix_access_role()='admin' THEN
   IF NOT coalesce(public.sowrix_has_permission('enquiries','view'),false) OR NOT coalesce(public.sowrix_has_permission('enquiries',CASE WHEN p_action='export' THEN 'export' WHEN p_action IN ('assign','status','follow_up','update','link_client') THEN 'edit' ELSE 'view' END),false) THEN RAISE EXCEPTION 'Enquiry action permission required' USING ERRCODE='42501'; END IF;
  END IF;
  $body$;
  IF item.dw THEN guard:=guard||$body$ IF public.sowrix_access_role()='admin' AND ((p_action='employees' AND NOT coalesce(public.sowrix_has_permission('employees','view'),false)) OR (p_action='link_client' AND NOT coalesce(public.sowrix_has_permission('clients','edit'),false))) THEN RAISE EXCEPTION 'Related module permission required' USING ERRCODE='42501'; END IF; $body$; END IF;
  EXECUTE replace(f,anchor,guard||anchor);
 END LOOP;
END $guard$;
-- Prevent direct authenticated edits bypassing the workflow RPC; service intake stays intact.
REVOKE UPDATE ON public.sowrix_early_access_requests FROM authenticated;
DROP POLICY IF EXISTS sowrix_r1016d_early_read ON public.sowrix_early_access_requests;
CREATE POLICY sowrix_r1016d_early_read ON public.sowrix_early_access_requests AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_access_role() IS DISTINCT FROM 'admin' OR coalesce(public.sowrix_has_permission('enquiries','view'),false));
DROP POLICY IF EXISTS sowrix_r1016d_history_read ON public.sowrix_early_access_history;
CREATE POLICY sowrix_r1016d_history_read ON public.sowrix_early_access_history AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_access_role() IS DISTINCT FROM 'admin' OR coalesce(public.sowrix_has_permission('enquiries','view'),false));
COMMIT;
