-- SOWRIX security foundation, release 10. Apply AFTER the complete release 9 schema.
-- Test in staging first. Requires real Supabase Auth session and MFA tables.
-- Existing data/IDs remain. Unclassified notes move to staff-only companion tables.
BEGIN;
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
