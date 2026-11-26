-- Additive V2 security boundary; after R46-26 prerequisites including 13.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_def_can(uuid,text)') IS NULL
 OR to_regprocedure('public.sowrix_def_collector_v11(text,text,jsonb)') IS NULL
 OR to_regprocedure('public.sowrix_def_collector(text,text,jsonb)') IS NULL THEN
  RAISE EXCEPTION 'Install existing Defensowrix migrations through 13 first';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v2_context(p_org uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caps text[];
BEGIN
 IF auth.uid() IS NULL OR p_org IS NULL OR NOT EXISTS (
  SELECT 1 FROM public.sowrix_def_orgs o JOIN public.clients c ON c.id=o.organization_id
   WHERE o.organization_id=p_org AND o.enabled AND c.status='active')
  OR NOT coalesce(public.sowrix_def_can(p_org,'read'),false) THEN
  RAISE EXCEPTION 'Resource not found or access not permitted' USING ERRCODE='42501';
 END IF;
 SELECT ARRAY(SELECT k FROM unnest(ARRAY['read','operate','configure','members','live','ai']) k
   WHERE public.sowrix_def_can(p_org,k)) INTO caps;
 PERFORM public.sowrix_def_audit_write(p_org,'ops_v2_context',p_org::text,'{}'::jsonb);
 RETURN jsonb_build_object('release','V2.0.0','organization_id',p_org,'capabilities',caps);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v2_context(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v2_context(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v2_ingest(p_token text,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.sowrix_def_collectors; s jsonb; result jsonb; d uuid;
BEGIN
 IF p_token IS NULL OR p_token !~ '^[0-9a-f]{64}$' THEN
  RAISE EXCEPTION 'Collector is not authorized' USING ERRCODE='42501';
 END IF;
 SELECT * INTO c FROM public.sowrix_def_collectors
 WHERE token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') FOR UPDATE;
 IF c.id IS NULL OR c.status<>'active' OR (c.token_expires_at IS NOT NULL AND c.token_expires_at<=now())
 OR NOT EXISTS(SELECT 1 FROM public.sowrix_def_orgs o JOIN public.clients cl ON cl.id=o.organization_id
  WHERE o.organization_id=c.organization_id AND o.enabled AND cl.status='active') THEN
  RAISE EXCEPTION 'Collector is not authorized' USING ERRCODE='42501';
 END IF;
 IF jsonb_typeof(p_data) IS DISTINCT FROM 'object' OR octet_length(p_data::text)>500000
 OR EXISTS (SELECT 1 FROM jsonb_object_keys(p_data) k WHERE k NOT IN ('sequence','samples'))
 OR jsonb_typeof(p_data->'sequence') IS DISTINCT FROM 'number'
 OR coalesce(p_data->>'sequence','') !~ '^[1-9][0-9]{0,18}$'
 OR jsonb_typeof(p_data->'samples') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid monitoring evidence' USING ERRCODE='22023'; END IF;
 IF (p_data->>'sequence')::numeric>9223372036854775807 OR jsonb_array_length(p_data->'samples') NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION 'Invalid monitoring evidence' USING ERRCODE='22023'; END IF;
 FOR s IN SELECT jsonb_array_elements(p_data->'samples') LOOP
  IF jsonb_typeof(s) IS DISTINCT FROM 'object' OR NOT (s ?& ARRAY['device_id','observed_at','status','metrics'])
   OR EXISTS(SELECT 1 FROM jsonb_object_keys(s) k WHERE k NOT IN ('device_id','observed_at','status','metrics'))
   OR jsonb_typeof(s->'device_id') IS DISTINCT FROM 'string'
   OR coalesce(s->>'device_id','') !~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
   OR jsonb_typeof(s->'observed_at') IS DISTINCT FROM 'string'
   OR coalesce(s->>'observed_at','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-](0[0-9]|1[0-5]):[0-5][0-9])$'
   OR jsonb_typeof(s->'status') IS DISTINCT FROM 'string' OR coalesce(s->>'status','') NOT IN ('up','down','unknown','unsupported')
   OR jsonb_typeof(s->'metrics') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Invalid monitoring evidence' USING ERRCODE='22023'; END IF;
  IF octet_length((s->'metrics')::text)>8192 OR (SELECT count(*) FROM jsonb_object_keys(s->'metrics'))>100
   OR EXISTS(SELECT 1 FROM jsonb_each(s->'metrics') m WHERE m.key !~ '^[a-z][a-z0-9_]{0,63}$' OR CASE WHEN jsonb_typeof(m.value)='number' THEN abs((m.value::text)::numeric)>1e15 ELSE true END)
   OR (s->>'observed_at')::timestamptz NOT BETWEEN now()-interval '24 hours' AND now()+interval '2 minutes' THEN
   RAISE EXCEPTION 'Invalid monitoring evidence' USING ERRCODE='22023'; END IF;
  SELECT id INTO d FROM public.sowrix_def_devices WHERE id=(s->>'device_id')::uuid AND organization_id=c.organization_id
   AND site_id=c.site_id AND collector_id=c.id AND enabled FOR UPDATE;
  IF d IS NULL THEN RAISE EXCEPTION 'Resource not found or access not permitted' USING ERRCODE='42501'; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_data->'samples') AS obs(value) GROUP BY (obs.value->>'device_id')::uuid,(obs.value->>'observed_at')::timestamptz HAVING count(*)>1) THEN
  RAISE EXCEPTION 'Duplicate observation' USING ERRCODE='22023'; END IF;
 -- Existing transaction owns sequence, samples, rules and incidents. No second store.
 result:=public.sowrix_def_collector('ingest',p_token,p_data);
 IF NOT coalesce((result->>'duplicate')::boolean,false) THEN
  INSERT INTO public.sowrix_def_audit(organization_id,actor_id,action,target_id,details)
  VALUES(c.organization_id,NULL,'ops_v2_ingest',c.id::text,jsonb_build_object('actor_type','collector','sequence',(p_data->>'sequence')::bigint,'accepted',(result->>'accepted')::integer));
 END IF;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v2_ingest(text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v2_ingest(text,jsonb) TO service_role;
COMMIT;
