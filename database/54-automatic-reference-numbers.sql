-- R100: additive display identifiers only. Apply on backed-up staging after migrations 15,45,46.6,46.23,53 and other existing modules.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_r45_next_code(text)') IS NULL OR
    to_regprocedure('public.sowrix_r45_user_code_trigger()') IS NULL OR
    to_regprocedure('public.sowrix_r4623_business_number_trigger()') IS NULL OR
    to_regprocedure('public.sowrix_r466_apply(text,jsonb)') IS NULL OR
    to_regprocedure('public.sowrix_amc_guard()') IS NULL THEN RAISE EXCEPTION 'Install required earlier migrations before R100'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_r100_format(n text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT SET search_path='' AS $$ SELECT lpad(n,greatest(4,length(n)),'0') $$;
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r45_sa_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r45_sa_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.sowrix_r45_identity_codes DROP CONSTRAINT IF EXISTS sowrix_r45_code_format;
ALTER TABLE public.sowrix_r45_identity_codes ADD CONSTRAINT sowrix_r45_code_format CHECK(code ~ '^SW/(SA|AD|HR|EM|PR|CL)/[0-9]{4,}$');
CREATE OR REPLACE FUNCTION public.sowrix_r45_next_code(p_prefix text) RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $function$
DECLARE n bigint;
BEGIN
  CASE p_prefix
    WHEN 'SA' THEN n:=nextval('public.sowrix_r45_sa_seq'::regclass);
    WHEN 'AD' THEN n:=nextval('public.sowrix_r45_ad_seq'::regclass);
    WHEN 'HR' THEN n:=nextval('public.sowrix_r45_hr_seq'::regclass);
    WHEN 'EM' THEN n:=nextval('public.sowrix_r45_em_seq'::regclass);
    WHEN 'PR' THEN n:=nextval('public.sowrix_r45_pr_seq'::regclass);
    WHEN 'CL' THEN n:=nextval('public.sowrix_r45_cl_seq'::regclass);
    ELSE RAISE EXCEPTION 'Unsupported role category' USING ERRCODE='22023';
  END CASE;
  RETURN 'SW/'||p_prefix||'/'||lpad(n::text,greatest(4,length(n::text)),'0');
END;
$function$;
CREATE OR REPLACE FUNCTION public.sowrix_r45_user_code_trigger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE prefix text;
BEGIN
  -- Client organisation uses its own canonical SW/CL code; do not issue a second login code.
  IF lower(NEW.role::text)='client' THEN RETURN NEW; END IF;
  IF EXISTS (SELECT 1 FROM public.sowrix_r45_identity_codes WHERE user_id=NEW.user_id) THEN RETURN NEW; END IF;
  prefix:=CASE lower(NEW.role::text)
    WHEN 'super_admin' THEN 'SA' WHEN 'admin' THEN 'AD'
    WHEN 'hr' THEN 'HR' WHEN 'hr_manager' THEN 'HR' WHEN 'hr_staff' THEN 'HR'
    WHEN 'client' THEN 'CL' WHEN 'project_manager' THEN 'PR' ELSE 'EM' END;
  INSERT INTO public.sowrix_r45_identity_codes(user_id,code,first_role)
  VALUES (NEW.user_id,public.sowrix_r45_next_code(prefix),lower(NEW.role::text))
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$function$;
CREATE OR REPLACE FUNCTION public.sowrix_r4623_business_number_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
BEGIN
 IF TG_TABLE_NAME = 'invoices' THEN
   IF TG_OP='INSERT' THEN
     NEW.invoice_number:='SW/INV/'||public.sowrix_r100_format(nextval('public.sowrix_r4623_invoice_seq'::regclass)::text);
   ELSE
     NEW.invoice_number:=OLD.invoice_number;
   END IF;
   -- No discount column exists in the current schema. Keep totals aligned
   -- for new invoices or when amounts are edited; do not rewrite old totals.
   IF TG_OP='INSERT' THEN
     NEW.total_amount:=round(NEW.subtotal + COALESCE(NEW.tax_amount,0),2);
   ELSIF NEW.subtotal IS DISTINCT FROM OLD.subtotal
      OR NEW.tax_amount IS DISTINCT FROM OLD.tax_amount
      OR NEW.total_amount IS DISTINCT FROM OLD.total_amount THEN
     NEW.total_amount:=round(NEW.subtotal + COALESCE(NEW.tax_amount,0),2);
   END IF;
 ELSIF TG_TABLE_NAME = 'quotations' THEN
   IF TG_OP='INSERT' THEN
     NEW.quotation_number:='SW/QT/'||public.sowrix_r100_format(nextval('public.sowrix_r4623_quote_seq'::regclass)::text);
   ELSE
     NEW.quotation_number:=OLD.quotation_number;
   END IF;
   IF TG_OP='INSERT' THEN
     NEW.total_amount:=round(NEW.subtotal + COALESCE(NEW.tax_amount,0),2);
   ELSIF NEW.subtotal IS DISTINCT FROM OLD.subtotal
      OR NEW.tax_amount IS DISTINCT FROM OLD.tax_amount
      OR NEW.total_amount IS DISTINCT FROM OLD.total_amount THEN
     NEW.total_amount:=round(NEW.subtotal + COALESCE(NEW.tax_amount,0),2);
   END IF;
 ELSIF TG_TABLE_NAME = 'support_tickets' THEN
   IF TG_OP='INSERT' THEN
     NEW.ticket_number:='SW/TK/'||public.sowrix_r100_format(nextval('public.sowrix_r4623_ticket_seq'::regclass)::text);
   ELSIF NULLIF(btrim(OLD.ticket_number),'') IS NOT NULL THEN
     NEW.ticket_number:=OLD.ticket_number;
   ELSE
     NEW.ticket_number:='SW/TK/'||public.sowrix_r100_format(nextval('public.sowrix_r4623_ticket_seq'::regclass)::text);
   END IF;
 ELSE
   RAISE EXCEPTION 'Unsupported numbering table' USING ERRCODE='22023';
 END IF;
 RETURN NEW;
END;
$function$;
CREATE OR REPLACE FUNCTION public.sowrix_r100_record_code() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  NEW.sowrix_reference:='SW/'||TG_ARGV[0]||'/'||public.sowrix_r100_format(nextval(('public.sowrix_r100_'||lower(TG_ARGV[0])||'_seq')::regclass)::text);
 ELSE NEW.sowrix_reference:=OLD.sowrix_reference; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_r100_record_code() FROM PUBLIC,anon,authenticated;
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_pj_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_pj_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_pj_reference_unique ON public.projects(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.projects;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('PJ');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_ts_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_ts_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_ts_reference_unique ON public.tasks(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.tasks;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('TS');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_exp_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_exp_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_exp_reference_unique ON public.expenses(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.expenses;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.expenses FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('EXP');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_att_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_att_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.attendance_records ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_att_reference_unique ON public.attendance_records(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.attendance_records;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.attendance_records FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('ATT');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_lv_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_lv_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.leave_requests ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_lv_reference_unique ON public.leave_requests(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.leave_requests;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.leave_requests FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('LV');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_pay_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_pay_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.payroll_records ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_pay_reference_unique ON public.payroll_records(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.payroll_records;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.payroll_records FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('PAY');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_int_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_int_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.interviews ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_int_reference_unique ON public.interviews(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.interviews;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.interviews FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('INT');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_dep_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_dep_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.departments ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_dep_reference_unique ON public.departments(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.departments;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.departments FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('DEP');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_job_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_job_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_job_reference_unique ON public.jobs(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.jobs;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.jobs FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('JOB');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_app_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_app_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.job_applications ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_app_reference_unique ON public.job_applications(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.job_applications;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.job_applications FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('APP');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_enq_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_enq_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.contact_enquiries ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_enq_reference_unique ON public.contact_enquiries(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.contact_enquiries;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.contact_enquiries FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('ENQ');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_ntf_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_ntf_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_ntf_reference_unique ON public.notifications(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.notifications;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.notifications FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('NTF');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_aud_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_aud_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_aud_reference_unique ON public.audit_logs(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.audit_logs;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.audit_logs FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('AUD');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_ld_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_ld_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.sowrix_r467_leads ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_ld_reference_unique ON public.sowrix_r467_leads(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.sowrix_r467_leads;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.sowrix_r467_leads FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('LD');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_agr_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_agr_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.sowrix_r467_agreements ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_agr_reference_unique ON public.sowrix_r467_agreements(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.sowrix_r467_agreements;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.sowrix_r467_agreements FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('AGR');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_doc_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_doc_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.sowrix_r465_documents ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_doc_reference_unique ON public.sowrix_r465_documents(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.sowrix_r465_documents;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.sowrix_r465_documents FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('DOC');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_fb_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_fb_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.sowrix_r464_feedback ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_fb_reference_unique ON public.sowrix_r464_feedback(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.sowrix_r464_feedback;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.sowrix_r464_feedback FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('FB');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_apr_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_apr_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.sowrix_r465_staff_requests ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_apr_reference_unique ON public.sowrix_r465_staff_requests(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.sowrix_r465_staff_requests;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.sowrix_r465_staff_requests FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('APR');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_org_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_org_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.sowrix_def_orgs ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_org_reference_unique ON public.sowrix_def_orgs(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.sowrix_def_orgs;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.sowrix_def_orgs FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('ORG');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_dev_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_dev_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.sowrix_def_devices ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_dev_reference_unique ON public.sowrix_def_devices(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.sowrix_def_devices;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.sowrix_def_devices FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('DEV');
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_inc_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_inc_seq FROM PUBLIC,anon,authenticated;
ALTER TABLE public.sowrix_def_incidents ADD COLUMN IF NOT EXISTS sowrix_reference text;
CREATE UNIQUE INDEX IF NOT EXISTS r100_inc_reference_unique ON public.sowrix_def_incidents(sowrix_reference);
DROP TRIGGER IF EXISTS sowrix_r100_reference ON public.sowrix_def_incidents;
CREATE TRIGGER sowrix_r100_reference BEFORE INSERT OR UPDATE ON public.sowrix_def_incidents FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_record_code('INC');
LOCK TABLE public.sowrix_r466_assets IN SHARE ROW EXCLUSIVE MODE;
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_ast_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_ast_seq FROM PUBLIC,anon,authenticated;
DO $$ DECLARE highest bigint; last_num bigint; called boolean; BEGIN
 SELECT max(substring(asset_tag FROM '^SW/AST/([0-9]{4,18})$')::bigint) INTO highest FROM public.sowrix_r466_assets;
 SELECT last_value,is_called INTO last_num,called FROM public.sowrix_r100_ast_seq;
 IF highest IS NOT NULL AND highest >= last_num THEN PERFORM setval('public.sowrix_r100_ast_seq'::regclass,highest,true); END IF;
END $$;
LOCK TABLE public.sowrix_amc_contracts IN SHARE ROW EXCLUSIVE MODE;
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r100_amc_seq;
REVOKE ALL ON SEQUENCE public.sowrix_r100_amc_seq FROM PUBLIC,anon,authenticated;
DO $$ DECLARE highest bigint; last_num bigint; called boolean; BEGIN
 SELECT max(substring(contract_number FROM '^SW/AMC/([0-9]{4,18})$')::bigint) INTO highest FROM public.sowrix_amc_contracts;
 SELECT last_value,is_called INTO last_num,called FROM public.sowrix_r100_amc_seq;
 IF highest IS NOT NULL AND highest >= last_num THEN PERFORM setval('public.sowrix_r100_amc_seq'::regclass,highest,true); END IF;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_r100_asset_code() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='INSERT' THEN NEW.asset_tag:='SW/AST/'||public.sowrix_r100_format(nextval('public.sowrix_r100_ast_seq'::regclass)::text);
 ELSE NEW.asset_tag:=OLD.asset_tag; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_r100_asset_code() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS sowrix_r100_asset_code ON public.sowrix_r466_assets;
CREATE TRIGGER sowrix_r100_asset_code BEFORE INSERT OR UPDATE ON public.sowrix_r466_assets FOR EACH ROW EXECUTE FUNCTION public.sowrix_r100_asset_code();
CREATE OR REPLACE FUNCTION public.sowrix_r466_apply(p_action text,p_data jsonb DEFAULT '{}'::jsonb) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE r text;is_admin boolean;is_hr boolean;v_org uuid;v_id uuid;v_title text;v_text text;
        v_kind text;v_state text;v_date date;v_assignee uuid;v_rule public.sowrix_r466_automation_rules%ROWTYPE;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_user_active(auth.uid()) THEN RAISE EXCEPTION 'Active user required' USING ERRCODE='42501'; END IF;
 IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR length(p_data::text)>3000
 THEN RAISE EXCEPTION 'Invalid request' USING ERRCODE='22023'; END IF;
 r:=public.sowrix_access_role();is_admin:=public.sowrix_access_admin();is_hr:=is_admin OR r IN ('hr','hr_staff','hr_manager');
 IF p_action='onboard_create' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
  v_org:=(p_data->>'organization_id')::uuid;
  IF NOT EXISTS(SELECT 1 FROM public.clients WHERE id=v_org AND status='active') THEN RAISE EXCEPTION 'Client unavailable' USING ERRCODE='42501';END IF;
  INSERT INTO public.sowrix_r466_onboarding(organization_id,owner_id) VALUES(v_org,auth.uid())
   ON CONFLICT (organization_id) DO NOTHING;
 ELSIF p_action='onboard_step' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
  v_id:=(p_data->>'id')::uuid;v_kind:=p_data->>'step';
  IF v_kind NOT IN ('contact_confirmed','scope_approved','credentials_ready','kick_off_complete')
     OR jsonb_typeof(p_data->'value') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Invalid onboarding step' USING ERRCODE='22023'; END IF;
  UPDATE public.sowrix_r466_onboarding SET
   contact_confirmed=CASE WHEN v_kind='contact_confirmed' THEN (p_data->>'value')::boolean ELSE contact_confirmed END,
   scope_approved=CASE WHEN v_kind='scope_approved' THEN (p_data->>'value')::boolean ELSE scope_approved END,
   credentials_ready=CASE WHEN v_kind='credentials_ready' THEN (p_data->>'value')::boolean ELSE credentials_ready END,
   kick_off_complete=CASE WHEN v_kind='kick_off_complete' THEN (p_data->>'value')::boolean ELSE kick_off_complete END,
   updated_at=now() WHERE id=v_id;
  IF NOT FOUND THEN RETURN false;END IF;
 ELSIF p_action='subscription_create' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
  v_org:=(p_data->>'organization_id')::uuid;v_title:=btrim(p_data->>'service_name');v_text:=btrim(p_data->>'plan_label');
  IF length(v_title) NOT BETWEEN 3 AND 140 OR length(v_text) NOT BETWEEN 2 AND 100
   OR NOT EXISTS(SELECT 1 FROM public.clients WHERE id=v_org AND status='active') THEN
    RAISE EXCEPTION 'Invalid subscription details' USING ERRCODE='22023';END IF;
  v_date:=NULLIF(p_data->>'renewal_on','')::date;
  IF v_date IS NOT NULL AND v_date<current_date THEN RAISE EXCEPTION 'Past renewal date' USING ERRCODE='22023';END IF;
  INSERT INTO public.sowrix_r466_subscriptions(organization_id,service_name,plan_label,renewal_on,created_by)
  VALUES(v_org,v_title,v_text,v_date,auth.uid());
 ELSIF p_action='asset_create' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_title:='AUTO';v_text:=btrim(p_data->>'asset_name');v_kind:=p_data->>'category';
  IF length(v_title) NOT BETWEEN 3 AND 40 OR v_title !~ '^[a-zA-Z0-9-]+$'
    OR length(v_text) NOT BETWEEN 3 AND 150 OR v_kind NOT IN ('laptop','desktop','network','software','equipment','other')
    THEN RAISE EXCEPTION 'Invalid asset details' USING ERRCODE='22023';END IF;
  v_date:=NULLIF(p_data->>'warranty_end','')::date;
  INSERT INTO public.sowrix_r466_assets(asset_tag,asset_name,category,warranty_end)
  VALUES(v_title,v_text,v_kind,v_date);
 ELSIF p_action='subscription_status' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
  v_id:=(p_data->>'id')::uuid;v_state:=p_data->>'status';
  IF v_state NOT IN ('pending','active','paused','expired') THEN RAISE EXCEPTION 'Invalid status' USING ERRCODE='22023';END IF;
  UPDATE public.sowrix_r466_subscriptions SET status=v_state WHERE id=v_id;
  IF NOT FOUND THEN RETURN false;END IF;
 ELSIF p_action='asset_assign' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_id:=(p_data->>'id')::uuid;
  v_assignee:=NULLIF(p_data->>'assigned_to','')::uuid;
  IF v_assignee IS NOT NULL AND (NOT public.sowrix_user_active(v_assignee)
    OR NOT EXISTS(SELECT 1 FROM public.employees e WHERE e.user_id=v_assignee AND e.employment_status='active')) THEN
   RAISE EXCEPTION 'Inactive or unknown employee' USING ERRCODE='42501'; END IF;
  UPDATE public.sowrix_r466_assets SET assigned_to=v_assignee,
   state=CASE WHEN v_assignee IS NULL THEN 'available' ELSE 'assigned' END,updated_at=now()
   WHERE id=v_id AND state NOT IN ('retired','repair');
  IF NOT FOUND THEN RETURN false; END IF;
 ELSIF p_action='announcement_publish' THEN
  IF NOT is_hr THEN RAISE EXCEPTION 'HR or Admin only' USING ERRCODE='42501';END IF;
  v_title:=btrim(p_data->>'title');v_text:=btrim(p_data->>'body');
  IF length(v_title) NOT BETWEEN 4 AND 140 OR length(v_text) NOT BETWEEN 10 AND 1500 THEN
   RAISE EXCEPTION 'Invalid announcement' USING ERRCODE='22023';END IF;
  v_date:=NULLIF(p_data->>'expires_on','')::date;
  IF v_date IS NOT NULL AND v_date<current_date THEN RAISE EXCEPTION 'Expired announcement' USING ERRCODE='22023'; END IF;
  INSERT INTO public.sowrix_r466_announcements(title,body,author_id,expires_on)
   VALUES(v_title,v_text,auth.uid(),v_date);
 ELSIF p_action='announcement_ack' THEN
  IF r='client' THEN RAISE EXCEPTION 'Staff only' USING ERRCODE='42501';END IF;
  v_id:=(p_data->>'id')::uuid;
  INSERT INTO public.sowrix_r466_announcement_reads(announcement_id,user_id)
   SELECT id,auth.uid() FROM public.sowrix_r466_announcements
   WHERE id=v_id AND (expires_on IS NULL OR expires_on>=current_date)
   ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RETURN false;END IF;
 ELSIF p_action='rule_create' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
  v_title:=btrim(p_data->>'name');v_kind:=p_data->>'event_kind';v_text:=p_data->>'action_kind';
  IF length(v_title) NOT BETWEEN 4 AND 100 OR v_kind NOT IN
   ('ticket_created','ticket_overdue','invoice_overdue','amc_renewal_due','task_overdue')
   OR v_text NOT IN ('notify_internal','queue_review') THEN
   RAISE EXCEPTION 'Invalid safe automation rule' USING ERRCODE='22023';END IF;
  INSERT INTO public.sowrix_r466_automation_rules(name,event_kind,action_kind,creator_id)
   VALUES(v_title,v_kind,v_text,auth.uid());
 ELSIF p_action='rule_review' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
  v_id:=(p_data->>'id')::uuid;v_state:=p_data->>'state';
  IF v_state NOT IN ('approved','disabled') THEN RAISE EXCEPTION 'Invalid decision' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_rule FROM public.sowrix_r466_automation_rules WHERE id=v_id FOR UPDATE;
  IF NOT FOUND OR v_rule.state<>'draft' THEN RETURN false;END IF;
  IF v_rule.creator_id=auth.uid() THEN RAISE EXCEPTION 'Independent Admin reviewer required' USING ERRCODE='42501';END IF;
  UPDATE public.sowrix_r466_automation_rules SET state=v_state,reviewer_id=auth.uid(),reviewed_at=now() WHERE id=v_id;
 ELSIF p_action='compliance_record' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
  v_title:=btrim(p_data->>'control_name');v_text:=btrim(coalesce(p_data->>'evidence_note',''));v_state:=p_data->>'state';
  IF length(v_title) NOT BETWEEN 5 AND 140 OR length(v_text)>500 OR
   v_state NOT IN ('planned','in_review','verified') THEN RAISE EXCEPTION 'Invalid compliance entry' USING ERRCODE='22023'; END IF;
  -- A manual state, NEVER proof of MFA/TLS/backups or third-party compliance certification.
  INSERT INTO public.sowrix_r466_compliance_register(control_name,evidence_note,state,updated_by)
   VALUES(v_title,v_text,v_state,auth.uid()) ON CONFLICT(control_name) DO UPDATE
    SET evidence_note=EXCLUDED.evidence_note,state=EXCLUDED.state,updated_by=auth.uid(),updated_at=now();
 ELSE RAISE EXCEPTION 'Unknown action' USING ERRCODE='22023'; END IF;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r466_'||p_action,'operations','record',jsonb_build_object('kind',p_action));
 RETURN true;
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_amc_guard() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  NEW.created_by:=auth.uid();NEW.created_at:=now();
  NEW.contract_number:='SW/AMC/'||public.sowrix_r100_format(nextval('public.sowrix_r100_amc_seq'::regclass)::text);
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
REVOKE ALL ON FUNCTION public.sowrix_r45_next_code(text),public.sowrix_r45_user_code_trigger(),public.sowrix_r4623_business_number_trigger(),public.sowrix_amc_guard() FROM PUBLIC,anon,authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
