-- Stage 4 pilot: explicit ordinary-Admin grants for six additional business modules.
-- Apply only to a restored staging copy after reviewing existing Admin grants.
BEGIN;
DO $guard$
DECLARE f text; old text; item record; n int;
BEGIN
 f:=pg_get_functiondef('public.sowrix_has_permission(text,text)'::regprocedure);
 IF strpos(f,'R101.3 expense grant')=0 THEN RAISE EXCEPTION 'Install migrations 55-57 first'; END IF;
 FOR item IN SELECT * FROM (VALUES ('clients','clients'),('projects','projects'),('tasks','tasks'),('invoices','invoices'),('quotations','quotations'),('support_tickets','tickets')) v(tbl,mod) LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_class WHERE oid=to_regclass('public.'||item.tbl) AND relrowsecurity) THEN RAISE EXCEPTION 'RLS missing: %',item.tbl; END IF;
  SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public' AND tablename=item.tbl AND permissive='RESTRICTIVE' AND policyname IN ('sowrix_v4_select','sowrix_v4_insert','sowrix_v4_update','sowrix_v4_delete') AND (coalesce(qual,'')||coalesce(with_check,'')) LIKE '%sowrix_has_permission%';
  IF n<>4 THEN RAISE EXCEPTION 'Expected restrictive policies missing: %',item.tbl; END IF;
 END LOOP;
 IF strpos(f,'R101.4 business grants')=0 THEN
  old:='p_module=''expenses''';
  IF (length(f)-length(replace(f,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'Unexpected permission helper'; END IF;
  EXECUTE replace(f,old,$replacement$p_module IN ('expenses','clients','projects','tasks','invoices','quotations','tickets') /* R101.4 business grants */$replacement$);
 END IF;
 f:=pg_get_functiondef('public.sowrix_user_permission(uuid,text,text)'::regprocedure);
 IF strpos(f,'R101.4 business grants')=0 THEN
  old:='lower(r.role::text) IN (''admin'',''super_admin'')';
  IF (length(f)-length(replace(f,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'Unexpected target permission helper'; END IF;
  EXECUTE replace(f,old,$replacement$(lower(r.role::text)='super_admin' OR (lower(r.role::text)='admin' AND p_module NOT IN ('expenses','clients','projects','tasks','invoices','quotations','tickets'))) /* R101.4 business grants */$replacement$);
 END IF;
END $guard$;
UPDATE public.sowrix_permission_catalog SET actions=array_append(actions,'export') WHERE module_key IN ('clients','projects','tasks','invoices','quotations','tickets') AND NOT ('export'=ANY(actions));
COMMIT;
