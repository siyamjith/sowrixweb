-- SOWRIX complete backend release 10 (legacy-column compatibility included). Run in the existing Supabase project.
-- One transaction. Existing records and granular access decisions are retained.
BEGIN;

-- FILE: sowrix-complete-setup.sql
-- SOWRIX backend setup. Run in SQL Editor after taking a backup.
-- Transactional: incompatible existing schemas stop and roll back, never drop data.

CREATE TABLE IF NOT EXISTS public.clients (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 organization_name text NOT NULL,
 auth_user_id uuid,
 contact_person text,
 email text,
 phone text,
 organization_type text,
 address text,
 status text NOT NULL,
 notes text
);

CREATE TABLE IF NOT EXISTS public.projects (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 name text NOT NULL,
 client_id uuid,
 description text,
 status text NOT NULL,
 priority text NOT NULL,
 start_date date,
 due_date date,
 manager_id uuid
);

CREATE TABLE IF NOT EXISTS public.tasks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 title text NOT NULL,
 project_id uuid,
 description text,
 assignee_id uuid,
 status text NOT NULL,
 priority text NOT NULL,
 start_date date,
 due_date date,
 completed_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.invoices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 invoice_number text NOT NULL,
 client_id uuid,
 project_id uuid,
 description text,
 issue_date date NOT NULL,
 due_date date NOT NULL,
 subtotal numeric NOT NULL,
 tax_amount numeric,
 total_amount numeric NOT NULL,
 status text NOT NULL,
 notes text,
 paid_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.expenses (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 title text NOT NULL,
 category text NOT NULL,
 vendor text,
 amount numeric NOT NULL,
 expense_date date NOT NULL,
 payment_method text,
 status text NOT NULL,
 receipt_url text,
 notes text
);

CREATE TABLE IF NOT EXISTS public.quotations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 quotation_number text NOT NULL,
 client_id uuid,
 project_id uuid,
 title text NOT NULL,
 description text,
 subtotal numeric NOT NULL,
 tax_amount numeric,
 total_amount numeric NOT NULL,
 valid_until date,
 status text NOT NULL,
 notes text
);

CREATE TABLE IF NOT EXISTS public.support_tickets (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 ticket_number text,
 subject text NOT NULL,
 description text NOT NULL,
 category text NOT NULL,
 priority text NOT NULL,
 status text NOT NULL,
 requester_id uuid,
 assignee_id uuid,
 client_id uuid,
 due_date date
);

CREATE TABLE IF NOT EXISTS public.employees (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 full_name text NOT NULL,
 email text NOT NULL,
 employee_code text,
 department text,
 user_id uuid,
 department_id uuid,
 designation text NOT NULL,
 employment_status text NOT NULL,
 joining_date date
);

CREATE TABLE IF NOT EXISTS public.attendance_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 employee_user_id uuid NOT NULL,
 attendance_date date NOT NULL,
 check_in time,
 check_out time,
 status text NOT NULL,
 notes text,
 full_name text,
 employee_code text
);

CREATE TABLE IF NOT EXISTS public.leave_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 employee_user_id uuid NOT NULL,
 start_date date NOT NULL,
 end_date date NOT NULL,
 reason text,
 status text NOT NULL,
 full_name text,
 employee_code text
);

CREATE TABLE IF NOT EXISTS public.payroll_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 employee_user_id uuid NOT NULL,
 period text NOT NULL,
 basic_amount numeric NOT NULL,
 allowances numeric,
 deductions numeric,
 net_amount numeric NOT NULL,
 status text NOT NULL,
 paid_at date,
 full_name text,
 employee_code text
);

CREATE TABLE IF NOT EXISTS public.notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 user_id uuid NOT NULL,
 category text NOT NULL,
 title text NOT NULL,
 body text,
 read_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 actor_id uuid,
 action text,
 target_type text,
 target_id text,
 details jsonb
);

CREATE TABLE IF NOT EXISTS public.interviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 candidate_name text NOT NULL,
 candidate_email text NOT NULL,
 position text NOT NULL,
 interview_at timestamptz NOT NULL,
 interviewer_id uuid,
 meeting_url text,
 status text NOT NULL,
 feedback text,
 interviewer_employee_code text
);

CREATE TABLE IF NOT EXISTS public.departments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 name text NOT NULL
);

CREATE TABLE IF NOT EXISTS public.jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 title text NOT NULL,
 department text,
 location text,
 employment_type text,
 description text NOT NULL,
 status text NOT NULL
);

CREATE TABLE IF NOT EXISTS public.job_applications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 job_id uuid NOT NULL,
 full_name text NOT NULL,
 email text NOT NULL,
 phone text,
 status text NOT NULL,
 reviewer_id uuid,
 location text,
 skills text,
 cover_letter text,
 position text,
 resume_path text,
 resume_filename text,
 linkedin_url text,
 portfolio_url text,
 experience_years numeric
);

CREATE TABLE IF NOT EXISTS public.services (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 title text NOT NULL,
 slug text NOT NULL,
 description text NOT NULL,
 status text NOT NULL,
 featured boolean DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.portfolio_projects (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 title text NOT NULL,
 slug text NOT NULL,
 summary text NOT NULL,
 body text,
 category text,
 image_path text,
 external_url text,
 status text NOT NULL,
 featured boolean DEFAULT false,
 published_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.blog_posts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 title text NOT NULL,
 slug text NOT NULL,
 excerpt text,
 body text NOT NULL,
 category text,
 seo_title text,
 seo_description text,
 status text NOT NULL,
 published_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.contact_enquiries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 name text NOT NULL,
 email text NOT NULL,
 phone text,
 service_interest text,
 message text NOT NULL,
 status text NOT NULL,
 assigned_to uuid,
 company text,
 location text,
 budget text
);

CREATE TABLE IF NOT EXISTS public.task_comments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 task_id uuid NOT NULL,
 author_id uuid NOT NULL,
 body text NOT NULL
);

CREATE TABLE IF NOT EXISTS public.user_roles (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 role text NOT NULL CHECK(role IN ('super_admin','admin','hr','hr_manager','hr_staff','project_manager','employee','client'))
);

CREATE TABLE IF NOT EXISTS public.site_content (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 collection text NOT NULL,
 record jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);

-- Additive compatibility for older SOWRIX tables, before strict schema validation.
-- These nullable display fields do not replace employee/user identifiers.
-- No row values, roles, policies or existing column types are changed here.
ALTER TABLE public.attendance_records
 ADD COLUMN IF NOT EXISTS full_name text,
 ADD COLUMN IF NOT EXISTS employee_code text;
ALTER TABLE public.leave_requests
 ADD COLUMN IF NOT EXISTS full_name text,
 ADD COLUMN IF NOT EXISTS employee_code text;
ALTER TABLE public.payroll_records
 ADD COLUMN IF NOT EXISTS full_name text,
 ADD COLUMN IF NOT EXISTS employee_code text;
ALTER TABLE public.interviews
 ADD COLUMN IF NOT EXISTS interviewer_employee_code text;

DO $$ DECLARE missing text; BEGIN SELECT string_agg(v.t||'.'||v.c, ', ') INTO missing FROM (VALUES ('clients','id'),('clients','created_at'),('clients','updated_at'),('clients','organization_name'),('clients','auth_user_id'),('clients','contact_person'),('clients','email'),('clients','phone'),('clients','organization_type'),('clients','address'),('clients','status'),('clients','notes'),('projects','id'),('projects','created_at'),('projects','updated_at'),('projects','name'),('projects','client_id'),('projects','description'),('projects','status'),('projects','priority'),('projects','start_date'),('projects','due_date'),('projects','manager_id'),('tasks','id'),('tasks','created_at'),('tasks','updated_at'),('tasks','title'),('tasks','project_id'),('tasks','description'),('tasks','assignee_id'),('tasks','status'),('tasks','priority'),('tasks','start_date'),('tasks','due_date'),('tasks','completed_at'),('invoices','id'),('invoices','created_at'),('invoices','updated_at'),('invoices','invoice_number'),('invoices','client_id'),('invoices','project_id'),('invoices','description'),('invoices','issue_date'),('invoices','due_date'),('invoices','subtotal'),('invoices','tax_amount'),('invoices','total_amount'),('invoices','status'),('invoices','notes'),('invoices','paid_at'),('expenses','id'),('expenses','created_at'),('expenses','updated_at'),('expenses','title'),('expenses','category'),('expenses','vendor'),('expenses','amount'),('expenses','expense_date'),('expenses','payment_method'),('expenses','status'),('expenses','receipt_url'),('expenses','notes'),('quotations','id'),('quotations','created_at'),('quotations','updated_at'),('quotations','quotation_number'),('quotations','client_id'),('quotations','project_id'),('quotations','title'),('quotations','description'),('quotations','subtotal'),('quotations','tax_amount'),('quotations','total_amount'),('quotations','valid_until'),('quotations','status'),('quotations','notes'),('support_tickets','id'),('support_tickets','created_at'),('support_tickets','updated_at'),('support_tickets','ticket_number'),('support_tickets','subject'),('support_tickets','description'),('support_tickets','category'),('support_tickets','priority'),('support_tickets','status'),('support_tickets','requester_id'),('support_tickets','assignee_id'),('support_tickets','client_id'),('support_tickets','due_date'),('employees','id'),('employees','created_at'),('employees','updated_at'),('employees','full_name'),('employees','email'),('employees','employee_code'),('employees','department'),('employees','user_id'),('employees','department_id'),('employees','designation'),('employees','employment_status'),('employees','joining_date'),('attendance_records','id'),('attendance_records','created_at'),('attendance_records','updated_at'),('attendance_records','employee_user_id'),('attendance_records','attendance_date'),('attendance_records','check_in'),('attendance_records','check_out'),('attendance_records','status'),('attendance_records','notes'),('attendance_records','full_name'),('attendance_records','employee_code'),('leave_requests','id'),('leave_requests','created_at'),('leave_requests','updated_at'),('leave_requests','employee_user_id'),('leave_requests','start_date'),('leave_requests','end_date'),('leave_requests','reason'),('leave_requests','status'),('leave_requests','full_name'),('leave_requests','employee_code'),('payroll_records','id'),('payroll_records','created_at'),('payroll_records','updated_at'),('payroll_records','employee_user_id'),('payroll_records','period'),('payroll_records','basic_amount'),('payroll_records','allowances'),('payroll_records','deductions'),('payroll_records','net_amount'),('payroll_records','status'),('payroll_records','paid_at'),('payroll_records','full_name'),('payroll_records','employee_code'),('notifications','id'),('notifications','created_at'),('notifications','updated_at'),('notifications','user_id'),('notifications','category'),('notifications','title'),('notifications','body'),('notifications','read_at'),('audit_logs','id'),('audit_logs','created_at'),('audit_logs','updated_at'),('audit_logs','actor_id'),('audit_logs','action'),('audit_logs','target_type'),('audit_logs','target_id'),('audit_logs','details'),('interviews','id'),('interviews','created_at'),('interviews','updated_at'),('interviews','candidate_name'),('interviews','candidate_email'),('interviews','position'),('interviews','interview_at'),('interviews','interviewer_id'),('interviews','meeting_url'),('interviews','status'),('interviews','feedback'),('interviews','interviewer_employee_code'),('departments','id'),('departments','created_at'),('departments','updated_at'),('departments','name'),('jobs','id'),('jobs','created_at'),('jobs','updated_at'),('jobs','title'),('jobs','department'),('jobs','location'),('jobs','employment_type'),('jobs','description'),('jobs','status'),('job_applications','id'),('job_applications','created_at'),('job_applications','updated_at'),('job_applications','job_id'),('job_applications','full_name'),('job_applications','email'),('job_applications','phone'),('job_applications','status'),('job_applications','reviewer_id'),('job_applications','location'),('job_applications','skills'),('job_applications','cover_letter'),('job_applications','position'),('job_applications','resume_path'),('job_applications','resume_filename'),('job_applications','linkedin_url'),('job_applications','portfolio_url'),('job_applications','experience_years'),('services','id'),('services','created_at'),('services','updated_at'),('services','title'),('services','slug'),('services','description'),('services','status'),('services','featured'),('portfolio_projects','id'),('portfolio_projects','created_at'),('portfolio_projects','updated_at'),('portfolio_projects','title'),('portfolio_projects','slug'),('portfolio_projects','summary'),('portfolio_projects','body'),('portfolio_projects','category'),('portfolio_projects','image_path'),('portfolio_projects','external_url'),('portfolio_projects','status'),('portfolio_projects','featured'),('portfolio_projects','published_at'),('blog_posts','id'),('blog_posts','created_at'),('blog_posts','updated_at'),('blog_posts','title'),('blog_posts','slug'),('blog_posts','excerpt'),('blog_posts','body'),('blog_posts','category'),('blog_posts','seo_title'),('blog_posts','seo_description'),('blog_posts','status'),('blog_posts','published_at'),('contact_enquiries','id'),('contact_enquiries','created_at'),('contact_enquiries','updated_at'),('contact_enquiries','name'),('contact_enquiries','email'),('contact_enquiries','phone'),('contact_enquiries','service_interest'),('contact_enquiries','message'),('contact_enquiries','status'),('contact_enquiries','assigned_to'),('contact_enquiries','company'),('contact_enquiries','location'),('contact_enquiries','budget'),('task_comments','id'),('task_comments','created_at'),('task_comments','updated_at'),('task_comments','task_id'),('task_comments','author_id'),('task_comments','body'),('user_roles','user_id'),('user_roles','role'),('site_content','id'),('site_content','collection'),('site_content','record'),('site_content','created_at'),('site_content','updated_at')) v(t,c) WHERE NOT EXISTS(SELECT 1 FROM information_schema.columns i WHERE i.table_schema='public' AND i.table_name=v.t AND i.column_name=v.c); IF missing IS NOT NULL THEN RAISE EXCEPTION 'Existing schema differs. Reconcile these missing columns before rerunning: %',missing; END IF; END $$;

-- Run once as the project owner in Supabase SQL Editor.
-- Existing row-ownership policies remain authoritative; these RESTRICTIVE policies
-- add a module gate. This does not replace existing table schemas or policies.

CREATE TABLE IF NOT EXISTS public.sowrix_access_modules (
 module_key text PRIMARY KEY,
 allowed_roles text[] NOT NULL
);
CREATE TABLE IF NOT EXISTS public.sowrix_module_access (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 module_key text NOT NULL REFERENCES public.sowrix_access_modules(module_key),
 granted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,module_key)
);
CREATE TABLE IF NOT EXISTS public.sowrix_access_changes (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 target_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 modules text[] NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.sowrix_access_modules(module_key,allowed_roles) VALUES
 ('clients','{}'),('projects','{employee}'),('tasks','{employee}'),
 ('invoices','{}'),('expenses','{}'),('quotations','{}'),
 ('tickets','{hr,hr_manager,hr_staff,employee}'),
 ('employees','{hr,hr_manager,hr_staff}'),
 ('attendance','{hr,hr_manager,hr_staff,employee}'),
 ('leaves','{hr,hr_manager,hr_staff,employee}'),
 ('payroll','{hr_manager}'),('notifications','{hr,hr_manager,hr_staff,employee}'),
 ('audit','{}'),('interviews','{hr,hr_manager,hr_staff}'),
 ('departments','{hr,hr_manager,hr_staff}'),('jobs','{hr,hr_manager,hr_staff}'),
 ('applications','{hr,hr_manager,hr_staff}'),('services','{}'),
 ('portfolio','{}'),('blog','{}'),('enquiries','{}'),('task_comments','{employee}')
ON CONFLICT(module_key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.sowrix_access_role()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$ SELECT lower(role::text) FROM public.user_roles WHERE user_id=auth.uid() LIMIT 1 $$;
CREATE OR REPLACE FUNCTION public.sowrix_access_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$ SELECT coalesce(public.sowrix_access_role() IN ('admin','super_admin'),false) $$;

ALTER TABLE public.sowrix_access_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_module_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_access_changes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_access_modules, public.sowrix_module_access, public.sowrix_access_changes FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.sowrix_access_modules, public.sowrix_module_access, public.sowrix_access_changes TO authenticated;
DROP POLICY IF EXISTS sowrix_catalog_read ON public.sowrix_access_modules;
CREATE POLICY sowrix_catalog_read ON public.sowrix_access_modules FOR SELECT TO authenticated USING(true);
DROP POLICY IF EXISTS sowrix_assignments_read ON public.sowrix_module_access;
CREATE POLICY sowrix_assignments_read ON public.sowrix_module_access FOR SELECT TO authenticated
 USING(user_id=auth.uid() OR public.sowrix_access_admin());
DROP POLICY IF EXISTS sowrix_changes_read ON public.sowrix_access_changes;
CREATE POLICY sowrix_changes_read ON public.sowrix_access_changes FOR SELECT TO authenticated
 USING(public.sowrix_access_admin());

CREATE OR REPLACE FUNCTION public.sowrix_has_module_access(p_module text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT CASE
 WHEN auth.uid() IS NULL THEN false
 WHEN public.sowrix_access_role() IN ('admin','super_admin','project_manager','client') THEN true
 WHEN public.sowrix_access_role() IN ('hr','hr_manager','hr_staff','employee') THEN EXISTS(
  SELECT 1 FROM public.sowrix_module_access a
  JOIN public.sowrix_access_modules m USING(module_key)
  WHERE a.user_id=auth.uid() AND a.module_key=p_module
   AND public.sowrix_access_role()=ANY(m.allowed_roles)
 ) ELSE false END
$$;
CREATE OR REPLACE FUNCTION public.sowrix_my_module_access()
RETURNS TABLE(module_key text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT a.module_key FROM public.sowrix_module_access a
 JOIN public.sowrix_access_modules m USING(module_key)
 WHERE a.user_id=auth.uid() AND public.sowrix_access_role()=ANY(m.allowed_roles)
 ORDER BY a.module_key
$$;
CREATE OR REPLACE FUNCTION public.sowrix_list_team_access()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $$
BEGIN
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x.record ORDER BY x.email) FROM (
  SELECT u.email,jsonb_build_object('user_id',u.id,'email',u.email,
   'full_name',coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name',''),
   'role',lower(r.role::text),'modules',coalesce((SELECT jsonb_agg(a.module_key ORDER BY a.module_key)
    FROM public.sowrix_module_access a JOIN public.sowrix_access_modules m USING(module_key)
    WHERE a.user_id=u.id AND lower(r.role::text)=ANY(m.allowed_roles)),'[]'::jsonb)) record
  FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id
  WHERE lower(r.role::text) IN ('hr','hr_manager','hr_staff','employee')
 ) x),'[]'::jsonb);
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_set_module_access(p_user_id uuid,p_modules text[])
RETURNS text[] LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE target_role text; selected text[];
BEGIN
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
 -- Serialize replacement of one user's assignment set.
 PERFORM 1 FROM auth.users WHERE id=p_user_id FOR UPDATE;
 SELECT lower(role::text) INTO target_role FROM public.user_roles WHERE user_id=p_user_id LIMIT 1;
 IF target_role IS NULL OR target_role NOT IN ('hr','hr_manager','hr_staff','employee') THEN
  RAISE EXCEPTION 'Select an existing HR or employee account' USING ERRCODE='22023';
 END IF;
 IF array_length(p_modules,1)>100 THEN RAISE EXCEPTION 'Too many modules' USING ERRCODE='22023'; END IF;
 SELECT coalesce(array_agg(DISTINCT k ORDER BY k),'{}') INTO selected FROM unnest(coalesce(p_modules,'{}')) k;
 IF EXISTS(SELECT 1 FROM unnest(selected) k WHERE k IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.sowrix_access_modules m WHERE m.module_key=k AND target_role=ANY(m.allowed_roles)
 )) THEN RAISE EXCEPTION 'One or more modules are not eligible for this account role' USING ERRCODE='22023'; END IF;
 DELETE FROM public.sowrix_module_access WHERE user_id=p_user_id;
 INSERT INTO public.sowrix_module_access(user_id,module_key,granted_by)
  SELECT p_user_id,k,auth.uid() FROM unnest(selected) k;
 INSERT INTO public.sowrix_access_changes(actor_id,target_user_id,modules) VALUES(auth.uid(),p_user_id,selected);
 RETURN selected;
END $$;

REVOKE ALL ON FUNCTION public.sowrix_access_role(),public.sowrix_access_admin(),
 public.sowrix_has_module_access(text),public.sowrix_my_module_access(),
 public.sowrix_list_team_access(),public.sowrix_set_module_access(uuid,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_access_role(),public.sowrix_access_admin(),
 public.sowrix_has_module_access(text),public.sowrix_my_module_access(),
 public.sowrix_list_team_access(),public.sowrix_set_module_access(uuid,text[]) TO authenticated;

-- All existing permissive policies still apply. No new row-ownership grants are added.
DO $$
DECLARE item record; command text; select_rule text;
BEGIN
 FOR item IN SELECT * FROM (VALUES
 ('clients','clients'),('projects','projects'),('tasks','tasks'),('invoices','invoices'),
 ('expenses','expenses'),('quotations','quotations'),('support_tickets','tickets'),
 ('employees','employees'),('attendance_records','attendance'),('leave_requests','leaves'),
 ('payroll_records','payroll'),('notifications','notifications'),('audit_logs','audit'),
 ('interviews','interviews'),('departments','departments'),('jobs','jobs'),
 ('job_applications','applications'),('services','services'),('portfolio_projects','portfolio'),
 ('blog_posts','blog'),('contact_enquiries','enquiries'),('task_comments','task_comments')
 ) AS mapping(table_name,module_key)
 LOOP
  IF to_regclass('public.'||item.table_name) IS NOT NULL THEN
   EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',item.table_name);
   EXECUTE format('DROP POLICY IF EXISTS sowrix_module_gate ON public.%I',item.table_name);
   select_rule := format('public.sowrix_has_module_access(%L)',item.module_key);
   -- Public published content remains public; workspace access is still gated.
   IF item.table_name IN ('jobs','services','portfolio_projects','blog_posts') AND EXISTS(
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name=item.table_name AND column_name='status'
   ) THEN select_rule := '('||select_rule||' OR status::text = ''published'')'; END IF;
   EXECUTE format('DROP POLICY IF EXISTS sowrix_module_select ON public.%I',item.table_name);
   EXECUTE format('CREATE POLICY sowrix_module_select ON public.%I AS RESTRICTIVE FOR SELECT TO authenticated USING (%s)',item.table_name,select_rule);
   FOREACH command IN ARRAY ARRAY['INSERT','UPDATE','DELETE'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I','sowrix_module_'||lower(command),item.table_name);
    EXECUTE format('CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR %s TO authenticated %s',
     'sowrix_module_'||lower(command),item.table_name,command,
     CASE command WHEN 'INSERT' THEN format('WITH CHECK (public.sowrix_has_module_access(%L))',item.module_key)
      WHEN 'DELETE' THEN format('USING (public.sowrix_has_module_access(%L))',item.module_key)
      ELSE format('USING (public.sowrix_has_module_access(%L)) WITH CHECK (public.sowrix_has_module_access(%L))',item.module_key,item.module_key) END);
   END LOOP;
  ELSE RAISE NOTICE 'Missing table %: rerun this migration after creating it.',item.table_name;
  END IF;
 END LOOP;
END $$;
-- Prevent role self-promotion through an overly broad existing role-write policy.
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sowrix_role_insert ON public.user_roles;
CREATE POLICY sowrix_role_insert ON public.user_roles AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(public.sowrix_access_admin());
DROP POLICY IF EXISTS sowrix_role_update ON public.user_roles;
CREATE POLICY sowrix_role_update ON public.user_roles AS RESTRICTIVE FOR UPDATE TO authenticated USING(public.sowrix_access_admin()) WITH CHECK(public.sowrix_access_admin());
DROP POLICY IF EXISTS sowrix_role_delete ON public.user_roles;
CREATE POLICY sowrix_role_delete ON public.user_roles AS RESTRICTIVE FOR DELETE TO authenticated USING(public.sowrix_access_admin());
-- Prevent an authenticated HR/employee without Recruitment access from bypassing
-- the module through an existing permissive resume-storage SELECT policy.
DROP POLICY IF EXISTS sowrix_resume_module_gate ON storage.objects;
CREATE POLICY sowrix_resume_module_gate ON storage.objects AS RESTRICTIVE FOR SELECT TO authenticated
 USING(bucket_id<>'resumes' OR public.sowrix_has_module_access('applications'));



CREATE OR REPLACE FUNCTION public.sowrix_project_scope(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.projects p WHERE p.id=p_id AND ((public.sowrix_access_role()='project_manager' AND p.manager_id=auth.uid())
 OR (public.sowrix_access_role()='employee' AND EXISTS(SELECT 1 FROM public.tasks t WHERE t.project_id=p.id AND t.assignee_id=auth.uid()))
 OR (public.sowrix_access_role()='client' AND EXISTS(SELECT 1 FROM public.clients c WHERE c.id=p.client_id AND c.auth_user_id=auth.uid()))))
$$;
REVOKE ALL ON FUNCTION public.sowrix_project_scope(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_project_scope(uuid) TO authenticated;


ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.clients FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.clients TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.clients;
CREATE POLICY sowrix_v3_select_allow ON public.clients AS PERMISSIVE FOR SELECT TO authenticated USING ((((public.sowrix_access_admin() OR auth_user_id=auth.uid())) AND public.sowrix_has_module_access('clients')));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.clients;
CREATE POLICY sowrix_v3_select_scope ON public.clients AS RESTRICTIVE FOR SELECT TO authenticated USING ((((public.sowrix_access_admin() OR auth_user_id=auth.uid())) AND public.sowrix_has_module_access('clients')));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.clients;
CREATE POLICY sowrix_v3_insert_allow ON public.clients AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.clients;
CREATE POLICY sowrix_v3_insert_scope ON public.clients AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.clients;
CREATE POLICY sowrix_v3_update_allow ON public.clients AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.clients;
CREATE POLICY sowrix_v3_update_scope ON public.clients AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.clients;
CREATE POLICY sowrix_v3_delete_allow ON public.clients AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.clients;
CREATE POLICY sowrix_v3_delete_scope ON public.clients AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.projects FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.projects TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.projects;
CREATE POLICY sowrix_v3_select_allow ON public.projects AS PERMISSIVE FOR SELECT TO authenticated USING (((public.sowrix_access_admin() OR (public.sowrix_access_role() IN ('client','employee','project_manager') AND public.sowrix_project_scope(id)))) AND public.sowrix_has_module_access('projects'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.projects;
CREATE POLICY sowrix_v3_select_scope ON public.projects AS RESTRICTIVE FOR SELECT TO authenticated USING (((public.sowrix_access_admin() OR (public.sowrix_access_role() IN ('client','employee','project_manager') AND public.sowrix_project_scope(id)))) AND public.sowrix_has_module_access('projects'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.projects;
CREATE POLICY sowrix_v3_insert_allow ON public.projects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND manager_id=auth.uid())));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.projects;
CREATE POLICY sowrix_v3_insert_scope ON public.projects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND manager_id=auth.uid())));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.projects;
CREATE POLICY sowrix_v3_update_allow ON public.projects AS PERMISSIVE FOR UPDATE TO authenticated USING ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND manager_id=auth.uid()))) WITH CHECK ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND manager_id=auth.uid())));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.projects;
CREATE POLICY sowrix_v3_update_scope ON public.projects AS RESTRICTIVE FOR UPDATE TO authenticated USING ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND manager_id=auth.uid()))) WITH CHECK ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND manager_id=auth.uid())));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.projects;
CREATE POLICY sowrix_v3_delete_allow ON public.projects AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.projects;
CREATE POLICY sowrix_v3_delete_scope ON public.projects AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.tasks FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.tasks TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.tasks;
CREATE POLICY sowrix_v3_select_allow ON public.tasks AS PERMISSIVE FOR SELECT TO authenticated USING (((public.sowrix_access_admin() OR (public.sowrix_access_role()='employee' AND assignee_id=auth.uid()) OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(project_id)))) AND public.sowrix_has_module_access('tasks'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.tasks;
CREATE POLICY sowrix_v3_select_scope ON public.tasks AS RESTRICTIVE FOR SELECT TO authenticated USING (((public.sowrix_access_admin() OR (public.sowrix_access_role()='employee' AND assignee_id=auth.uid()) OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(project_id)))) AND public.sowrix_has_module_access('tasks'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.tasks;
CREATE POLICY sowrix_v3_insert_allow ON public.tasks AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(project_id))));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.tasks;
CREATE POLICY sowrix_v3_insert_scope ON public.tasks AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(project_id))));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.tasks;
CREATE POLICY sowrix_v3_update_allow ON public.tasks AS PERMISSIVE FOR UPDATE TO authenticated USING ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(project_id)))) WITH CHECK ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(project_id))));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.tasks;
CREATE POLICY sowrix_v3_update_scope ON public.tasks AS RESTRICTIVE FOR UPDATE TO authenticated USING ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(project_id)))) WITH CHECK ((public.sowrix_access_admin() OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(project_id))));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.tasks;
CREATE POLICY sowrix_v3_delete_allow ON public.tasks AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.tasks;
CREATE POLICY sowrix_v3_delete_scope ON public.tasks AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.invoices FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.invoices TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.invoices;
CREATE POLICY sowrix_v3_select_allow ON public.invoices AS PERMISSIVE FOR SELECT TO authenticated USING (((public.sowrix_access_admin() OR (public.sowrix_access_role()='client' AND EXISTS(SELECT 1 FROM public.clients c WHERE c.id=client_id AND c.auth_user_id=auth.uid())))) AND public.sowrix_has_module_access('invoices'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.invoices;
CREATE POLICY sowrix_v3_select_scope ON public.invoices AS RESTRICTIVE FOR SELECT TO authenticated USING (((public.sowrix_access_admin() OR (public.sowrix_access_role()='client' AND EXISTS(SELECT 1 FROM public.clients c WHERE c.id=client_id AND c.auth_user_id=auth.uid())))) AND public.sowrix_has_module_access('invoices'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.invoices;
CREATE POLICY sowrix_v3_insert_allow ON public.invoices AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.invoices;
CREATE POLICY sowrix_v3_insert_scope ON public.invoices AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.invoices;
CREATE POLICY sowrix_v3_update_allow ON public.invoices AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.invoices;
CREATE POLICY sowrix_v3_update_scope ON public.invoices AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.invoices;
CREATE POLICY sowrix_v3_delete_allow ON public.invoices AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.invoices;
CREATE POLICY sowrix_v3_delete_scope ON public.invoices AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.expenses FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.expenses TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.expenses;
CREATE POLICY sowrix_v3_select_allow ON public.expenses AS PERMISSIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('expenses'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.expenses;
CREATE POLICY sowrix_v3_select_scope ON public.expenses AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('expenses'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.expenses;
CREATE POLICY sowrix_v3_insert_allow ON public.expenses AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.expenses;
CREATE POLICY sowrix_v3_insert_scope ON public.expenses AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.expenses;
CREATE POLICY sowrix_v3_update_allow ON public.expenses AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.expenses;
CREATE POLICY sowrix_v3_update_scope ON public.expenses AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.expenses;
CREATE POLICY sowrix_v3_delete_allow ON public.expenses AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.expenses;
CREATE POLICY sowrix_v3_delete_scope ON public.expenses AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.quotations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.quotations FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.quotations TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.quotations;
CREATE POLICY sowrix_v3_select_allow ON public.quotations AS PERMISSIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('quotations'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.quotations;
CREATE POLICY sowrix_v3_select_scope ON public.quotations AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('quotations'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.quotations;
CREATE POLICY sowrix_v3_insert_allow ON public.quotations AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.quotations;
CREATE POLICY sowrix_v3_insert_scope ON public.quotations AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.quotations;
CREATE POLICY sowrix_v3_update_allow ON public.quotations AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.quotations;
CREATE POLICY sowrix_v3_update_scope ON public.quotations AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.quotations;
CREATE POLICY sowrix_v3_delete_allow ON public.quotations AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.quotations;
CREATE POLICY sowrix_v3_delete_scope ON public.quotations AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.support_tickets FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.support_tickets TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.support_tickets;
CREATE POLICY sowrix_v3_select_allow ON public.support_tickets AS PERMISSIVE FOR SELECT TO authenticated USING (((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR requester_id=auth.uid() OR assignee_id=auth.uid())) AND public.sowrix_has_module_access('tickets'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.support_tickets;
CREATE POLICY sowrix_v3_select_scope ON public.support_tickets AS RESTRICTIVE FOR SELECT TO authenticated USING (((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR requester_id=auth.uid() OR assignee_id=auth.uid())) AND public.sowrix_has_module_access('tickets'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.support_tickets;
CREATE POLICY sowrix_v3_insert_allow ON public.support_tickets AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((public.sowrix_access_role() IN ('admin','client','employee','hr','hr_manager','hr_staff','project_manager','super_admin') AND requester_id=auth.uid()));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.support_tickets;
CREATE POLICY sowrix_v3_insert_scope ON public.support_tickets AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK ((public.sowrix_access_role() IN ('admin','client','employee','hr','hr_manager','hr_staff','project_manager','super_admin') AND requester_id=auth.uid()));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.support_tickets;
CREATE POLICY sowrix_v3_update_allow ON public.support_tickets AS PERMISSIVE FOR UPDATE TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','project_manager','super_admin') AND ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR requester_id=auth.uid() OR assignee_id=auth.uid())))) WITH CHECK ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','project_manager','super_admin') AND ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR requester_id=auth.uid() OR assignee_id=auth.uid()))));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.support_tickets;
CREATE POLICY sowrix_v3_update_scope ON public.support_tickets AS RESTRICTIVE FOR UPDATE TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','project_manager','super_admin') AND ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR requester_id=auth.uid() OR assignee_id=auth.uid())))) WITH CHECK ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','project_manager','super_admin') AND ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR requester_id=auth.uid() OR assignee_id=auth.uid()))));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.support_tickets;
CREATE POLICY sowrix_v3_delete_allow ON public.support_tickets AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.support_tickets;
CREATE POLICY sowrix_v3_delete_scope ON public.support_tickets AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.employees FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.employees TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.employees;
CREATE POLICY sowrix_v3_select_allow ON public.employees AS PERMISSIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) AND public.sowrix_has_module_access('employees'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.employees;
CREATE POLICY sowrix_v3_select_scope ON public.employees AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) AND public.sowrix_has_module_access('employees'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.employees;
CREATE POLICY sowrix_v3_insert_allow ON public.employees AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (false);

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.employees;
CREATE POLICY sowrix_v3_insert_scope ON public.employees AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (false);

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.employees;
CREATE POLICY sowrix_v3_update_allow ON public.employees AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.employees;
CREATE POLICY sowrix_v3_update_scope ON public.employees AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.employees;
CREATE POLICY sowrix_v3_delete_allow ON public.employees AS PERMISSIVE FOR DELETE TO authenticated USING (false);

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.employees;
CREATE POLICY sowrix_v3_delete_scope ON public.employees AS RESTRICTIVE FOR DELETE TO authenticated USING (false);

ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.attendance_records FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.attendance_records TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.attendance_records;
CREATE POLICY sowrix_v3_select_allow ON public.attendance_records AS PERMISSIVE FOR SELECT TO authenticated USING (((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR (public.sowrix_access_role()='employee' AND employee_user_id=auth.uid()))) AND public.sowrix_has_module_access('attendance'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.attendance_records;
CREATE POLICY sowrix_v3_select_scope ON public.attendance_records AS RESTRICTIVE FOR SELECT TO authenticated USING (((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR (public.sowrix_access_role()='employee' AND employee_user_id=auth.uid()))) AND public.sowrix_has_module_access('attendance'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.attendance_records;
CREATE POLICY sowrix_v3_insert_allow ON public.attendance_records AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.attendance_records;
CREATE POLICY sowrix_v3_insert_scope ON public.attendance_records AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.attendance_records;
CREATE POLICY sowrix_v3_update_allow ON public.attendance_records AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.attendance_records;
CREATE POLICY sowrix_v3_update_scope ON public.attendance_records AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.attendance_records;
CREATE POLICY sowrix_v3_delete_allow ON public.attendance_records AS PERMISSIVE FOR DELETE TO authenticated USING (false);

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.attendance_records;
CREATE POLICY sowrix_v3_delete_scope ON public.attendance_records AS RESTRICTIVE FOR DELETE TO authenticated USING (false);

ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.leave_requests FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.leave_requests TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.leave_requests;
CREATE POLICY sowrix_v3_select_allow ON public.leave_requests AS PERMISSIVE FOR SELECT TO authenticated USING (((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR (public.sowrix_access_role()='employee' AND employee_user_id=auth.uid()))) AND public.sowrix_has_module_access('leaves'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.leave_requests;
CREATE POLICY sowrix_v3_select_scope ON public.leave_requests AS RESTRICTIVE FOR SELECT TO authenticated USING (((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR (public.sowrix_access_role()='employee' AND employee_user_id=auth.uid()))) AND public.sowrix_has_module_access('leaves'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.leave_requests;
CREATE POLICY sowrix_v3_insert_allow ON public.leave_requests AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR (public.sowrix_access_role()='employee' AND employee_user_id=auth.uid() AND status='pending')));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.leave_requests;
CREATE POLICY sowrix_v3_insert_scope ON public.leave_requests AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin') OR (public.sowrix_access_role()='employee' AND employee_user_id=auth.uid() AND status='pending')));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.leave_requests;
CREATE POLICY sowrix_v3_update_allow ON public.leave_requests AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.leave_requests;
CREATE POLICY sowrix_v3_update_scope ON public.leave_requests AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.leave_requests;
CREATE POLICY sowrix_v3_delete_allow ON public.leave_requests AS PERMISSIVE FOR DELETE TO authenticated USING (false);

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.leave_requests;
CREATE POLICY sowrix_v3_delete_scope ON public.leave_requests AS RESTRICTIVE FOR DELETE TO authenticated USING (false);

ALTER TABLE public.payroll_records ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.payroll_records FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.payroll_records TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.payroll_records;
CREATE POLICY sowrix_v3_select_allow ON public.payroll_records AS PERMISSIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr_manager','super_admin')) AND public.sowrix_has_module_access('payroll'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.payroll_records;
CREATE POLICY sowrix_v3_select_scope ON public.payroll_records AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr_manager','super_admin')) AND public.sowrix_has_module_access('payroll'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.payroll_records;
CREATE POLICY sowrix_v3_insert_allow ON public.payroll_records AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr_manager','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.payroll_records;
CREATE POLICY sowrix_v3_insert_scope ON public.payroll_records AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr_manager','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.payroll_records;
CREATE POLICY sowrix_v3_update_allow ON public.payroll_records AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr_manager','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr_manager','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.payroll_records;
CREATE POLICY sowrix_v3_update_scope ON public.payroll_records AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr_manager','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr_manager','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.payroll_records;
CREATE POLICY sowrix_v3_delete_allow ON public.payroll_records AS PERMISSIVE FOR DELETE TO authenticated USING (false);

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.payroll_records;
CREATE POLICY sowrix_v3_delete_scope ON public.payroll_records AS RESTRICTIVE FOR DELETE TO authenticated USING (false);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notifications FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.notifications TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.notifications;
CREATE POLICY sowrix_v3_select_allow ON public.notifications AS PERMISSIVE FOR SELECT TO authenticated USING (((public.sowrix_access_admin() OR user_id=auth.uid())) AND public.sowrix_has_module_access('notifications'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.notifications;
CREATE POLICY sowrix_v3_select_scope ON public.notifications AS RESTRICTIVE FOR SELECT TO authenticated USING (((public.sowrix_access_admin() OR user_id=auth.uid())) AND public.sowrix_has_module_access('notifications'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.notifications;
CREATE POLICY sowrix_v3_insert_allow ON public.notifications AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.notifications;
CREATE POLICY sowrix_v3_insert_scope ON public.notifications AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.notifications;
CREATE POLICY sowrix_v3_update_allow ON public.notifications AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.notifications;
CREATE POLICY sowrix_v3_update_scope ON public.notifications AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.notifications;
CREATE POLICY sowrix_v3_delete_allow ON public.notifications AS PERMISSIVE FOR DELETE TO authenticated USING (false);

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.notifications;
CREATE POLICY sowrix_v3_delete_scope ON public.notifications AS RESTRICTIVE FOR DELETE TO authenticated USING (false);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.audit_logs FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.audit_logs TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.audit_logs;
CREATE POLICY sowrix_v3_select_allow ON public.audit_logs AS PERMISSIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('audit'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.audit_logs;
CREATE POLICY sowrix_v3_select_scope ON public.audit_logs AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('audit'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.audit_logs;
CREATE POLICY sowrix_v3_insert_allow ON public.audit_logs AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL AND actor_id=auth.uid());

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.audit_logs;
CREATE POLICY sowrix_v3_insert_scope ON public.audit_logs AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL AND actor_id=auth.uid());

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.audit_logs;
CREATE POLICY sowrix_v3_update_allow ON public.audit_logs AS PERMISSIVE FOR UPDATE TO authenticated USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.audit_logs;
CREATE POLICY sowrix_v3_update_scope ON public.audit_logs AS RESTRICTIVE FOR UPDATE TO authenticated USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.audit_logs;
CREATE POLICY sowrix_v3_delete_allow ON public.audit_logs AS PERMISSIVE FOR DELETE TO authenticated USING (false);

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.audit_logs;
CREATE POLICY sowrix_v3_delete_scope ON public.audit_logs AS RESTRICTIVE FOR DELETE TO authenticated USING (false);

ALTER TABLE public.interviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.interviews FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.interviews TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.interviews;
CREATE POLICY sowrix_v3_select_allow ON public.interviews AS PERMISSIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) AND public.sowrix_has_module_access('interviews'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.interviews;
CREATE POLICY sowrix_v3_select_scope ON public.interviews AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) AND public.sowrix_has_module_access('interviews'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.interviews;
CREATE POLICY sowrix_v3_insert_allow ON public.interviews AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.interviews;
CREATE POLICY sowrix_v3_insert_scope ON public.interviews AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.interviews;
CREATE POLICY sowrix_v3_update_allow ON public.interviews AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.interviews;
CREATE POLICY sowrix_v3_update_scope ON public.interviews AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.interviews;
CREATE POLICY sowrix_v3_delete_allow ON public.interviews AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.interviews;
CREATE POLICY sowrix_v3_delete_scope ON public.interviews AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.departments FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.departments TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.departments;
CREATE POLICY sowrix_v3_select_allow ON public.departments AS PERMISSIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) AND public.sowrix_has_module_access('departments'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.departments;
CREATE POLICY sowrix_v3_select_scope ON public.departments AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) AND public.sowrix_has_module_access('departments'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.departments;
CREATE POLICY sowrix_v3_insert_allow ON public.departments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr_manager','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.departments;
CREATE POLICY sowrix_v3_insert_scope ON public.departments AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr_manager','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.departments;
CREATE POLICY sowrix_v3_update_allow ON public.departments AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr_manager','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr_manager','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.departments;
CREATE POLICY sowrix_v3_update_scope ON public.departments AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr_manager','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr_manager','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.departments;
CREATE POLICY sowrix_v3_delete_allow ON public.departments AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.departments;
CREATE POLICY sowrix_v3_delete_scope ON public.departments AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.jobs FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.jobs TO authenticated;

GRANT SELECT ON public.jobs TO anon;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.jobs;
CREATE POLICY sowrix_v3_select_allow ON public.jobs AS PERMISSIVE FOR SELECT TO anon,authenticated USING (((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) AND public.sowrix_has_module_access('jobs')) OR status='published');

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.jobs;
CREATE POLICY sowrix_v3_select_scope ON public.jobs AS RESTRICTIVE FOR SELECT TO anon,authenticated USING (((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) AND public.sowrix_has_module_access('jobs')) OR status='published');

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.jobs;
CREATE POLICY sowrix_v3_insert_allow ON public.jobs AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr_manager','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.jobs;
CREATE POLICY sowrix_v3_insert_scope ON public.jobs AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','hr_manager','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.jobs;
CREATE POLICY sowrix_v3_update_allow ON public.jobs AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.jobs;
CREATE POLICY sowrix_v3_update_scope ON public.jobs AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.jobs;
CREATE POLICY sowrix_v3_delete_allow ON public.jobs AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.jobs;
CREATE POLICY sowrix_v3_delete_scope ON public.jobs AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.job_applications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.job_applications FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.job_applications TO authenticated;

GRANT INSERT ON public.job_applications TO anon;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.job_applications;
CREATE POLICY sowrix_v3_select_allow ON public.job_applications AS PERMISSIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) AND public.sowrix_has_module_access('applications'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.job_applications;
CREATE POLICY sowrix_v3_select_scope ON public.job_applications AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) AND public.sowrix_has_module_access('applications'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.job_applications;
CREATE POLICY sowrix_v3_insert_allow ON public.job_applications AS PERMISSIVE FOR INSERT TO anon,authenticated WITH CHECK (status='applied' AND reviewer_id IS NULL AND length(full_name) BETWEEN 2 AND 250 AND email LIKE '%@%' AND resume_path LIKE 'applications/%' AND EXISTS(SELECT 1 FROM public.jobs j WHERE j.id=job_id AND j.status='published'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.job_applications;
CREATE POLICY sowrix_v3_insert_scope ON public.job_applications AS RESTRICTIVE FOR INSERT TO anon,authenticated WITH CHECK (status='applied' AND reviewer_id IS NULL AND length(full_name) BETWEEN 2 AND 250 AND email LIKE '%@%' AND resume_path LIKE 'applications/%' AND EXISTS(SELECT 1 FROM public.jobs j WHERE j.id=job_id AND j.status='published'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.job_applications;
CREATE POLICY sowrix_v3_update_allow ON public.job_applications AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.job_applications;
CREATE POLICY sowrix_v3_update_scope ON public.job_applications AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','hr','hr_manager','hr_staff','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.job_applications;
CREATE POLICY sowrix_v3_delete_allow ON public.job_applications AS PERMISSIVE FOR DELETE TO authenticated USING (false);

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.job_applications;
CREATE POLICY sowrix_v3_delete_scope ON public.job_applications AS RESTRICTIVE FOR DELETE TO authenticated USING (false);

DROP POLICY IF EXISTS sowrix_module_insert ON public.job_applications;

ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.services FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.services TO authenticated;

GRANT SELECT ON public.services TO anon;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.services;
CREATE POLICY sowrix_v3_select_allow ON public.services AS PERMISSIVE FOR SELECT TO anon,authenticated USING (((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('services')) OR status='published');

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.services;
CREATE POLICY sowrix_v3_select_scope ON public.services AS RESTRICTIVE FOR SELECT TO anon,authenticated USING (((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('services')) OR status='published');

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.services;
CREATE POLICY sowrix_v3_insert_allow ON public.services AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.services;
CREATE POLICY sowrix_v3_insert_scope ON public.services AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.services;
CREATE POLICY sowrix_v3_update_allow ON public.services AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.services;
CREATE POLICY sowrix_v3_update_scope ON public.services AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.services;
CREATE POLICY sowrix_v3_delete_allow ON public.services AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.services;
CREATE POLICY sowrix_v3_delete_scope ON public.services AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.portfolio_projects ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.portfolio_projects FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.portfolio_projects TO authenticated;

GRANT SELECT ON public.portfolio_projects TO anon;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.portfolio_projects;
CREATE POLICY sowrix_v3_select_allow ON public.portfolio_projects AS PERMISSIVE FOR SELECT TO anon,authenticated USING (((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('portfolio')) OR status='published');

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.portfolio_projects;
CREATE POLICY sowrix_v3_select_scope ON public.portfolio_projects AS RESTRICTIVE FOR SELECT TO anon,authenticated USING (((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('portfolio')) OR status='published');

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.portfolio_projects;
CREATE POLICY sowrix_v3_insert_allow ON public.portfolio_projects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.portfolio_projects;
CREATE POLICY sowrix_v3_insert_scope ON public.portfolio_projects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.portfolio_projects;
CREATE POLICY sowrix_v3_update_allow ON public.portfolio_projects AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.portfolio_projects;
CREATE POLICY sowrix_v3_update_scope ON public.portfolio_projects AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.portfolio_projects;
CREATE POLICY sowrix_v3_delete_allow ON public.portfolio_projects AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.portfolio_projects;
CREATE POLICY sowrix_v3_delete_scope ON public.portfolio_projects AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.blog_posts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.blog_posts FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.blog_posts TO authenticated;

GRANT SELECT ON public.blog_posts TO anon;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.blog_posts;
CREATE POLICY sowrix_v3_select_allow ON public.blog_posts AS PERMISSIVE FOR SELECT TO anon,authenticated USING (((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('blog')) OR status='published');

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.blog_posts;
CREATE POLICY sowrix_v3_select_scope ON public.blog_posts AS RESTRICTIVE FOR SELECT TO anon,authenticated USING (((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('blog')) OR status='published');

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.blog_posts;
CREATE POLICY sowrix_v3_insert_allow ON public.blog_posts AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.blog_posts;
CREATE POLICY sowrix_v3_insert_scope ON public.blog_posts AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.blog_posts;
CREATE POLICY sowrix_v3_update_allow ON public.blog_posts AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.blog_posts;
CREATE POLICY sowrix_v3_update_scope ON public.blog_posts AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.blog_posts;
CREATE POLICY sowrix_v3_delete_allow ON public.blog_posts AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.blog_posts;
CREATE POLICY sowrix_v3_delete_scope ON public.blog_posts AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.contact_enquiries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.contact_enquiries FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.contact_enquiries TO authenticated;

GRANT INSERT ON public.contact_enquiries TO anon;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.contact_enquiries;
CREATE POLICY sowrix_v3_select_allow ON public.contact_enquiries AS PERMISSIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('enquiries'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.contact_enquiries;
CREATE POLICY sowrix_v3_select_scope ON public.contact_enquiries AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_access_role() IN ('admin','super_admin')) AND public.sowrix_has_module_access('enquiries'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.contact_enquiries;
CREATE POLICY sowrix_v3_insert_allow ON public.contact_enquiries AS PERMISSIVE FOR INSERT TO anon,authenticated WITH CHECK (status='open' AND assigned_to IS NULL AND length(name) BETWEEN 2 AND 250 AND length(message) BETWEEN 20 AND 10000 AND email LIKE '%@%');

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.contact_enquiries;
CREATE POLICY sowrix_v3_insert_scope ON public.contact_enquiries AS RESTRICTIVE FOR INSERT TO anon,authenticated WITH CHECK (status='open' AND assigned_to IS NULL AND length(name) BETWEEN 2 AND 250 AND length(message) BETWEEN 20 AND 10000 AND email LIKE '%@%');

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.contact_enquiries;
CREATE POLICY sowrix_v3_update_allow ON public.contact_enquiries AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.contact_enquiries;
CREATE POLICY sowrix_v3_update_scope ON public.contact_enquiries AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_role() IN ('admin','super_admin')) WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.contact_enquiries;
CREATE POLICY sowrix_v3_delete_allow ON public.contact_enquiries AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.contact_enquiries;
CREATE POLICY sowrix_v3_delete_scope ON public.contact_enquiries AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_module_insert ON public.contact_enquiries;

ALTER TABLE public.task_comments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.task_comments FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.task_comments TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.task_comments;
CREATE POLICY sowrix_v3_select_allow ON public.task_comments AS PERMISSIVE FOR SELECT TO authenticated USING (((public.sowrix_access_admin() OR EXISTS(SELECT 1 FROM public.tasks t WHERE t.id=task_id AND (t.assignee_id=auth.uid() OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(t.project_id)))))) AND public.sowrix_has_module_access('task_comments'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.task_comments;
CREATE POLICY sowrix_v3_select_scope ON public.task_comments AS RESTRICTIVE FOR SELECT TO authenticated USING (((public.sowrix_access_admin() OR EXISTS(SELECT 1 FROM public.tasks t WHERE t.id=task_id AND (t.assignee_id=auth.uid() OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(t.project_id)))))) AND public.sowrix_has_module_access('task_comments'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.task_comments;
CREATE POLICY sowrix_v3_insert_allow ON public.task_comments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((public.sowrix_access_role() IN ('admin','employee','project_manager','super_admin') AND author_id=auth.uid() AND ((public.sowrix_access_admin() OR EXISTS(SELECT 1 FROM public.tasks t WHERE t.id=task_id AND (t.assignee_id=auth.uid() OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(t.project_id))))))));

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.task_comments;
CREATE POLICY sowrix_v3_insert_scope ON public.task_comments AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK ((public.sowrix_access_role() IN ('admin','employee','project_manager','super_admin') AND author_id=auth.uid() AND ((public.sowrix_access_admin() OR EXISTS(SELECT 1 FROM public.tasks t WHERE t.id=task_id AND (t.assignee_id=auth.uid() OR (public.sowrix_access_role()='project_manager' AND public.sowrix_project_scope(t.project_id))))))));

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.task_comments;
CREATE POLICY sowrix_v3_update_allow ON public.task_comments AS PERMISSIVE FOR UPDATE TO authenticated USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.task_comments;
CREATE POLICY sowrix_v3_update_scope ON public.task_comments AS RESTRICTIVE FOR UPDATE TO authenticated USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.task_comments;
CREATE POLICY sowrix_v3_delete_allow ON public.task_comments AS PERMISSIVE FOR DELETE TO authenticated USING (false);

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.task_comments;
CREATE POLICY sowrix_v3_delete_scope ON public.task_comments AS RESTRICTIVE FOR DELETE TO authenticated USING (false);

GRANT EXECUTE ON FUNCTION public.sowrix_access_role(),public.sowrix_access_admin(),public.sowrix_has_module_access(text) TO anon;

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY; REVOKE ALL ON public.user_roles FROM PUBLIC,anon,authenticated; GRANT SELECT,INSERT,UPDATE,DELETE ON public.user_roles TO authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.user_roles; CREATE POLICY sowrix_v3_select_allow ON public.user_roles AS PERMISSIVE FOR SELECT TO authenticated USING (user_id=auth.uid() OR public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.user_roles; CREATE POLICY sowrix_v3_select_scope ON public.user_roles AS RESTRICTIVE FOR SELECT TO authenticated USING (user_id=auth.uid() OR public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.user_roles; CREATE POLICY sowrix_v3_insert_allow ON public.user_roles AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.user_roles; CREATE POLICY sowrix_v3_insert_scope ON public.user_roles AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.user_roles; CREATE POLICY sowrix_v3_update_allow ON public.user_roles AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_admin()) WITH CHECK (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.user_roles; CREATE POLICY sowrix_v3_update_scope ON public.user_roles AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_admin()) WITH CHECK (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.user_roles; CREATE POLICY sowrix_v3_delete_allow ON public.user_roles AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.user_roles; CREATE POLICY sowrix_v3_delete_scope ON public.user_roles AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

ALTER TABLE public.site_content ENABLE ROW LEVEL SECURITY; REVOKE ALL ON public.site_content FROM PUBLIC,anon,authenticated; GRANT SELECT,INSERT,UPDATE,DELETE ON public.site_content TO authenticated;

GRANT SELECT ON public.site_content TO anon;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.site_content; CREATE POLICY sowrix_v3_select_allow ON public.site_content AS PERMISSIVE FOR SELECT TO anon,authenticated USING (public.sowrix_access_admin() OR (collection IN ('industries','solutions','testimonials','faqs','social') AND lower(record->>'status') IN ('published','active')) OR collection IN ('settings','seo'));

DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.site_content; CREATE POLICY sowrix_v3_select_scope ON public.site_content AS RESTRICTIVE FOR SELECT TO anon,authenticated USING (public.sowrix_access_admin() OR (collection IN ('industries','solutions','testimonials','faqs','social') AND lower(record->>'status') IN ('published','active')) OR collection IN ('settings','seo'));

DROP POLICY IF EXISTS sowrix_v3_insert_allow ON public.site_content; CREATE POLICY sowrix_v3_insert_allow ON public.site_content AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_insert_scope ON public.site_content; CREATE POLICY sowrix_v3_insert_scope ON public.site_content AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.site_content; CREATE POLICY sowrix_v3_update_allow ON public.site_content AS PERMISSIVE FOR UPDATE TO authenticated USING (public.sowrix_access_admin()) WITH CHECK (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.site_content; CREATE POLICY sowrix_v3_update_scope ON public.site_content AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_access_admin()) WITH CHECK (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.site_content; CREATE POLICY sowrix_v3_delete_allow ON public.site_content AS PERMISSIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());

DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.site_content; CREATE POLICY sowrix_v3_delete_scope ON public.site_content AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_access_admin());


-- Private resumes: applicants may upload; only permitted recruitment staff can read.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('resumes','resumes',false,5242880,ARRAY['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
DROP POLICY IF EXISTS sowrix_resume_upload ON storage.objects;
CREATE POLICY sowrix_resume_upload ON storage.objects FOR INSERT TO anon,authenticated
 WITH CHECK(bucket_id='resumes' AND (storage.foldername(name))[1]='applications' AND lower(storage.extension(name)) IN ('pdf','doc','docx'));
DROP POLICY IF EXISTS sowrix_resume_read ON storage.objects;
CREATE POLICY sowrix_resume_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='resumes' AND public.sowrix_has_module_access('applications') AND public.sowrix_access_role() IN ('admin','super_admin','hr','hr_staff','hr_manager'));
DROP POLICY IF EXISTS sowrix_resume_read_scope ON storage.objects;
CREATE POLICY sowrix_resume_read_scope ON storage.objects AS RESTRICTIVE FOR SELECT TO anon,authenticated USING(bucket_id<>'resumes' OR (public.sowrix_has_module_access('applications') AND public.sowrix_access_role() IN ('admin','super_admin','hr','hr_staff','hr_manager')));
-- Avoid anonymous overwrites/deletes if legacy storage policies are broad.
DROP POLICY IF EXISTS sowrix_resume_update_scope ON storage.objects;
CREATE POLICY sowrix_resume_update_scope ON storage.objects AS RESTRICTIVE FOR UPDATE TO anon,authenticated USING(bucket_id<>'resumes') WITH CHECK(bucket_id<>'resumes');
DROP POLICY IF EXISTS sowrix_resume_delete_scope ON storage.objects;
CREATE POLICY sowrix_resume_delete_scope ON storage.objects AS RESTRICTIVE FOR DELETE TO anon,authenticated USING(bucket_id<>'resumes' OR public.sowrix_access_admin());
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_role_user_unique ON public.user_roles(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_attendance_day_unique ON public.attendance_records(employee_user_id,attendance_date);
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_blog_slug_unique ON public.blog_posts(slug);
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_service_slug_unique ON public.services(slug);
CREATE INDEX IF NOT EXISTS sowrix_task_assignee_idx ON public.tasks(assignee_id);
CREATE INDEX IF NOT EXISTS sowrix_project_manager_idx ON public.projects(manager_id);
CREATE INDEX IF NOT EXISTS sowrix_client_user_idx ON public.clients(auth_user_id);
CREATE INDEX IF NOT EXISTS sowrix_notification_user_idx ON public.notifications(user_id);
-- Included by sowrix-complete-setup.sql; run with that setup.
CREATE OR REPLACE FUNCTION public.sowrix_self_action(p_action text,p_id uuid DEFAULT NULL,p_value text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result_id uuid; uid uuid:=auth.uid(); r text:=public.sowrix_access_role(); today date:=(now() AT TIME ZONE 'Asia/Kolkata')::date; clock time:=(now() AT TIME ZONE 'Asia/Kolkata')::time;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 IF p_action='task' THEN
  IF r<>'employee' OR NOT public.sowrix_has_module_access('tasks') THEN RAISE EXCEPTION 'Task access required' USING ERRCODE='42501'; END IF;
  IF p_value NOT IN ('in_progress','done') OR p_value IS NULL THEN RAISE EXCEPTION 'Invalid task status'; END IF;
  UPDATE public.tasks SET status=p_value,completed_at=CASE WHEN p_value='done' THEN now() ELSE NULL END,updated_at=now()
   WHERE id=p_id AND assignee_id=uid AND status NOT IN ('cancelled') RETURNING id INTO result_id;
 ELSIF p_action='notification' THEN
  IF NOT public.sowrix_has_module_access('notifications') THEN RAISE EXCEPTION 'Notifications access required' USING ERRCODE='42501'; END IF;
  UPDATE public.notifications SET read_at=now(),updated_at=now() WHERE id=p_id AND user_id=uid RETURNING id INTO result_id;
 ELSIF p_action IN ('check_in','check_out') THEN
  IF r<>'employee' OR NOT public.sowrix_has_module_access('attendance') THEN RAISE EXCEPTION 'Attendance access required' USING ERRCODE='42501'; END IF;
  IF p_action='check_in' THEN
   INSERT INTO public.attendance_records(employee_user_id,attendance_date,check_in,status)
   VALUES(uid,today,clock,'present') ON CONFLICT(employee_user_id,attendance_date) DO NOTHING RETURNING id INTO result_id;
   IF result_id IS NULL THEN RAISE EXCEPTION 'You have already checked in today'; END IF;
  ELSE
   UPDATE public.attendance_records SET check_out=clock,updated_at=now()
   WHERE employee_user_id=uid AND attendance_date=today AND check_in IS NOT NULL AND check_out IS NULL RETURNING id INTO result_id;
  END IF;
 ELSE RAISE EXCEPTION 'Unknown action';
 END IF;
 IF result_id IS NULL THEN RAISE EXCEPTION 'No accessible record was updated. Check in first or refresh your records.' USING ERRCODE='42501'; END IF;
 RETURN result_id;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_self_action(text,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_self_action(text,uuid,text) TO authenticated;
-- Database-owned audit writes record the authenticated actor, including RPC changes.
CREATE OR REPLACE FUNCTION public.sowrix_record_audit() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),lower(TG_OP),TG_TABLE_NAME,CASE WHEN TG_OP='DELETE' THEN OLD.id::text ELSE NEW.id::text END,'{}'::jsonb);
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_record_audit() FROM PUBLIC,anon,authenticated;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['clients','projects','tasks','invoices','expenses','quotations','support_tickets','employees','attendance_records','leave_requests','payroll_records','notifications','interviews','departments','jobs','job_applications','services','portfolio_projects','blog_posts','contact_enquiries','task_comments','site_content'] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS sowrix_audit_change ON public.%I',t);
  EXECUTE format('CREATE TRIGGER sowrix_audit_change AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.sowrix_record_audit()',t);
 END LOOP;
END $$;
REVOKE INSERT,UPDATE,DELETE ON public.audit_logs FROM authenticated;

-- Add employee names and employee codes to Attendance without exposing auth.users
-- or requiring HR/Employee accounts to open the Employees module.
-- Run after sowrix-complete-setup.sql in Supabase SQL Editor.
CREATE OR REPLACE FUNCTION public.sowrix_attendance_people(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, employee_code text, full_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
  target uuid;
  role_name text := public.sowrix_access_role();
  profile jsonb;
  auth_name text;
  code text;
  profile_table text;
BEGIN
  IF auth.uid() IS NULL OR role_name NOT IN ('admin','super_admin','hr','hr_manager','hr_staff','employee') THEN
    RAISE EXCEPTION 'Attendance access required' USING ERRCODE='42501';
  END IF;
  IF NOT public.sowrix_has_module_access('attendance') THEN
    RAISE EXCEPTION 'Attendance module access is not assigned' USING ERRCODE='42501';
  END IF;
  IF coalesce(cardinality(p_user_ids),0)>500 THEN
    RAISE EXCEPTION 'Request at most 500 employees' USING ERRCODE='22023';
  END IF;
  FOR target IN
    SELECT DISTINCT u.requested_id FROM unnest(coalesce(p_user_ids,'{}'::uuid[])) AS u(requested_id)
    WHERE u.requested_id IS NOT NULL
  LOOP
    -- Employees may resolve only their own attendance profile.
    IF role_name='employee' AND target<>auth.uid() THEN CONTINUE; END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.attendance_records a
      WHERE a.employee_user_id=target
        AND (role_name<>'employee' OR a.employee_user_id=auth.uid())
    ) THEN CONTINUE; END IF;

    SELECT u.raw_user_meta_data INTO profile
    FROM auth.users u WHERE u.id=target;
    auth_name := coalesce(nullif(btrim(profile->>'full_name'),''),
                          nullif(btrim(profile->>'name'),''),
                          nullif(btrim(profile->>'display_name'),''));

    -- Re-read directory profile because auth metadata is intentionally private.
    profile := '{}'::jsonb;
    FOREACH profile_table IN ARRAY ARRAY['employees','employee_profiles'] LOOP
      IF to_regclass('public.'||profile_table) IS NOT NULL THEN
        EXECUTE format(
          $query$SELECT to_jsonb(e) FROM public.%I e WHERE to_jsonb(e)->>'user_id'=$1 AND (nullif(btrim(to_jsonb(e)->>'full_name'),'') IS NOT NULL OR nullif(btrim(to_jsonb(e)->>'employee_code'),'') IS NOT NULL OR nullif(btrim(to_jsonb(e)->>'name'),'') IS NOT NULL) LIMIT 1$query$,
          profile_table
        ) INTO profile USING target::text;
        IF profile IS NOT NULL THEN EXIT; END IF;
      END IF;
    END LOOP;
    code := coalesce(nullif(btrim(profile->>'employee_code'),''),
                     nullif(btrim(profile->>'employee_id'),''),
                     nullif(btrim(profile->>'staff_id'),''));
    full_name := coalesce(nullif(btrim(profile->>'full_name'),''),
                          nullif(btrim(profile->>'display_name'),''),
                          nullif(btrim(profile->>'name'),''),
                          auth_name,
                          'Name not set');
    user_id := target;
    employee_code := coalesce(code,'—');
    RETURN NEXT;
  END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION public.sowrix_attendance_people(uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_attendance_people(uuid[]) TO authenticated;


-- Employee directory sync, employee-name display, and attendance edit restrictions.
-- Safe to run once after the earlier SOWRIX setup and attendance display migration.


-- The invite function uses an employee Auth UID as its internal key. Keep one
-- directory row per account so invitations can safely retry profile sync.
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_employees_user_unique
  ON public.employees(user_id) WHERE user_id IS NOT NULL;

-- Complete invitation setup in one transaction. This RPC is for the Edge
-- Function's service role only; browser sessions cannot assign roles.
CREATE OR REPLACE FUNCTION public.sowrix_sync_invited_employee(
  p_user_id uuid,
  p_email text,
  p_full_name text,
  p_employee_code text,
  p_department text,
  p_designation text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE existing_role text;
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  IF p_user_id IS NULL OR p_email IS NULL OR p_full_name IS NULL OR length(btrim(p_full_name))<2 THEN
    RAISE EXCEPTION 'Valid employee account details are required' USING ERRCODE='22023';
  END IF;
  SELECT lower(role::text) INTO existing_role FROM public.user_roles WHERE user_id=p_user_id;
  IF existing_role IS NOT NULL AND existing_role <> 'employee' THEN
    RAISE EXCEPTION 'This account already has a different role' USING ERRCODE='23514';
  END IF;
  INSERT INTO public.user_roles(user_id,role) VALUES(p_user_id,'employee')
    ON CONFLICT(user_id) DO NOTHING;
  INSERT INTO public.employees(user_id,email,full_name,employee_code,department,designation,employment_status)
    VALUES(p_user_id,lower(btrim(p_email)),btrim(p_full_name),nullif(btrim(p_employee_code),''),nullif(btrim(p_department),''),coalesce(nullif(btrim(p_designation),''),'Employee'),'active')
    ON CONFLICT(user_id) WHERE user_id IS NOT NULL DO UPDATE SET
      email=excluded.email,full_name=excluded.full_name,
      employee_code=coalesce(excluded.employee_code,public.employees.employee_code),
      department=coalesce(excluded.department,public.employees.department),
      designation=excluded.designation,employment_status='active',updated_at=now();
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_sync_invited_employee(uuid,text,text,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_sync_invited_employee(uuid,text,text,text,text,text) TO service_role;

-- Resolve only employees known to the directory. HR/Admin can see name/code
-- for modules they are assigned; employees can resolve only themselves.
CREATE OR REPLACE FUNCTION public.sowrix_people_display(p_user_ids uuid[])
RETURNS TABLE(user_id uuid,employee_code text,full_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $function$
DECLARE target uuid; role_name text:=public.sowrix_access_role(); profile jsonb; auth_name text; code text;
BEGIN
  IF auth.uid() IS NULL OR role_name NOT IN ('admin','super_admin','hr','hr_manager','hr_staff','employee') THEN
    RAISE EXCEPTION 'People module access required' USING ERRCODE='42501';
  END IF;
  IF role_name='employee' THEN
    IF NOT public.sowrix_has_module_access('attendance') THEN RAISE EXCEPTION 'Attendance access required' USING ERRCODE='42501'; END IF;
  ELSIF NOT (public.sowrix_has_module_access('employees') OR public.sowrix_has_module_access('attendance') OR public.sowrix_has_module_access('leaves') OR public.sowrix_has_module_access('payroll') OR public.sowrix_has_module_access('interviews')) THEN
    RAISE EXCEPTION 'People module access required' USING ERRCODE='42501';
  END IF;
  IF coalesce(cardinality(p_user_ids),0)>500 THEN RAISE EXCEPTION 'Request at most 500 employees' USING ERRCODE='22023'; END IF;
  FOR target IN SELECT DISTINCT x.uid FROM unnest(coalesce(p_user_ids,'{}'::uuid[])) AS x(uid) WHERE x.uid IS NOT NULL LOOP
    IF role_name='employee' AND target<>auth.uid() THEN CONTINUE; END IF;
    SELECT to_jsonb(e) INTO profile FROM public.employees e WHERE e.user_id=target LIMIT 1;
    IF profile IS NULL THEN CONTINUE; END IF;
    SELECT coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'),''),nullif(btrim(u.raw_user_meta_data->>'name'),''),nullif(btrim(u.raw_user_meta_data->>'display_name'),''))
      INTO auth_name FROM auth.users u WHERE u.id=target;
    code:=coalesce(nullif(btrim(profile->>'employee_code'),''),nullif(btrim(profile->>'employee_id'),''),nullif(btrim(profile->>'staff_id'),''));
    user_id:=target; employee_code:=coalesce(code,'—');
    full_name:=coalesce(nullif(btrim(profile->>'full_name'),''),nullif(btrim(profile->>'display_name'),''),nullif(btrim(profile->>'name'),''),auth_name,'Name not set');
    RETURN NEXT;
  END LOOP;
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_people_display(uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_people_display(uuid[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_employee_picker()
RETURNS TABLE(user_id uuid,employee_code text,full_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $function$
DECLARE role_name text:=public.sowrix_access_role();
BEGIN
  IF auth.uid() IS NULL OR role_name NOT IN ('admin','super_admin','hr','hr_manager','hr_staff') THEN
    RAISE EXCEPTION 'Employee assignment access required' USING ERRCODE='42501';
  END IF;
  IF NOT (public.sowrix_has_module_access('employees') OR public.sowrix_has_module_access('attendance') OR public.sowrix_has_module_access('leaves') OR public.sowrix_has_module_access('payroll') OR public.sowrix_has_module_access('interviews') OR public.sowrix_has_module_access('tasks') OR public.sowrix_has_module_access('tickets')) THEN
    RAISE EXCEPTION 'Employee assignment module access required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT e.user_id,coalesce(nullif(btrim(e.employee_code),''),'—'),coalesce(nullif(btrim(e.full_name),''),'Name not set')
    FROM public.employees e WHERE e.user_id IS NOT NULL AND e.employment_status<>'terminated'
    ORDER BY e.full_name,e.employee_code LIMIT 500;
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_employee_picker() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_employee_picker() TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_client_account_picker()
RETURNS TABLE(user_id uuid,email text,full_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.sowrix_access_admin() OR NOT public.sowrix_has_module_access('clients') THEN
    RAISE EXCEPTION 'Client account assignment access required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT u.id,u.email,coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'),''),nullif(btrim(u.raw_user_meta_data->>'name'),''),u.email)
    FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id
    WHERE lower(r.role::text)='client' ORDER BY u.email LIMIT 500;
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_client_account_picker() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_client_account_picker() TO authenticated;

-- HR may read attendance, but only Admin/Super Admin can change attendance rows.
DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.attendance_records;
CREATE POLICY sowrix_v3_update_allow ON public.attendance_records AS PERMISSIVE FOR UPDATE TO authenticated
  USING (public.sowrix_access_role() IN ('admin','super_admin'))
  WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));
DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.attendance_records;
CREATE POLICY sowrix_v3_update_scope ON public.attendance_records AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (public.sowrix_access_role() IN ('admin','super_admin'))
  WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));




NOTIFY pgrst, 'reload schema';


-- FILE: sowrix-employee-workflow.sql
-- Employee directory sync, employee-name display, and attendance edit restrictions.
-- Safe to run once after the earlier SOWRIX setup and attendance display migration.

-- The invite function uses an employee Auth UID as its internal key. Keep one
-- directory row per account so invitations can safely retry profile sync.
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_employees_user_unique
  ON public.employees(user_id) WHERE user_id IS NOT NULL;

-- Complete invitation setup in one transaction. This RPC is for the Edge
-- Function's service role only; browser sessions cannot assign roles.
CREATE OR REPLACE FUNCTION public.sowrix_sync_invited_employee(
  p_user_id uuid,
  p_email text,
  p_full_name text,
  p_employee_code text,
  p_department text,
  p_designation text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE existing_role text;
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  IF p_user_id IS NULL OR p_email IS NULL OR p_full_name IS NULL OR length(btrim(p_full_name))<2 THEN
    RAISE EXCEPTION 'Valid employee account details are required' USING ERRCODE='22023';
  END IF;
  SELECT lower(role::text) INTO existing_role FROM public.user_roles WHERE user_id=p_user_id;
  IF existing_role IS NOT NULL AND existing_role <> 'employee' THEN
    RAISE EXCEPTION 'This account already has a different role' USING ERRCODE='23514';
  END IF;
  INSERT INTO public.user_roles(user_id,role) VALUES(p_user_id,'employee')
    ON CONFLICT(user_id) DO NOTHING;
  INSERT INTO public.employees(user_id,email,full_name,employee_code,department,designation,employment_status)
    VALUES(p_user_id,lower(btrim(p_email)),btrim(p_full_name),nullif(btrim(p_employee_code),''),nullif(btrim(p_department),''),coalesce(nullif(btrim(p_designation),''),'Employee'),'active')
    ON CONFLICT(user_id) WHERE user_id IS NOT NULL DO UPDATE SET
      email=excluded.email,full_name=excluded.full_name,
      employee_code=coalesce(excluded.employee_code,public.employees.employee_code),
      department=coalesce(excluded.department,public.employees.department),
      designation=excluded.designation,employment_status='active',updated_at=now();
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_sync_invited_employee(uuid,text,text,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_sync_invited_employee(uuid,text,text,text,text,text) TO service_role;

-- Resolve only employees known to the directory. HR/Admin can see name/code
-- for modules they are assigned; employees can resolve only themselves.
CREATE OR REPLACE FUNCTION public.sowrix_people_display(p_user_ids uuid[])
RETURNS TABLE(user_id uuid,employee_code text,full_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $function$
DECLARE target uuid; role_name text:=public.sowrix_access_role(); profile jsonb; auth_name text; code text;
BEGIN
  IF auth.uid() IS NULL OR role_name NOT IN ('admin','super_admin','hr','hr_manager','hr_staff','employee') THEN
    RAISE EXCEPTION 'People module access required' USING ERRCODE='42501';
  END IF;
  IF role_name='employee' THEN
    IF NOT public.sowrix_has_module_access('attendance') THEN RAISE EXCEPTION 'Attendance access required' USING ERRCODE='42501'; END IF;
  ELSIF NOT (public.sowrix_has_module_access('employees') OR public.sowrix_has_module_access('attendance') OR public.sowrix_has_module_access('leaves') OR public.sowrix_has_module_access('payroll') OR public.sowrix_has_module_access('interviews')) THEN
    RAISE EXCEPTION 'People module access required' USING ERRCODE='42501';
  END IF;
  IF coalesce(cardinality(p_user_ids),0)>500 THEN RAISE EXCEPTION 'Request at most 500 employees' USING ERRCODE='22023'; END IF;
  FOR target IN SELECT DISTINCT x.uid FROM unnest(coalesce(p_user_ids,'{}'::uuid[])) AS x(uid) WHERE x.uid IS NOT NULL LOOP
    IF role_name='employee' AND target<>auth.uid() THEN CONTINUE; END IF;
    SELECT to_jsonb(e) INTO profile FROM public.employees e WHERE e.user_id=target LIMIT 1;
    IF profile IS NULL THEN CONTINUE; END IF;
    SELECT coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'),''),nullif(btrim(u.raw_user_meta_data->>'name'),''),nullif(btrim(u.raw_user_meta_data->>'display_name'),''))
      INTO auth_name FROM auth.users u WHERE u.id=target;
    code:=coalesce(nullif(btrim(profile->>'employee_code'),''),nullif(btrim(profile->>'employee_id'),''),nullif(btrim(profile->>'staff_id'),''));
    user_id:=target; employee_code:=coalesce(code,'—');
    full_name:=coalesce(nullif(btrim(profile->>'full_name'),''),nullif(btrim(profile->>'display_name'),''),nullif(btrim(profile->>'name'),''),auth_name,'Name not set');
    RETURN NEXT;
  END LOOP;
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_people_display(uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_people_display(uuid[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_employee_picker()
RETURNS TABLE(user_id uuid,employee_code text,full_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $function$
DECLARE role_name text:=public.sowrix_access_role();
BEGIN
  IF auth.uid() IS NULL OR role_name NOT IN ('admin','super_admin','hr','hr_manager','hr_staff') THEN
    RAISE EXCEPTION 'Employee assignment access required' USING ERRCODE='42501';
  END IF;
  IF NOT (public.sowrix_has_module_access('employees') OR public.sowrix_has_module_access('attendance') OR public.sowrix_has_module_access('leaves') OR public.sowrix_has_module_access('payroll') OR public.sowrix_has_module_access('interviews') OR public.sowrix_has_module_access('tasks') OR public.sowrix_has_module_access('tickets')) THEN
    RAISE EXCEPTION 'Employee assignment module access required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT e.user_id,coalesce(nullif(btrim(e.employee_code),''),'—'),coalesce(nullif(btrim(e.full_name),''),'Name not set')
    FROM public.employees e WHERE e.user_id IS NOT NULL AND e.employment_status<>'terminated'
    ORDER BY e.full_name,e.employee_code LIMIT 500;
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_employee_picker() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_employee_picker() TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_client_account_picker()
RETURNS TABLE(user_id uuid,email text,full_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.sowrix_access_admin() OR NOT public.sowrix_has_module_access('clients') THEN
    RAISE EXCEPTION 'Client account assignment access required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT u.id,u.email,coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'),''),nullif(btrim(u.raw_user_meta_data->>'name'),''),u.email)
    FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id
    WHERE lower(r.role::text)='client' ORDER BY u.email LIMIT 500;
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_client_account_picker() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_client_account_picker() TO authenticated;

-- HR may read attendance, but only Admin/Super Admin can change attendance rows.
DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.attendance_records;
CREATE POLICY sowrix_v3_update_allow ON public.attendance_records AS PERMISSIVE FOR UPDATE TO authenticated
  USING (public.sowrix_access_role() IN ('admin','super_admin'))
  WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));
DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.attendance_records;
CREATE POLICY sowrix_v3_update_scope ON public.attendance_records AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (public.sowrix_access_role() IN ('admin','super_admin'))
  WITH CHECK (public.sowrix_access_role() IN ('admin','super_admin'));

NOTIFY pgrst, 'reload schema';


-- FILE: 04-feature-suite.sql
-- SOWRIX frontend suite: run after the existing complete setup and employee workflow SQL.
-- This creates new tables/policies only and does not execute automatically from HTML.

INSERT INTO public.sowrix_access_modules(module_key,allowed_roles) VALUES
 ('profile','{employee,hr,hr_manager,hr_staff}'),
 ('documents','{employee,hr,hr_manager,hr_staff}'),
 ('onboarding','{employee,hr,hr_manager,hr_staff}'),
 ('holidays','{employee,hr,hr_manager,hr_staff}'),
 ('announcements','{employee,hr,hr_manager,hr_staff}'),
 ('payslips','{employee}'),('client_quotes','{}')
ON CONFLICT(module_key) DO NOTHING;
CREATE TABLE IF NOT EXISTS public.sowrix_ui_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 kind text NOT NULL CHECK(kind IN ('profile','document','onboarding','acknowledgement','holiday','announcement','leave_allowance','milestone','quote_response','archive')),
 owner_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 200),
 body text NOT NULL DEFAULT '',
 payload jsonb NOT NULL DEFAULT '{}',
 audience text NOT NULL DEFAULT 'private' CHECK(audience IN ('private','all_staff','department','role')),
 audience_value text NOT NULL DEFAULT '',
 status text NOT NULL DEFAULT 'active',
 due_date date,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sowrix_ui_owner_kind ON public.sowrix_ui_records(owner_id,kind);
ALTER TABLE public.sowrix_ui_records ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_ui_records FROM anon, PUBLIC;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.sowrix_ui_records TO authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_ui_module(k text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE k WHEN 'document' THEN 'documents' WHEN 'acknowledgement' THEN 'onboarding' WHEN 'holiday' THEN 'holidays' WHEN 'announcement' THEN 'announcements' WHEN 'leave_allowance' THEN 'leaves' WHEN 'milestone' THEN 'projects' WHEN 'quote_response' THEN 'client_quotes' WHEN 'archive' THEN 'audit' ELSE k END
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_manager(k text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_access_admin() OR (public.sowrix_has_module_access(public.sowrix_ui_module(k)) AND
 ((public.sowrix_access_role() IN ('hr','hr_manager','hr_staff') AND k IN ('document','onboarding','holiday','announcement','leave_allowance')) OR
 (public.sowrix_access_role()='project_manager' AND k IN ('milestone','announcement'))))
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_visible(r public.sowrix_ui_records) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND public.sowrix_has_module_access(public.sowrix_ui_module(r.kind)) AND (
 public.sowrix_access_admin() OR public.sowrix_ui_manager(r.kind) OR r.owner_id=auth.uid() OR (r.kind='milestone' AND public.sowrix_project_scope((r.payload->>'project_id')::uuid)) OR
 (r.status='active' AND r.kind IN ('holiday','announcement','onboarding') AND (
  (r.audience='all_staff' AND public.sowrix_access_role()<>'client') OR
  (r.audience='role' AND r.audience_value=public.sowrix_access_role()) OR
  (r.audience='department' AND EXISTS(SELECT 1 FROM public.employees e WHERE e.user_id=auth.uid() AND e.department=r.audience_value))
 )))
$$;
DROP POLICY IF EXISTS sowrix_ui_read ON public.sowrix_ui_records;
CREATE POLICY sowrix_ui_read ON public.sowrix_ui_records FOR SELECT TO authenticated USING(public.sowrix_ui_visible(sowrix_ui_records));
DROP POLICY IF EXISTS sowrix_ui_insert ON public.sowrix_ui_records;
CREATE POLICY sowrix_ui_insert ON public.sowrix_ui_records FOR INSERT TO authenticated WITH CHECK(
 public.sowrix_has_module_access(public.sowrix_ui_module(kind)) AND (
 public.sowrix_ui_manager(kind) OR (owner_id=auth.uid() AND audience='private' AND kind IN ('profile','document','acknowledgement'))));
DROP POLICY IF EXISTS sowrix_ui_update ON public.sowrix_ui_records;
CREATE POLICY sowrix_ui_update ON public.sowrix_ui_records FOR UPDATE TO authenticated USING(
 public.sowrix_ui_manager(kind) OR (owner_id=auth.uid() AND kind IN ('profile','document','acknowledgement') AND public.sowrix_has_module_access(public.sowrix_ui_module(kind))))
 WITH CHECK(public.sowrix_ui_manager(kind) OR (owner_id=auth.uid() AND audience='private' AND kind IN ('profile','document','acknowledgement') AND public.sowrix_has_module_access(public.sowrix_ui_module(kind))));
DROP POLICY IF EXISTS sowrix_ui_delete ON public.sowrix_ui_records;
CREATE POLICY sowrix_ui_delete ON public.sowrix_ui_records FOR DELETE TO authenticated USING(public.sowrix_access_admin());
CREATE OR REPLACE FUNCTION public.sowrix_ui_stamp() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF TG_OP='UPDATE' AND (NEW.kind<>OLD.kind OR NEW.owner_id IS DISTINCT FROM OLD.owner_id) THEN RAISE EXCEPTION 'Record ownership/type cannot change'; END IF;
 IF NEW.kind IN ('document','profile') AND NEW.payload ? 'path' AND split_part(NEW.payload->>'path','/',1) IS DISTINCT FROM NEW.owner_id::text THEN RAISE EXCEPTION 'File owner mismatch'; END IF;
 IF NEW.kind='acknowledgement' AND NOT EXISTS(SELECT 1 FROM public.sowrix_ui_records p WHERE p.id::text=NEW.payload->>'item_id' AND p.kind='onboarding' AND public.sowrix_ui_visible(p)) THEN RAISE EXCEPTION 'Onboarding item unavailable'; END IF;
 IF NOT public.sowrix_ui_manager(NEW.kind) AND ((NEW.kind='document' AND NEW.status<>'pending') OR (NEW.kind='profile' AND NEW.status<>'active') OR (NEW.kind='acknowledgement' AND NEW.status<>'completed')) THEN RAISE EXCEPTION 'Invalid self-service status'; END IF;
 NEW.updated_at=now(); RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS sowrix_ui_stamp ON public.sowrix_ui_records;
CREATE TRIGGER sowrix_ui_stamp BEFORE INSERT OR UPDATE ON public.sowrix_ui_records FOR EACH ROW EXECUTE FUNCTION public.sowrix_ui_stamp();
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_ui_profile_unique ON public.sowrix_ui_records(owner_id) WHERE kind='profile';
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_ui_ack_unique ON public.sowrix_ui_records(owner_id,(payload->>'item_id')) WHERE kind='acknowledgement';
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES ('sowrix-private','sowrix-private',false,10485760,ARRAY['application/pdf','image/jpeg','image/png','image/webp']) ON CONFLICT(id) DO NOTHING;
DROP POLICY IF EXISTS sowrix_ui_files_read ON storage.objects;
CREATE POLICY sowrix_ui_files_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='sowrix-private' AND (
 (split_part(name,'/',1)=auth.uid()::text AND (public.sowrix_has_module_access('documents') OR public.sowrix_has_module_access('profile'))) OR
 EXISTS(SELECT 1 FROM public.sowrix_ui_records r WHERE r.kind IN ('document','profile') AND r.payload->>'path'=name AND public.sowrix_ui_visible(r))));
DROP POLICY IF EXISTS sowrix_ui_files_insert ON storage.objects;
CREATE POLICY sowrix_ui_files_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='sowrix-private' AND (
 (split_part(name,'/',1)=auth.uid()::text AND (public.sowrix_has_module_access('documents') OR public.sowrix_has_module_access('profile'))) OR public.sowrix_ui_manager('document')));
DROP POLICY IF EXISTS sowrix_ui_files_delete ON storage.objects;
CREATE POLICY sowrix_ui_files_delete ON storage.objects FOR DELETE TO authenticated USING(bucket_id='sowrix-private' AND (split_part(name,'/',1)=auth.uid()::text OR public.sowrix_access_admin()));
CREATE OR REPLACE FUNCTION public.sowrix_ui_employee_self() RETURNS SETOF public.employees LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT e.* FROM public.employees e WHERE e.user_id=auth.uid() AND public.sowrix_has_module_access('profile')
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_payslips() RETURNS SETOF public.payroll_records LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT p.* FROM public.payroll_records p WHERE p.employee_user_id=auth.uid() AND p.status IN ('approved','paid') AND public.sowrix_has_module_access('payslips') ORDER BY p.period DESC
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_invitations() RETURNS TABLE(employee_code text,full_name text,email text,department text,designation text,invited_at timestamptz,activation_status text) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT (public.sowrix_access_role() IN ('admin','super_admin','hr','hr_manager','hr_staff') AND public.sowrix_has_module_access('employees')) THEN RAISE EXCEPTION 'Employee administration access required'; END IF;
 RETURN QUERY SELECT e.employee_code,e.full_name,e.email,e.department,e.designation,u.invited_at,
 CASE WHEN u.id IS NULL THEN 'Not linked' WHEN u.encrypted_password IS NOT NULL AND u.encrypted_password<>'' AND u.email_confirmed_at IS NOT NULL THEN 'Account activated' ELSE 'Pending' END
 FROM public.employees e LEFT JOIN auth.users u ON u.id=e.user_id ORDER BY e.created_at DESC;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_quotes() RETURNS SETOF public.quotations LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT q.* FROM public.quotations q JOIN public.clients c ON c.id=q.client_id WHERE c.auth_user_id=auth.uid() AND public.sowrix_access_role()='client' AND q.status<>'draft'
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_respond_quote(p_id uuid,p_status text,p_comment text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE q public.quotations;
BEGIN
 SELECT * INTO q FROM public.quotations WHERE id=p_id FOR UPDATE;
 IF auth.uid() IS NULL OR public.sowrix_access_role()<>'client' OR NOT EXISTS(SELECT 1 FROM public.clients c WHERE c.id=q.client_id AND c.auth_user_id=auth.uid()) THEN RAISE EXCEPTION 'Quotation not available'; END IF;
 IF q.status<>'sent' OR (q.valid_until IS NOT NULL AND q.valid_until<current_date) THEN RAISE EXCEPTION 'Quotation already answered or expired'; END IF;
 IF p_status NOT IN ('accepted','rejected') OR length(p_comment)>2000 THEN RAISE EXCEPTION 'Invalid response'; END IF;
 UPDATE public.quotations SET status=p_status,updated_at=now() WHERE id=p_id;
 INSERT INTO public.sowrix_ui_records(kind,owner_id,title,body,payload) VALUES('quote_response',auth.uid(),q.quotation_number,p_comment,jsonb_build_object('quote_id',q.id,'decision',p_status));
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_archive(p_table text,p_id uuid,p_restore boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE prior text; m text; rec public.sowrix_ui_records;
BEGIN
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin access required'; END IF;
 m=CASE p_table WHEN 'clients' THEN 'clients' WHEN 'projects' THEN 'projects' WHEN 'jobs' THEN 'jobs' WHEN 'blog_posts' THEN 'blog' WHEN 'portfolio_projects' THEN 'portfolio' WHEN 'services' THEN 'services' WHEN 'contact_enquiries' THEN 'enquiries' END;
 IF m IS NULL THEN RAISE EXCEPTION 'This record type cannot be archived'; END IF;
 EXECUTE format('SELECT status FROM public.%I WHERE id=$1 FOR UPDATE',p_table) INTO prior USING p_id;
 IF prior IS NULL THEN RAISE EXCEPTION 'Record not found'; END IF;
 IF p_restore THEN
  SELECT * INTO rec FROM public.sowrix_ui_records WHERE kind='archive' AND payload->>'table'=p_table AND payload->>'record_id'=p_id::text AND status='active' ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF rec.id IS NULL OR prior<>'archived' THEN RAISE EXCEPTION 'No restorable archive'; END IF;
  EXECUTE format('UPDATE public.%I SET status=$1,updated_at=now() WHERE id=$2',p_table) USING rec.payload->>'previous_status',p_id;
  UPDATE public.sowrix_ui_records SET status='restored' WHERE id=rec.id;
 ELSE
  IF prior='archived' THEN RAISE EXCEPTION 'Record is already archived'; END IF;
  EXECUTE format('UPDATE public.%I SET status=$1,updated_at=now() WHERE id=$2',p_table) USING 'archived',p_id;
  INSERT INTO public.sowrix_ui_records(kind,owner_id,title,payload) VALUES('archive',auth.uid(),m,jsonb_build_object('table',p_table,'record_id',p_id,'previous_status',prior));
 END IF;
END $$;
DO $$ DECLARE f text; BEGIN FOREACH f IN ARRAY ARRAY['sowrix_ui_module(text)','sowrix_ui_manager(text)','sowrix_ui_visible(public.sowrix_ui_records)','sowrix_ui_employee_self()','sowrix_ui_payslips()','sowrix_ui_invitations()','sowrix_ui_quotes()','sowrix_ui_respond_quote(uuid,text,text)','sowrix_ui_archive(text,uuid,boolean)'] LOOP
 EXECUTE 'REVOKE ALL ON FUNCTION public.'||f||' FROM PUBLIC,anon';
 EXECUTE 'GRANT EXECUTE ON FUNCTION public.'||f||' TO authenticated';
END LOOP; END $$;
CREATE TABLE IF NOT EXISTS public.sowrix_invite_cooldowns(email text PRIMARY KEY,last_sent timestamptz NOT NULL);
ALTER TABLE public.sowrix_invite_cooldowns ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_invite_cooldowns FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_ui_invite_claim(p_email text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE claimed text;
BEGIN
 INSERT INTO public.sowrix_invite_cooldowns(email,last_sent) VALUES(lower(p_email),now()) ON CONFLICT(email) DO UPDATE SET last_sent=now() WHERE public.sowrix_invite_cooldowns.last_sent < now()-interval '60 seconds' RETURNING email INTO claimed;
 IF claimed IS NULL THEN RAISE EXCEPTION 'Invitation cooldown'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ui_invite_claim(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_ui_invite_claim(text) TO service_role;
-- Read-only HR attendance is enforced independently of permissive policies.
DROP POLICY IF EXISTS sowrix_ui_attendance_update_guard ON public.attendance_records;
CREATE POLICY sowrix_ui_attendance_update_guard ON public.attendance_records AS RESTRICTIVE FOR UPDATE TO authenticated USING(public.sowrix_access_role() NOT IN ('hr','hr_manager','hr_staff')) WITH CHECK(public.sowrix_access_role() NOT IN ('hr','hr_manager','hr_staff'));
-- Server-side activity history for the new records.
CREATE OR REPLACE FUNCTION public.sowrix_ui_audit() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),lower(TG_OP),NEW.kind,NEW.id::text,jsonb_build_object('title',NEW.title,'status',NEW.status));
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS sowrix_ui_audit ON public.sowrix_ui_records;
CREATE TRIGGER sowrix_ui_audit AFTER INSERT OR UPDATE ON public.sowrix_ui_records FOR EACH ROW EXECUTE FUNCTION public.sowrix_ui_audit();
CREATE OR REPLACE FUNCTION public.sowrix_ui_notify() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_TABLE_NAME='tasks' THEN
  IF NEW.assignee_id IS NOT NULL AND (TG_OP='INSERT' OR NEW.assignee_id IS DISTINCT FROM OLD.assignee_id) THEN
   INSERT INTO public.notifications(user_id,category,title,body) VALUES(NEW.assignee_id,'task','Task assigned',NEW.title);
  END IF;
 ELSIF TG_TABLE_NAME='leave_requests' AND NEW.status IS DISTINCT FROM OLD.status THEN
  INSERT INTO public.notifications(user_id,category,title,body) VALUES(NEW.employee_user_id,'leave','Leave request updated','Your leave request is now '||NEW.status||'.');
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS sowrix_ui_task_notification ON public.tasks;
CREATE TRIGGER sowrix_ui_task_notification AFTER INSERT OR UPDATE OF assignee_id ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.sowrix_ui_notify();
DROP TRIGGER IF EXISTS sowrix_ui_leave_notification ON public.leave_requests;
CREATE TRIGGER sowrix_ui_leave_notification AFTER UPDATE OF status ON public.leave_requests FOR EACH ROW EXECUTE FUNCTION public.sowrix_ui_notify();
DROP POLICY IF EXISTS sowrix_ui_project_boundary ON public.sowrix_ui_records;
CREATE POLICY sowrix_ui_project_boundary ON public.sowrix_ui_records AS RESTRICTIVE FOR ALL TO authenticated
 USING(kind<>'milestone' OR public.sowrix_access_admin() OR public.sowrix_project_scope((payload->>'project_id')::uuid))
 WITH CHECK(kind<>'milestone' OR public.sowrix_access_admin() OR public.sowrix_project_scope((payload->>'project_id')::uuid));


-- FILE: 05-consultation-fix.sql
-- SOWRIX consultation intake and Admin inbox repair.
-- Run this entire file once in the SAME Supabase project's SQL Editor as postgres.
-- Replace index.html with the accompanying version. Safe to rerun; keeps existing enquiries.
-- This does not assign Admin roles or send emails. It saves requests in contact_enquiries.
-- Reference: https://supabase.com/docs/guides/database/functions

DO $preflight$
BEGIN
 IF to_regclass('public.user_roles') IS NULL THEN
  RAISE EXCEPTION 'Run the existing SOWRIX base setup first: public.user_roles is missing.';
 END IF;
END
$preflight$;

CREATE TABLE IF NOT EXISTS public.contact_enquiries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 name text NOT NULL, email text NOT NULL, phone text,
 service_interest text, message text NOT NULL,
 status text NOT NULL DEFAULT 'open', assigned_to uuid,
 company text, location text, budget text, submission_key uuid
);

ALTER TABLE public.contact_enquiries
 ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
 ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now(),
 ADD COLUMN IF NOT EXISTS name text,
 ADD COLUMN IF NOT EXISTS email text,
 ADD COLUMN IF NOT EXISTS phone text,
 ADD COLUMN IF NOT EXISTS service_interest text,
 ADD COLUMN IF NOT EXISTS message text,
 ADD COLUMN IF NOT EXISTS status text DEFAULT 'open',
 ADD COLUMN IF NOT EXISTS assigned_to uuid,
 ADD COLUMN IF NOT EXISTS company text,
 ADD COLUMN IF NOT EXISTS location text,
 ADD COLUMN IF NOT EXISTS budget text,
 ADD COLUMN IF NOT EXISTS submission_key uuid;

DO $compatibility$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM information_schema.columns
   WHERE table_schema='public' AND table_name='contact_enquiries' AND column_name='id' AND udt_name='uuid') THEN
  RAISE EXCEPTION 'contact_enquiries.id must be uuid. No data has been changed; reconcile this existing column first.';
 END IF;
 -- Preserve service labels from older SOWRIX schemas.
 IF EXISTS (SELECT 1 FROM information_schema.columns
   WHERE table_schema='public' AND table_name='contact_enquiries' AND column_name='service') THEN
  EXECUTE 'UPDATE public.contact_enquiries SET service_interest=service::text WHERE service_interest IS NULL AND service IS NOT NULL';
 END IF;
END
$compatibility$;

ALTER TABLE public.contact_enquiries
 ALTER COLUMN id SET DEFAULT gen_random_uuid(),
 ALTER COLUMN created_at SET DEFAULT now(),
 ALTER COLUMN updated_at SET DEFAULT now(),
 ALTER COLUMN status SET DEFAULT 'open';
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_consultation_submission_unique
 ON public.contact_enquiries(submission_key);
CREATE INDEX IF NOT EXISTS sowrix_consultation_recent
 ON public.contact_enquiries(created_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS sowrix_consultation_open
 ON public.contact_enquiries(status) WHERE status='open';

-- Trust the existing role table, never a role claimed by a browser or user metadata.
CREATE OR REPLACE FUNCTION public.sowrix_consultation_is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $function$
 SELECT EXISTS (SELECT 1 FROM public.user_roles r
  WHERE r.user_id=auth.uid() AND lower(r.role::text) IN ('admin','super_admin'));
$function$;
REVOKE ALL ON FUNCTION public.sowrix_consultation_is_admin() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_consultation_is_admin() TO authenticated;

ALTER TABLE public.contact_enquiries ENABLE ROW LEVEL SECURITY;
-- Visitors submit through the narrow function below; they cannot read the inbox.
REVOKE ALL ON public.contact_enquiries FROM PUBLIC,anon,authenticated;
GRANT SELECT,UPDATE,DELETE ON public.contact_enquiries TO authenticated;
GRANT USAGE ON SCHEMA public TO anon,authenticated;

DROP POLICY IF EXISTS sowrix_v3_select_allow ON public.contact_enquiries;
CREATE POLICY sowrix_v3_select_allow ON public.contact_enquiries AS PERMISSIVE
 FOR SELECT TO authenticated USING (public.sowrix_consultation_is_admin());
DROP POLICY IF EXISTS sowrix_v3_select_scope ON public.contact_enquiries;
CREATE POLICY sowrix_v3_select_scope ON public.contact_enquiries AS RESTRICTIVE
 FOR SELECT TO authenticated USING (public.sowrix_consultation_is_admin());
DROP POLICY IF EXISTS sowrix_consultation_private ON public.contact_enquiries;
CREATE POLICY sowrix_consultation_private ON public.contact_enquiries AS RESTRICTIVE
 FOR SELECT TO anon USING (false);
DROP POLICY IF EXISTS sowrix_v3_update_allow ON public.contact_enquiries;
CREATE POLICY sowrix_v3_update_allow ON public.contact_enquiries AS PERMISSIVE
 FOR UPDATE TO authenticated USING (public.sowrix_consultation_is_admin())
 WITH CHECK (public.sowrix_consultation_is_admin());
DROP POLICY IF EXISTS sowrix_v3_update_scope ON public.contact_enquiries;
CREATE POLICY sowrix_v3_update_scope ON public.contact_enquiries AS RESTRICTIVE
 FOR UPDATE TO authenticated USING (public.sowrix_consultation_is_admin())
 WITH CHECK (public.sowrix_consultation_is_admin());
DROP POLICY IF EXISTS sowrix_v3_delete_allow ON public.contact_enquiries;
CREATE POLICY sowrix_v3_delete_allow ON public.contact_enquiries AS PERMISSIVE
 FOR DELETE TO authenticated USING (public.sowrix_consultation_is_admin());
DROP POLICY IF EXISTS sowrix_v3_delete_scope ON public.contact_enquiries;
CREATE POLICY sowrix_v3_delete_scope ON public.contact_enquiries AS RESTRICTIVE
 FOR DELETE TO authenticated USING (public.sowrix_consultation_is_admin());

-- SECURITY DEFINER is intentional for this public intake action. It accepts only
-- validated contact fields, forces open/unassigned state, and returns no private row.
-- Anonymous callers receive no SELECT permission. A random retry key deduplicates
-- repeated clicks/timeouts from the same form. It is not a public lookup endpoint.
CREATE OR REPLACE FUNCTION public.sowrix_submit_consultation(p_request jsonb,p_submission_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
 v_name text; v_email text; v_phone text; v_service text; v_message text;
 v_company text; v_location text; v_budget text; k text;
 insert_columns text; insert_values text; inserted_count bigint;
BEGIN
 IF p_submission_key IS NULL OR p_request IS NULL OR jsonb_typeof(p_request)<>'object' THEN
  RAISE EXCEPTION 'A request and retry key are required.' USING ERRCODE='22023';
 END IF;
 FOREACH k IN ARRAY ARRAY['name','email','phone','service_interest','message'] LOOP
  IF coalesce(jsonb_typeof(p_request->k),'null')<>'string' THEN
   RAISE EXCEPTION 'Required contact fields must be text.' USING ERRCODE='22023';
  END IF;
 END LOOP;
 FOREACH k IN ARRAY ARRAY['company','location','budget'] LOOP
  IF coalesce(jsonb_typeof(p_request->k),'null') NOT IN ('string','null') THEN
   RAISE EXCEPTION 'Optional contact fields must be text.' USING ERRCODE='22023';
  END IF;
 END LOOP;
 v_name=btrim(p_request->>'name');v_email=lower(btrim(p_request->>'email'));
 v_phone=btrim(p_request->>'phone');v_service=btrim(p_request->>'service_interest');
 v_message=btrim(p_request->>'message');v_company=nullif(btrim(p_request->>'company'),'');
 v_location=nullif(btrim(p_request->>'location'),'');v_budget=nullif(btrim(p_request->>'budget'),'');
 IF length(v_name) NOT BETWEEN 2 AND 250
  OR length(v_email)>254 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]{2,}$'
  OR v_phone !~ '^[+0-9][0-9 ()-]{7,18}$'
  OR length(v_service) NOT BETWEEN 2 AND 250 OR length(v_message) NOT BETWEEN 20 AND 10000
  OR coalesce(length(v_company),0)>250 OR coalesce(length(v_location),0)>250
  OR coalesce(length(v_budget),0)>100 THEN
  RAISE EXCEPTION 'Check the name, email, phone, service and project description.' USING ERRCODE='22023';
 END IF;

 insert_columns='name,email,phone,service_interest,message,company,location,budget,submission_key,status,assigned_to';
 insert_values='$1,$2,$3,$4,$5,$6,$7,$8,$9,''open'',NULL';
 -- Some earlier versions required service or subject. Populate them when present
 -- instead of deleting legacy columns, weakening constraints, or dropping data.
 IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='contact_enquiries' AND column_name='service') THEN
  insert_columns=insert_columns||',service';insert_values=insert_values||',$4';
 END IF;
 IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='contact_enquiries' AND column_name='subject') THEN
  insert_columns=insert_columns||',subject';insert_values=insert_values||',$4';
 END IF;
 EXECUTE 'INSERT INTO public.contact_enquiries ('||insert_columns||') VALUES ('||insert_values||') ON CONFLICT (submission_key) DO NOTHING'
  USING v_name,v_email,v_phone,v_service,v_message,v_company,v_location,v_budget,p_submission_key;
 GET DIAGNOSTICS inserted_count=ROW_COUNT;
 IF inserted_count=0 AND NOT EXISTS (
  SELECT 1 FROM public.contact_enquiries e WHERE e.submission_key=p_submission_key
   AND e.name=v_name AND e.email=v_email AND e.phone=v_phone AND e.service_interest=v_service
   AND e.message=v_message AND e.company IS NOT DISTINCT FROM v_company
   AND e.location IS NOT DISTINCT FROM v_location AND e.budget IS NOT DISTINCT FROM v_budget
 ) THEN
  RAISE EXCEPTION 'Retry key conflict. Open a new form.' USING ERRCODE='22023';
 END IF;
 RETURN jsonb_build_object('accepted',true);
END
$function$;
REVOKE ALL ON FUNCTION public.sowrix_submit_consultation(jsonb,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_submit_consultation(jsonb,uuid) TO anon,authenticated;

NOTIFY pgrst,'reload schema';

-- This checks installation without creating a fake customer request.
SELECT 'Consultation setup ready. Replace index.html, refresh, and submit a test enquiry.' AS result;


-- FILE: 06-granular-access.sql
-- SOWRIX v4: granular access and auditable role assignment.
-- Corrected installer: repairs missing module keys and installs the feature suite
-- prerequisite only when its objects are missing. Uses the existing SOWRIX backend.
-- Run this WHOLE file in Supabase SQL Editor as the project owner.
-- Existing allowed_roles values and user assignments are preserved by the repair.
-- Base setup must already exist; no tables, accounts or business records are deleted.

-- Check the existing backend before writing anything.
DO $sowrix_preflight$
DECLARE missing text;
BEGIN
 SELECT string_agg(name, ', ' ORDER BY name) INTO missing
 FROM unnest(ARRAY['user_roles','sowrix_access_modules','sowrix_module_access','clients','projects','tasks','invoices','expenses','quotations','support_tickets','employees','attendance_records','leave_requests','payroll_records','notifications','audit_logs','interviews','departments','jobs','job_applications','services','portfolio_projects','blog_posts','contact_enquiries','task_comments']::text[]) required(name)
 WHERE to_regclass('public.' || name) IS NULL;
 IF missing IS NOT NULL THEN
  RAISE EXCEPTION 'Existing SOWRIX base setup is incomplete.'
   USING ERRCODE='55000', DETAIL='Missing tables: ' || missing,
   HINT='Complete the matching existing base setup before running this access installer.';
 END IF;
 SELECT string_agg(signature, ', ' ORDER BY signature) INTO missing
 FROM unnest(ARRAY['sowrix_access_admin()','sowrix_access_role()','sowrix_has_module_access(text)','sowrix_project_scope(uuid)']::text[]) required(signature)
 WHERE to_regprocedure('public.' || signature) IS NULL;
 IF missing IS NOT NULL THEN
  RAISE EXCEPTION 'Existing SOWRIX access helpers are missing.'
   USING ERRCODE='55000', DETAIL=missing,
   HINT='Complete the existing base access setup; this installer does not replace account roles.';
 END IF;
END
$sowrix_preflight$;

-- Parent keys MUST exist before sowrix_permission_catalog references them.
-- This catalog is not a user grant. Preserve any existing role restrictions.
INSERT INTO public.sowrix_access_modules(module_key,allowed_roles) VALUES
 ('clients','{}'),('projects','{employee}'),('tasks','{employee}'),
 ('invoices','{}'),('expenses','{}'),('quotations','{}'),
 ('tickets','{hr,hr_manager,hr_staff,employee}'),
 ('employees','{hr,hr_manager,hr_staff}'),
 ('attendance','{hr,hr_manager,hr_staff,employee}'),
 ('leaves','{hr,hr_manager,hr_staff,employee}'),
 ('payroll','{hr_manager}'),('notifications','{hr,hr_manager,hr_staff,employee}'),
 ('audit','{}'),('interviews','{hr,hr_manager,hr_staff}'),
 ('departments','{hr,hr_manager,hr_staff}'),('jobs','{hr,hr_manager,hr_staff}'),
 ('applications','{hr,hr_manager,hr_staff}'),('services','{}'),
 ('portfolio','{}'),('blog','{}'),('enquiries','{}'),('task_comments','{employee}'),
 ('profile','{employee,hr,hr_manager,hr_staff}'),
 ('documents','{employee,hr,hr_manager,hr_staff}'),
 ('onboarding','{employee,hr,hr_manager,hr_staff}'),
 ('holidays','{employee,hr,hr_manager,hr_staff}'),
 ('announcements','{employee,hr,hr_manager,hr_staff}'),
 ('payslips','{employee}'),('client_quotes','{}')
ON CONFLICT(module_key) DO NOTHING;

-- Some older deployments have the base modules but never ran 04-feature-suite.
-- Install that dependency in this SAME transaction so a later error rolls it back.
-- A complete feature suite is left untouched on reruns.
DO $sowrix_feature_dependency$
BEGIN
 IF to_regclass('public.sowrix_ui_records') IS NULL
 OR to_regclass('public.sowrix_invite_cooldowns') IS NULL
 OR EXISTS (
  SELECT 1 FROM unnest(ARRAY['sowrix_ui_module','sowrix_ui_manager','sowrix_ui_visible','sowrix_ui_stamp','sowrix_ui_employee_self','sowrix_ui_payslips','sowrix_ui_invitations','sowrix_ui_quotes','sowrix_ui_respond_quote','sowrix_ui_archive','sowrix_ui_invite_claim','sowrix_ui_audit','sowrix_ui_notify']::text[]) required(name)
  WHERE NOT EXISTS (
   SELECT 1 FROM pg_catalog.pg_proc p
   JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname=required.name
  )
 ) THEN
  EXECUTE $sowrix_feature_source$
-- Module catalog entries were seeded above without changing existing rows.
CREATE TABLE IF NOT EXISTS public.sowrix_ui_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 kind text NOT NULL CHECK(kind IN ('profile','document','onboarding','acknowledgement','holiday','announcement','leave_allowance','milestone','quote_response','archive')),
 owner_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 200),
 body text NOT NULL DEFAULT '',
 payload jsonb NOT NULL DEFAULT '{}',
 audience text NOT NULL DEFAULT 'private' CHECK(audience IN ('private','all_staff','department','role')),
 audience_value text NOT NULL DEFAULT '',
 status text NOT NULL DEFAULT 'active',
 due_date date,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sowrix_ui_owner_kind ON public.sowrix_ui_records(owner_id,kind);
ALTER TABLE public.sowrix_ui_records ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_ui_records FROM anon, PUBLIC;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.sowrix_ui_records TO authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_ui_module(k text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE k WHEN 'document' THEN 'documents' WHEN 'acknowledgement' THEN 'onboarding' WHEN 'holiday' THEN 'holidays' WHEN 'announcement' THEN 'announcements' WHEN 'leave_allowance' THEN 'leaves' WHEN 'milestone' THEN 'projects' WHEN 'quote_response' THEN 'client_quotes' WHEN 'archive' THEN 'audit' ELSE k END
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_manager(k text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_access_admin() OR (public.sowrix_has_module_access(public.sowrix_ui_module(k)) AND
 ((public.sowrix_access_role() IN ('hr','hr_manager','hr_staff') AND k IN ('document','onboarding','holiday','announcement','leave_allowance')) OR
 (public.sowrix_access_role()='project_manager' AND k IN ('milestone','announcement'))))
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_visible(r public.sowrix_ui_records) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND public.sowrix_has_module_access(public.sowrix_ui_module(r.kind)) AND (
 public.sowrix_access_admin() OR public.sowrix_ui_manager(r.kind) OR r.owner_id=auth.uid() OR (r.kind='milestone' AND public.sowrix_project_scope((r.payload->>'project_id')::uuid)) OR
 (r.status='active' AND r.kind IN ('holiday','announcement','onboarding') AND (
  (r.audience='all_staff' AND public.sowrix_access_role()<>'client') OR
  (r.audience='role' AND r.audience_value=public.sowrix_access_role()) OR
  (r.audience='department' AND EXISTS(SELECT 1 FROM public.employees e WHERE e.user_id=auth.uid() AND e.department=r.audience_value))
 )))
$$;
DROP POLICY IF EXISTS sowrix_ui_read ON public.sowrix_ui_records;
CREATE POLICY sowrix_ui_read ON public.sowrix_ui_records FOR SELECT TO authenticated USING(public.sowrix_ui_visible(sowrix_ui_records));
DROP POLICY IF EXISTS sowrix_ui_insert ON public.sowrix_ui_records;
CREATE POLICY sowrix_ui_insert ON public.sowrix_ui_records FOR INSERT TO authenticated WITH CHECK(
 public.sowrix_has_module_access(public.sowrix_ui_module(kind)) AND (
 public.sowrix_ui_manager(kind) OR (owner_id=auth.uid() AND audience='private' AND kind IN ('profile','document','acknowledgement'))));
DROP POLICY IF EXISTS sowrix_ui_update ON public.sowrix_ui_records;
CREATE POLICY sowrix_ui_update ON public.sowrix_ui_records FOR UPDATE TO authenticated USING(
 public.sowrix_ui_manager(kind) OR (owner_id=auth.uid() AND kind IN ('profile','document','acknowledgement') AND public.sowrix_has_module_access(public.sowrix_ui_module(kind))))
 WITH CHECK(public.sowrix_ui_manager(kind) OR (owner_id=auth.uid() AND audience='private' AND kind IN ('profile','document','acknowledgement') AND public.sowrix_has_module_access(public.sowrix_ui_module(kind))));
DROP POLICY IF EXISTS sowrix_ui_delete ON public.sowrix_ui_records;
CREATE POLICY sowrix_ui_delete ON public.sowrix_ui_records FOR DELETE TO authenticated USING(public.sowrix_access_admin());
CREATE OR REPLACE FUNCTION public.sowrix_ui_stamp() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF TG_OP='UPDATE' AND (NEW.kind<>OLD.kind OR NEW.owner_id IS DISTINCT FROM OLD.owner_id) THEN RAISE EXCEPTION 'Record ownership/type cannot change'; END IF;
 IF NEW.kind IN ('document','profile') AND NEW.payload ? 'path' AND split_part(NEW.payload->>'path','/',1) IS DISTINCT FROM NEW.owner_id::text THEN RAISE EXCEPTION 'File owner mismatch'; END IF;
 IF NEW.kind='acknowledgement' AND NOT EXISTS(SELECT 1 FROM public.sowrix_ui_records p WHERE p.id::text=NEW.payload->>'item_id' AND p.kind='onboarding' AND public.sowrix_ui_visible(p)) THEN RAISE EXCEPTION 'Onboarding item unavailable'; END IF;
 IF NOT public.sowrix_ui_manager(NEW.kind) AND ((NEW.kind='document' AND NEW.status<>'pending') OR (NEW.kind='profile' AND NEW.status<>'active') OR (NEW.kind='acknowledgement' AND NEW.status<>'completed')) THEN RAISE EXCEPTION 'Invalid self-service status'; END IF;
 NEW.updated_at=now(); RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS sowrix_ui_stamp ON public.sowrix_ui_records;
CREATE TRIGGER sowrix_ui_stamp BEFORE INSERT OR UPDATE ON public.sowrix_ui_records FOR EACH ROW EXECUTE FUNCTION public.sowrix_ui_stamp();
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_ui_profile_unique ON public.sowrix_ui_records(owner_id) WHERE kind='profile';
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_ui_ack_unique ON public.sowrix_ui_records(owner_id,(payload->>'item_id')) WHERE kind='acknowledgement';
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES ('sowrix-private','sowrix-private',false,10485760,ARRAY['application/pdf','image/jpeg','image/png','image/webp']) ON CONFLICT(id) DO NOTHING;
DROP POLICY IF EXISTS sowrix_ui_files_read ON storage.objects;
CREATE POLICY sowrix_ui_files_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='sowrix-private' AND (
 (split_part(name,'/',1)=auth.uid()::text AND (public.sowrix_has_module_access('documents') OR public.sowrix_has_module_access('profile'))) OR
 EXISTS(SELECT 1 FROM public.sowrix_ui_records r WHERE r.kind IN ('document','profile') AND r.payload->>'path'=name AND public.sowrix_ui_visible(r))));
DROP POLICY IF EXISTS sowrix_ui_files_insert ON storage.objects;
CREATE POLICY sowrix_ui_files_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='sowrix-private' AND (
 (split_part(name,'/',1)=auth.uid()::text AND (public.sowrix_has_module_access('documents') OR public.sowrix_has_module_access('profile'))) OR public.sowrix_ui_manager('document')));
DROP POLICY IF EXISTS sowrix_ui_files_delete ON storage.objects;
CREATE POLICY sowrix_ui_files_delete ON storage.objects FOR DELETE TO authenticated USING(bucket_id='sowrix-private' AND (split_part(name,'/',1)=auth.uid()::text OR public.sowrix_access_admin()));
CREATE OR REPLACE FUNCTION public.sowrix_ui_employee_self() RETURNS SETOF public.employees LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT e.* FROM public.employees e WHERE e.user_id=auth.uid() AND public.sowrix_has_module_access('profile')
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_payslips() RETURNS SETOF public.payroll_records LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT p.* FROM public.payroll_records p WHERE p.employee_user_id=auth.uid() AND p.status IN ('approved','paid') AND public.sowrix_has_module_access('payslips') ORDER BY p.period DESC
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_invitations() RETURNS TABLE(employee_code text,full_name text,email text,department text,designation text,invited_at timestamptz,activation_status text) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT (public.sowrix_access_role() IN ('admin','super_admin','hr','hr_manager','hr_staff') AND public.sowrix_has_module_access('employees')) THEN RAISE EXCEPTION 'Employee administration access required'; END IF;
 RETURN QUERY SELECT e.employee_code,e.full_name,e.email,e.department,e.designation,u.invited_at,
 CASE WHEN u.id IS NULL THEN 'Not linked' WHEN u.encrypted_password IS NOT NULL AND u.encrypted_password<>'' AND u.email_confirmed_at IS NOT NULL THEN 'Account activated' ELSE 'Pending' END
 FROM public.employees e LEFT JOIN auth.users u ON u.id=e.user_id ORDER BY e.created_at DESC;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_quotes() RETURNS SETOF public.quotations LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT q.* FROM public.quotations q JOIN public.clients c ON c.id=q.client_id WHERE c.auth_user_id=auth.uid() AND public.sowrix_access_role()='client' AND q.status<>'draft'
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_respond_quote(p_id uuid,p_status text,p_comment text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE q public.quotations;
BEGIN
 SELECT * INTO q FROM public.quotations WHERE id=p_id FOR UPDATE;
 IF auth.uid() IS NULL OR public.sowrix_access_role()<>'client' OR NOT EXISTS(SELECT 1 FROM public.clients c WHERE c.id=q.client_id AND c.auth_user_id=auth.uid()) THEN RAISE EXCEPTION 'Quotation not available'; END IF;
 IF q.status<>'sent' OR (q.valid_until IS NOT NULL AND q.valid_until<current_date) THEN RAISE EXCEPTION 'Quotation already answered or expired'; END IF;
 IF p_status NOT IN ('accepted','rejected') OR length(p_comment)>2000 THEN RAISE EXCEPTION 'Invalid response'; END IF;
 UPDATE public.quotations SET status=p_status,updated_at=now() WHERE id=p_id;
 INSERT INTO public.sowrix_ui_records(kind,owner_id,title,body,payload) VALUES('quote_response',auth.uid(),q.quotation_number,p_comment,jsonb_build_object('quote_id',q.id,'decision',p_status));
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_archive(p_table text,p_id uuid,p_restore boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE prior text; m text; rec public.sowrix_ui_records;
BEGIN
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin access required'; END IF;
 m=CASE p_table WHEN 'clients' THEN 'clients' WHEN 'projects' THEN 'projects' WHEN 'jobs' THEN 'jobs' WHEN 'blog_posts' THEN 'blog' WHEN 'portfolio_projects' THEN 'portfolio' WHEN 'services' THEN 'services' WHEN 'contact_enquiries' THEN 'enquiries' END;
 IF m IS NULL THEN RAISE EXCEPTION 'This record type cannot be archived'; END IF;
 EXECUTE format('SELECT status FROM public.%I WHERE id=$1 FOR UPDATE',p_table) INTO prior USING p_id;
 IF prior IS NULL THEN RAISE EXCEPTION 'Record not found'; END IF;
 IF p_restore THEN
  SELECT * INTO rec FROM public.sowrix_ui_records WHERE kind='archive' AND payload->>'table'=p_table AND payload->>'record_id'=p_id::text AND status='active' ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF rec.id IS NULL OR prior<>'archived' THEN RAISE EXCEPTION 'No restorable archive'; END IF;
  EXECUTE format('UPDATE public.%I SET status=$1,updated_at=now() WHERE id=$2',p_table) USING rec.payload->>'previous_status',p_id;
  UPDATE public.sowrix_ui_records SET status='restored' WHERE id=rec.id;
 ELSE
  IF prior='archived' THEN RAISE EXCEPTION 'Record is already archived'; END IF;
  EXECUTE format('UPDATE public.%I SET status=$1,updated_at=now() WHERE id=$2',p_table) USING 'archived',p_id;
  INSERT INTO public.sowrix_ui_records(kind,owner_id,title,payload) VALUES('archive',auth.uid(),m,jsonb_build_object('table',p_table,'record_id',p_id,'previous_status',prior));
 END IF;
END $$;
DO $$ DECLARE f text; BEGIN FOREACH f IN ARRAY ARRAY['sowrix_ui_module(text)','sowrix_ui_manager(text)','sowrix_ui_visible(public.sowrix_ui_records)','sowrix_ui_employee_self()','sowrix_ui_payslips()','sowrix_ui_invitations()','sowrix_ui_quotes()','sowrix_ui_respond_quote(uuid,text,text)','sowrix_ui_archive(text,uuid,boolean)'] LOOP
 EXECUTE 'REVOKE ALL ON FUNCTION public.'||f||' FROM PUBLIC,anon';
 EXECUTE 'GRANT EXECUTE ON FUNCTION public.'||f||' TO authenticated';
END LOOP; END $$;
CREATE TABLE IF NOT EXISTS public.sowrix_invite_cooldowns(email text PRIMARY KEY,last_sent timestamptz NOT NULL);
ALTER TABLE public.sowrix_invite_cooldowns ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_invite_cooldowns FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_ui_invite_claim(p_email text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE claimed text;
BEGIN
 INSERT INTO public.sowrix_invite_cooldowns(email,last_sent) VALUES(lower(p_email),now()) ON CONFLICT(email) DO UPDATE SET last_sent=now() WHERE public.sowrix_invite_cooldowns.last_sent < now()-interval '60 seconds' RETURNING email INTO claimed;
 IF claimed IS NULL THEN RAISE EXCEPTION 'Invitation cooldown'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ui_invite_claim(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_ui_invite_claim(text) TO service_role;
-- Read-only HR attendance is enforced independently of permissive policies.
DROP POLICY IF EXISTS sowrix_ui_attendance_update_guard ON public.attendance_records;
CREATE POLICY sowrix_ui_attendance_update_guard ON public.attendance_records AS RESTRICTIVE FOR UPDATE TO authenticated USING(public.sowrix_access_role() NOT IN ('hr','hr_manager','hr_staff')) WITH CHECK(public.sowrix_access_role() NOT IN ('hr','hr_manager','hr_staff'));
-- Server-side activity history for the new records.
CREATE OR REPLACE FUNCTION public.sowrix_ui_audit() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),lower(TG_OP),NEW.kind,NEW.id::text,jsonb_build_object('title',NEW.title,'status',NEW.status));
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS sowrix_ui_audit ON public.sowrix_ui_records;
CREATE TRIGGER sowrix_ui_audit AFTER INSERT OR UPDATE ON public.sowrix_ui_records FOR EACH ROW EXECUTE FUNCTION public.sowrix_ui_audit();
CREATE OR REPLACE FUNCTION public.sowrix_ui_notify() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_TABLE_NAME='tasks' THEN
  IF NEW.assignee_id IS NOT NULL AND (TG_OP='INSERT' OR NEW.assignee_id IS DISTINCT FROM OLD.assignee_id) THEN
   INSERT INTO public.notifications(user_id,category,title,body) VALUES(NEW.assignee_id,'task','Task assigned',NEW.title);
  END IF;
 ELSIF TG_TABLE_NAME='leave_requests' AND NEW.status IS DISTINCT FROM OLD.status THEN
  INSERT INTO public.notifications(user_id,category,title,body) VALUES(NEW.employee_user_id,'leave','Leave request updated','Your leave request is now '||NEW.status||'.');
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS sowrix_ui_task_notification ON public.tasks;
CREATE TRIGGER sowrix_ui_task_notification AFTER INSERT OR UPDATE OF assignee_id ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.sowrix_ui_notify();
DROP TRIGGER IF EXISTS sowrix_ui_leave_notification ON public.leave_requests;
CREATE TRIGGER sowrix_ui_leave_notification AFTER UPDATE OF status ON public.leave_requests FOR EACH ROW EXECUTE FUNCTION public.sowrix_ui_notify();
DROP POLICY IF EXISTS sowrix_ui_project_boundary ON public.sowrix_ui_records;
CREATE POLICY sowrix_ui_project_boundary ON public.sowrix_ui_records AS RESTRICTIVE FOR ALL TO authenticated
 USING(kind<>'milestone' OR public.sowrix_access_admin() OR public.sowrix_project_scope((payload->>'project_id')::uuid))
 WITH CHECK(kind<>'milestone' OR public.sowrix_access_admin() OR public.sowrix_project_scope((payload->>'project_id')::uuid));

  $sowrix_feature_source$;
 END IF;
END
$sowrix_feature_dependency$;

-- Apply the v4 permission rules after all dependencies exist.
CREATE TABLE IF NOT EXISTS public.sowrix_permission_catalog (
 module_key text PRIMARY KEY REFERENCES public.sowrix_access_modules(module_key),
 label text NOT NULL, actions text[] NOT NULL, allow_wide boolean NOT NULL DEFAULT false,
 admin_only boolean NOT NULL DEFAULT false
);
INSERT INTO public.sowrix_permission_catalog(module_key,label,actions,allow_wide,admin_only) VALUES
('clients','Client & CRM Management',ARRAY['view','create','edit','delete']::text[],true,false),
('projects','Project Management',ARRAY['view','create','edit','delete']::text[],true,false),
('tasks','Task & Delivery Board',ARRAY['view','create','edit','delete']::text[],true,false),
('invoices','Invoices & Receivables',ARRAY['view','create','edit','delete','approve']::text[],true,false),
('expenses','Expenses & Cost Tracking',ARRAY['view','create','edit','delete','approve']::text[],true,false),
('quotations','Quotations & Proposals',ARRAY['view','create','edit','delete','approve']::text[],true,false),
('tickets','Support & IT Service Desk',ARRAY['view','create','edit','delete']::text[],true,false),
('employees','Employee Directory',ARRAY['view','create','edit']::text[],true,false),
('attendance','Attendance Register',ARRAY['view','create','edit']::text[],false,false),
('leaves','Leave Requests',ARRAY['view','create','edit','approve']::text[],true,false),
('payroll','Payroll Records',ARRAY['view','create','edit','approve']::text[],true,false),
('notifications','Notifications Centre',ARRAY['view','create','edit']::text[],false,false),
('audit','Audit & Security Trail',ARRAY['view']::text[],false,true),
('interviews','Interview Scheduler',ARRAY['view','create','edit','delete']::text[],true,false),
('departments','Departments',ARRAY['view','create','edit','delete']::text[],true,false),
('jobs','Careers & Job Postings',ARRAY['view','create','edit','delete']::text[],true,false),
('applications','Recruitment Applications',ARRAY['view','edit','approve']::text[],true,false),
('services','Website Services CMS',ARRAY['view','create','edit','delete']::text[],true,false),
('portfolio','Portfolio CMS',ARRAY['view','create','edit','delete']::text[],true,false),
('blog','Blog & Articles CMS',ARRAY['view','create','edit','delete']::text[],true,false),
('enquiries','Contact Enquiries',ARRAY['view','edit','delete']::text[],false,true),
('task_comments','Task Comments',ARRAY['view','create']::text[],false,false),
('profile','My Profile',ARRAY['view','create','edit']::text[],false,false),
('documents','Documents',ARRAY['view','create','edit','delete','approve']::text[],false,false),
('onboarding','Onboarding',ARRAY['view','create','edit','delete']::text[],false,false),
('holidays','Company Holidays',ARRAY['view','create','edit','delete']::text[],false,false),
('announcements','Announcements',ARRAY['view','create','edit','delete']::text[],false,false),
('payslips','Own Payslips',ARRAY['view']::text[],false,false),
('client_quotes','Client Quotes',ARRAY['view','approve']::text[],false,false)
ON CONFLICT(module_key) DO UPDATE SET label=excluded.label,actions=excluded.actions,allow_wide=excluded.allow_wide,admin_only=excluded.admin_only;
CREATE TABLE IF NOT EXISTS public.sowrix_action_grants (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 module_key text NOT NULL REFERENCES public.sowrix_permission_catalog(module_key),
 actions text[] NOT NULL DEFAULT '{view}',
 row_scope text NOT NULL DEFAULT 'standard' CHECK(row_scope IN ('standard','all')),
 granted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 updated_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(user_id,module_key)
);
CREATE TABLE IF NOT EXISTS public.sowrix_access_revisions(user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,revision bigint NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS public.sowrix_upgrade_markers(name text PRIMARY KEY,applied_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.sowrix_permission_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_action_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_access_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_upgrade_markers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_permission_catalog,public.sowrix_action_grants,public.sowrix_access_revisions,public.sowrix_upgrade_markers FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.sowrix_permission_catalog,public.sowrix_action_grants TO authenticated;
DROP POLICY IF EXISTS sowrix_v4_catalog_read ON public.sowrix_permission_catalog;
CREATE POLICY sowrix_v4_catalog_read ON public.sowrix_permission_catalog FOR SELECT TO authenticated USING(true);
DROP POLICY IF EXISTS sowrix_v4_grant_read ON public.sowrix_action_grants;
CREATE POLICY sowrix_v4_grant_read ON public.sowrix_action_grants FOR SELECT TO authenticated USING(user_id=auth.uid() OR public.sowrix_access_admin());
-- Preserve the capabilities of already assigned legacy accounts on the FIRST run.
-- Subsequent runs must never restore revoked permissions.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_upgrade_markers WHERE name='granular-access-v4') THEN
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'projects',ARRAY['view']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='employee' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='projects')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'projects',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='project_manager') u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'projects',ARRAY['view']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='client') u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'tasks',ARRAY['view','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='employee' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='tasks')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'tasks',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='project_manager') u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'invoices',ARRAY['view']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='client') u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'tickets',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='tickets')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'tickets',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_staff' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='tickets')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'tickets',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_manager' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='tickets')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'tickets',ARRAY['view','create']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='employee' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='tickets')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'tickets',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='project_manager') u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'tickets',ARRAY['view','create']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='client') u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'employees',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='employees')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'employees',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_staff' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='employees')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'employees',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_manager' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='employees')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'attendance',ARRAY['view']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='attendance')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'attendance',ARRAY['view']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_staff' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='attendance')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'attendance',ARRAY['view']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_manager' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='attendance')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'attendance',ARRAY['view']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='employee' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='attendance')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'leaves',ARRAY['view','create','edit','approve']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='leaves')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'leaves',ARRAY['view','create','edit','approve']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_staff' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='leaves')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'leaves',ARRAY['view','create','edit','approve']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_manager' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='leaves')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'leaves',ARRAY['view','create']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='employee' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='leaves')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'payroll',ARRAY['view','create','edit','approve']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_manager' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='payroll')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'notifications',ARRAY['view','create','edit','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='notifications')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'notifications',ARRAY['view','create','edit','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_staff' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='notifications')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'notifications',ARRAY['view','create','edit','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_manager' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='notifications')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'notifications',ARRAY['view','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='employee' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='notifications')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'notifications',ARRAY['view','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='project_manager') u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'notifications',ARRAY['view','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='client') u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'interviews',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='interviews')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'interviews',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_staff' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='interviews')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'interviews',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_manager' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='interviews')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'departments',ARRAY['view']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='departments')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'departments',ARRAY['view']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_staff' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='departments')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'departments',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_manager' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='departments')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'jobs',ARRAY['view','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='jobs')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'jobs',ARRAY['view','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_staff' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='jobs')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'jobs',ARRAY['view','create','edit']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_manager' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='jobs')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'applications',ARRAY['view','edit','approve']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='applications')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'applications',ARRAY['view','edit','approve']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_staff' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='applications')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'applications',ARRAY['view','edit','approve']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='hr_manager' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='applications')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'task_comments',ARRAY['view','create']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='employee' AND EXISTS(SELECT 1 FROM public.sowrix_module_access a WHERE a.user_id=r.user_id AND a.module_key='task_comments')) u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT u.user_id,'task_comments',ARRAY['view','create']::text[] FROM (SELECT r.user_id FROM public.user_roles r WHERE r.role::text='project_manager') u ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT user_id,'clients','{view}' FROM public.user_roles WHERE role::text='client' ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT a.user_id,a.module_key,CASE WHEN a.module_key IN ('profile','documents','onboarding') THEN '{view,create,edit}'::text[] WHEN r.role::text IN ('hr','hr_staff','hr_manager') AND a.module_key IN ('holidays','announcements') THEN '{view,create,edit}'::text[] ELSE '{view}'::text[] END FROM public.sowrix_module_access a JOIN public.user_roles r ON r.user_id=a.user_id WHERE a.module_key='profile' ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT a.user_id,a.module_key,CASE WHEN a.module_key IN ('profile','documents','onboarding') THEN '{view,create,edit}'::text[] WHEN r.role::text IN ('hr','hr_staff','hr_manager') AND a.module_key IN ('holidays','announcements') THEN '{view,create,edit}'::text[] ELSE '{view}'::text[] END FROM public.sowrix_module_access a JOIN public.user_roles r ON r.user_id=a.user_id WHERE a.module_key='documents' ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT a.user_id,a.module_key,CASE WHEN a.module_key IN ('profile','documents','onboarding') THEN '{view,create,edit}'::text[] WHEN r.role::text IN ('hr','hr_staff','hr_manager') AND a.module_key IN ('holidays','announcements') THEN '{view,create,edit}'::text[] ELSE '{view}'::text[] END FROM public.sowrix_module_access a JOIN public.user_roles r ON r.user_id=a.user_id WHERE a.module_key='onboarding' ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT a.user_id,a.module_key,CASE WHEN a.module_key IN ('profile','documents','onboarding') THEN '{view,create,edit}'::text[] WHEN r.role::text IN ('hr','hr_staff','hr_manager') AND a.module_key IN ('holidays','announcements') THEN '{view,create,edit}'::text[] ELSE '{view}'::text[] END FROM public.sowrix_module_access a JOIN public.user_roles r ON r.user_id=a.user_id WHERE a.module_key='holidays' ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT a.user_id,a.module_key,CASE WHEN a.module_key IN ('profile','documents','onboarding') THEN '{view,create,edit}'::text[] WHEN r.role::text IN ('hr','hr_staff','hr_manager') AND a.module_key IN ('holidays','announcements') THEN '{view,create,edit}'::text[] ELSE '{view}'::text[] END FROM public.sowrix_module_access a JOIN public.user_roles r ON r.user_id=a.user_id WHERE a.module_key='announcements' ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT a.user_id,a.module_key,CASE WHEN a.module_key IN ('profile','documents','onboarding') THEN '{view,create,edit}'::text[] WHEN r.role::text IN ('hr','hr_staff','hr_manager') AND a.module_key IN ('holidays','announcements') THEN '{view,create,edit}'::text[] ELSE '{view}'::text[] END FROM public.sowrix_module_access a JOIN public.user_roles r ON r.user_id=a.user_id WHERE a.module_key='payslips' ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT a.user_id,a.module_key,CASE WHEN a.module_key IN ('profile','documents','onboarding') THEN '{view,create,edit}'::text[] WHEN r.role::text IN ('hr','hr_staff','hr_manager') AND a.module_key IN ('holidays','announcements') THEN '{view,create,edit}'::text[] ELSE '{view}'::text[] END FROM public.sowrix_module_access a JOIN public.user_roles r ON r.user_id=a.user_id WHERE a.module_key='client_quotes' ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_action_grants(user_id,module_key,actions) SELECT user_id,'client_quotes','{view,approve}' FROM public.user_roles WHERE role::text='client' ON CONFLICT DO NOTHING;
 INSERT INTO public.sowrix_upgrade_markers(name) VALUES('granular-access-v4');
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_has_permission(p_module text,p_action text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND EXISTS(SELECT 1 FROM public.sowrix_permission_catalog c WHERE c.module_key=p_module AND p_action=ANY(c.actions)) AND
 (public.sowrix_access_admin() OR (
  NOT EXISTS(SELECT 1 FROM public.sowrix_permission_catalog c WHERE c.module_key=p_module AND c.admin_only) AND
  NOT (p_module='attendance' AND p_action<>'view') AND
  NOT (p_module='employees' AND p_action='create' AND public.sowrix_access_role() NOT IN ('hr','hr_staff','hr_manager')) AND
  EXISTS(SELECT 1 FROM public.sowrix_action_grants g WHERE g.user_id=auth.uid() AND g.module_key=p_module AND 'view'=ANY(g.actions) AND p_action=ANY(g.actions))
 ))
$$;
CREATE OR REPLACE FUNCTION public.sowrix_wide_access(p_module text,p_action text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_has_permission(p_module,p_action) AND EXISTS(
  SELECT 1 FROM public.sowrix_action_grants g JOIN public.sowrix_permission_catalog c USING(module_key)
  WHERE g.user_id=auth.uid() AND g.module_key=p_module AND g.row_scope='all' AND c.allow_wide AND public.sowrix_access_role()<>'client')
$$;
CREATE OR REPLACE FUNCTION public.sowrix_has_module_access(p_module text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT public.sowrix_has_permission(p_module,'view') $$;
CREATE OR REPLACE FUNCTION public.sowrix_my_module_access()
RETURNS TABLE(module_key text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT c.module_key FROM public.sowrix_permission_catalog c WHERE public.sowrix_has_permission(c.module_key,'view') ORDER BY c.module_key
$$;
CREATE OR REPLACE FUNCTION public.sowrix_permission_snapshot()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('role',public.sowrix_access_role(),'version',4,
  'permissions',coalesce((SELECT jsonb_agg(c.module_key) FROM public.sowrix_permission_catalog c WHERE public.sowrix_has_permission(c.module_key,'view')),'[]'::jsonb),
  'actionPermissions',coalesce((SELECT jsonb_object_agg(c.module_key,(SELECT jsonb_agg(a) FROM unnest(c.actions) a WHERE public.sowrix_has_permission(c.module_key,a))) FROM public.sowrix_permission_catalog c WHERE public.sowrix_has_permission(c.module_key,'view')),'{}'::jsonb),
  'permissionScopes',coalesce((SELECT jsonb_object_agg(g.module_key,g.row_scope) FROM public.sowrix_action_grants g WHERE g.user_id=auth.uid()),'{}'::jsonb));
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_team_access_v4()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('people',coalesce((SELECT jsonb_agg(x.row ORDER BY x.email) FROM (
  SELECT u.email,jsonb_build_object('user_id',u.id,'email',u.email,'full_name',coalesce(e.full_name,u.raw_user_meta_data->>'full_name',''),
   'employee_code',coalesce(e.employee_code,''),'department',coalesce(e.department,''),'designation',coalesce(e.designation,''),
   'role',r.role::text,'revision',coalesce(v.revision,0),'grants',coalesce((SELECT jsonb_agg(jsonb_build_object('module',g.module_key,'actions',g.actions,'scope',g.row_scope)) FROM public.sowrix_action_grants g WHERE g.user_id=u.id),'[]'::jsonb)) row
  FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id LEFT JOIN public.employees e ON e.user_id=u.id LEFT JOIN public.sowrix_access_revisions v ON v.user_id=u.id
 ) x),'[]'::jsonb),'catalog',(SELECT jsonb_agg(to_jsonb(c) ORDER BY c.label) FROM public.sowrix_permission_catalog c),
 'history',coalesce((SELECT jsonb_agg(to_jsonb(z)) FROM (SELECT a.created_at,coalesce(e.full_name,u.email,'Administrator') actor,a.details FROM public.audit_logs a LEFT JOIN auth.users u ON u.id=a.actor_id LEFT JOIN public.employees e ON e.user_id=a.actor_id WHERE a.action='access_changed_v4' ORDER BY a.created_at DESC LIMIT 30) z),'[]'::jsonb));
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_save_team_access(p_user_id uuid,p_role text,p_grants jsonb,p_reason text,p_confirm_broad boolean,p_expected_revision bigint,p_department text DEFAULT NULL,p_designation text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor_role text; old_role text; v bigint; g jsonb; c public.sowrix_permission_catalog; acts text[]; scope text; broad boolean:=false; target_name text;
BEGIN
 -- Serialize role changes, then verify current database roles (not JWT claims).
 PERFORM pg_advisory_xact_lock(193740621);
 actor_role:=public.sowrix_access_role();
 IF actor_role NOT IN ('admin','super_admin') OR actor_role IS NULL THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 IF p_user_id IS NULL OR p_user_id=auth.uid() THEN RAISE EXCEPTION 'Ask another administrator to change your own access' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM auth.users WHERE id=p_user_id FOR UPDATE;
 SELECT role::text INTO old_role FROM public.user_roles WHERE user_id=p_user_id;
 IF old_role IS NULL THEN RAISE EXCEPTION 'Select an existing provisioned account'; END IF;
 IF old_role='super_admin' OR p_role='super_admin' THEN RAISE EXCEPTION 'Super Admin changes require the project owner' USING ERRCODE='42501'; END IF;
 IF (old_role='admin' OR p_role='admin') AND actor_role<>'super_admin' THEN RAISE EXCEPTION 'Only Super Admin can change Administrator access' USING ERRCODE='42501'; END IF;
 IF p_role IS NULL OR p_role NOT IN ('admin','hr_staff','hr_manager','employee','project_manager','client') THEN RAISE EXCEPTION 'Invalid account role'; END IF;
 IF length(btrim(coalesce(p_reason,'')))<8 OR length(p_reason)>1000 THEN RAISE EXCEPTION 'Enter an access-change reason (8–1000 characters)'; END IF;
 IF length(coalesce(p_department,''))>100 OR length(coalesce(p_designation,''))>200 THEN RAISE EXCEPTION 'Department or designation is too long'; END IF;
 INSERT INTO public.sowrix_access_revisions(user_id) VALUES(p_user_id) ON CONFLICT DO NOTHING;
 SELECT revision INTO v FROM public.sowrix_access_revisions WHERE user_id=p_user_id FOR UPDATE;
 IF p_expected_revision IS NULL OR p_expected_revision<>v THEN RAISE EXCEPTION 'Access changed in another session. Refresh and review before saving.' USING ERRCODE='40001'; END IF;
 IF jsonb_typeof(p_grants) IS DISTINCT FROM 'array' OR jsonb_array_length(p_grants)>50 THEN RAISE EXCEPTION 'Invalid permission list'; END IF;
 IF (SELECT count(*) FROM jsonb_array_elements(p_grants))<>(SELECT count(DISTINCT item->>'module') FROM jsonb_array_elements(p_grants) item) THEN RAISE EXCEPTION 'Duplicate or missing module'; END IF;
 FOR g IN SELECT value FROM jsonb_array_elements(p_grants) LOOP
  SELECT * INTO c FROM public.sowrix_permission_catalog WHERE module_key=g->>'module';
  IF c.module_key IS NULL OR (c.admin_only AND p_role<>'admin') THEN RAISE EXCEPTION 'Module is restricted to administrators'; END IF;
  IF jsonb_typeof(g->'actions') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid actions'; END IF;
  SELECT coalesce(array_agg(DISTINCT a),'{}') INTO acts FROM jsonb_array_elements_text(g->'actions') a;
  scope:=coalesce(g->>'scope','standard');
  IF NOT ('view'=ANY(acts)) OR NOT (acts<@c.actions) OR array_position(acts,NULL) IS NOT NULL THEN RAISE EXCEPTION 'Choose valid actions including View'; END IF;
  IF scope NOT IN ('standard','all') OR (scope='all' AND (NOT c.allow_wide OR p_role='client')) THEN RAISE EXCEPTION 'Record scope is not available for this module/account'; END IF;
  IF p_role<>'admin' AND c.module_key='attendance' AND acts<>'{view}'::text[] THEN RAISE EXCEPTION 'Attendance changes are Administrator-only'; END IF;
  IF p_role NOT IN ('admin','hr_staff','hr_manager') AND c.module_key='employees' AND 'create'=ANY(acts) THEN RAISE EXCEPTION 'Only authorized HR/Administrators can invite employees'; END IF;
  IF p_role='client' AND c.module_key NOT IN ('clients','projects','invoices','quotations','tickets','notifications','client_quotes') THEN RAISE EXCEPTION 'Choose client-facing modules only'; END IF;
  IF scope='all' THEN broad:=true; END IF;
 END LOOP;
 IF (broad OR p_role='admin') AND p_confirm_broad IS DISTINCT FROM true THEN RAISE EXCEPTION 'Confirm broader access explicitly'; END IF;
 DELETE FROM public.sowrix_action_grants WHERE user_id=p_user_id;
 DELETE FROM public.sowrix_module_access WHERE user_id=p_user_id;
 FOR g IN SELECT value FROM jsonb_array_elements(p_grants) LOOP
  SELECT array_agg(DISTINCT a) INTO acts FROM jsonb_array_elements_text(g->'actions') a;
  INSERT INTO public.sowrix_action_grants(user_id,module_key,actions,row_scope,granted_by) VALUES(p_user_id,g->>'module',acts,coalesce(g->>'scope','standard'),auth.uid());
  INSERT INTO public.sowrix_module_access(user_id,module_key,granted_by) VALUES(p_user_id,g->>'module',auth.uid());
 END LOOP;
 -- Casting preserves compatibility with an existing enum-based role column.
 EXECUTE format('UPDATE public.user_roles SET role=%L WHERE user_id=$1',p_role) USING p_user_id;
 UPDATE public.employees SET department=coalesce(p_department,department),designation=coalesce(p_designation,designation),updated_at=now() WHERE user_id=p_user_id;
 UPDATE public.sowrix_access_revisions SET revision=v+1 WHERE user_id=p_user_id;
 SELECT coalesce(e.full_name,u.email,'Team member') INTO target_name FROM auth.users u LEFT JOIN public.employees e ON e.user_id=u.id WHERE u.id=p_user_id;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details) VALUES(auth.uid(),'access_changed_v4','team_access',p_user_id::text,jsonb_build_object('target',target_name,'previous_role',old_role,'role',p_role,'reason',btrim(p_reason),'grants',p_grants,'broad_confirmed',p_confirm_broad,'revision',v+1));
 RETURN jsonb_build_object('saved',true,'revision',v+1);
END $$;
-- Old clients cannot silently replace the granular configuration.
CREATE OR REPLACE FUNCTION public.sowrix_set_module_access(p_user_id uuid,p_modules text[])
RETURNS text[] LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN RAISE EXCEPTION 'Use the updated Team Access screen to save role and action permissions'; END $$;
REVOKE INSERT,UPDATE,DELETE ON public.user_roles FROM authenticated;

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='clients' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.clients USING (('||old_q||') OR public.sowrix_wide_access(''clients'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.clients WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''clients'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.clients;
CREATE POLICY sowrix_v4_select ON public.clients AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('clients','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.clients;
CREATE POLICY sowrix_v4_wide_select ON public.clients FOR SELECT TO authenticated USING (public.sowrix_wide_access('clients','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='clients' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.clients USING (('||old_q||') OR public.sowrix_wide_access(''clients'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.clients WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''clients'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.clients;
CREATE POLICY sowrix_v4_insert ON public.clients AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('clients','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.clients;
CREATE POLICY sowrix_v4_wide_insert ON public.clients FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('clients','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='clients' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.clients USING (('||old_q||') OR public.sowrix_wide_access(''clients'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.clients WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''clients'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.clients;
CREATE POLICY sowrix_v4_update ON public.clients AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('clients','edit')) WITH CHECK (public.sowrix_has_permission('clients','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.clients;
CREATE POLICY sowrix_v4_wide_update ON public.clients FOR UPDATE TO authenticated USING (public.sowrix_wide_access('clients','edit')) WITH CHECK (public.sowrix_wide_access('clients','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='clients' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.clients USING (('||old_q||') OR public.sowrix_wide_access(''clients'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.clients WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''clients'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.clients;
CREATE POLICY sowrix_v4_delete ON public.clients AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('clients','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.clients;
CREATE POLICY sowrix_v4_wide_delete ON public.clients FOR DELETE TO authenticated USING (public.sowrix_wide_access('clients','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='projects' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.projects USING (('||old_q||') OR public.sowrix_wide_access(''projects'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.projects WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''projects'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.projects;
CREATE POLICY sowrix_v4_select ON public.projects AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('projects','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.projects;
CREATE POLICY sowrix_v4_wide_select ON public.projects FOR SELECT TO authenticated USING (public.sowrix_wide_access('projects','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='projects' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.projects USING (('||old_q||') OR public.sowrix_wide_access(''projects'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.projects WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''projects'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.projects;
CREATE POLICY sowrix_v4_insert ON public.projects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('projects','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.projects;
CREATE POLICY sowrix_v4_wide_insert ON public.projects FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('projects','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='projects' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.projects USING (('||old_q||') OR public.sowrix_wide_access(''projects'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.projects WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''projects'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.projects;
CREATE POLICY sowrix_v4_update ON public.projects AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('projects','edit')) WITH CHECK (public.sowrix_has_permission('projects','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.projects;
CREATE POLICY sowrix_v4_wide_update ON public.projects FOR UPDATE TO authenticated USING (public.sowrix_wide_access('projects','edit')) WITH CHECK (public.sowrix_wide_access('projects','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='projects' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.projects USING (('||old_q||') OR public.sowrix_wide_access(''projects'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.projects WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''projects'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.projects;
CREATE POLICY sowrix_v4_delete ON public.projects AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('projects','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.projects;
CREATE POLICY sowrix_v4_wide_delete ON public.projects FOR DELETE TO authenticated USING (public.sowrix_wide_access('projects','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='tasks' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.tasks USING (('||old_q||') OR public.sowrix_wide_access(''tasks'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.tasks WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''tasks'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.tasks;
CREATE POLICY sowrix_v4_select ON public.tasks AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('tasks','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.tasks;
CREATE POLICY sowrix_v4_wide_select ON public.tasks FOR SELECT TO authenticated USING (public.sowrix_wide_access('tasks','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='tasks' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.tasks USING (('||old_q||') OR public.sowrix_wide_access(''tasks'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.tasks WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''tasks'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.tasks;
CREATE POLICY sowrix_v4_insert ON public.tasks AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('tasks','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.tasks;
CREATE POLICY sowrix_v4_wide_insert ON public.tasks FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('tasks','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='tasks' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.tasks USING (('||old_q||') OR public.sowrix_wide_access(''tasks'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.tasks WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''tasks'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.tasks;
CREATE POLICY sowrix_v4_update ON public.tasks AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('tasks','edit')) WITH CHECK (public.sowrix_has_permission('tasks','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.tasks;
CREATE POLICY sowrix_v4_wide_update ON public.tasks FOR UPDATE TO authenticated USING (public.sowrix_wide_access('tasks','edit')) WITH CHECK (public.sowrix_wide_access('tasks','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='tasks' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.tasks USING (('||old_q||') OR public.sowrix_wide_access(''tasks'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.tasks WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''tasks'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.tasks;
CREATE POLICY sowrix_v4_delete ON public.tasks AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('tasks','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.tasks;
CREATE POLICY sowrix_v4_wide_delete ON public.tasks FOR DELETE TO authenticated USING (public.sowrix_wide_access('tasks','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='invoices' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.invoices USING (('||old_q||') OR public.sowrix_wide_access(''invoices'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.invoices WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''invoices'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.invoices;
CREATE POLICY sowrix_v4_select ON public.invoices AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('invoices','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.invoices;
CREATE POLICY sowrix_v4_wide_select ON public.invoices FOR SELECT TO authenticated USING (public.sowrix_wide_access('invoices','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='invoices' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.invoices USING (('||old_q||') OR public.sowrix_wide_access(''invoices'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.invoices WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''invoices'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.invoices;
CREATE POLICY sowrix_v4_insert ON public.invoices AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('invoices','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.invoices;
CREATE POLICY sowrix_v4_wide_insert ON public.invoices FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('invoices','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='invoices' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.invoices USING (('||old_q||') OR (public.sowrix_wide_access(''invoices'',''edit'') OR public.sowrix_wide_access(''invoices'',''approve'')))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.invoices WITH CHECK (('||old_c||') OR (public.sowrix_wide_access(''invoices'',''edit'') OR public.sowrix_wide_access(''invoices'',''approve'')))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.invoices;
CREATE POLICY sowrix_v4_update ON public.invoices AS RESTRICTIVE FOR UPDATE TO authenticated USING ((public.sowrix_has_permission('invoices','edit') OR public.sowrix_has_permission('invoices','approve'))) WITH CHECK ((public.sowrix_has_permission('invoices','edit') OR public.sowrix_has_permission('invoices','approve')));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.invoices;
CREATE POLICY sowrix_v4_wide_update ON public.invoices FOR UPDATE TO authenticated USING ((public.sowrix_wide_access('invoices','edit') OR public.sowrix_wide_access('invoices','approve'))) WITH CHECK ((public.sowrix_wide_access('invoices','edit') OR public.sowrix_wide_access('invoices','approve')));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='invoices' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.invoices USING (('||old_q||') OR public.sowrix_wide_access(''invoices'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.invoices WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''invoices'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.invoices;
CREATE POLICY sowrix_v4_delete ON public.invoices AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('invoices','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.invoices;
CREATE POLICY sowrix_v4_wide_delete ON public.invoices FOR DELETE TO authenticated USING (public.sowrix_wide_access('invoices','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='expenses' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.expenses USING (('||old_q||') OR public.sowrix_wide_access(''expenses'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.expenses WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''expenses'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.expenses;
CREATE POLICY sowrix_v4_select ON public.expenses AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('expenses','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.expenses;
CREATE POLICY sowrix_v4_wide_select ON public.expenses FOR SELECT TO authenticated USING (public.sowrix_wide_access('expenses','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='expenses' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.expenses USING (('||old_q||') OR public.sowrix_wide_access(''expenses'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.expenses WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''expenses'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.expenses;
CREATE POLICY sowrix_v4_insert ON public.expenses AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('expenses','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.expenses;
CREATE POLICY sowrix_v4_wide_insert ON public.expenses FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('expenses','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='expenses' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.expenses USING (('||old_q||') OR (public.sowrix_wide_access(''expenses'',''edit'') OR public.sowrix_wide_access(''expenses'',''approve'')))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.expenses WITH CHECK (('||old_c||') OR (public.sowrix_wide_access(''expenses'',''edit'') OR public.sowrix_wide_access(''expenses'',''approve'')))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.expenses;
CREATE POLICY sowrix_v4_update ON public.expenses AS RESTRICTIVE FOR UPDATE TO authenticated USING ((public.sowrix_has_permission('expenses','edit') OR public.sowrix_has_permission('expenses','approve'))) WITH CHECK ((public.sowrix_has_permission('expenses','edit') OR public.sowrix_has_permission('expenses','approve')));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.expenses;
CREATE POLICY sowrix_v4_wide_update ON public.expenses FOR UPDATE TO authenticated USING ((public.sowrix_wide_access('expenses','edit') OR public.sowrix_wide_access('expenses','approve'))) WITH CHECK ((public.sowrix_wide_access('expenses','edit') OR public.sowrix_wide_access('expenses','approve')));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='expenses' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.expenses USING (('||old_q||') OR public.sowrix_wide_access(''expenses'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.expenses WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''expenses'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.expenses;
CREATE POLICY sowrix_v4_delete ON public.expenses AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('expenses','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.expenses;
CREATE POLICY sowrix_v4_wide_delete ON public.expenses FOR DELETE TO authenticated USING (public.sowrix_wide_access('expenses','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='quotations' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.quotations USING (('||old_q||') OR public.sowrix_wide_access(''quotations'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.quotations WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''quotations'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.quotations;
CREATE POLICY sowrix_v4_select ON public.quotations AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('quotations','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.quotations;
CREATE POLICY sowrix_v4_wide_select ON public.quotations FOR SELECT TO authenticated USING (public.sowrix_wide_access('quotations','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='quotations' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.quotations USING (('||old_q||') OR public.sowrix_wide_access(''quotations'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.quotations WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''quotations'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.quotations;
CREATE POLICY sowrix_v4_insert ON public.quotations AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('quotations','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.quotations;
CREATE POLICY sowrix_v4_wide_insert ON public.quotations FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('quotations','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='quotations' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.quotations USING (('||old_q||') OR (public.sowrix_wide_access(''quotations'',''edit'') OR public.sowrix_wide_access(''quotations'',''approve'')))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.quotations WITH CHECK (('||old_c||') OR (public.sowrix_wide_access(''quotations'',''edit'') OR public.sowrix_wide_access(''quotations'',''approve'')))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.quotations;
CREATE POLICY sowrix_v4_update ON public.quotations AS RESTRICTIVE FOR UPDATE TO authenticated USING ((public.sowrix_has_permission('quotations','edit') OR public.sowrix_has_permission('quotations','approve'))) WITH CHECK ((public.sowrix_has_permission('quotations','edit') OR public.sowrix_has_permission('quotations','approve')));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.quotations;
CREATE POLICY sowrix_v4_wide_update ON public.quotations FOR UPDATE TO authenticated USING ((public.sowrix_wide_access('quotations','edit') OR public.sowrix_wide_access('quotations','approve'))) WITH CHECK ((public.sowrix_wide_access('quotations','edit') OR public.sowrix_wide_access('quotations','approve')));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='quotations' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.quotations USING (('||old_q||') OR public.sowrix_wide_access(''quotations'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.quotations WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''quotations'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.quotations;
CREATE POLICY sowrix_v4_delete ON public.quotations AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('quotations','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.quotations;
CREATE POLICY sowrix_v4_wide_delete ON public.quotations FOR DELETE TO authenticated USING (public.sowrix_wide_access('quotations','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='support_tickets' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.support_tickets USING (('||old_q||') OR public.sowrix_wide_access(''tickets'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.support_tickets WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''tickets'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.support_tickets;
CREATE POLICY sowrix_v4_select ON public.support_tickets AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('tickets','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.support_tickets;
CREATE POLICY sowrix_v4_wide_select ON public.support_tickets FOR SELECT TO authenticated USING (public.sowrix_wide_access('tickets','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='support_tickets' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.support_tickets USING (('||old_q||') OR public.sowrix_wide_access(''tickets'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.support_tickets WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''tickets'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.support_tickets;
CREATE POLICY sowrix_v4_insert ON public.support_tickets AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('tickets','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.support_tickets;
CREATE POLICY sowrix_v4_wide_insert ON public.support_tickets FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('tickets','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='support_tickets' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.support_tickets USING (('||old_q||') OR public.sowrix_wide_access(''tickets'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.support_tickets WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''tickets'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.support_tickets;
CREATE POLICY sowrix_v4_update ON public.support_tickets AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('tickets','edit')) WITH CHECK (public.sowrix_has_permission('tickets','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.support_tickets;
CREATE POLICY sowrix_v4_wide_update ON public.support_tickets FOR UPDATE TO authenticated USING (public.sowrix_wide_access('tickets','edit')) WITH CHECK (public.sowrix_wide_access('tickets','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='support_tickets' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.support_tickets USING (('||old_q||') OR public.sowrix_wide_access(''tickets'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.support_tickets WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''tickets'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.support_tickets;
CREATE POLICY sowrix_v4_delete ON public.support_tickets AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('tickets','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.support_tickets;
CREATE POLICY sowrix_v4_wide_delete ON public.support_tickets FOR DELETE TO authenticated USING (public.sowrix_wide_access('tickets','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='employees' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.employees USING (('||old_q||') OR public.sowrix_wide_access(''employees'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.employees WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''employees'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.employees;
CREATE POLICY sowrix_v4_select ON public.employees AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('employees','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.employees;
CREATE POLICY sowrix_v4_wide_select ON public.employees FOR SELECT TO authenticated USING (public.sowrix_wide_access('employees','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='employees' AND policyname='sowrix_v3_insert_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.employees USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.employees WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.employees;
CREATE POLICY sowrix_v4_insert ON public.employees AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('employees','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='employees' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.employees USING (('||old_q||') OR public.sowrix_wide_access(''employees'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.employees WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''employees'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.employees;
CREATE POLICY sowrix_v4_update ON public.employees AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('employees','edit')) WITH CHECK (public.sowrix_has_permission('employees','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.employees;
CREATE POLICY sowrix_v4_wide_update ON public.employees FOR UPDATE TO authenticated USING (public.sowrix_wide_access('employees','edit')) WITH CHECK (public.sowrix_wide_access('employees','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='employees' AND policyname='sowrix_v3_delete_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.employees USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.employees WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.employees;
CREATE POLICY sowrix_v4_delete ON public.employees AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('employees','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='attendance_records' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.attendance_records USING (('||old_q||') OR public.sowrix_wide_access(''attendance'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.attendance_records WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''attendance'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.attendance_records;
CREATE POLICY sowrix_v4_select ON public.attendance_records AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('attendance','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.attendance_records;
CREATE POLICY sowrix_v4_wide_select ON public.attendance_records FOR SELECT TO authenticated USING (public.sowrix_wide_access('attendance','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='attendance_records' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.attendance_records USING (('||old_q||') OR public.sowrix_wide_access(''attendance'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.attendance_records WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''attendance'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.attendance_records;
CREATE POLICY sowrix_v4_insert ON public.attendance_records AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('attendance','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.attendance_records;
CREATE POLICY sowrix_v4_wide_insert ON public.attendance_records FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('attendance','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='attendance_records' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.attendance_records USING (('||old_q||') OR public.sowrix_wide_access(''attendance'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.attendance_records WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''attendance'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.attendance_records;
CREATE POLICY sowrix_v4_update ON public.attendance_records AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('attendance','edit')) WITH CHECK (public.sowrix_has_permission('attendance','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.attendance_records;
CREATE POLICY sowrix_v4_wide_update ON public.attendance_records FOR UPDATE TO authenticated USING (public.sowrix_wide_access('attendance','edit')) WITH CHECK (public.sowrix_wide_access('attendance','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='attendance_records' AND policyname='sowrix_v3_delete_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.attendance_records USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.attendance_records WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.attendance_records;
CREATE POLICY sowrix_v4_delete ON public.attendance_records AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('attendance','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='leave_requests' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.leave_requests USING (('||old_q||') OR public.sowrix_wide_access(''leaves'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.leave_requests WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''leaves'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.leave_requests;
CREATE POLICY sowrix_v4_select ON public.leave_requests AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('leaves','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.leave_requests;
CREATE POLICY sowrix_v4_wide_select ON public.leave_requests FOR SELECT TO authenticated USING (public.sowrix_wide_access('leaves','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='leave_requests' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.leave_requests USING (('||old_q||') OR public.sowrix_wide_access(''leaves'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.leave_requests WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''leaves'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.leave_requests;
CREATE POLICY sowrix_v4_insert ON public.leave_requests AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('leaves','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.leave_requests;
CREATE POLICY sowrix_v4_wide_insert ON public.leave_requests FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('leaves','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='leave_requests' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.leave_requests USING (('||old_q||') OR (public.sowrix_wide_access(''leaves'',''edit'') OR public.sowrix_wide_access(''leaves'',''approve'')))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.leave_requests WITH CHECK (('||old_c||') OR (public.sowrix_wide_access(''leaves'',''edit'') OR public.sowrix_wide_access(''leaves'',''approve'')))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.leave_requests;
CREATE POLICY sowrix_v4_update ON public.leave_requests AS RESTRICTIVE FOR UPDATE TO authenticated USING ((public.sowrix_has_permission('leaves','edit') OR public.sowrix_has_permission('leaves','approve'))) WITH CHECK ((public.sowrix_has_permission('leaves','edit') OR public.sowrix_has_permission('leaves','approve')));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.leave_requests;
CREATE POLICY sowrix_v4_wide_update ON public.leave_requests FOR UPDATE TO authenticated USING ((public.sowrix_wide_access('leaves','edit') OR public.sowrix_wide_access('leaves','approve'))) WITH CHECK ((public.sowrix_wide_access('leaves','edit') OR public.sowrix_wide_access('leaves','approve')));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='leave_requests' AND policyname='sowrix_v3_delete_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.leave_requests USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.leave_requests WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.leave_requests;
CREATE POLICY sowrix_v4_delete ON public.leave_requests AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('leaves','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='payroll_records' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.payroll_records USING (('||old_q||') OR public.sowrix_wide_access(''payroll'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.payroll_records WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''payroll'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.payroll_records;
CREATE POLICY sowrix_v4_select ON public.payroll_records AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('payroll','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.payroll_records;
CREATE POLICY sowrix_v4_wide_select ON public.payroll_records FOR SELECT TO authenticated USING (public.sowrix_wide_access('payroll','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='payroll_records' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.payroll_records USING (('||old_q||') OR public.sowrix_wide_access(''payroll'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.payroll_records WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''payroll'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.payroll_records;
CREATE POLICY sowrix_v4_insert ON public.payroll_records AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('payroll','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.payroll_records;
CREATE POLICY sowrix_v4_wide_insert ON public.payroll_records FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('payroll','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='payroll_records' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.payroll_records USING (('||old_q||') OR (public.sowrix_wide_access(''payroll'',''edit'') OR public.sowrix_wide_access(''payroll'',''approve'')))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.payroll_records WITH CHECK (('||old_c||') OR (public.sowrix_wide_access(''payroll'',''edit'') OR public.sowrix_wide_access(''payroll'',''approve'')))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.payroll_records;
CREATE POLICY sowrix_v4_update ON public.payroll_records AS RESTRICTIVE FOR UPDATE TO authenticated USING ((public.sowrix_has_permission('payroll','edit') OR public.sowrix_has_permission('payroll','approve'))) WITH CHECK ((public.sowrix_has_permission('payroll','edit') OR public.sowrix_has_permission('payroll','approve')));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.payroll_records;
CREATE POLICY sowrix_v4_wide_update ON public.payroll_records FOR UPDATE TO authenticated USING ((public.sowrix_wide_access('payroll','edit') OR public.sowrix_wide_access('payroll','approve'))) WITH CHECK ((public.sowrix_wide_access('payroll','edit') OR public.sowrix_wide_access('payroll','approve')));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='payroll_records' AND policyname='sowrix_v3_delete_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.payroll_records USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.payroll_records WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.payroll_records;
CREATE POLICY sowrix_v4_delete ON public.payroll_records AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('payroll','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='notifications' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.notifications USING (('||old_q||') OR public.sowrix_wide_access(''notifications'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.notifications WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''notifications'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.notifications;
CREATE POLICY sowrix_v4_select ON public.notifications AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('notifications','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.notifications;
CREATE POLICY sowrix_v4_wide_select ON public.notifications FOR SELECT TO authenticated USING (public.sowrix_wide_access('notifications','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='notifications' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.notifications USING (('||old_q||') OR public.sowrix_wide_access(''notifications'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.notifications WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''notifications'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.notifications;
CREATE POLICY sowrix_v4_insert ON public.notifications AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('notifications','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.notifications;
CREATE POLICY sowrix_v4_wide_insert ON public.notifications FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('notifications','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='notifications' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.notifications USING (('||old_q||') OR public.sowrix_wide_access(''notifications'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.notifications WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''notifications'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.notifications;
CREATE POLICY sowrix_v4_update ON public.notifications AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('notifications','edit')) WITH CHECK (public.sowrix_has_permission('notifications','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.notifications;
CREATE POLICY sowrix_v4_wide_update ON public.notifications FOR UPDATE TO authenticated USING (public.sowrix_wide_access('notifications','edit')) WITH CHECK (public.sowrix_wide_access('notifications','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='notifications' AND policyname='sowrix_v3_delete_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.notifications USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.notifications WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.notifications;
CREATE POLICY sowrix_v4_delete ON public.notifications AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('notifications','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='audit_logs' AND policyname='sowrix_v3_select_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.audit_logs USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.audit_logs WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.audit_logs;
CREATE POLICY sowrix_v4_select ON public.audit_logs AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('audit','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='audit_logs' AND policyname='sowrix_v3_insert_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.audit_logs USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.audit_logs WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.audit_logs;
CREATE POLICY sowrix_v4_insert ON public.audit_logs AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('audit','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='audit_logs' AND policyname='sowrix_v3_update_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.audit_logs USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.audit_logs WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.audit_logs;
CREATE POLICY sowrix_v4_update ON public.audit_logs AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('audit','edit')) WITH CHECK (public.sowrix_has_permission('audit','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='audit_logs' AND policyname='sowrix_v3_delete_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.audit_logs USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.audit_logs WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.audit_logs;
CREATE POLICY sowrix_v4_delete ON public.audit_logs AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('audit','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='interviews' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.interviews USING (('||old_q||') OR public.sowrix_wide_access(''interviews'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.interviews WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''interviews'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.interviews;
CREATE POLICY sowrix_v4_select ON public.interviews AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('interviews','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.interviews;
CREATE POLICY sowrix_v4_wide_select ON public.interviews FOR SELECT TO authenticated USING (public.sowrix_wide_access('interviews','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='interviews' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.interviews USING (('||old_q||') OR public.sowrix_wide_access(''interviews'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.interviews WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''interviews'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.interviews;
CREATE POLICY sowrix_v4_insert ON public.interviews AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('interviews','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.interviews;
CREATE POLICY sowrix_v4_wide_insert ON public.interviews FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('interviews','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='interviews' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.interviews USING (('||old_q||') OR public.sowrix_wide_access(''interviews'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.interviews WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''interviews'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.interviews;
CREATE POLICY sowrix_v4_update ON public.interviews AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('interviews','edit')) WITH CHECK (public.sowrix_has_permission('interviews','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.interviews;
CREATE POLICY sowrix_v4_wide_update ON public.interviews FOR UPDATE TO authenticated USING (public.sowrix_wide_access('interviews','edit')) WITH CHECK (public.sowrix_wide_access('interviews','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='interviews' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.interviews USING (('||old_q||') OR public.sowrix_wide_access(''interviews'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.interviews WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''interviews'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.interviews;
CREATE POLICY sowrix_v4_delete ON public.interviews AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('interviews','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.interviews;
CREATE POLICY sowrix_v4_wide_delete ON public.interviews FOR DELETE TO authenticated USING (public.sowrix_wide_access('interviews','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='departments' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.departments USING (('||old_q||') OR public.sowrix_wide_access(''departments'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.departments WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''departments'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.departments;
CREATE POLICY sowrix_v4_select ON public.departments AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('departments','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.departments;
CREATE POLICY sowrix_v4_wide_select ON public.departments FOR SELECT TO authenticated USING (public.sowrix_wide_access('departments','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='departments' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.departments USING (('||old_q||') OR public.sowrix_wide_access(''departments'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.departments WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''departments'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.departments;
CREATE POLICY sowrix_v4_insert ON public.departments AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('departments','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.departments;
CREATE POLICY sowrix_v4_wide_insert ON public.departments FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('departments','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='departments' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.departments USING (('||old_q||') OR public.sowrix_wide_access(''departments'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.departments WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''departments'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.departments;
CREATE POLICY sowrix_v4_update ON public.departments AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('departments','edit')) WITH CHECK (public.sowrix_has_permission('departments','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.departments;
CREATE POLICY sowrix_v4_wide_update ON public.departments FOR UPDATE TO authenticated USING (public.sowrix_wide_access('departments','edit')) WITH CHECK (public.sowrix_wide_access('departments','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='departments' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.departments USING (('||old_q||') OR public.sowrix_wide_access(''departments'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.departments WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''departments'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.departments;
CREATE POLICY sowrix_v4_delete ON public.departments AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('departments','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.departments;
CREATE POLICY sowrix_v4_wide_delete ON public.departments FOR DELETE TO authenticated USING (public.sowrix_wide_access('departments','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='jobs' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.jobs USING (('||old_q||') OR public.sowrix_wide_access(''jobs'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.jobs WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''jobs'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.jobs;
CREATE POLICY sowrix_v4_select ON public.jobs AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_has_permission('jobs','view') OR status::text='published'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.jobs;
CREATE POLICY sowrix_v4_wide_select ON public.jobs FOR SELECT TO authenticated USING (public.sowrix_wide_access('jobs','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='jobs' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.jobs USING (('||old_q||') OR public.sowrix_wide_access(''jobs'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.jobs WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''jobs'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.jobs;
CREATE POLICY sowrix_v4_insert ON public.jobs AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('jobs','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.jobs;
CREATE POLICY sowrix_v4_wide_insert ON public.jobs FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('jobs','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='jobs' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.jobs USING (('||old_q||') OR public.sowrix_wide_access(''jobs'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.jobs WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''jobs'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.jobs;
CREATE POLICY sowrix_v4_update ON public.jobs AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('jobs','edit')) WITH CHECK (public.sowrix_has_permission('jobs','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.jobs;
CREATE POLICY sowrix_v4_wide_update ON public.jobs FOR UPDATE TO authenticated USING (public.sowrix_wide_access('jobs','edit')) WITH CHECK (public.sowrix_wide_access('jobs','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='jobs' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.jobs USING (('||old_q||') OR public.sowrix_wide_access(''jobs'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.jobs WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''jobs'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.jobs;
CREATE POLICY sowrix_v4_delete ON public.jobs AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('jobs','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.jobs;
CREATE POLICY sowrix_v4_wide_delete ON public.jobs FOR DELETE TO authenticated USING (public.sowrix_wide_access('jobs','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='job_applications' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.job_applications USING (('||old_q||') OR public.sowrix_wide_access(''applications'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.job_applications WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''applications'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.job_applications;
CREATE POLICY sowrix_v4_select ON public.job_applications AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('applications','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.job_applications;
CREATE POLICY sowrix_v4_wide_select ON public.job_applications FOR SELECT TO authenticated USING (public.sowrix_wide_access('applications','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='job_applications' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.job_applications USING (('||old_q||') OR public.sowrix_wide_access(''applications'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.job_applications WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''applications'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.job_applications;
CREATE POLICY sowrix_v4_insert ON public.job_applications AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK ((status='applied' AND reviewer_id IS NULL));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.job_applications;
CREATE POLICY sowrix_v4_wide_insert ON public.job_applications FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('applications','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='job_applications' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.job_applications USING (('||old_q||') OR (public.sowrix_wide_access(''applications'',''edit'') OR public.sowrix_wide_access(''applications'',''approve'')))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.job_applications WITH CHECK (('||old_c||') OR (public.sowrix_wide_access(''applications'',''edit'') OR public.sowrix_wide_access(''applications'',''approve'')))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.job_applications;
CREATE POLICY sowrix_v4_update ON public.job_applications AS RESTRICTIVE FOR UPDATE TO authenticated USING ((public.sowrix_has_permission('applications','edit') OR public.sowrix_has_permission('applications','approve'))) WITH CHECK ((public.sowrix_has_permission('applications','edit') OR public.sowrix_has_permission('applications','approve')));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.job_applications;
CREATE POLICY sowrix_v4_wide_update ON public.job_applications FOR UPDATE TO authenticated USING ((public.sowrix_wide_access('applications','edit') OR public.sowrix_wide_access('applications','approve'))) WITH CHECK ((public.sowrix_wide_access('applications','edit') OR public.sowrix_wide_access('applications','approve')));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='job_applications' AND policyname='sowrix_v3_delete_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.job_applications USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.job_applications WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.job_applications;
CREATE POLICY sowrix_v4_delete ON public.job_applications AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('applications','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='services' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.services USING (('||old_q||') OR public.sowrix_wide_access(''services'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.services WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''services'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.services;
CREATE POLICY sowrix_v4_select ON public.services AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_has_permission('services','view') OR status::text='published'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.services;
CREATE POLICY sowrix_v4_wide_select ON public.services FOR SELECT TO authenticated USING (public.sowrix_wide_access('services','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='services' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.services USING (('||old_q||') OR public.sowrix_wide_access(''services'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.services WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''services'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.services;
CREATE POLICY sowrix_v4_insert ON public.services AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('services','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.services;
CREATE POLICY sowrix_v4_wide_insert ON public.services FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('services','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='services' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.services USING (('||old_q||') OR public.sowrix_wide_access(''services'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.services WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''services'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.services;
CREATE POLICY sowrix_v4_update ON public.services AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('services','edit')) WITH CHECK (public.sowrix_has_permission('services','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.services;
CREATE POLICY sowrix_v4_wide_update ON public.services FOR UPDATE TO authenticated USING (public.sowrix_wide_access('services','edit')) WITH CHECK (public.sowrix_wide_access('services','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='services' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.services USING (('||old_q||') OR public.sowrix_wide_access(''services'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.services WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''services'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.services;
CREATE POLICY sowrix_v4_delete ON public.services AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('services','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.services;
CREATE POLICY sowrix_v4_wide_delete ON public.services FOR DELETE TO authenticated USING (public.sowrix_wide_access('services','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='portfolio_projects' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.portfolio_projects USING (('||old_q||') OR public.sowrix_wide_access(''portfolio'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.portfolio_projects WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''portfolio'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.portfolio_projects;
CREATE POLICY sowrix_v4_select ON public.portfolio_projects AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_has_permission('portfolio','view') OR status::text='published'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.portfolio_projects;
CREATE POLICY sowrix_v4_wide_select ON public.portfolio_projects FOR SELECT TO authenticated USING (public.sowrix_wide_access('portfolio','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='portfolio_projects' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.portfolio_projects USING (('||old_q||') OR public.sowrix_wide_access(''portfolio'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.portfolio_projects WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''portfolio'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.portfolio_projects;
CREATE POLICY sowrix_v4_insert ON public.portfolio_projects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('portfolio','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.portfolio_projects;
CREATE POLICY sowrix_v4_wide_insert ON public.portfolio_projects FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('portfolio','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='portfolio_projects' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.portfolio_projects USING (('||old_q||') OR public.sowrix_wide_access(''portfolio'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.portfolio_projects WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''portfolio'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.portfolio_projects;
CREATE POLICY sowrix_v4_update ON public.portfolio_projects AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('portfolio','edit')) WITH CHECK (public.sowrix_has_permission('portfolio','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.portfolio_projects;
CREATE POLICY sowrix_v4_wide_update ON public.portfolio_projects FOR UPDATE TO authenticated USING (public.sowrix_wide_access('portfolio','edit')) WITH CHECK (public.sowrix_wide_access('portfolio','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='portfolio_projects' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.portfolio_projects USING (('||old_q||') OR public.sowrix_wide_access(''portfolio'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.portfolio_projects WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''portfolio'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.portfolio_projects;
CREATE POLICY sowrix_v4_delete ON public.portfolio_projects AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('portfolio','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.portfolio_projects;
CREATE POLICY sowrix_v4_wide_delete ON public.portfolio_projects FOR DELETE TO authenticated USING (public.sowrix_wide_access('portfolio','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='blog_posts' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.blog_posts USING (('||old_q||') OR public.sowrix_wide_access(''blog'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.blog_posts WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''blog'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.blog_posts;
CREATE POLICY sowrix_v4_select ON public.blog_posts AS RESTRICTIVE FOR SELECT TO authenticated USING ((public.sowrix_has_permission('blog','view') OR status::text='published'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.blog_posts;
CREATE POLICY sowrix_v4_wide_select ON public.blog_posts FOR SELECT TO authenticated USING (public.sowrix_wide_access('blog','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='blog_posts' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.blog_posts USING (('||old_q||') OR public.sowrix_wide_access(''blog'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.blog_posts WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''blog'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.blog_posts;
CREATE POLICY sowrix_v4_insert ON public.blog_posts AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('blog','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.blog_posts;
CREATE POLICY sowrix_v4_wide_insert ON public.blog_posts FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('blog','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='blog_posts' AND policyname='sowrix_v3_update_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.blog_posts USING (('||old_q||') OR public.sowrix_wide_access(''blog'',''edit''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.blog_posts WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''blog'',''edit''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.blog_posts;
CREATE POLICY sowrix_v4_update ON public.blog_posts AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('blog','edit')) WITH CHECK (public.sowrix_has_permission('blog','edit'));
DROP POLICY IF EXISTS sowrix_v4_wide_update ON public.blog_posts;
CREATE POLICY sowrix_v4_wide_update ON public.blog_posts FOR UPDATE TO authenticated USING (public.sowrix_wide_access('blog','edit')) WITH CHECK (public.sowrix_wide_access('blog','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='blog_posts' AND policyname='sowrix_v3_delete_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.blog_posts USING (('||old_q||') OR public.sowrix_wide_access(''blog'',''delete''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.blog_posts WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''blog'',''delete''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.blog_posts;
CREATE POLICY sowrix_v4_delete ON public.blog_posts AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('blog','delete'));
DROP POLICY IF EXISTS sowrix_v4_wide_delete ON public.blog_posts;
CREATE POLICY sowrix_v4_wide_delete ON public.blog_posts FOR DELETE TO authenticated USING (public.sowrix_wide_access('blog','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='contact_enquiries' AND policyname='sowrix_v3_select_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.contact_enquiries USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.contact_enquiries WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.contact_enquiries;
CREATE POLICY sowrix_v4_select ON public.contact_enquiries AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('enquiries','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='contact_enquiries' AND policyname='sowrix_v3_insert_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.contact_enquiries USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.contact_enquiries WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.contact_enquiries;
CREATE POLICY sowrix_v4_insert ON public.contact_enquiries AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('enquiries','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='contact_enquiries' AND policyname='sowrix_v3_update_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.contact_enquiries USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.contact_enquiries WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.contact_enquiries;
CREATE POLICY sowrix_v4_update ON public.contact_enquiries AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('enquiries','edit')) WITH CHECK (public.sowrix_has_permission('enquiries','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='contact_enquiries' AND policyname='sowrix_v3_delete_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.contact_enquiries USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.contact_enquiries WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.contact_enquiries;
CREATE POLICY sowrix_v4_delete ON public.contact_enquiries AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('enquiries','delete'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='task_comments' AND policyname='sowrix_v3_select_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.task_comments USING (('||old_q||') OR public.sowrix_wide_access(''task_comments'',''view''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_select_scope ON public.task_comments WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''task_comments'',''view''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_select ON public.task_comments;
CREATE POLICY sowrix_v4_select ON public.task_comments AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_has_permission('task_comments','view'));
DROP POLICY IF EXISTS sowrix_v4_wide_select ON public.task_comments;
CREATE POLICY sowrix_v4_wide_select ON public.task_comments FOR SELECT TO authenticated USING (public.sowrix_wide_access('task_comments','view'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='task_comments' AND policyname='sowrix_v3_insert_scope';
 IF true AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.task_comments USING (('||old_q||') OR public.sowrix_wide_access(''task_comments'',''create''))'; END IF;
 IF true AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_insert_scope ON public.task_comments WITH CHECK (('||old_c||') OR public.sowrix_wide_access(''task_comments'',''create''))'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_insert ON public.task_comments;
CREATE POLICY sowrix_v4_insert ON public.task_comments AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.sowrix_has_permission('task_comments','create'));
DROP POLICY IF EXISTS sowrix_v4_wide_insert ON public.task_comments;
CREATE POLICY sowrix_v4_wide_insert ON public.task_comments FOR INSERT TO authenticated WITH CHECK (public.sowrix_wide_access('task_comments','create'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='task_comments' AND policyname='sowrix_v3_update_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.task_comments USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_update_scope ON public.task_comments WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_update ON public.task_comments;
CREATE POLICY sowrix_v4_update ON public.task_comments AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.sowrix_has_permission('task_comments','edit')) WITH CHECK (public.sowrix_has_permission('task_comments','edit'));

DO $policy$ DECLARE old_q text; old_c text; BEGIN
 SELECT qual,with_check INTO old_q,old_c FROM pg_policies WHERE schemaname='public' AND tablename='task_comments' AND policyname='sowrix_v3_delete_scope';
 IF false AND old_q IS NOT NULL AND position('sowrix_wide_access' in old_q)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.task_comments USING (('||old_q||') OR false)'; END IF;
 IF false AND old_c IS NOT NULL AND position('sowrix_wide_access' in old_c)=0 THEN EXECUTE 'ALTER POLICY sowrix_v3_delete_scope ON public.task_comments WITH CHECK (('||old_c||') OR false)'; END IF;
END $policy$;
DROP POLICY IF EXISTS sowrix_v4_delete ON public.task_comments;
CREATE POLICY sowrix_v4_delete ON public.task_comments AS RESTRICTIVE FOR DELETE TO authenticated USING (public.sowrix_has_permission('task_comments','delete'));

DROP POLICY IF EXISTS sowrix_v4_ui_insert ON public.sowrix_ui_records;
CREATE POLICY sowrix_v4_ui_insert ON public.sowrix_ui_records AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(public.sowrix_has_permission(public.sowrix_ui_module(kind),'create') OR (kind='quote_response' AND owner_id=auth.uid() AND public.sowrix_has_permission('client_quotes','approve')));
DROP POLICY IF EXISTS sowrix_v4_ui_update ON public.sowrix_ui_records;
CREATE POLICY sowrix_v4_ui_update ON public.sowrix_ui_records AS RESTRICTIVE FOR UPDATE TO authenticated USING(public.sowrix_has_permission(public.sowrix_ui_module(kind),'edit') OR public.sowrix_has_permission(public.sowrix_ui_module(kind),'approve')) WITH CHECK(public.sowrix_has_permission(public.sowrix_ui_module(kind),'edit') OR public.sowrix_has_permission(public.sowrix_ui_module(kind),'approve'));
DROP POLICY IF EXISTS sowrix_v4_ui_delete ON public.sowrix_ui_records;
CREATE POLICY sowrix_v4_ui_delete ON public.sowrix_ui_records AS RESTRICTIVE FOR DELETE TO authenticated USING(public.sowrix_has_permission(public.sowrix_ui_module(kind),'delete'));
-- Approval is a distinct capability; edit-only users cannot approve or undo approval.
CREATE OR REPLACE FUNCTION public.sowrix_approval_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m text:=TG_ARGV[0]; n jsonb:=to_jsonb(NEW); o jsonb:='{}'::jsonb; approved text[]:='{approved,rejected,paid,partially_paid,selected,hired,accepted}';
BEGIN
 IF auth.uid() IS NULL OR auth.role()='service_role' THEN RETURN NEW; END IF;
 IF TG_OP='UPDATE' THEN o:=to_jsonb(OLD); END IF;
 IF TG_TABLE_NAME='sowrix_ui_records' THEN m:=public.sowrix_ui_module(NEW.kind); END IF;
 IF TG_TABLE_NAME='quotations' AND public.sowrix_access_role()='client' THEN m:='client_quotes'; END IF;
 IF (n->>'status') IS DISTINCT FROM (o->>'status') AND ((n->>'status')=ANY(approved) OR (o->>'status')=ANY(approved)) AND NOT public.sowrix_has_permission(m,'approve') THEN RAISE EXCEPTION 'Approval permission required' USING ERRCODE='42501'; END IF;
 IF TG_OP='UPDATE' AND NOT public.sowrix_has_permission(m,'edit') AND ((n-ARRAY['status','updated_at','reviewer_id','paid_at']) IS DISTINCT FROM (o-ARRAY['status','updated_at','reviewer_id','paid_at'])) THEN RAISE EXCEPTION 'Edit permission required for non-approval fields' USING ERRCODE='42501'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS sowrix_v4_approval ON public.quotations;
CREATE TRIGGER sowrix_v4_approval BEFORE INSERT OR UPDATE ON public.quotations FOR EACH ROW EXECUTE FUNCTION public.sowrix_approval_guard('quotations');
DROP TRIGGER IF EXISTS sowrix_v4_approval ON public.payroll_records;
CREATE TRIGGER sowrix_v4_approval BEFORE INSERT OR UPDATE ON public.payroll_records FOR EACH ROW EXECUTE FUNCTION public.sowrix_approval_guard('payroll');
DROP TRIGGER IF EXISTS sowrix_v4_approval ON public.expenses;
CREATE TRIGGER sowrix_v4_approval BEFORE INSERT OR UPDATE ON public.expenses FOR EACH ROW EXECUTE FUNCTION public.sowrix_approval_guard('expenses');
DROP TRIGGER IF EXISTS sowrix_v4_approval ON public.job_applications;
CREATE TRIGGER sowrix_v4_approval BEFORE INSERT OR UPDATE ON public.job_applications FOR EACH ROW EXECUTE FUNCTION public.sowrix_approval_guard('applications');
DROP TRIGGER IF EXISTS sowrix_v4_approval ON public.leave_requests;
CREATE TRIGGER sowrix_v4_approval BEFORE INSERT OR UPDATE ON public.leave_requests FOR EACH ROW EXECUTE FUNCTION public.sowrix_approval_guard('leaves');
DROP TRIGGER IF EXISTS sowrix_v4_approval ON public.invoices;
CREATE TRIGGER sowrix_v4_approval BEFORE INSERT OR UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.sowrix_approval_guard('invoices');
DROP TRIGGER IF EXISTS sowrix_v4_approval ON public.sowrix_ui_records;
CREATE TRIGGER sowrix_v4_approval BEFORE INSERT OR UPDATE ON public.sowrix_ui_records FOR EACH ROW EXECUTE FUNCTION public.sowrix_approval_guard('documents');
-- Private storage remains owner/role scoped; action permissions additionally gate writes.
DROP POLICY IF EXISTS sowrix_v4_private_insert ON storage.objects;
CREATE POLICY sowrix_v4_private_insert ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(bucket_id<>'sowrix-private' OR public.sowrix_has_permission('documents','create') OR public.sowrix_has_permission('profile','create'));
DROP POLICY IF EXISTS sowrix_v4_private_update ON storage.objects;
CREATE POLICY sowrix_v4_private_update ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated USING(bucket_id<>'sowrix-private' OR public.sowrix_has_permission('documents','edit') OR public.sowrix_has_permission('profile','edit')) WITH CHECK(bucket_id<>'sowrix-private' OR public.sowrix_has_permission('documents','edit') OR public.sowrix_has_permission('profile','edit'));
DROP POLICY IF EXISTS sowrix_v4_private_delete ON storage.objects;
CREATE POLICY sowrix_v4_private_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(bucket_id<>'sowrix-private' OR public.sowrix_has_permission('documents','delete'));
-- No direct role updates, including by an administrator: the audited RPC is required.
DROP POLICY IF EXISTS sowrix_v4_role_insert ON public.user_roles;
CREATE POLICY sowrix_v4_role_insert ON public.user_roles AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(false);
DROP POLICY IF EXISTS sowrix_v4_role_update ON public.user_roles;
CREATE POLICY sowrix_v4_role_update ON public.user_roles AS RESTRICTIVE FOR UPDATE TO authenticated USING(false) WITH CHECK(false);
DROP POLICY IF EXISTS sowrix_v4_role_delete ON public.user_roles;
CREATE POLICY sowrix_v4_role_delete ON public.user_roles AS RESTRICTIVE FOR DELETE TO authenticated USING(false);
-- Included by sowrix-complete-setup.sql; run with that setup.
CREATE OR REPLACE FUNCTION public.sowrix_self_action(p_action text,p_id uuid DEFAULT NULL,p_value text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result_id uuid; uid uuid:=auth.uid(); r text:=public.sowrix_access_role(); today date:=(now() AT TIME ZONE 'Asia/Kolkata')::date; clock time:=(now() AT TIME ZONE 'Asia/Kolkata')::time;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 IF p_action='task' THEN
  IF r<>'employee' OR NOT public.sowrix_has_permission('tasks','edit') THEN RAISE EXCEPTION 'Task access required' USING ERRCODE='42501'; END IF;
  IF p_value NOT IN ('in_progress','done') OR p_value IS NULL THEN RAISE EXCEPTION 'Invalid task status'; END IF;
  UPDATE public.tasks SET status=p_value,completed_at=CASE WHEN p_value='done' THEN now() ELSE NULL END,updated_at=now()
   WHERE id=p_id AND assignee_id=uid AND status NOT IN ('cancelled') RETURNING id INTO result_id;
 ELSIF p_action='notification' THEN
  IF NOT public.sowrix_has_permission('notifications','edit') THEN RAISE EXCEPTION 'Notifications access required' USING ERRCODE='42501'; END IF;
  UPDATE public.notifications SET read_at=now(),updated_at=now() WHERE id=p_id AND user_id=uid RETURNING id INTO result_id;
 ELSIF p_action IN ('check_in','check_out') THEN
  IF r<>'employee' OR NOT public.sowrix_has_module_access('attendance') THEN RAISE EXCEPTION 'Attendance access required' USING ERRCODE='42501'; END IF;
  IF p_action='check_in' THEN
   INSERT INTO public.attendance_records(employee_user_id,attendance_date,check_in,status)
   VALUES(uid,today,clock,'present') ON CONFLICT(employee_user_id,attendance_date) DO NOTHING RETURNING id INTO result_id;
   IF result_id IS NULL THEN RAISE EXCEPTION 'You have already checked in today'; END IF;
  ELSE
   UPDATE public.attendance_records SET check_out=clock,updated_at=now()
   WHERE employee_user_id=uid AND attendance_date=today AND check_in IS NOT NULL AND check_out IS NULL RETURNING id INTO result_id;
  END IF;
 ELSE RAISE EXCEPTION 'Unknown action';
 END IF;
 IF result_id IS NULL THEN RAISE EXCEPTION 'No accessible record was updated. Check in first or refresh your records.' USING ERRCODE='42501'; END IF;
 RETURN result_id;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_self_action(text,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_self_action(text,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_ui_quotes() RETURNS SETOF public.quotations LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT q.* FROM public.quotations q JOIN public.clients c ON c.id=q.client_id WHERE c.auth_user_id=auth.uid() AND public.sowrix_access_role()='client' AND public.sowrix_has_permission('client_quotes','view') AND q.status<>'draft'
$$;
CREATE OR REPLACE FUNCTION public.sowrix_people_display(p_user_ids uuid[])
RETURNS TABLE(user_id uuid,employee_code text,full_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $identity$
DECLARE
 see_team boolean;
 target uuid;
 directory_record jsonb;
 legacy_record jsonb;
 metadata_record jsonb;
 resolved_name text;
 resolved_code text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 IF coalesce(cardinality(p_user_ids),0)>500 THEN
  RAISE EXCEPTION 'Request at most 500 employees' USING ERRCODE='22023';
 END IF;
 -- Keep the existing v4 module, role and row-scope checks.
 see_team:=public.sowrix_access_admin() OR EXISTS(
  SELECT 1 FROM public.sowrix_permission_catalog c
  WHERE c.module_key IN ('employees','attendance','leaves','payroll','interviews')
  AND public.sowrix_has_permission(c.module_key,'view')
  AND (public.sowrix_access_role() IN ('hr','hr_staff','hr_manager')
       OR public.sowrix_wide_access(c.module_key,'view')));
 IF NOT see_team AND NOT EXISTS(
  SELECT 1 FROM public.sowrix_permission_catalog c
  WHERE c.module_key IN ('attendance','leaves','payroll','interviews')
  AND public.sowrix_has_permission(c.module_key,'view')
 ) THEN RAISE EXCEPTION 'People module access required' USING ERRCODE='42501'; END IF;

 FOR target IN SELECT DISTINCT requested.id
  FROM unnest(coalesce(p_user_ids,'{}'::uuid[])) requested(id)
  WHERE requested.id IS NOT NULL
 LOOP
  IF NOT see_team AND target<>auth.uid() THEN CONTINUE; END IF;
  directory_record:=NULL; legacy_record:=NULL; metadata_record:=NULL;
  resolved_name:=NULL; resolved_code:=NULL;
  SELECT to_jsonb(e) INTO directory_record FROM public.employees e
  WHERE e.user_id=target ORDER BY e.created_at DESC,e.id LIMIT 1;
  -- Legacy field aliases are read without requiring schema changes.
  IF to_regclass('public.employee_profiles') IS NOT NULL THEN
   EXECUTE $legacy$
    SELECT to_jsonb(e) FROM public.employee_profiles e
    WHERE coalesce(nullif(to_jsonb(e)->>'user_id',''),
                   nullif(to_jsonb(e)->>'auth_user_id',''))=$1
    ORDER BY to_jsonb(e)->>'updated_at' DESC NULLS LAST,
             to_jsonb(e)->>'created_at' DESC NULLS LAST,to_jsonb(e)->>'id'
    LIMIT 1
   $legacy$ INTO legacy_record USING target::text;
  END IF;
  -- Auth fallback is limited to known profiles or users referenced by staff records.
  IF directory_record IS NULL AND legacy_record IS NULL
   AND NOT EXISTS(SELECT 1 FROM public.attendance_records a WHERE a.employee_user_id=target)
   AND NOT EXISTS(SELECT 1 FROM public.leave_requests l WHERE l.employee_user_id=target)
   AND NOT EXISTS(SELECT 1 FROM public.payroll_records p WHERE p.employee_user_id=target)
   AND NOT EXISTS(SELECT 1 FROM public.interviews i WHERE i.interviewer_id=target)
  THEN CONTINUE; END IF;
  SELECT u.raw_user_meta_data INTO metadata_record FROM auth.users u WHERE u.id=target;
  -- Resolve each field separately: a current name must not hide an older ID.
  SELECT btrim(v.value) INTO resolved_name
  FROM unnest(ARRAY[
   directory_record->>'full_name',directory_record->>'display_name',directory_record->>'name',
   legacy_record->>'full_name',legacy_record->>'display_name',legacy_record->>'name',
   metadata_record->>'full_name',metadata_record->>'display_name',metadata_record->>'name'
  ]) WITH ORDINALITY v(value,priority)
  WHERE nullif(btrim(v.value),'') IS NOT NULL
   AND lower(btrim(v.value)) NOT IN ('name not set','not set','unknown','unassigned','null','undefined','—','-')
  ORDER BY v.priority LIMIT 1;
  SELECT btrim(v.value) INTO resolved_code
  FROM unnest(ARRAY[
   directory_record->>'employee_code',directory_record->>'employee_id',directory_record->>'staff_id',
   legacy_record->>'employee_code',legacy_record->>'employee_id',legacy_record->>'staff_id',
   metadata_record->>'employee_code',metadata_record->>'employee_id',metadata_record->>'staff_id'
  ]) WITH ORDINALITY v(value,priority)
  WHERE nullif(btrim(v.value),'') IS NOT NULL
   AND lower(btrim(v.value)) NOT IN ('name not set','not set','unknown','unassigned','null','undefined','—','-')
  ORDER BY v.priority LIMIT 1;
  user_id:=target; employee_code:=resolved_code; full_name:=resolved_name;
  RETURN NEXT;
 END LOOP;
END
$identity$;
REVOKE ALL ON FUNCTION public.sowrix_people_display(uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_people_display(uuid[]) TO authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_employee_picker()
RETURNS TABLE(user_id uuid,employee_code text,full_name text) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.sowrix_access_admin() AND NOT EXISTS(SELECT 1 FROM public.sowrix_permission_catalog c WHERE c.module_key IN ('employees','tasks','projects','interviews','leaves','payroll','tickets','documents','onboarding') AND (public.sowrix_has_permission(c.module_key,'create') OR public.sowrix_has_permission(c.module_key,'edit'))) THEN RAISE EXCEPTION 'Employee assignment access required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT e.user_id,coalesce(e.employee_code,'—'),coalesce(e.full_name,'Name not set') FROM public.employees e WHERE e.user_id IS NOT NULL AND e.employment_status<>'terminated' ORDER BY e.full_name LIMIT 500;
END $$;
DO $$ DECLARE f text; BEGIN FOREACH f IN ARRAY ARRAY['sowrix_has_permission(text,text)','sowrix_wide_access(text,text)','sowrix_permission_snapshot()','sowrix_team_access_v4()','sowrix_save_team_access(uuid,text,jsonb,text,boolean,bigint,text,text)'] LOOP
 EXECUTE 'REVOKE ALL ON FUNCTION public.'||f||' FROM PUBLIC,anon';EXECUTE 'GRANT EXECUTE ON FUNCTION public.'||f||' TO authenticated';
END LOOP; END $$;
-- Published-content policies evaluate these own-session boolean helpers for anon.
GRANT EXECUTE ON FUNCTION public.sowrix_has_permission(text,text),public.sowrix_wide_access(text,text) TO anon;
REVOKE ALL ON FUNCTION public.sowrix_approval_guard() FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_ui_respond_quote(p_id uuid,p_status text,p_comment text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE q public.quotations;
BEGIN
 SELECT * INTO q FROM public.quotations WHERE id=p_id FOR UPDATE;
 IF auth.uid() IS NULL OR NOT public.sowrix_has_permission('client_quotes','approve') OR public.sowrix_access_role()<>'client' OR NOT EXISTS(SELECT 1 FROM public.clients c WHERE c.id=q.client_id AND c.auth_user_id=auth.uid()) THEN RAISE EXCEPTION 'Quotation not available'; END IF;
 IF q.status<>'sent' OR (q.valid_until IS NOT NULL AND q.valid_until<current_date) THEN RAISE EXCEPTION 'Quotation already answered or expired'; END IF;
 IF p_status NOT IN ('accepted','rejected') OR length(p_comment)>2000 THEN RAISE EXCEPTION 'Invalid response'; END IF;
 UPDATE public.quotations SET status=p_status,updated_at=now() WHERE id=p_id;
 INSERT INTO public.sowrix_ui_records(kind,owner_id,title,body,payload) VALUES('quote_response',auth.uid(),q.quotation_number,p_comment,jsonb_build_object('quote_id',q.id,'decision',p_status));
END $$;

-- BEGIN LAUNCH IDENTITY
-- Internal helper. It is intentionally not callable by browser roles.
CREATE OR REPLACE FUNCTION public.sowrix_identity_internal(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $identity$
DECLARE d jsonb; l jsonb; m jsonb; n text; c text; email_value text;
BEGIN
 SELECT to_jsonb(e) INTO d FROM public.employees e WHERE e.user_id=p_user_id
 ORDER BY e.created_at DESC,e.id LIMIT 1;
 IF to_regclass('public.employee_profiles') IS NOT NULL THEN
  EXECUTE $legacy$
   SELECT to_jsonb(e) FROM public.employee_profiles e
   WHERE coalesce(nullif(to_jsonb(e)->>'user_id',''),nullif(to_jsonb(e)->>'auth_user_id',''))=$1
   ORDER BY to_jsonb(e)->>'updated_at' DESC NULLS LAST,
            to_jsonb(e)->>'created_at' DESC NULLS LAST,to_jsonb(e)->>'id' LIMIT 1
  $legacy$ INTO l USING p_user_id::text;
 END IF;
 SELECT u.raw_user_meta_data,u.email INTO m,email_value FROM auth.users u WHERE u.id=p_user_id;
 SELECT btrim(v.value) INTO n FROM unnest(ARRAY[
  d->>'full_name',d->>'display_name',d->>'name',l->>'full_name',l->>'display_name',l->>'name',
  m->>'full_name',m->>'display_name',m->>'name'
 ]) WITH ORDINALITY v(value,priority)
 WHERE nullif(btrim(v.value),'') IS NOT NULL
 AND lower(btrim(v.value)) NOT IN ('name not set','not set','unknown','unassigned','null','undefined','—','-')
 ORDER BY v.priority LIMIT 1;
 SELECT btrim(v.value) INTO c FROM unnest(ARRAY[
  d->>'employee_code',d->>'employee_id',d->>'staff_id',l->>'employee_code',l->>'employee_id',l->>'staff_id',
  m->>'employee_code',m->>'employee_id',m->>'staff_id'
 ]) WITH ORDINALITY v(value,priority)
 WHERE nullif(btrim(v.value),'') IS NOT NULL
 AND lower(btrim(v.value)) NOT IN ('name not set','not set','unknown','unassigned','null','undefined','—','-')
 ORDER BY v.priority LIMIT 1;
 RETURN jsonb_build_object('user_id',p_user_id,'full_name',n,'employee_code',c,'email',email_value,
  'department',coalesce(nullif(btrim(d->>'department'),''),nullif(btrim(l->>'department'),'')),
  'designation',coalesce(nullif(btrim(d->>'designation'),''),nullif(btrim(l->>'designation'),'')),
  'joining_date',coalesce(d->>'joining_date',l->>'joining_date'),
  'has_profile',d IS NOT NULL OR l IS NOT NULL);
END
$identity$;
REVOKE ALL ON FUNCTION public.sowrix_identity_internal(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_my_identity()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR public.sowrix_access_role() IS NULL THEN
  RAISE EXCEPTION 'Approved sign-in required' USING ERRCODE='42501';
 END IF;
 -- No caller-supplied user ID: this endpoint can only return the current account.
 RETURN public.sowrix_identity_internal(auth.uid());
END $$;
REVOKE ALL ON FUNCTION public.sowrix_my_identity() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_my_identity() TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_employee_picker()
RETURNS TABLE(user_id uuid,employee_code text,full_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR (NOT public.sowrix_access_admin() AND NOT EXISTS(
  SELECT 1 FROM public.sowrix_permission_catalog c
  WHERE c.module_key IN ('employees','tasks','projects','interviews','leaves','payroll','tickets','documents','onboarding')
  AND (public.sowrix_has_permission(c.module_key,'create') OR public.sowrix_has_permission(c.module_key,'edit'))
 )) THEN RAISE EXCEPTION 'Employee assignment access required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT e.user_id,coalesce(i.value->>'employee_code','—'),coalesce(i.value->>'full_name','Name not set')
 FROM public.employees e
 CROSS JOIN LATERAL (SELECT public.sowrix_identity_internal(e.user_id) AS value) i
 WHERE e.user_id IS NOT NULL AND e.employment_status<>'terminated'
 ORDER BY i.value->>'full_name',e.user_id LIMIT 500;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_employee_picker() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_employee_picker() TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_team_access_v4()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('people',coalesce((SELECT jsonb_agg(x.row ORDER BY x.email) FROM (
  SELECT u.email,jsonb_build_object('user_id',u.id,'email',u.email,
   'full_name',coalesce(i.value->>'full_name',''),'employee_code',coalesce(i.value->>'employee_code',''),
   'department',coalesce(i.value->>'department',''),'designation',coalesce(i.value->>'designation',''),
   'role',r.role::text,'revision',coalesce(v.revision,0),
   'grants',coalesce((SELECT jsonb_agg(jsonb_build_object('module',g.module_key,'actions',g.actions,'scope',g.row_scope)) FROM public.sowrix_action_grants g WHERE g.user_id=u.id),'[]'::jsonb)) row
  FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id
  LEFT JOIN public.sowrix_access_revisions v ON v.user_id=u.id
  CROSS JOIN LATERAL (SELECT public.sowrix_identity_internal(u.id) AS value) i
 ) x),'[]'::jsonb),
 'catalog',(SELECT jsonb_agg(to_jsonb(c) ORDER BY c.label) FROM public.sowrix_permission_catalog c),
 'history',coalesce((SELECT jsonb_agg(to_jsonb(z)) FROM (
  SELECT a.created_at,coalesce(nullif(public.sowrix_identity_internal(a.actor_id)->>'full_name',''),u.email,'Administrator') actor,a.details
  FROM public.audit_logs a LEFT JOIN auth.users u ON u.id=a.actor_id
  WHERE a.action='access_changed_v4' ORDER BY a.created_at DESC LIMIT 30
 ) z),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.sowrix_team_access_v4() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_team_access_v4() TO authenticated;
-- END LAUNCH IDENTITY

NOTIFY pgrst,'reload schema';

-- A successful SQL Editor run returns this installation summary.
SELECT 'Team Access installation complete'::text AS status,
       to_regprocedure('public.sowrix_team_access_v4()')::text AS team_access_rpc,
       (SELECT count(*) FROM public.sowrix_permission_catalog) AS permission_modules;


-- FILE: 09-client-contact-repair.sql
-- SOWRIX client onboarding and durable enquiry notifications.
-- Run after 06 in the existing project. No accounts, emails or old requests are
-- created/sent by installation. Existing roles and access decisions are preserved.

CREATE OR REPLACE FUNCTION public.sowrix_client_invite_context(p_actor_id uuid,p_client_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.clients; u auth.users; r text;
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' OR NOT EXISTS(SELECT 1 FROM public.user_roles WHERE user_id=p_actor_id AND role::text IN ('admin','super_admin')) THEN
  RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';
 END IF;
 SELECT * INTO c FROM public.clients WHERE id=p_client_id;
 IF c.id IS NULL OR c.status<>'active' THEN RAISE EXCEPTION 'Choose an active client record' USING ERRCODE='22023'; END IF;
 IF coalesce(c.email,'') !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]{2,}$' THEN RAISE EXCEPTION 'Save the client email before setting up login' USING ERRCODE='22023'; END IF;
 SELECT * INTO u FROM auth.users WHERE lower(email)=lower(btrim(c.email));
 IF c.auth_user_id IS NOT NULL AND c.auth_user_id IS DISTINCT FROM u.id THEN RAISE EXCEPTION 'Linked login does not match the client email. Review the link first' USING ERRCODE='23514'; END IF;
 SELECT role::text INTO r FROM public.user_roles WHERE user_id=u.id;
 IF (r IS NOT NULL AND r<>'client') OR EXISTS(SELECT 1 FROM public.employees WHERE user_id=u.id) THEN RAISE EXCEPTION 'This email belongs to a staff account. Use a separate client email' USING ERRCODE='23514'; END IF;
 RETURN jsonb_build_object('client_id',c.id,'email',lower(btrim(c.email)),'full_name',coalesce(nullif(btrim(c.contact_person),''),c.organization_name),'user_id',u.id,'confirmed',u.email_confirmed_at IS NOT NULL);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_client_invite_context(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_client_invite_context(uuid,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.sowrix_bind_client_login(p_actor_id uuid,p_client_id uuid,p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ctx jsonb; r text; revision bigint; grant_count integer;
BEGIN
 PERFORM 1 FROM public.clients WHERE id=p_client_id FOR UPDATE;
 PERFORM 1 FROM auth.users WHERE id=p_user_id FOR UPDATE;
 ctx:=public.sowrix_client_invite_context(p_actor_id,p_client_id);
 IF nullif(ctx->>'user_id','')::uuid IS DISTINCT FROM p_user_id OR p_user_id IS NULL THEN RAISE EXCEPTION 'The verified email and account do not match' USING ERRCODE='23514'; END IF;
 SELECT role::text INTO r FROM public.user_roles WHERE user_id=p_user_id FOR UPDATE;
 IF r IS NOT NULL AND r<>'client' THEN RAISE EXCEPTION 'Account role changed. Review Team Access' USING ERRCODE='23514'; END IF;
 INSERT INTO public.user_roles(user_id,role) VALUES(p_user_id,'client') ON CONFLICT DO NOTHING;
 SELECT coalesce(v.revision,0) INTO revision FROM public.sowrix_access_revisions v WHERE user_id=p_user_id;
 SELECT count(*) INTO grant_count FROM public.sowrix_action_grants WHERE user_id=p_user_id;
 -- Only provision an untouched account. Never restore a revoked/edited grant set.
 IF coalesce(revision,0)=0 AND grant_count=0 THEN
  INSERT INTO public.sowrix_action_grants(user_id,module_key,actions,row_scope,granted_by)
   SELECT p_user_id,k,a,'standard',p_actor_id FROM (VALUES
    ('clients','{view}'::text[]),('projects','{view}'::text[]),('invoices','{view}'::text[]),
    ('tickets','{view,create}'::text[]),('notifications','{view,edit}'::text[]),('client_quotes','{view,approve}'::text[])) v(k,a)
   ON CONFLICT DO NOTHING;
 END IF;
 UPDATE public.clients SET auth_user_id=p_user_id,updated_at=now() WHERE id=p_client_id;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
  VALUES(p_actor_id,'client_login_linked','clients',p_client_id::text,jsonb_build_object('user_id',p_user_id));
 RETURN jsonb_build_object('linked',true,'permissions_preserved',coalesce(revision,0)>0 OR grant_count>0);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_bind_client_login(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_bind_client_login(uuid,uuid,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.sowrix_client_login_status()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR public.sowrix_access_role()<>'client' THEN RAISE EXCEPTION 'Client sign-in required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('linked',EXISTS(SELECT 1 FROM public.clients WHERE auth_user_id=auth.uid() AND status='active'),
  'organizations',coalesce((SELECT jsonb_agg(organization_name) FROM public.clients WHERE auth_user_id=auth.uid() AND status='active'),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.sowrix_client_login_status() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_client_login_status() TO authenticated;

-- Client accounts must stay within active linked organizations, including writes.
CREATE OR REPLACE FUNCTION public.sowrix_client_active_owned(p_client_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND public.sowrix_access_role()='client' AND EXISTS
  (SELECT 1 FROM public.clients WHERE auth_user_id=auth.uid() AND status='active' AND (p_client_id IS NULL OR id=p_client_id))
$$;
REVOKE ALL ON FUNCTION public.sowrix_client_active_owned(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_client_active_owned(uuid) TO authenticated;
DROP POLICY IF EXISTS sowrix_client_active_scope ON public.projects;
CREATE POLICY sowrix_client_active_scope ON public.projects AS RESTRICTIVE FOR SELECT TO authenticated USING
 (public.sowrix_access_role()<>'client' OR (client_id IS NOT NULL AND public.sowrix_client_active_owned(client_id)));
DROP POLICY IF EXISTS sowrix_client_active_scope ON public.invoices;
CREATE POLICY sowrix_client_active_scope ON public.invoices AS RESTRICTIVE FOR SELECT TO authenticated USING
 (public.sowrix_access_role()<>'client' OR (status<>'draft' AND client_id IS NOT NULL AND public.sowrix_client_active_owned(client_id)));
DROP POLICY IF EXISTS sowrix_client_active_scope ON public.clients;
CREATE POLICY sowrix_client_active_scope ON public.clients AS RESTRICTIVE FOR SELECT TO authenticated USING
 (public.sowrix_access_role()<>'client' OR (auth_user_id=auth.uid() AND status='active'));
DROP POLICY IF EXISTS sowrix_client_ticket_write ON public.support_tickets;
CREATE POLICY sowrix_client_ticket_write ON public.support_tickets AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK
 (public.sowrix_access_role()<>'client' OR (requester_id=auth.uid() AND public.sowrix_client_active_owned(client_id)));

ALTER TABLE public.contact_enquiries ADD COLUMN IF NOT EXISTS email_status text NOT NULL DEFAULT 'not_queued';
ALTER TABLE public.contact_enquiries ADD COLUMN IF NOT EXISTS email_accepted_at timestamptz;
ALTER TABLE public.contact_enquiries ADD COLUMN IF NOT EXISTS email_last_error text;
CREATE TABLE IF NOT EXISTS public.sowrix_contact_outbox(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), enquiry_id uuid NOT NULL UNIQUE REFERENCES public.contact_enquiries(id) ON DELETE CASCADE,
 state text NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','sending','sent','failed')),
 created_at timestamptz NOT NULL DEFAULT now(), attempts integer NOT NULL DEFAULT 0,
 next_attempt_at timestamptz NOT NULL DEFAULT now(), lease_until timestamptz, claim_token uuid,
 provider_id text, last_error text
);
CREATE INDEX IF NOT EXISTS sowrix_outbox_pending ON public.sowrix_contact_outbox(next_attempt_at) WHERE state IN ('pending','sending');
ALTER TABLE public.sowrix_contact_outbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_contact_outbox FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_queue_contact()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.sowrix_contact_outbox(enquiry_id) VALUES(NEW.id) ON CONFLICT DO NOTHING;
 INSERT INTO public.notifications(user_id,category,title,body)
  SELECT user_id,'enquiry','New website enquiry','A new request is available in Contact Enquiries.'
  FROM public.user_roles WHERE role::text IN ('admin','super_admin');
 UPDATE public.contact_enquiries SET email_status='queued' WHERE id=NEW.id;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_queue_contact() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS sowrix_contact_queue ON public.contact_enquiries;
CREATE TRIGGER sowrix_contact_queue AFTER INSERT ON public.contact_enquiries FOR EACH ROW EXECUTE FUNCTION public.sowrix_queue_contact();

CREATE OR REPLACE FUNCTION public.sowrix_claim_contact_mail(p_limit integer DEFAULT 5)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Service access required' USING ERRCODE='42501'; END IF;
 -- Retry only during the provider idempotency window; ambiguous older jobs require review.
 UPDATE public.sowrix_contact_outbox SET state='failed',last_error='Retry window expired; review provider logs before retrying'
  WHERE state IN ('pending','sending') AND attempts>0 AND created_at<now()-interval '23 hours';
 UPDATE public.contact_enquiries e SET email_status='failed',email_last_error=o.last_error
  FROM public.sowrix_contact_outbox o WHERE o.enquiry_id=e.id AND o.state='failed' AND e.email_status<>'failed';
 WITH chosen AS (SELECT id FROM public.sowrix_contact_outbox
  WHERE (state='pending' OR (state='sending' AND lease_until<now())) AND attempts<6 AND next_attempt_at<=now()
  ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT greatest(1,least(coalesce(p_limit,5),10))),
 claimed AS (UPDATE public.sowrix_contact_outbox o SET state='sending',attempts=attempts+1,lease_until=now()+interval '3 minutes',claim_token=gen_random_uuid()
  FROM chosen c WHERE o.id=c.id RETURNING o.*)
 SELECT coalesce(jsonb_agg(jsonb_build_object('job_id',o.id,'claim_token',o.claim_token,'enquiry_id',e.id,
  'name',e.name,'email',e.email,'phone',e.phone,'company',e.company,'service',e.service_interest,'message',e.message,'location',e.location,'budget',e.budget)),'[]'::jsonb)
 INTO result FROM claimed o JOIN public.contact_enquiries e ON e.id=o.enquiry_id;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_claim_contact_mail(integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_claim_contact_mail(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.sowrix_finish_contact_mail(p_job_id uuid,p_claim_token uuid,p_provider_id text,p_error text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE job public.sowrix_contact_outbox; ok boolean;
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' THEN RAISE EXCEPTION 'Service access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO job FROM public.sowrix_contact_outbox WHERE id=p_job_id AND claim_token=p_claim_token AND state='sending' FOR UPDATE;
 IF job.id IS NULL THEN RETURN false; END IF;
 ok:=nullif(p_provider_id,'') IS NOT NULL AND nullif(p_error,'') IS NULL;
 UPDATE public.sowrix_contact_outbox SET state=CASE WHEN ok THEN 'sent' WHEN attempts>=6 THEN 'failed' ELSE 'pending' END,
  provider_id=CASE WHEN ok THEN left(p_provider_id,200) ELSE provider_id END,last_error=CASE WHEN ok THEN NULL ELSE left(coalesce(p_error,'Delivery not confirmed'),500) END,
  next_attempt_at=now()+make_interval(mins=>least(60,attempts*5)),lease_until=NULL,claim_token=NULL WHERE id=job.id;
 UPDATE public.contact_enquiries SET email_status=CASE WHEN ok THEN 'accepted' WHEN job.attempts>=6 THEN 'failed' ELSE 'retrying' END,
  email_accepted_at=CASE WHEN ok THEN now() ELSE email_accepted_at END,email_last_error=CASE WHEN ok THEN NULL ELSE left(coalesce(p_error,'Delivery not confirmed'),500) END WHERE id=job.enquiry_id;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_finish_contact_mail(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_finish_contact_mail(uuid,uuid,text,text) TO service_role;

CREATE OR REPLACE FUNCTION public.sowrix_submit_consultation_core(p_request jsonb,p_submission_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
 v_name text; v_email text; v_phone text; v_service text; v_message text;
 v_company text; v_location text; v_budget text; k text;
 insert_columns text; insert_values text; inserted_count bigint;
BEGIN
 IF p_submission_key IS NULL OR p_request IS NULL OR jsonb_typeof(p_request)<>'object' THEN
  RAISE EXCEPTION 'A request and retry key are required.' USING ERRCODE='22023';
 END IF;
 FOREACH k IN ARRAY ARRAY['name','email','phone','service_interest','message'] LOOP
  IF coalesce(jsonb_typeof(p_request->k),'null')<>'string' THEN
   RAISE EXCEPTION 'Required contact fields must be text.' USING ERRCODE='22023';
  END IF;
 END LOOP;
 FOREACH k IN ARRAY ARRAY['company','location','budget'] LOOP
  IF coalesce(jsonb_typeof(p_request->k),'null') NOT IN ('string','null') THEN
   RAISE EXCEPTION 'Optional contact fields must be text.' USING ERRCODE='22023';
  END IF;
 END LOOP;
 v_name=btrim(p_request->>'name');v_email=lower(btrim(p_request->>'email'));
 v_phone=btrim(p_request->>'phone');v_service=btrim(p_request->>'service_interest');
 v_message=btrim(p_request->>'message');v_company=nullif(btrim(p_request->>'company'),'');
 v_location=nullif(btrim(p_request->>'location'),'');v_budget=nullif(btrim(p_request->>'budget'),'');
 IF length(v_name) NOT BETWEEN 2 AND 250
  OR length(v_email)>254 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]{2,}$'
  OR v_phone !~ '^[+0-9][0-9 ()-]{7,18}$'
  OR length(v_service) NOT BETWEEN 2 AND 250 OR length(v_message) NOT BETWEEN 20 AND 10000
  OR coalesce(length(v_company),0)>250 OR coalesce(length(v_location),0)>250
  OR coalesce(length(v_budget),0)>100 THEN
  RAISE EXCEPTION 'Check the name, email, phone, service and project description.' USING ERRCODE='22023';
 END IF;

 insert_columns='name,email,phone,service_interest,message,company,location,budget,submission_key,status,assigned_to';
 insert_values='$1,$2,$3,$4,$5,$6,$7,$8,$9,''open'',NULL';
 -- Some earlier versions required service or subject. Populate them when present
 -- instead of deleting legacy columns, weakening constraints, or dropping data.
 IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='contact_enquiries' AND column_name='service') THEN
  insert_columns=insert_columns||',service';insert_values=insert_values||',$4';
 END IF;
 IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='contact_enquiries' AND column_name='subject') THEN
  insert_columns=insert_columns||',subject';insert_values=insert_values||',$4';
 END IF;
 EXECUTE 'INSERT INTO public.contact_enquiries ('||insert_columns||') VALUES ('||insert_values||') ON CONFLICT (submission_key) DO NOTHING'
  USING v_name,v_email,v_phone,v_service,v_message,v_company,v_location,v_budget,p_submission_key;
 GET DIAGNOSTICS inserted_count=ROW_COUNT;
 IF inserted_count=0 AND NOT EXISTS (
  SELECT 1 FROM public.contact_enquiries e WHERE e.submission_key=p_submission_key
   AND e.name=v_name AND e.email=v_email AND e.phone=v_phone AND e.service_interest=v_service
   AND e.message=v_message AND e.company IS NOT DISTINCT FROM v_company
   AND e.location IS NOT DISTINCT FROM v_location AND e.budget IS NOT DISTINCT FROM v_budget
 ) THEN
  RAISE EXCEPTION 'Retry key conflict. Open a new form.' USING ERRCODE='22023';
 END IF;
 RETURN jsonb_build_object('accepted',true);
END
$function$;
REVOKE ALL ON FUNCTION public.sowrix_submit_consultation_core(jsonb,uuid) FROM PUBLIC,anon,authenticated;
-- Rate limiting and idempotency are applied before the durable insert.
CREATE TABLE IF NOT EXISTS public.sowrix_contact_limits(key text PRIMARY KEY,window_start timestamptz NOT NULL DEFAULT now(),used integer NOT NULL DEFAULT 0);
ALTER TABLE public.sowrix_contact_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_contact_limits FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_submit_consultation(p_request jsonb,p_submission_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE k text; v integer;
BEGIN
 IF p_submission_key IS NULL OR p_request IS NULL OR jsonb_typeof(p_request)<>'object' THEN RAISE EXCEPTION 'Invalid contact request' USING ERRCODE='22023'; END IF;
 k:=md5(lower(btrim(coalesce(p_request->>'email',''))));
 PERFORM pg_advisory_xact_lock(hashtext(k));
 IF NOT EXISTS(SELECT 1 FROM public.contact_enquiries WHERE submission_key=p_submission_key) THEN
  INSERT INTO public.sowrix_contact_limits(key,used) VALUES(k,1) ON CONFLICT(key) DO UPDATE
   SET used=CASE WHEN public.sowrix_contact_limits.window_start<now()-interval '1 hour' THEN 1 ELSE public.sowrix_contact_limits.used+1 END,
    window_start=CASE WHEN public.sowrix_contact_limits.window_start<now()-interval '1 hour' THEN now() ELSE public.sowrix_contact_limits.window_start END RETURNING used INTO v;
  IF v>5 THEN RAISE EXCEPTION 'Too many requests. Please contact the team or try again later' USING ERRCODE='P0001'; END IF;
  DELETE FROM public.sowrix_contact_limits WHERE window_start<now()-interval '2 days';
 END IF;
 RETURN public.sowrix_submit_consultation_core(p_request,p_submission_key);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_submit_consultation(jsonb,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_submit_consultation(jsonb,uuid) TO anon,authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_release_health()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('release',9,'unlinked_clients',(SELECT count(*) FROM public.clients WHERE status='active' AND auth_user_id IS NULL),
  'mail_pending',(SELECT count(*) FROM public.sowrix_contact_outbox WHERE state IN ('pending','sending')),
  'mail_failed',(SELECT count(*) FROM public.sowrix_contact_outbox WHERE state='failed'));
END $$;
REVOKE ALL ON FUNCTION public.sowrix_release_health() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_release_health() TO authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_ui_quotes() RETURNS SETOF public.quotations LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT q.* FROM public.quotations q JOIN public.clients c ON c.id=q.client_id WHERE c.auth_user_id=auth.uid() AND c.status='active' AND public.sowrix_access_role()='client' AND public.sowrix_has_permission('client_quotes','view') AND q.status<>'draft'
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_respond_quote(p_id uuid,p_status text,p_comment text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE q public.quotations;
BEGIN
 SELECT * INTO q FROM public.quotations WHERE id=p_id FOR UPDATE;
 IF auth.uid() IS NULL OR NOT public.sowrix_has_permission('client_quotes','approve') OR public.sowrix_access_role()<>'client' OR NOT EXISTS(SELECT 1 FROM public.clients c WHERE c.id=q.client_id AND c.auth_user_id=auth.uid() AND c.status='active') THEN RAISE EXCEPTION 'Quotation not available'; END IF;
 IF q.status<>'sent' OR (q.valid_until IS NOT NULL AND q.valid_until<current_date) THEN RAISE EXCEPTION 'Quotation already answered or expired'; END IF;
 IF p_status NOT IN ('accepted','rejected') OR length(p_comment)>2000 THEN RAISE EXCEPTION 'Invalid response'; END IF;
 UPDATE public.quotations SET status=p_status,updated_at=now() WHERE id=p_id;
 INSERT INTO public.sowrix_ui_records(kind,owner_id,title,body,payload) VALUES('quote_response',auth.uid(),q.quotation_number,p_comment,jsonb_build_object('quote_id',q.id,'decision',p_status));
END $$;
NOTIFY pgrst,'reload schema';

NOTIFY pgrst,'reload schema';


-- SOWRIX security foundation, release 10. Apply AFTER the complete release 9 schema.
-- Test in staging first. Requires real Supabase Auth session and MFA tables.
-- Existing data/IDs remain. Unclassified notes move to staff-only companion tables.
DO $$ BEGIN
 IF to_regclass('auth.sessions') IS NULL OR to_regclass('auth.mfa_factors') IS NULL OR to_regprocedure('auth.jwt()') IS NULL THEN
  RAISE EXCEPTION 'Supabase Auth sessions, MFA factors and auth.jwt() are required' USING ERRCODE='55000';
 END IF;
 IF to_regprocedure('public.sowrix_release_health()') IS NULL THEN RAISE EXCEPTION 'Install the complete release 9 backend first' USING ERRCODE='55000'; END IF;
 IF EXISTS(SELECT 1 FROM public.invoices i JOIN public.projects p ON p.id=i.project_id WHERE i.client_id IS DISTINCT FROM p.client_id)
 OR EXISTS(SELECT 1 FROM public.quotations q JOIN public.projects p ON p.id=q.project_id WHERE q.client_id IS DISTINCT FROM p.client_id) THEN
  RAISE EXCEPTION 'An invoice or quotation references a project from a different organization. Review and correct those existing links before installing; no data has been changed.' USING ERRCODE='23514';
 END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.sowrix_account_security(
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 disabled_at timestamptz,
 reauth_after timestamptz NOT NULL DEFAULT '-infinity',
 reason text NOT NULL DEFAULT '',
 updated_by uuid REFERENCES auth.users(id),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sowrix_org_memberships(
 organization_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 member_role text NOT NULL CHECK(member_role IN ('owner','member')),
 status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','suspended')),
 billing_access boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(organization_id,user_id)
);
CREATE INDEX IF NOT EXISTS sowrix_org_membership_user ON public.sowrix_org_memberships(user_id,status,organization_id);
ALTER TABLE public.sowrix_account_security ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_org_memberships ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_account_security,public.sowrix_org_memberships FROM PUBLIC,anon,authenticated;
-- A membership is created once from an existing verified client linkage. Reruns never
-- reactivate a suspended membership or restore a deliberately changed billing grant.
INSERT INTO public.sowrix_org_memberships(organization_id,user_id,member_role,billing_access)
 SELECT c.id,c.auth_user_id,'owner',true FROM public.clients c
 JOIN public.user_roles r ON r.user_id=c.auth_user_id AND lower(r.role::text)='client'
 JOIN auth.users u ON u.id=c.auth_user_id
 ON CONFLICT(organization_id,user_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.sowrix_secure_session_allowed()
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); claims jsonb:=auth.jwt(); sid uuid; account_role text;
BEGIN
 IF uid IS NULL THEN RETURN false; END IF;
 SELECT lower(r.role::text) INTO account_role FROM public.user_roles r WHERE r.user_id=uid;
 IF account_role IS NULL THEN RETURN false; END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=uid AND u.deleted_at IS NULL AND (u.banned_until IS NULL OR u.banned_until<=now()))
 OR EXISTS(SELECT 1 FROM public.sowrix_account_security s WHERE s.user_id=uid AND s.disabled_at IS NOT NULL) THEN RETURN false; END IF;
 BEGIN sid:=nullif(claims->>'session_id','')::uuid; EXCEPTION WHEN invalid_text_representation THEN RETURN false; END;
 IF sid IS NULL OR NOT EXISTS(SELECT 1 FROM auth.sessions s WHERE s.id=sid AND s.user_id=uid AND s.created_at>=coalesce((SELECT a.reauth_after FROM public.sowrix_account_security a WHERE a.user_id=uid),'-infinity'::timestamptz)) THEN RETURN false; END IF;
 IF account_role='client' THEN
  RETURN EXISTS(SELECT 1 FROM public.sowrix_org_memberships m JOIN public.clients c ON c.id=m.organization_id
   WHERE m.user_id=uid AND m.status='active' AND c.status='active');
 END IF;
 IF claims->>'aal' IS DISTINCT FROM 'aal2' OR NOT EXISTS(SELECT 1 FROM auth.mfa_factors f WHERE f.user_id=uid AND f.status::text='verified') THEN RETURN false; END IF;
 IF EXISTS(SELECT 1 FROM public.employees e WHERE e.user_id=uid AND lower(e.employment_status) IN ('inactive','terminated','suspended')) THEN RETURN false; END IF;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_secure_session_allowed() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_secure_session_allowed() TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sowrix_require_secure_session(p_recent_mfa boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE verified_at timestamptz;
BEGIN
 IF NOT public.sowrix_secure_session_allowed() THEN
  RAISE EXCEPTION 'Verified active session required. Staff must complete authenticator verification.' USING ERRCODE='42501';
 END IF;
 IF p_recent_mfa AND public.sowrix_access_role()<>'client' THEN
  SELECT max(to_timestamp((v->>'timestamp')::double precision)) INTO verified_at
   FROM jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) v
   WHERE v->>'method' IN ('totp','phone','mfa/totp','mfa/phone') AND v->>'timestamp' ~ '^[0-9]+(\.[0-9]+)?$';
  IF verified_at IS NULL OR verified_at<now()-interval '10 minutes' OR verified_at>now()+interval '1 minute' THEN
   RAISE EXCEPTION 'Verify a new authenticator code in Account Security before this sensitive action.' USING ERRCODE='42501';
  END IF;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_require_secure_session(boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_require_secure_session(boolean) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sowrix_org_access(p_organization_id uuid,p_capability text DEFAULT 'general')
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_secure_session_allowed() AND public.sowrix_access_role()='client' AND EXISTS(
  SELECT 1 FROM public.sowrix_org_memberships m JOIN public.clients c ON c.id=m.organization_id
  WHERE m.user_id=auth.uid() AND m.organization_id=p_organization_id AND m.status='active' AND c.status='active'
   AND (p_capability IN ('general','tickets') OR (p_capability='billing' AND (m.member_role='owner' OR m.billing_access)) OR (p_capability='members' AND m.member_role='owner')))
$$;
REVOKE ALL ON FUNCTION public.sowrix_org_access(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_org_access(uuid,text) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.sowrix_client_active_owned(p_client_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_secure_session_allowed() AND EXISTS(SELECT 1 FROM public.sowrix_org_memberships m
 JOIN public.clients c ON c.id=m.organization_id WHERE m.user_id=auth.uid() AND m.status='active' AND c.status='active'
 AND (p_client_id IS NULL OR c.id=p_client_id) AND public.sowrix_access_role()='client')
$$;
CREATE OR REPLACE FUNCTION public.sowrix_access_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(public.sowrix_access_role() IN ('admin','super_admin'),false) AND public.sowrix_secure_session_allowed()
$$;
CREATE OR REPLACE FUNCTION public.sowrix_consultation_is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT public.sowrix_access_admin() $$;

-- Existing ordinary application grants still decide which modules/actions are allowed.
CREATE OR REPLACE FUNCTION public.sowrix_has_permission(p_module text,p_action text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_secure_session_allowed() AND EXISTS(SELECT 1 FROM public.sowrix_permission_catalog c WHERE c.module_key=p_module AND p_action=ANY(c.actions)) AND
 (public.sowrix_access_admin() OR (
  NOT EXISTS(SELECT 1 FROM public.sowrix_permission_catalog c WHERE c.module_key=p_module AND c.admin_only) AND
  NOT (p_module='attendance' AND p_action<>'view') AND
  NOT (p_module='employees' AND p_action='create' AND public.sowrix_access_role() NOT IN ('hr','hr_staff','hr_manager')) AND
  EXISTS(SELECT 1 FROM public.sowrix_action_grants g WHERE g.user_id=auth.uid() AND g.module_key=p_module AND 'view'=ANY(g.actions) AND p_action=ANY(g.actions))
 ))
$$;
CREATE OR REPLACE FUNCTION public.sowrix_permission_snapshot()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE account_role text:=public.sowrix_access_role(); permitted boolean:=public.sowrix_secure_session_allowed();
BEGIN
 IF auth.uid() IS NULL OR account_role IS NULL THEN RAISE EXCEPTION 'Approved sign-in required' USING ERRCODE='42501'; END IF;
 -- Own role is available before MFA so enrollment can complete. No records or team data.
 RETURN jsonb_build_object('role',account_role,'version',10,'securityReady',true,'sessionAllowed',permitted,
 'mfaRequired',account_role<>'client','permissions',CASE WHEN permitted THEN coalesce((SELECT jsonb_agg(c.module_key) FROM public.sowrix_permission_catalog c WHERE public.sowrix_has_permission(c.module_key,'view')),'[]'::jsonb) ELSE '[]'::jsonb END,
 'actionPermissions',CASE WHEN permitted THEN coalesce((SELECT jsonb_object_agg(c.module_key,(SELECT jsonb_agg(a) FROM unnest(c.actions) a WHERE public.sowrix_has_permission(c.module_key,a))) FROM public.sowrix_permission_catalog c WHERE public.sowrix_has_permission(c.module_key,'view')),'{}'::jsonb) ELSE '{}'::jsonb END,
 'permissionScopes',CASE WHEN permitted THEN coalesce((SELECT jsonb_object_agg(g.module_key,g.row_scope) FROM public.sowrix_action_grants g WHERE g.user_id=auth.uid()),'{}'::jsonb) ELSE '{}'::jsonb END);
END $$;

-- Require the session on every private table, including tables with permissive policies.
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='public'
 -- Only tables owned by this audited SOWRIX schema; do not alter other apps in the project.
 AND tablename=ANY(ARRAY['attendance_records','audit_logs','blog_posts','clients','contact_enquiries','departments','employees','expenses','interviews','invoices','job_applications','jobs','leave_requests','notifications','payroll_records','portfolio_projects','projects','quotations','services','site_content','sowrix_access_changes','sowrix_access_modules','sowrix_access_revisions','sowrix_action_grants','sowrix_contact_limits','sowrix_contact_outbox','sowrix_invite_cooldowns','sowrix_module_access','sowrix_ui_records','support_tickets','task_comments','tasks']) LOOP
  EXECUTE format('DROP POLICY IF EXISTS sowrix_session_required ON public.%I',r.tablename);
  IF r.tablename IN ('services','portfolio_projects','blog_posts','jobs','site_content') THEN
   -- Existing publication policies control public reads. All mutations still need MFA.
   EXECUTE format('DROP POLICY IF EXISTS sowrix_session_insert ON public.%I',r.tablename);
   EXECUTE format('DROP POLICY IF EXISTS sowrix_session_update ON public.%I',r.tablename);
   EXECUTE format('DROP POLICY IF EXISTS sowrix_session_delete ON public.%I',r.tablename);
   EXECUTE format('CREATE POLICY sowrix_session_insert ON public.%I AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(public.sowrix_secure_session_allowed())',r.tablename);
   EXECUTE format('CREATE POLICY sowrix_session_update ON public.%I AS RESTRICTIVE FOR UPDATE TO authenticated USING(public.sowrix_secure_session_allowed()) WITH CHECK(public.sowrix_secure_session_allowed())',r.tablename);
   EXECUTE format('CREATE POLICY sowrix_session_delete ON public.%I AS RESTRICTIVE FOR DELETE TO authenticated USING(public.sowrix_secure_session_allowed())',r.tablename);
  ELSE
   EXECUTE format('CREATE POLICY sowrix_session_required ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING(public.sowrix_secure_session_allowed()) WITH CHECK(public.sowrix_secure_session_allowed())',r.tablename);
  END IF;
 END LOOP;
END $$;
DROP POLICY IF EXISTS sowrix_storage_session_required ON storage.objects;
CREATE POLICY sowrix_storage_session_required ON storage.objects AS RESTRICTIVE FOR ALL TO authenticated
 USING(bucket_id NOT IN ('sowrix-private','resumes') OR public.sowrix_secure_session_allowed())
 WITH CHECK(bucket_id NOT IN ('sowrix-private','resumes') OR public.sowrix_secure_session_allowed());
UPDATE storage.buckets SET public=false WHERE id IN ('sowrix-private','resumes');
REVOKE UPDATE,DELETE,TRUNCATE ON public.audit_logs FROM authenticated,anon;

CREATE OR REPLACE FUNCTION public.sowrix_project_scope(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_secure_session_allowed() AND EXISTS(SELECT 1 FROM public.projects p WHERE p.id=p_id AND (
 (public.sowrix_access_role()='project_manager' AND p.manager_id=auth.uid()) OR
 (public.sowrix_access_role()='employee' AND EXISTS(SELECT 1 FROM public.tasks t WHERE t.project_id=p.id AND t.assignee_id=auth.uid())) OR
 (public.sowrix_access_role()='client' AND public.sowrix_org_access(p.client_id,'general'))))
$$;
-- Keep staff scope expressions; extend client reads to active organization members.
DO $$ DECLARE r record; suffix text; BEGIN
 FOR r IN SELECT * FROM pg_policies WHERE schemaname='public' AND cmd='SELECT'
 AND tablename IN ('clients','invoices','support_tickets') AND policyname IN ('sowrix_v3_select_allow','sowrix_v3_select_scope') LOOP
  suffix:=CASE r.tablename WHEN 'clients' THEN 'public.sowrix_org_access(id,''general'') AND public.sowrix_has_permission(''clients'',''view'')'
   WHEN 'invoices' THEN 'public.sowrix_org_access(client_id,''billing'') AND status<>''draft'' AND public.sowrix_has_permission(''invoices'',''view'')'
   ELSE 'public.sowrix_org_access(client_id,''tickets'') AND public.sowrix_has_permission(''tickets'',''view'')' END;
  -- Marked expressions are not appended again on rerun.
  IF position('sowrix_org_access' in r.qual)=0 THEN EXECUTE format('ALTER POLICY %I ON public.%I USING ((%s) OR (%s))',r.policyname,r.tablename,r.qual,suffix); END IF;
 END LOOP;
END $$;
DROP POLICY IF EXISTS sowrix_client_active_scope ON public.clients;
CREATE POLICY sowrix_client_active_scope ON public.clients AS RESTRICTIVE FOR SELECT TO authenticated
 USING(public.sowrix_access_role()<>'client' OR public.sowrix_org_access(id,'general'));
DROP POLICY IF EXISTS sowrix_client_active_scope ON public.invoices;
CREATE POLICY sowrix_client_active_scope ON public.invoices AS RESTRICTIVE FOR SELECT TO authenticated
 USING(public.sowrix_access_role()<>'client' OR (status<>'draft' AND public.sowrix_org_access(client_id,'billing')));
DROP POLICY IF EXISTS sowrix_client_ticket_scope ON public.support_tickets;
CREATE POLICY sowrix_client_ticket_scope ON public.support_tickets AS RESTRICTIVE FOR ALL TO authenticated
 USING(public.sowrix_access_role()<>'client' OR (public.sowrix_org_access(client_id,'tickets') OR (client_id IS NULL AND requester_id=auth.uid() AND public.sowrix_client_active_owned(NULL))))
 WITH CHECK(public.sowrix_access_role()<>'client' OR (requester_id=auth.uid() AND public.sowrix_org_access(client_id,'tickets')));
-- New client tickets must identify one of the client's active organizations.
CREATE OR REPLACE FUNCTION public.sowrix_ticket_organization_default()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE org_count integer;
BEGIN
 IF public.sowrix_access_role()='client' AND NEW.client_id IS NULL THEN
  SELECT count(*),min(m.organization_id::text)::uuid INTO org_count,NEW.client_id
   FROM public.sowrix_org_memberships m JOIN public.clients c ON c.id=m.organization_id
   WHERE m.user_id=auth.uid() AND m.status='active' AND c.status='active';
  IF org_count<>1 THEN RAISE EXCEPTION 'Select one active organization for this ticket' USING ERRCODE='22023'; END IF;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS sowrix_ticket_organization_default ON public.support_tickets;
CREATE TRIGGER sowrix_ticket_organization_default BEFORE INSERT ON public.support_tickets FOR EACH ROW EXECUTE FUNCTION public.sowrix_ticket_organization_default();

-- Composite references prevent a child from pointing at a different organization's project.
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_projects_tenant_id ON public.projects(client_id,id);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.invoices'::regclass AND conname='sowrix_invoice_project_organization') THEN
  ALTER TABLE public.invoices ADD CONSTRAINT sowrix_invoice_project_organization FOREIGN KEY(client_id,project_id) REFERENCES public.projects(client_id,id);
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.quotations'::regclass AND conname='sowrix_quote_project_organization') THEN
  ALTER TABLE public.quotations ADD CONSTRAINT sowrix_quote_project_organization FOREIGN KEY(client_id,project_id) REFERENCES public.projects(client_id,id);
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_check_project_organization()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.project_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.projects p WHERE p.id=NEW.project_id AND p.client_id IS NOT DISTINCT FROM NEW.client_id) THEN
  RAISE EXCEPTION 'Project organization mismatch' USING ERRCODE='23514';
 END IF; RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS sowrix_invoice_org_check ON public.invoices;
CREATE TRIGGER sowrix_invoice_org_check BEFORE INSERT OR UPDATE OF client_id,project_id ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.sowrix_check_project_organization();
DROP TRIGGER IF EXISTS sowrix_quote_org_check ON public.quotations;
CREATE TRIGGER sowrix_quote_org_check BEFORE INSERT OR UPDATE OF client_id,project_id ON public.quotations FOR EACH ROW EXECUTE FUNCTION public.sowrix_check_project_organization();

-- Internal notes are never returned in a tenant-readable source row. Companion
-- records preserve all existing note text and staff-only editing through old forms.
DO $$ DECLARE t text; organization_expression text; BEGIN
 FOREACH t IN ARRAY ARRAY['clients','invoices','quotations'] LOOP
  EXECUTE format('CREATE TABLE IF NOT EXISTS public.%I(record_id uuid PRIMARY KEY REFERENCES public.%I(id) ON DELETE CASCADE,organization_id uuid REFERENCES public.clients(id),notes text NOT NULL,updated_at timestamptz NOT NULL DEFAULT now())',t||'_private_notes',t);
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t||'_private_notes');
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t||'_private_notes');
  EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t||'_private_notes');
  EXECUTE format('DROP POLICY IF EXISTS staff_notes ON public.%I',t||'_private_notes');
  EXECUTE format('CREATE POLICY staff_notes ON public.%I FOR SELECT TO authenticated USING(public.sowrix_access_role()<>''client'' AND public.sowrix_has_permission(%L,''view'') AND EXISTS(SELECT 1 FROM public.%I p WHERE p.id=record_id))',t||'_private_notes',t,t);
  organization_expression:=CASE WHEN t='clients' THEN 'id' ELSE 'client_id' END;
  EXECUTE format('INSERT INTO public.%I(record_id,organization_id,notes) SELECT id,%s,notes FROM public.%I WHERE notes IS NOT NULL ON CONFLICT(record_id) DO UPDATE SET notes=excluded.notes,organization_id=excluded.organization_id,updated_at=now()',t||'_private_notes',organization_expression,t);
  EXECUTE format('UPDATE public.%I SET notes=NULL WHERE notes IS NOT NULL',t);
 END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_keep_notes_private()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE org uuid;
BEGIN
 IF TG_TABLE_NAME NOT IN ('clients','invoices','quotations') THEN RAISE EXCEPTION 'Unsupported private-note source'; END IF;
 org:=CASE WHEN TG_TABLE_NAME='clients' THEN NEW.id ELSE (to_jsonb(NEW)->>'client_id')::uuid END;
 IF NEW.notes IS NOT NULL THEN
  EXECUTE format('INSERT INTO public.%I(record_id,organization_id,notes) VALUES($1,$2,$3) ON CONFLICT(record_id) DO UPDATE SET notes=excluded.notes,organization_id=excluded.organization_id,updated_at=now()',TG_TABLE_NAME||'_private_notes') USING NEW.id,org,NEW.notes;
  EXECUTE format('UPDATE public.%I SET notes=NULL WHERE id=$1',TG_TABLE_NAME) USING NEW.id;
 ELSIF TG_OP='UPDATE' THEN
  EXECUTE format('UPDATE public.%I SET organization_id=$1 WHERE record_id=$2',TG_TABLE_NAME||'_private_notes') USING org,NEW.id;
 END IF; RETURN NEW;
END $$;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['clients','invoices','quotations'] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS sowrix_notes_private ON public.%I',t);
  EXECUTE format('CREATE TRIGGER sowrix_notes_private AFTER INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.sowrix_keep_notes_private()',t);
 END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_private_notes(p_module text,p_ids uuid[])
RETURNS TABLE(record_id uuid,notes text) LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $$
BEGIN
 PERFORM public.sowrix_require_secure_session();
 IF p_module NOT IN ('clients','invoices','quotations') OR cardinality(p_ids)>100 OR public.sowrix_access_role()='client' OR NOT public.sowrix_has_permission(p_module,'view') THEN RAISE EXCEPTION 'Private notes unavailable' USING ERRCODE='42501'; END IF;
 RETURN QUERY EXECUTE format('SELECT n.record_id,n.notes FROM public.%I n JOIN public.%I p ON p.id=n.record_id WHERE n.record_id=ANY($1)',p_module||'_private_notes',p_module) USING p_ids;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_private_notes(text,uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_private_notes(text,uuid[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_set_org_member(p_organization_id uuid,p_user_id uuid,p_member_role text,p_status text,p_billing_access boolean,p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE existing_role text;
BEGIN
 PERFORM public.sowrix_require_secure_session(true);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Administrator required' USING ERRCODE='42501'; END IF;
 IF p_reason IS NULL OR p_member_role IS NULL OR p_status IS NULL OR p_billing_access IS NULL OR p_member_role NOT IN ('owner','member') OR p_status NOT IN ('active','suspended') OR length(btrim(p_reason)) NOT BETWEEN 8 AND 500 THEN RAISE EXCEPTION 'Invalid membership change or reason' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM public.clients c WHERE c.id=p_organization_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Organization not found' USING ERRCODE='22023'; END IF;
 SELECT r.role::text INTO existing_role FROM public.user_roles r WHERE r.user_id=p_user_id;
 IF existing_role IS DISTINCT FROM 'client' THEN RAISE EXCEPTION 'A provisioned client account is required; staff accounts cannot be linked as client members' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM public.sowrix_org_memberships WHERE organization_id=p_organization_id AND user_id=p_user_id AND member_role='owner' AND status='active')
 AND (p_status<>'active' OR p_member_role<>'owner') AND NOT EXISTS(SELECT 1 FROM public.sowrix_org_memberships WHERE organization_id=p_organization_id AND user_id<>p_user_id AND member_role='owner' AND status='active') THEN
  RAISE EXCEPTION 'Assign another active owner before changing the last owner' USING ERRCODE='23514';
 END IF;
 INSERT INTO public.sowrix_org_memberships(organization_id,user_id,member_role,status,billing_access) VALUES(p_organization_id,p_user_id,p_member_role,p_status,p_billing_access)
 ON CONFLICT(organization_id,user_id) DO UPDATE SET member_role=excluded.member_role,status=excluded.status,billing_access=excluded.billing_access,updated_at=now();
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details) VALUES(auth.uid(),'organization_membership_changed','organization',p_organization_id::text,jsonb_build_object('user_id',p_user_id,'role',p_member_role,'status',p_status,'billing',p_billing_access,'reason',btrim(p_reason)));
END $$;
REVOKE ALL ON FUNCTION public.sowrix_set_org_member(uuid,uuid,text,text,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_set_org_member(uuid,uuid,text,text,boolean,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_set_account_enabled(p_user_id uuid,p_enabled boolean,p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.sowrix_require_secure_session(true);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Administrator required' USING ERRCODE='42501'; END IF;
 IF p_user_id=auth.uid() THEN RAISE EXCEPTION 'Another administrator must change your account access' USING ERRCODE='23514'; END IF;
 IF p_enabled IS NULL OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 8 AND 500 THEN RAISE EXCEPTION 'A reason of 8 to 500 characters is required' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM public.user_roles WHERE user_id=p_user_id AND role::text='super_admin') AND public.sowrix_access_role()<>'super_admin' THEN RAISE EXCEPTION 'Super administrator required' USING ERRCODE='42501'; END IF;
 INSERT INTO public.sowrix_account_security(user_id,disabled_at,reauth_after,reason,updated_by) VALUES(p_user_id,CASE WHEN p_enabled THEN NULL ELSE now() END,now(),btrim(p_reason),auth.uid())
 ON CONFLICT(user_id) DO UPDATE SET disabled_at=excluded.disabled_at,reauth_after=excluded.reauth_after,reason=excluded.reason,updated_by=excluded.updated_by,updated_at=now();
 -- The Auth provider owns refresh sessions. Application access is denied immediately;
 -- re-enabling requires a session created after this change, not a refreshed old token.
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details) VALUES(auth.uid(),CASE WHEN p_enabled THEN 'account_enabled' ELSE 'account_suspended' END,'account',p_user_id::text,jsonb_build_object('reason',btrim(p_reason)));
END $$;
REVOKE ALL ON FUNCTION public.sowrix_set_account_enabled(uuid,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_set_account_enabled(uuid,boolean,text) TO authenticated;

-- Updated client status and quotation functions use membership, not a single login field.
CREATE OR REPLACE FUNCTION public.sowrix_client_login_status()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR public.sowrix_access_role()<>'client' THEN RAISE EXCEPTION 'Client sign-in required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('linked',public.sowrix_secure_session_allowed(),'organizations',CASE WHEN public.sowrix_secure_session_allowed() THEN coalesce((SELECT jsonb_agg(c.organization_name) FROM public.clients c WHERE public.sowrix_org_access(c.id,'general')),'[]'::jsonb) ELSE '[]'::jsonb END);
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ui_quotes()
RETURNS SETOF public.quotations LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT q.* FROM public.quotations q WHERE public.sowrix_org_access(q.client_id,'billing') AND public.sowrix_has_permission('client_quotes','view') AND q.status<>'draft'
$$;
-- GENERATED RPC GUARDS BELOW
-- Verified active session guard: sowrix_attendance_people
CREATE OR REPLACE FUNCTION public.sowrix_attendance_people(p_user_ids uuid[])
 RETURNS TABLE(user_id uuid, employee_code text, full_name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  target uuid;
  role_name text := public.sowrix_access_role();
  profile jsonb;
  auth_name text;
  code text;
  profile_table text;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
  IF auth.uid() IS NULL OR role_name NOT IN ('admin','super_admin','hr','hr_manager','hr_staff','employee') THEN
    RAISE EXCEPTION 'Attendance access required' USING ERRCODE='42501';
  END IF;
  IF NOT public.sowrix_has_module_access('attendance') THEN
    RAISE EXCEPTION 'Attendance module access is not assigned' USING ERRCODE='42501';
  END IF;
  IF coalesce(cardinality(p_user_ids),0)>500 THEN
    RAISE EXCEPTION 'Request at most 500 employees' USING ERRCODE='22023';
  END IF;
  FOR target IN
    SELECT DISTINCT u.requested_id FROM unnest(coalesce(p_user_ids,'{}'::uuid[])) AS u(requested_id)
    WHERE u.requested_id IS NOT NULL
  LOOP
    -- Employees may resolve only their own attendance profile.
    IF role_name='employee' AND target<>auth.uid() THEN CONTINUE; END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.attendance_records a
      WHERE a.employee_user_id=target
        AND (role_name<>'employee' OR a.employee_user_id=auth.uid())
    ) THEN CONTINUE; END IF;

    SELECT u.raw_user_meta_data INTO profile
    FROM auth.users u WHERE u.id=target;
    auth_name := coalesce(nullif(btrim(profile->>'full_name'),''),
                          nullif(btrim(profile->>'name'),''),
                          nullif(btrim(profile->>'display_name'),''));

    -- Re-read directory profile because auth metadata is intentionally private.
    profile := '{}'::jsonb;
    FOREACH profile_table IN ARRAY ARRAY['employees','employee_profiles'] LOOP
      IF to_regclass('public.'||profile_table) IS NOT NULL THEN
        EXECUTE format(
          $query$SELECT to_jsonb(e) FROM public.%I e WHERE to_jsonb(e)->>'user_id'=$1 AND (nullif(btrim(to_jsonb(e)->>'full_name'),'') IS NOT NULL OR nullif(btrim(to_jsonb(e)->>'employee_code'),'') IS NOT NULL OR nullif(btrim(to_jsonb(e)->>'name'),'') IS NOT NULL) LIMIT 1$query$,
          profile_table
        ) INTO profile USING target::text;
        IF profile IS NOT NULL THEN EXIT; END IF;
      END IF;
    END LOOP;
    code := coalesce(nullif(btrim(profile->>'employee_code'),''),
                     nullif(btrim(profile->>'employee_id'),''),
                     nullif(btrim(profile->>'staff_id'),''));
    full_name := coalesce(nullif(btrim(profile->>'full_name'),''),
                          nullif(btrim(profile->>'display_name'),''),
                          nullif(btrim(profile->>'name'),''),
                          auth_name,
                          'Name not set');
    user_id := target;
    employee_code := coalesce(code,'—');
    RETURN NEXT;
  END LOOP;
END;
$function$;

-- Verified active session guard: sowrix_client_account_picker
CREATE OR REPLACE FUNCTION public.sowrix_client_account_picker()
 RETURNS TABLE(user_id uuid, email text, full_name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
  IF auth.uid() IS NULL OR NOT public.sowrix_access_admin() OR NOT public.sowrix_has_module_access('clients') THEN
    RAISE EXCEPTION 'Client account assignment access required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT u.id,u.email,coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'),''),nullif(btrim(u.raw_user_meta_data->>'name'),''),u.email)
    FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id
    WHERE lower(r.role::text)='client' ORDER BY u.email LIMIT 500;
END;
$function$;

-- Verified active session guard: sowrix_employee_picker
CREATE OR REPLACE FUNCTION public.sowrix_employee_picker()
 RETURNS TABLE(user_id uuid, employee_code text, full_name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF auth.uid() IS NULL OR (NOT public.sowrix_access_admin() AND NOT EXISTS(
  SELECT 1 FROM public.sowrix_permission_catalog c
  WHERE c.module_key IN ('employees','tasks','projects','interviews','leaves','payroll','tickets','documents','onboarding')
  AND (public.sowrix_has_permission(c.module_key,'create') OR public.sowrix_has_permission(c.module_key,'edit'))
 )) THEN RAISE EXCEPTION 'Employee assignment access required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT e.user_id,coalesce(i.value->>'employee_code','—'),coalesce(i.value->>'full_name','Name not set')
 FROM public.employees e
 CROSS JOIN LATERAL (SELECT public.sowrix_identity_internal(e.user_id) AS value) i
 WHERE e.user_id IS NOT NULL AND e.employment_status<>'terminated'
 ORDER BY i.value->>'full_name',e.user_id LIMIT 500;
END $function$;

-- Verified active session guard: sowrix_list_team_access
CREATE OR REPLACE FUNCTION public.sowrix_list_team_access()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x.record ORDER BY x.email) FROM (
  SELECT u.email,jsonb_build_object('user_id',u.id,'email',u.email,
   'full_name',coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name',''),
   'role',lower(r.role::text),'modules',coalesce((SELECT jsonb_agg(a.module_key ORDER BY a.module_key)
    FROM public.sowrix_module_access a JOIN public.sowrix_access_modules m USING(module_key)
    WHERE a.user_id=u.id AND lower(r.role::text)=ANY(m.allowed_roles)),'[]'::jsonb)) record
  FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id
  WHERE lower(r.role::text) IN ('hr','hr_manager','hr_staff','employee')
 ) x),'[]'::jsonb);
END $function$;

-- Verified active session guard: sowrix_my_identity
CREATE OR REPLACE FUNCTION public.sowrix_my_identity()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF auth.uid() IS NULL OR public.sowrix_access_role() IS NULL THEN
  RAISE EXCEPTION 'Approved sign-in required' USING ERRCODE='42501';
 END IF;
 -- No caller-supplied user ID: this endpoint can only return the current account.
 RETURN public.sowrix_identity_internal(auth.uid());
END $function$;

-- Verified active session guard: sowrix_people_display
CREATE OR REPLACE FUNCTION public.sowrix_people_display(p_user_ids uuid[])
 RETURNS TABLE(user_id uuid, employee_code text, full_name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 see_team boolean;
 target uuid;
 directory_record jsonb;
 legacy_record jsonb;
 metadata_record jsonb;
 resolved_name text;
 resolved_code text;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 IF coalesce(cardinality(p_user_ids),0)>500 THEN
  RAISE EXCEPTION 'Request at most 500 employees' USING ERRCODE='22023';
 END IF;
 -- Keep the existing v4 module, role and row-scope checks.
 see_team:=public.sowrix_access_admin() OR EXISTS(
  SELECT 1 FROM public.sowrix_permission_catalog c
  WHERE c.module_key IN ('employees','attendance','leaves','payroll','interviews')
  AND public.sowrix_has_permission(c.module_key,'view')
  AND (public.sowrix_access_role() IN ('hr','hr_staff','hr_manager')
       OR public.sowrix_wide_access(c.module_key,'view')));
 IF NOT see_team AND NOT EXISTS(
  SELECT 1 FROM public.sowrix_permission_catalog c
  WHERE c.module_key IN ('attendance','leaves','payroll','interviews')
  AND public.sowrix_has_permission(c.module_key,'view')
 ) THEN RAISE EXCEPTION 'People module access required' USING ERRCODE='42501'; END IF;

 FOR target IN SELECT DISTINCT requested.id
  FROM unnest(coalesce(p_user_ids,'{}'::uuid[])) requested(id)
  WHERE requested.id IS NOT NULL
 LOOP
  IF NOT see_team AND target<>auth.uid() THEN CONTINUE; END IF;
  directory_record:=NULL; legacy_record:=NULL; metadata_record:=NULL;
  resolved_name:=NULL; resolved_code:=NULL;
  SELECT to_jsonb(e) INTO directory_record FROM public.employees e
  WHERE e.user_id=target ORDER BY e.created_at DESC,e.id LIMIT 1;
  -- Legacy field aliases are read without requiring schema changes.
  IF to_regclass('public.employee_profiles') IS NOT NULL THEN
   EXECUTE $legacy$
    SELECT to_jsonb(e) FROM public.employee_profiles e
    WHERE coalesce(nullif(to_jsonb(e)->>'user_id',''),
                   nullif(to_jsonb(e)->>'auth_user_id',''))=$1
    ORDER BY to_jsonb(e)->>'updated_at' DESC NULLS LAST,
             to_jsonb(e)->>'created_at' DESC NULLS LAST,to_jsonb(e)->>'id'
    LIMIT 1
   $legacy$ INTO legacy_record USING target::text;
  END IF;
  -- Auth fallback is limited to known profiles or users referenced by staff records.
  IF directory_record IS NULL AND legacy_record IS NULL
   AND NOT EXISTS(SELECT 1 FROM public.attendance_records a WHERE a.employee_user_id=target)
   AND NOT EXISTS(SELECT 1 FROM public.leave_requests l WHERE l.employee_user_id=target)
   AND NOT EXISTS(SELECT 1 FROM public.payroll_records p WHERE p.employee_user_id=target)
   AND NOT EXISTS(SELECT 1 FROM public.interviews i WHERE i.interviewer_id=target)
  THEN CONTINUE; END IF;
  SELECT u.raw_user_meta_data INTO metadata_record FROM auth.users u WHERE u.id=target;
  -- Resolve each field separately: a current name must not hide an older ID.
  SELECT btrim(v.value) INTO resolved_name
  FROM unnest(ARRAY[
   directory_record->>'full_name',directory_record->>'display_name',directory_record->>'name',
   legacy_record->>'full_name',legacy_record->>'display_name',legacy_record->>'name',
   metadata_record->>'full_name',metadata_record->>'display_name',metadata_record->>'name'
  ]) WITH ORDINALITY v(value,priority)
  WHERE nullif(btrim(v.value),'') IS NOT NULL
   AND lower(btrim(v.value)) NOT IN ('name not set','not set','unknown','unassigned','null','undefined','—','-')
  ORDER BY v.priority LIMIT 1;
  SELECT btrim(v.value) INTO resolved_code
  FROM unnest(ARRAY[
   directory_record->>'employee_code',directory_record->>'employee_id',directory_record->>'staff_id',
   legacy_record->>'employee_code',legacy_record->>'employee_id',legacy_record->>'staff_id',
   metadata_record->>'employee_code',metadata_record->>'employee_id',metadata_record->>'staff_id'
  ]) WITH ORDINALITY v(value,priority)
  WHERE nullif(btrim(v.value),'') IS NOT NULL
   AND lower(btrim(v.value)) NOT IN ('name not set','not set','unknown','unassigned','null','undefined','—','-')
  ORDER BY v.priority LIMIT 1;
  user_id:=target; employee_code:=resolved_code; full_name:=resolved_name;
  RETURN NEXT;
 END LOOP;
END
$function$;

-- Verified active session guard: sowrix_release_health
CREATE OR REPLACE FUNCTION public.sowrix_release_health()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF auth.uid() IS NULL OR NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('release',10,'unlinked_clients',(SELECT count(*) FROM public.clients WHERE status='active' AND auth_user_id IS NULL),
  'mail_pending',(SELECT count(*) FROM public.sowrix_contact_outbox WHERE state IN ('pending','sending')),
  'mail_failed',(SELECT count(*) FROM public.sowrix_contact_outbox WHERE state='failed'));
END $function$;

-- Verified active session guard: sowrix_save_team_access
CREATE OR REPLACE FUNCTION public.sowrix_save_team_access(p_user_id uuid, p_role text, p_grants jsonb, p_reason text, p_confirm_broad boolean, p_expected_revision bigint, p_department text DEFAULT NULL::text, p_designation text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE actor_role text; old_role text; v bigint; g jsonb; c public.sowrix_permission_catalog; acts text[]; scope text; broad boolean:=false; target_name text;
BEGIN
 PERFORM public.sowrix_require_secure_session(true);
 -- Serialize role changes, then verify current database roles (not JWT claims).
 PERFORM pg_advisory_xact_lock(193740621);
 actor_role:=public.sowrix_access_role();
 IF actor_role NOT IN ('admin','super_admin') OR actor_role IS NULL THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 IF p_user_id IS NULL OR p_user_id=auth.uid() THEN RAISE EXCEPTION 'Ask another administrator to change your own access' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM auth.users WHERE id=p_user_id FOR UPDATE;
 SELECT role::text INTO old_role FROM public.user_roles WHERE user_id=p_user_id;
 IF old_role IS NULL THEN RAISE EXCEPTION 'Select an existing provisioned account'; END IF;
 IF old_role='super_admin' OR p_role='super_admin' THEN RAISE EXCEPTION 'Super Admin changes require the project owner' USING ERRCODE='42501'; END IF;
 IF (old_role='admin' OR p_role='admin') AND actor_role<>'super_admin' THEN RAISE EXCEPTION 'Only Super Admin can change Administrator access' USING ERRCODE='42501'; END IF;
 IF p_role IS NULL OR p_role NOT IN ('admin','hr_staff','hr_manager','employee','project_manager','client') THEN RAISE EXCEPTION 'Invalid account role'; END IF;
 IF length(btrim(coalesce(p_reason,'')))<8 OR length(p_reason)>1000 THEN RAISE EXCEPTION 'Enter an access-change reason (8–1000 characters)'; END IF;
 IF length(coalesce(p_department,''))>100 OR length(coalesce(p_designation,''))>200 THEN RAISE EXCEPTION 'Department or designation is too long'; END IF;
 INSERT INTO public.sowrix_access_revisions(user_id) VALUES(p_user_id) ON CONFLICT DO NOTHING;
 SELECT revision INTO v FROM public.sowrix_access_revisions WHERE user_id=p_user_id FOR UPDATE;
 IF p_expected_revision IS NULL OR p_expected_revision<>v THEN RAISE EXCEPTION 'Access changed in another session. Refresh and review before saving.' USING ERRCODE='40001'; END IF;
 IF jsonb_typeof(p_grants) IS DISTINCT FROM 'array' OR jsonb_array_length(p_grants)>50 THEN RAISE EXCEPTION 'Invalid permission list'; END IF;
 IF (SELECT count(*) FROM jsonb_array_elements(p_grants))<>(SELECT count(DISTINCT item->>'module') FROM jsonb_array_elements(p_grants) item) THEN RAISE EXCEPTION 'Duplicate or missing module'; END IF;
 FOR g IN SELECT value FROM jsonb_array_elements(p_grants) LOOP
  SELECT * INTO c FROM public.sowrix_permission_catalog WHERE module_key=g->>'module';
  IF c.module_key IS NULL OR (c.admin_only AND p_role<>'admin') THEN RAISE EXCEPTION 'Module is restricted to administrators'; END IF;
  IF jsonb_typeof(g->'actions') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid actions'; END IF;
  SELECT coalesce(array_agg(DISTINCT a),'{}') INTO acts FROM jsonb_array_elements_text(g->'actions') a;
  scope:=coalesce(g->>'scope','standard');
  IF NOT ('view'=ANY(acts)) OR NOT (acts<@c.actions) OR array_position(acts,NULL) IS NOT NULL THEN RAISE EXCEPTION 'Choose valid actions including View'; END IF;
  IF scope NOT IN ('standard','all') OR (scope='all' AND (NOT c.allow_wide OR p_role='client')) THEN RAISE EXCEPTION 'Record scope is not available for this module/account'; END IF;
  IF p_role<>'admin' AND c.module_key='attendance' AND acts<>'{view}'::text[] THEN RAISE EXCEPTION 'Attendance changes are Administrator-only'; END IF;
  IF p_role NOT IN ('admin','hr_staff','hr_manager') AND c.module_key='employees' AND 'create'=ANY(acts) THEN RAISE EXCEPTION 'Only authorized HR/Administrators can invite employees'; END IF;
  IF p_role='client' AND c.module_key NOT IN ('clients','projects','invoices','quotations','tickets','notifications','client_quotes') THEN RAISE EXCEPTION 'Choose client-facing modules only'; END IF;
  IF scope='all' THEN broad:=true; END IF;
 END LOOP;
 IF (broad OR p_role='admin') AND p_confirm_broad IS DISTINCT FROM true THEN RAISE EXCEPTION 'Confirm broader access explicitly'; END IF;
 DELETE FROM public.sowrix_action_grants WHERE user_id=p_user_id;
 DELETE FROM public.sowrix_module_access WHERE user_id=p_user_id;
 FOR g IN SELECT value FROM jsonb_array_elements(p_grants) LOOP
  SELECT array_agg(DISTINCT a) INTO acts FROM jsonb_array_elements_text(g->'actions') a;
  INSERT INTO public.sowrix_action_grants(user_id,module_key,actions,row_scope,granted_by) VALUES(p_user_id,g->>'module',acts,coalesce(g->>'scope','standard'),auth.uid());
  INSERT INTO public.sowrix_module_access(user_id,module_key,granted_by) VALUES(p_user_id,g->>'module',auth.uid());
 END LOOP;
 -- Casting preserves compatibility with an existing enum-based role column.
 EXECUTE format('UPDATE public.user_roles SET role=%L WHERE user_id=$1',p_role) USING p_user_id;
 UPDATE public.employees SET department=coalesce(p_department,department),designation=coalesce(p_designation,designation),updated_at=now() WHERE user_id=p_user_id;
 UPDATE public.sowrix_access_revisions SET revision=v+1 WHERE user_id=p_user_id;
 SELECT coalesce(e.full_name,u.email,'Team member') INTO target_name FROM auth.users u LEFT JOIN public.employees e ON e.user_id=u.id WHERE u.id=p_user_id;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details) VALUES(auth.uid(),'access_changed_v4','team_access',p_user_id::text,jsonb_build_object('target',target_name,'previous_role',old_role,'role',p_role,'reason',btrim(p_reason),'grants',p_grants,'broad_confirmed',p_confirm_broad,'revision',v+1));
 RETURN jsonb_build_object('saved',true,'revision',v+1);
END $function$;

-- Verified active session guard: sowrix_self_action
CREATE OR REPLACE FUNCTION public.sowrix_self_action(p_action text, p_id uuid DEFAULT NULL::uuid, p_value text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE result_id uuid; uid uuid:=auth.uid(); r text:=public.sowrix_access_role(); today date:=(now() AT TIME ZONE 'Asia/Kolkata')::date; clock time:=(now() AT TIME ZONE 'Asia/Kolkata')::time;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF uid IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 IF p_action='task' THEN
  IF r<>'employee' OR NOT public.sowrix_has_permission('tasks','edit') THEN RAISE EXCEPTION 'Task access required' USING ERRCODE='42501'; END IF;
  IF p_value NOT IN ('in_progress','done') OR p_value IS NULL THEN RAISE EXCEPTION 'Invalid task status'; END IF;
  UPDATE public.tasks SET status=p_value,completed_at=CASE WHEN p_value='done' THEN now() ELSE NULL END,updated_at=now()
   WHERE id=p_id AND assignee_id=uid AND status NOT IN ('cancelled') RETURNING id INTO result_id;
 ELSIF p_action='notification' THEN
  IF NOT public.sowrix_has_permission('notifications','edit') THEN RAISE EXCEPTION 'Notifications access required' USING ERRCODE='42501'; END IF;
  UPDATE public.notifications SET read_at=now(),updated_at=now() WHERE id=p_id AND user_id=uid RETURNING id INTO result_id;
 ELSIF p_action IN ('check_in','check_out') THEN
  IF r<>'employee' OR NOT public.sowrix_has_module_access('attendance') THEN RAISE EXCEPTION 'Attendance access required' USING ERRCODE='42501'; END IF;
  IF p_action='check_in' THEN
   INSERT INTO public.attendance_records(employee_user_id,attendance_date,check_in,status)
   VALUES(uid,today,clock,'present') ON CONFLICT(employee_user_id,attendance_date) DO NOTHING RETURNING id INTO result_id;
   IF result_id IS NULL THEN RAISE EXCEPTION 'You have already checked in today'; END IF;
  ELSE
   UPDATE public.attendance_records SET check_out=clock,updated_at=now()
   WHERE employee_user_id=uid AND attendance_date=today AND check_in IS NOT NULL AND check_out IS NULL RETURNING id INTO result_id;
  END IF;
 ELSE RAISE EXCEPTION 'Unknown action';
 END IF;
 IF result_id IS NULL THEN RAISE EXCEPTION 'No accessible record was updated. Check in first or refresh your records.' USING ERRCODE='42501'; END IF;
 RETURN result_id;
END $function$;

-- Verified active session guard: sowrix_set_module_access
CREATE OR REPLACE FUNCTION public.sowrix_set_module_access(p_user_id uuid, p_modules text[])
 RETURNS text[]
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ BEGIN
 PERFORM public.sowrix_require_secure_session(true); RAISE EXCEPTION 'Use the updated Team Access screen to save role and action permissions'; END $function$;

-- Verified active session guard: sowrix_team_access_v4
CREATE OR REPLACE FUNCTION public.sowrix_team_access_v4()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('people',coalesce((SELECT jsonb_agg(x.row ORDER BY x.email) FROM (
  SELECT u.email,jsonb_build_object('user_id',u.id,'email',u.email,
   'full_name',coalesce(i.value->>'full_name',''),'employee_code',coalesce(i.value->>'employee_code',''),
   'department',coalesce(i.value->>'department',''),'designation',coalesce(i.value->>'designation',''),
   'role',r.role::text,'revision',coalesce(v.revision,0),
   'grants',coalesce((SELECT jsonb_agg(jsonb_build_object('module',g.module_key,'actions',g.actions,'scope',g.row_scope)) FROM public.sowrix_action_grants g WHERE g.user_id=u.id),'[]'::jsonb)) row
  FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id
  LEFT JOIN public.sowrix_access_revisions v ON v.user_id=u.id
  CROSS JOIN LATERAL (SELECT public.sowrix_identity_internal(u.id) AS value) i
 ) x),'[]'::jsonb),
 'catalog',(SELECT jsonb_agg(to_jsonb(c) ORDER BY c.label) FROM public.sowrix_permission_catalog c),
 'history',coalesce((SELECT jsonb_agg(to_jsonb(z)) FROM (
  SELECT a.created_at,coalesce(nullif(public.sowrix_identity_internal(a.actor_id)->>'full_name',''),u.email,'Administrator') actor,a.details
  FROM public.audit_logs a LEFT JOIN auth.users u ON u.id=a.actor_id
  WHERE a.action='access_changed_v4' ORDER BY a.created_at DESC LIMIT 30
 ) z),'[]'::jsonb));
END $function$;

-- Verified active session guard: sowrix_ui_archive
CREATE OR REPLACE FUNCTION public.sowrix_ui_archive(p_table text, p_id uuid, p_restore boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE prior text; m text; rec public.sowrix_ui_records;
BEGIN
 PERFORM public.sowrix_require_secure_session(true);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin access required'; END IF;
 m=CASE p_table WHEN 'clients' THEN 'clients' WHEN 'projects' THEN 'projects' WHEN 'jobs' THEN 'jobs' WHEN 'blog_posts' THEN 'blog' WHEN 'portfolio_projects' THEN 'portfolio' WHEN 'services' THEN 'services' WHEN 'contact_enquiries' THEN 'enquiries' END;
 IF m IS NULL THEN RAISE EXCEPTION 'This record type cannot be archived'; END IF;
 EXECUTE format('SELECT status FROM public.%I WHERE id=$1 FOR UPDATE',p_table) INTO prior USING p_id;
 IF prior IS NULL THEN RAISE EXCEPTION 'Record not found'; END IF;
 IF p_restore THEN
  SELECT * INTO rec FROM public.sowrix_ui_records WHERE kind='archive' AND payload->>'table'=p_table AND payload->>'record_id'=p_id::text AND status='active' ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF rec.id IS NULL OR prior<>'archived' THEN RAISE EXCEPTION 'No restorable archive'; END IF;
  EXECUTE format('UPDATE public.%I SET status=$1,updated_at=now() WHERE id=$2',p_table) USING rec.payload->>'previous_status',p_id;
  UPDATE public.sowrix_ui_records SET status='restored' WHERE id=rec.id;
 ELSE
  IF prior='archived' THEN RAISE EXCEPTION 'Record is already archived'; END IF;
  EXECUTE format('UPDATE public.%I SET status=$1,updated_at=now() WHERE id=$2',p_table) USING 'archived',p_id;
  INSERT INTO public.sowrix_ui_records(kind,owner_id,title,payload) VALUES('archive',auth.uid(),m,jsonb_build_object('table',p_table,'record_id',p_id,'previous_status',prior));
 END IF;
END $function$;

-- Verified active session guard: sowrix_ui_invitations
CREATE OR REPLACE FUNCTION public.sowrix_ui_invitations()
 RETURNS TABLE(employee_code text, full_name text, email text, department text, designation text, invited_at timestamp with time zone, activation_status text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT (public.sowrix_access_role() IN ('admin','super_admin','hr','hr_manager','hr_staff') AND public.sowrix_has_module_access('employees')) THEN RAISE EXCEPTION 'Employee administration access required'; END IF;
 RETURN QUERY SELECT e.employee_code,e.full_name,e.email,e.department,e.designation,u.invited_at,
 CASE WHEN u.id IS NULL THEN 'Not linked' WHEN u.encrypted_password IS NOT NULL AND u.encrypted_password<>'' AND u.email_confirmed_at IS NOT NULL THEN 'Account activated' ELSE 'Pending' END
 FROM public.employees e LEFT JOIN auth.users u ON u.id=e.user_id ORDER BY e.created_at DESC;
END $function$;

-- Verified active session guard: sowrix_ui_respond_quote
CREATE OR REPLACE FUNCTION public.sowrix_ui_respond_quote(p_id uuid, p_status text, p_comment text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE q public.quotations;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 SELECT * INTO q FROM public.quotations WHERE id=p_id FOR UPDATE;
 IF auth.uid() IS NULL OR NOT public.sowrix_has_permission('client_quotes','approve') OR public.sowrix_access_role()<>'client' OR NOT public.sowrix_org_access(q.client_id,'billing') THEN RAISE EXCEPTION 'Quotation not available' USING ERRCODE='42501'; END IF;
 IF q.status<>'sent' OR (q.valid_until IS NOT NULL AND q.valid_until<current_date) THEN RAISE EXCEPTION 'Quotation already answered or expired'; END IF;
 IF p_status NOT IN ('accepted','rejected') OR length(p_comment)>2000 THEN RAISE EXCEPTION 'Invalid response'; END IF;
 UPDATE public.quotations SET status=p_status,updated_at=now() WHERE id=p_id;
 INSERT INTO public.sowrix_ui_records(kind,owner_id,title,body,payload) VALUES('quote_response',auth.uid(),q.quotation_number,p_comment,jsonb_build_object('quote_id',q.id,'decision',p_status));
END $function$;

CREATE OR REPLACE FUNCTION public.sowrix_bind_client_login(p_actor_id uuid, p_client_id uuid, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE ctx jsonb; r text; revision bigint; grant_count integer;
BEGIN
 PERFORM 1 FROM public.clients WHERE id=p_client_id FOR UPDATE;
 PERFORM 1 FROM auth.users WHERE id=p_user_id FOR UPDATE;
 ctx:=public.sowrix_client_invite_context(p_actor_id,p_client_id);
 IF nullif(ctx->>'user_id','')::uuid IS DISTINCT FROM p_user_id OR p_user_id IS NULL THEN RAISE EXCEPTION 'The verified email and account do not match' USING ERRCODE='23514'; END IF;
 SELECT role::text INTO r FROM public.user_roles WHERE user_id=p_user_id FOR UPDATE;
 IF r IS NOT NULL AND r<>'client' THEN RAISE EXCEPTION 'Account role changed. Review Team Access' USING ERRCODE='23514'; END IF;
 INSERT INTO public.user_roles(user_id,role) VALUES(p_user_id,'client') ON CONFLICT DO NOTHING;
 SELECT coalesce(v.revision,0) INTO revision FROM public.sowrix_access_revisions v WHERE user_id=p_user_id;
 SELECT count(*) INTO grant_count FROM public.sowrix_action_grants WHERE user_id=p_user_id;
 -- Only provision an untouched account. Never restore a revoked/edited grant set.
 IF coalesce(revision,0)=0 AND grant_count=0 THEN
  INSERT INTO public.sowrix_action_grants(user_id,module_key,actions,row_scope,granted_by)
   SELECT p_user_id,k,a,'standard',p_actor_id FROM (VALUES
    ('clients','{view}'::text[]),('projects','{view}'::text[]),('invoices','{view}'::text[]),
    ('tickets','{view,create}'::text[]),('notifications','{view,edit}'::text[]),('client_quotes','{view,approve}'::text[])) v(k,a)
   ON CONFLICT DO NOTHING;
 END IF;
 UPDATE public.clients SET auth_user_id=p_user_id,updated_at=now() WHERE id=p_client_id;
 INSERT INTO public.sowrix_org_memberships(organization_id,user_id,member_role,billing_access) VALUES(p_client_id,p_user_id,'owner',true) ON CONFLICT(organization_id,user_id) DO NOTHING;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
  VALUES(p_actor_id,'client_login_linked','clients',p_client_id::text,jsonb_build_object('user_id',p_user_id));
 RETURN jsonb_build_object('linked',true,'permissions_preserved',coalesce(revision,0)>0 OR grant_count>0);
END $function$;
-- Trigger functions are invoked by triggers, never exposed as caller RPC actions.
REVOKE ALL ON FUNCTION public.sowrix_keep_notes_private(),public.sowrix_ticket_organization_default(),public.sowrix_check_project_organization() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.sowrix_ui_audit(),public.sowrix_ui_notify() FROM PUBLIC,anon,authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;

-- Defensowrix 11. Additive migration after SOWRIX release 10.
-- Run in staging first. This file does not provision any platform administrators.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_secure_session_allowed()') IS NULL THEN
  RAISE EXCEPTION 'Install the matching release 10 foundation before Defensowrix 11';
 END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.sowrix_def_platform_admins (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_orgs (
 organization_id uuid PRIMARY KEY REFERENCES public.clients(id),
 kind text NOT NULL DEFAULT 'customer' CHECK (kind IN ('customer','msp')),
 enabled boolean NOT NULL DEFAULT false,
 device_limit integer NOT NULL DEFAULT 100 CHECK(device_limit BETWEEN 1 AND 10000),
 ai_budget_cents integer NOT NULL DEFAULT 0 CHECK(ai_budget_cents BETWEEN 0 AND 100000),
 live_enabled boolean NOT NULL DEFAULT false,
 notification_emails text[] NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_members (
 organization_id uuid NOT NULL REFERENCES public.sowrix_def_orgs(organization_id),
 user_id uuid NOT NULL REFERENCES auth.users(id),
 role text NOT NULL CHECK(role IN ('customer_admin','operator','viewer')),
 live_access boolean NOT NULL DEFAULT false,
 ai_access boolean NOT NULL DEFAULT false,
 enabled boolean NOT NULL DEFAULT true,
 PRIMARY KEY(organization_id,user_id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_delegations (
 msp_id uuid NOT NULL REFERENCES public.sowrix_def_orgs(organization_id),
 organization_id uuid NOT NULL REFERENCES public.sowrix_def_orgs(organization_id),
 capabilities text[] NOT NULL DEFAULT '{read}' CHECK(capabilities <@ ARRAY['read','operate','configure','live','ai']),
 enabled boolean NOT NULL DEFAULT true,
 expires_at timestamptz,
 PRIMARY KEY(msp_id,organization_id), CHECK(msp_id<>organization_id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_sites (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES public.sowrix_def_orgs(organization_id),
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 100), location text NOT NULL DEFAULT '',
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(organization_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_collectors (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 site_id uuid NOT NULL, name text NOT NULL CHECK(length(name) BETWEEN 1 AND 100),
 token_hash text NOT NULL UNIQUE, token_expires_at timestamptz,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','active','revoked')),
 last_seen timestamptz, version text, last_sequence bigint NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(organization_id,site_id) REFERENCES public.sowrix_def_sites(organization_id,id),
 UNIQUE(organization_id,site_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_devices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 site_id uuid NOT NULL, collector_id uuid NOT NULL,
 device_code text NOT NULL DEFAULT ('SWX-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 100),
 kind text NOT NULL CHECK(kind IN ('server','laptop','router','switch','firewall','api','storage','backup','camera','recorder','other')),
 protocol text NOT NULL CHECK(protocol IN ('icmp','tcp','https','prometheus','snmp_exporter','backup_json','onvif','rtsp')),
 target text NOT NULL CHECK(length(target) BETWEEN 1 AND 500),
 settings jsonb NOT NULL DEFAULT '{}' CHECK(jsonb_typeof(settings)='object' AND octet_length(settings::text)<=4096),
 interval_seconds integer NOT NULL DEFAULT 60 CHECK(interval_seconds BETWEEN 15 AND 3600),
 enabled boolean NOT NULL DEFAULT true,
 status text NOT NULL DEFAULT 'unknown' CHECK(status IN ('unknown','up','down','unsupported')),
 last_seen timestamptz, last_observed timestamptz, latest_metrics jsonb NOT NULL DEFAULT '{}',
 latest_message text NOT NULL DEFAULT '', failure_count integer NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(organization_id,id), UNIQUE(organization_id,device_code),
 FOREIGN KEY(organization_id,site_id,collector_id) REFERENCES public.sowrix_def_collectors(organization_id,site_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_samples (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, organization_id uuid NOT NULL, device_id uuid NOT NULL,
 observed_at timestamptz NOT NULL, received_at timestamptz NOT NULL DEFAULT now(),
 status text NOT NULL CHECK(status IN ('up','down','unknown','unsupported')),
 metrics jsonb NOT NULL DEFAULT '{}',
 FOREIGN KEY(organization_id,device_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 UNIQUE(device_id,observed_at)
);
CREATE INDEX IF NOT EXISTS sowrix_def_samples_history ON public.sowrix_def_samples(organization_id,device_id,observed_at DESC);
CREATE INDEX IF NOT EXISTS sowrix_def_samples_retention ON public.sowrix_def_samples(received_at);
CREATE TABLE IF NOT EXISTS public.sowrix_def_rules (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 device_id uuid NOT NULL, name text NOT NULL CHECK(length(name) BETWEEN 1 AND 100),
 metric text NOT NULL CHECK(metric ~ '^[a-z][a-z0-9_]{0,63}$'),
 comparison text NOT NULL CHECK(comparison IN ('gt','lt','eq')),
 threshold numeric NOT NULL, samples_required integer NOT NULL DEFAULT 3 CHECK(samples_required BETWEEN 1 AND 30),
 hits integer NOT NULL DEFAULT 0, enabled boolean NOT NULL DEFAULT true,
 FOREIGN KEY(organization_id,device_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 UNIQUE(organization_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_incidents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 device_id uuid NOT NULL, rule_key text NOT NULL,
 title text NOT NULL, severity text NOT NULL DEFAULT 'warning' CHECK(severity IN ('info','warning','critical')),
 status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','acknowledged','resolved')),
 opened_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 acknowledged_by uuid REFERENCES auth.users(id), resolved_at timestamptz,
 evidence jsonb NOT NULL DEFAULT '{}',
 FOREIGN KEY(organization_id,device_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 UNIQUE(organization_id,id)
);
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_def_incident_dedup ON public.sowrix_def_incidents(device_id,rule_key) WHERE status<>'resolved';
CREATE INDEX IF NOT EXISTS sowrix_def_incident_org ON public.sowrix_def_incidents(organization_id,opened_at DESC);
CREATE TABLE IF NOT EXISTS public.sowrix_def_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL, device_id uuid NOT NULL,
 source_id text NOT NULL CHECK(length(source_id) BETWEEN 1 AND 120),
 observed_at timestamptz NOT NULL, received_at timestamptz NOT NULL DEFAULT now(),
 severity text NOT NULL CHECK(severity IN ('info','warning','critical')),
 source text NOT NULL CHECK(length(source)<=80), message text NOT NULL CHECK(length(message)<=2000),
 FOREIGN KEY(organization_id,device_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 UNIQUE(device_id,source_id)
);
CREATE INDEX IF NOT EXISTS sowrix_def_events_org ON public.sowrix_def_events(organization_id,observed_at DESC);
CREATE TABLE IF NOT EXISTS public.sowrix_def_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, organization_id uuid,
 actor_id uuid, action text NOT NULL, target_id text, details jsonb NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_outbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 incident_id uuid NOT NULL, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','sending','sent','failed')),
 attempts integer NOT NULL DEFAULT 0, next_attempt_at timestamptz NOT NULL DEFAULT now(), lease_until timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(), delivered_at timestamptz,
 UNIQUE(incident_id),
 FOREIGN KEY(organization_id,incident_id) REFERENCES public.sowrix_def_incidents(organization_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_streams (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL, device_id uuid NOT NULL,
 user_id uuid NOT NULL REFERENCES auth.users(id), token_hash text NOT NULL UNIQUE,
 expires_at timestamptz NOT NULL DEFAULT now()+interval '5 minutes', revoked_at timestamptz,
 FOREIGN KEY(organization_id,device_id) REFERENCES public.sowrix_def_devices(organization_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_ai_runs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL, incident_id uuid NOT NULL,
 user_id uuid NOT NULL REFERENCES auth.users(id), reserved_cents integer NOT NULL CHECK(reserved_cents>0),
 actual_cents integer CHECK(actual_cents>=0), status text NOT NULL DEFAULT 'reserved' CHECK(status IN ('reserved','complete','failed')),
 result jsonb, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(organization_id,incident_id) REFERENCES public.sowrix_def_incidents(organization_id,id)
);
-- Session ciphertext can be read only by the server's service role.
CREATE TABLE IF NOT EXISTS public.sowrix_def_sessions (
 token_hash text PRIMARY KEY, user_id uuid NOT NULL REFERENCES auth.users(id),
 encrypted_tokens text NOT NULL, csrf_hash text NOT NULL, expires_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.sowrix_def_platform()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_secure_session_allowed() AND public.sowrix_access_role()='super_admin'
  AND EXISTS(SELECT 1 FROM public.sowrix_def_platform_admins WHERE user_id=auth.uid())
$$;
CREATE OR REPLACE FUNCTION public.sowrix_def_can(p_org uuid,p_cap text DEFAULT 'read')
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE allowed boolean:=false;
BEGIN
 IF p_cap NOT IN ('read','operate','configure','members','live','ai') OR NOT public.sowrix_secure_session_allowed() THEN RETURN false; END IF;
 IF public.sowrix_def_platform() THEN RETURN true; END IF;
 IF public.sowrix_access_role() IS DISTINCT FROM 'client' THEN RETURN false; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_orgs d JOIN public.clients c ON c.id=d.organization_id
  WHERE d.organization_id=p_org AND d.enabled AND c.status='active') THEN RETURN false; END IF;
 SELECT EXISTS(SELECT 1 FROM public.sowrix_def_members m JOIN public.sowrix_org_memberships b
  ON b.organization_id=m.organization_id AND b.user_id=m.user_id
  WHERE m.organization_id=p_org AND m.user_id=auth.uid() AND m.enabled AND b.status='active'
  AND (m.role<>'customer_admin' OR (auth.jwt()->>'aal'='aal2' AND EXISTS(SELECT 1 FROM auth.mfa_factors WHERE user_id=auth.uid() AND status::text='verified')))
  AND (p_cap='read' OR (p_cap='operate' AND m.role IN ('customer_admin','operator'))
    OR (p_cap IN ('configure','members') AND m.role='customer_admin')
    OR (p_cap='live' AND m.live_access) OR (p_cap='ai' AND m.ai_access))) INTO allowed;
 IF NOT allowed AND p_cap<>'members' THEN
 SELECT EXISTS(SELECT 1 FROM public.sowrix_def_delegations d
  JOIN public.sowrix_def_orgs o ON o.organization_id=d.msp_id AND o.kind='msp' AND o.enabled
  JOIN public.clients c ON c.id=o.organization_id AND c.status='active'
  JOIN public.sowrix_def_members m ON m.organization_id=d.msp_id AND m.user_id=auth.uid() AND m.enabled
  JOIN public.sowrix_org_memberships b ON b.organization_id=m.organization_id AND b.user_id=m.user_id AND b.status='active'
  WHERE d.organization_id=p_org AND d.enabled AND (d.expires_at IS NULL OR d.expires_at>now()) AND p_cap=ANY(d.capabilities)
  AND auth.jwt()->>'aal'='aal2' AND EXISTS(SELECT 1 FROM auth.mfa_factors WHERE user_id=auth.uid() AND status::text='verified')
  AND (p_cap='read' OR (p_cap='operate' AND m.role IN ('customer_admin','operator'))
   OR (p_cap='configure' AND m.role='customer_admin')
   OR (p_cap='live' AND m.live_access) OR (p_cap='ai' AND m.ai_access))) INTO allowed;
 END IF;
 IF p_cap IN ('configure','members','live','ai') AND (auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' OR NOT EXISTS(SELECT 1 FROM auth.mfa_factors WHERE user_id=auth.uid() AND status::text='verified')) THEN RETURN false; END IF;
 RETURN allowed;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_def_audit_write(p_org uuid,p_action text,p_target text,p_details jsonb DEFAULT '{}')
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 INSERT INTO public.sowrix_def_audit(organization_id,actor_id,action,target_id,details)
 VALUES(p_org,auth.uid(),p_action,p_target,p_details)
$$;
REVOKE ALL ON FUNCTION public.sowrix_def_audit_write(uuid,text,text,jsonb) FROM PUBLIC,anon,authenticated;

-- All writes use validated RPC operations. Raw table mutation grants are absent.
DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['platform_admins','orgs','members','delegations','sites','collectors','devices','samples','rules','incidents','events','audit','outbox','streams','ai_runs','sessions'] LOOP
  EXECUTE format('ALTER TABLE public.sowrix_def_%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.sowrix_def_%I FROM PUBLIC,anon,authenticated',t);
  EXECUTE format('GRANT ALL ON public.sowrix_def_%I TO service_role',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['sites','devices','samples','rules','incidents','events'] LOOP
  EXECUTE format('DROP POLICY IF EXISTS def_read ON public.sowrix_def_%I',t);
  EXECUTE format('CREATE POLICY def_read ON public.sowrix_def_%I FOR SELECT TO authenticated USING(public.sowrix_def_can(organization_id,''read''))',t);
  EXECUTE format('GRANT SELECT ON public.sowrix_def_%I TO authenticated',t);
 END LOOP;
END $$;
REVOKE ALL ON public.sowrix_def_samples_id_seq,public.sowrix_def_audit_id_seq FROM PUBLIC,anon,authenticated;
GRANT USAGE,SELECT ON public.sowrix_def_samples_id_seq,public.sowrix_def_audit_id_seq TO service_role;

CREATE OR REPLACE FUNCTION public.sowrix_def_bootstrap(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.user_roles WHERE user_id=p_user_id AND role::text='super_admin') THEN
  RAISE EXCEPTION 'Select an existing SOWRIX Super Admin account';
 END IF;
 INSERT INTO public.sowrix_def_platform_admins(user_id) VALUES(p_user_id) ON CONFLICT DO NOTHING;
 PERFORM public.sowrix_def_audit_write(NULL,'platform_bootstrap',p_user_id::text);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_bootstrap(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_bootstrap(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.sowrix_def_request(p_action text,p_org uuid DEFAULT NULL,p_data jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
#variable_conflict use_column
DECLARE result jsonb; v_id uuid; s public.sowrix_def_sites; c public.sowrix_def_collectors;
 d public.sowrix_def_devices; inc public.sowrix_def_incidents; role_name text; target_user uuid;
 secret text; cap text; o public.sowrix_def_orgs; amount integer; spent bigint; allowed_caps text[];
BEGIN
 IF auth.uid() IS NULL OR NOT public.sowrix_secure_session_allowed() THEN
  RAISE EXCEPTION 'Verified active sign-in required' USING ERRCODE='42501';
 END IF;
 IF jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>20000 THEN RAISE EXCEPTION 'Invalid request'; END IF;
 IF p_action='context' THEN
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',x.organization_id,'name',x.organization_name,'kind',x.kind,
   'capabilities',x.capabilities,'live_enabled',x.live_enabled) ORDER BY x.organization_name),'[]') INTO result FROM (
    SELECT o.organization_id,c.organization_name,o.kind,o.live_enabled,
     ARRAY(SELECT k FROM unnest(ARRAY['read','operate','configure','members','live','ai']) k WHERE public.sowrix_def_can(o.organization_id,k)) capabilities
    FROM public.sowrix_def_orgs o JOIN public.clients c ON c.id=o.organization_id
    WHERE public.sowrix_def_can(o.organization_id,'read')
  )x;
  RETURN jsonb_build_object('release',11,'platform_admin',public.sowrix_def_platform(),'organizations',result,
   'requires_mfa',public.sowrix_access_role()<>'client' OR EXISTS(SELECT 1 FROM public.sowrix_def_members WHERE user_id=auth.uid() AND enabled AND role='customer_admin'),
   'role',public.sowrix_access_role(),'user_id',auth.uid(),
   'available_clients',CASE WHEN public.sowrix_def_platform() THEN (SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',organization_name)),'[]') FROM public.clients WHERE status='active') ELSE '[]'::jsonb END);
 END IF;
 IF p_action='organization.config' THEN
  IF NOT public.sowrix_def_platform() THEN RAISE EXCEPTION 'SOWRIX platform administration required' USING ERRCODE='42501'; END IF;
  SELECT to_jsonb(x) INTO result FROM public.sowrix_def_orgs x WHERE organization_id=p_org;
  RETURN coalesce(result,'{}');
 END IF;
 IF p_action IN ('organization.save','delegation.save') THEN
  IF NOT public.sowrix_def_platform() THEN RAISE EXCEPTION 'SOWRIX platform administration required' USING ERRCODE='42501'; END IF;
  PERFORM public.sowrix_require_secure_session(true);
  IF p_action='organization.save' THEN
   IF jsonb_typeof(coalesce(p_data->'notification_emails','[]'))<>'array'
    OR jsonb_array_length(coalesce(p_data->'notification_emails','[]'))>10
    OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(coalesce(p_data->'notification_emails','[]')) e
      WHERE length(e)>254 OR e !~ '^[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
    RAISE EXCEPTION 'Use up to ten valid approved notification email addresses';
   END IF;
   INSERT INTO public.sowrix_def_orgs(organization_id,kind,enabled,device_limit,ai_budget_cents,live_enabled,notification_emails)
   VALUES(p_org,coalesce(p_data->>'kind','customer'),coalesce((p_data->>'enabled')::boolean,true),
    coalesce((p_data->>'device_limit')::integer,100),coalesce((p_data->>'ai_budget_cents')::integer,0),
    coalesce((p_data->>'live_enabled')::boolean,false),
    ARRAY(SELECT jsonb_array_elements_text(coalesce(p_data->'notification_emails','[]'))))
   ON CONFLICT(organization_id) DO UPDATE SET enabled=EXCLUDED.enabled,device_limit=EXCLUDED.device_limit,
    ai_budget_cents=EXCLUDED.ai_budget_cents,live_enabled=EXCLUDED.live_enabled,notification_emails=EXCLUDED.notification_emails;
   -- Kind is immutable once assigned: it is an authorization relationship.
   IF (SELECT kind FROM public.sowrix_def_orgs WHERE organization_id=p_org) IS DISTINCT FROM coalesce(p_data->>'kind','customer') THEN RAISE EXCEPTION 'Organization kind cannot be changed'; END IF;
  ELSE
   IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_orgs WHERE organization_id=(p_data->>'msp_id')::uuid AND kind='msp')
    OR NOT EXISTS(SELECT 1 FROM public.sowrix_def_orgs WHERE organization_id=p_org AND kind='customer') THEN RAISE EXCEPTION 'Select an MSP and a customer'; END IF;
   allowed_caps=ARRAY(SELECT jsonb_array_elements_text(coalesce(p_data->'capabilities','["read"]')));
   INSERT INTO public.sowrix_def_delegations(msp_id,organization_id,capabilities,enabled,expires_at)
   VALUES((p_data->>'msp_id')::uuid,p_org,allowed_caps,coalesce((p_data->>'enabled')::boolean,true),(p_data->>'expires_at')::timestamptz)
   ON CONFLICT(msp_id,organization_id) DO UPDATE SET capabilities=EXCLUDED.capabilities,enabled=EXCLUDED.enabled,expires_at=EXCLUDED.expires_at;
  END IF;
  PERFORM public.sowrix_def_audit_write(p_org,p_action,p_org::text);
  RETURN jsonb_build_object('ok',true);
 END IF;
 cap:=CASE WHEN p_action IN ('site.save','device.save','device.disable','collector.enroll','collector.revoke','rule.save') THEN 'configure'
  WHEN p_action='member.save' THEN 'members'
  WHEN p_action IN ('incident.acknowledge','incident.resolve') THEN 'operate'
  WHEN p_action='stream.create' THEN 'live'
  WHEN p_action IN ('ai.reserve','ai.list') THEN 'ai'
  ELSE 'read' END;
 IF p_org IS NULL OR NOT public.sowrix_def_can(p_org,cap) THEN RAISE EXCEPTION 'Resource not found or access not permitted' USING ERRCODE='42501'; END IF;
 -- Serialize quota changes, not concurrent dashboard reads.
 IF p_action IN ('device.save','collector.enroll','ai.reserve','stream.create') THEN
  SELECT * INTO o FROM public.sowrix_def_orgs WHERE organization_id=p_org FOR UPDATE;
 ELSE
  SELECT * INTO o FROM public.sowrix_def_orgs WHERE organization_id=p_org;
 END IF;
 IF p_action='overview' THEN
  RETURN jsonb_build_object('devices',(SELECT count(*) FROM public.sowrix_def_devices WHERE organization_id=p_org AND enabled),
   'up',(SELECT count(*) FROM public.sowrix_def_devices WHERE organization_id=p_org AND enabled AND status='up' AND last_observed>now()-greatest(interval_seconds*3,180)*interval '1 second'),
   'down',(SELECT count(*) FROM public.sowrix_def_devices WHERE organization_id=p_org AND enabled AND status='down' AND last_observed>now()-greatest(interval_seconds*3,180)*interval '1 second'),
   'incidents',(SELECT count(*) FROM public.sowrix_def_incidents WHERE organization_id=p_org AND status<>'resolved'),
   'collectors',(SELECT count(*) FROM public.sowrix_def_collectors WHERE organization_id=p_org AND status='active' AND last_seen>now()-interval '3 minutes'),
   'sites',(SELECT count(*) FROM public.sowrix_def_sites WHERE organization_id=p_org),
   'ai_budget_cents',o.ai_budget_cents,'device_limit',o.device_limit,'live_enabled',o.live_enabled,
   'retention',jsonb_build_object('samples_hours',24,'events_days',7,'audit_days',180),
   'notification_configured',cardinality(o.notification_emails)>0);
 ELSIF p_action='sites.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name),'[]') INTO result FROM public.sowrix_def_sites x WHERE organization_id=p_org;
 ELSIF p_action='devices.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name),'[]') INTO result FROM (
   SELECT d.*,s.name site_name,CASE WHEN d.last_observed IS NULL OR d.last_observed<now()-greatest(d.interval_seconds*3,180)*interval '1 second' THEN 'unknown' ELSE d.status END effective_status
   FROM public.sowrix_def_devices d JOIN public.sowrix_def_sites s ON s.id=d.site_id WHERE d.organization_id=p_org
   ORDER BY d.name LIMIT 500 OFFSET greatest(0,least(coalesce((p_data->>'offset')::integer,0),10000))
  )x;
 ELSIF p_action='collectors.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT id,site_id,name,status,last_seen,version,created_at FROM public.sowrix_def_collectors WHERE organization_id=p_org ORDER BY created_at DESC
  )x;
 ELSIF p_action='incidents.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT i.*,d.name device_name,d.device_code FROM public.sowrix_def_incidents i JOIN public.sowrix_def_devices d ON d.id=i.device_id
   WHERE i.organization_id=p_org ORDER BY i.opened_at DESC LIMIT 100 OFFSET greatest(0,least(coalesce((p_data->>'offset')::integer,0),10000))
  )x;
 ELSIF p_action='events.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT e.*,d.name device_name FROM public.sowrix_def_events e JOIN public.sowrix_def_devices d ON d.id=e.device_id
   WHERE e.organization_id=p_org ORDER BY e.observed_at DESC LIMIT 100 OFFSET greatest(0,least(coalesce((p_data->>'offset')::integer,0),10000))
  )x;
 ELSIF p_action='rules.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM public.sowrix_def_rules x WHERE organization_id=p_org;
 ELSIF p_action='history' THEN
  SELECT * INTO d FROM public.sowrix_def_devices WHERE id=(p_data->>'device_id')::uuid AND organization_id=p_org;
  IF d.id IS NULL THEN RAISE EXCEPTION 'Device not found'; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.observed_at),'[]') INTO result FROM (
   SELECT observed_at,status,metrics FROM public.sowrix_def_samples WHERE organization_id=p_org AND device_id=d.id ORDER BY observed_at DESC LIMIT 120
  )x;
 ELSIF p_action='members.list' THEN
  IF NOT public.sowrix_def_can(p_org,'members') THEN RAISE EXCEPTION 'Member administration required' USING ERRCODE='42501'; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT m.*,u.email FROM public.sowrix_def_members m JOIN auth.users u ON u.id=m.user_id WHERE m.organization_id=p_org
  )x;
 ELSIF p_action='audit.list' THEN
  IF NOT public.sowrix_def_can(p_org,'members') THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT * FROM public.sowrix_def_audit WHERE organization_id=p_org ORDER BY created_at DESC LIMIT 100
  )x;
 ELSIF p_action='member.save' THEN
  SELECT id INTO target_user FROM auth.users WHERE lower(email)=lower(btrim(p_data->>'email'));
  IF target_user IS NULL OR NOT EXISTS(SELECT 1 FROM public.user_roles WHERE user_id=target_user AND role::text='client') THEN RAISE EXCEPTION 'Provision this client account through SOWRIX first'; END IF;
  IF NOT public.sowrix_def_platform() AND NOT EXISTS(SELECT 1 FROM public.sowrix_org_memberships WHERE user_id=target_user AND organization_id=p_org AND status='active') THEN RAISE EXCEPTION 'SOWRIX must first link this account to the organization'; END IF;
  IF target_user=auth.uid() THEN RAISE EXCEPTION 'Another authorized administrator must change your own access'; END IF;
  role_name=p_data->>'role';
  IF role_name NOT IN ('customer_admin','operator','viewer') OR role_name IS NULL THEN RAISE EXCEPTION 'Invalid customer role'; END IF;
  INSERT INTO public.sowrix_org_memberships(organization_id,user_id,member_role,billing_access) VALUES(p_org,target_user,'member',false) ON CONFLICT DO NOTHING;
  INSERT INTO public.sowrix_def_members(organization_id,user_id,role,enabled,live_access,ai_access)
   VALUES(p_org,target_user,role_name,coalesce((p_data->>'enabled')::boolean,true),coalesce((p_data->>'live_access')::boolean,false),coalesce((p_data->>'ai_access')::boolean,false))
   ON CONFLICT(organization_id,user_id) DO UPDATE SET role=EXCLUDED.role,enabled=EXCLUDED.enabled,live_access=EXCLUDED.live_access,ai_access=EXCLUDED.ai_access;
  v_id=target_user;
 ELSIF p_action='site.save' THEN
  v_id=coalesce((p_data->>'id')::uuid,gen_random_uuid());
  IF EXISTS(SELECT 1 FROM public.sowrix_def_sites WHERE id=v_id AND organization_id<>p_org) THEN RAISE EXCEPTION 'Site not found'; END IF;
  INSERT INTO public.sowrix_def_sites(id,organization_id,name,location) VALUES(v_id,p_org,btrim(p_data->>'name'),left(coalesce(p_data->>'location',''),200))
   ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,location=EXCLUDED.location;
 ELSIF p_action='collector.enroll' THEN
  SELECT * INTO s FROM public.sowrix_def_sites WHERE id=(p_data->>'site_id')::uuid AND organization_id=p_org;
  IF s.id IS NULL THEN RAISE EXCEPTION 'Site not found'; END IF;
  IF (SELECT count(*) FROM public.sowrix_def_collectors WHERE organization_id=p_org AND status<>'revoked')>=100 THEN RAISE EXCEPTION 'Collector limit reached'; END IF;
  secret=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
  INSERT INTO public.sowrix_def_collectors(organization_id,site_id,name,token_hash,token_expires_at)
   VALUES(p_org,s.id,btrim(p_data->>'name'),encode(sha256(convert_to(secret,'UTF8')),'hex'),now()+interval '15 minutes') RETURNING id INTO v_id;
  PERFORM public.sowrix_def_audit_write(p_org,p_action,v_id::text);
  RETURN jsonb_build_object('id',v_id,'enrollment_token',secret,'expires_in_seconds',900);
 ELSIF p_action='collector.revoke' THEN
  UPDATE public.sowrix_def_collectors SET status='revoked' WHERE id=(p_data->>'id')::uuid AND organization_id=p_org RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'Collector not found'; END IF;
 ELSIF p_action='device.save' THEN
  SELECT * INTO c FROM public.sowrix_def_collectors WHERE id=(p_data->>'collector_id')::uuid AND organization_id=p_org AND status<>'revoked';
  IF c.id IS NULL THEN RAISE EXCEPTION 'Collector not found'; END IF;
  v_id=coalesce((p_data->>'id')::uuid,gen_random_uuid());
  IF EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE id=v_id AND organization_id<>p_org) THEN RAISE EXCEPTION 'Device not found'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE id=v_id AND enabled) AND (SELECT count(*) FROM public.sowrix_def_devices WHERE organization_id=p_org AND enabled)>=o.device_limit THEN RAISE EXCEPTION 'Device limit reached'; END IF;
  IF (p_data->'settings')::text ~* '(password|secret|token|authorization)' OR p_data->>'target' ~ '[@?#]' THEN RAISE EXCEPTION 'Keep credentials and query secrets in the collector local secret configuration'; END IF;
  INSERT INTO public.sowrix_def_devices(id,organization_id,site_id,collector_id,name,kind,protocol,target,settings,interval_seconds)
   VALUES(v_id,p_org,c.site_id,c.id,btrim(p_data->>'name'),p_data->>'kind',p_data->>'protocol',p_data->>'target',coalesce(p_data->'settings','{}'),coalesce((p_data->>'interval_seconds')::integer,60))
   ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,kind=EXCLUDED.kind,protocol=EXCLUDED.protocol,target=EXCLUDED.target,settings=EXCLUDED.settings,interval_seconds=EXCLUDED.interval_seconds,collector_id=EXCLUDED.collector_id,site_id=EXCLUDED.site_id,enabled=true,status='unknown',failure_count=0;
 ELSIF p_action='device.disable' THEN
  UPDATE public.sowrix_def_devices SET enabled=false WHERE id=(p_data->>'id')::uuid AND organization_id=p_org RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'Device not found'; END IF;
 ELSIF p_action='rule.save' THEN
  SELECT * INTO d FROM public.sowrix_def_devices WHERE id=(p_data->>'device_id')::uuid AND organization_id=p_org;
  IF d.id IS NULL THEN RAISE EXCEPTION 'Device not found'; END IF;
  v_id=coalesce((p_data->>'id')::uuid,gen_random_uuid());
  IF EXISTS(SELECT 1 FROM public.sowrix_def_rules WHERE id=v_id AND organization_id<>p_org) THEN RAISE EXCEPTION 'Rule not found'; END IF;
  INSERT INTO public.sowrix_def_rules(id,organization_id,device_id,name,metric,comparison,threshold,samples_required,enabled)
   VALUES(v_id,p_org,d.id,btrim(p_data->>'name'),p_data->>'metric',p_data->>'comparison',(p_data->>'threshold')::numeric,coalesce((p_data->>'samples_required')::integer,3),coalesce((p_data->>'enabled')::boolean,true))
   ON CONFLICT(id) DO UPDATE SET device_id=EXCLUDED.device_id,name=EXCLUDED.name,metric=EXCLUDED.metric,comparison=EXCLUDED.comparison,threshold=EXCLUDED.threshold,samples_required=EXCLUDED.samples_required,enabled=EXCLUDED.enabled,hits=0;
  UPDATE public.sowrix_def_incidents SET status='resolved',resolved_at=now(),updated_at=now(),evidence=evidence||'{"resolution":"Rule configuration changed; subsequent observations are evaluated under the new rule."}'::jsonb
   WHERE organization_id=p_org AND rule_key=v_id::text AND status<>'resolved';
 ELSIF p_action='incident.acknowledge' THEN
  UPDATE public.sowrix_def_incidents SET status='acknowledged',acknowledged_by=auth.uid(),updated_at=now()
   WHERE id=(p_data->>'id')::uuid AND organization_id=p_org AND status='open' RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'Open incident not found'; END IF;
 ELSIF p_action='incident.resolve' THEN
  IF length(btrim(coalesce(p_data->>'reason','')))<8 THEN RAISE EXCEPTION 'Enter a resolution reason of at least eight characters'; END IF;
  UPDATE public.sowrix_def_incidents SET status='resolved',resolved_at=now(),updated_at=now(),
   evidence=evidence||jsonb_build_object('manual_resolution',left(p_data->>'reason',500),'resolved_by',auth.uid())
   WHERE id=(p_data->>'id')::uuid AND organization_id=p_org AND status<>'resolved' RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'Active incident not found'; END IF;
 ELSIF p_action='stream.create' THEN
  IF NOT o.live_enabled THEN RAISE EXCEPTION 'Live viewing is not enabled for this organization'; END IF;
  SELECT * INTO d FROM public.sowrix_def_devices WHERE id=(p_data->>'device_id')::uuid AND organization_id=p_org AND kind IN ('camera','recorder') AND enabled;
  IF d.id IS NULL THEN RAISE EXCEPTION 'Camera not found'; END IF;
  IF (SELECT count(*) FROM public.sowrix_def_streams WHERE organization_id=p_org AND revoked_at IS NULL AND expires_at>now())>=4 THEN RAISE EXCEPTION 'Concurrent viewing limit reached'; END IF;
  secret=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
  INSERT INTO public.sowrix_def_streams(organization_id,device_id,user_id,token_hash) VALUES(p_org,d.id,auth.uid(),encode(sha256(convert_to(secret,'UTF8')),'hex')) RETURNING id INTO v_id;
  PERFORM public.sowrix_def_audit_write(p_org,p_action,d.id::text);
  RETURN jsonb_build_object('id',v_id,'token',secret,'path',p_org::text||'/'||d.id::text,'expires_in',300);
 ELSIF p_action='stream.revoke' THEN
  UPDATE public.sowrix_def_streams SET revoked_at=now() WHERE id=(p_data->>'id')::uuid AND organization_id=p_org AND user_id=auth.uid() RETURNING id INTO v_id;
 ELSIF p_action='ai.reserve' THEN
  SELECT * INTO inc FROM public.sowrix_def_incidents WHERE id=(p_data->>'incident_id')::uuid AND organization_id=p_org;
  IF inc.id IS NULL THEN RAISE EXCEPTION 'Incident not found'; END IF;
  amount=greatest(1,least(coalesce((p_data->>'reserve_cents')::integer,10),1000));
  SELECT coalesce(sum(coalesce(actual_cents,reserved_cents)),0) INTO spent FROM public.sowrix_def_ai_runs WHERE organization_id=p_org AND created_at>=date_trunc('month',now());
  IF spent+amount>o.ai_budget_cents THEN RAISE EXCEPTION 'Monthly AI budget reached or not configured'; END IF;
  IF (SELECT count(*) FROM public.sowrix_def_ai_runs WHERE organization_id=p_org AND status='reserved' AND created_at>now()-interval '10 minutes')>=2 THEN RAISE EXCEPTION 'Two investigations are already in progress'; END IF;
  INSERT INTO public.sowrix_def_ai_runs(organization_id,incident_id,user_id,reserved_cents) VALUES(p_org,inc.id,auth.uid(),amount) RETURNING id INTO v_id;
  PERFORM public.sowrix_def_audit_write(p_org,p_action,v_id::text);
  RETURN jsonb_build_object('id',v_id,'incident',to_jsonb(inc));
 ELSIF p_action='ai.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT id,incident_id,status,result,actual_cents,reserved_cents,created_at FROM public.sowrix_def_ai_runs WHERE organization_id=p_org ORDER BY created_at DESC LIMIT 50
  )x;
 ELSIF p_action='export' THEN
  PERFORM public.sowrix_def_audit_write(p_org,'inventory_export',p_org::text);
  SELECT coalesce(jsonb_agg(jsonb_build_object('device_code',device_code,'name',name,'kind',kind,'status',CASE WHEN last_observed IS NULL OR last_observed<now()-greatest(interval_seconds*3,180)*interval '1 second' THEN 'unknown' ELSE status END,'last_seen',last_seen)),'[]')
   INTO result FROM public.sowrix_def_devices WHERE organization_id=p_org;
 ELSE RAISE EXCEPTION 'Unsupported operation';
 END IF;
 IF result IS NOT NULL THEN RETURN result; END IF;
 PERFORM public.sowrix_def_audit_write(p_org,p_action,v_id::text);
 RETURN jsonb_build_object('ok',true,'id',v_id);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_platform(),public.sowrix_def_can(uuid,text),public.sowrix_def_request(text,uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_def_platform(),public.sowrix_def_can(uuid,text),public.sowrix_def_request(text,uuid,jsonb) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sowrix_def_incident(p_org uuid,p_device uuid,p_key text,p_title text,p_bad boolean,p_evidence jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id uuid;
BEGIN
 IF p_bad THEN
  INSERT INTO public.sowrix_def_incidents(organization_id,device_id,rule_key,title,evidence,severity)
   VALUES(p_org,p_device,p_key,p_title,p_evidence,CASE WHEN p_key LIKE 'security:%' THEN 'critical' ELSE 'warning' END)
   ON CONFLICT(device_id,rule_key) WHERE status<>'resolved' DO UPDATE SET updated_at=now(),evidence=EXCLUDED.evidence RETURNING id INTO v_id;
  INSERT INTO public.sowrix_def_outbox(organization_id,incident_id) VALUES(p_org,v_id) ON CONFLICT DO NOTHING;
 ELSE
  UPDATE public.sowrix_def_incidents SET status='resolved',resolved_at=now(),updated_at=now(),evidence=p_evidence
   WHERE device_id=p_device AND rule_key=p_key AND status<>'resolved';
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_incident(uuid,uuid,text,text,boolean,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_def_collector(p_action text,p_token text,p_data jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.sowrix_def_collectors; d public.sowrix_def_devices; r public.sowrix_def_rules;
 sample jsonb; event jsonb; tm timestamptz; seq bigint; value numeric; bad boolean; secret text; inserted integer; total integer:=0;
BEGIN
 IF length(coalesce(p_token,''))<>64 OR octet_length(p_data::text)>500000 THEN RAISE EXCEPTION 'Invalid collector request' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.sowrix_def_collectors WHERE token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') FOR UPDATE;
 IF c.id IS NULL OR c.status='revoked' OR NOT EXISTS(SELECT 1 FROM public.sowrix_def_orgs o JOIN public.clients cl ON cl.id=o.organization_id WHERE o.organization_id=c.organization_id AND o.enabled AND cl.status='active') THEN RAISE EXCEPTION 'Collector is not authorized' USING ERRCODE='42501'; END IF;
 IF p_action='activate' THEN
  IF c.status<>'pending' OR c.token_expires_at<now() THEN RAISE EXCEPTION 'Enrollment token expired or already used'; END IF;
  secret=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
  UPDATE public.sowrix_def_collectors SET token_hash=encode(sha256(convert_to(secret,'UTF8')),'hex'),token_expires_at=NULL,status='active',last_seen=now(),version=left(p_data->>'version',40) WHERE id=c.id;
  PERFORM public.sowrix_def_audit_write(c.organization_id,'collector_activated',c.id::text);
  RETURN jsonb_build_object('collector_id',c.id,'organization_id',c.organization_id,'site_id',c.site_id,'credential',secret);
 END IF;
 IF c.status<>'active' THEN RAISE EXCEPTION 'Enrollment required'; END IF;
 UPDATE public.sowrix_def_collectors SET last_seen=now(),version=left(coalesce(p_data->>'version',version),40) WHERE id=c.id;
 IF p_action='config' THEN
  RETURN jsonb_build_object('collector_id',c.id,'organization_id',c.organization_id,'last_sequence',c.last_sequence,
   'devices',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'kind',kind,'protocol',protocol,'target',target,'settings',settings,'interval_seconds',interval_seconds)),'[]') FROM public.sowrix_def_devices WHERE collector_id=c.id AND enabled),
   'live_devices',(SELECT coalesce(jsonb_agg(DISTINCT st.device_id),'[]') FROM public.sowrix_def_streams st JOIN public.sowrix_def_devices dev ON dev.id=st.device_id JOIN public.sowrix_def_orgs o ON o.organization_id=st.organization_id WHERE dev.collector_id=c.id AND dev.enabled AND o.live_enabled AND st.expires_at>now() AND st.revoked_at IS NULL));
 END IF;
 IF p_action<>'ingest' THEN RAISE EXCEPTION 'Unsupported collector operation'; END IF;
 seq=(p_data->>'sequence')::bigint;
 IF seq IS NULL OR seq<1 THEN RAISE EXCEPTION 'Sequence required'; END IF;
 IF seq<=c.last_sequence THEN RETURN jsonb_build_object('accepted',0,'duplicate',true); END IF;
 IF jsonb_typeof(p_data->'samples')<>'array' OR jsonb_array_length(p_data->'samples')>100 THEN RAISE EXCEPTION 'At most 100 samples per batch'; END IF;
 FOR sample IN SELECT jsonb_array_elements(p_data->'samples') LOOP
  SELECT * INTO d FROM public.sowrix_def_devices WHERE id=(sample->>'device_id')::uuid AND collector_id=c.id AND organization_id=c.organization_id AND enabled FOR UPDATE;
  IF d.id IS NULL THEN RAISE EXCEPTION 'Device does not belong to this collector'; END IF;
  tm=(sample->>'observed_at')::timestamptz;
  IF tm IS NULL OR tm>now()+interval '2 minutes' OR tm<now()-interval '24 hours' THEN RAISE EXCEPTION 'Observation timestamp outside supported spool window'; END IF;
  IF sample->>'status' NOT IN ('up','down','unknown','unsupported') OR sample->>'status' IS NULL THEN RAISE EXCEPTION 'Invalid observation status'; END IF;
  IF jsonb_typeof(sample->'metrics')<>'object' OR octet_length((sample->'metrics')::text)>8192
   OR (SELECT count(*) FROM jsonb_object_keys(sample->'metrics'))>100
   OR EXISTS(SELECT 1 FROM jsonb_each(sample->'metrics') e WHERE e.key !~ '^[a-z][a-z0-9_]{0,63}$' OR jsonb_typeof(e.value)<>'number') THEN RAISE EXCEPTION 'Metrics must be bounded numeric fields'; END IF;
  INSERT INTO public.sowrix_def_samples(organization_id,device_id,observed_at,status,metrics)
   VALUES(c.organization_id,d.id,tm,sample->>'status',sample->'metrics') ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS inserted=ROW_COUNT;
  IF inserted=0 THEN CONTINUE; END IF;
  total=total+1;
  -- Historical spool data must not overwrite current state or create new live alerts.
  IF d.last_observed IS NOT NULL AND tm<=d.last_observed THEN CONTINUE; END IF;
  IF d.last_observed IS NULL OR tm-d.last_observed>greatest(d.interval_seconds*3,180)*interval '1 second' THEN UPDATE public.sowrix_def_rules SET hits=0 WHERE device_id=d.id; END IF;
  UPDATE public.sowrix_def_devices SET status=sample->>'status',last_seen=now(),last_observed=tm,latest_metrics=sample->'metrics',
   latest_message=left(coalesce(sample->>'message',''),200),failure_count=CASE WHEN sample->>'status'='down' THEN CASE WHEN tm-last_observed<=greatest(interval_seconds*3,180)*interval '1 second' THEN failure_count+1 ELSE 1 END ELSE 0 END
   WHERE id=d.id RETURNING * INTO d;
  IF tm<now()-greatest(d.interval_seconds*3,180)*interval '1 second' THEN CONTINUE; END IF;
  IF d.status='up' OR (d.status='down' AND d.failure_count>=3) THEN
   PERFORM public.sowrix_def_incident(c.organization_id,d.id,'availability',d.name||' is unavailable',d.failure_count>=3,jsonb_build_object('observed_at',tm,'status',d.status,'consecutive_failures',d.failure_count));
  END IF;
  FOR r IN SELECT * FROM public.sowrix_def_rules WHERE device_id=d.id AND enabled LOOP
   IF NOT sample->'metrics' ? r.metric OR d.status<>'up' THEN UPDATE public.sowrix_def_rules SET hits=0 WHERE id=r.id; CONTINUE; END IF;
   value=(sample->'metrics'->>r.metric)::numeric;
   bad=CASE r.comparison WHEN 'gt' THEN value>r.threshold WHEN 'lt' THEN value<r.threshold ELSE value=r.threshold END;
   UPDATE public.sowrix_def_rules SET hits=CASE WHEN bad THEN least(hits+1,samples_required) ELSE 0 END WHERE id=r.id RETURNING * INTO r;
   IF NOT bad OR r.hits>=r.samples_required THEN
    PERFORM public.sowrix_def_incident(c.organization_id,d.id,r.id::text,r.name,bad,jsonb_build_object('observed_at',tm,'metric',r.metric,'value',value,'threshold',r.threshold));
   END IF;
  END LOOP;
 END LOOP;
 IF p_data ? 'events' THEN
  IF jsonb_typeof(p_data->'events')<>'array' OR jsonb_array_length(p_data->'events')>100 THEN RAISE EXCEPTION 'At most 100 events per batch'; END IF;
  FOR event IN SELECT jsonb_array_elements(p_data->'events') LOOP
   SELECT * INTO d FROM public.sowrix_def_devices WHERE id=(event->>'device_id')::uuid AND collector_id=c.id AND enabled;
   IF d.id IS NULL THEN RAISE EXCEPTION 'Event device not found'; END IF;
   tm=(event->>'observed_at')::timestamptz;
   IF tm IS NULL OR tm>now()+interval '2 minutes' OR tm<now()-interval '24 hours' THEN RAISE EXCEPTION 'Event timestamp outside window'; END IF;
   INSERT INTO public.sowrix_def_events(organization_id,device_id,source_id,observed_at,severity,source,message)
    VALUES(c.organization_id,d.id,event->>'source_id',tm,event->>'severity',event->>'source',event->>'message') ON CONFLICT DO NOTHING;
   GET DIAGNOSTICS inserted=ROW_COUNT;
   IF inserted>0 AND event->>'severity'='critical' AND tm>now()-interval '5 minutes' THEN
    PERFORM public.sowrix_def_incident(c.organization_id,d.id,'security:'||left(event->>'source',80),
      d.name||': critical security event received',true,
      jsonb_build_object('source_id',event->>'source_id','source',event->>'source','message',event->>'message','observed_at',tm,'untrusted_log_content',true));
   END IF;
  END LOOP;
 END IF;
 UPDATE public.sowrix_def_collectors SET last_sequence=seq WHERE id=c.id;
 RETURN jsonb_build_object('accepted',total,'sequence',seq);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_collector(text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_collector(text,text,jsonb) TO service_role;

-- Verify a viewer against its original provider session as well as current permissions.
CREATE OR REPLACE FUNCTION public.sowrix_def_stream_check(p_id uuid,p_user uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.sowrix_def_streams;
BEGIN
 IF p_user IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Stream owner mismatch' USING ERRCODE='42501'; END IF;
 SELECT * INTO s FROM public.sowrix_def_streams WHERE id=p_id AND user_id=p_user AND expires_at>now() AND revoked_at IS NULL;
 IF s.id IS NULL OR NOT public.sowrix_def_can(s.organization_id,'live')
  OR NOT EXISTS(SELECT 1 FROM public.sowrix_def_orgs WHERE organization_id=s.organization_id AND enabled AND live_enabled)
  OR NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices d JOIN public.sowrix_def_collectors c ON c.id=d.collector_id AND c.status='active'
    JOIN public.clients cl ON cl.id=d.organization_id AND cl.status='active' WHERE d.id=s.device_id AND d.enabled) THEN RAISE EXCEPTION 'Stream access expired or revoked' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('id',s.id,'organization_id',s.organization_id,'device_id',s.device_id);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_stream_check(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_def_stream_check(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_def_maintenance()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE n integer;
BEGIN
 DELETE FROM public.sowrix_def_samples WHERE id IN (SELECT id FROM public.sowrix_def_samples WHERE received_at<now()-interval '24 hours' LIMIT 20000);
 GET DIAGNOSTICS n=ROW_COUNT;
 DELETE FROM public.sowrix_def_events WHERE id IN (SELECT id FROM public.sowrix_def_events WHERE received_at<now()-interval '7 days' LIMIT 20000);
 DELETE FROM public.sowrix_def_sessions WHERE expires_at<now();
 DELETE FROM public.sowrix_def_streams WHERE expires_at<now()-interval '1 day';
 DELETE FROM public.sowrix_def_audit WHERE created_at<now()-interval '180 days';
 UPDATE public.sowrix_def_ai_runs SET status='failed',actual_cents=reserved_cents,result='{"error":"Investigation interrupted; reserved budget retained until reconciliation."}' WHERE status='reserved' AND created_at<now()-interval '15 minutes';
 RETURN jsonb_build_object('samples_pruned',n);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_maintenance() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_maintenance() TO service_role;
CREATE OR REPLACE FUNCTION public.sowrix_def_claim_alerts()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ids uuid[]; result jsonb;
BEGIN
 SELECT array_agg(id) INTO ids FROM (
  SELECT q.id FROM public.sowrix_def_outbox q
  JOIN public.sowrix_def_orgs o ON o.organization_id=q.organization_id AND o.enabled AND cardinality(o.notification_emails)>0
  JOIN public.clients c ON c.id=o.organization_id AND c.status='active'
  WHERE q.next_attempt_at<=now() AND q.attempts<5
   AND (q.status='pending' OR (q.status='sending' AND q.lease_until<now()))
  ORDER BY q.created_at LIMIT 10 FOR UPDATE OF q SKIP LOCKED
 )x;
 UPDATE public.sowrix_def_outbox SET status='sending',attempts=attempts+1,lease_until=now()+interval '5 minutes' WHERE id=ANY(ids);
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',q.id,'attempts',q.attempts,'recipients',o.notification_emails,'title',i.title)),'[]')
 INTO result FROM public.sowrix_def_outbox q JOIN public.sowrix_def_orgs o ON o.organization_id=q.organization_id
 JOIN public.sowrix_def_incidents i ON i.id=q.incident_id WHERE q.id=ANY(ids);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_claim_alerts() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_claim_alerts() TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;


-- Targeted client invitation repair after the matching SOWRIX release 10/11.
-- No accounts or messages are created by this migration. Existing data is preserved.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NULL
 OR to_regprocedure('public.sowrix_client_invite_context(uuid,uuid)') IS NULL
 OR to_regprocedure('public.sowrix_bind_client_login(uuid,uuid,uuid)') IS NULL THEN
  RAISE EXCEPTION 'Matching SOWRIX security foundation is missing. Review the complete backend installation first.';
 END IF;
END $$;

-- Hosted Auth email is varchar; a RETURNS TABLE text column requires an explicit cast.
CREATE OR REPLACE FUNCTION public.sowrix_client_account_picker()
RETURNS TABLE(user_id uuid,email text,full_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF auth.uid() IS NULL OR NOT public.sowrix_access_admin() OR NOT public.sowrix_has_module_access('clients') THEN
  RAISE EXCEPTION 'Client account assignment access required' USING ERRCODE='42501';
 END IF;
 RETURN QUERY SELECT u.id,u.email::text,
  coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'),''),nullif(btrim(u.raw_user_meta_data->>'name'),''),u.email::text)::text
 FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id
 WHERE lower(r.role::text)='client' ORDER BY u.email LIMIT 500;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_client_account_picker() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_client_account_picker() TO authenticated;

-- Caller-JWT gate. The gateway must pass this BEFORE any service-role Auth call.
CREATE OR REPLACE FUNCTION public.sowrix_client_invite_authorize(p_client_id uuid,p_send boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.clients;
BEGIN
 PERFORM public.sowrix_require_secure_session(p_send);
 IF NOT public.sowrix_access_admin() OR NOT public.sowrix_has_module_access('clients')
 OR NOT (public.sowrix_has_permission('clients','create') OR public.sowrix_has_permission('clients','edit')) THEN
  RAISE EXCEPTION 'Administrator client-management access is required' USING ERRCODE='42501';
 END IF;
 SELECT * INTO c FROM public.clients WHERE id=p_client_id;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Client not found or access not permitted' USING ERRCODE='42501'; END IF;
 IF c.status IS DISTINCT FROM 'active' THEN RAISE EXCEPTION 'Activate this client before sending an invitation' USING ERRCODE='22023'; END IF;
 IF coalesce(c.email,'') !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]{2,}$' THEN
  RAISE EXCEPTION 'Save a valid client email before sending an invitation' USING ERRCODE='22023';
 END IF;
 RETURN jsonb_build_object('actor_id',auth.uid(),'client_id',c.id,'email',lower(btrim(c.email)),'linked',c.auth_user_id IS NOT NULL);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_client_invite_authorize(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_client_invite_authorize(uuid,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_client_invite_audit(p_actor_id uuid,p_client_id uuid,p_outcome text,p_provider_id text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' OR p_outcome NOT IN ('accepted','failed','unknown') THEN
  RAISE EXCEPTION 'Trusted invitation worker required' USING ERRCODE='42501';
 END IF;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(p_actor_id,'client_invitation_'||p_outcome,'clients',p_client_id::text,
  jsonb_build_object('email_status',p_outcome,'provider_message_id',left(p_provider_id,120)));
END $$;
REVOKE ALL ON FUNCTION public.sowrix_client_invite_audit(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_client_invite_audit(uuid,uuid,text,text) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

-- Release 13: additive hardening. Apply after 11 and 12, in staging first.
-- Preserves existing sites, device IDs, roles, and monitoring history.
BEGIN;
DO $$
DECLARE predicate text;
BEGIN
 IF to_regprocedure('public.sowrix_client_invite_authorize(uuid,boolean)') IS NULL
 OR to_regprocedure('public.sowrix_def_request(text,uuid,jsonb)') IS NULL THEN
  RAISE EXCEPTION 'Install matching releases 11 and 12 before release 13';
 END IF;
 -- Capture the previously manual client/Super Admin role compatibility repair.
 SELECT pg_get_expr(conbin,conrelid) INTO predicate FROM pg_constraint
 WHERE conrelid='public.user_roles'::regclass AND conname='user_roles_role_check' AND contype='c';
 IF predicate IS NOT NULL AND (position('client' in predicate)=0 OR position('super_admin' in predicate)=0) THEN
  ALTER TABLE public.user_roles DROP CONSTRAINT user_roles_role_check;
  EXECUTE 'ALTER TABLE public.user_roles ADD CONSTRAINT user_roles_role_check CHECK (('
    ||predicate||') OR role::text IN (''client'',''super_admin''))';
 END IF;
 IF to_regprocedure('public.sowrix_def_request_v12(text,uuid,jsonb)') IS NULL THEN
  ALTER FUNCTION public.sowrix_def_request(text,uuid,jsonb) RENAME TO sowrix_def_request_v12;
 END IF;
 IF to_regprocedure('public.sowrix_def_collector_v11(text,text,jsonb)') IS NULL THEN
  ALTER FUNCTION public.sowrix_def_collector(text,text,jsonb) RENAME TO sowrix_def_collector_v11;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_request_v12(text,uuid,jsonb),public.sowrix_def_collector_v11(text,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;

-- Lock by tenant and normalized name; reject new duplicates without deleting old ones.
CREATE OR REPLACE FUNCTION public.sowrix_def_site_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 NEW.name=btrim(NEW.name);
 IF TG_OP='UPDATE' AND NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
  RAISE EXCEPTION 'A site cannot be moved to another organization';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(NEW.organization_id::text||':'||lower(NEW.name),0));
 IF EXISTS(SELECT 1 FROM public.sowrix_def_sites s WHERE s.organization_id=NEW.organization_id
  AND lower(btrim(s.name))=lower(NEW.name) AND s.id<>NEW.id) THEN
  IF TG_OP='INSERT' OR lower(NEW.name) IS DISTINCT FROM lower(btrim(OLD.name)) THEN
   RAISE EXCEPTION 'A site with this name already exists in this organization. Edit the existing site.' USING ERRCODE='23505';
  END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_site_guard() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS sowrix_def_site_guard ON public.sowrix_def_sites;
CREATE TRIGGER sowrix_def_site_guard BEFORE INSERT OR UPDATE ON public.sowrix_def_sites
 FOR EACH ROW EXECUTE FUNCTION public.sowrix_def_site_guard();

ALTER TABLE public.sowrix_def_events ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}';
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.sowrix_def_events'::regclass AND conname='sowrix_def_event_metadata') THEN
  ALTER TABLE public.sowrix_def_events ADD CONSTRAINT sowrix_def_event_metadata
   CHECK(jsonb_typeof(metadata)='object' AND octet_length(metadata::text)<=4096);
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS sowrix_def_events_source_time ON public.sowrix_def_events(organization_id,source,observed_at DESC,id);
CREATE INDEX IF NOT EXISTS sowrix_def_audit_org_time ON public.sowrix_def_audit(organization_id,created_at DESC,id);

-- Local integration metadata remains untrusted evidence, never instructions.
CREATE OR REPLACE FUNCTION public.sowrix_def_collector(p_action text,p_token text,p_data jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e jsonb; m jsonb; result jsonb; cid uuid;
BEGIN
 IF jsonb_typeof(p_data) IS DISTINCT FROM 'object' OR octet_length(p_data::text)>500000 THEN RAISE EXCEPTION 'Invalid collector request'; END IF;
 IF p_data ? 'events' THEN
  IF jsonb_typeof(p_data->'events') IS DISTINCT FROM 'array' OR jsonb_array_length(p_data->'events')>100 THEN RAISE EXCEPTION 'At most 100 events per batch'; END IF;
  FOR e IN SELECT jsonb_array_elements(p_data->'events') LOOP
   m=coalesce(e->'metadata','{}');
   IF jsonb_typeof(m) IS DISTINCT FROM 'object' OR octet_length(m::text)>4096
    OR EXISTS(SELECT 1 FROM jsonb_object_keys(m) k WHERE k NOT IN ('rule_id','category','technique_ids','integration','action','untrusted')) THEN RAISE EXCEPTION 'Invalid event metadata'; END IF;
   IF m ? 'technique_ids' THEN
    IF jsonb_typeof(m->'technique_ids') IS DISTINCT FROM 'array' OR jsonb_array_length(m->'technique_ids')>20
     OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(m->'technique_ids') t WHERE t !~ '^T[0-9]{4}(\.[0-9]{3})?$') THEN RAISE EXCEPTION 'Invalid ATT&CK technique IDs'; END IF;
   END IF;
   IF EXISTS(SELECT 1 FROM jsonb_each(m) v WHERE v.key IN ('rule_id','category','integration','action')
     AND (jsonb_typeof(v.value)<>'string' OR length(v.value::text)>300)) THEN RAISE EXCEPTION 'Invalid integration metadata'; END IF;
  END LOOP;
 END IF;
 result=public.sowrix_def_collector_v11(p_action,p_token,p_data);
 IF p_action='ingest' AND NOT coalesce((result->>'duplicate')::boolean,false) THEN
  SELECT id INTO cid FROM public.sowrix_def_collectors WHERE token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex');
  FOR e IN SELECT jsonb_array_elements(coalesce(p_data->'events','[]')) LOOP
   UPDATE public.sowrix_def_events ev SET metadata=coalesce(e->'metadata','{}')||'{"untrusted":true}'::jsonb
    FROM public.sowrix_def_devices d WHERE d.id=ev.device_id AND d.collector_id=cid
    AND ev.device_id=(e->>'device_id')::uuid AND ev.source_id=e->>'source_id' AND ev.metadata='{}';
  END LOOP;
 END IF;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_collector(text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_collector(text,text,jsonb) TO service_role;

-- Browser-callable operations. Never accept executable SQL, SPL, KQL or commands.
CREATE OR REPLACE FUNCTION public.sowrix_def_request(p_action text,p_org uuid DEFAULT NULL,p_data jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
#variable_conflict use_variable
DECLARE result jsonb; q text; severity text; src text; technique text; dev uuid;
 start_at timestamptz; end_at timestamptz; take integer; skip integer; v_id uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT public.sowrix_secure_session_allowed() THEN RAISE EXCEPTION 'Verified active sign-in required' USING ERRCODE='42501'; END IF;
 IF p_action IS NULL OR jsonb_typeof(p_data) IS DISTINCT FROM 'object' OR octet_length(p_data::text)>20000 THEN RAISE EXCEPTION 'Invalid request'; END IF;
 IF p_action IN ('ai.reserve','stream.create') THEN RAISE EXCEPTION 'Use the authorized gateway endpoint' USING ERRCODE='42501'; END IF;
 IF p_action='context' THEN
  RETURN public.sowrix_def_request_v12(p_action,p_org,p_data)||'{"release":13}'::jsonb;
 END IF;
 IF p_action IN ('events.search','operations.status','audit.list','notification.retry') THEN
  IF p_org IS NULL OR NOT public.sowrix_def_can(p_org,'read') THEN RAISE EXCEPTION 'Resource not found or access not permitted' USING ERRCODE='42501'; END IF;
  IF p_action IN ('operations.status','notification.retry') AND NOT public.sowrix_def_can(p_org,'configure') THEN RAISE EXCEPTION 'Configuration permission required' USING ERRCODE='42501'; END IF;
  IF p_action='events.search' THEN
   IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_data) k WHERE k NOT IN ('query','severity','source','technique_id','device_id','from','to','limit','offset')) THEN RAISE EXCEPTION 'Unsupported search filter. Use the structured filters.'; END IF;
   q=coalesce(p_data->>'query','');severity=nullif(p_data->>'severity','');src=nullif(p_data->>'source','');technique=nullif(p_data->>'technique_id','');dev=nullif(p_data->>'device_id','')::uuid;
   IF length(q)>200 OR length(src)>80 OR (severity IS NOT NULL AND severity NOT IN ('info','warning','critical'))
    OR (technique IS NOT NULL AND technique !~ '^T[0-9]{4}(\.[0-9]{3})?$') THEN RAISE EXCEPTION 'Invalid event filter'; END IF;
   start_at=coalesce(nullif(p_data->>'from','')::timestamptz,now()-interval '7 days');
   end_at=coalesce(nullif(p_data->>'to','')::timestamptz,now()+interval '2 minutes');
   IF end_at<start_at OR end_at-start_at>interval '31 days' THEN RAISE EXCEPTION 'Choose a time range of at most 31 days'; END IF;
   take=greatest(1,least(coalesce((p_data->>'limit')::integer,100),100));skip=greatest(0,least(coalesce((p_data->>'offset')::integer,0),10000));
   SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.observed_at DESC,x.id),'[]') INTO result FROM (
    SELECT e.*,d.name device_name,d.device_code FROM public.sowrix_def_events e
    JOIN public.sowrix_def_devices d ON d.organization_id=e.organization_id AND d.id=e.device_id
    WHERE e.organization_id=p_org AND e.observed_at BETWEEN start_at AND end_at
     AND (severity IS NULL OR e.severity=severity) AND (src IS NULL OR e.source=src)
     AND (dev IS NULL OR e.device_id=dev) AND (technique IS NULL OR e.metadata->'technique_ids' ? technique)
     AND (q='' OR strpos(lower(e.message||' '||e.source||' '||d.name||' '||d.device_code||' '||e.metadata::text),lower(q))>0)
    ORDER BY e.observed_at DESC,e.id LIMIT take OFFSET skip
   ) x;
   PERFORM public.sowrix_def_audit_write(p_org,'events.search',NULL,jsonb_build_object('results',jsonb_array_length(result)));
   RETURN result;
  ELSIF p_action='audit.list' THEN
   IF NOT public.sowrix_def_can(p_org,'members') THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
   SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC,x.id DESC),'[]') INTO result FROM (
    SELECT * FROM public.sowrix_def_audit WHERE organization_id=p_org ORDER BY created_at DESC,id DESC
    LIMIT 100 OFFSET greatest(0,least(coalesce((p_data->>'offset')::integer,0),10000))
   ) x;
   RETURN result;
  ELSIF p_action='notification.retry' THEN
   UPDATE public.sowrix_def_outbox SET status='pending',attempts=0,next_attempt_at=now(),lease_until=NULL
    WHERE organization_id=p_org AND id=(p_data->>'id')::uuid AND status='failed' RETURNING id INTO v_id;
   IF v_id IS NULL THEN RAISE EXCEPTION 'Failed notification not found'; END IF;
   PERFORM public.sowrix_def_audit_write(p_org,p_action,v_id::text);
   RETURN jsonb_build_object('ok',true);
  ELSE
   RETURN jsonb_build_object('release',13,
    'duplicate_site_groups',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (
      SELECT min(name) name,count(*) count FROM public.sowrix_def_sites WHERE organization_id=p_org GROUP BY lower(btrim(name)) HAVING count(*)>1) x),
    'stale_collectors',(SELECT count(*) FROM public.sowrix_def_collectors WHERE organization_id=p_org AND status='active' AND (last_seen IS NULL OR last_seen<now()-interval '3 minutes')),
    'notifications',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (SELECT q.id,q.incident_id,q.status,q.attempts,q.created_at,q.next_attempt_at,q.delivered_at,i.title
      FROM public.sowrix_def_outbox q JOIN public.sowrix_def_incidents i ON i.organization_id=q.organization_id AND i.id=q.incident_id
      WHERE q.organization_id=p_org ORDER BY q.created_at DESC LIMIT 30)x),
    'retention',jsonb_build_object('samples_hours',24,'events_days',7,'audit_days',180),
    'boundary','Configuration checks do not certify production security. Hosted isolation, restore and device tests remain required.');
  END IF;
 END IF;
 RETURN public.sowrix_def_request_v12(p_action,p_org,p_data);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_request(text,uuid,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_def_request(text,uuid,jsonb) TO authenticated;

-- Only the server can reserve provider spending or create a media secret.
-- Claims come from a previously Auth-verified, encrypted server session.
-- The private implementation still rechecks Auth session, MFA and current roles.
CREATE OR REPLACE FUNCTION public.sowrix_def_internal_request(p_action text,p_org uuid,p_data jsonb,p_claims jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb; old_claims text:=current_setting('request.jwt.claims',true);
 old_sub text:=current_setting('request.jwt.claim.sub',true); old_role text:=current_setting('request.jwt.claim.role',true);
BEGIN
 IF p_action NOT IN ('ai.reserve','stream.create') OR p_action IS NULL
  OR p_claims->>'role' IS DISTINCT FROM 'authenticated' OR nullif(p_claims->>'sub','') IS NULL
  OR coalesce((p_claims->>'exp')::numeric,0)<extract(epoch FROM now())
  OR jsonb_typeof(p_data) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Invalid trusted request' USING ERRCODE='42501'; END IF;
 PERFORM set_config('request.jwt.claims',p_claims::text,true),set_config('request.jwt.claim.sub',p_claims->>'sub',true),set_config('request.jwt.claim.role','authenticated',true);
 result=public.sowrix_def_request_v12(p_action,p_org,p_data);
 PERFORM set_config('request.jwt.claims',coalesce(old_claims,''),true),set_config('request.jwt.claim.sub',coalesce(old_sub,''),true),set_config('request.jwt.claim.role',coalesce(old_role,''),true);
 RETURN result;
EXCEPTION WHEN OTHERS THEN
 PERFORM set_config('request.jwt.claims',coalesce(old_claims,''),true),set_config('request.jwt.claim.sub',coalesce(old_sub,''),true),set_config('request.jwt.claim.role',coalesce(old_role,''),true);
 RAISE;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_internal_request(text,uuid,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_internal_request(text,uuid,jsonb,jsonb) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

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

-- R16 additive work assignment and recipient-scoped notifications.
-- Apply after foundation -> 11 -> 12 -> 13 -> 15 in STAGING first. No resets.
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.sowrix_amc_contracts') IS NULL OR to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NULL THEN
  RAISE EXCEPTION 'R16 requires the existing security foundation and AMC migration 15';
 END IF;
END $$;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS assigned_to uuid REFERENCES auth.users(id);
CREATE TABLE IF NOT EXISTS public.sowrix_work_catalog(
 module text PRIMARY KEY, table_name text NOT NULL UNIQUE, assignee_field text NOT NULL
);
INSERT INTO public.sowrix_work_catalog VALUES
 ('clients','clients','assigned_to'),('projects','projects','manager_id'),('tasks','tasks','assignee_id'),
 ('tickets','support_tickets','assignee_id'),('enquiries','contact_enquiries','assigned_to'),
 ('applications','job_applications','reviewer_id'),('interviews','interviews','interviewer_id')
ON CONFLICT DO NOTHING;
ALTER TABLE public.sowrix_work_catalog ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_work_catalog FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS public.sowrix_staff_org_scopes(
 user_id uuid NOT NULL REFERENCES auth.users(id), organization_id uuid NOT NULL REFERENCES public.clients(id),
 module text NOT NULL REFERENCES public.sowrix_work_catalog(module), enabled boolean NOT NULL DEFAULT true,
 granted_by uuid REFERENCES auth.users(id), updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,organization_id,module)
);
ALTER TABLE public.sowrix_staff_org_scopes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_staff_org_scopes FROM PUBLIC,anon,authenticated;
-- Existing permission profiles, not new global Support/Finance roles.
UPDATE public.sowrix_permission_catalog SET actions=array_append(actions,'assign')
 WHERE module_key IN (SELECT module FROM public.sowrix_work_catalog) AND NOT ('assign'=ANY(actions));
-- Enquiry staff must be explicitly granted view/edit/assign; no grants are seeded.
UPDATE public.sowrix_permission_catalog SET admin_only=false WHERE module_key='enquiries';
UPDATE public.sowrix_access_modules SET allowed_roles=ARRAY['hr','hr_staff','hr_manager','employee','project_manager'] WHERE module_key='enquiries';

CREATE OR REPLACE FUNCTION public.sowrix_user_active(p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id
 WHERE u.id=p_user AND u.deleted_at IS NULL AND (u.banned_until IS NULL OR u.banned_until<=now()))
 AND NOT EXISTS(SELECT 1 FROM public.sowrix_account_security s WHERE s.user_id=p_user AND s.disabled_at IS NOT NULL)
 AND NOT EXISTS(SELECT 1 FROM public.employees e WHERE e.user_id=p_user AND lower(e.employment_status) IN ('inactive','terminated','suspended'))
$$;
CREATE OR REPLACE FUNCTION public.sowrix_user_permission(p_user uuid,p_module text,p_action text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_user_active(p_user) AND EXISTS(
 SELECT 1 FROM public.user_roles r CROSS JOIN public.sowrix_permission_catalog c
 WHERE r.user_id=p_user AND c.module_key=p_module AND p_action=ANY(c.actions) AND
 (lower(r.role::text) IN ('admin','super_admin') OR
 (NOT c.admin_only AND NOT(p_module='attendance' AND p_action<>'view') AND
 EXISTS(SELECT 1 FROM public.sowrix_action_grants g WHERE g.user_id=p_user AND g.module_key=p_module AND 'view'=ANY(g.actions) AND p_action=ANY(g.actions)))))
$$;
CREATE OR REPLACE FUNCTION public.sowrix_staff_eligible(p_user uuid,p_module text,p_org uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_user_permission(p_user,p_module,'view') AND EXISTS(SELECT 1 FROM public.user_roles r
 WHERE r.user_id=p_user AND lower(r.role::text) IN ('super_admin','admin','hr','hr_manager','hr_staff','employee','project_manager')
 AND (p_org IS NULL OR (EXISTS(SELECT 1 FROM public.clients c WHERE c.id=p_org AND c.status='active') AND
 (lower(r.role::text) IN ('admin','super_admin') OR
 EXISTS(SELECT 1 FROM public.sowrix_action_grants g JOIN public.sowrix_permission_catalog pc USING(module_key)
 WHERE g.user_id=p_user AND g.module_key=p_module AND g.row_scope='all' AND pc.allow_wide) OR
 EXISTS(SELECT 1 FROM public.sowrix_staff_org_scopes s WHERE s.user_id=p_user AND s.module=p_module AND s.organization_id=p_org AND s.enabled)))))
$$;
CREATE OR REPLACE FUNCTION public.sowrix_work_org(p_module text,p_row jsonb) RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result uuid;
BEGIN
 IF p_module='clients' THEN RETURN (p_row->>'id')::uuid; END IF;
 IF p_module='tasks' THEN SELECT p.client_id INTO result FROM public.projects p WHERE p.id=(p_row->>'project_id')::uuid;RETURN result; END IF;
 RETURN nullif(p_row->>'client_id','')::uuid;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_work_row(p_module text,p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE t text;r jsonb; BEGIN
 SELECT table_name INTO t FROM public.sowrix_work_catalog WHERE module=p_module;
 IF t IS NULL THEN
  t:=CASE p_module WHEN 'leaves' THEN 'leave_requests' WHEN 'attendance' THEN 'attendance_records' WHEN 'invoices' THEN 'invoices' WHEN 'amc' THEN 'sowrix_amc_contracts' WHEN 'documents' THEN 'sowrix_ui_records' WHEN 'legacy' THEN 'notifications' END;
 END IF;
 IF t IS NULL THEN RETURN NULL; END IF;
 EXECUTE format('SELECT to_jsonb(r) FROM public.%I r WHERE id=$1',t) INTO r USING p_id;RETURN r;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_user_record_access(p_user uuid,p_module text,p_row jsonb) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE r text;f text;org uuid; BEGIN
 IF p_module='legacy' THEN RETURN public.sowrix_user_active(p_user) AND p_row->>'user_id'=p_user::text;END IF;
 IF p_row IS NULL OR NOT public.sowrix_user_permission(p_user,p_module,'view') THEN RETURN false; END IF;
 SELECT lower(role::text) INTO r FROM public.user_roles WHERE user_id=p_user;
 IF r IN ('admin','super_admin') THEN RETURN true; END IF;
 org:=public.sowrix_work_org(p_module,p_row);
 IF r='client' THEN
  RETURN p_module IN ('clients','projects','tickets','invoices','amc')
   AND (p_module NOT IN ('invoices','amc') OR p_row->>'status'<>'draft')
   AND EXISTS(SELECT 1 FROM public.sowrix_org_memberships m JOIN public.clients c ON c.id=m.organization_id
    WHERE m.user_id=p_user AND m.organization_id=org AND m.status='active' AND c.status='active'
    AND (p_module NOT IN ('invoices','amc') OR m.member_role='owner' OR m.billing_access));
 END IF;
 IF EXISTS(SELECT 1 FROM public.sowrix_action_grants g JOIN public.sowrix_permission_catalog c USING(module_key)
  WHERE g.user_id=p_user AND g.module_key=p_module AND g.row_scope='all' AND c.allow_wide) THEN RETURN true; END IF;
 IF p_module IN ('attendance','leaves') THEN RETURN p_row->>'employee_user_id'=p_user::text OR r IN ('hr','hr_staff','hr_manager'); END IF;
 IF p_module='documents' THEN RETURN p_row->>'owner_id'=p_user::text OR r IN ('hr','hr_staff','hr_manager'); END IF;
 IF p_module IN ('applications','interviews') AND r IN ('hr','hr_staff','hr_manager') THEN RETURN true; END IF;
 IF NOT public.sowrix_staff_eligible(p_user,p_module,org) THEN RETURN false; END IF;
 SELECT assignee_field INTO f FROM public.sowrix_work_catalog WHERE module=p_module;
 IF p_row->>f=p_user::text THEN RETURN true; END IF;
 IF p_module='tickets' AND p_row->>'requester_id'=p_user::text THEN RETURN true; END IF;
 IF p_module='projects' THEN RETURN EXISTS(SELECT 1 FROM public.tasks t WHERE t.project_id=(p_row->>'id')::uuid AND t.assignee_id=p_user AND public.sowrix_staff_eligible(p_user,'tasks',org));END IF;
 IF p_module='tasks' THEN RETURN EXISTS(SELECT 1 FROM public.projects p WHERE p.id=(p_row->>'project_id')::uuid AND p.manager_id=p_user); END IF;
 RETURN false;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_assignment_access(p_module text,p_row jsonb) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_secure_session_allowed() AND public.sowrix_access_role()<>'client'
 AND public.sowrix_user_record_access(auth.uid(),p_module,p_row)
$$;
CREATE OR REPLACE FUNCTION public.sowrix_user_record_visible(p_module text,p_row jsonb) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_secure_session_allowed() AND public.sowrix_user_record_access(auth.uid(),p_module,p_row)
$$;
REVOKE ALL ON FUNCTION public.sowrix_user_record_visible(text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_user_record_visible(text,jsonb) TO authenticated;
-- Add assignment-based access to both legacy permissive and restrictive SELECT scopes.
-- Existing independent scope remains; the secure-session and action gates remain intact.
DO $$ DECLARE r record;p record;expr text;BEGIN
 FOR r IN SELECT * FROM public.sowrix_work_catalog LOOP
  expr:=format('public.sowrix_assignment_access(%L,to_jsonb(%I))',r.module,r.table_name);
  FOR p IN SELECT * FROM pg_policies WHERE schemaname='public' AND tablename=r.table_name AND policyname IN ('sowrix_v3_select_allow','sowrix_v3_select_scope','sowrix_consultation_admin_read') LOOP
   IF position('sowrix_assignment_access' in coalesce(p.qual,''))=0 THEN
    EXECUTE format('ALTER POLICY %I ON public.%I USING ((%s) OR (%s))',p.policyname,r.table_name,coalesce(p.qual,'false'),expr);
   END IF;
  END LOOP;
  EXECUTE format('DROP POLICY IF EXISTS sowrix_work_read ON public.%I',r.table_name);
  EXECUTE format('CREATE POLICY sowrix_work_read ON public.%I FOR SELECT TO authenticated USING (%s)',r.table_name,expr);
  EXECUTE format('DROP POLICY IF EXISTS sowrix_work_current_scope ON public.%I',r.table_name);
  EXECUTE format('CREATE POLICY sowrix_work_current_scope ON public.%I AS RESTRICTIVE FOR SELECT TO authenticated USING (public.sowrix_user_record_visible(%L,to_jsonb(%I)))',r.table_name,r.module,r.table_name);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_assignment_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m text;f text;n jsonb:=to_jsonb(NEW);o jsonb;org uuid;uid uuid;BEGIN
 SELECT module,assignee_field INTO m,f FROM public.sowrix_work_catalog WHERE table_name=TG_TABLE_NAME;
 IF TG_OP='UPDATE' THEN o:=to_jsonb(OLD);END IF;
 uid:=nullif(n->>f,'')::uuid;org:=public.sowrix_work_org(m,n);
 IF TG_OP='UPDATE' AND (n->>'client_id' IS DISTINCT FROM o->>'client_id' OR (m='tasks' AND n->>'project_id' IS DISTINCT FROM o->>'project_id')) THEN
  IF n->>'client_id' IS DISTINCT FROM o->>'client_id' OR uid IS NOT NULL THEN RAISE EXCEPTION 'Unassign first; tenant changes require a separate reviewed migration' USING ERRCODE='42501';END IF;
 END IF;
 IF TG_OP='UPDATE' AND auth.uid() IS NOT NULL AND auth.role()<>'service_role'
 AND NOT public.sowrix_access_admin() AND NOT public.sowrix_wide_access(m,'edit')
 AND NOT(m IN ('applications','interviews') AND public.sowrix_access_role() IN ('hr','hr_staff','hr_manager'))
 AND NOT(m='projects' AND public.sowrix_access_role()='project_manager' AND o->>f=auth.uid()::text)
 AND (n-ARRAY['status','updated_at','completed_at',f]) IS DISTINCT FROM (o-ARRAY['status','updated_at','completed_at',f]) THEN
  RAISE EXCEPTION 'Assigned staff can update permitted status fields only' USING ERRCODE='42501';
 END IF;
 IF (TG_OP='INSERT' AND uid IS NOT NULL) OR (TG_OP='UPDATE' AND n->>f IS DISTINCT FROM o->>f) THEN
  IF auth.role()<>'service_role' AND auth.uid() IS NOT NULL THEN
   PERFORM public.sowrix_require_secure_session(false);
   IF NOT public.sowrix_has_permission(m,'assign') OR public.sowrix_access_role()='client' THEN RAISE EXCEPTION 'Assignment permission required' USING ERRCODE='42501';END IF;
  ELSIF auth.role()<>'service_role' AND current_setting('role',true) IN ('anon','authenticated') THEN
   RAISE EXCEPTION 'Assignment requires authentication' USING ERRCODE='42501';
  END IF;
  IF uid IS NOT NULL AND NOT public.sowrix_staff_eligible(uid,m,org) THEN RAISE EXCEPTION 'Assignee must be active and authorized for this module and organization' USING ERRCODE='42501';END IF;
 END IF;
 RETURN NEW;
END $$;
DO $$ DECLARE r record;BEGIN FOR r IN SELECT * FROM public.sowrix_work_catalog LOOP
 EXECUTE format('DROP TRIGGER IF EXISTS sowrix_work_guard ON public.%I',r.table_name);
 EXECUTE format('CREATE TRIGGER sowrix_work_guard BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.sowrix_assignment_guard()',r.table_name);
 EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON public.%I(%I,id)', 'sowrix_work_'||r.module,r.table_name,r.assignee_field);
END LOOP;END $$;

DO $$ DECLARE r record;cols text;BEGIN
 FOR r IN SELECT * FROM public.sowrix_work_catalog LOOP
  SELECT string_agg(quote_ident(column_name),',') INTO cols FROM information_schema.columns WHERE table_schema='public' AND table_name=r.table_name AND column_name<>r.assignee_field;
  EXECUTE format('REVOKE UPDATE ON public.%I FROM authenticated',r.table_name);
  EXECUTE format('REVOKE UPDATE(%I) ON public.%I FROM authenticated',r.assignee_field,r.table_name);
  EXECUTE format('GRANT UPDATE(%s) ON public.%I TO authenticated',cols,r.table_name);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_work_candidates(p_module text,p_id uuid,p_search text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE rec jsonb;org uuid;BEGIN
 PERFORM public.sowrix_require_secure_session(false);rec:=public.sowrix_work_row(p_module,p_id);
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_work_catalog WHERE module=p_module) OR NOT public.sowrix_has_permission(p_module,'assign')
 OR public.sowrix_access_role()='client' OR NOT public.sowrix_user_record_access(auth.uid(),p_module,rec) THEN RAISE EXCEPTION 'Record not available for assignment' USING ERRCODE='42501';END IF;
 org:=public.sowrix_work_org(p_module,rec);
 RETURN coalesce((SELECT jsonb_agg(x) FROM(SELECT u.id AS user_id,i.v->>'full_name' AS full_name,i.v->>'employee_code' AS employee_code,lower(r.role::text) AS role
 FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id CROSS JOIN LATERAL(SELECT public.sowrix_identity_internal(u.id) v)i
 WHERE public.sowrix_staff_eligible(u.id,p_module,org) AND (coalesce(p_search,'')='' OR concat(i.v->>'full_name',' ',i.v->>'employee_code',' ',r.role::text) ILIKE '%'||left(p_search,100)||'%')
 ORDER BY i.v->>'full_name',u.id LIMIT 100)x),'[]'::jsonb);
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_assign_work(p_module text,p_id uuid,p_assignee uuid,p_expected_updated_at timestamptz) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE t text;f text;rec jsonb;result jsonb;BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 SELECT table_name,assignee_field INTO t,f FROM public.sowrix_work_catalog WHERE module=p_module;
 IF t IS NULL OR public.sowrix_access_role()='client' OR NOT public.sowrix_has_permission(p_module,'assign') THEN RAISE EXCEPTION 'Assignment permission required' USING ERRCODE='42501';END IF;
 EXECUTE format('SELECT to_jsonb(r) FROM public.%I r WHERE id=$1 FOR UPDATE',t) INTO rec USING p_id;
 IF NOT public.sowrix_user_record_access(auth.uid(),p_module,rec) THEN RAISE EXCEPTION 'Record not available' USING ERRCODE='42501';END IF;
 IF p_expected_updated_at IS NULL OR (rec->>'updated_at')::timestamptz IS DISTINCT FROM p_expected_updated_at THEN RAISE EXCEPTION 'Record changed. Refresh before assigning.' USING ERRCODE='40001';END IF;
 EXECUTE format('UPDATE public.%I SET %I=$1,updated_at=clock_timestamp() WHERE id=$2 RETURNING to_jsonb(%I)',t,f,t) INTO result USING p_assignee,p_id;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_work_status(p_module text,p_id uuid,p_status text,p_expected_updated_at timestamptz) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE t text;f text;r jsonb;result jsonb;allowed text[];BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 SELECT table_name,assignee_field INTO t,f FROM public.sowrix_work_catalog WHERE module=p_module;
 allowed:=CASE p_module WHEN 'tasks' THEN ARRAY['todo','in_progress','blocked','done','cancelled'] WHEN 'tickets' THEN ARRAY['open','in_progress','waiting','resolved','closed'] WHEN 'projects' THEN ARRAY['planned','active','on_hold','completed','archived'] WHEN 'enquiries' THEN ARRAY['open','in_progress','resolved','spam','archived'] WHEN 'clients' THEN ARRAY['active','inactive','archived'] WHEN 'applications' THEN ARRAY['applied','under_review','shortlisted','interview_scheduled','selected','rejected','hired'] WHEN 'interviews' THEN ARRAY['scheduled','completed','cancelled','no_show'] ELSE '{}'::text[] END;
 IF t IS NULL OR NOT(p_status=ANY(allowed)) OR NOT public.sowrix_has_permission(p_module,'edit') OR public.sowrix_access_role()='client' THEN RAISE EXCEPTION 'Status update unavailable' USING ERRCODE='42501';END IF;
 EXECUTE format('SELECT to_jsonb(r) FROM public.%I r WHERE id=$1 FOR UPDATE',t) INTO r USING p_id;
 IF NOT public.sowrix_user_record_access(auth.uid(),p_module,r) OR (r->>f IS DISTINCT FROM auth.uid()::text AND NOT public.sowrix_access_admin() AND NOT public.sowrix_wide_access(p_module,'edit')) THEN RAISE EXCEPTION 'Record not available' USING ERRCODE='42501';END IF;
 IF p_expected_updated_at IS NULL OR (r->>'updated_at')::timestamptz IS DISTINCT FROM p_expected_updated_at THEN RAISE EXCEPTION 'Record changed. Refresh before updating.' USING ERRCODE='40001';END IF;
 EXECUTE format('UPDATE public.%I SET status=$1,updated_at=clock_timestamp()%s WHERE id=$2 RETURNING to_jsonb(%I)',t,CASE WHEN p_module='tasks' THEN ',completed_at=CASE WHEN $1=''done'' THEN coalesce(completed_at,now()) ELSE NULL END' ELSE '' END,t) INTO result USING p_status,p_id;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_set_staff_scope(p_user uuid,p_organization uuid,p_module text,p_enabled boolean,p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.sowrix_require_secure_session(true);
 IF NOT public.sowrix_access_admin() OR length(btrim(p_reason)) NOT BETWEEN 5 AND 500 THEN RAISE EXCEPTION 'Admin and reason required' USING ERRCODE='42501';END IF;
 IF NOT public.sowrix_user_active(p_user) OR NOT EXISTS(SELECT 1 FROM public.user_roles WHERE user_id=p_user AND role::text<>'client') THEN RAISE EXCEPTION 'Active staff required';END IF;
 INSERT INTO public.sowrix_staff_org_scopes(user_id,organization_id,module,enabled,granted_by) VALUES(p_user,p_organization,p_module,p_enabled,auth.uid())
 ON CONFLICT(user_id,organization_id,module) DO UPDATE SET enabled=excluded.enabled,granted_by=excluded.granted_by,updated_at=clock_timestamp();
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details) VALUES(auth.uid(),'staff_scope','assignment',p_user::text,jsonb_build_object('organization',p_organization,'module',p_module,'enabled',p_enabled,'reason',p_reason));
END $$;

CREATE TABLE IF NOT EXISTS public.sowrix_business_events(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),module text NOT NULL,record_id uuid NOT NULL,
 kind text NOT NULL,event_key text NOT NULL,actor_id uuid,created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(module,record_id,event_key)
);
CREATE TABLE IF NOT EXISTS public.sowrix_business_notifications(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),event_id uuid NOT NULL REFERENCES public.sowrix_business_events(id),
 user_id uuid NOT NULL REFERENCES auth.users(id),read_at timestamptz,created_at timestamptz NOT NULL DEFAULT now(),
 detached boolean NOT NULL DEFAULT false,UNIQUE(event_id,user_id)
);
CREATE INDEX IF NOT EXISTS sowrix_business_inbox ON public.sowrix_business_notifications(user_id,created_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS sowrix_business_unread ON public.sowrix_business_notifications(user_id) WHERE read_at IS NULL;
CREATE TABLE IF NOT EXISTS public.sowrix_notification_preferences(
 user_id uuid PRIMARY KEY REFERENCES auth.users(id),email_enabled boolean NOT NULL DEFAULT false
);
CREATE TABLE IF NOT EXISTS public.sowrix_event_recipients(
 module text NOT NULL REFERENCES public.sowrix_permission_catalog(module_key),user_id uuid NOT NULL REFERENCES auth.users(id),
 PRIMARY KEY(module,user_id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_business_outbox(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),notification_id uuid NOT NULL UNIQUE REFERENCES public.sowrix_business_notifications(id),
 status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','processing','accepted','delivered','failed','exhausted','cancelled')),
 attempts integer NOT NULL DEFAULT 0,lease_token uuid,lease_until timestamptz,next_attempt_at timestamptz NOT NULL DEFAULT now(),
 provider_id text,last_error text,accepted_at timestamptz,delivered_at timestamptz,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sowrix_business_outbox_due ON public.sowrix_business_outbox(next_attempt_at) WHERE status IN ('queued','processing','failed');
DO $$ DECLARE t text;BEGIN
 FOREACH t IN ARRAY ARRAY['sowrix_business_events','sowrix_business_notifications','sowrix_notification_preferences','sowrix_event_recipients','sowrix_business_outbox'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
 END LOOP;
END $$;
-- Preserve historical notifications while enforcing owner-only reads, including Admin.
DROP POLICY IF EXISTS sowrix_notification_owner ON public.notifications;
CREATE POLICY sowrix_notification_owner ON public.notifications AS RESTRICTIVE FOR ALL TO authenticated USING(user_id=auth.uid()) WITH CHECK(user_id=auth.uid());
REVOKE INSERT,UPDATE,DELETE ON public.notifications FROM authenticated;
DROP TRIGGER IF EXISTS sowrix_ui_task_notification ON public.tasks;
DROP TRIGGER IF EXISTS sowrix_ui_leave_notification ON public.leave_requests;

CREATE OR REPLACE FUNCTION public.sowrix_emit_event(p_module text,p_record uuid,p_kind text,p_key text,p_users uuid[],p_old uuid DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE eid uuid;uid uuid;nid uuid;rec jsonb;BEGIN
 INSERT INTO public.sowrix_business_events(module,record_id,kind,event_key,actor_id) VALUES(p_module,p_record,p_kind,p_key,auth.uid())
 ON CONFLICT(module,record_id,event_key) DO NOTHING RETURNING id INTO eid;
 IF eid IS NULL THEN RETURN NULL;END IF;
 rec:=public.sowrix_work_row(p_module,p_record);
 FOR uid IN SELECT DISTINCT x FROM unnest(coalesce(p_users,'{}'::uuid[])||ARRAY[p_old])x WHERE x IS NOT NULL LOOP
  IF public.sowrix_user_active(uid) AND (uid=p_old OR public.sowrix_user_record_access(uid,p_module,rec)) THEN
   INSERT INTO public.sowrix_business_notifications(event_id,user_id,detached) VALUES(eid,uid,uid IS NOT DISTINCT FROM p_old) RETURNING id INTO nid;
   -- Queue durably; recipient preferences and access are checked again at claim/send.
   INSERT INTO public.sowrix_business_outbox(notification_id) VALUES(nid);
  END IF;
 END LOOP;
 RETURN eid;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_business_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m text:=TG_ARGV[0];n jsonb:=to_jsonb(NEW);o jsonb;f text;old_uid uuid;new_uid uuid;recipients uuid[]:='{}';kind text;key text;uid uuid;BEGIN
 IF TG_OP='UPDATE' THEN o:=to_jsonb(OLD);END IF;
 SELECT assignee_field INTO f FROM public.sowrix_work_catalog WHERE module=m;
 new_uid:=nullif(n->>f,'')::uuid;old_uid:=nullif(o->>f,'')::uuid;
 kind:=CASE WHEN TG_OP='INSERT' THEN 'created' WHEN new_uid IS DISTINCT FROM old_uid THEN 'reassigned' WHEN n->>'status' IS DISTINCT FROM o->>'status' THEN 'status_changed' WHEN n->>'due_date' IS DISTINCT FROM o->>'due_date' OR n->>'ends_on' IS DISTINCT FROM o->>'ends_on' THEN 'schedule_changed' ELSE NULL END;
 IF kind IS NULL THEN RETURN NEW;END IF;
 key:=TG_OP||':'||coalesce(n->>'updated_at',clock_timestamp()::text)||':'||kind;
 IF new_uid IS NOT NULL THEN recipients:=array_append(recipients,new_uid);END IF;
 IF m='tickets' THEN recipients:=array_append(recipients,(n->>'requester_id')::uuid);END IF;
 IF m IN ('attendance','leaves') THEN recipients:=array_append(recipients,(n->>'employee_user_id')::uuid);END IF;
 SELECT recipients||coalesce(array_agg(r.user_id),'{}'::uuid[]) INTO recipients FROM public.sowrix_event_recipients r WHERE r.module=m;
 IF m IN ('invoices','amc','projects','tickets') THEN
  SELECT recipients||coalesce(array_agg(s.user_id),'{}'::uuid[]) INTO recipients FROM public.sowrix_org_memberships s WHERE s.organization_id=(n->>'client_id')::uuid AND s.status='active';
 END IF;
 IF m IN ('invoices','amc') AND n->>'status'='draft' THEN
  SELECT coalesce(array_agg(x),'{}') INTO recipients FROM unnest(recipients)x JOIN public.user_roles r ON r.user_id=x WHERE r.role::text<>'client';
 END IF;
 PERFORM public.sowrix_emit_event(m,(n->>'id')::uuid,kind,key,recipients,CASE WHEN new_uid IS DISTINCT FROM old_uid THEN old_uid ELSE NULL END);
 IF new_uid IS DISTINCT FROM old_uid THEN
  INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details) VALUES(auth.uid(),'assignment',m,n->>'id',jsonb_build_object('previous_assignee',old_uid,'new_assignee',new_uid));
 END IF;
 RETURN NEW;
END $$;
DO $$ DECLARE r record;BEGIN
 FOR r IN SELECT module,table_name FROM public.sowrix_work_catalog UNION ALL SELECT * FROM(VALUES('attendance','attendance_records'),('leaves','leave_requests'),('invoices','invoices'),('amc','sowrix_amc_contracts'))v(module,table_name) LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS sowrix_business_change ON public.%I',r.table_name);
  EXECUTE format('CREATE TRIGGER sowrix_business_change AFTER INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.sowrix_business_change(%L)',r.table_name,r.module);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_inbox(p_limit integer DEFAULT 25,p_before timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF p_limit NOT BETWEEN 1 AND 100 OR (p_before IS NULL)<>(p_before_id IS NULL) THEN RAISE EXCEPTION 'Invalid inbox page';END IF;
 SELECT jsonb_build_object('unread',(SELECT count(*) FROM public.sowrix_business_notifications WHERE user_id=auth.uid() AND read_at IS NULL),
 'email_enabled',coalesce((SELECT email_enabled FROM public.sowrix_notification_preferences WHERE user_id=auth.uid()),false),
 'items',coalesce(jsonb_agg(x ORDER BY x.created_at DESC,x.id DESC),'[]'::jsonb)) INTO result FROM(
 SELECT n.id,n.created_at,n.read_at,e.kind,e.module,
 CASE WHEN e.module='legacy' THEN public.sowrix_work_row('legacy',e.record_id)->>'body' ELSE NULL END AS body,
 CASE WHEN e.module<>'legacy' AND NOT n.detached AND public.sowrix_user_record_access(auth.uid(),e.module,public.sowrix_work_row(e.module,e.record_id)) THEN e.record_id ELSE NULL END AS record_id,
 CASE WHEN e.module='legacy' THEN coalesce(public.sowrix_work_row('legacy',e.record_id)->>'title','Previous notification') WHEN n.detached THEN 'Assignment removed' WHEN public.sowrix_user_record_access(auth.uid(),e.module,public.sowrix_work_row(e.module,e.record_id)) THEN 'SOWRIX work update' ELSE 'Record no longer available' END AS title
 FROM public.sowrix_business_notifications n JOIN public.sowrix_business_events e ON e.id=n.event_id
 WHERE n.user_id=auth.uid() AND (p_before IS NULL OR (n.created_at,n.id)<(p_before,p_before_id))
 ORDER BY n.created_at DESC,n.id DESC LIMIT p_limit)x;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_inbox_read(p_ids uuid[] DEFAULT NULL,p_read boolean DEFAULT true,p_all_before timestamptz DEFAULT NULL) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE changed integer;BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF coalesce(cardinality(p_ids),0)>100 OR (p_ids IS NULL AND (p_all_before IS NULL OR NOT p_read)) THEN RAISE EXCEPTION 'Select notifications or a mark-all-read cutoff';END IF;
 UPDATE public.sowrix_business_notifications SET read_at=CASE WHEN p_read THEN now() ELSE NULL END
 WHERE user_id=auth.uid() AND ((p_ids IS NOT NULL AND id=ANY(p_ids)) OR (p_ids IS NULL AND created_at<=p_all_before));
 GET DIAGNOSTICS changed=ROW_COUNT;RETURN changed;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_inbox_preferences(p_email_enabled boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 INSERT INTO public.sowrix_notification_preferences VALUES(auth.uid(),p_email_enabled) ON CONFLICT(user_id) DO UPDATE SET email_enabled=excluded.email_enabled;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_inbox_open(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.sowrix_business_events;n public.sowrix_business_notifications;BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 SELECT * INTO n FROM public.sowrix_business_notifications WHERE id=p_id AND user_id=auth.uid();
 SELECT * INTO e FROM public.sowrix_business_events WHERE id=n.event_id;
 IF n.id IS NULL OR n.detached OR NOT public.sowrix_user_record_access(auth.uid(),e.module,public.sowrix_work_row(e.module,e.record_id)) THEN RETURN jsonb_build_object('available',false);END IF;
 RETURN jsonb_build_object('available',true,'module',e.module,'record_id',e.record_id);
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_set_event_recipient(p_module text,p_user uuid,p_enabled boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 PERFORM public.sowrix_require_secure_session(true);
 IF NOT public.sowrix_access_admin() OR NOT public.sowrix_user_permission(p_user,p_module,'view') OR EXISTS(SELECT 1 FROM public.user_roles WHERE user_id=p_user AND role::text='client') THEN RAISE EXCEPTION 'Admin and authorized responsible staff required' USING ERRCODE='42501';END IF;
 IF p_enabled THEN INSERT INTO public.sowrix_event_recipients VALUES(p_module,p_user) ON CONFLICT DO NOTHING;
 ELSE DELETE FROM public.sowrix_event_recipients WHERE module=p_module AND user_id=p_user;END IF;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details) VALUES(auth.uid(),'event_recipient','notifications',p_user::text,jsonb_build_object('module',p_module,'enabled',p_enabled));
END $$;
-- Preserve existing personal inbox history without replaying emails.
INSERT INTO public.sowrix_business_events(module,record_id,kind,event_key,created_at)
 SELECT 'legacy',id,category,'legacy-import',created_at FROM public.notifications ON CONFLICT DO NOTHING;
INSERT INTO public.sowrix_business_notifications(event_id,user_id,read_at,created_at)
 SELECT e.id,n.user_id,n.read_at,n.created_at FROM public.notifications n JOIN public.sowrix_business_events e ON e.module='legacy' AND e.record_id=n.id
 ON CONFLICT(event_id,user_id) DO NOTHING;
-- Internal service role only. SKIP LOCKED + lease token fences stale workers.
CREATE OR REPLACE FUNCTION public.sowrix_claim_business_mail(p_limit integer DEFAULT 20) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb:='[]';j record;token uuid;mail text;BEGIN
 IF auth.role()<>'service_role' THEN RAISE EXCEPTION 'Server worker required' USING ERRCODE='42501';END IF;
 IF p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'Invalid batch';END IF;
 FOR j IN SELECT o.*,n.user_id,n.detached,e.module,e.record_id FROM public.sowrix_business_outbox o
 JOIN public.sowrix_business_notifications n ON n.id=o.notification_id JOIN public.sowrix_business_events e ON e.id=n.event_id
 WHERE ((o.status IN ('queued','failed') AND o.next_attempt_at<=now()) OR (o.status='processing' AND o.lease_until<now())) AND o.attempts<5
 ORDER BY o.next_attempt_at,o.id LIMIT p_limit FOR UPDATE OF o SKIP LOCKED LOOP
  IF NOT public.sowrix_user_active(j.user_id) OR NOT coalesce((SELECT email_enabled FROM public.sowrix_notification_preferences WHERE user_id=j.user_id),false)
   OR (NOT j.detached AND NOT public.sowrix_user_record_access(j.user_id,j.module,public.sowrix_work_row(j.module,j.record_id))) THEN
   UPDATE public.sowrix_business_outbox SET status='cancelled',lease_token=NULL,lease_until=NULL,last_error='preference_or_access' WHERE id=j.id;CONTINUE;
  END IF;
  SELECT email INTO mail FROM auth.users WHERE id=j.user_id;
  IF mail IS NULL OR mail !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN UPDATE public.sowrix_business_outbox SET status='cancelled',last_error='recipient_unavailable' WHERE id=j.id;CONTINUE;END IF;
  IF j.attempts>0 AND j.created_at<now()-interval '23 hours' THEN UPDATE public.sowrix_business_outbox SET status='exhausted',last_error='manual_provider_reconciliation_required' WHERE id=j.id;CONTINUE;END IF;
  token:=gen_random_uuid();
  UPDATE public.sowrix_business_outbox SET status='processing',attempts=attempts+1,lease_token=token,lease_until=now()+interval '2 minutes' WHERE id=j.id;
  result:=result||jsonb_build_array(jsonb_build_object('id',j.id,'lease_token',token,'email',mail,'attempt',j.attempts+1));
 END LOOP;
 UPDATE public.sowrix_business_outbox SET status='exhausted',lease_token=NULL,lease_until=NULL WHERE status='processing' AND lease_until<now() AND attempts>=5;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_finish_business_mail(p_id uuid,p_lease uuid,p_accepted boolean,p_provider_id text DEFAULT NULL,p_error text DEFAULT NULL) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE changed integer;BEGIN
 IF auth.role()<>'service_role' THEN RAISE EXCEPTION 'Server worker required' USING ERRCODE='42501';END IF;
 UPDATE public.sowrix_business_outbox SET status=CASE WHEN p_accepted THEN 'accepted' WHEN attempts>=5 THEN 'exhausted' ELSE 'failed' END,
 accepted_at=CASE WHEN p_accepted THEN now() ELSE NULL END,provider_id=CASE WHEN p_accepted THEN left(p_provider_id,200) ELSE NULL END,
 last_error=CASE WHEN p_accepted THEN NULL ELSE left(coalesce(p_error,'provider_failure'),80) END,
 next_attempt_at=now()+make_interval(secs=>60*power(2,least(attempts,5))::integer),lease_until=NULL,lease_token=NULL
 WHERE id=p_id AND lease_token=p_lease AND status='processing' AND lease_until>now();
 GET DIAGNOSTICS changed=ROW_COUNT;RETURN changed=1;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_retry_business_mail(p_id uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE changed integer;BEGIN
 PERFORM public.sowrix_require_secure_session(true);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 UPDATE public.sowrix_business_outbox SET status='queued',attempts=0,next_attempt_at=now()+interval '60 seconds',last_error=NULL
 WHERE id=p_id AND status IN ('failed','exhausted') AND next_attempt_at<=now() AND created_at>now()-interval '23 hours';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed>0 THEN INSERT INTO public.audit_logs(actor_id,action,target_type,target_id) VALUES(auth.uid(),'notification_retry','notifications',p_id::text);END IF;
 RETURN changed=1;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_business_reminders() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r record;n integer:=0;users uuid[];BEGIN
 IF auth.role()<>'service_role' THEN RAISE EXCEPTION 'Server scheduler required' USING ERRCODE='42501';END IF;
 FOR r IN SELECT 'tasks'::text m,id,due_date::text due,assignee_id uid FROM public.tasks WHERE due_date=current_date+1 AND status NOT IN ('done','cancelled')
 UNION ALL SELECT 'projects',id,due_date::text,manager_id FROM public.projects WHERE due_date=current_date+1 AND status NOT IN ('completed','archived')
 UNION ALL SELECT 'invoices',id,due_date::text,NULL::uuid FROM public.invoices WHERE due_date=current_date+1 AND status IN ('sent','partially_paid','overdue')
 UNION ALL SELECT 'amc',id,ends_on::text,NULL::uuid FROM public.sowrix_amc_contracts WHERE ends_on=current_date+renewal_notice_days AND status='active'
 LOOP
  SELECT coalesce(array_agg(user_id),'{}')||ARRAY[r.uid] INTO users FROM public.sowrix_event_recipients WHERE module=r.m;
  IF r.m IN ('invoices','amc') THEN SELECT users||coalesce(array_agg(user_id),'{}') INTO users FROM public.sowrix_org_memberships WHERE organization_id=(public.sowrix_work_row(r.m,r.id)->>'client_id')::uuid AND status='active';END IF;
  IF public.sowrix_emit_event(r.m,r.id,'reminder','due:'||r.due,users) IS NOT NULL THEN n:=n+1;END IF;
 END LOOP;RETURN n;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_business_delivery_status() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$ BEGIN
 PERFORM public.sowrix_require_secure_session(false);IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('counts',(SELECT coalesce(jsonb_object_agg(status,n),'{}') FROM(SELECT status,count(*) n FROM public.sowrix_business_outbox GROUP BY status)x),
 'unrouted_modules',(SELECT coalesce(jsonb_agg(module_key),'[]') FROM public.sowrix_permission_catalog c WHERE module_key IN ('enquiries','applications','leaves','invoices','amc') AND NOT EXISTS(SELECT 1 FROM public.sowrix_event_recipients r WHERE r.module=c.module_key)),
 'recent',(SELECT coalesce(jsonb_agg(x),'[]') FROM(SELECT id,status,attempts,last_error,created_at FROM public.sowrix_business_outbox ORDER BY created_at DESC LIMIT 50)x));
END $$;


CREATE OR REPLACE FUNCTION public.sowrix_work_labels(p_module text,p_ids uuid[]) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE rid uuid;r jsonb;f text;uid uuid;i jsonb;result jsonb:='[]';BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF cardinality(p_ids)>100 THEN RAISE EXCEPTION 'At most 100 records';END IF;
 SELECT assignee_field INTO f FROM public.sowrix_work_catalog WHERE module=p_module;
 IF f IS NULL THEN RAISE EXCEPTION 'Unknown module';END IF;
 FOREACH rid IN ARRAY coalesce(p_ids,'{}'::uuid[]) LOOP
  r:=public.sowrix_work_row(p_module,rid);
  IF NOT public.sowrix_user_record_access(auth.uid(),p_module,r) THEN CONTINUE;END IF;
  uid:=(r->>f)::uuid;i:=public.sowrix_identity_internal(uid);
  result:=result||jsonb_build_array(jsonb_build_object('id',rid,'full_name',i->>'full_name','employee_code',i->>'employee_code','role',(SELECT role::text FROM public.user_roles WHERE user_id=uid),'assigned',uid IS NOT NULL));
 END LOOP;RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_work_admin_settings() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$ BEGIN
 PERFORM public.sowrix_require_secure_session(false);IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('staff',(SELECT coalesce(jsonb_agg(x),'[]') FROM(SELECT u.id,i.v->>'full_name' AS full_name,i.v->>'employee_code' AS employee_code,r.role::text AS role FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id CROSS JOIN LATERAL(SELECT public.sowrix_identity_internal(u.id)v)i WHERE r.role::text<>'client' AND public.sowrix_user_active(u.id) ORDER BY i.v->>'full_name',u.id LIMIT 500)x),
 'organizations',(SELECT coalesce(jsonb_agg(x),'[]') FROM(SELECT id,organization_name FROM public.clients WHERE status='active' ORDER BY organization_name,id LIMIT 500)x),
 'scopes',(SELECT coalesce(jsonb_agg(s),'[]') FROM public.sowrix_staff_org_scopes s),
 'recipients',(SELECT coalesce(jsonb_agg(r),'[]') FROM public.sowrix_event_recipients r));
END $$;
REVOKE ALL ON FUNCTION public.sowrix_work_labels(text,uuid[]),public.sowrix_work_admin_settings() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_work_labels(text,uuid[]),public.sowrix_work_admin_settings() TO authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_identity_internal(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $identity$
DECLARE d jsonb; l jsonb; m jsonb; n text; c text; email_value text;
BEGIN
 SELECT to_jsonb(e) INTO d FROM public.employees e WHERE e.user_id=p_user_id
 ORDER BY e.created_at DESC,e.id LIMIT 1;
 IF to_regclass('public.employee_profiles') IS NOT NULL THEN
  EXECUTE $legacy$
   SELECT to_jsonb(e) FROM public.employee_profiles e
   WHERE coalesce(nullif(to_jsonb(e)->>'user_id',''),nullif(to_jsonb(e)->>'auth_user_id',''),nullif(to_jsonb(e)->>'id',''))=$1
   ORDER BY to_jsonb(e)->>'updated_at' DESC NULLS LAST,
            to_jsonb(e)->>'created_at' DESC NULLS LAST,to_jsonb(e)->>'id' LIMIT 1
  $legacy$ INTO l USING p_user_id::text;
 END IF;
 SELECT u.raw_user_meta_data,u.email INTO m,email_value FROM auth.users u WHERE u.id=p_user_id;
 SELECT btrim(v.value) INTO n FROM unnest(ARRAY[
  d->>'full_name',d->>'display_name',d->>'name',l->>'full_name',l->>'display_name',l->>'name',
  m->>'full_name',m->>'display_name',m->>'name'
 ]) WITH ORDINALITY v(value,priority)
 WHERE nullif(btrim(v.value),'') IS NOT NULL
 AND lower(btrim(v.value)) NOT IN ('name not set','not set','unknown','unassigned','null','undefined','—','-')
 ORDER BY v.priority LIMIT 1;
 SELECT btrim(v.value) INTO c FROM unnest(ARRAY[
  d->>'employee_code',d->>'employee_id',d->>'staff_id',l->>'employee_code',l->>'employee_id',l->>'staff_id',
  m->>'employee_code',m->>'employee_id',m->>'staff_id'
 ]) WITH ORDINALITY v(value,priority)
 WHERE nullif(btrim(v.value),'') IS NOT NULL
 AND lower(btrim(v.value)) NOT IN ('name not set','not set','unknown','unassigned','null','undefined','—','-')
 ORDER BY v.priority LIMIT 1;
 RETURN jsonb_build_object('user_id',p_user_id,'full_name',n,'employee_code',c,'email',email_value,
  'department',coalesce(nullif(btrim(d->>'department'),''),nullif(btrim(l->>'department'),'')),
  'designation',coalesce(nullif(btrim(d->>'designation'),''),nullif(btrim(l->>'designation'),'')),
  'joining_date',coalesce(d->>'joining_date',l->>'joining_date'),
  'has_profile',d IS NOT NULL OR l IS NOT NULL);
END
$identity$;
REVOKE ALL ON FUNCTION public.sowrix_identity_internal(uuid) FROM PUBLIC,anon,authenticated;


CREATE OR REPLACE FUNCTION public.sowrix_people_display(p_user_ids uuid[])
RETURNS TABLE(user_id uuid,employee_code text,full_name text) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE see_team boolean;target uuid;i jsonb;BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF coalesce(cardinality(p_user_ids),0)>500 THEN RAISE EXCEPTION 'Request at most 500 employees';END IF;
 see_team:=public.sowrix_access_admin() OR EXISTS(SELECT 1 FROM public.sowrix_permission_catalog c WHERE c.module_key IN ('employees','attendance','leaves','payroll','interviews') AND public.sowrix_has_permission(c.module_key,'view') AND (public.sowrix_access_role() IN ('hr','hr_staff','hr_manager') OR public.sowrix_wide_access(c.module_key,'view')));
 IF NOT see_team AND NOT EXISTS(SELECT 1 FROM public.sowrix_permission_catalog c WHERE c.module_key IN ('attendance','leaves','payroll','interviews') AND public.sowrix_has_permission(c.module_key,'view')) THEN RAISE EXCEPTION 'People module access required' USING ERRCODE='42501';END IF;
 FOR target IN SELECT DISTINCT x FROM unnest(coalesce(p_user_ids,'{}'::uuid[]))x WHERE x IS NOT NULL LOOP
  IF NOT see_team AND target<>auth.uid() THEN CONTINUE;END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=target) THEN CONTINUE;END IF;
  i:=public.sowrix_identity_internal(target);user_id:=target;full_name:=i->>'full_name';employee_code:=i->>'employee_code';RETURN NEXT;
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_people_display(uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_people_display(uuid[]) TO authenticated;
CREATE TABLE IF NOT EXISTS public.sowrix_ticket_replies(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),ticket_id uuid NOT NULL REFERENCES public.support_tickets(id),
 author_id uuid NOT NULL REFERENCES auth.users(id),visibility text NOT NULL CHECK(visibility IN ('public','internal')),
 body text NOT NULL CHECK(length(btrim(body)) BETWEEN 1 AND 5000),submission_key uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(author_id,submission_key)
);
CREATE INDEX IF NOT EXISTS sowrix_ticket_reply_page ON public.sowrix_ticket_replies(ticket_id,created_at DESC,id DESC);
ALTER TABLE public.sowrix_ticket_replies ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_ticket_replies FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_ticket_thread(p_ticket uuid,p_before timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE r jsonb;BEGIN
 PERFORM public.sowrix_require_secure_session(false);r:=public.sowrix_work_row('tickets',p_ticket);
 IF NOT public.sowrix_user_record_access(auth.uid(),'tickets',r) THEN RAISE EXCEPTION 'Ticket not available' USING ERRCODE='42501';END IF;
 IF (p_before IS NULL)<>(p_before_id IS NULL) THEN RAISE EXCEPTION 'Invalid reply page';END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC,x.id DESC) FROM(SELECT id,body,visibility,created_at,author_id=auth.uid() AS mine
 FROM public.sowrix_ticket_replies WHERE ticket_id=p_ticket AND (visibility='public' OR public.sowrix_access_role()<>'client')
 AND (p_before IS NULL OR (created_at,id)<(p_before,p_before_id)) ORDER BY created_at DESC,id DESC LIMIT 25)x),'[]');
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ticket_reply(p_ticket uuid,p_body text,p_visibility text,p_key uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r jsonb;rid uuid;users uuid[];old public.sowrix_ticket_replies;BEGIN
 PERFORM public.sowrix_require_secure_session(false);r:=public.sowrix_work_row('tickets',p_ticket);
 IF NOT public.sowrix_user_record_access(auth.uid(),'tickets',r) OR NOT(public.sowrix_has_permission('tickets','edit') OR (public.sowrix_has_permission('tickets','create') AND r->>'requester_id'=auth.uid()::text)) THEN RAISE EXCEPTION 'Ticket reply not permitted' USING ERRCODE='42501';END IF;
 IF p_visibility NOT IN ('public','internal') OR (p_visibility='internal' AND public.sowrix_access_role()='client') OR p_key IS NULL THEN RAISE EXCEPTION 'Invalid reply visibility' USING ERRCODE='42501';END IF;
 SELECT * INTO old FROM public.sowrix_ticket_replies WHERE author_id=auth.uid() AND submission_key=p_key;
 IF old.id IS NOT NULL THEN
  IF old.ticket_id<>p_ticket OR old.body<>btrim(p_body) OR old.visibility<>p_visibility THEN RAISE EXCEPTION 'Submission key already used for a different reply';END IF;RETURN old.id;
 END IF;
 INSERT INTO public.sowrix_ticket_replies(ticket_id,author_id,visibility,body,submission_key) VALUES(p_ticket,auth.uid(),p_visibility,btrim(p_body),p_key) RETURNING id INTO rid;
 users:=ARRAY[(r->>'assignee_id')::uuid,(r->>'requester_id')::uuid];
 SELECT users||coalesce(array_agg(user_id),'{}') INTO users FROM public.sowrix_event_recipients WHERE module='tickets';
 IF p_visibility='internal' THEN SELECT coalesce(array_agg(x),'{}') INTO users FROM unnest(users)x JOIN public.user_roles ur ON ur.user_id=x WHERE ur.role::text<>'client';END IF;
 PERFORM public.sowrix_emit_event('tickets',p_ticket,CASE p_visibility WHEN 'internal' THEN 'internal_note' ELSE 'public_reply' END,'reply:'||rid::text,users);
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details) VALUES(auth.uid(),'ticket_reply','tickets',p_ticket::text,jsonb_build_object('reply_id',rid,'visibility',p_visibility));
 RETURN rid;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ticket_thread(uuid,timestamptz,uuid),public.sowrix_ticket_reply(uuid,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_ticket_thread(uuid,timestamptz,uuid),public.sowrix_ticket_reply(uuid,text,text,uuid) TO authenticated;

ALTER TABLE public.sowrix_business_outbox ADD COLUMN IF NOT EXISTS delivery_checked_at timestamptz;
CREATE OR REPLACE FUNCTION public.sowrix_business_delivery_pending() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ids uuid[];result jsonb;BEGIN
 IF auth.role()<>'service_role' THEN RAISE EXCEPTION 'Server worker required' USING ERRCODE='42501';END IF;
 SELECT array_agg(id) INTO ids FROM(SELECT id FROM public.sowrix_business_outbox WHERE status='accepted' AND accepted_at>now()-interval '3 days' AND (delivery_checked_at IS NULL OR delivery_checked_at<now()-interval '5 minutes') ORDER BY delivery_checked_at NULLS FIRST,id LIMIT 20 FOR UPDATE SKIP LOCKED)x;
 UPDATE public.sowrix_business_outbox SET delivery_checked_at=now() WHERE id=ANY(ids);
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'provider_id',provider_id)),'[]') INTO result FROM public.sowrix_business_outbox WHERE id=ANY(ids);RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_business_delivery_confirm(p_id uuid,p_provider_id text,p_event text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE changed integer;BEGIN
 IF auth.role()<>'service_role' THEN RAISE EXCEPTION 'Server worker required' USING ERRCODE='42501';END IF;
 IF p_event NOT IN ('delivered','bounced','failed','suppressed','complained') THEN RETURN false;END IF;
 UPDATE public.sowrix_business_outbox SET status=CASE WHEN p_event='delivered' THEN 'delivered' ELSE 'exhausted' END,
 delivered_at=CASE WHEN p_event='delivered' THEN now() ELSE NULL END,last_error=CASE WHEN p_event='delivered' THEN NULL ELSE 'delivery_'||p_event END
 WHERE id=p_id AND provider_id=p_provider_id AND status='accepted';GET DIAGNOSTICS changed=ROW_COUNT;RETURN changed=1;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_business_delivery_pending(),public.sowrix_business_delivery_confirm(uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_business_delivery_pending(),public.sowrix_business_delivery_confirm(uuid,text,text) TO service_role;

-- Keep helpers private. Each browser RPC above explicitly checks its caller.
DO $$ DECLARE r record;BEGIN
 FOR r IN SELECT p.oid::regprocedure f,p.proname n FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace WHERE ns.nspname='public' AND p.proname IN
 ('sowrix_user_active','sowrix_user_permission','sowrix_staff_eligible','sowrix_work_org','sowrix_work_row','sowrix_user_record_access','sowrix_assignment_access','sowrix_assignment_guard','sowrix_work_candidates','sowrix_assign_work','sowrix_work_status','sowrix_set_staff_scope','sowrix_emit_event','sowrix_business_change','sowrix_inbox','sowrix_inbox_read','sowrix_inbox_preferences','sowrix_inbox_open','sowrix_set_event_recipient','sowrix_claim_business_mail','sowrix_finish_business_mail','sowrix_retry_business_mail','sowrix_business_reminders','sowrix_business_delivery_status') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.f);
  IF r.n IN ('sowrix_assignment_access','sowrix_work_candidates','sowrix_assign_work','sowrix_work_status','sowrix_set_staff_scope','sowrix_inbox','sowrix_inbox_read','sowrix_inbox_preferences','sowrix_inbox_open','sowrix_set_event_recipient','sowrix_retry_business_mail','sowrix_business_delivery_status') THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',r.f);END IF;
  IF r.n IN ('sowrix_claim_business_mail','sowrix_finish_business_mail','sowrix_business_reminders') THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.f);END IF;
 END LOOP;
END $$;
INSERT INTO public.sowrix_upgrade_markers(name) VALUES('work-notifications-v16') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
