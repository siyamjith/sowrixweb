-- SOWRIX R46.2: optional, additive operations. Run ONLY AFTER migration 46.
-- Requires reviewed backup + restored staging test. No payroll transfer, invoice settlement,
-- external email, device monitoring or data deletion is triggered by this migration.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_r46_automation_health()') IS NULL
    OR to_regprocedure('public.sowrix_staff_eligible(uuid,text,uuid)') IS NULL
    OR to_regprocedure('public.sowrix_emit_event(text,uuid,text,text,uuid[],uuid)') IS NULL
    OR to_regclass('public.sowrix_r45_payroll_reviews') IS NULL THEN
  RAISE EXCEPTION 'Install and verify R16, R45 and R46 migrations before R46.2';
 END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.sowrix_r462_config(
 id boolean PRIMARY KEY DEFAULT true CHECK(id),
 auto_route boolean NOT NULL DEFAULT false,
 sla_alerts boolean NOT NULL DEFAULT false,
 updated_at timestamptz NOT NULL DEFAULT now(),updated_by uuid REFERENCES auth.users(id)
);
INSERT INTO public.sowrix_r462_config(id) VALUES(true) ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS public.sowrix_r462_routing_pool(
 user_id uuid PRIMARY KEY REFERENCES auth.users(id),enabled boolean NOT NULL DEFAULT false,
 updated_at timestamptz NOT NULL DEFAULT now(),updated_by uuid REFERENCES auth.users(id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_r462_approvals(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), module text NOT NULL
 CHECK(module IN ('invoices','quotations','leaves','payroll')),
 record_id uuid NOT NULL, status text NOT NULL DEFAULT 'pending'
 CHECK(status IN ('pending','approved','rejected','cancelled')),
 requested_by uuid NOT NULL REFERENCES auth.users(id),decided_by uuid REFERENCES auth.users(id),
 request_note text NOT NULL DEFAULT '',decision_note text NOT NULL DEFAULT '',
 created_at timestamptz NOT NULL DEFAULT now(),decided_at timestamptz,
 CHECK(length(request_note)<=500 AND length(decision_note)<=500)
);
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_r462_pending_unique
 ON public.sowrix_r462_approvals(module,record_id) WHERE status='pending';
CREATE INDEX IF NOT EXISTS sowrix_r462_approvals_recent
 ON public.sowrix_r462_approvals(created_at DESC,id DESC);
DO $$DECLARE n text;BEGIN
 FOREACH n IN ARRAY ARRAY['sowrix_r462_config','sowrix_r462_routing_pool','sowrix_r462_approvals'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',n);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',n);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_r462_configure(p_auto_route boolean,p_sla_alerts boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 IF p_auto_route AND NOT EXISTS(SELECT 1 FROM public.sowrix_r462_routing_pool WHERE enabled) THEN
  RAISE EXCEPTION 'Opt in and authorize a routing-pool member first' USING ERRCODE='22023';END IF;
 UPDATE public.sowrix_r462_config SET auto_route=p_auto_route,sla_alerts=p_sla_alerts,updated_by=auth.uid(),updated_at=now() WHERE id;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r462_automation_config','operations','ticket_automations',
        jsonb_build_object('auto_route',p_auto_route,'sla_alerts',p_sla_alerts));
END $fn$;

CREATE OR REPLACE FUNCTION public.sowrix_r462_pool_member(p_user uuid,p_enabled boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 IF NOT public.sowrix_staff_eligible(p_user,'tickets',NULL) OR NOT EXISTS(
  SELECT 1 FROM public.user_roles WHERE user_id=p_user AND lower(role::text) IN ('employee','project_manager')
 ) THEN RAISE EXCEPTION 'Only authorized active support staff may opt in' USING ERRCODE='42501';END IF;
 INSERT INTO public.sowrix_r462_routing_pool(user_id,enabled,updated_at,updated_by)
 VALUES(p_user,p_enabled,now(),auth.uid())
 ON CONFLICT(user_id) DO UPDATE SET enabled=excluded.enabled,updated_at=now(),updated_by=auth.uid();
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r462_routing_pool','operations','support_team',jsonb_build_object('enabled',p_enabled));
END $fn$;

-- Service-role only: guarded, opt-in least-active-workload assignment; 30 tickets/run.
-- Existing assignment triggers reject ineligible users; no cross-tenant assignment.
CREATE OR REPLACE FUNCTION public.sowrix_r462_route_tickets() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE ticket record; candidate uuid; assigned integer:=0;
BEGIN
 IF auth.role()<>'service_role' THEN RAISE EXCEPTION 'Scheduler only' USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_r462_config WHERE id AND auto_route) THEN RETURN 0;END IF;
 FOR ticket IN SELECT id,client_id FROM public.support_tickets
  WHERE assignee_id IS NULL AND status NOT IN ('resolved','closed','cancelled')
    AND created_at>=now()-interval '30 days'
  ORDER BY created_at,id LIMIT 30 FOR UPDATE SKIP LOCKED LOOP
  SELECT p.user_id INTO candidate FROM public.sowrix_r462_routing_pool p
  JOIN public.user_roles u ON u.user_id=p.user_id
  WHERE p.enabled AND lower(u.role::text) IN ('employee','project_manager')
    AND public.sowrix_staff_eligible(p.user_id,'tickets',ticket.client_id)
  ORDER BY (SELECT count(*) FROM public.support_tickets active
            WHERE active.assignee_id=p.user_id AND active.status NOT IN ('resolved','closed','cancelled')),
           p.user_id LIMIT 1;
  IF candidate IS NOT NULL THEN
   UPDATE public.support_tickets SET assignee_id=candidate,updated_at=clock_timestamp()
   WHERE id=ticket.id AND assignee_id IS NULL;
   IF FOUND THEN assigned:=assigned+1;END IF;
  END IF;
 END LOOP;
 RETURN assigned;
END $fn$;

-- Service-role only: notify via existing recipient-scoped, deduplicated event path.
-- The SLA tiers are response targets, not legal or contractual guarantees; staff must review.
CREATE OR REPLACE FUNCTION public.sowrix_r462_sla_alerts() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE t record; receivers uuid[]; sent integer:=0; hrs integer;
BEGIN
 IF auth.role()<>'service_role' THEN RAISE EXCEPTION 'Scheduler only' USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_r462_config WHERE id AND sla_alerts) THEN RETURN 0;END IF;
 FOR t IN SELECT id,priority,created_at,requester_id,assignee_id FROM public.support_tickets
  WHERE status NOT IN ('resolved','closed','cancelled') AND created_at>=now()-interval '30 days'
  ORDER BY created_at LIMIT 250 LOOP
  hrs:=CASE lower(coalesce(t.priority,'')) WHEN 'critical' THEN 1 WHEN 'urgent' THEN 2
      WHEN 'high' THEN 4 WHEN 'medium' THEN 12 ELSE 24 END;
  IF t.created_at+make_interval(hours=>hrs)>now() THEN CONTINUE;END IF;
  -- A public staff response satisfies the first-response target; internal notes do not.
  IF EXISTS(SELECT 1 FROM public.sowrix_ticket_replies r
     WHERE r.ticket_id=t.id AND r.visibility='public'
       AND r.author_id IS DISTINCT FROM t.requester_id
       AND r.created_at>=t.created_at) THEN CONTINUE; END IF;
  SELECT coalesce(array_agg(user_id),'{}'::uuid[]) INTO receivers
    FROM public.sowrix_event_recipients WHERE module='tickets';
  receivers:=receivers||ARRAY[t.assignee_id,t.requester_id];
  IF public.sowrix_emit_event('tickets',t.id,'sla_first_response_overdue',
      'r462:first-response:'||hrs::text,receivers) IS NOT NULL THEN sent:=sent+1;END IF;
 END LOOP;
 RETURN sent;
