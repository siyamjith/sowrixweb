-- R45 additive identity numbering and controlled payroll review metadata.
-- Staging first. Take a real backup and run 45-preflight-read-only.sql before applying.
-- Human-readable IDs are labels, NEVER credentials and NEVER substitutes for auth.uid/RLS.
BEGIN;

CREATE SEQUENCE IF NOT EXISTS public.sowrix_r45_ad_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r45_hr_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r45_em_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r45_pr_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r45_cl_seq START 1;
REVOKE ALL ON SEQUENCE public.sowrix_r45_ad_seq,public.sowrix_r45_hr_seq,public.sowrix_r45_em_seq,public.sowrix_r45_pr_seq,public.sowrix_r45_cl_seq FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS public.sowrix_r45_identity_codes (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  code text NOT NULL UNIQUE,
  first_role text NOT NULL,
  issued_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sowrix_r45_code_format CHECK (code ~ '^SW/(AD|HR|EM|PR|CL)/[0-9]{4,}$')
);
ALTER TABLE public.sowrix_r45_identity_codes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_r45_identity_codes FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.sowrix_r45_identity_codes TO authenticated;
DROP POLICY IF EXISTS sowrix_r45_identity_read ON public.sowrix_r45_identity_codes;
CREATE POLICY sowrix_r45_identity_read ON public.sowrix_r45_identity_codes FOR SELECT TO authenticated
USING (user_id=auth.uid() OR public.sowrix_access_role() IN ('super_admin','admin')
 OR (public.sowrix_access_role() IN ('hr_manager','hr','hr_staff') AND first_role IN ('employee','hr','hr_manager','hr_staff')));

