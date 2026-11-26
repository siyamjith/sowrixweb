-- SOWRIX R46.4. Optional additive migration. REVIEW IN RESTORED STAGING FIRST.
-- No funds are moved, payroll is not finalized, no mail sent, no records erased.
-- This migration assumes R45, R46, R46.2 and R46.3 SQL are already installed.
BEGIN;
DO $$BEGIN
 IF to_regprocedure('public.sowrix_r462_decide_approval(uuid,boolean,text)') IS NULL
 OR to_regprocedure('public.sowrix_r463_client_snapshot()') IS NULL
 OR to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NULL
 OR to_regclass('public.leave_requests') IS NULL
 OR to_regclass('public.payroll_records') IS NULL
 THEN RAISE EXCEPTION 'Missing R45 through R46.3 dependencies. Stop without applying R46.4'; END IF;
END$$;

-- Atomic source-of-truth leave resolution. Only pending leave records may transition;
-- approval history and the leave row commit together or neither does. No pay effects.
CREATE OR REPLACE FUNCTION public.sowrix_r462_decide_approval(p_id uuid,p_approve boolean,p_note text DEFAULT '')
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE r public.sowrix_r462_approvals%ROWTYPE; leave_row public.leave_requests%ROWTYPE;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF p_id IS NULL OR length(coalesce(p_note,''))>500 THEN RAISE EXCEPTION 'Invalid review' USING ERRCODE='22023'; END IF;
 SELECT * INTO r FROM public.sowrix_r462_approvals WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR r.status<>'pending' THEN RETURN false; END IF;
 IF (NOT public.sowrix_access_admin() AND NOT (public.sowrix_access_role()='hr_manager'
    AND r.module='leaves' AND public.sowrix_has_module_access('leaves')))
    OR r.requested_by=auth.uid() THEN
   RAISE EXCEPTION 'Independent authorized reviewer required' USING ERRCODE='42501'; END IF;
 IF r.module='leaves' THEN
   SELECT * INTO leave_row FROM public.leave_requests WHERE id=r.record_id FOR UPDATE;
   IF NOT FOUND OR lower(coalesce(leave_row.status,'')) NOT IN ('pending','submitted','requested','under_review')
   THEN RAISE EXCEPTION 'Leave changed: refresh and review the source record' USING ERRCODE='40001'; END IF;
   IF leave_row.employee_user_id=auth.uid() THEN
     RAISE EXCEPTION 'Cannot review own leave' USING ERRCODE='42501'; END IF;
   UPDATE public.leave_requests SET status=CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
     updated_at=clock_timestamp() WHERE id=r.record_id;
 END IF;
 UPDATE public.sowrix_r462_approvals SET status=CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
  decided_by=auth.uid(),decision_note=coalesce(p_note,''),decided_at=clock_timestamp() WHERE id=p_id;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r464_independent_approval',r.module,r.record_id::text,
        jsonb_build_object('approved',p_approve,'source_leave_updated',r.module='leaves'));
 RETURN true;
END $fn$;

-- Employees see their own approved calendar-day usage; no invented annual entitlement.
-- Weekends, holidays, half-days and local labor policy require an explicit policy engine.
CREATE OR REPLACE FUNCTION public.sowrix_r464_my_leave_usage() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE result jsonb;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 SELECT jsonb_build_object(
  'approved_requests',count(*),
  'approved_calendar_days',coalesce(sum(end_date-start_date+1),0),
  'possible_attendance_conflicts',(
      SELECT count(*) FROM public.leave_requests l
      JOIN public.attendance_records a ON a.employee_user_id=l.employee_user_id
         AND a.attendance_date BETWEEN l.start_date AND l.end_date
      WHERE l.employee_user_id=auth.uid() AND lower(l.status)='approved'
        AND lower(a.status) IN ('present','late','half_day')
    ),
  'policy_balance_available',false
 ) INTO result FROM public.leave_requests
 WHERE employee_user_id=auth.uid() AND lower(status)='approved' AND end_date>=start_date
  AND start_date>=date_trunc('year',current_date)::date;
 RETURN result;
END $fn$;

