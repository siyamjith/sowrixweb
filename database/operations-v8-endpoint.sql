-- V8 additive endpoint index on existing V5 leases and V4 evidence.
BEGIN;
DO $$ BEGIN IF to_regprocedure('public.sowrix_ops_v7_configure(uuid,uuid,jsonb)') IS NULL THEN RAISE EXCEPTION 'Install V7 first';END IF;END $$;
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v8_profiles(
 organization_id uuid NOT NULL,asset_id uuid PRIMARY KEY,configuration jsonb NOT NULL,enabled boolean NOT NULL,actor_id uuid NOT NULL REFERENCES auth.users(id),updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(organization_id,asset_id) REFERENCES public.sowrix_def_devices(organization_id,id),UNIQUE(organization_id,asset_id));
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v8_observations(
 evidence_id uuid PRIMARY KEY,metadata_id uuid NOT NULL,run_id uuid NOT NULL UNIQUE,organization_id uuid NOT NULL,asset_id uuid NOT NULL,observed_at timestamptz NOT NULL,status text NOT NULL,metrics jsonb NOT NULL,inventory jsonb NOT NULL,
 FOREIGN KEY(organization_id,asset_id,evidence_id) REFERENCES public.sowrix_ops_v4_evidence(organization_id,asset_id,id),
 FOREIGN KEY(organization_id,asset_id,metadata_id) REFERENCES public.sowrix_ops_v4_evidence(organization_id,asset_id,id));
CREATE INDEX IF NOT EXISTS sowrix_ops_v8_history ON public.sowrix_ops_v8_observations(organization_id,asset_id,observed_at DESC,evidence_id DESC);
DO $$ DECLARE t text;BEGIN FOREACH t IN ARRAY ARRAY['profiles','observations'] LOOP
 EXECUTE format('ALTER TABLE public.sowrix_ops_v8_%I ENABLE ROW LEVEL SECURITY',t);EXECUTE format('REVOKE ALL ON public.sowrix_ops_v8_%I FROM PUBLIC,anon,authenticated,service_role',t);END LOOP;END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v8_validate(p jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE s jsonb;
BEGIN
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR octet_length(p::text)>4096 OR NOT(p ?& ARRAY['enabled','device_class','platform','capabilities','services']) OR (SELECT count(*) FROM jsonb_object_keys(p))<>5
 OR jsonb_typeof(p->'enabled') IS DISTINCT FROM 'boolean' OR p->>'device_class' IS NULL OR p->>'device_class' NOT IN ('server','desktop','laptop') OR p->>'platform' IS NULL OR p->>'platform' NOT IN ('Windows','Linux')
 OR jsonb_typeof(p->'capabilities') IS DISTINCT FROM 'array' OR jsonb_array_length(p->'capabilities') NOT BETWEEN 1 AND 6
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p->'capabilities') c WHERE jsonb_typeof(c)<>'string' OR c #>> '{}' NOT IN ('cpu','memory','storage','uptime','inventory','services')) OR (SELECT count(DISTINCT value) FROM jsonb_array_elements(p->'capabilities'))<>jsonb_array_length(p->'capabilities')
 OR jsonb_typeof(p->'services') IS DISTINCT FROM 'array' OR jsonb_array_length(p->'services')>4 OR (jsonb_array_length(p->'services')>0 AND NOT(p->'capabilities' ? 'services')) THEN RAISE EXCEPTION 'Invalid endpoint profile' USING ERRCODE='22023';END IF;
 FOR s IN SELECT jsonb_array_elements(p->'services') LOOP
  IF jsonb_typeof(s) IS DISTINCT FROM 'object' OR NOT(s ?& ARRAY['index','label']) OR (SELECT count(*) FROM jsonb_object_keys(s))<>2 OR jsonb_typeof(s->'index') IS DISTINCT FROM 'number' OR s->>'index' !~ '^[1-4]$' OR jsonb_typeof(s->'label') IS DISTINCT FROM 'string' OR s->>'label' !~ '^[A-Za-z0-9 _.-]{1,48}$' THEN RAISE EXCEPTION 'Invalid service alias' USING ERRCODE='22023';END IF;
 END LOOP;
 IF (SELECT count(DISTINCT value->>'index') FROM jsonb_array_elements(p->'services'))<>jsonb_array_length(p->'services') THEN RAISE EXCEPTION 'Duplicate service alias' USING ERRCODE='22023';END IF;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v8_metadata(p jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE m record;
BEGIN
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR octet_length(p::text)>1024 OR (SELECT count(*) FROM jsonb_object_keys(p))>3 THEN RAISE EXCEPTION 'Invalid endpoint inventory' USING ERRCODE='22023';END IF;
 FOR m IN SELECT key,value FROM jsonb_each(p) LOOP
  IF m.key NOT IN ('os_family','os_release','architecture') OR jsonb_typeof(m.value)<>'string' OR m.value #>> '{}' !~ '^[A-Za-z0-9 ._()+-]{1,128}$' OR (m.key='os_family' AND m.value #>> '{}' NOT IN ('Windows','Linux')) THEN RAISE EXCEPTION 'Invalid OS inventory' USING ERRCODE='22023';END IF;
 END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v8_configure(p_org uuid,p_asset uuid,p_data jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'configure');PERFORM 1 FROM public.sowrix_def_orgs WHERE organization_id=p_org FOR UPDATE;PERFORM public.sowrix_ops_v8_validate(p_data);
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE organization_id=p_org AND id=p_asset AND enabled AND protocol='prometheus' AND target='http://127.0.0.1:9188/endpoint-v8') OR EXISTS(SELECT 1 FROM public.sowrix_ops_v6_profiles WHERE asset_id=p_asset) THEN RAISE EXCEPTION 'Authorized dedicated local endpoint asset required' USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v8_profiles WHERE asset_id=p_asset) AND (SELECT count(*) FROM public.sowrix_ops_v8_profiles WHERE organization_id=p_org)>=100 THEN RAISE EXCEPTION 'Endpoint inventory limit' USING ERRCODE='54000';END IF;
 INSERT INTO public.sowrix_ops_v8_profiles VALUES(p_org,p_asset,p_data,(p_data->>'enabled')::boolean,auth.uid(),now()) ON CONFLICT(asset_id) DO UPDATE SET configuration=excluded.configuration,enabled=excluded.enabled,actor_id=auth.uid(),updated_at=now();
 UPDATE public.sowrix_ops_v5_runs SET state='cancelled',finished_at=clock_timestamp() WHERE check_id IN(SELECT id FROM public.sowrix_ops_v5_checks WHERE organization_id=p_org AND asset_id=p_asset) AND state='leased';
 UPDATE public.sowrix_ops_v5_checks SET revision=revision+1,lease_id=NULL,lease_until=NULL,owner=NULL,next_due=now(),health='UNKNOWN',failures=0,recoveries=0,enabled=enabled AND (p_data->>'enabled')::boolean WHERE organization_id=p_org AND asset_id=p_asset;
 PERFORM public.sowrix_def_audit_write(p_org,'ops_v8_profile',p_asset::text,p_data);RETURN jsonb_build_object('organization_id',p_org,'asset_id',p_asset,'configuration',p_data,'local_consent_required',true);