END $fn$;

-- Non-destructive approval decision ledger; does not edit invoices, leave, payroll or transfer funds.
CREATE OR REPLACE FUNCTION public.sowrix_r462_request_approval(p_module text,p_record uuid,p_note text DEFAULT '')
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE owner_id uuid; present boolean:=false;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF p_record IS NULL OR p_module NOT IN ('invoices','quotations','leaves','payroll')
    OR length(coalesce(p_note,''))>500 THEN RAISE EXCEPTION 'Invalid approval request' USING ERRCODE='22023';END IF;
 CASE p_module
 WHEN 'invoices' THEN
  SELECT EXISTS(SELECT 1 FROM public.invoices WHERE id=p_record) INTO present;
  IF NOT public.sowrix_access_admin() AND NOT(public.sowrix_has_permission('invoices','edit')
   AND public.sowrix_user_record_access(auth.uid(),'invoices',public.sowrix_work_row('invoices',p_record))) THEN
    RAISE EXCEPTION 'Invoice approval unavailable' USING ERRCODE='42501';END IF;
 WHEN 'quotations' THEN
  SELECT EXISTS(SELECT 1 FROM public.quotations WHERE id=p_record) INTO present;
  IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Quote approval requires admin' USING ERRCODE='42501';END IF;
 WHEN 'leaves' THEN
  SELECT employee_user_id INTO owner_id FROM public.leave_requests WHERE id=p_record;
  present:=FOUND;
  IF NOT public.sowrix_access_admin() AND (owner_id IS DISTINCT FROM auth.uid()
       OR NOT public.sowrix_has_module_access('leaves')) THEN
    RAISE EXCEPTION 'Leave request unavailable' USING ERRCODE='42501';END IF;
 WHEN 'payroll' THEN
  SELECT EXISTS(SELECT 1 FROM public.sowrix_r45_payroll_reviews WHERE id=p_record) INTO present;
  IF NOT(public.sowrix_access_admin() OR (public.sowrix_access_role()='hr_manager'
    AND public.sowrix_has_module_access('payroll'))) THEN RAISE EXCEPTION 'Payroll review unavailable' USING ERRCODE='42501';END IF;
 END CASE;
 IF NOT present THEN RAISE EXCEPTION 'Record not available' USING ERRCODE='42501';END IF;
 INSERT INTO public.sowrix_r462_approvals(module,record_id,requested_by,request_note)
 VALUES(p_module,p_record,auth.uid(),left(coalesce(p_note,''),500)) ON CONFLICT DO NOTHING;
 RETURN FOUND;
