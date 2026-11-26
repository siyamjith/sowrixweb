-- R101 Stage 5 candidate. Apply on isolated staging only after 58; no data backfill.
BEGIN;
DO $guard$
DECLARE f text; old text; next_modules text; item record; n integer;
BEGIN
 old:=$list$('expenses','clients','projects','tasks','invoices','quotations','tickets')$list$;
 next_modules:=$list$('expenses','clients','projects','tasks','invoices','quotations','tickets','employees','payroll','amc')$list$;
 FOR item IN SELECT * FROM (VALUES ('employees','employees'),('payroll_records','payroll'),('sowrix_amc_contracts','amc'),('sowrix_r45_payroll_reviews','payroll')) v(tbl,mod) LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_class WHERE oid=to_regclass('public.'||item.tbl) AND relrowsecurity) THEN RAISE EXCEPTION 'Missing RLS prerequisite: %',item.tbl; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sowrix_permission_catalog WHERE module_key=item.mod AND actions @> ARRAY['view','create','edit']::text[]) THEN RAISE EXCEPTION 'Missing permission catalog: %',item.mod; END IF;
 END LOOP;
 FOR item IN SELECT * FROM (VALUES ('employees'),('payroll_records')) v(tbl) LOOP
  SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public' AND tablename=item.tbl AND permissive='RESTRICTIVE' AND policyname IN ('sowrix_v4_select','sowrix_v4_insert','sowrix_v4_update','sowrix_v4_delete') AND (coalesce(qual,'')||coalesce(with_check,'')) LIKE '%sowrix_has_permission%';
  IF n<>4 THEN RAISE EXCEPTION 'Missing expected restrictive policies: %',item.tbl; END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.payroll_records'::regclass AND tgname='sowrix_v4_approval' AND tgenabled IN ('O','A') AND tgfoid='public.sowrix_approval_guard()'::regprocedure) THEN RAISE EXCEPTION 'Payroll approval guard missing'; END IF;
 f:=pg_get_functiondef('public.sowrix_has_permission(text,text)'::regprocedure);
 IF strpos(f,'R101.4 business grants')=0 THEN RAISE EXCEPTION 'Install migration 58 first'; END IF;
 IF strpos(f,'R101.5 people grants')=0 THEN
  IF (length(f)-length(replace(f,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'Unexpected current actor permission helper'; END IF;
  f:=replace(f,old,next_modules||' /* R101.5 people grants */');
  old:=$roles$public.sowrix_access_role() NOT IN ('hr','hr_staff','hr_manager')$roles$;
  IF (length(f)-length(replace(f,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'Unexpected employee create guard'; END IF;
  EXECUTE replace(f,old,$roles$public.sowrix_access_role() NOT IN ('admin','hr','hr_staff','hr_manager')$roles$);
 END IF;
 old:=$list$('expenses','clients','projects','tasks','invoices','quotations','tickets')$list$;
 f:=pg_get_functiondef('public.sowrix_user_permission(uuid,text,text)'::regprocedure);
 IF strpos(f,'R101.4 business grants')=0 THEN RAISE EXCEPTION 'Install migration 58 target helper first'; END IF;
 IF strpos(f,'R101.5 people grants')=0 THEN
  IF (length(f)-length(replace(f,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'Unexpected target actor permission helper'; END IF;
  EXECUTE replace(f,old,next_modules||' /* R101.5 people grants */');
 END IF;
END $guard$;
UPDATE public.sowrix_permission_catalog SET actions=array_append(actions,'export') WHERE module_key IN ('employees','payroll','amc') AND NOT ('export'=ANY(actions));
-- Restrictive overlays preserve existing ownership checks and non-Admin behavior.
DROP POLICY IF EXISTS sowrix_r1015_amc_read ON public.sowrix_amc_contracts;
CREATE POLICY sowrix_r1015_amc_read ON public.sowrix_amc_contracts AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_access_role() IS DISTINCT FROM 'admin' OR public.sowrix_has_permission('amc','view'));
DROP POLICY IF EXISTS sowrix_r1015_amc_create ON public.sowrix_amc_contracts;
CREATE POLICY sowrix_r1015_amc_create ON public.sowrix_amc_contracts AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IS DISTINCT FROM 'admin' OR public.sowrix_has_permission('amc','create'));
DROP POLICY IF EXISTS sowrix_r1015_amc_edit ON public.sowrix_amc_contracts;
CREATE POLICY sowrix_r1015_amc_edit ON public.sowrix_amc_contracts AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IS DISTINCT FROM 'admin' OR public.sowrix_has_permission('amc','edit')) WITH CHECK (public.sowrix_access_role() IS DISTINCT FROM 'admin' OR public.sowrix_has_permission('amc','edit'));
-- Existing payroll review policy only checks View on INSERT; require Create for Admin.
DROP POLICY IF EXISTS sowrix_r1015_payroll_review_create ON public.sowrix_r45_payroll_reviews;
CREATE POLICY sowrix_r1015_payroll_review_create ON public.sowrix_r45_payroll_reviews AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IS DISTINCT FROM 'admin' OR public.sowrix_has_permission('payroll','create'));
COMMIT;
