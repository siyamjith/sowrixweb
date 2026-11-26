-- SOWRIX R46.7 | Business growth + customer collaboration (additive migration).
-- ONLY operator-applied to a backed-up, restored staging database after R46.6.
-- No automatic email, payment, conversion, legal e-signature, device access or profile provisioning.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_r466_board(text)') IS NULL
   OR to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NULL
   OR to_regclass('public.sowrix_org_memberships') IS NULL
   OR to_regclass('public.sowrix_r464_feedback') IS NULL
 THEN RAISE EXCEPTION 'R46.6 and all earlier migrations must be installed first'; END IF;
END $$;

-- CRM only references real enquiries submitted through the existing contact workflow.
CREATE TABLE IF NOT EXISTS public.sowrix_r467_leads (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 enquiry_id uuid NOT NULL UNIQUE REFERENCES public.contact_enquiries(id),
 stage text NOT NULL DEFAULT 'new' CHECK(stage IN ('new','contacted','qualified','proposal','won','lost')),
 next_followup_at timestamptz, created_by uuid NOT NULL REFERENCES auth.users(id),
 updated_at timestamptz NOT NULL DEFAULT now(), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sowrix_r467_leads_followup_idx ON public.sowrix_r467_leads(stage,next_followup_at);
CREATE TABLE IF NOT EXISTS public.sowrix_r467_lead_notes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), lead_id uuid NOT NULL REFERENCES public.sowrix_r467_leads(id),
 body text NOT NULL CHECK(length(body) BETWEEN 5 AND 1200), author_id uuid NOT NULL REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sowrix_r467_consultations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES public.clients(id),
 requested_by uuid NOT NULL REFERENCES auth.users(id),
 subject text NOT NULL CHECK(length(subject) BETWEEN 5 AND 160),
 preferred_at timestamptz NOT NULL, timezone text NOT NULL DEFAULT 'Asia/Kolkata' CHECK(length(timezone)<=80),
 state text NOT NULL DEFAULT 'requested' CHECK(state IN ('requested','confirmed','declined','completed','cancelled')),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sowrix_r467_consultations_org ON public.sowrix_r467_consultations(organization_id,preferred_at);
CREATE TABLE IF NOT EXISTS public.sowrix_r467_messages (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES public.clients(id),
 author_id uuid NOT NULL REFERENCES auth.users(id),
 subject text NOT NULL CHECK(length(subject) BETWEEN 4 AND 120),
 body text NOT NULL CHECK(length(body) BETWEEN 3 AND 2000),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sowrix_r467_messages_org ON public.sowrix_r467_messages(organization_id,created_at DESC);
-- Agreement metadata only. Client acknowledgement is NOT a legally binding electronic signature.
CREATE TABLE IF NOT EXISTS public.sowrix_r467_agreements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES public.clients(id),
 title text NOT NULL CHECK(length(title) BETWEEN 5 AND 140),
 document_reference text NOT NULL CHECK(length(document_reference) BETWEEN 5 AND 250),
 state text NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','review','approved','archived')),
 created_by uuid NOT NULL REFERENCES auth.users(id),reviewed_by uuid REFERENCES auth.users(id),
 reviewed_at timestamptz,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sowrix_r467_agreement_ack (
 agreement_id uuid NOT NULL REFERENCES public.sowrix_r467_agreements(id),
 user_id uuid NOT NULL REFERENCES auth.users(id),acknowledged_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(agreement_id,user_id)
);
-- Idempotent internal reminders: no external emails, SMS or client data exposure.
CREATE TABLE IF NOT EXISTS public.sowrix_r467_followup_alerts (
 lead_id uuid NOT NULL REFERENCES public.sowrix_r467_leads(id),alert_date date NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(lead_id,alert_date)
);
-- Public incident statuses must be manually reviewed and published, not auto-claimed 'all green'.
CREATE TABLE IF NOT EXISTS public.sowrix_r467_status_updates (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),service text NOT NULL CHECK(length(service) BETWEEN 3 AND 80),
 category text NOT NULL CHECK(category IN ('notice','maintenance','degraded','incident','resolved')),
 message text NOT NULL CHECK(length(message) BETWEEN 10 AND 500),
 published boolean NOT NULL DEFAULT false,updated_by uuid NOT NULL REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT now(),expires_at timestamptz
);

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['sowrix_r467_leads','sowrix_r467_lead_notes','sowrix_r467_consultations',
  'sowrix_r467_messages','sowrix_r467_agreements','sowrix_r467_agreement_ack','sowrix_r467_status_updates','sowrix_r467_followup_alerts'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_r467_public_status() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM (
 SELECT service,category,message,created_at FROM public.sowrix_r467_status_updates
 WHERE published=true AND (expires_at IS NULL OR expires_at>now())
 ORDER BY created_at DESC LIMIT 20) x),'[]'::jsonb);