END $$;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v8_prior_unit(text)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_unit(text) RENAME TO sowrix_ops_v8_prior_unit;END IF;
 IF to_regprocedure('public.sowrix_ops_v8_prior_claim(text,uuid,integer)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer) RENAME TO sowrix_ops_v8_prior_claim;END IF;
 IF to_regprocedure('public.sowrix_ops_v8_prior_finish(text,uuid,uuid,jsonb)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) RENAME TO sowrix_ops_v8_prior_finish;END IF;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_unit(p_metric text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_metric='agent_available' OR p_metric ~ '^service_[1-4]_available$' THEN 'code' WHEN p_metric='cpu_cores' THEN 'count' WHEN p_metric IN ('memory_total_bytes','storage_total_bytes') THEN 'bytes' ELSE public.sowrix_ops_v8_prior_unit(p_metric) END
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_claim(p_token text,p_owner uuid,p_limit integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;job jsonb;p public.sowrix_ops_v8_profiles;jobs jsonb:='[]';
BEGIN
 result:=public.sowrix_ops_v8_prior_claim(p_token,p_owner,p_limit);
 FOR job IN SELECT jsonb_array_elements(result->'jobs') LOOP
  SELECT * INTO p FROM public.sowrix_ops_v8_profiles WHERE asset_id=(job->'device'->>'id')::uuid;
  IF p.asset_id IS NOT NULL THEN
   IF NOT p.enabled OR job->'device'->>'target' IS DISTINCT FROM 'http://127.0.0.1:9188/endpoint-v8' OR job->'device'->>'protocol' IS DISTINCT FROM 'prometheus' OR job->'device' ? 'network' THEN PERFORM public.sowrix_ops_v8_prior_finish(p_token,p_owner,(job->>'id')::uuid,'{"outcome":"cancelled","sample":null}');CONTINUE;END IF;
   job:=jsonb_set(job,'{device,endpoint}',p.configuration);
  END IF;jobs:=jobs||jsonb_build_array(job);
 END LOOP;RETURN jsonb_build_object('jobs',jobs);
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_finish(p_token text,p_owner uuid,p_run uuid,p_result jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;p public.sowrix_ops_v8_profiles;r public.sowrix_ops_v5_runs;c public.sowrix_ops_v5_checks;old public.sowrix_ops_v8_observations;meta jsonb;metrics jsonb;doc jsonb;ev uuid;companion uuid;m record;cap text;
BEGIN
 IF octet_length(p_result::text)>16000 THEN RAISE EXCEPTION 'Completion exceeds bound' USING ERRCODE='22023';END IF;
 result:=public.sowrix_ops_v8_prior_finish(p_token,p_owner,p_run,p_result-'endpoint');
 SELECT * INTO r FROM public.sowrix_ops_v5_runs WHERE id=p_run;SELECT * INTO c FROM public.sowrix_ops_v5_checks WHERE id=r.check_id;SELECT * INTO old FROM public.sowrix_ops_v8_observations WHERE run_id=p_run;
 IF old.run_id IS NOT NULL THEN IF old.inventory IS DISTINCT FROM p_result->'endpoint' THEN RAISE EXCEPTION 'Conflicting endpoint completion' USING ERRCODE='22023';END IF;RETURN result;END IF;
 SELECT * INTO p FROM public.sowrix_ops_v8_profiles WHERE organization_id=c.organization_id AND asset_id=c.asset_id AND enabled;
 IF p.asset_id IS NULL THEN IF p_result ? 'endpoint' THEN RAISE EXCEPTION 'Endpoint source not registered' USING ERRCODE='42501';END IF;RETURN result;END IF;
 IF result->>'state'<>'completed' OR (result->>'duplicate')::boolean THEN RETURN result;END IF;
 IF NOT(p_result ? 'endpoint') THEN RAISE EXCEPTION 'Endpoint envelope required' USING ERRCODE='22023';END IF;
 meta:=p_result->'endpoint';metrics:=p_result->'sample'->'metrics';PERFORM public.sowrix_ops_v8_metadata(meta);
 IF p_result->'sample'->>'status' NOT IN ('up','unknown','unsupported') OR (p_result->'sample'->>'status'='up' AND metrics->>'agent_available' IS DISTINCT FROM '1') OR (p_result->'sample'->>'status'<>'up' AND (metrics<>'{}'::jsonb OR meta<>'{}'::jsonb)) THEN RAISE EXCEPTION 'Unconfirmed endpoint availability' USING ERRCODE='22023';END IF;
 IF (meta<>'{}'::jsonb AND NOT(p.configuration->'capabilities' ? 'inventory')) OR (meta ? 'os_family' AND meta->>'os_family' IS DISTINCT FROM p.configuration->>'platform') THEN RAISE EXCEPTION 'Unauthorized inventory capability' USING ERRCODE='42501';END IF;
 FOR m IN SELECT key,value FROM jsonb_each(metrics) LOOP
  cap:=CASE m.key WHEN 'agent_available' THEN NULL WHEN 'cpu_percent' THEN 'cpu' WHEN 'memory_percent' THEN 'memory' WHEN 'disk_percent' THEN 'storage' WHEN 'uptime_seconds' THEN 'uptime' WHEN 'cpu_cores' THEN 'inventory' WHEN 'memory_total_bytes' THEN 'inventory' WHEN 'storage_total_bytes' THEN 'inventory' ELSE 'services' END;
  IF m.key NOT IN ('agent_available','cpu_percent','memory_percent','disk_percent','uptime_seconds','cpu_cores','memory_total_bytes','storage_total_bytes') AND (m.key !~ '^service_[1-4]_available$' OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p.configuration->'services') s WHERE s->>'index'=split_part(m.key,'_',2))) THEN RAISE EXCEPTION 'Unauthorized endpoint measurement' USING ERRCODE='42501';END IF;
  IF cap IS NOT NULL AND NOT(p.configuration->'capabilities' ? cap) THEN RAISE EXCEPTION 'Unsupported endpoint measurement' USING ERRCODE='42501';END IF;
  IF (public.sowrix_ops_v5_unit(m.key)='code' AND m.value NOT IN ('0'::jsonb,'1'::jsonb)) OR (m.key='cpu_cores' AND ((m.value::text)::numeric NOT BETWEEN 1 AND 4096 OR (m.value::text)::numeric<>trunc((m.value::text)::numeric))) OR (public.sowrix_ops_v5_unit(m.key)='bytes' AND ((m.value::text)::numeric<=0 OR (m.value::text)::numeric<>trunc((m.value::text)::numeric))) THEN RAISE EXCEPTION 'Invalid endpoint units' USING ERRCODE='22023';END IF;
 END LOOP;
 ev:=(result->>'evidence_id')::uuid;SELECT document INTO doc FROM public.sowrix_ops_v4_evidence WHERE id=ev;
 doc:=(doc-'authorized_source_identity'-'collector_id')||jsonb_build_object('source_key','endpoint:'||p_run::text,'attributes',meta||jsonb_build_object('scheduler_run',p_run),'measurements','{}'::jsonb,'methodology','Credential-bound consent-enforcing native adapter; source authentication is not independent hardware attestation');
 companion:=((public.sowrix_ops_v4_write(doc,NULL,r.collector_id))->'record'->>'id')::uuid;
 INSERT INTO public.sowrix_ops_v8_observations VALUES(ev,companion,p_run,c.organization_id,c.asset_id,(p_result->'sample'->>'observed_at')::timestamptz,p_result->'sample'->>'status',metrics,meta);RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v8_snapshot(p_org uuid,p_asset uuid DEFAULT NULL,p_before timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scheduler jsonb;nodes jsonb;history jsonb;alerts jsonb;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'read');IF (p_before IS NULL)<>(p_before_id IS NULL) OR (p_before IS NOT NULL AND NOT isfinite(p_before)) THEN RAISE EXCEPTION 'Invalid endpoint cursor' USING ERRCODE='22023';END IF;
 IF p_asset IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v8_profiles WHERE organization_id=p_org AND asset_id=p_asset) THEN RAISE EXCEPTION 'Endpoint asset not permitted' USING ERRCODE='42501';END IF;
 scheduler:=public.sowrix_ops_v5_snapshot(p_org,NULL);
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.name),'[]') INTO nodes FROM (
  SELECT p.organization_id,p.asset_id,d.name,d.site_id,s.name site_name,d.collector_id,col.last_seen agent_last_heartbeat,p.configuration,
   CASE WHEN NOT p.enabled OR NOT d.enabled THEN 'DISABLED' ELSE coalesce((SELECT x->>'effective_health' FROM jsonb_array_elements(scheduler->'checks') x WHERE x->>'asset_id'=d.id::text),'UNKNOWN') END health,
   coalesce((SELECT x->>'collector_health' FROM jsonb_array_elements(scheduler->'checks') x WHERE x->>'asset_id'=d.id::text),'UNKNOWN') agent_connectivity,
   coalesce((SELECT (x->>'interval_seconds')::int FROM jsonb_array_elements(scheduler->'checks') x WHERE x->>'asset_id'=d.id::text),60) interval_seconds,
   (SELECT x->>'last_observed' FROM jsonb_array_elements(scheduler->'checks') x WHERE x->>'asset_id'=d.id::text) last_observed,
   (SELECT max(observed_at) FROM public.sowrix_ops_v8_observations WHERE organization_id=p_org AND asset_id=p.asset_id AND status='up') last_successful_observation
  FROM public.sowrix_ops_v8_profiles p JOIN public.sowrix_def_devices d ON d.id=p.asset_id JOIN public.sowrix_def_sites s ON s.id=d.site_id JOIN public.sowrix_def_collectors col ON col.id=d.collector_id WHERE p.organization_id=p_org) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.observed_at DESC,q.evidence_id DESC),'[]') INTO history FROM (SELECT * FROM public.sowrix_ops_v8_observations WHERE organization_id=p_org AND (p_asset IS NULL OR asset_id=p_asset) AND (p_before IS NULL OR (observed_at,evidence_id)<(p_before,p_before_id)) ORDER BY observed_at DESC,evidence_id DESC LIMIT 100) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.id DESC),'[]') INTO alerts FROM (SELECT t.*,c.asset_id FROM public.sowrix_ops_v5_timeline t JOIN public.sowrix_ops_v5_checks c ON c.id=t.check_id JOIN public.sowrix_ops_v8_profiles p ON p.asset_id=c.asset_id AND p.organization_id=t.organization_id WHERE t.organization_id=p_org AND (p_asset IS NULL OR c.asset_id=p_asset) ORDER BY t.id DESC LIMIT 100) q;
 RETURN jsonb_build_object('organization_id',p_org,'server_time',clock_timestamp(),'nodes',nodes,'history',history,'alerts',alerts,'local_consent_required',true);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v8_validate(jsonb),public.sowrix_ops_v8_metadata(jsonb),public.sowrix_ops_v8_prior_unit(text),public.sowrix_ops_v8_prior_claim(text,uuid,integer),public.sowrix_ops_v8_prior_finish(text,uuid,uuid,jsonb),public.sowrix_ops_v5_unit(text),public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb),public.sowrix_ops_v8_configure(uuid,uuid,jsonb),public.sowrix_ops_v8_snapshot(uuid,uuid,timestamptz,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v8_configure(uuid,uuid,jsonb),public.sowrix_ops_v8_snapshot(uuid,uuid,timestamptz,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';COMMIT;
