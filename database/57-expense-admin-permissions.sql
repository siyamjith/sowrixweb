-- Stage 3 pilot: Expenses only. Stage on a restored copy first.
BEGIN;
DO $check$
DECLARE f text; p text; n integer;
BEGIN
 IF strpos(pg_get_functiondef('public.sowrix_set_account_enabled(uuid,boolean,text)'::regprocedure),'R101.2 privileged target guard')=0 OR strpos(pg_get_functiondef('public.sowrix_save_team_access(uuid,text,jsonb,text,boolean,bigint,text,text)'::regprocedure),'Super Admin access required')=0 THEN RAISE EXCEPTION 'Apply migrations 55 and 56 first'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_class WHERE oid='public.expenses'::regclass AND relrowsecurity) THEN RAISE EXCEPTION 'Expenses RLS missing'; END IF;
 SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public' AND tablename='expenses' AND permissive='RESTRICTIVE' AND policyname IN ('sowrix_v4_select','sowrix_v4_insert','sowrix_v4_update','sowrix_v4_delete') AND (coalesce(qual,'')||coalesce(with_check,'')) LIKE '%sowrix_has_permission%';
 IF n<>4 THEN RAISE EXCEPTION 'Expected expense policies missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.expenses'::regclass AND tgname='sowrix_v4_approval' AND tgenabled IN ('O','A') AND tgfoid='public.sowrix_approval_guard()'::regprocedure) THEN RAISE EXCEPTION 'Expense approval trigger missing'; END IF;
 f:=pg_get_functiondef('public.sowrix_has_permission(text,text)'::regprocedure);
 p:='(public.sowrix_access_admin() OR (';
 IF strpos(f,'R101.3 expense grant')=0 THEN
  IF (length(f)-length(replace(f,p,'')))/length(p)<>1 THEN RAISE EXCEPTION 'Unexpected permission helper definition'; END IF;
  EXECUTE replace(f,p,$guard$(/* R101.3 expense grant */ (public.sowrix_access_admin() AND NOT (public.sowrix_access_role()='admin' AND p_module='expenses')) OR ($guard$);
 END IF;
END $check$;
-- Export controls the app's CSV action only, not copying data already visible to a reader.
UPDATE public.sowrix_permission_catalog SET actions=array_append(actions,'export') WHERE module_key='expenses' AND NOT ('export'=ANY(actions));
-- Prevent approval-only users from changing expense status to a non-approval state
-- unless transitioning from an approved state (existing approval guard handles those).
CREATE OR REPLACE FUNCTION public.sowrix_r1013_expense_status_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF public.sowrix_access_role()='admin' AND NEW.status IS DISTINCT FROM OLD.status AND NOT public.sowrix_has_permission('expenses','edit') AND NOT (NEW.status IN ('approved','rejected','paid') OR OLD.status IN ('approved','rejected','paid')) THEN
  RAISE EXCEPTION 'Expense edit permission required' USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_r1013_expense_status_guard() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS sowrix_r1013_expense_status ON public.expenses;
CREATE TRIGGER sowrix_r1013_expense_status BEFORE UPDATE ON public.expenses FOR EACH ROW EXECUTE FUNCTION public.sowrix_r1013_expense_status_guard();
COMMIT;