END $fn$;

CREATE OR REPLACE FUNCTION public.sowrix_r467_board(p_section text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE is_admin boolean;r text;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_user_active(auth.uid()) THEN RAISE EXCEPTION 'Active account required' USING ERRCODE='42501'; END IF;
 is_admin:=public.sowrix_access_admin();r:=public.sowrix_access_role();
 IF p_section='crm' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM (
   SELECT l.id,l.enquiry_id,l.stage,l.next_followup_at,l.created_at,l.updated_at,
    left(c.name,120) AS contact_name,left(c.company,140) AS company,
    left(c.service_interest,140) AS service_interest,
    (SELECT count(*) FROM public.sowrix_r467_lead_notes n WHERE n.lead_id=l.id) AS note_count
   FROM public.sowrix_r467_leads l JOIN public.contact_enquiries c ON c.id=l.enquiry_id
   ORDER BY l.created_at DESC LIMIT 120)x),'[]'::jsonb);
 ELSIF p_section='enquiries' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM (
   SELECT e.id,left(e.name,100) name,left(e.company,100) company,left(e.service_interest,100) service_interest,e.created_at
   FROM public.contact_enquiries e WHERE NOT EXISTS(SELECT 1 FROM public.sowrix_r467_leads l WHERE l.enquiry_id=e.id)
   ORDER BY e.created_at DESC LIMIT 75)x),'[]'::jsonb);
 ELSIF p_section='consultations' THEN
  IF NOT (is_admin OR r='client') THEN RAISE EXCEPTION 'Client or Admin only' USING ERRCODE='42501';END IF;
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.preferred_at DESC) FROM (
   SELECT c.id,c.organization_id,c.subject,c.preferred_at,c.timezone,c.state,c.created_at,
    left(o.organization_name,140) organization_name FROM public.sowrix_r467_consultations c
    JOIN public.clients o ON o.id=c.organization_id
    WHERE is_admin OR (r='client' AND public.sowrix_r466_client_org(c.organization_id))
    ORDER BY c.preferred_at DESC LIMIT 100)x),'[]'::jsonb);
 ELSIF p_section='messages' THEN
  IF NOT (is_admin OR r='client') THEN RAISE EXCEPTION 'Client or Admin only' USING ERRCODE='42501';END IF;
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM (
    SELECT m.id,m.organization_id,m.subject,m.body,m.created_at,
     left(c.organization_name,140) AS organization_name,
     CASE WHEN m.author_id=auth.uid() THEN 'you' ELSE 'team' END AS author
    FROM public.sowrix_r467_messages m JOIN public.clients c ON c.id=m.organization_id
    WHERE is_admin OR (r='client' AND public.sowrix_r466_client_org(m.organization_id))
    ORDER BY m.created_at DESC LIMIT 150)x),'[]'::jsonb);
 ELSIF p_section='agreements' THEN
  IF NOT (is_admin OR r='client') THEN RAISE EXCEPTION 'Client or Admin only' USING ERRCODE='42501';END IF;
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM (
    SELECT a.id,a.organization_id,a.title,a.document_reference,a.state,a.created_at,
      a.created_by=auth.uid() AS is_creator,
      EXISTS(SELECT 1 FROM public.sowrix_r467_agreement_ack v WHERE v.agreement_id=a.id AND v.user_id=auth.uid()) acknowledged,
      left(c.organization_name,140) organization_name
    FROM public.sowrix_r467_agreements a JOIN public.clients c ON c.id=a.organization_id
    WHERE is_admin OR (a.state='approved' AND r='client' AND public.sowrix_r466_client_org(a.organization_id))
    ORDER BY a.created_at DESC LIMIT 100)x),'[]'::jsonb);
 ELSIF p_section='status' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM (
    SELECT id,service,category,message,published,created_at,expires_at
    FROM public.sowrix_r467_status_updates ORDER BY created_at DESC LIMIT 60)x),'[]'::jsonb);
 ELSIF p_section='security' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  RETURN jsonb_build_object(
    'audit_events_24h',(SELECT count(*) FROM public.audit_logs WHERE created_at>now()-interval '24 hours'),
    'possible_access_failures_24h',(SELECT count(*) FROM public.audit_logs WHERE created_at>now()-interval '24 hours'
      AND (coalesce(action,'') ILIKE '%auth%fail%' OR coalesce(action,'') ILIKE '%access%denied%')),
    'business_actions_24h',(SELECT count(*) FROM public.audit_logs WHERE created_at>now()-interval '24 hours'
      AND action LIKE 'r467_%'),
    'unreviewed_agreements',(SELECT count(*) FROM public.sowrix_r467_agreements WHERE state='review'),
    'unpublished_notices',(SELECT count(*) FROM public.sowrix_r467_status_updates WHERE published=false)
  );
 ELSIF p_section='analytics' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  RETURN jsonb_build_object(
    'enquiries',(SELECT count(*) FROM public.contact_enquiries),
    'leads',(SELECT count(*) FROM public.sowrix_r467_leads),
    'qualified',(SELECT count(*) FROM public.sowrix_r467_leads WHERE stage='qualified'),
    'won',(SELECT count(*) FROM public.sowrix_r467_leads WHERE stage='won'),
    'followups_due',(SELECT count(*) FROM public.sowrix_r467_leads WHERE next_followup_at<=now() AND stage NOT IN('won','lost')),
    'consultations_requested',(SELECT count(*) FROM public.sowrix_r467_consultations WHERE state='requested'),
    'open_client_messages',(SELECT count(*) FROM public.sowrix_r467_messages WHERE created_at>now()-interval '7 days'),
    'feedback_count',(SELECT count(*) FROM public.sowrix_r464_feedback),
    'feedback_mean',(SELECT round(avg(rating)::numeric,1) FROM public.sowrix_r464_feedback),
    'recent_audit_events',(SELECT count(*) FROM public.audit_logs WHERE created_at>now()-interval '24 hours')
  );
 ELSE RAISE EXCEPTION 'Unknown board section' USING ERRCODE='22023';END IF;