-- Only *finalized or paid* records can be previewed by the subject employee.
-- No payroll approval or payment can be performed via this function.
CREATE OR REPLACE FUNCTION public.sowrix_r464_my_payslip(p_period text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE row record;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF p_period IS NULL OR p_period !~ '^20[0-9]{2}-(0[1-9]|1[0-2])$'
 THEN RAISE EXCEPTION 'Invalid payroll period' USING ERRCODE='22023'; END IF;
 SELECT p.period,p.basic_amount,p.allowances,p.deductions,p.net_amount,p.status,p.paid_at,
        e.full_name,e.employee_code INTO row
 FROM public.payroll_records p LEFT JOIN public.employees e ON e.user_id=p.employee_user_id
 WHERE p.employee_user_id=auth.uid() AND p.period=p_period
   AND lower(p.status) IN ('finalized','paid')
 ORDER BY p.updated_at DESC,p.id DESC LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'Finalized payslip unavailable' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('period',row.period,'basic',row.basic_amount,
  'allowances',coalesce(row.allowances,0),'deductions',coalesce(row.deductions,0),
  'net',row.net_amount,'status',row.status,'paid_at',row.paid_at,
  'employee_name',row.full_name,'employee_code',row.employee_code,
  'document_status','employee_preview_only');
END $fn$;

-- Work metrics for the authenticated employee only; never a hiring/pay decision score.
CREATE OR REPLACE FUNCTION public.sowrix_r464_my_work_summary() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 RETURN jsonb_build_object(
  'assigned_open_tasks',(SELECT count(*) FROM public.tasks WHERE assignee_id=auth.uid() AND status NOT IN ('done','cancelled')),
  'completed_tasks',(SELECT count(*) FROM public.tasks WHERE assignee_id=auth.uid() AND status='done'),
  'overdue_tasks',(SELECT count(*) FROM public.tasks WHERE assignee_id=auth.uid() AND due_date<current_date AND status NOT IN ('done','cancelled')),
  'attendance_days_this_month',(SELECT count(DISTINCT attendance_date) FROM public.attendance_records
     WHERE employee_user_id=auth.uid() AND attendance_date>=date_trunc('month',current_date)::date
       AND lower(status) IN ('present','half_day','working')));
END $fn$;

-- Controlled, permission-scoped internal knowledge base. Records are NEVER public SQL data.
CREATE TABLE IF NOT EXISTS public.sowrix_r464_knowledge(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 title text NOT NULL CHECK(length(title) BETWEEN 4 AND 120),
 body text NOT NULL CHECK(length(body) BETWEEN 10 AND 6000),
 audience text NOT NULL DEFAULT 'staff' CHECK(audience IN ('staff','all_signed_in')),
 published boolean NOT NULL DEFAULT false,
 author_id uuid NOT NULL REFERENCES auth.users(id),
 updated_by uuid NOT NULL REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.sowrix_r464_knowledge ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_r464_knowledge FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_r464_knowledge_list() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_user_active(auth.uid()) THEN RAISE EXCEPTION 'Active workspace required' USING ERRCODE='42501';END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.updated_at DESC) FROM
 (SELECT id,title,body,audience,published,updated_at FROM public.sowrix_r464_knowledge
 WHERE (published AND (audience='all_signed_in' OR public.sowrix_access_role() NOT IN ('client')))
     OR public.sowrix_access_admin() ORDER BY updated_at DESC LIMIT 60)x),'[]'::jsonb);
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r464_knowledge_save(
 p_title text,p_body text,p_audience text DEFAULT 'staff',p_publish boolean DEFAULT false,p_id uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE result uuid;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 IF length(btrim(coalesce(p_title,''))) NOT BETWEEN 4 AND 120
 OR length(btrim(coalesce(p_body,''))) NOT BETWEEN 10 AND 6000
 OR p_audience NOT IN ('staff','all_signed_in') THEN RAISE EXCEPTION 'Invalid article' USING ERRCODE='22023';END IF;
 IF p_id IS NULL THEN
  INSERT INTO public.sowrix_r464_knowledge(title,body,audience,published,author_id,updated_by)
   VALUES(btrim(p_title),btrim(p_body),p_audience,p_publish,auth.uid(),auth.uid()) RETURNING id INTO result;
 ELSE
  UPDATE public.sowrix_r464_knowledge SET title=btrim(p_title),body=btrim(p_body),audience=p_audience,
    published=p_publish,updated_by=auth.uid(),updated_at=now() WHERE id=p_id RETURNING id INTO result;
  IF result IS NULL THEN RAISE EXCEPTION 'Article not found' USING ERRCODE='42501';END IF;
 END IF;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r464_knowledge_save','knowledge','article',jsonb_build_object('published',p_publish));
 RETURN result;
END $fn$;

-- Feedback is accepted ONLY from a resolved ticket's original requester, once.
CREATE TABLE IF NOT EXISTS public.sowrix_r464_feedback(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),ticket_id uuid NOT NULL UNIQUE REFERENCES public.support_tickets(id),
 requester_id uuid NOT NULL REFERENCES auth.users(id),rating integer NOT NULL CHECK(rating BETWEEN 1 AND 5),
 comment text NOT NULL DEFAULT '' CHECK(length(comment)<=500),created_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.sowrix_r464_feedback ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_r464_feedback FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_r464_feedback_options() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM
  (SELECT t.id,t.ticket_number,t.subject,t.created_at FROM public.support_tickets t
   WHERE t.requester_id=auth.uid() AND lower(t.status) IN ('resolved','closed')
     AND NOT EXISTS(SELECT 1 FROM public.sowrix_r464_feedback f WHERE f.ticket_id=t.id)
     AND public.sowrix_user_record_access(auth.uid(),'tickets',public.sowrix_work_row('tickets',t.id))
   ORDER BY t.created_at DESC LIMIT 30)x),'[]'::jsonb);
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r464_feedback_submit(p_ticket uuid,p_rating integer,p_comment text DEFAULT '')
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE t public.support_tickets%ROWTYPE;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF p_ticket IS NULL OR p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 OR length(coalesce(p_comment,''))>500
 THEN RAISE EXCEPTION 'Invalid feedback' USING ERRCODE='22023';END IF;
 SELECT * INTO t FROM public.support_tickets WHERE id=p_ticket FOR UPDATE;
 IF NOT FOUND OR t.requester_id IS DISTINCT FROM auth.uid()
 OR lower(t.status) NOT IN ('resolved','closed')
 OR NOT public.sowrix_user_record_access(auth.uid(),'tickets',public.sowrix_work_row('tickets',p_ticket))
 THEN RAISE EXCEPTION 'Ticket unavailable for feedback' USING ERRCODE='42501';END IF;
 INSERT INTO public.sowrix_r464_feedback(ticket_id,requester_id,rating,comment)
 VALUES(p_ticket,auth.uid(),p_rating,coalesce(p_comment,'')) ON CONFLICT(ticket_id) DO NOTHING;
 RETURN FOUND;
