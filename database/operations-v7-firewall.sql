-- Additive V7 overlay: existing registry, V6 telemetry, V5 leases and V4 evidence.
BEGIN;
DO $$ BEGIN IF to_regprocedure('public.sowrix_ops_v6_snapshot(uuid,uuid,timestamptz,uuid)') IS NULL THEN RAISE EXCEPTION 'Install V6 first'; END IF; END $$;
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v7_profiles(
 organization_id uuid NOT NULL,asset_id uuid PRIMARY KEY,configuration jsonb NOT NULL,enabled boolean NOT NULL,
 actor_id uuid NOT NULL REFERENCES auth.users(id),updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(organization_id,asset_id) REFERENCES public.sowrix_ops_v6_profiles(organization_id,asset_id),UNIQUE(organization_id,asset_id));
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v7_observations(
 evidence_id uuid PRIMARY KEY,metadata_id uuid NOT NULL,run_id uuid NOT NULL UNIQUE,organization_id uuid NOT NULL,asset_id uuid NOT NULL,
 observed_at timestamptz NOT NULL,status text NOT NULL,details jsonb NOT NULL,
 FOREIGN KEY(organization_id,asset_id,evidence_id) REFERENCES public.sowrix_ops_v4_evidence(organization_id,asset_id,id),
 FOREIGN KEY(organization_id,asset_id,metadata_id) REFERENCES public.sowrix_ops_v4_evidence(organization_id,asset_id,id));
CREATE INDEX IF NOT EXISTS sowrix_ops_v7_time ON public.sowrix_ops_v7_observations(organization_id,asset_id,observed_at DESC,evidence_id DESC);
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v7_events(
 evidence_id uuid PRIMARY KEY,organization_id uuid NOT NULL,asset_id uuid NOT NULL,ingested_at timestamptz NOT NULL,
 FOREIGN KEY(organization_id,asset_id,evidence_id) REFERENCES public.sowrix_ops_v4_evidence(organization_id,asset_id,id));
CREATE INDEX IF NOT EXISTS sowrix_ops_v7_event_time ON public.sowrix_ops_v7_events(organization_id,asset_id,ingested_at DESC,evidence_id DESC);
DO $$ DECLARE t text;BEGIN FOREACH t IN ARRAY ARRAY['profiles','observations','events'] LOOP
 EXECUTE format('ALTER TABLE public.sowrix_ops_v7_%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON public.sowrix_ops_v7_%I FROM PUBLIC,anon,authenticated,service_role',t);