END $fn$;

CREATE OR REPLACE FUNCTION public.sowrix_r467_apply(p_action text,p_data jsonb DEFAULT '{}'::jsonb)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE is_admin boolean;r text;v_id uuid;v_org uuid;v_state text;v_subject text;v_body text;
 v_date timestamptz;v_agreement public.sowrix_r467_agreements%ROWTYPE;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_user_active(auth.uid()) THEN RAISE EXCEPTION 'Active account required' USING ERRCODE='42501';END IF;
 IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR length(p_data::text)>3500
 THEN RAISE EXCEPTION 'Invalid request payload' USING ERRCODE='22023';END IF;
 is_admin:=public.sowrix_access_admin();r:=public.sowrix_access_role();
 IF p_action='lead_create' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_id:=(p_data->>'enquiry_id')::uuid;
  INSERT INTO public.sowrix_r467_leads(enquiry_id,created_by)
   SELECT e.id,auth.uid() FROM public.contact_enquiries e WHERE e.id=v_id
   ON CONFLICT(enquiry_id) DO NOTHING;
  IF NOT FOUND THEN RETURN false;END IF;
 ELSIF p_action='lead_stage' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_id:=(p_data->>'id')::uuid;v_state:=p_data->>'stage';
  IF v_state NOT IN ('new','contacted','qualified','proposal','won','lost') THEN RAISE EXCEPTION 'Invalid stage' USING ERRCODE='22023';END IF;
  UPDATE public.sowrix_r467_leads SET stage=v_state,updated_at=now() WHERE id=v_id;
  IF NOT FOUND THEN RETURN false;END IF;
 ELSIF p_action='lead_followup' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_id:=(p_data->>'id')::uuid;
  v_date:=NULLIF(p_data->>'when','')::timestamptz;
  IF v_date IS NOT NULL AND v_date<now()-interval '1 day' THEN RAISE EXCEPTION 'Past follow-up time' USING ERRCODE='22023';END IF;
  UPDATE public.sowrix_r467_leads SET next_followup_at=v_date,updated_at=now()
   WHERE id=v_id AND stage NOT IN('won','lost');
  IF NOT FOUND THEN RETURN false;END IF;
 ELSIF p_action='lead_note' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_id:=(p_data->>'id')::uuid;v_body:=btrim(coalesce(p_data->>'body',''));
  IF length(v_body) NOT BETWEEN 5 AND 1200 THEN RAISE EXCEPTION 'Invalid note' USING ERRCODE='22023';END IF;
  INSERT INTO public.sowrix_r467_lead_notes(lead_id,body,author_id)
   SELECT id,v_body,auth.uid() FROM public.sowrix_r467_leads WHERE id=v_id;
  IF NOT FOUND THEN RETURN false;END IF;
 ELSIF p_action='consultation_request' THEN
  IF NOT (is_admin OR r='client') THEN RAISE EXCEPTION 'Client or Admin only' USING ERRCODE='42501';END IF;
  v_org:=(p_data->>'organization_id')::uuid;v_subject:=btrim(coalesce(p_data->>'subject',''));
  v_date:=(p_data->>'preferred_at')::timestamptz;
  IF length(v_subject) NOT BETWEEN 5 AND 160 OR v_date<now()+interval '1 hour' OR v_date>now()+interval '180 days'
    OR NOT EXISTS(SELECT 1 FROM public.clients WHERE id=v_org AND status='active')
    OR (NOT is_admin AND NOT public.sowrix_r466_client_org(v_org))
  THEN RAISE EXCEPTION 'Invalid appointment request' USING ERRCODE='22023';END IF;
  INSERT INTO public.sowrix_r467_consultations(organization_id,requested_by,subject,preferred_at)
   VALUES(v_org,auth.uid(),v_subject,v_date);
 ELSIF p_action='consultation_state' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_id:=(p_data->>'id')::uuid;v_state:=p_data->>'state';
  IF v_state NOT IN ('confirmed','declined','completed','cancelled') THEN RAISE EXCEPTION 'Invalid appointment state' USING ERRCODE='22023';END IF;
  UPDATE public.sowrix_r467_consultations SET state=v_state,updated_at=now() WHERE id=v_id;
  IF NOT FOUND THEN RETURN false;END IF;
 ELSIF p_action='message_create' THEN
  IF NOT (is_admin OR r='client') THEN RAISE EXCEPTION 'Client or Admin only' USING ERRCODE='42501';END IF;
  v_org:=(p_data->>'organization_id')::uuid;v_subject:=btrim(coalesce(p_data->>'subject',''));
  v_body:=btrim(coalesce(p_data->>'body',''));
  IF length(v_subject) NOT BETWEEN 4 AND 120 OR length(v_body) NOT BETWEEN 3 AND 2000
    OR NOT EXISTS(SELECT 1 FROM public.clients WHERE id=v_org AND status='active')
    OR (NOT is_admin AND NOT public.sowrix_r466_client_org(v_org))
  THEN RAISE EXCEPTION 'Invalid client message' USING ERRCODE='22023';END IF;
  INSERT INTO public.sowrix_r467_messages(organization_id,author_id,subject,body)
  VALUES(v_org,auth.uid(),v_subject,v_body);
 ELSIF p_action='agreement_create' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_org:=(p_data->>'organization_id')::uuid;v_subject:=btrim(coalesce(p_data->>'title',''));
  v_body:=btrim(coalesce(p_data->>'document_reference',''));
  IF length(v_subject) NOT BETWEEN 5 AND 140 OR length(v_body) NOT BETWEEN 5 AND 250
   OR NOT EXISTS(SELECT 1 FROM public.clients WHERE id=v_org AND status='active')
   THEN RAISE EXCEPTION 'Invalid agreement metadata' USING ERRCODE='22023';END IF;
  INSERT INTO public.sowrix_r467_agreements(organization_id,title,document_reference,created_by)
   VALUES(v_org,v_subject,v_body,auth.uid());
 ELSIF p_action='agreement_review' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_id:=(p_data->>'id')::uuid;v_state:=p_data->>'state';
  IF v_state NOT IN ('review','approved','archived') THEN RAISE EXCEPTION 'Invalid agreement decision' USING ERRCODE='22023';END IF;
  SELECT * INTO v_agreement FROM public.sowrix_r467_agreements WHERE id=v_id FOR UPDATE;
  IF NOT FOUND THEN RETURN false;END IF;
  IF v_state='review' AND v_agreement.state<>'draft' OR
    v_state='approved' AND (v_agreement.state<>'review' OR v_agreement.created_by=auth.uid()) OR
    v_state='archived' AND v_agreement.state<>'approved'
  THEN RAISE EXCEPTION 'Independent review or state change required' USING ERRCODE='42501';END IF;
  UPDATE public.sowrix_r467_agreements SET state=v_state,reviewed_by=auth.uid(),reviewed_at=now() WHERE id=v_id;
 ELSIF p_action='agreement_ack' THEN
  IF r<>'client' THEN RAISE EXCEPTION 'Client only' USING ERRCODE='42501';END IF;
  v_id:=(p_data->>'id')::uuid;
  INSERT INTO public.sowrix_r467_agreement_ack(agreement_id,user_id)
   SELECT id,auth.uid() FROM public.sowrix_r467_agreements
   WHERE id=v_id AND state='approved' AND public.sowrix_r466_client_org(organization_id)
   ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RETURN false;END IF;
 ELSIF p_action='status_create' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_subject:=btrim(coalesce(p_data->>'service',''));v_state:=p_data->>'category';v_body:=btrim(coalesce(p_data->>'message',''));
  IF length(v_subject) NOT BETWEEN 3 AND 80 OR v_state NOT IN('notice','maintenance','degraded','incident','resolved')
    OR length(v_body) NOT BETWEEN 10 AND 500 THEN RAISE EXCEPTION 'Invalid public status update' USING ERRCODE='22023';END IF;
  INSERT INTO public.sowrix_r467_status_updates(service,category,message,updated_by,expires_at)
   VALUES(v_subject,v_state,v_body,auth.uid(),now()+interval '7 days');
 ELSIF p_action='status_publish' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_id:=(p_data->>'id')::uuid;
  UPDATE public.sowrix_r467_status_updates SET published=true
   WHERE id=v_id AND published=false AND updated_by<>auth.uid();
  IF NOT FOUND THEN RETURN false;END IF;
 ELSIF p_action='status_unpublish' THEN
  IF NOT is_admin THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';END IF;
  v_id:=(p_data->>'id')::uuid;
  UPDATE public.sowrix_r467_status_updates SET published=false
   WHERE id=v_id AND published=true;
  IF NOT FOUND THEN RETURN false;END IF;
 ELSE RAISE EXCEPTION 'Unknown operation' USING ERRCODE='22023';END IF;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r467_'||p_action,'business_growth','record',jsonb_build_object('action_kind',p_action));
 RETURN true;
