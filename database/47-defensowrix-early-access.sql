-- SOWRIX DEFENSOWRIX Early Access foundation. Additive; do not remove existing data.
BEGIN;

CREATE TABLE IF NOT EXISTS public.sowrix_early_access_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_number bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
    request_id text GENERATED ALWAYS AS ('SW/EA/' || lpad(request_number::text,4,'0')) STORED UNIQUE,
    submission_key uuid NOT NULL UNIQUE,
    full_name text NOT NULL CHECK (length(btrim(full_name)) BETWEEN 2 AND 200),
    company_name text NOT NULL CHECK (length(btrim(company_name)) BETWEEN 2 AND 200),
    business_email text NOT NULL CHECK (length(business_email) <= 254 AND business_email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]{2,}$'),
    contact_number text NOT NULL CHECK (contact_number ~ '^[+0-9][0-9 ()-]{7,18}$'),
    interested_solutions text[] NOT NULL CHECK (cardinality(interested_solutions) BETWEEN 1 AND 17),
    approximate_device_count integer NOT NULL CHECK (approximate_device_count BETWEEN 0 AND 10000000),
    business_requirements text NOT NULL CHECK (length(btrim(business_requirements)) BETWEEN 20 AND 5000),
    contact_consent boolean NOT NULL CHECK (contact_consent),
    consented_at timestamptz NOT NULL DEFAULT now(),
    status text NOT NULL DEFAULT 'new' CHECK (status IN ('new','contacted','waiting','converted','closed')),
    assigned_employee uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    follow_up_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (interested_solutions <@ ARRAY['Infrastructure Monitoring','Network Monitoring','Firewall Health','Endpoint Monitoring','Hardware Monitoring','Authorized CCTV and NVR Health','Printer and UPS Monitoring','NAS and Storage Monitoring','Backup Health','AI Engineer Copilot','AI-Assisted Troubleshooting','Defensive Security Operations','NOC Dashboard','Incident Management','Intelligent Alerts','Analytics and Reporting','Multi-Site Monitoring']::text[])
);

CREATE TABLE IF NOT EXISTS public.sowrix_early_access_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL REFERENCES public.sowrix_early_access_requests(id) ON DELETE RESTRICT,
    actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    event_type text NOT NULL CHECK (event_type IN ('created','status_changed','assigned','follow_up','note')),
    previous_status text,
    new_status text,
    follow_up_at timestamptz,
    note text CHECK (note IS NULL OR length(note) <= 5000),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sowrix_early_access_status_created_idx ON public.sowrix_early_access_requests(status,created_at DESC);
CREATE INDEX IF NOT EXISTS sowrix_early_access_assigned_followup_idx ON public.sowrix_early_access_requests(assigned_employee,follow_up_at);
CREATE INDEX IF NOT EXISTS sowrix_early_access_email_idx ON public.sowrix_early_access_requests(lower(business_email));
CREATE INDEX IF NOT EXISTS sowrix_early_access_history_request_idx ON public.sowrix_early_access_history(request_id,created_at DESC);

ALTER TABLE public.sowrix_early_access_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_early_access_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_early_access_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_early_access_history FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.sowrix_early_access_requests, public.sowrix_early_access_history FROM PUBLIC, anon, authenticated;
GRANT SELECT, UPDATE ON public.sowrix_early_access_requests TO authenticated;
GRANT SELECT ON public.sowrix_early_access_history TO authenticated;
GRANT ALL ON public.sowrix_early_access_requests, public.sowrix_early_access_history TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.sowrix_early_access_requests_request_number_seq TO service_role;

DROP POLICY IF EXISTS sowrix_early_access_admin_read ON public.sowrix_early_access_requests;
CREATE POLICY sowrix_early_access_admin_read ON public.sowrix_early_access_requests FOR SELECT TO authenticated
 USING (public.sowrix_access_admin() AND public.sowrix_has_module_access('enquiries'));
