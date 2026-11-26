-- R101 Stage 6B staging candidate. Apply after 60 and required 46.5, 46.7, 50, 51 migrations.
-- No business records changed. Published job listings and public application intake stay public.
BEGIN;
DO $guard$
DECLARE f text; old text; replacement text; item record; n integer;
BEGIN
 old:=$list$('expenses','clients','projects','tasks','invoices','quotations','tickets','employees','payroll','amc','attendance','leaves')$list$;
 replacement:=$list$('expenses','clients','projects','tasks','invoices','quotations','tickets','employees','payroll','amc','attendance','leaves','jobs','applications','interviews','enquiries','portfolio','blog','documents','crm','editorial') /* R101.6B recruitment and business content grants */$list$;
 FOR item IN SELECT * FROM (VALUES ('jobs','jobs'),('job_applications','applications'),('interviews','interviews'),('contact_enquiries','enquiries'),('portfolio_projects','portfolio'),('blog_posts','blog')) v(tbl,mod) LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_class WHERE oid=to_regclass('public.'||item.tbl) AND relrowsecurity) THEN RAISE EXCEPTION 'RLS missing: %',item.tbl; END IF;
  SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public' AND tablename=item.tbl AND permissive='RESTRICTIVE' AND policyname IN ('sowrix_v4_select','sowrix_v4_update','sowrix_v4_delete') AND (coalesce(qual,'')||coalesce(with_check,'')) LIKE '%sowrix_has_permission%';
  IF n<>3 THEN RAISE EXCEPTION 'Expected restrictive policies missing: %',item.tbl; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sowrix_permission_catalog WHERE module_key=item.mod AND NOT admin_only AND actions @> ARRAY['view','edit']::text[]) THEN RAISE EXCEPTION 'Missing or incompatible permission catalog: %',item.mod; END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_permission_catalog WHERE module_key='documents' AND NOT admin_only AND actions @> ARRAY['view','create','edit','approve']::text[]) THEN RAISE EXCEPTION 'Document catalog missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.job_applications'::regclass AND tgname='sowrix_v4_approval' AND tgenabled IN ('O','A') AND tgfoid='public.sowrix_approval_guard()'::regprocedure) THEN RAISE EXCEPTION 'Application approval guard missing'; END IF;
 FOR item IN SELECT * FROM (VALUES ('public.sowrix_has_permission(text,text)'),('public.sowrix_user_permission(uuid,text,text)')) v(sig) LOOP
  f:=pg_get_functiondef(to_regprocedure(item.sig));
  IF f IS NULL OR strpos(f,'R101.6A attendance and leave grants')=0 THEN RAISE EXCEPTION 'Install migration 60 first: %',item.sig; END IF;
  IF strpos(f,'R101.6B recruitment and business content grants')=0 THEN
   IF (length(f)-length(replace(f,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'Unexpected permission helper: %',item.sig; END IF;
   EXECUTE replace(f,old,replacement);
  END IF;
 END LOOP;
END $guard$;
INSERT INTO public.sowrix_access_modules(module_key,allowed_roles) VALUES ('crm',ARRAY['admin','super_admin']::text[]),('editorial',ARRAY['admin','super_admin']::text[]) ON CONFLICT DO NOTHING;
INSERT INTO public.sowrix_permission_catalog(module_key,label,actions,allow_wide,admin_only) VALUES
 ('crm','Sales CRM',ARRAY['view','create','edit']::text[],false,false),
 ('editorial','Public Editorial CMS',ARRAY['view','create','edit','approve','delete']::text[],false,false)
 ON CONFLICT DO NOTHING;
UPDATE public.sowrix_permission_catalog SET actions=array_append(actions,'export') WHERE module_key IN ('jobs','applications','interviews','enquiries','portfolio','blog') AND NOT ('export'=ANY(actions));
-- Preserve current RPC ownership, grants, secure-session checks and all other logic.
DO $rpc$
DECLARE f text; anchor text; item record; guard text;
BEGIN
 FOR item IN SELECT * FROM (VALUES
  ($v$public.sowrix_r465_document_list()$v$,$v$PERFORM public.sowrix_require_secure_session(false);$v$,$v$IF public.sowrix_access_role()='admin' AND NOT public.sowrix_has_permission('documents','view') THEN RAISE EXCEPTION 'Document view permission required' USING ERRCODE='42501'; END IF;$v$,1)
 ,($v$public.sowrix_r465_document_create(text,text,text,text,uuid,date)$v$,$v$PERFORM public.sowrix_require_secure_session(false);$v$,$v$IF public.sowrix_access_role()='admin' AND NOT public.sowrix_has_permission('documents','create') THEN RAISE EXCEPTION 'Document create permission required' USING ERRCODE='42501'; END IF;$v$,2)
 ,($v$public.sowrix_r465_document_version(uuid,text)$v$,$v$PERFORM public.sowrix_require_secure_session(false);$v$,$v$IF public.sowrix_access_role()='admin' AND NOT public.sowrix_has_permission('documents','edit') THEN RAISE EXCEPTION 'Document edit permission required' USING ERRCODE='42501'; END IF;$v$,3)
 ,($v$public.sowrix_r465_document_approve(uuid)$v$,$v$PERFORM public.sowrix_require_secure_session(false);$v$,$v$IF public.sowrix_access_role()='admin' AND NOT public.sowrix_has_permission('documents','approve') THEN RAISE EXCEPTION 'Document approve permission required' USING ERRCODE='42501'; END IF;$v$,4)
 ,($v$public.sowrix_r465_organization_choices()$v$,$v$PERFORM public.sowrix_require_secure_session(false);$v$,$v$IF public.sowrix_access_role()='admin' AND NOT public.sowrix_has_permission('documents','create') THEN RAISE EXCEPTION 'Document create permission required' USING ERRCODE='42501'; END IF;$v$,5)
 ,($v$public.sowrix_r467_board(text)$v$,$v$PERFORM public.sowrix_require_secure_session(false);$v$,$v$IF public.sowrix_access_role()='admin' AND p_section IN ('crm','enquiries') AND (NOT public.sowrix_has_permission('crm','view') OR (p_section='enquiries' AND NOT public.sowrix_has_permission('enquiries','view'))) THEN RAISE EXCEPTION 'CRM access required' USING ERRCODE='42501'; END IF;$v$,6)
 ,($v$public.sowrix_r467_apply(text,jsonb)$v$,$v$PERFORM public.sowrix_require_secure_session(false);$v$,$v$IF public.sowrix_access_role()='admin' AND p_action IN ('lead_create','lead_stage','lead_followup','lead_note') AND (NOT public.sowrix_has_permission('crm',CASE WHEN p_action='lead_create' THEN 'create' ELSE 'edit' END) OR (p_action='lead_create' AND NOT public.sowrix_has_permission('enquiries','view'))) THEN RAISE EXCEPTION 'CRM action permission required' USING ERRCODE='42501'; END IF;$v$,7)
 ,($v$public.sowrix_cms_admin(text,text,text,jsonb)$v$,$v$IF p_kind IS NULL OR p_kind NOT IN$v$,$v$IF public.sowrix_access_role()='admin' AND NOT public.sowrix_has_permission('editorial',CASE WHEN p_action IN ('list','preview','save') THEN 'view' WHEN p_action IN ('publish','unpublish') THEN 'approve' WHEN p_action='archive' THEN 'delete' WHEN p_action='restore' THEN 'edit' ELSE 'invalid' END) THEN RAISE EXCEPTION 'Editorial permission required' USING ERRCODE='42501'; END IF;$v$,8)
 ,($v$public.sowrix_cms_admin(text,text,text,jsonb)$v$,$v$IF p_action='save' THEN$v$,$v$IF public.sowrix_access_role()='admin' AND p_action='save' AND NOT public.sowrix_has_permission('editorial',CASE WHEN e.id IS NULL THEN 'create' ELSE 'edit' END) THEN RAISE EXCEPTION 'Editorial save permission required' USING ERRCODE='42501'; END IF;$v$,9)
 ) v(sig,anchor_text,guard_text,step) ORDER BY step LOOP
  f:=pg_get_functiondef(to_regprocedure(item.sig)); anchor:=item.anchor_text;
  guard:='/* R101.6B RPC guard '||item.step||' */ '||item.guard_text;
  IF f IS NULL THEN RAISE EXCEPTION 'Required RPC missing: %',item.sig; END IF;
  IF strpos(f,'/* R101.6B RPC guard '||item.step||' */')=0 THEN
   IF (length(f)-length(replace(f,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'Unexpected RPC definition: %',item.sig; END IF;
   IF item.step IN (8,9) THEN EXECUTE replace(f,anchor,guard||E'\n '||anchor);
   ELSE EXECUTE replace(f,anchor,anchor||E'\n '||guard); END IF;
  END IF;
 END LOOP;
END $rpc$;
COMMIT;