END $fn$;

CREATE OR REPLACE FUNCTION public.sowrix_r462_approval_queue() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT(public.sowrix_access_admin() OR (public.sowrix_access_role()='hr_manager'
      AND public.sowrix_has_module_access('leaves'))) THEN
  RAISE EXCEPTION 'Approval reviewer required' USING ERRCODE='42501';END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC)
 FROM (SELECT a.id,a.module,a.status,a.created_at,a.request_note,
       CASE WHEN a.module='leaves' THEN 'Leave request' WHEN a.module='payroll' THEN 'Payroll review'
            WHEN a.module='invoices' THEN 'Invoice' ELSE 'Quotation' END label
       FROM public.sowrix_r462_approvals a WHERE a.status='pending'
        AND (public.sowrix_access_admin() OR a.module='leaves')
       ORDER BY a.created_at DESC LIMIT 50)x),'[]'::jsonb);
END $fn$;

CREATE OR REPLACE FUNCTION public.sowrix_r462_decide_approval(p_id uuid,p_approve boolean,p_note text DEFAULT '')
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE r public.sowrix_r462_approvals%ROWTYPE;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF p_id IS NULL OR length(coalesce(p_note,''))>500 THEN RAISE EXCEPTION 'Invalid decision' USING ERRCODE='22023';END IF;
 SELECT * INTO r FROM public.sowrix_r462_approvals WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR r.status<>'pending' THEN RETURN false;END IF;
 IF (NOT public.sowrix_access_admin() AND NOT(public.sowrix_access_role()='hr_manager'
  AND r.module='leaves' AND public.sowrix_has_module_access('leaves')))
  OR r.requested_by=auth.uid() THEN
  RAISE EXCEPTION 'Independent reviewer with module authorization required' USING ERRCODE='42501';END IF;
 UPDATE public.sowrix_r462_approvals SET status=CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
  decided_by=auth.uid(),decision_note=left(coalesce(p_note,''),500),decided_at=now() WHERE id=p_id;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details) VALUES
 (auth.uid(),'r462_approval_decision',r.module,r.record_id::text,jsonb_build_object('approved',p_approve));
 RETURN true;
END $fn$;

