-- V6 network metadata/history/topology: same assets, V5 leases and V4 source ledger.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb)') IS NULL THEN RAISE EXCEPTION 'Install V5 first'; END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v6_profiles (
 organization_id uuid NOT NULL,asset_id uuid PRIMARY KEY,configuration jsonb NOT NULL,
 enabled boolean NOT NULL,actor_id uuid NOT NULL REFERENCES auth.users(id),updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(organization_id,asset_id) REFERENCES public.sowrix_def_devices(organization_id,id),UNIQUE(organization_id,asset_id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v6_interfaces (
 organization_id uuid NOT NULL,asset_id uuid NOT NULL,interface_index integer NOT NULL,name text NOT NULL,
 capacity_bps numeric,counter_bits integer NOT NULL,enabled boolean NOT NULL DEFAULT true,
 PRIMARY KEY(organization_id,asset_id,interface_index),FOREIGN KEY(organization_id,asset_id) REFERENCES public.sowrix_ops_v6_profiles(organization_id,asset_id),
 CHECK(interface_index BETWEEN 1 AND 4096 AND counter_bits IN (32,64)),CHECK(capacity_bps IS NULL OR capacity_bps BETWEEN 1 AND 1e12)
);
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v6_observations (
 evidence_id uuid PRIMARY KEY,organization_id uuid NOT NULL,asset_id uuid NOT NULL,observed_at timestamptz NOT NULL,
 status text NOT NULL CHECK(status IN ('up','down','unknown','unsupported')),metrics jsonb NOT NULL,
 FOREIGN KEY(organization_id,asset_id,evidence_id) REFERENCES public.sowrix_ops_v4_evidence(organization_id,asset_id,id)
);
CREATE INDEX IF NOT EXISTS sowrix_ops_v6_history ON public.sowrix_ops_v6_observations(organization_id,asset_id,observed_at DESC,evidence_id DESC);
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v6_interface_history (
 evidence_id uuid NOT NULL,organization_id uuid NOT NULL,asset_id uuid NOT NULL,interface_index integer NOT NULL,
 observed_at timestamptz NOT NULL,in_octets numeric(20,0),out_octets numeric(20,0),in_bps numeric,out_bps numeric,
 in_utilization_percent numeric,out_utilization_percent numeric,capacity_bps numeric,oper_status integer,
 PRIMARY KEY(evidence_id,interface_index),FOREIGN KEY(evidence_id) REFERENCES public.sowrix_ops_v6_observations(evidence_id),
 FOREIGN KEY(organization_id,asset_id,interface_index) REFERENCES public.sowrix_ops_v6_interfaces(organization_id,asset_id,interface_index)
);
CREATE INDEX IF NOT EXISTS sowrix_ops_v6_interface_time ON public.sowrix_ops_v6_interface_history(organization_id,asset_id,interface_index,observed_at DESC);
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v6_links (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL,source_asset uuid NOT NULL,target_asset uuid NOT NULL,
 interface_index integer,relation text NOT NULL CHECK(relation IN ('uplink','wan','controller')),enabled boolean NOT NULL DEFAULT true,actor_id uuid NOT NULL,
 FOREIGN KEY(organization_id,source_asset) REFERENCES public.sowrix_ops_v6_profiles(organization_id,asset_id),
 FOREIGN KEY(organization_id,target_asset) REFERENCES public.sowrix_ops_v6_profiles(organization_id,asset_id),
 FOREIGN KEY(organization_id,source_asset,interface_index) REFERENCES public.sowrix_ops_v6_interfaces(organization_id,asset_id,interface_index),
 CHECK(source_asset<>target_asset),UNIQUE(organization_id,source_asset,target_asset,relation)
);
CREATE INDEX IF NOT EXISTS sowrix_ops_v6_topology ON public.sowrix_ops_v6_links(organization_id) WHERE enabled;
DO $$ DECLARE t text;BEGIN
 FOREACH t IN ARRAY ARRAY['profiles','interfaces','observations','interface_history','links'] LOOP
  EXECUTE format('ALTER TABLE public.sowrix_ops_v6_%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.sowrix_ops_v6_%I FROM PUBLIC,anon,authenticated,service_role',t);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v6_configure(p_org uuid,p_asset uuid,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i jsonb;expected text;d public.sowrix_def_devices;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'configure');PERFORM 1 FROM public.sowrix_def_orgs WHERE organization_id=p_org FOR UPDATE;
 IF jsonb_typeof(p_data) IS DISTINCT FROM 'object' OR octet_length(p_data::text)>8192 OR NOT(p_data ?& ARRAY['role','vendor','model','adapter','capabilities','interfaces','enabled']) OR (SELECT count(*) FROM jsonb_object_keys(p_data))<>7
 OR jsonb_typeof(p_data->'enabled') IS DISTINCT FROM 'boolean' OR p_data->>'role' IS NULL OR p_data->>'role' NOT IN ('router','switch','access_point','gateway','ont','onu','internet','controller','virtual_appliance')
 OR jsonb_typeof(p_data->'vendor') IS DISTINCT FROM 'string' OR length(p_data->>'vendor') NOT BETWEEN 1 AND 100 OR p_data->>'vendor' ~ '[[:cntrl:]]'
 OR jsonb_typeof(p_data->'model') IS DISTINCT FROM 'string' OR length(p_data->>'model') NOT BETWEEN 1 AND 100 OR p_data->>'model' ~ '[[:cntrl:]]' THEN RAISE EXCEPTION 'Invalid network profile' USING ERRCODE='22023'; END IF;
 expected:=CASE p_data->>'adapter' WHEN 'prometheus' THEN 'prometheus' WHEN 'snmpv3_exporter' THEN 'snmp_exporter' WHEN 'vendor_api' THEN 'https' WHEN 'tcp_availability' THEN 'tcp' WHEN 'icmp_availability' THEN 'icmp' END;
 SELECT * INTO d FROM public.sowrix_def_devices WHERE organization_id=p_org AND id=p_asset;
 IF d.id IS NULL OR NOT d.enabled OR expected IS NULL OR d.protocol<>expected THEN RAISE EXCEPTION 'Authorized compatible asset required' USING ERRCODE='42501'; END IF;
 IF jsonb_typeof(p_data->'capabilities') IS DISTINCT FROM 'array' OR jsonb_array_length(p_data->'capabilities') NOT BETWEEN 1 AND 9
 OR NOT(p_data->'capabilities' ? 'availability') OR (SELECT count(DISTINCT value) FROM jsonb_array_elements(p_data->'capabilities'))<>jsonb_array_length(p_data->'capabilities')
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_data->'capabilities') x WHERE jsonb_typeof(x)<>'string' OR x #>> '{}' NOT IN ('availability','latency','packet_loss','interfaces','uptime','cpu','memory','temperature','internet')) THEN RAISE EXCEPTION 'Invalid capabilities' USING ERRCODE='22023'; END IF;
 IF p_data->>'adapter' IN ('tcp_availability','icmp_availability') AND EXISTS(SELECT 1 FROM jsonb_array_elements_text(p_data->'capabilities') x WHERE x NOT IN ('availability','latency','internet')) THEN RAISE EXCEPTION 'Unsupported adapter capability' USING ERRCODE='22023'; END IF;
 IF jsonb_typeof(p_data->'interfaces') IS DISTINCT FROM 'array' OR jsonb_array_length(p_data->'interfaces')>8 OR (jsonb_array_length(p_data->'interfaces')>0 AND NOT(p_data->'capabilities' ? 'interfaces')) THEN RAISE EXCEPTION 'Invalid selected interfaces' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v6_profiles WHERE asset_id=p_asset) AND (SELECT count(*) FROM public.sowrix_ops_v6_profiles WHERE organization_id=p_org)>=100 THEN RAISE EXCEPTION 'Network inventory limit reached' USING ERRCODE='54000'; END IF;
 INSERT INTO public.sowrix_ops_v6_profiles VALUES(p_org,p_asset,p_data,(p_data->>'enabled')::boolean,auth.uid(),now()) ON CONFLICT(asset_id) DO UPDATE SET configuration=excluded.configuration,enabled=excluded.enabled,actor_id=auth.uid(),updated_at=now();
 UPDATE public.sowrix_ops_v6_interfaces SET enabled=false WHERE organization_id=p_org AND asset_id=p_asset;
 FOR i IN SELECT jsonb_array_elements(p_data->'interfaces') LOOP
  IF jsonb_typeof(i) IS DISTINCT FROM 'object' OR NOT(i ?& ARRAY['index','name','capacity_bps','counter_bits']) OR (SELECT count(*) FROM jsonb_object_keys(i))<>4
  OR jsonb_typeof(i->'index') IS DISTINCT FROM 'number' OR i->>'index' !~ '^[1-9][0-9]{0,3}$' OR (i->>'index')::int>4096
  OR jsonb_typeof(i->'name') IS DISTINCT FROM 'string' OR length(i->>'name') NOT BETWEEN 1 AND 64 OR i->>'name' ~ '[[:cntrl:]]'
  OR i->'counter_bits' NOT IN ('32'::jsonb,'64'::jsonb) OR (i->'capacity_bps'<>'null'::jsonb AND (jsonb_typeof(i->'capacity_bps') IS DISTINCT FROM 'number' OR (i->>'capacity_bps')::numeric NOT BETWEEN 1 AND 1e12)) THEN RAISE EXCEPTION 'Invalid interface configuration' USING ERRCODE='22023'; END IF;
  INSERT INTO public.sowrix_ops_v6_interfaces VALUES(p_org,p_asset,(i->>'index')::int,i->>'name',(i->>'capacity_bps')::numeric,(i->>'counter_bits')::int,true)
   ON CONFLICT(organization_id,asset_id,interface_index) DO UPDATE SET name=excluded.name,capacity_bps=excluded.capacity_bps,counter_bits=excluded.counter_bits,enabled=true;
 END LOOP;
 IF (SELECT count(DISTINCT value->>'index') FROM jsonb_array_elements(p_data->'interfaces'))<>jsonb_array_length(p_data->'interfaces') THEN RAISE EXCEPTION 'Duplicate interface' USING ERRCODE='22023'; END IF;
 UPDATE public.sowrix_ops_v5_runs SET state='cancelled',finished_at=clock_timestamp() WHERE check_id IN (SELECT id FROM public.sowrix_ops_v5_checks WHERE organization_id=p_org AND asset_id=p_asset) AND state='leased';
 UPDATE public.sowrix_ops_v5_checks SET revision=revision+1,lease_id=NULL,lease_until=NULL,owner=NULL,next_due=now(),health='UNKNOWN',failures=0,recoveries=0,enabled=enabled AND (p_data->>'enabled')::boolean WHERE organization_id=p_org AND asset_id=p_asset;
 PERFORM public.sowrix_def_audit_write(p_org,'ops_v6_profile',p_asset::text,p_data);
 RETURN jsonb_build_object('organization_id',p_org,'asset_id',p_asset,'configuration',p_data,'hardware_verified',false);
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v6_link(p_org uuid,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE edge public.sowrix_ops_v6_links;s uuid;t uuid;idx integer;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'configure');PERFORM 1 FROM public.sowrix_def_orgs WHERE organization_id=p_org FOR UPDATE;
 IF jsonb_typeof(p_data) IS DISTINCT FROM 'object' OR NOT(p_data ?& ARRAY['source','target','interface_index','relation','enabled']) OR (SELECT count(*) FROM jsonb_object_keys(p_data))<>5
 OR jsonb_typeof(p_data->'enabled') IS DISTINCT FROM 'boolean' OR p_data->>'relation' IS NULL OR p_data->>'relation' NOT IN ('uplink','wan','controller') THEN RAISE EXCEPTION 'Invalid topology relationship' USING ERRCODE='22023'; END IF;
 s:=(p_data->>'source')::uuid;t:=(p_data->>'target')::uuid;idx:=(p_data->>'interface_index')::int;
 IF s IS NULL OR t IS NULL OR s=t OR (SELECT count(*) FROM public.sowrix_ops_v6_profiles WHERE organization_id=p_org AND enabled AND asset_id IN (s,t))<>2
 OR (idx IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v6_interfaces WHERE organization_id=p_org AND asset_id=s AND interface_index=idx AND enabled)) THEN RAISE EXCEPTION 'Topology asset or interface not permitted' USING ERRCODE='42501'; END IF;
 IF (SELECT count(*) FROM public.sowrix_ops_v6_links WHERE organization_id=p_org)>=256 AND NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v6_links WHERE organization_id=p_org AND source_asset=s AND target_asset=t AND relation=p_data->>'relation') THEN RAISE EXCEPTION 'Topology limit reached' USING ERRCODE='54000'; END IF;
 INSERT INTO public.sowrix_ops_v6_links(organization_id,source_asset,target_asset,interface_index,relation,enabled,actor_id) VALUES(p_org,s,t,idx,p_data->>'relation',(p_data->>'enabled')::boolean,auth.uid())
 ON CONFLICT(organization_id,source_asset,target_asset,relation) DO UPDATE SET interface_index=excluded.interface_index,enabled=excluded.enabled,actor_id=auth.uid() RETURNING * INTO edge;
 PERFORM public.sowrix_def_audit_write(p_org,'ops_v6_topology',edge.id::text,to_jsonb(edge));RETURN to_jsonb(edge);
