-- Restricted Admin database operations for the additive Early Access schema.
BEGIN;
CREATE OR REPLACE FUNCTION public.sowrix_early_access_admin(p_action text,p_data jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE out_value jsonb; rid uuid; status_value text; employee_value uuid; page_value int; size_value int; search_value text;
BEGIN
 IF auth.uid() IS NULL OR NOT public.sowrix_access_admin() OR NOT public.sowrix_has_module_access('enquiries') THEN
   RAISE EXCEPTION 'Admin enquiries permission required' USING ERRCODE='42501';
 END IF;
 IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' THEN RAISE EXCEPTION 'Invalid request'; END IF;
 IF p_action='list' OR p_action='export' OR p_action='counts' THEN
   search_value:=left(btrim(coalesce(p_data->>'search','')),200);
   status_value:=p_data->>'status';
   IF status_value IS NOT NULL AND status_value NOT IN ('new','contacted','waiting','converted','closed') THEN RAISE EXCEPTION 'Invalid status filter'; END IF;
   IF p_action='counts' THEN
     SELECT jsonb_build_object('total',count(*),'new',count(*) FILTER(WHERE status='new'),'contacted',count(*) FILTER(WHERE status='contacted'),'waiting',count(*) FILTER(WHERE status='waiting'),'converted',count(*) FILTER(WHERE status='converted')) INTO out_value FROM public.sowrix_early_access_requests;
   ELSE
     page_value:=greatest(1,least(coalesce((p_data->>'page')::int,1),10000)); size_value:=greatest(1,least(coalesce((p_data->>'page_size')::int,50),100));
     SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.created_at DESC),'[]'::jsonb) INTO out_value FROM (
       SELECT id,request_id,full_name,company_name,business_email,contact_number,interested_solutions,approximate_device_count,status,assigned_employee,follow_up_at,created_at,updated_at
       FROM public.sowrix_early_access_requests r WHERE (status_value IS NULL OR r.status=status_value) AND
        (search_value='' OR concat_ws(' ',r.request_id,r.full_name,r.company_name,r.business_email) ILIKE '%'||search_value||'%')
       ORDER BY created_at DESC LIMIT CASE WHEN p_action='export' THEN 5000 ELSE size_value END OFFSET CASE WHEN p_action='export' THEN 0 ELSE (page_value-1)*size_value END
     ) q;
   END IF;
   RETURN coalesce(out_value,'{}'::jsonb);
 END IF;
 rid:=nullif(p_data->>'id','')::uuid;
 IF p_action='detail' THEN
   SELECT jsonb_build_object('request',to_jsonb(r),'history',coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.created_at DESC) FROM public.sowrix_early_access_history h WHERE h.request_id=r.id),'[]'::jsonb)) INTO out_value FROM public.sowrix_early_access_requests r WHERE r.id=rid;
   IF out_value IS NULL THEN RAISE EXCEPTION 'Request not found' USING ERRCODE='P0002'; END IF; RETURN out_value;
 ELSIF p_action='history' THEN
   SELECT coalesce(jsonb_agg(to_jsonb(h) ORDER BY h.created_at DESC),'[]'::jsonb) INTO out_value FROM public.sowrix_early_access_history h WHERE h.request_id=rid;
   IF NOT EXISTS(SELECT 1 FROM public.sowrix_early_access_requests WHERE id=rid) THEN RAISE EXCEPTION 'Request not found' USING ERRCODE='P0002'; END IF; RETURN out_value;
 ELSIF p_action='status' THEN
   status_value:=p_data->>'status';
   IF status_value NOT IN ('new','contacted','waiting','converted','closed') THEN RAISE EXCEPTION 'Invalid status'; END IF;
   UPDATE public.sowrix_early_access_requests SET status=status_value WHERE id=rid AND
     (status=status_value OR (status='new' AND status_value IN ('contacted','closed')) OR (status='contacted' AND status_value IN ('waiting','converted','closed')) OR (status='waiting' AND status_value IN ('contacted','converted','closed')) OR (status='converted' AND status_value='closed')) RETURNING to_jsonb(sowrix_early_access_requests.*) INTO out_value;
   IF out_value IS NULL THEN RAISE EXCEPTION 'Invalid transition or request not found'; END IF; RETURN out_value;
 ELSIF p_action='assign' THEN
   employee_value:=nullif(p_data->>'employee_id','')::uuid;
   IF employee_value IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.employees e WHERE e.user_id=employee_value AND e.employment_status='active') THEN RAISE EXCEPTION 'Active employee assignment required'; END IF;
   UPDATE public.sowrix_early_access_requests SET assigned_employee=employee_value WHERE id=rid RETURNING to_jsonb(sowrix_early_access_requests.*) INTO out_value;
   IF out_value IS NULL THEN RAISE EXCEPTION 'Request not found'; END IF; RETURN out_value;
 ELSIF p_action='follow_up' THEN
   UPDATE public.sowrix_early_access_requests SET follow_up_at=nullif(p_data->>'follow_up_at','')::timestamptz WHERE id=rid RETURNING to_jsonb(sowrix_early_access_requests.*) INTO out_value;
   IF out_value IS NULL THEN RAISE EXCEPTION 'Request not found'; END IF;
   IF nullif(btrim(p_data->>'note'),'') IS NOT NULL THEN
     INSERT INTO public.sowrix_early_access_history(request_id,actor_id,event_type,note) VALUES(rid,auth.uid(),'note',left(btrim(p_data->>'note'),5000));
   END IF; RETURN out_value;
 ELSE RAISE EXCEPTION 'Unsupported Early Access operation'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_early_access_admin(text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_early_access_admin(text,jsonb) TO authenticated;
COMMIT;