DROP POLICY IF EXISTS sowrix_early_access_admin_update ON public.sowrix_early_access_requests;
CREATE POLICY sowrix_early_access_admin_update ON public.sowrix_early_access_requests FOR UPDATE TO authenticated
 USING (public.sowrix_access_admin() AND public.sowrix_has_module_access('enquiries'))
 WITH CHECK (public.sowrix_access_admin() AND public.sowrix_has_module_access('enquiries'));
DROP POLICY IF EXISTS sowrix_early_access_history_admin_read ON public.sowrix_early_access_history;
CREATE POLICY sowrix_early_access_history_admin_read ON public.sowrix_early_access_history FOR SELECT TO authenticated
 USING (public.sowrix_access_admin() AND public.sowrix_has_module_access('enquiries'));
DROP POLICY IF EXISTS sowrix_early_access_history_admin_insert ON public.sowrix_early_access_history;
CREATE POLICY sowrix_early_access_history_admin_insert ON public.sowrix_early_access_history FOR INSERT TO authenticated
 WITH CHECK (public.sowrix_access_admin() AND public.sowrix_has_module_access('enquiries'));

CREATE OR REPLACE FUNCTION public.sowrix_early_access_touch() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  NEW.updated_at := now();
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.sowrix_early_access_history(request_id,actor_id,event_type,previous_status,new_status)
    VALUES(NEW.id,auth.uid(),'status_changed',OLD.status,NEW.status);
  END IF;
  IF OLD.assigned_employee IS DISTINCT FROM NEW.assigned_employee THEN
    INSERT INTO public.sowrix_early_access_history(request_id,actor_id,event_type,note)
    VALUES(NEW.id,auth.uid(),'assigned',CASE WHEN NEW.assigned_employee IS NULL THEN 'Assignment cleared' ELSE 'Employee assignment changed' END);
  END IF;
  IF OLD.follow_up_at IS DISTINCT FROM NEW.follow_up_at THEN
    INSERT INTO public.sowrix_early_access_history(request_id,actor_id,event_type,follow_up_at)
    VALUES(NEW.id,auth.uid(),'follow_up',NEW.follow_up_at);
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_early_access_touch() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS sowrix_early_access_touch ON public.sowrix_early_access_requests;
CREATE TRIGGER sowrix_early_access_touch BEFORE UPDATE ON public.sowrix_early_access_requests
FOR EACH ROW EXECUTE FUNCTION public.sowrix_early_access_touch();

CREATE OR REPLACE FUNCTION public.sowrix_submit_early_access(p_request jsonb,p_submission_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.sowrix_early_access_requests;
BEGIN
  IF p_submission_key IS NULL OR jsonb_typeof(p_request) IS DISTINCT FROM 'object' OR
     (p_request - ARRAY['full_name','company_name','business_email','contact_number','interested_solutions','approximate_device_count','business_requirements','contact_consent']) <> '{}'::jsonb OR
     coalesce((p_request->>'contact_consent')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'Invalid early access request' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.sowrix_early_access_requests(submission_key,full_name,company_name,business_email,contact_number,interested_solutions,approximate_device_count,business_requirements,contact_consent)
  VALUES(p_submission_key,btrim(p_request->>'full_name'),btrim(p_request->>'company_name'),lower(btrim(p_request->>'business_email')),btrim(p_request->>'contact_number'),ARRAY(SELECT jsonb_array_elements_text(p_request->'interested_solutions')), (p_request->>'approximate_device_count')::integer,btrim(p_request->>'business_requirements'),true)
  ON CONFLICT(submission_key) DO UPDATE SET submission_key=excluded.submission_key
  RETURNING * INTO r;
  IF r.created_at= r.updated_at THEN
    INSERT INTO public.sowrix_early_access_history(request_id,event_type,new_status) VALUES(r.id,'created','new') ON CONFLICT DO NOTHING;
  END IF;
  RETURN jsonb_build_object('accepted',true,'request_id',r.request_id);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_submit_early_access(jsonb,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_submit_early_access(jsonb,uuid) TO service_role;

COMMIT;
