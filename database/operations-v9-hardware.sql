-- V9 additive hardware index on existing V5 leases and V4 evidence.
BEGIN;
DO $$ BEGIN IF to_regprocedure('public.sowrix_ops_v8_configure(uuid,uuid,jsonb)') IS NULL THEN RAISE EXCEPTION 'Install V8 first';END IF;END $$;
-- Widen only the existing kind predicate; preserve customer-added categories and all rows.
DO $$ DECLARE predicate text;BEGIN
 SELECT pg_get_expr(conbin,conrelid) INTO predicate FROM pg_constraint WHERE conrelid='public.sowrix_def_devices'::regclass AND conname='sowrix_def_devices_kind_check';
 IF predicate IS NOT NULL AND (position(quote_literal('printer') in predicate)=0 OR position(quote_literal('multifunction') in predicate)=0 OR position(quote_literal('ups') in predicate)=0 OR position(quote_literal('nas') in predicate)=0 OR position(quote_literal('environment') in predicate)=0) THEN
  ALTER TABLE public.sowrix_def_devices DROP CONSTRAINT sowrix_def_devices_kind_check;
  EXECUTE format('ALTER TABLE public.sowrix_def_devices ADD CONSTRAINT sowrix_def_devices_kind_check CHECK ((%s) OR kind IN (''printer'',''multifunction'',''ups'',''nas'',''environment''))',predicate);
 END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v9_profiles(
 organization_id uuid NOT NULL,asset_id uuid PRIMARY KEY,configuration jsonb NOT NULL,enabled boolean NOT NULL,actor_id uuid NOT NULL REFERENCES auth.users(id),updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(organization_id,asset_id) REFERENCES public.sowrix_def_devices(organization_id,id),UNIQUE(organization_id,asset_id));
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v9_observations(
 evidence_id uuid PRIMARY KEY,metadata_id uuid NOT NULL,run_id uuid NOT NULL UNIQUE,organization_id uuid NOT NULL,asset_id uuid NOT NULL,observed_at timestamptz NOT NULL,status text NOT NULL,category text NOT NULL,metrics jsonb NOT NULL,inventory jsonb NOT NULL,
 FOREIGN KEY(organization_id,asset_id,evidence_id) REFERENCES public.sowrix_ops_v4_evidence(organization_id,asset_id,id),
 FOREIGN KEY(organization_id,asset_id,metadata_id) REFERENCES public.sowrix_ops_v4_evidence(organization_id,asset_id,id));