END $$;

-- Extend existing internal helpers while preserving exact prior functions for rollback.
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v6_prior_unit(text)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_unit(text) RENAME TO sowrix_ops_v6_prior_unit; END IF;
 IF to_regprocedure('public.sowrix_ops_v6_prior_validate(jsonb)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v4_validate(jsonb) RENAME TO sowrix_ops_v6_prior_validate; END IF;
 IF to_regprocedure('public.sowrix_ops_v6_prior_claim(text,uuid,integer)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer) RENAME TO sowrix_ops_v6_prior_claim; END IF;
 IF to_regprocedure('public.sowrix_ops_v6_prior_finish(text,uuid,uuid,jsonb)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) RENAME TO sowrix_ops_v6_prior_finish; END IF;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v6_prior_unit(text),public.sowrix_ops_v6_prior_validate(jsonb),public.sowrix_ops_v6_prior_claim(text,uuid,integer),public.sowrix_ops_v6_prior_finish(text,uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_unit(p_metric text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_metric='network_available' THEN 'code' WHEN p_metric='packet_loss_percent' OR p_metric ~ '^if_[1-9][0-9]{0,3}_(in|out)_utilization_percent$' THEN 'percent'
 WHEN p_metric='uptime_seconds' THEN 'seconds' WHEN p_metric='temperature_kelvin' THEN 'kelvin'
 WHEN p_metric ~ '^if_[1-9][0-9]{0,3}_(in|out)_octets_(hi|lo)$' THEN 'word32'
 WHEN p_metric ~ '^if_[1-9][0-9]{0,3}_((in|out)_bps|speed_bps)$' THEN 'bits_per_second'
 WHEN p_metric ~ '^if_[1-9][0-9]{0,3}_oper_status$' THEN 'code' ELSE public.sowrix_ops_v6_prior_unit(p_metric) END
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v4_validate(p jsonb)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE copy jsonb:=p;m record;unit text;v numeric;
BEGIN
 IF jsonb_typeof(p->'measurements')='object' THEN
  FOR m IN SELECT key,value FROM jsonb_each(p->'measurements') LOOP
   unit:=m.value->>'unit';
   IF unit IN ('seconds','kelvin','bits_per_second','word32') THEN
    IF m.value->>'status'='OBSERVED' THEN
     IF jsonb_typeof(m.value->'value') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Invalid numeric network measurement' USING ERRCODE='22023'; END IF;
     v:=(m.value->>'value')::numeric;
     IF v<0 OR (unit='word32' AND (v>=4294967296 OR v<>trunc(v))) OR (unit='kelvin' AND v>1273.15) THEN RAISE EXCEPTION 'Invalid network measurement bounds' USING ERRCODE='22023'; END IF;
    END IF;
    copy:=jsonb_set(copy,ARRAY['measurements',m.key,'unit'],'"unspecified"'::jsonb);
   END IF;
  END LOOP;
 END IF;
 PERFORM public.sowrix_ops_v6_prior_validate(copy);
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_claim(p_token text,p_owner uuid,p_limit integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;job jsonb;jobs jsonb:='[]';p public.sowrix_ops_v6_profiles;
BEGIN
 result:=public.sowrix_ops_v6_prior_claim(p_token,p_owner,p_limit);
 FOR job IN SELECT jsonb_array_elements(result->'jobs') LOOP
  SELECT * INTO p FROM public.sowrix_ops_v6_profiles WHERE asset_id=(job->'device'->>'id')::uuid;
  IF p.asset_id IS NOT NULL THEN
   IF NOT p.enabled THEN
    PERFORM public.sowrix_ops_v6_prior_finish(p_token,p_owner,(job->>'id')::uuid,'{"outcome":"cancelled","sample":null}');CONTINUE;
   END IF;
   job:=jsonb_set(job,'{device,network}',p.configuration);
  END IF;
  jobs:=jobs||jsonb_build_array(job);
 END LOOP;
 RETURN jsonb_build_object('jobs',jobs);
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_finish(p_token text,p_owner uuid,p_run uuid,p_result jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;p public.sowrix_ops_v6_profiles;r public.sowrix_ops_v5_runs;c public.sowrix_ops_v5_checks;m record;idx integer;i record;metrics jsonb;prefix text;ev uuid;at timestamptz;
BEGIN
 -- Prior completion owns authorization and fencing. Any later validation error rolls it all back.
 result:=public.sowrix_ops_v6_prior_finish(p_token,p_owner,p_run,p_result);
 IF (result->>'duplicate')::boolean OR result->>'state'<>'completed' THEN RETURN result; END IF;
 SELECT * INTO r FROM public.sowrix_ops_v5_runs WHERE id=p_run;SELECT * INTO c FROM public.sowrix_ops_v5_checks WHERE id=r.check_id;
 SELECT * INTO p FROM public.sowrix_ops_v6_profiles WHERE organization_id=c.organization_id AND asset_id=c.asset_id AND enabled;
 IF p.asset_id IS NULL THEN RETURN result; END IF;
 metrics:=p_result->'sample'->'metrics';ev:=(result->>'evidence_id')::uuid;at:=(p_result->'sample'->>'observed_at')::timestamptz;
 IF p_result->'sample'->>'status' IN ('up','down') AND metrics->>'network_available' IS DISTINCT FROM (CASE WHEN p_result->'sample'->>'status'='up' THEN '1' ELSE '0' END) THEN RAISE EXCEPTION 'Explicit network availability source required' USING ERRCODE='22023'; END IF;
 FOR m IN SELECT key,value FROM jsonb_each(metrics) LOOP
  IF m.key ~ '^if_' THEN
   IF m.key !~ '^if_[1-9][0-9]{0,3}_((in|out)_octets_(hi|lo)|(in|out)_bps|(in|out)_utilization_percent|speed_bps|oper_status)$' THEN RAISE EXCEPTION 'Invalid interface metric' USING ERRCODE='22023'; END IF;
   idx:=split_part(m.key,'_',2)::int;
   IF NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v6_interfaces WHERE organization_id=c.organization_id AND asset_id=c.asset_id AND interface_index=idx AND enabled) THEN RAISE EXCEPTION 'Interface not authorized' USING ERRCODE='42501'; END IF;
   IF public.sowrix_ops_v5_unit(m.key)='word32' AND (m.value::text::numeric NOT BETWEEN 0 AND 4294967295 OR m.value::text::numeric<>trunc(m.value::text::numeric)) THEN RAISE EXCEPTION 'Invalid counter word' USING ERRCODE='22023'; END IF;
  END IF;
 END LOOP;
 IF p_result->'sample'->>'status' NOT IN ('up','down') THEN metrics:='{}'; END IF;
 INSERT INTO public.sowrix_ops_v6_observations VALUES(ev,c.organization_id,c.asset_id,at,p_result->'sample'->>'status',metrics);
 FOR i IN SELECT * FROM public.sowrix_ops_v6_interfaces WHERE organization_id=c.organization_id AND asset_id=c.asset_id AND enabled LOOP
  prefix:='if_'||i.interface_index::text||'_';
  INSERT INTO public.sowrix_ops_v6_interface_history VALUES(ev,c.organization_id,c.asset_id,i.interface_index,at,
   (metrics->>(prefix||'in_octets_hi'))::numeric*4294967296+(metrics->>(prefix||'in_octets_lo'))::numeric,
   (metrics->>(prefix||'out_octets_hi'))::numeric*4294967296+(metrics->>(prefix||'out_octets_lo'))::numeric,
   (metrics->>(prefix||'in_bps'))::numeric,(metrics->>(prefix||'out_bps'))::numeric,
   (metrics->>(prefix||'in_utilization_percent'))::numeric,(metrics->>(prefix||'out_utilization_percent'))::numeric,
   (metrics->>(prefix||'speed_bps'))::numeric,(metrics->>(prefix||'oper_status'))::int);
 END LOOP;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v6_snapshot(p_org uuid,p_asset uuid DEFAULT NULL,p_before timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE nodes jsonb;links jsonb;history jsonb;ports jsonb;scheduler jsonb;alerts jsonb;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'read');
 IF (p_before IS NULL)<>(p_before_id IS NULL) OR (p_before IS NOT NULL AND NOT isfinite(p_before)) THEN RAISE EXCEPTION 'Invalid network history cursor' USING ERRCODE='22023'; END IF;
 IF p_asset IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v6_profiles WHERE organization_id=p_org AND asset_id=p_asset) THEN RAISE EXCEPTION 'Network asset not permitted' USING ERRCODE='42501'; END IF;
 scheduler:=public.sowrix_ops_v5_snapshot(p_org,NULL);
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.name),'[]') INTO nodes FROM (
  SELECT p.organization_id,d.id asset_id,d.name,d.site_id,s.name site_name,p.configuration,p.enabled,d.last_observed,
   CASE WHEN NOT p.enabled OR NOT d.enabled THEN 'DISABLED' ELSE coalesce((SELECT x->>'effective_health' FROM jsonb_array_elements(scheduler->'checks') x WHERE x->>'asset_id'=d.id::text),'UNKNOWN') END health,
   coalesce((SELECT (x->>'interval_seconds')::int FROM jsonb_array_elements(scheduler->'checks') x WHERE x->>'asset_id'=d.id::text),60) interval_seconds,
   coalesce((SELECT x->>'collector_health' FROM jsonb_array_elements(scheduler->'checks') x WHERE x->>'asset_id'=d.id::text),'UNKNOWN') collector_health
  FROM public.sowrix_ops_v6_profiles p JOIN public.sowrix_def_devices d ON d.id=p.asset_id JOIN public.sowrix_def_sites s ON s.id=d.site_id WHERE p.organization_id=p_org
 ) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]') INTO links FROM (SELECT * FROM public.sowrix_ops_v6_links WHERE organization_id=p_org AND enabled ORDER BY id LIMIT 256) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.observed_at DESC,q.evidence_id DESC),'[]') INTO history FROM (
  SELECT * FROM public.sowrix_ops_v6_observations WHERE organization_id=p_org AND (p_asset IS NULL OR asset_id=p_asset)
   AND (p_before IS NULL OR (observed_at,evidence_id)<(p_before,p_before_id)) ORDER BY observed_at DESC,evidence_id DESC LIMIT 100) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.observed_at DESC),'[]') INTO ports FROM (
  SELECT h.evidence_id,h.organization_id,h.asset_id,h.interface_index,h.observed_at,h.in_octets::text in_octets,h.out_octets::text out_octets,
   h.in_bps,h.out_bps,h.in_utilization_percent,h.out_utilization_percent,h.capacity_bps,h.oper_status,i.name
  FROM public.sowrix_ops_v6_interface_history h JOIN public.sowrix_ops_v6_interfaces i USING(organization_id,asset_id,interface_index)
  WHERE h.organization_id=p_org AND h.evidence_id IN (SELECT (x->>'evidence_id')::uuid FROM jsonb_array_elements(history) x) ORDER BY h.observed_at DESC LIMIT 800) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.id DESC),'[]') INTO alerts FROM (
  SELECT t.*,c.asset_id FROM public.sowrix_ops_v5_timeline t JOIN public.sowrix_ops_v5_checks c ON c.id=t.check_id
  JOIN public.sowrix_ops_v6_profiles p ON p.asset_id=c.asset_id AND p.organization_id=t.organization_id
  WHERE t.organization_id=p_org AND (p_asset IS NULL OR c.asset_id=p_asset) ORDER BY t.id DESC LIMIT 100) q;
 RETURN jsonb_build_object('organization_id',p_org,'server_time',clock_timestamp(),'nodes',nodes,'links',links,'history',history,'interfaces',ports,'alerts',alerts,'hardware_verified',false);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v6_configure(uuid,uuid,jsonb),public.sowrix_ops_v6_link(uuid,jsonb),public.sowrix_ops_v6_snapshot(uuid,uuid,timestamptz,uuid),public.sowrix_ops_v5_unit(text),public.sowrix_ops_v4_validate(jsonb),public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v6_configure(uuid,uuid,jsonb),public.sowrix_ops_v6_link(uuid,jsonb),public.sowrix_ops_v6_snapshot(uuid,uuid,timestamptz,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