CREATE OR REPLACE FUNCTION public.sowrix_r45_next_code(p_prefix text) RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $function$
DECLARE n bigint;
BEGIN
  CASE p_prefix
    WHEN 'AD' THEN n:=nextval('public.sowrix_r45_ad_seq'::regclass);
    WHEN 'HR' THEN n:=nextval('public.sowrix_r45_hr_seq'::regclass);
    WHEN 'EM' THEN n:=nextval('public.sowrix_r45_em_seq'::regclass);
    WHEN 'PR' THEN n:=nextval('public.sowrix_r45_pr_seq'::regclass);
    WHEN 'CL' THEN n:=nextval('public.sowrix_r45_cl_seq'::regclass);
    ELSE RAISE EXCEPTION 'Unsupported role category' USING ERRCODE='22023';
  END CASE;
  RETURN 'SW/'||p_prefix||'/'||lpad(n::text,4,'0');
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_r45_next_code(text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_r45_user_code_trigger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE prefix text;
BEGIN
  -- Client organisation uses its own canonical SW/CL code; do not issue a second login code.
  IF lower(NEW.role::text)='client' THEN RETURN NEW; END IF;
  IF EXISTS (SELECT 1 FROM public.sowrix_r45_identity_codes WHERE user_id=NEW.user_id) THEN RETURN NEW; END IF;
  prefix:=CASE lower(NEW.role::text)
    WHEN 'super_admin' THEN 'AD' WHEN 'admin' THEN 'AD'
    WHEN 'hr' THEN 'HR' WHEN 'hr_manager' THEN 'HR' WHEN 'hr_staff' THEN 'HR'
    WHEN 'client' THEN 'CL' WHEN 'project_manager' THEN 'PR' ELSE 'EM' END;
  INSERT INTO public.sowrix_r45_identity_codes(user_id,code,first_role)
  VALUES (NEW.user_id,public.sowrix_r45_next_code(prefix),lower(NEW.role::text))
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_r45_user_code_trigger() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS sowrix_r45_role_assign ON public.user_roles;
CREATE TRIGGER sowrix_r45_role_assign AFTER INSERT OR UPDATE OF role ON public.user_roles
FOR EACH ROW EXECUTE FUNCTION public.sowrix_r45_user_code_trigger();
-- Deterministic backfill for existing authenticated users. Preserve any issued code.
-- Trigger is the only writer in normal operation; role changes do not renumber users.
INSERT INTO public.sowrix_r45_identity_codes(user_id,code,first_role)
SELECT r.user_id,
       public.sowrix_r45_next_code(CASE WHEN lower(r.role::text) IN ('super_admin','admin') THEN 'AD'
                                    WHEN lower(r.role::text) IN ('hr','hr_staff','hr_manager') THEN 'HR'
                                    WHEN lower(r.role::text)='client' THEN 'CL' WHEN lower(r.role::text)='project_manager' THEN 'PR' ELSE 'EM' END),
       lower(r.role::text)
FROM public.user_roles r WHERE lower(r.role::text)<>'client' AND NOT EXISTS
(SELECT 1 FROM public.sowrix_r45_identity_codes i WHERE i.user_id=r.user_id)
ORDER BY r.user_id
ON CONFLICT (user_id) DO NOTHING;

ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS sowrix_code text;
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS sowrix_code text;
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_r45_client_code_unique ON public.clients(sowrix_code) WHERE sowrix_code IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_r45_employee_code_unique ON public.employees(sowrix_code) WHERE sowrix_code IS NOT NULL;

CREATE OR REPLACE FUNCTION public.sowrix_r45_client_code_trigger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
BEGIN
  -- Client-organisation ID is distinct from the login identity ID.
  IF TG_OP='INSERT' THEN
    NEW.sowrix_code:=public.sowrix_r45_next_code('CL');
  ELSIF OLD.sowrix_code IS NOT NULL THEN
    NEW.sowrix_code:=OLD.sowrix_code;
  ELSIF NEW.sowrix_code IS NULL THEN
    NEW.sowrix_code:=public.sowrix_r45_next_code('CL');
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_r45_client_code_trigger() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS sowrix_r45_client_assign ON public.clients;
CREATE TRIGGER sowrix_r45_client_assign BEFORE INSERT OR UPDATE ON public.clients
FOR EACH ROW EXECUTE FUNCTION public.sowrix_r45_client_code_trigger();

CREATE OR REPLACE FUNCTION public.sowrix_r45_employee_code_trigger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE identity_code text;
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    SELECT i.code INTO identity_code FROM public.sowrix_r45_identity_codes i WHERE i.user_id=NEW.user_id;
  END IF;
  IF TG_OP='INSERT' THEN
    NEW.sowrix_code:=coalesce(identity_code,public.sowrix_r45_next_code('EM'));
  ELSIF OLD.sowrix_code IS NOT NULL THEN
    NEW.sowrix_code:=OLD.sowrix_code;
  ELSIF NEW.sowrix_code IS NULL THEN
    NEW.sowrix_code:=coalesce(identity_code,public.sowrix_r45_next_code('EM'));
  END IF;
  IF nullif(btrim(NEW.employee_code),'') IS NULL THEN NEW.employee_code:=NEW.sowrix_code;END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_r45_employee_code_trigger() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS sowrix_r45_employee_assign ON public.employees;
CREATE TRIGGER sowrix_r45_employee_assign BEFORE INSERT OR UPDATE ON public.employees
FOR EACH ROW EXECUTE FUNCTION public.sowrix_r45_employee_code_trigger();
-- Existing third-party employee codes are retained. The new SOWRIX label is separate.
UPDATE public.clients SET sowrix_code=public.sowrix_r45_next_code('CL') WHERE sowrix_code IS NULL;
UPDATE public.employees SET sowrix_code=NULL WHERE sowrix_code IS NULL;

-- Review log does not change payroll_records, approve payment or initiate transfers.
CREATE TABLE IF NOT EXISTS public.sowrix_r45_payroll_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period text NOT NULL CHECK (period ~ '^20[0-9]{2}-(0[1-9]|1[0-2])$'),
  version integer NOT NULL DEFAULT 1 CHECK (version BETWEEN 1 AND 9999),
  state text NOT NULL DEFAULT 'draft' CHECK (state IN ('draft','under_review','reviewed','returned')),
  notes text,
  created_by uuid NOT NULL DEFAULT auth.uid(),
  updated_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(period,version)
);
ALTER TABLE public.sowrix_r45_payroll_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_r45_payroll_reviews FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT ON public.sowrix_r45_payroll_reviews TO authenticated;
DROP POLICY IF EXISTS sowrix_r45_payroll_review_read ON public.sowrix_r45_payroll_reviews;
CREATE POLICY sowrix_r45_payroll_review_read ON public.sowrix_r45_payroll_reviews
FOR SELECT TO authenticated USING (public.sowrix_access_role() IN ('super_admin','admin','hr_manager') AND public.sowrix_has_module_access('payroll'));
DROP POLICY IF EXISTS sowrix_r45_payroll_review_insert ON public.sowrix_r45_payroll_reviews;
CREATE POLICY sowrix_r45_payroll_review_insert ON public.sowrix_r45_payroll_reviews
FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('super_admin','admin','hr_manager') AND public.sowrix_has_module_access('payroll') AND created_by=auth.uid() AND updated_by=auth.uid() AND state='draft');
-- Updates are deliberately denied pending approved statutory payroll rules and audit process.
DROP POLICY IF EXISTS sowrix_r45_payroll_review_update ON public.sowrix_r45_payroll_reviews;
CREATE POLICY sowrix_r45_payroll_review_update ON public.sowrix_r45_payroll_reviews
FOR UPDATE TO authenticated USING (false) WITH CHECK (false);
NOTIFY pgrst, 'reload schema';
COMMIT;