END LOOP;END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v7_validate(p jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE t jsonb;r record;
BEGIN
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR octet_length(p::text)>4096 OR NOT(p ?& ARRAY['enabled','adapter','capabilities','vpn_tunnels','interface_roles']) OR (SELECT count(*) FROM jsonb_object_keys(p))<>5
 OR jsonb_typeof(p->'enabled') IS DISTINCT FROM 'boolean' OR p->>'adapter' IS NULL OR p->>'adapter' NOT IN ('sonicwall_snmpv3','firewall_https_bridge')
 OR jsonb_typeof(p->'capabilities') IS DISTINCT FROM 'array' OR jsonb_array_length(p->'capabilities')>4 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p->'capabilities') x WHERE jsonb_typeof(x)<>'string' OR x #>> '{}' NOT IN ('vpn','firmware','ha','internet'))
 OR (SELECT count(DISTINCT value) FROM jsonb_array_elements(p->'capabilities'))<>jsonb_array_length(p->'capabilities')
 OR jsonb_typeof(p->'vpn_tunnels') IS DISTINCT FROM 'array' OR jsonb_array_length(p->'vpn_tunnels')>4 OR (jsonb_array_length(p->'vpn_tunnels')>0 AND NOT(p->'capabilities' ? 'vpn'))
 OR jsonb_typeof(p->'interface_roles') IS DISTINCT FROM 'object' OR (SELECT count(*) FROM jsonb_object_keys(p->'interface_roles'))>4 THEN RAISE EXCEPTION 'Invalid firewall profile' USING ERRCODE='22023'; END IF;
 FOR t IN SELECT jsonb_array_elements(p->'vpn_tunnels') LOOP
  IF jsonb_typeof(t) IS DISTINCT FROM 'object' OR NOT(t ?& ARRAY['index','label']) OR (SELECT count(*) FROM jsonb_object_keys(t))<>2
  OR jsonb_typeof(t->'index') IS DISTINCT FROM 'number' OR t->>'index' !~ '^[1-4]$' OR jsonb_typeof(t->'label') IS DISTINCT FROM 'string' OR t->>'label' !~ '^[A-Za-z0-9 _.-]{1,48}$' THEN RAISE EXCEPTION 'Invalid tunnel alias' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF (SELECT count(DISTINCT value->>'index') FROM jsonb_array_elements(p->'vpn_tunnels'))<>jsonb_array_length(p->'vpn_tunnels') THEN RAISE EXCEPTION 'Duplicate tunnel' USING ERRCODE='22023'; END IF;
 FOR r IN SELECT key,value FROM jsonb_each(p->'interface_roles') LOOP
  IF r.key !~ '^[1-9][0-9]{0,3}$' OR r.key::int>4096 OR r.value NOT IN ('"WAN"'::jsonb,'"LAN"'::jsonb,'"OTHER"'::jsonb) THEN RAISE EXCEPTION 'Invalid interface role' USING ERRCODE='22023'; END IF;
 END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v7_metadata(p jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR octet_length(p::text)>512 OR EXISTS(SELECT 1 FROM jsonb_object_keys(p) x WHERE x NOT IN ('firmware','ha_state'))
 OR (p ? 'firmware' AND (jsonb_typeof(p->'firmware')<>'string' OR p->>'firmware' !~ '^[A-Za-z0-9][A-Za-z0-9._()+-]{0,79}$'))
 OR (p ? 'ha_state' AND (jsonb_typeof(p->'ha_state') IS DISTINCT FROM 'string' OR p->>'ha_state' NOT IN ('active','standby','standalone','degraded'))) THEN RAISE EXCEPTION 'Invalid firewall metadata' USING ERRCODE='22023'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v7_configure(p_org uuid,p_asset uuid,p_data jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE n public.sowrix_ops_v6_profiles;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'configure');PERFORM 1 FROM public.sowrix_def_orgs WHERE organization_id=p_org FOR UPDATE;
 PERFORM public.sowrix_ops_v7_validate(p_data);
 SELECT * INTO n FROM public.sowrix_ops_v6_profiles WHERE organization_id=p_org AND asset_id=p_asset AND enabled;
 IF n.asset_id IS NULL OR n.configuration->>'vendor' NOT IN ('SonicWall','Fortinet','Cisco','Sophos','Palo Alto','pfSense') OR jsonb_array_length(n.configuration->'interfaces')>4
 OR (p_data->>'adapter'='sonicwall_snmpv3' AND (n.configuration->>'vendor'<>'SonicWall' OR n.configuration->>'adapter'<>'snmpv3_exporter'))
 OR (p_data->>'adapter'='firewall_https_bridge' AND n.configuration->>'adapter'<>'vendor_api')
 OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_data->'interface_roles') k WHERE NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v6_interfaces i WHERE i.organization_id=p_org AND i.asset_id=p_asset AND i.interface_index=k::int AND i.enabled))
 OR NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE id=p_asset AND organization_id=p_org AND enabled) THEN RAISE EXCEPTION 'Compatible authorized firewall asset required' USING ERRCODE='42501'; END IF;
 INSERT INTO public.sowrix_ops_v7_profiles VALUES(p_org,p_asset,p_data,(p_data->>'enabled')::boolean,auth.uid(),now()) ON CONFLICT(asset_id) DO UPDATE SET configuration=excluded.configuration,enabled=excluded.enabled,actor_id=auth.uid(),updated_at=now();
 UPDATE public.sowrix_ops_v5_runs SET state='cancelled',finished_at=clock_timestamp() WHERE check_id IN(SELECT id FROM public.sowrix_ops_v5_checks WHERE organization_id=p_org AND asset_id=p_asset) AND state='leased';
 UPDATE public.sowrix_ops_v5_checks SET revision=revision+1,lease_id=NULL,lease_until=NULL,owner=NULL,next_due=now(),health='UNKNOWN',failures=0,recoveries=0,enabled=enabled AND (p_data->>'enabled')::boolean WHERE organization_id=p_org AND asset_id=p_asset;
 PERFORM public.sowrix_def_audit_write(p_org,'ops_v7_profile',p_asset::text,p_data);
 RETURN jsonb_build_object('organization_id',p_org,'asset_id',p_asset,'configuration',p_data,'hardware_verified',false);