END $fn$;

-- Proposal draft + independent review. Approval NEVER sends mail, alters invoices,
-- accepts a payment or exposes customer data to an unauthenticated viewer.
CREATE TABLE IF NOT EXISTS public.sowrix_r464_proposals(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),title text NOT NULL CHECK(length(title) BETWEEN 4 AND 150),
 scope text NOT NULL CHECK(length(scope) BETWEEN 10 AND 8000),
 estimated_amount numeric(14,2) CHECK(estimated_amount>=0),currency text NOT NULL DEFAULT 'INR' CHECK(currency='INR'),
 state text NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','approved','returned')),
 author_id uuid NOT NULL REFERENCES auth.users(id),decided_by uuid REFERENCES auth.users(id),
 decision_note text NOT NULL DEFAULT '',created_at timestamptz NOT NULL DEFAULT now(),decided_at timestamptz);
ALTER TABLE public.sowrix_r464_proposals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_r464_proposals FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_r464_proposal_draft(p_title text,p_scope text,p_amount numeric DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE proposal uuid;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 IF length(btrim(coalesce(p_title,''))) NOT BETWEEN 4 AND 150 OR length(btrim(coalesce(p_scope,''))) NOT BETWEEN 10 AND 8000
 OR (p_amount IS NOT NULL AND (p_amount<0 OR p_amount>999999999999)) THEN
 RAISE EXCEPTION 'Invalid proposal draft' USING ERRCODE='22023';END IF;
 INSERT INTO public.sowrix_r464_proposals(title,scope,estimated_amount,author_id)
 VALUES(btrim(p_title),btrim(p_scope),p_amount,auth.uid()) RETURNING id INTO proposal;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r464_proposal_draft','proposals','draft',jsonb_build_object('amount_set',p_amount IS NOT NULL));
 RETURN proposal;
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r464_proposal_list() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM
  (SELECT id,title,scope,estimated_amount,currency,state,created_at FROM public.sowrix_r464_proposals
   ORDER BY created_at DESC LIMIT 40)x),'[]'::jsonb);
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r464_proposal_decide(p_id uuid,p_approve boolean,p_note text DEFAULT '')
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE proposal public.sowrix_r464_proposals%ROWTYPE;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() OR length(coalesce(p_note,''))>500
 THEN RAISE EXCEPTION 'Independent Admin review required' USING ERRCODE='42501';END IF;
 SELECT * INTO proposal FROM public.sowrix_r464_proposals WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR proposal.state<>'draft' THEN RETURN false;END IF;
 IF proposal.author_id=auth.uid() THEN RAISE EXCEPTION 'A second Admin must review' USING ERRCODE='42501';END IF;
 UPDATE public.sowrix_r464_proposals SET state=CASE WHEN p_approve THEN 'approved' ELSE 'returned' END,
  decided_by=auth.uid(),decided_at=now(),decision_note=coalesce(p_note,'') WHERE id=p_id;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r464_proposal_review','proposals','proposal',jsonb_build_object('approved',p_approve));
 RETURN true;
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r464_admin_overview() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object(
 'knowledge_articles',(SELECT count(*) FROM public.sowrix_r464_knowledge WHERE published),
 'proposal_drafts',(SELECT count(*) FROM public.sowrix_r464_proposals WHERE state='draft'),
 'proposals_approved',(SELECT count(*) FROM public.sowrix_r464_proposals WHERE state='approved'),
 'feedback_count',(SELECT count(*) FROM public.sowrix_r464_feedback),
 'feedback_average',(SELECT round(avg(rating)::numeric,1) FROM public.sowrix_r464_feedback));