CREATE OR REPLACE FUNCTION public.sowrix_r462_project_progress(p_project uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE r jsonb;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 r:=public.sowrix_work_row('projects',p_project);
 IF NOT public.sowrix_user_record_access(auth.uid(),'projects',r) THEN
  RAISE EXCEPTION 'Project not available' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('name',r->>'name','status',r->>'status','due_date',r->>'due_date',
  'tasks_total',(SELECT count(*) FROM public.tasks WHERE project_id=p_project),
  'tasks_completed',(SELECT count(*) FROM public.tasks WHERE project_id=p_project AND status='done'),
  'tasks_blocked',(SELECT count(*) FROM public.tasks WHERE project_id=p_project AND status='blocked'),
  'updated_at',r->>'updated_at');
END $fn$;

CREATE OR REPLACE FUNCTION public.sowrix_r462_admin_pulse() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('as_of',now(),
  'open_tickets',(SELECT count(*) FROM public.support_tickets WHERE status NOT IN ('resolved','closed','cancelled')),
  'pending_approvals',(SELECT count(*) FROM public.sowrix_r462_approvals WHERE status='pending'),
  'active_projects',(SELECT count(*) FROM public.projects WHERE status IN ('planned','active','on_hold')),
  'open_applications',(SELECT count(*) FROM public.job_applications WHERE status IN ('applied','under_review','shortlisted')),
  'unassigned_tickets',(SELECT count(*) FROM public.support_tickets WHERE assignee_id IS NULL AND status NOT IN ('resolved','closed','cancelled')),
  'overdue_tasks',(SELECT count(*) FROM public.tasks WHERE due_date<current_date AND status NOT IN ('done','cancelled')),
  'unpaid_invoices',(SELECT count(*) FROM public.invoices WHERE status IN ('sent','partially_paid','overdue')),
  'expiring_amcs',(SELECT count(*) FROM public.sowrix_amc_contracts WHERE status='active' AND ends_on BETWEEN current_date AND current_date+30),
  'automation',(SELECT jsonb_build_object('auto_route',auto_route,'sla_alerts',sla_alerts) FROM public.sowrix_r462_config WHERE id),
  'routing_pool',(SELECT count(*) FROM public.sowrix_r462_routing_pool WHERE enabled));
END $fn$;

CREATE OR REPLACE FUNCTION public.sowrix_r462_activity() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 -- Deliberately exclude details, customer data, UUIDs and secrets from the overview.
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM
  (SELECT created_at,left(action,80) action,left(target_type,70) target_type
   FROM public.audit_logs ORDER BY created_at DESC LIMIT 30)x),'[]'::jsonb);
END $fn$;

-- Admin-controlled staff routing choices; no customer or ticket identifiers returned.
CREATE OR REPLACE FUNCTION public.sowrix_r462_pool_status() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.display_name) FROM
  (SELECT u.id AS user_id,coalesce(nullif(i.v->>'full_name',''),nullif(i.v->>'employee_code',''),'Active staff') AS display_name,
    coalesce(p.enabled,false) AS enabled
   FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id
   CROSS JOIN LATERAL (SELECT public.sowrix_identity_internal(u.id) v) i
   LEFT JOIN public.sowrix_r462_routing_pool p ON p.user_id=u.id
   WHERE lower(r.role::text) IN ('employee','project_manager')
     AND public.sowrix_staff_eligible(u.id,'tickets',NULL)
   ORDER BY display_name LIMIT 100)x),'[]'::jsonb);
END $fn$;