END $$;

DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v7_prior_unit(text)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_unit(text) RENAME TO sowrix_ops_v7_prior_unit;END IF;
 IF to_regprocedure('public.sowrix_ops_v7_prior_claim(text,uuid,integer)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer) RENAME TO sowrix_ops_v7_prior_claim;END IF;
 IF to_regprocedure('public.sowrix_ops_v7_prior_finish(text,uuid,uuid,jsonb)') IS NULL THEN ALTER FUNCTION public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) RENAME TO sowrix_ops_v7_prior_finish;END IF;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_unit(p_metric text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_metric ~ '^vpn_[1-4]_duration_seconds$' THEN 'seconds' WHEN p_metric ~ '^vpn_[1-4]_sessions$' THEN 'count'
 WHEN p_metric ~ '^vpn_[1-4]_available$' OR p_metric IN ('vpn_healthy','ha_degraded','internet_available') THEN 'code' ELSE public.sowrix_ops_v7_prior_unit(p_metric) END
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_claim(p_token text,p_owner uuid,p_limit integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;job jsonb;p public.sowrix_ops_v7_profiles;jobs jsonb:='[]';
BEGIN
 result:=public.sowrix_ops_v7_prior_claim(p_token,p_owner,p_limit);
 FOR job IN SELECT jsonb_array_elements(result->'jobs') LOOP
  SELECT * INTO p FROM public.sowrix_ops_v7_profiles WHERE asset_id=(job->'device'->>'id')::uuid;
  IF p.asset_id IS NOT NULL THEN
   IF NOT p.enabled OR jsonb_array_length(job->'device'->'network'->'interfaces')>4 OR (p.configuration->>'adapter'='sonicwall_snmpv3' AND (job->'device'->'network'->>'adapter' IS DISTINCT FROM 'snmpv3_exporter' OR job->'device'->'network'->>'vendor' IS DISTINCT FROM 'SonicWall')) OR (p.configuration->>'adapter'='firewall_https_bridge' AND job->'device'->'network'->>'adapter' IS DISTINCT FROM 'vendor_api') THEN
    PERFORM public.sowrix_ops_v7_prior_finish(p_token,p_owner,(job->>'id')::uuid,'{"outcome":"cancelled","sample":null}');CONTINUE;
   END IF;
   job:=jsonb_set(job,'{device,firewall}',p.configuration);
  END IF;
  jobs:=jobs||jsonb_build_array(job);
 END LOOP;
 RETURN jsonb_build_object('jobs',jobs);
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_finish(p_token text,p_owner uuid,p_run uuid,p_result jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;p public.sowrix_ops_v7_profiles;r public.sowrix_ops_v5_runs;c public.sowrix_ops_v5_checks;old public.sowrix_ops_v7_observations;doc jsonb;meta jsonb;ev uuid;companion uuid;m record;idx int;
BEGIN
 -- Existing credential/lease/asset/revision checks and all writes remain in the same transaction.
 IF octet_length(p_result::text)>16000 THEN RAISE EXCEPTION 'Completion exceeds bound' USING ERRCODE='22023';END IF;
 result:=public.sowrix_ops_v7_prior_finish(p_token,p_owner,p_run,p_result-'firewall');
 SELECT * INTO r FROM public.sowrix_ops_v5_runs WHERE id=p_run;SELECT * INTO c FROM public.sowrix_ops_v5_checks WHERE id=r.check_id;
 SELECT * INTO old FROM public.sowrix_ops_v7_observations WHERE run_id=p_run;
 IF old.run_id IS NOT NULL THEN
  IF old.details IS DISTINCT FROM p_result->'firewall' THEN RAISE EXCEPTION 'Conflicting firewall completion' USING ERRCODE='22023'; END IF;RETURN result;
 END IF;
 SELECT * INTO p FROM public.sowrix_ops_v7_profiles WHERE organization_id=c.organization_id AND asset_id=c.asset_id AND enabled;
 IF p.asset_id IS NULL THEN
  IF p_result ? 'firewall' THEN RAISE EXCEPTION 'Firewall source not registered' USING ERRCODE='42501'; END IF;RETURN result;
 END IF;
 IF result->>'state'<>'completed' OR (result->>'duplicate')::boolean THEN RETURN result;END IF;
 IF NOT(p_result ? 'firewall') THEN RAISE EXCEPTION 'Firewall metadata envelope required' USING ERRCODE='22023'; END IF;
 meta:=p_result->'firewall';PERFORM public.sowrix_ops_v7_metadata(meta);
 IF p_result->'sample'->>'status'<>'up' AND meta<>'{}'::jsonb THEN RAISE EXCEPTION 'Unavailable source cannot claim metadata' USING ERRCODE='22023'; END IF;
 IF (meta ? 'firmware' AND NOT(p.configuration->'capabilities' ? 'firmware')) OR (meta ? 'ha_state' AND NOT(p.configuration->'capabilities' ? 'ha')) THEN RAISE EXCEPTION 'Unsupported metadata capability' USING ERRCODE='42501';END IF;
 FOR m IN SELECT key,value FROM jsonb_each(p_result->'sample'->'metrics') LOOP
  IF p_result->'sample'->>'status'<>'up' AND (m.key ~ '^vpn_' OR m.key IN ('ha_degraded','internet_available')) THEN RAISE EXCEPTION 'Unavailable firewall cannot claim service measurements' USING ERRCODE='22023';END IF;
  IF m.key ~ '^vpn_' THEN
   IF NOT(p.configuration->'capabilities' ? 'vpn') OR (m.key<>'vpn_healthy' AND m.key !~ '^vpn_[1-4]_(available|duration_seconds|sessions)$') THEN RAISE EXCEPTION 'Invalid VPN metric' USING ERRCODE='22023';END IF;
   IF m.key<>'vpn_healthy' THEN
    idx:=split_part(m.key,'_',2)::int;
    IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p.configuration->'vpn_tunnels') t WHERE (t->>'index')::int=idx) THEN RAISE EXCEPTION 'Tunnel not authorized' USING ERRCODE='42501';END IF;
   END IF;
  END IF;
  IF (m.key ~ '^vpn_.*available$' OR m.key IN ('vpn_healthy','ha_degraded','internet_available')) AND m.value NOT IN ('0'::jsonb,'1'::jsonb) THEN RAISE EXCEPTION 'Invalid availability code' USING ERRCODE='22023';END IF;
  IF m.key ~ '^vpn_[1-4]_sessions$' AND ((m.value::text)::numeric>1000000 OR (m.value::text)::numeric<>trunc((m.value::text)::numeric)) THEN RAISE EXCEPTION 'Invalid aggregate count' USING ERRCODE='22023';END IF;
  IF m.key ~ '^vpn_[1-4]_(sessions|duration_seconds)$' AND (p_result->'sample'->'metrics'->>('vpn_'||split_part(m.key,'_',2)||'_available') IS DISTINCT FROM '1' OR (m.value::text)::numeric>1e12) THEN RAISE EXCEPTION 'VPN aggregates require observed connectivity' USING ERRCODE='22023';END IF;
  IF (m.key='ha_degraded' AND NOT(p.configuration->'capabilities' ? 'ha')) OR (m.key='internet_available' AND NOT(p.configuration->'capabilities' ? 'internet')) THEN RAISE EXCEPTION 'Unsupported firewall metric' USING ERRCODE='42501';END IF;
 END LOOP;
 IF p_result->'sample'->'metrics' ? 'vpn_healthy' THEN
  IF jsonb_array_length(p.configuration->'vpn_tunnels')=0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p.configuration->'vpn_tunnels') t WHERE p_result->'sample'->'metrics'->>('vpn_'||(t->>'index')||'_available') IS NULL)
  OR p_result->'sample'->'metrics'->>'vpn_healthy' IS DISTINCT FROM (CASE WHEN EXISTS(SELECT 1 FROM jsonb_array_elements(p.configuration->'vpn_tunnels') t WHERE p_result->'sample'->'metrics'->>('vpn_'||(t->>'index')||'_available')='0') THEN '0' ELSE '1' END) THEN RAISE EXCEPTION 'Unconfirmed VPN aggregate' USING ERRCODE='22023';END IF;
 END IF;
 IF (meta ? 'ha_state')<>(p_result->'sample'->'metrics' ? 'ha_degraded') OR (meta ? 'ha_state' AND p_result->'sample'->'metrics'->>'ha_degraded' IS DISTINCT FROM CASE WHEN meta->>'ha_state'='degraded' THEN '1' ELSE '0' END) THEN RAISE EXCEPTION 'Unconfirmed HA state' USING ERRCODE='22023';END IF;
 ev:=(result->>'evidence_id')::uuid;
 SELECT document INTO doc FROM public.sowrix_ops_v4_evidence WHERE id=ev;
 doc:=(doc-'authorized_source_identity'-'collector_id')||jsonb_build_object('source_key','firewall:'||p_run::text,'attributes',meta||jsonb_build_object('scheduler_run',p_run),'measurements','{}'::jsonb,'methodology','Credential-bound firewall adapter metadata; source authentication is not independent attestation');
 companion:=((public.sowrix_ops_v4_write(doc,NULL,r.collector_id))->'record'->>'id')::uuid;
 INSERT INTO public.sowrix_ops_v7_observations VALUES(ev,companion,p_run,c.organization_id,c.asset_id,(p_result->'sample'->>'observed_at')::timestamptz,p_result->'sample'->>'status',meta);
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v7_import(p_data jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;org uuid;asset uuid;a jsonb;
BEGIN
 org:=(p_data->>'organization_id')::uuid;asset:=(p_data->>'asset_id')::uuid;
 PERFORM public.sowrix_ops_v3_require(org,'operate');
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v7_profiles WHERE organization_id=org AND asset_id=asset AND enabled) THEN RAISE EXCEPTION 'Firewall source not registered' USING ERRCODE='42501';END IF;
 a:=p_data->'attributes';
 IF p_data->>'category' IS DISTINCT FROM 'soc' OR p_data->>'provenance' IS DISTINCT FROM 'imported_claim' OR p_data->>'status' IS DISTINCT FROM 'OBSERVED'
 OR p_data->>'source_key' !~ '^firewall:[0-9a-f-]{36}$' OR p_data->>'observation_type' NOT IN ('firewall_device_health','firewall_interface_state','firewall_vpn_availability','firewall_authentication_summary','firewall_policy_summary','firewall_vendor_alert')
 OR jsonb_typeof(a) IS DISTINCT FROM 'object' OR NOT(a ?& ARRAY['vendor','event_kind','severity']) OR (SELECT count(*) FROM jsonb_object_keys(a))<>3
 OR a->>'vendor' NOT IN ('SonicWall','Fortinet','Cisco','Sophos','Palo Alto','pfSense') OR a->>'event_kind' NOT IN ('device_health','interface_state','vpn_availability','authentication_summary','policy_summary','vendor_alert')
 OR p_data->>'observation_type' IS DISTINCT FROM 'firewall_'||(a->>'event_kind') OR a->>'severity' NOT IN ('info','warning','critical')
 OR jsonb_typeof(p_data->'measurements') IS DISTINCT FROM 'object' OR NOT(p_data->'measurements' ? 'event_count') OR (SELECT count(*) FROM jsonb_object_keys(p_data->'measurements'))<>1
 OR p_data->'measurements'->'event_count'->>'unit' IS DISTINCT FROM 'count' OR p_data->'measurements'->'event_count'->>'status' IS DISTINCT FROM 'OBSERVED'
 OR (p_data->'measurements'->'event_count'->>'value')::numeric NOT BETWEEN 1 AND 1000000 OR (p_data->'measurements'->'event_count'->>'value')::numeric<>trunc((p_data->'measurements'->'event_count'->>'value')::numeric) THEN RAISE EXCEPTION 'Invalid aggregate firewall event claim' USING ERRCODE='22023';END IF;
 result:=public.sowrix_ops_v4_append(p_data);
 INSERT INTO public.sowrix_ops_v7_events VALUES((result->'record'->>'id')::uuid,org,asset,(result->'record'->>'ingested_at')::timestamptz) ON CONFLICT(evidence_id) DO NOTHING;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v7_snapshot(p_org uuid,p_asset uuid DEFAULT NULL,p_before timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL,p_event_before timestamptz DEFAULT NULL,p_event_id uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE network jsonb;nodes jsonb;history jsonb;events jsonb;alerts jsonb;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'read');
 IF (p_before IS NULL)<>(p_before_id IS NULL) OR (p_event_before IS NULL)<>(p_event_id IS NULL) OR (p_before IS NOT NULL AND NOT isfinite(p_before)) OR (p_event_before IS NOT NULL AND NOT isfinite(p_event_before)) THEN RAISE EXCEPTION 'Invalid firewall history cursor' USING ERRCODE='22023';END IF;
 IF p_asset IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v7_profiles WHERE organization_id=p_org AND asset_id=p_asset) THEN RAISE EXCEPTION 'Firewall asset not permitted' USING ERRCODE='42501';END IF;
 network:=public.sowrix_ops_v6_snapshot(p_org,p_asset,NULL,NULL);
 SELECT coalesce(jsonb_agg(n||jsonb_build_object('firewall',p.configuration,'collector_id',d.collector_id,'health',CASE WHEN NOT p.enabled THEN 'DISABLED' ELSE n->>'health' END,'last_successful_observation',(SELECT max(observed_at) FROM public.sowrix_ops_v7_observations o WHERE o.organization_id=p_org AND o.asset_id=p.asset_id AND o.status='up'))),'[]') INTO nodes
 FROM jsonb_array_elements(network->'nodes') n JOIN public.sowrix_ops_v7_profiles p ON p.asset_id=(n->>'asset_id')::uuid AND p.organization_id=p_org JOIN public.sowrix_def_devices d ON d.id=p.asset_id;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.observed_at DESC,q.evidence_id DESC),'[]') INTO history FROM (
  SELECT o.*,v.metrics FROM public.sowrix_ops_v7_observations o JOIN public.sowrix_ops_v6_observations v USING(evidence_id)
  WHERE o.organization_id=p_org AND (p_asset IS NULL OR o.asset_id=p_asset) AND (p_before IS NULL OR (o.observed_at,o.evidence_id)<(p_before,p_before_id)) ORDER BY o.observed_at DESC,o.evidence_id DESC LIMIT 100) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.ingested_at DESC,q.id DESC),'[]') INTO events FROM (
  SELECT e.* FROM public.sowrix_ops_v7_events f JOIN public.sowrix_ops_v4_evidence e ON e.id=f.evidence_id WHERE f.organization_id=p_org AND (p_asset IS NULL OR f.asset_id=p_asset)
   AND (p_event_before IS NULL OR (f.ingested_at,f.evidence_id)<(p_event_before,p_event_id)) ORDER BY f.ingested_at DESC,f.evidence_id DESC LIMIT 100) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.id DESC),'[]') INTO alerts FROM (
  SELECT t.*,c.asset_id FROM public.sowrix_ops_v5_timeline t JOIN public.sowrix_ops_v5_checks c ON c.id=t.check_id JOIN public.sowrix_ops_v7_profiles p ON p.asset_id=c.asset_id AND p.organization_id=t.organization_id
  WHERE t.organization_id=p_org AND (p_asset IS NULL OR c.asset_id=p_asset) ORDER BY t.id DESC LIMIT 100) q;
 RETURN jsonb_build_object('organization_id',p_org,'server_time',network->'server_time','nodes',nodes,'history',history,'events',events,'alerts',alerts,'hardware_verified',false);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v7_validate(jsonb),public.sowrix_ops_v7_metadata(jsonb),public.sowrix_ops_v7_prior_unit(text),public.sowrix_ops_v7_prior_claim(text,uuid,integer),public.sowrix_ops_v7_prior_finish(text,uuid,uuid,jsonb),public.sowrix_ops_v5_unit(text),public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb),public.sowrix_ops_v7_configure(uuid,uuid,jsonb),public.sowrix_ops_v7_import(jsonb),public.sowrix_ops_v7_snapshot(uuid,uuid,timestamptz,uuid,timestamptz,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v7_configure(uuid,uuid,jsonb),public.sowrix_ops_v7_import(jsonb),public.sowrix_ops_v7_snapshot(uuid,uuid,timestamptz,uuid,timestamptz,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