END $fn$;

-- Source-linked proposal builder. The lead's own text is placed in a private
-- Admin draft; no invented price, no auto send, no customer selection by AI.
ALTER TABLE public.sowrix_r464_proposals
 ADD COLUMN IF NOT EXISTS enquiry_id uuid REFERENCES public.contact_enquiries(id);
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_r464_proposal_enquiry_unique
 ON public.sowrix_r464_proposals(enquiry_id) WHERE enquiry_id IS NOT NULL;
CREATE OR REPLACE FUNCTION public.sowrix_r464_enquiry_candidates() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM
  (SELECT e.id,left(coalesce(nullif(e.service_interest,''),'Technology services'),120) service,
          e.created_at FROM public.contact_enquiries e
   WHERE NOT EXISTS(SELECT 1 FROM public.sowrix_r464_proposals p WHERE p.enquiry_id=e.id)
   ORDER BY e.created_at DESC LIMIT 40)x),'[]'::jsonb);
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r464_proposal_from_enquiry(p_enquiry uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE lead record; proposal uuid;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 SELECT service_interest,message INTO lead FROM public.contact_enquiries WHERE id=p_enquiry;
 IF NOT FOUND THEN RAISE EXCEPTION 'Enquiry unavailable' USING ERRCODE='42501';END IF;
 INSERT INTO public.sowrix_r464_proposals(title,scope,enquiry_id,author_id)
 VALUES(left('Draft proposal — '||coalesce(nullif(lead.service_interest,''),'Technology services'),150),
        left('Customer-provided requirements (review before sharing): '||coalesce(lead.message,''),8000),
        p_enquiry,auth.uid()) ON CONFLICT DO NOTHING RETURNING id INTO proposal;
 IF proposal IS NULL THEN SELECT id INTO proposal FROM public.sowrix_r464_proposals WHERE enquiry_id=p_enquiry; END IF;
 RETURN proposal;
END $fn$;

-- Same-origin notification stream checks the caller's session on EVERY poll.
-- No private titles or identifiers are ever transmitted to the stream.
CREATE OR REPLACE FUNCTION public.sowrix_r464_notification_watermark() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 RETURN (SELECT jsonb_build_object('total',count(*),
   'unread',count(*) FILTER(WHERE read_at IS NULL),
   'latest',max(created_at))
 FROM public.sowrix_business_notifications WHERE user_id=auth.uid());
END $fn$;

-- Ensure these functions are accessible ONLY via authenticated Supabase sessions.
DO $$DECLARE f record;BEGIN
 FOR f IN SELECT p.oid::regprocedure AS fn FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND (p.proname LIKE 'sowrix_r464_%' OR p.proname='sowrix_r462_decide_approval') LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon',f.fn);
 EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.fn);
 END LOOP;
END$$;
NOTIFY pgrst,'reload schema';
COMMIT;
