-- Website business-interest intake only. Does not enable Early Access or provision product access.
BEGIN;
CREATE TABLE public.sowrix_dw_interest (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 number bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
 submission_key uuid NOT NULL UNIQUE,
 fingerprint text NOT NULL UNIQUE,
 full_name text NOT NULL CHECK (length(full_name) BETWEEN 2 AND 120),
 company_name text NOT NULL CHECK (length(company_name) BETWEEN 2 AND 160),
 business_email text NOT NULL CHECK (length(business_email)<=254 AND business_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]{2,}$'),
 phone text NOT NULL CHECK (phone ~ '^[+]?[0-9][0-9 ()-]{7,22}$'),
 solution text NOT NULL CHECK (solution IN ('Infrastructure Monitoring','AI Engineer Troubleshooting','SOC Security Operations','Complete DEFENSOWRIX Platform')),
 infrastructure text NOT NULL CHECK (length(infrastructure) BETWEEN 5 AND 500),
 device_count integer NOT NULL CHECK (device_count BETWEEN 0 AND 10000000),
 requirements text NOT NULL CHECK (length(requirements) BETWEEN 20 AND 4000),
 consent boolean NOT NULL CHECK (consent),
 status text NOT NULL DEFAULT 'new' CHECK (status IN ('new','under_review','contacted','discussion_scheduled','awaiting_availability','approved','closed')),
 assignee uuid REFERENCES auth.users(id),
 client_id uuid REFERENCES public.clients(id) ON DELETE RESTRICT,
 discussion timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.sowrix_dw_interest_history (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 request_id uuid REFERENCES public.sowrix_dw_interest(id),
 actor uuid,
 event text NOT NULL,
 detail jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON public.sowrix_dw_interest(status,created_at DESC);
CREATE INDEX ON public.sowrix_dw_interest_history(request_id,id DESC);
ALTER TABLE public.sowrix_dw_interest ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_dw_interest_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_dw_interest,public.sowrix_dw_interest_history FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.sowrix_submit_dw_interest(p_record jsonb,p_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.sowrix_dw_interest; fp text;
BEGIN
 IF p_key IS NULL OR jsonb_typeof(p_record) IS DISTINCT FROM 'object' OR p_record->'consent' IS DISTINCT FROM 'true'::jsonb THEN
   RAISE EXCEPTION 'Invalid interest request' USING ERRCODE='22023';
 END IF;
 fp:=encode(sha256(convert_to(jsonb_build_array(lower(btrim(p_record->>'business_email')),
      lower(btrim(p_record->>'company_name')),p_record->>'solution',lower(btrim(p_record->>'requirements')))::text,'UTF8')),'hex');
 INSERT INTO public.sowrix_dw_interest(submission_key,fingerprint,full_name,company_name,business_email,phone,solution,infrastructure,device_count,requirements,consent)
 VALUES(p_key,fp,p_record->>'full_name',p_record->>'company_name',lower(btrim(p_record->>'business_email')),
 p_record->>'phone',p_record->>'solution',p_record->>'infrastructure',(p_record->>'device_count')::integer,p_record->>'requirements',true)
 ON CONFLICT DO NOTHING RETURNING * INTO r;
 IF FOUND THEN
   INSERT INTO public.sowrix_dw_interest_history(request_id,event) VALUES(r.id,'received');
 ELSE
   SELECT * INTO r FROM public.sowrix_dw_interest WHERE submission_key=p_key AND fingerprint=fp
     AND full_name=p_record->>'full_name' AND phone=p_record->>'phone'
     AND infrastructure=p_record->>'infrastructure' AND device_count=(p_record->>'device_count')::integer
     AND company_name=p_record->>'company_name' AND requirements=p_record->>'requirements';
   IF NOT FOUND THEN RETURN jsonb_build_object('conflict',true); END IF;
 END IF;
 RETURN jsonb_build_object('accepted',true,'reference','SW/DR/'||lpad(r.number::text,greatest(4,length(r.number::text)),'0'));
END $$;
REVOKE ALL ON FUNCTION public.sowrix_submit_dw_interest(jsonb,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_submit_dw_interest(jsonb,uuid) TO service_role;

CREATE FUNCTION public.sowrix_manage_dw_interest(p_action text,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.sowrix_dw_interest; result jsonb; actor uuid:=auth.uid();
  target_status text; target_assignee uuid; target_discussion timestamptz; note text;
BEGIN
 IF actor IS NULL OR NOT coalesce(public.sowrix_access_admin(),false)
   OR NOT coalesce(public.sowrix_has_module_access('enquiries'),false) THEN
   RAISE EXCEPTION 'Enquiries admin required' USING ERRCODE='42501';
 END IF;
 IF p_action='counts' THEN
   SELECT jsonb_build_object('total',count(*),'new',count(*) FILTER(WHERE status='new'),
    'under_review',count(*) FILTER(WHERE status='under_review'),'contacted',count(*) FILTER(WHERE status='contacted'),
    'discussion_scheduled',count(*) FILTER(WHERE status='discussion_scheduled'),
    'awaiting_availability',count(*) FILTER(WHERE status='awaiting_availability'),
    'approved',count(*) FILTER(WHERE status='approved'),'closed',count(*) FILTER(WHERE status='closed'))
   INTO result FROM public.sowrix_dw_interest;
 ELSIF p_action='employees' THEN
   SELECT coalesce(jsonb_agg(jsonb_build_object('id',q.user_id,'name',q.full_name)),'[]'::jsonb) INTO result
   FROM (SELECT user_id,full_name FROM public.employees WHERE user_id IS NOT NULL AND employment_status='active'
         ORDER BY full_name,user_id LIMIT 500) q;
 ELSIF p_action IN ('list','export') THEN
   SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.created_at DESC,q.id),'[]'::jsonb) INTO result FROM (
    SELECT id,'SW/DR/'||lpad(number::text,greatest(4,length(number::text)),'0') AS reference,
    full_name,company_name,business_email,phone,solution,device_count,status,discussion,created_at
    FROM public.sowrix_dw_interest
    WHERE (coalesce(p_data->>'status','')='' OR status=p_data->>'status')
      AND strpos(lower(concat_ws(' ','SW/DR/'||lpad(number::text,greatest(4,length(number::text)),'0'),
      company_name,full_name,business_email)),lower(left(coalesce(p_data->>'search',''),160)))>0
    ORDER BY created_at DESC,id LIMIT CASE WHEN p_action='export' THEN 2000 ELSE 50 END
    OFFSET CASE WHEN p_action='export' THEN 0 ELSE (greatest(1,least(1000,coalesce((p_data->>'page')::int,1)))-1)*50 END
   ) q;
   IF p_action='export' THEN
     INSERT INTO public.sowrix_dw_interest_history(actor,event,detail)
     VALUES(actor,'export',jsonb_build_object('rows',jsonb_array_length(result)));
   END IF;
 ELSIF p_action IN ('detail','update','link_client') THEN
   SELECT * INTO r FROM public.sowrix_dw_interest WHERE id=(p_data->>'id')::uuid FOR UPDATE;
   IF NOT FOUND THEN RAISE EXCEPTION 'Request not found' USING ERRCODE='22023'; END IF;
   IF p_action='link_client' THEN
     IF NOT coalesce(public.sowrix_has_module_access('clients'),false) THEN
       RAISE EXCEPTION 'Clients permission required' USING ERRCODE='42501';
     END IF;
     IF r.status<>'approved' OR r.client_id IS NOT NULL OR NOT EXISTS(
       SELECT 1 FROM public.clients c WHERE c.id=(p_data->>'client_id')::uuid
       AND lower(btrim(c.email))=r.business_email
       AND lower(btrim(c.organization_name))=lower(btrim(r.company_name))) THEN
       RAISE EXCEPTION 'Approved request and matching client record required' USING ERRCODE='22023';
     END IF;
     UPDATE public.sowrix_dw_interest SET client_id=(p_data->>'client_id')::uuid WHERE id=r.id;
     INSERT INTO public.sowrix_dw_interest_history(request_id,actor,event,detail)
     VALUES(r.id,actor,'client_linked',jsonb_build_object('client_id',p_data->>'client_id'));
     RETURN jsonb_build_object('saved',true);
   END IF;
   IF p_action='update' THEN
     target_status:=p_data->>'status'; target_assignee:=(p_data->>'assignee')::uuid;
     target_discussion:=(p_data->>'discussion')::timestamptz; note:=btrim(coalesce(p_data->>'note',''));
     IF target_status IS NULL OR length(note)>2000 OR
       (target_assignee IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.employees WHERE user_id=target_assignee AND employment_status='active')) OR
       (target_status='discussion_scheduled' AND target_discussion IS NULL) OR
       NOT (target_status=r.status OR (r.status<>'closed' AND target_status='closed') OR
            (r.status='new' AND target_status='under_review') OR
            (r.status='under_review' AND target_status='contacted') OR
            (r.status IN ('contacted','discussion_scheduled','awaiting_availability')
                 AND target_status IN ('contacted','discussion_scheduled','awaiting_availability','approved'))) THEN
       RAISE EXCEPTION 'Invalid request update' USING ERRCODE='22023';
     END IF;
     UPDATE public.sowrix_dw_interest SET status=target_status,assignee=target_assignee,discussion=target_discussion WHERE id=r.id;
     INSERT INTO public.sowrix_dw_interest_history(request_id,actor,event,detail)
     VALUES(r.id,actor,'updated',jsonb_build_object('previous_status',r.status,'status',target_status,
       'previous_assignee',r.assignee,'assignee',target_assignee,'discussion',target_discussion,'note',note));
     RETURN jsonb_build_object('saved',true);
   END IF;
   INSERT INTO public.sowrix_dw_interest_history(request_id,actor,event) VALUES(r.id,actor,'viewed');
   result:=jsonb_build_object('request',(to_jsonb(r)-ARRAY['submission_key','fingerprint','number']) ||
    jsonb_build_object('reference','SW/DR/'||lpad(r.number::text,greatest(4,length(r.number::text)),'0')),
    'history',(SELECT coalesce(jsonb_agg(to_jsonb(h) ORDER BY h.id DESC),'[]'::jsonb) FROM
      (SELECT hist.id,hist.actor,hist.event,hist.detail,hist.created_at FROM public.sowrix_dw_interest_history hist
       WHERE hist.request_id=r.id AND hist.event<>'viewed' ORDER BY hist.id DESC LIMIT 100) h));
 ELSE RAISE EXCEPTION 'Invalid action' USING ERRCODE='22023';
 END IF;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_manage_dw_interest(text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_manage_dw_interest(text,jsonb) TO authenticated;
COMMIT;
