-- SOWRIX R46.6. Additive, operator-applied only AFTER R46.5 on a backed-up staging DB.
-- Internal and client-facing metadata only; no salary transfers, payment updates, auto-emails,
-- external monitoring, secret material, executable user rules or public document access.
BEGIN;
DO $$BEGIN
 IF to_regprocedure('public.sowrix_r465_client_dashboard()') IS NULL
 OR to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NULL
 OR to_regclass('public.sowrix_org_memberships') IS NULL THEN
   RAISE EXCEPTION 'Install R46.5 and verify tenant/session access before R46.6';
 END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.sowrix_r466_onboarding (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL UNIQUE REFERENCES public.clients(id),
 owner_id uuid NOT NULL REFERENCES auth.users(id),
 contact_confirmed boolean NOT NULL DEFAULT false, scope_approved boolean NOT NULL DEFAULT false,
 credentials_ready boolean NOT NULL DEFAULT false, kick_off_complete boolean NOT NULL DEFAULT false,
 note text NOT NULL DEFAULT '' CHECK(length(note)<=500),
 updated_at timestamptz NOT NULL DEFAULT now(), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sowrix_r466_subscriptions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES public.clients(id),
 service_name text NOT NULL CHECK(length(service_name) BETWEEN 3 AND 140),
 plan_label text NOT NULL CHECK(length(plan_label) BETWEEN 2 AND 100),
 renewal_on date, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','active','paused','expired')),
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sowrix_r466_subscriptions_org ON public.sowrix_r466_subscriptions(organization_id,status,renewal_on);
CREATE TABLE IF NOT EXISTS public.sowrix_r466_assets (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), asset_tag text NOT NULL UNIQUE CHECK(length(asset_tag) BETWEEN 3 AND 40),
 asset_name text NOT NULL CHECK(length(asset_name) BETWEEN 3 AND 150),
 category text NOT NULL CHECK(category IN ('laptop','desktop','network','software','equipment','other')),
 assigned_to uuid REFERENCES auth.users(id), warranty_end date,
 state text NOT NULL DEFAULT 'available' CHECK(state IN ('available','assigned','repair','retired')),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sowrix_r466_assets_assignee ON public.sowrix_r466_assets(assigned_to);
CREATE TABLE IF NOT EXISTS public.sowrix_r466_announcements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL CHECK(length(title) BETWEEN 4 AND 140),
 body text NOT NULL CHECK(length(body) BETWEEN 10 AND 1500),
 audience text NOT NULL DEFAULT 'staff' CHECK(audience='staff'),
 author_id uuid NOT NULL REFERENCES auth.users(id), created_at timestamptz NOT NULL DEFAULT now(),
 expires_on date
);
CREATE TABLE IF NOT EXISTS public.sowrix_r466_announcement_reads (
 announcement_id uuid NOT NULL REFERENCES public.sowrix_r466_announcements(id),
 user_id uuid NOT NULL REFERENCES auth.users(id),read_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(announcement_id,user_id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_r466_automation_rules (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL UNIQUE CHECK(length(name) BETWEEN 4 AND 100),
 event_kind text NOT NULL CHECK(event_kind IN ('ticket_created','ticket_overdue','invoice_overdue','amc_renewal_due','task_overdue')),
 action_kind text NOT NULL CHECK(action_kind IN ('notify_internal','queue_review')),
 state text NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','approved','disabled')),
 creator_id uuid NOT NULL REFERENCES auth.users(id), reviewer_id uuid REFERENCES auth.users(id),
 reviewed_at timestamptz,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sowrix_r466_compliance_register (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), control_name text NOT NULL UNIQUE CHECK(length(control_name) BETWEEN 5 AND 140),
 evidence_note text NOT NULL DEFAULT '' CHECK(length(evidence_note)<=500),
 state text NOT NULL DEFAULT 'planned' CHECK(state IN ('planned','in_review','verified')),
 updated_by uuid NOT NULL REFERENCES auth.users(id), updated_at timestamptz NOT NULL DEFAULT now()
);

DO $$DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['sowrix_r466_onboarding','sowrix_r466_subscriptions','sowrix_r466_assets',
 'sowrix_r466_announcements','sowrix_r466_announcement_reads','sowrix_r466_automation_rules','sowrix_r466_compliance_register'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
 END LOOP;
END$$;

-- Authenticated, active clients can read only organizations they belong to.
-- Independent SECURITY DEFINER functions below never return arbitrary table contents.
CREATE OR REPLACE FUNCTION public.sowrix_r466_client_org(p_org uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT EXISTS(SELECT 1 FROM public.sowrix_org_memberships m
  WHERE m.user_id=auth.uid() AND m.organization_id=p_org AND m.status='active')
$fn$;

CREATE OR REPLACE FUNCTION public.sowrix_r466_board(p_section text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE r text;is_admin boolean;is_hr boolean;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_user_active(auth.uid()) THEN RAISE EXCEPTION 'Active user required' USING ERRCODE='42501'; END IF;
 r:=public.sowrix_access_role();is_admin:=public.sowrix_access_admin();
 is_hr:=is_admin OR r IN ('hr','hr_staff','hr_manager');
 IF p_section='onboarding' THEN
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.updated_at DESC) FROM (
   SELECT o.id,o.organization_id, left(c.organization_name,140) organization_name,
    o.contact_confirmed,o.scope_approved,o.credentials_ready,o.kick_off_complete,o.note,o.updated_at
   FROM public.sowrix_r466_onboarding o JOIN public.clients c ON c.id=o.organization_id
   WHERE is_admin OR (r='client' AND public.sowrix_r466_client_org(o.organization_id))
   ORDER BY o.updated_at DESC LIMIT 80)x),'[]'::jsonb);
 ELSIF p_section='subscriptions' THEN
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM (
   SELECT s.id,s.organization_id,left(c.organization_name,140) organization_name,s.service_name,s.plan_label,s.renewal_on,s.status,s.created_at
   FROM public.sowrix_r466_subscriptions s JOIN public.clients c ON c.id=s.organization_id
   WHERE is_admin OR (r='client' AND public.sowrix_r466_client_org(s.organization_id))
   ORDER BY s.created_at DESC LIMIT 120)x),'[]'::jsonb);
 ELSIF p_section='assets' THEN
  IF r='client' THEN RAISE EXCEPTION 'Staff only' USING ERRCODE='42501'; END IF;
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.asset_tag) FROM (
   SELECT a.id,a.asset_tag,a.asset_name,a.category,a.state,a.warranty_end,a.assigned_to=auth.uid() AS mine,
     CASE WHEN is_admin THEN a.assigned_to::text ELSE NULL END AS assigned_to
   FROM public.sowrix_r466_assets a WHERE is_admin OR a.assigned_to=auth.uid()
   ORDER BY a.asset_tag LIMIT 150)x),'[]'::jsonb);
 ELSIF p_section='announcements' THEN
  IF r='client' THEN RAISE EXCEPTION 'Staff only' USING ERRCODE='42501'; END IF;
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM (
   SELECT a.id,a.title,a.body,a.created_at,a.expires_on,
      EXISTS(SELECT 1 FROM public.sowrix_r466_announcement_reads v
       WHERE v.announcement_id=a.id AND v.user_id=auth.uid()) AS acknowledged
   FROM public.sowrix_r466_announcements a
   WHERE a.expires_on IS NULL OR a.expires_on>=current_date
   ORDER BY a.created_at DESC LIMIT 50)x),'[]'::jsonb);
 ELSIF p_section='rules' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM (
   SELECT x.id,x.name,x.event_kind,x.action_kind,x.state,x.created_at,
    x.creator_id=auth.uid() AS is_creator FROM public.sowrix_r466_automation_rules x
   ORDER BY x.created_at DESC LIMIT 100)x),'[]'::jsonb);
 ELSIF p_section='compliance' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object('controls',coalesce((SELECT jsonb_agg(x ORDER BY x.control_name) FROM (
    SELECT control_name,state,evidence_note,updated_at FROM public.sowrix_r466_compliance_register ORDER BY control_name LIMIT 100)x),'[]'::jsonb),
    'pending_onboarding',(SELECT count(*) FROM public.sowrix_r466_onboarding WHERE NOT (contact_confirmed AND scope_approved AND credentials_ready AND kick_off_complete)),
    'renewals_30d',(SELECT count(*) FROM public.sowrix_r466_subscriptions WHERE status='active' AND renewal_on BETWEEN current_date AND current_date+30),
    'warranties_30d',(SELECT count(*) FROM public.sowrix_r466_assets WHERE state<>'retired' AND warranty_end BETWEEN current_date AND current_date+30),
    'unacknowledged_announcements',(SELECT count(*) FROM public.sowrix_r466_announcements a WHERE a.expires_on IS NULL OR a.expires_on>=current_date));
 ELSE RAISE EXCEPTION 'Unknown section' USING ERRCODE='22023'; END IF;
END $fn$;

-- Admin-only staff selector for asset assignment, using existing employee directory.
CREATE OR REPLACE FUNCTION public.sowrix_r466_staff_choices() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.full_name) FROM (
  SELECT e.user_id AS id,left(e.full_name,100) full_name,
   left(coalesce(e.sowrix_code,e.employee_code,'Employee'),35) employee_code
  FROM public.employees e WHERE e.user_id IS NOT NULL AND e.employment_status='active'
  ORDER BY e.full_name LIMIT 150)x),'[]'::jsonb);
END $fn$;

-- All writes are bounded, validated metadata changes. p_data is always parsed using known keys.
-- Returns only a generic boolean, never a secret, recipient address, or full record dump.
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
  v_title:=btrim(p_data->>'asset_tag');v_text:=btrim(p_data->>'asset_name');v_kind:=p_data->>'category';
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

-- Explicit EXECUTE grants; raw base tables remain inaccessible to clients.
REVOKE ALL ON FUNCTION public.sowrix_r466_staff_choices() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_r466_staff_choices() TO authenticated;
REVOKE ALL ON FUNCTION public.sowrix_r466_client_org(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.sowrix_r466_board(text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.sowrix_r466_apply(text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_r466_client_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r466_board(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r466_apply(text,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
