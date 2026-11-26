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
