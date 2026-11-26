-- R15 additive AMC module. Review and back up first; no existing rows are changed.
-- Apply after the supplied R10/R11/R12/R13 foundation. Database 14 is read-only audit.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NULL
 OR to_regprocedure('public.sowrix_org_access(uuid,text)') IS NULL
 OR to_regclass('public.sowrix_permission_catalog') IS NULL THEN
  RAISE EXCEPTION 'Install the complete existing SOWRIX security foundation before AMC';
 END IF;
END $$;
-- Parent module first: avoids the previously reported permission catalogue FK error.
INSERT INTO public.sowrix_access_modules(module_key,allowed_roles)
 VALUES('amc','{super_admin,admin,hr_manager,hr_staff,project_manager,employee,client}')
 ON CONFLICT(module_key) DO NOTHING;
INSERT INTO public.sowrix_permission_catalog(module_key,label,actions,allow_wide,admin_only)
 VALUES('amc','AMC & Service Contracts','{view,create,edit}',true,false)
 ON CONFLICT(module_key) DO NOTHING;
CREATE TABLE IF NOT EXISTS public.sowrix_amc_contracts(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 contract_number text NOT NULL UNIQUE DEFAULT ('AMC-'||upper(replace(gen_random_uuid()::text,'-',''))),
 client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
 client_name text NOT NULL DEFAULT '',
 title text NOT NULL CHECK(char_length(btrim(title)) BETWEEN 2 AND 200),
 services text NOT NULL DEFAULT '' CHECK(char_length(services)<=5000),
 starts_on date NOT NULL,
 ends_on date NOT NULL CHECK(ends_on>=starts_on),
 renewal_notice_days integer NOT NULL DEFAULT 30 CHECK(renewal_notice_days BETWEEN 0 AND 180),
 amount numeric(12,2) NOT NULL DEFAULT 0 CHECK(amount>=0 AND amount<1000000000),
 currency text NOT NULL DEFAULT 'INR' CHECK(currency='INR'),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','active','expired','cancelled')),
 created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sowrix_amc_client_renewal ON public.sowrix_amc_contracts(client_id,ends_on);
CREATE INDEX IF NOT EXISTS sowrix_amc_status_renewal ON public.sowrix_amc_contracts(status,ends_on);
ALTER TABLE public.sowrix_amc_contracts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_amc_contracts FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.sowrix_amc_contracts TO authenticated;
DROP POLICY IF EXISTS sowrix_amc_read ON public.sowrix_amc_contracts;
CREATE POLICY sowrix_amc_read ON public.sowrix_amc_contracts FOR SELECT TO authenticated USING(
 public.sowrix_secure_session_allowed() AND public.sowrix_has_permission('amc','view') AND
 (public.sowrix_access_admin() OR
  (public.sowrix_access_role()<>'client' AND public.sowrix_wide_access('amc','view')) OR
  (public.sowrix_access_role()='client' AND status<>'draft' AND public.sowrix_org_access(client_id,'billing'))));
DROP POLICY IF EXISTS sowrix_amc_create ON public.sowrix_amc_contracts;
CREATE POLICY sowrix_amc_create ON public.sowrix_amc_contracts FOR INSERT TO authenticated WITH CHECK(
 public.sowrix_secure_session_allowed() AND public.sowrix_access_role()<>'client' AND public.sowrix_has_permission('amc','create') AND
 (public.sowrix_access_admin() OR public.sowrix_wide_access('amc','create')));
DROP POLICY IF EXISTS sowrix_amc_edit ON public.sowrix_amc_contracts;
CREATE POLICY sowrix_amc_edit ON public.sowrix_amc_contracts FOR UPDATE TO authenticated USING(
 public.sowrix_secure_session_allowed() AND public.sowrix_access_role()<>'client' AND public.sowrix_has_permission('amc','edit') AND
 (public.sowrix_access_admin() OR public.sowrix_wide_access('amc','edit')))
 WITH CHECK(public.sowrix_secure_session_allowed() AND public.sowrix_access_role()<>'client' AND public.sowrix_has_permission('amc','edit') AND
 (public.sowrix_access_admin() OR public.sowrix_wide_access('amc','edit')));
CREATE OR REPLACE FUNCTION public.sowrix_amc_guard() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  NEW.created_by:=auth.uid();NEW.created_at:=now();
  NEW.contract_number:='AMC-'||upper(replace(gen_random_uuid()::text,'-',''));
  SELECT c.organization_name INTO NEW.client_name FROM public.clients c WHERE c.id=NEW.client_id;
 ELSE
  IF NEW.client_id IS DISTINCT FROM OLD.client_id OR NEW.contract_number IS DISTINCT FROM OLD.contract_number
  OR NEW.created_by IS DISTINCT FROM OLD.created_by OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
   RAISE EXCEPTION 'Contract identity and organization cannot change' USING ERRCODE='23514';
  END IF;
  IF OLD.status='cancelled' AND NEW.status<>'cancelled' THEN
   RAISE EXCEPTION 'Create a new contract to replace a cancelled contract' USING ERRCODE='23514';
  END IF;
  NEW.client_name:=OLD.client_name;
 END IF;
 NEW.title:=btrim(NEW.title);NEW.updated_at:=now();RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS sowrix_amc_guard ON public.sowrix_amc_contracts;
CREATE TRIGGER sowrix_amc_guard BEFORE INSERT OR UPDATE ON public.sowrix_amc_contracts FOR EACH ROW EXECUTE FUNCTION public.sowrix_amc_guard();
CREATE OR REPLACE FUNCTION public.sowrix_amc_audit() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),CASE TG_OP WHEN 'INSERT' THEN 'amc_created' ELSE 'amc_updated' END,'amc',NEW.id::text,
 jsonb_build_object('client_id',NEW.client_id,'status',NEW.status,'starts_on',NEW.starts_on,'ends_on',NEW.ends_on,'amount',NEW.amount,'currency',NEW.currency));
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS sowrix_amc_audit ON public.sowrix_amc_contracts;
CREATE TRIGGER sowrix_amc_audit AFTER INSERT OR UPDATE ON public.sowrix_amc_contracts FOR EACH ROW EXECUTE FUNCTION public.sowrix_amc_audit();
REVOKE ALL ON FUNCTION public.sowrix_amc_guard(),public.sowrix_amc_audit() FROM PUBLIC,anon,authenticated;
-- No automatic grant seeding: administrators explicitly enable AMC View for a
-- client's billing users; existing revocations and assignments remain intact.
INSERT INTO public.sowrix_upgrade_markers(name) VALUES('amc-management-v1') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