END $fn$;


-- Service-role scheduler only. Must be enabled by an explicit private operator flag.
-- Locking and unique daily alerts make retries safe across process restarts.
CREATE OR REPLACE FUNCTION public.sowrix_r467_followup_reminders() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE item record;total integer:=0;
BEGIN
 IF auth.role() IS DISTINCT FROM 'service_role' THEN
   RAISE EXCEPTION 'Service worker only' USING ERRCODE='42501';
 END IF;
 FOR item IN
   SELECT l.id,l.created_by,coalesce(left(e.service_interest,100),'Business enquiry') AS service_name
   FROM public.sowrix_r467_leads l
   JOIN public.contact_enquiries e ON e.id=l.enquiry_id
   WHERE l.stage NOT IN('won','lost') AND l.next_followup_at IS NOT NULL AND l.next_followup_at<=now()
   ORDER BY l.next_followup_at LIMIT 50 FOR UPDATE OF l SKIP LOCKED
 LOOP
  INSERT INTO public.sowrix_r467_followup_alerts(lead_id,alert_date) VALUES(item.id,current_date) ON CONFLICT DO NOTHING;
  IF FOUND THEN
   INSERT INTO public.notifications(user_id,category,title,body)
   VALUES(item.created_by,'sales_followup','SOWRIX CRM follow-up due',
     'A sales lead needs review. Open the Business Growth Center.');
   total:=total+1;
  END IF;
 END LOOP;
 RETURN total;