CREATE INDEX IF NOT EXISTS sowrix_ops_v9_history ON public.sowrix_ops_v9_observations(organization_id,asset_id,observed_at DESC,evidence_id DESC);
DO $$ DECLARE t text;BEGIN FOREACH t IN ARRAY ARRAY['profiles','observations'] LOOP
 EXECUTE format('ALTER TABLE public.sowrix_ops_v9_%I ENABLE ROW LEVEL SECURITY',t);EXECUTE format('REVOKE ALL ON public.sowrix_ops_v9_%I FROM PUBLIC,anon,authenticated,service_role',t);END LOOP;END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v9_spec(category text) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$ SELECT ('{"printer":{"printer_operational":["code",1],"toner_percent":["percent",100],"ink_percent":["percent",100],"paper_available":["code",1],"paper_jam":["code",1],"page_count":["count",1000000000000000.0],"maintenance_warning":["code",1]},"camera":{"equipment_operational":["code",1],"temperature_kelvin":["kelvin",1273.15],"maintenance_warning":["code",1]},"recorder":{"recorder_operational":["code",1],"storage_total_bytes":["bytes",1000000000000000.0],"storage_available_bytes":["bytes",1000000000000000.0],"storage_percent":["percent",100],"channels_total":["count",4096],"channels_healthy":["count",4096],"maintenance_warning":["code",1]},"ups":{"input_power_available":["code",1],"output_power_available":["code",1],"battery_percent":["percent",100],"battery_runtime_seconds":["seconds",1000000000000.0],"load_percent":["percent",100],"battery_warning":["code",1],"maintenance_warning":["code",1]},"nas":{"storage_total_bytes":["bytes",1000000000000000.0],"storage_available_bytes":["bytes",1000000000000000.0],"storage_percent":["percent",100],"disk_healthy":["code",1],"raid_healthy":["code",1],"temperature_kelvin":["kelvin",1273.15],"maintenance_warning":["code",1]},"environment":{"temperature_kelvin":["kelvin",1273.15],"humidity_percent":["percent",100],"cooling_operational":["code",1],"maintenance_warning":["code",1]}}'::jsonb)->category $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v9_validate(p jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR octet_length(p::text)>4096 OR NOT(p ?& ARRAY['enabled','category','adapter','capabilities']) OR (SELECT count(*) FROM jsonb_object_keys(p))<>4
 OR jsonb_typeof(p->'enabled') IS DISTINCT FROM 'boolean' OR public.sowrix_ops_v9_spec(p->>'category') IS NULL OR p->>'adapter' IS NULL OR p->>'adapter' NOT IN ('snmpv3','https_bridge')
 OR jsonb_typeof(p->'capabilities') IS DISTINCT FROM 'array' OR jsonb_array_length(p->'capabilities')>16
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p->'capabilities') c WHERE jsonb_typeof(c)<>'string' OR NOT(public.sowrix_ops_v9_spec(p->>'category') ? (c #>> '{}')))
 OR (SELECT count(DISTINCT value) FROM jsonb_array_elements(p->'capabilities'))<>jsonb_array_length(p->'capabilities')
 OR (p->'capabilities' ? 'storage_percent' AND NOT(p->'capabilities' ?& ARRAY['storage_total_bytes','storage_available_bytes'])) THEN RAISE EXCEPTION 'Invalid hardware capability profile' USING ERRCODE='22023';END IF;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v9_metadata(p jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE m record;
BEGIN
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR octet_length(p::text)>512 OR (SELECT count(*) FROM jsonb_object_keys(p))>2 THEN RAISE EXCEPTION 'Invalid equipment metadata' USING ERRCODE='22023';END IF;
 FOR m IN SELECT key,value FROM jsonb_each(p) LOOP
  IF m.key NOT IN ('manufacturer','model') OR jsonb_typeof(m.value)<>'string' OR m.value #>> '{}' !~ '^[A-Za-z0-9 ._()+/-]{1,100}$' THEN RAISE EXCEPTION 'Private or invalid equipment metadata' USING ERRCODE='22023';END IF;
 END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v9_configure(p_org uuid,p_asset uuid,p_data jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'configure');PERFORM 1 FROM public.sowrix_def_orgs WHERE organization_id=p_org FOR UPDATE;PERFORM public.sowrix_ops_v9_validate(p_data);
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE organization_id=p_org AND id=p_asset AND enabled AND protocol=CASE p_data->>'adapter' WHEN 'snmpv3' THEN 'snmp_exporter' ELSE 'https' END) OR EXISTS(SELECT 1 FROM public.sowrix_ops_v6_profiles WHERE asset_id=p_asset) OR EXISTS(SELECT 1 FROM public.sowrix_ops_v8_profiles WHERE asset_id=p_asset) THEN RAISE EXCEPTION 'Registered compatible equipment asset required' USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v9_profiles WHERE asset_id=p_asset) AND (SELECT count(*) FROM public.sowrix_ops_v9_profiles WHERE organization_id=p_org)>=100 THEN RAISE EXCEPTION 'Hardware inventory limit' USING ERRCODE='54000';END IF;
 INSERT INTO public.sowrix_ops_v9_profiles VALUES(p_org,p_asset,p_data,(p_data->>'enabled')::boolean,auth.uid(),now()) ON CONFLICT(asset_id) DO UPDATE SET configuration=excluded.configuration,enabled=excluded.enabled,actor_id=auth.uid(),updated_at=now();
 UPDATE public.sowrix_ops_v5_runs SET state='cancelled',finished_at=clock_timestamp() WHERE check_id IN(SELECT id FROM public.sowrix_ops_v5_checks WHERE organization_id=p_org AND asset_id=p_asset) AND state='leased';
 UPDATE public.sowrix_ops_v5_checks SET revision=revision+1,lease_id=NULL,lease_until=NULL,owner=NULL,next_due=now(),health='UNKNOWN',failures=0,recoveries=0,enabled=enabled AND (p_data->>'enabled')::boolean WHERE organization_id=p_org AND asset_id=p_asset;
 PERFORM public.sowrix_def_audit_write(p_org,'ops_v9_profile',p_asset::text,p_data);RETURN jsonb_build_object('organization_id',p_org,'asset_id',p_asset,'configuration',p_data,'read_only',true);
END $$;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v9_prior_unit(text)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_unit(text) RENAME TO sowrix_ops_v9_prior_unit;END IF;
 IF to_regprocedure('public.sowrix_ops_v9_prior_claim(text,uuid,integer)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer) RENAME TO sowrix_ops_v9_prior_claim;END IF;
 IF to_regprocedure('public.sowrix_ops_v9_prior_finish(text,uuid,uuid,jsonb)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) RENAME TO sowrix_ops_v9_prior_finish;END IF;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_unit(p_metric text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$ SELECT CASE WHEN p_metric='battery_percent' THEN 'percent' WHEN p_metric='battery_runtime_seconds' THEN 'seconds' WHEN p_metric='battery_warning' THEN 'code' WHEN p_metric='channels_healthy' THEN 'count' WHEN p_metric='channels_total' THEN 'count' WHEN p_metric='cooling_operational' THEN 'code' WHEN p_metric='disk_healthy' THEN 'code' WHEN p_metric='equipment_operational' THEN 'code' WHEN p_metric='humidity_percent' THEN 'percent' WHEN p_metric='ink_percent' THEN 'percent' WHEN p_metric='input_power_available' THEN 'code' WHEN p_metric='load_percent' THEN 'percent' WHEN p_metric='maintenance_warning' THEN 'code' WHEN p_metric='output_power_available' THEN 'code' WHEN p_metric='page_count' THEN 'count' WHEN p_metric='paper_available' THEN 'code' WHEN p_metric='paper_jam' THEN 'code' WHEN p_metric='printer_operational' THEN 'code' WHEN p_metric='raid_healthy' THEN 'code' WHEN p_metric='recorder_operational' THEN 'code' WHEN p_metric='storage_available_bytes' THEN 'bytes' WHEN p_metric='storage_percent' THEN 'percent' WHEN p_metric='storage_total_bytes' THEN 'bytes' WHEN p_metric='temperature_kelvin' THEN 'kelvin' WHEN p_metric='toner_percent' THEN 'percent' ELSE public.sowrix_ops_v9_prior_unit(p_metric) END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_claim(p_token text,p_owner uuid,p_limit integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;job jsonb;p public.sowrix_ops_v9_profiles;jobs jsonb:='[]';
BEGIN
 result:=public.sowrix_ops_v9_prior_claim(p_token,p_owner,p_limit);
 FOR job IN SELECT jsonb_array_elements(result->'jobs') LOOP
  SELECT * INTO p FROM public.sowrix_ops_v9_profiles WHERE asset_id=(job->'device'->>'id')::uuid;
  IF p.asset_id IS NOT NULL THEN
   IF NOT p.enabled OR job->'device'->>'protocol' IS DISTINCT FROM (CASE p.configuration->>'adapter' WHEN 'snmpv3' THEN 'snmp_exporter' ELSE 'https' END) OR job->'device' ? 'network' OR job->'device' ? 'endpoint' THEN PERFORM public.sowrix_ops_v9_prior_finish(p_token,p_owner,(job->>'id')::uuid,'{"outcome":"cancelled","sample":null}');CONTINUE;END IF;
   job:=jsonb_set(job,'{device,hardware}',p.configuration);
  END IF;jobs:=jobs||jsonb_build_array(job);
 END LOOP;RETURN jsonb_build_object('jobs',jobs);
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_finish(p_token text,p_owner uuid,p_run uuid,p_result jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;p public.sowrix_ops_v9_profiles;r public.sowrix_ops_v5_runs;c public.sowrix_ops_v5_checks;old public.sowrix_ops_v9_observations;meta jsonb;metrics jsonb;doc jsonb;ev uuid;companion uuid;m record;cap text;
BEGIN
 IF octet_length(p_result::text)>16000 THEN RAISE EXCEPTION 'Completion exceeds bound' USING ERRCODE='22023';END IF;
 result:=public.sowrix_ops_v9_prior_finish(p_token,p_owner,p_run,p_result-'hardware');
 SELECT * INTO r FROM public.sowrix_ops_v5_runs WHERE id=p_run;SELECT * INTO c FROM public.sowrix_ops_v5_checks WHERE id=r.check_id;SELECT * INTO old FROM public.sowrix_ops_v9_observations WHERE run_id=p_run;
 IF old.run_id IS NOT NULL THEN IF old.inventory IS DISTINCT FROM p_result->'hardware' THEN RAISE EXCEPTION 'Conflicting hardware completion' USING ERRCODE='22023';END IF;RETURN result;END IF;
 SELECT * INTO p FROM public.sowrix_ops_v9_profiles WHERE organization_id=c.organization_id AND asset_id=c.asset_id AND enabled;
 IF p.asset_id IS NULL THEN IF p_result ? 'hardware' THEN RAISE EXCEPTION 'Hardware source not registered' USING ERRCODE='42501';END IF;RETURN result;END IF;
 IF result->>'state'<>'completed' OR (result->>'duplicate')::boolean THEN RETURN result;END IF;
 IF NOT(p_result ? 'hardware') THEN RAISE EXCEPTION 'Hardware envelope required' USING ERRCODE='22023';END IF;
 meta:=p_result->'hardware';metrics:=p_result->'sample'->'metrics';PERFORM public.sowrix_ops_v9_metadata(meta);
 IF p_result->'sample'->>'status' IN ('up','down') AND metrics->>'network_available' IS DISTINCT FROM (CASE WHEN p_result->'sample'->>'status'='up' THEN '1' ELSE '0' END) THEN RAISE EXCEPTION 'Explicit equipment observation required' USING ERRCODE='22023';END IF;
 IF p_result->'sample'->>'status' IN ('unknown','unsupported') AND (metrics<>'{}'::jsonb OR meta<>'{}'::jsonb) THEN RAISE EXCEPTION 'Unavailable equipment cannot claim observations' USING ERRCODE='22023';END IF;
 IF p_result->'sample'->>'status'='down' AND (meta<>'{}'::jsonb OR metrics<>'{"network_available":0}'::jsonb) THEN RAISE EXCEPTION 'Failed equipment cannot claim healthy measurements' USING ERRCODE='22023';END IF;
 FOR m IN SELECT key,value FROM jsonb_each(metrics) LOOP
  IF m.key NOT IN ('network_available','uptime_seconds') AND (NOT(p.configuration->'capabilities' ? m.key) OR NOT(public.sowrix_ops_v9_spec(p.configuration->>'category') ? m.key)) THEN RAISE EXCEPTION 'Unsupported or private hardware measurement' USING ERRCODE='42501';END IF;
  IF m.key NOT IN ('network_available','uptime_seconds') AND (m.value::text)::numeric>(public.sowrix_ops_v9_spec(p.configuration->>'category')->m.key->>1)::numeric THEN RAISE EXCEPTION 'Hardware measurement exceeds bound' USING ERRCODE='22023';END IF;
  IF (public.sowrix_ops_v5_unit(m.key)='code' AND m.value NOT IN ('0'::jsonb,'1'::jsonb)) OR (public.sowrix_ops_v5_unit(m.key) IN ('count','bytes') AND (m.value::text)::numeric<>trunc((m.value::text)::numeric)) OR (m.key='storage_total_bytes' AND (m.value::text)::numeric<=0) OR (m.key='uptime_seconds' AND (m.value::text)::numeric>1e12) THEN RAISE EXCEPTION 'Invalid hardware units' USING ERRCODE='22023';END IF;
 END LOOP;
 IF metrics ?& ARRAY['storage_total_bytes','storage_available_bytes'] AND (metrics->>'storage_available_bytes')::numeric>(metrics->>'storage_total_bytes')::numeric THEN RAISE EXCEPTION 'Invalid available capacity' USING ERRCODE='22023';END IF;
 IF metrics ? 'storage_percent' AND (NOT(metrics ?& ARRAY['storage_total_bytes','storage_available_bytes']) OR abs((metrics->>'storage_percent')::numeric-((metrics->>'storage_total_bytes')::numeric-(metrics->>'storage_available_bytes')::numeric)/(metrics->>'storage_total_bytes')::numeric*100)>0.0000001) THEN RAISE EXCEPTION 'Unconfirmed storage percentage' USING ERRCODE='22023';END IF;
 IF metrics ?& ARRAY['channels_total','channels_healthy'] AND (metrics->>'channels_healthy')::numeric>(metrics->>'channels_total')::numeric THEN RAISE EXCEPTION 'Invalid channel aggregate' USING ERRCODE='22023';END IF;
 ev:=(result->>'evidence_id')::uuid;SELECT document INTO doc FROM public.sowrix_ops_v4_evidence WHERE id=ev;
 doc:=(doc-'authorized_source_identity'-'collector_id')||jsonb_build_object('source_key','hardware:'||p_run::text,'attributes',meta||jsonb_build_object('scheduler_run',p_run,'equipment_category',p.configuration->>'category'),'measurements','{}'::jsonb,'methodology','Credential-bound read-only equipment health provider; no independent hardware attestation or media collection');
 companion:=((public.sowrix_ops_v4_write(doc,NULL,r.collector_id))->'record'->>'id')::uuid;
 INSERT INTO public.sowrix_ops_v9_observations VALUES(ev,companion,p_run,c.organization_id,c.asset_id,(p_result->'sample'->>'observed_at')::timestamptz,p_result->'sample'->>'status',p.configuration->>'category',metrics,meta);RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v9_snapshot(p_org uuid,p_asset uuid DEFAULT NULL,p_before timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE scheduler jsonb;nodes jsonb;history jsonb;alerts jsonb;incidents jsonb;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'read');IF (p_before IS NULL)<>(p_before_id IS NULL) OR (p_before IS NOT NULL AND NOT isfinite(p_before)) THEN RAISE EXCEPTION 'Invalid hardware cursor' USING ERRCODE='22023';END IF;
 IF p_asset IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v9_profiles WHERE organization_id=p_org AND asset_id=p_asset) THEN RAISE EXCEPTION 'Hardware asset not permitted' USING ERRCODE='42501';END IF;
 scheduler:=public.sowrix_ops_v5_snapshot(p_org,NULL);
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.name),'[]') INTO nodes FROM (
  SELECT p.organization_id,p.asset_id,d.name,d.site_id,s.name site_name,d.collector_id,col.last_seen collector_last_heartbeat,p.configuration,
   CASE WHEN NOT p.enabled OR NOT d.enabled THEN 'DISABLED' ELSE coalesce((SELECT x->>'effective_health' FROM jsonb_array_elements(scheduler->'checks') x WHERE x->>'asset_id'=d.id::text),'UNKNOWN') END health,
   coalesce((SELECT x->>'collector_health' FROM jsonb_array_elements(scheduler->'checks') x WHERE x->>'asset_id'=d.id::text),'UNKNOWN') collector_connectivity,
   coalesce((SELECT (x->>'interval_seconds')::int FROM jsonb_array_elements(scheduler->'checks') x WHERE x->>'asset_id'=d.id::text),60) interval_seconds,
   (SELECT x->>'last_observed' FROM jsonb_array_elements(scheduler->'checks') x WHERE x->>'asset_id'=d.id::text) last_observed,
   (SELECT max(observed_at) FROM public.sowrix_ops_v9_observations WHERE organization_id=p_org AND asset_id=p.asset_id AND status='up') last_successful_observation
  FROM public.sowrix_ops_v9_profiles p JOIN public.sowrix_def_devices d ON d.id=p.asset_id JOIN public.sowrix_def_sites s ON s.id=d.site_id JOIN public.sowrix_def_collectors col ON col.id=d.collector_id WHERE p.organization_id=p_org) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.observed_at DESC,q.evidence_id DESC),'[]') INTO history FROM (SELECT * FROM public.sowrix_ops_v9_observations WHERE organization_id=p_org AND (p_asset IS NULL OR asset_id=p_asset) AND (p_before IS NULL OR (observed_at,evidence_id)<(p_before,p_before_id)) ORDER BY observed_at DESC,evidence_id DESC LIMIT 100) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.id DESC),'[]') INTO alerts FROM (SELECT t.*,c.asset_id FROM public.sowrix_ops_v5_timeline t JOIN public.sowrix_ops_v5_checks c ON c.id=t.check_id JOIN public.sowrix_ops_v9_profiles p ON p.asset_id=c.asset_id AND p.organization_id=t.organization_id WHERE t.organization_id=p_org AND (p_asset IS NULL OR c.asset_id=p_asset) ORDER BY t.id DESC LIMIT 100) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.opened_at DESC),'[]') INTO incidents FROM (SELECT i.id,i.organization_id,i.device_id asset_id,i.title,i.severity,i.status,i.opened_at FROM public.sowrix_def_incidents i JOIN public.sowrix_ops_v5_checks c ON c.asset_id=i.device_id AND i.rule_key='scheduler:'||c.id::text JOIN public.sowrix_ops_v9_profiles p ON p.asset_id=c.asset_id AND p.organization_id=i.organization_id WHERE i.organization_id=p_org AND i.status<>'resolved' AND (p_asset IS NULL OR i.device_id=p_asset) ORDER BY i.opened_at DESC LIMIT 100) q;
 RETURN jsonb_build_object('organization_id',p_org,'server_time',clock_timestamp(),'nodes',nodes,'history',history,'alerts',alerts,'incidents',incidents,'read_only',true);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v9_spec(text),public.sowrix_ops_v9_validate(jsonb),public.sowrix_ops_v9_metadata(jsonb),public.sowrix_ops_v9_prior_unit(text),public.sowrix_ops_v9_prior_claim(text,uuid,integer),public.sowrix_ops_v9_prior_finish(text,uuid,uuid,jsonb),public.sowrix_ops_v5_unit(text),public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb),public.sowrix_ops_v9_configure(uuid,uuid,jsonb),public.sowrix_ops_v9_snapshot(uuid,uuid,timestamptz,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v9_configure(uuid,uuid,jsonb),public.sowrix_ops_v9_snapshot(uuid,uuid,timestamptz,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';COMMIT;