-- Ticket status for anyone who already has record-level access. No hidden notes.
CREATE OR REPLACE FUNCTION public.sowrix_r462_ticket_sla(p_ticket uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE ticket jsonb;limit_hours integer;response_time timestamptz;deadline timestamptz;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 ticket:=public.sowrix_work_row('tickets',p_ticket);
 IF NOT public.sowrix_user_record_access(auth.uid(),'tickets',ticket) THEN
  RAISE EXCEPTION 'Ticket unavailable' USING ERRCODE='42501';END IF;
 limit_hours:=CASE lower(coalesce(ticket->>'priority','')) WHEN 'critical' THEN 1
  WHEN 'urgent' THEN 2 WHEN 'high' THEN 4 WHEN 'medium' THEN 12 ELSE 24 END;
 deadline:=(ticket->>'created_at')::timestamptz+make_interval(hours=>limit_hours);
 SELECT min(r.created_at) INTO response_time FROM public.sowrix_ticket_replies r
 WHERE r.ticket_id=p_ticket AND r.visibility='public'
   AND r.author_id IS DISTINCT FROM nullif(ticket->>'requester_id','')::uuid;
 RETURN jsonb_build_object('priority',ticket->>'priority','status',ticket->>'status',
 'target_hours',limit_hours,'response_due_at',deadline,'responded_at',response_time,
 'response_overdue',CASE WHEN response_time IS NOT NULL THEN response_time>deadline
   ELSE now()>deadline AND ticket->>'status' NOT IN ('resolved','closed','cancelled') END);
END $fn$;

-- Employee onboarding *readiness*, not automatic permission grants or fabricated data.
-- Staff can inspect only their own readiness; HR/admin may view scoped staff.
CREATE OR REPLACE FUNCTION public.sowrix_r462_onboarding(p_user uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE target uuid:=coalesce(p_user,auth.uid());
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF target IS DISTINCT FROM auth.uid() AND NOT(public.sowrix_access_admin()
   OR public.sowrix_access_role() IN ('hr','hr_manager','hr_staff')) THEN
   RAISE EXCEPTION 'Employee onboarding is private' USING ERRCODE='42501';END IF;
 IF NOT public.sowrix_user_active(target) OR NOT EXISTS(SELECT 1 FROM public.employees WHERE user_id=target) THEN
   RAISE EXCEPTION 'Employee unavailable' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('profile_created',true,
    'identity_code_issued',EXISTS(SELECT 1 FROM public.sowrix_r45_identity_codes WHERE user_id=target),
    'module_grants_reviewed',EXISTS(SELECT 1 FROM public.sowrix_action_grants WHERE user_id=target),
    'employee_active',EXISTS(SELECT 1 FROM public.employees WHERE user_id=target AND
                       lower(employment_status)='active'),
    'next_step','HR must review access, policies and equipment before independent work');
END $fn$;

-- Snapshot aggregates are generated at most once per UTC day; no names or salaries.
CREATE TABLE IF NOT EXISTS public.sowrix_r462_daily_snapshots(
 day date PRIMARY KEY,created_at timestamptz NOT NULL DEFAULT now(),counts jsonb NOT NULL
);
ALTER TABLE public.sowrix_r462_daily_snapshots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_r462_daily_snapshots FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_r462_record_daily_snapshot() RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 IF auth.role()<>'service_role' THEN RAISE EXCEPTION 'Scheduler only' USING ERRCODE='42501';END IF;
 INSERT INTO public.sowrix_r462_daily_snapshots(day,counts) VALUES(
 (now() AT TIME ZONE 'UTC')::date,jsonb_build_object(
  'open_tickets',(SELECT count(*) FROM public.support_tickets WHERE status NOT IN ('resolved','closed','cancelled')),
  'active_projects',(SELECT count(*) FROM public.projects WHERE status IN ('planned','active','on_hold')),
  'new_enquiries',(SELECT count(*) FROM public.contact_enquiries WHERE created_at>now()-interval '24 hours'),
  'pending_approvals',(SELECT count(*) FROM public.sowrix_r462_approvals WHERE status='pending'),
  'unpaid_invoices',(SELECT count(*) FROM public.invoices WHERE status IN ('sent','partially_paid','overdue'))))
 ON CONFLICT(day) DO NOTHING;
 RETURN FOUND;
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r462_daily_history() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.day DESC) FROM
   (SELECT day,counts FROM public.sowrix_r462_daily_snapshots ORDER BY day DESC LIMIT 14)x),'[]'::jsonb);
END $fn$;

-- Harden all new tables: only their verified SECURITY DEFINER RPCs can write/read.
REVOKE ALL ON FUNCTION public.sowrix_r462_route_tickets(),public.sowrix_r462_sla_alerts(),public.sowrix_r462_record_daily_snapshot() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r462_route_tickets(),public.sowrix_r462_sla_alerts(),public.sowrix_r462_record_daily_snapshot() TO service_role;
DO $$DECLARE f record;BEGIN
 FOR f IN SELECT p.oid::regprocedure AS fn FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname IN
  ('sowrix_r462_configure','sowrix_r462_pool_member','sowrix_r462_request_approval',
   'sowrix_r462_approval_queue','sowrix_r462_decide_approval','sowrix_r462_project_progress',
   'sowrix_r462_admin_pulse','sowrix_r462_activity','sowrix_r462_pool_status',
   'sowrix_r462_ticket_sla','sowrix_r462_onboarding','sowrix_r462_daily_history') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon',f.fn);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.fn);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