END $fn$;

-- Organization selector limits clients to their OWN active memberships.
CREATE OR REPLACE FUNCTION public.sowrix_r467_org_choices() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE is_admin boolean;r text;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_user_active(auth.uid()) THEN RAISE EXCEPTION 'Active account required' USING ERRCODE='42501';END IF;
 is_admin:=public.sowrix_access_admin();r:=public.sowrix_access_role();
 IF NOT(is_admin OR r='client') THEN RAISE EXCEPTION 'Client or Admin only' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.organization_name) FROM (
  SELECT c.id,left(c.organization_name,140) organization_name
  FROM public.clients c WHERE c.status='active'
    AND (is_admin OR public.sowrix_r466_client_org(c.id))
  ORDER BY c.organization_name LIMIT 100)x),'[]'::jsonb);
END $fn$;
REVOKE ALL ON FUNCTION public.sowrix_r467_public_status() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r467_public_status() TO anon,authenticated;
REVOKE ALL ON FUNCTION public.sowrix_r467_board(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r467_board(text) TO authenticated;
REVOKE ALL ON FUNCTION public.sowrix_r467_apply(text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r467_apply(text,jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.sowrix_r467_org_choices() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r467_org_choices() TO authenticated;
REVOKE ALL ON FUNCTION public.sowrix_r467_followup_reminders() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r467_followup_reminders() TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
