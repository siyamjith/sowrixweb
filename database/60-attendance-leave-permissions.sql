-- R101 Stage 6A candidate. Apply only to an isolated staging copy after 59.
BEGIN;
DO $guard$
DECLARE f text; old text; replacement text; item record; n integer;
BEGIN
 old:=$list$('expenses','clients','projects','tasks','invoices','quotations','tickets','employees','payroll','amc')$list$;
 replacement:=$list$('expenses','clients','projects','tasks','invoices','quotations','tickets','employees','payroll','amc','attendance','leaves') /* R101.6A attendance and leave grants */$list$;
 FOR item IN SELECT * FROM (VALUES ('attendance_records','attendance'),('leave_requests','leaves')) v(tbl,mod) LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_class WHERE oid=to_regclass('public.'||item.tbl) AND relrowsecurity) THEN RAISE EXCEPTION 'RLS missing: %',item.tbl; END IF;
  SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public' AND tablename=item.tbl AND permissive='RESTRICTIVE' AND policyname IN ('sowrix_v4_select','sowrix_v4_insert','sowrix_v4_update','sowrix_v4_delete') AND (coalesce(qual,'')||coalesce(with_check,'')) LIKE '%sowrix_has_permission%';
  IF n<>4 THEN RAISE EXCEPTION 'Expected restrictive policies missing: %',item.tbl; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sowrix_permission_catalog WHERE module_key=item.mod AND actions @> ARRAY['view','create','edit']::text[]) THEN RAISE EXCEPTION 'Missing permission catalog: %',item.mod; END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.leave_requests'::regclass AND tgname='sowrix_v4_approval' AND tgenabled IN ('O','A') AND tgfoid='public.sowrix_approval_guard()'::regprocedure) THEN RAISE EXCEPTION 'Leave approval trigger missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_permission_catalog WHERE module_key='leaves' AND 'approve'=ANY(actions)) THEN RAISE EXCEPTION 'Leave approval catalog missing'; END IF;
 f:=pg_get_functiondef('public.sowrix_has_permission(text,text)'::regprocedure);
 IF strpos(f,'R101.5 people grants')=0 THEN RAISE EXCEPTION 'Install migration 59 first'; END IF;
 IF strpos(f,'R101.6A attendance and leave grants')=0 THEN
  IF (length(f)-length(replace(f,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'Unexpected actor permission helper'; END IF;
  f:=replace(f,old,replacement);
  IF strpos(f,$a$NOT (p_module='attendance' AND p_action<>'view')$a$)=0 THEN RAISE EXCEPTION 'Expected attendance guard missing'; END IF;
  EXECUTE replace(f,$a$NOT (p_module='attendance' AND p_action<>'view')$a$,$a$NOT (p_module='attendance' AND p_action<>'view' AND public.sowrix_access_role() IS DISTINCT FROM 'admin')$a$);
 END IF;
 f:=pg_get_functiondef('public.sowrix_user_permission(uuid,text,text)'::regprocedure);
 IF strpos(f,'R101.5 people grants')=0 THEN RAISE EXCEPTION 'Install migration 59 target helper first'; END IF;
 IF strpos(f,'R101.6A attendance and leave grants')=0 THEN
  IF (length(f)-length(replace(f,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'Unexpected target permission helper'; END IF;
  f:=replace(f,old,replacement);
  IF strpos(f,$a$NOT(p_module='attendance' AND p_action<>'view')$a$)=0 THEN RAISE EXCEPTION 'Expected target attendance guard missing'; END IF;
  EXECUTE replace(f,$a$NOT(p_module='attendance' AND p_action<>'view')$a$,$a$NOT(p_module='attendance' AND p_action<>'view' AND lower(r.role::text) IS DISTINCT FROM 'admin')$a$);
 END IF;
END $guard$;
UPDATE public.sowrix_permission_catalog SET actions=array_append(actions,'export') WHERE module_key IN ('attendance','leaves') AND NOT ('export'=ANY(actions));
-- Preserve existing approval trigger; approval-only Admin may decide pending requests,
-- but may not use the approval grant for arbitrary status edits.
CREATE OR REPLACE FUNCTION public.sowrix_r1016_leave_status_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF public.sowrix_access_role()='admin' AND NOT public.sowrix_has_permission('leaves','edit') AND NEW.status IS DISTINCT FROM OLD.status AND NOT (OLD.status='pending' AND NEW.status IN ('approved','rejected') AND public.sowrix_has_permission('leaves','approve')) THEN
  RAISE EXCEPTION 'Leave edit permission required' USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_r1016_leave_status_guard() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS sowrix_r1016_leave_status ON public.leave_requests;
CREATE TRIGGER sowrix_r1016_leave_status BEFORE UPDATE ON public.leave_requests FOR EACH ROW EXECUTE FUNCTION public.sowrix_r1016_leave_status_guard();
COMMIT;
