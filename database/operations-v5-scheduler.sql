-- Additive scheduler on existing authorized assets, V4 ledger and incident/outbox.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v4_write(jsonb,uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Install V4 first'; END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v5_checks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 asset_id uuid NOT NULL UNIQUE, enabled boolean NOT NULL DEFAULT true,
 interval_seconds integer NOT NULL CHECK(interval_seconds BETWEEN 15 AND 3600),
 timeout_seconds integer NOT NULL CHECK(timeout_seconds BETWEEN 1 AND 8),
 failure_confirm integer NOT NULL CHECK(failure_confirm BETWEEN 1 AND 10),
 recovery_confirm integer NOT NULL CHECK(recovery_confirm BETWEEN 1 AND 10),
 thresholds jsonb NOT NULL DEFAULT '[]', next_due timestamptz NOT NULL DEFAULT now(),
 revision integer NOT NULL DEFAULT 1, lease_id uuid, lease_until timestamptz, owner uuid,
 failures integer NOT NULL DEFAULT 0, recoveries integer NOT NULL DEFAULT 0,
 retries integer NOT NULL DEFAULT 0, health text NOT NULL DEFAULT 'UNKNOWN',
 last_observed timestamptz, last_finished timestamptz, last_outcome text,
 evidence_id uuid, created_by uuid NOT NULL REFERENCES auth.users(id),
 FOREIGN KEY(organization_id,asset_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 UNIQUE(organization_id,id), CHECK(health IN ('UP','DOWN','DEGRADED','UNKNOWN'))
);
CREATE INDEX IF NOT EXISTS sowrix_ops_v5_due ON public.sowrix_ops_v5_checks(organization_id,next_due) WHERE enabled;
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v5_runs (
 id uuid PRIMARY KEY, organization_id uuid NOT NULL, check_id uuid NOT NULL,
 owner uuid NOT NULL,collector_id uuid NOT NULL REFERENCES public.sowrix_def_collectors(id),definition jsonb NOT NULL,revision integer NOT NULL, state text NOT NULL DEFAULT 'leased',
 started_at timestamptz NOT NULL DEFAULT clock_timestamp(), finished_at timestamptz,
 evidence_id uuid, receipt jsonb, input jsonb,
 FOREIGN KEY(organization_id,check_id) REFERENCES public.sowrix_ops_v5_checks(organization_id,id),
 CHECK(state IN ('leased','completed','timeout','cancelled','expired','unavailable'))
);
CREATE INDEX IF NOT EXISTS sowrix_ops_v5_run_history ON public.sowrix_ops_v5_runs(organization_id,started_at DESC,id DESC);
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v5_windows (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organization_id uuid NOT NULL REFERENCES public.sowrix_def_orgs(organization_id),
 asset_id uuid,starts_at timestamptz NOT NULL,ends_at timestamptz NOT NULL,
 enabled boolean NOT NULL DEFAULT true,actor_id uuid NOT NULL REFERENCES auth.users(id),
 FOREIGN KEY(organization_id,asset_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 CHECK(isfinite(starts_at) AND isfinite(ends_at) AND ends_at>starts_at AND ends_at<=starts_at+interval '30 days')
);
CREATE INDEX IF NOT EXISTS sowrix_ops_v5_windows_scope ON public.sowrix_ops_v5_windows(organization_id,starts_at,ends_at) WHERE enabled;
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v5_timeline (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, organization_id uuid NOT NULL,
 check_id uuid NOT NULL,event text NOT NULL,at timestamptz NOT NULL DEFAULT clock_timestamp(),
 actor_id uuid,run_id uuid,incident_id uuid,evidence_id uuid,details jsonb NOT NULL DEFAULT '{}',
 FOREIGN KEY(organization_id,check_id) REFERENCES public.sowrix_ops_v5_checks(organization_id,id),
 FOREIGN KEY(organization_id,incident_id) REFERENCES public.sowrix_def_incidents(organization_id,id)
);
CREATE INDEX IF NOT EXISTS sowrix_ops_v5_alert_history ON public.sowrix_ops_v5_timeline(organization_id,id DESC);
ALTER TABLE public.sowrix_ops_v5_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_ops_v5_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_ops_v5_windows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_ops_v5_timeline ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_ops_v5_checks,public.sowrix_ops_v5_runs,public.sowrix_ops_v5_windows,public.sowrix_ops_v5_timeline FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON public.sowrix_ops_v5_timeline_id_seq FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_unit(p_metric text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_metric IN ('latency_ms','response_ms') THEN 'ms'
 WHEN p_metric IN ('cpu_percent','memory_percent','disk_percent') THEN 'percent' END
$$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_thresholds(p jsonb)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE t jsonb;
BEGIN
 IF jsonb_typeof(p) IS DISTINCT FROM 'array' OR jsonb_array_length(p)>8 THEN RAISE EXCEPTION 'Invalid thresholds' USING ERRCODE='22023'; END IF;
 FOR t IN SELECT jsonb_array_elements(p) LOOP
  IF jsonb_typeof(t) IS DISTINCT FROM 'object' OR NOT(t ?& ARRAY['metric','unit','warning','critical','direction']) OR (SELECT count(*) FROM jsonb_object_keys(t))<>5
  OR jsonb_typeof(t->'metric') IS DISTINCT FROM 'string' OR jsonb_typeof(t->'unit') IS DISTINCT FROM 'string'
  OR public.sowrix_ops_v5_unit(t->>'metric') IS NULL OR public.sowrix_ops_v5_unit(t->>'metric') IS DISTINCT FROM t->>'unit'
  OR jsonb_typeof(t->'warning') IS DISTINCT FROM 'number' OR jsonb_typeof(t->'critical') IS DISTINCT FROM 'number'
  OR jsonb_typeof(t->'direction') IS DISTINCT FROM 'string' OR t->>'direction' NOT IN ('above','below') THEN
   RAISE EXCEPTION 'Invalid threshold contract or units' USING ERRCODE='22023'; END IF;
  IF (t->>'warning')::numeric<0 OR (t->>'critical')::numeric<0 OR greatest((t->>'warning')::numeric,(t->>'critical')::numeric)>(CASE WHEN t->>'unit'='percent' THEN 100 ELSE 1e15 END)
  OR (t->>'direction'='above' AND (t->>'warning')::numeric>=(t->>'critical')::numeric)
  OR (t->>'direction'='below' AND (t->>'warning')::numeric<=(t->>'critical')::numeric) THEN
   RAISE EXCEPTION 'Invalid threshold levels' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF (SELECT count(DISTINCT value->>'metric') FROM jsonb_array_elements(p))<>jsonb_array_length(p) THEN RAISE EXCEPTION 'Duplicate metric threshold' USING ERRCODE='22023'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_configure(p_org uuid,p_asset uuid,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.sowrix_ops_v5_checks; k text;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'configure');
 PERFORM 1 FROM public.sowrix_def_orgs WHERE organization_id=p_org FOR UPDATE;
 IF jsonb_typeof(p_data) IS DISTINCT FROM 'object' OR octet_length(p_data::text)>4096
 OR NOT(p_data ?& ARRAY['enabled','interval_seconds','timeout_seconds','failure_confirm','recovery_confirm','thresholds']) OR (SELECT count(*) FROM jsonb_object_keys(p_data))<>6
 OR jsonb_typeof(p_data->'enabled') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Invalid check configuration' USING ERRCODE='22023'; END IF;
 FOREACH k IN ARRAY ARRAY['interval_seconds','timeout_seconds','failure_confirm','recovery_confirm'] LOOP
  IF jsonb_typeof(p_data->k) IS DISTINCT FROM 'number' OR p_data->>k !~ '^[0-9]{1,4}$' THEN RAISE EXCEPTION 'Integer limits required' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF (p_data->>'interval_seconds')::int NOT BETWEEN 15 AND 3600 OR (p_data->>'timeout_seconds')::int NOT BETWEEN 1 AND 8
 OR (p_data->>'failure_confirm')::int NOT BETWEEN 1 AND 10 OR (p_data->>'recovery_confirm')::int NOT BETWEEN 1 AND 10 THEN
  RAISE EXCEPTION 'Unsafe check limits' USING ERRCODE='22023'; END IF;
 PERFORM public.sowrix_ops_v5_thresholds(p_data->'thresholds');
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices d JOIN public.sowrix_def_collectors x ON x.id=d.collector_id
  WHERE d.organization_id=p_org AND d.id=p_asset AND d.enabled AND x.status='active'
  AND d.protocol IN ('tcp','https','prometheus','icmp','backup_json','snmp_exporter','onvif','rtsp')) THEN
  RAISE EXCEPTION 'Authorized enabled asset required' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v5_checks WHERE asset_id=p_asset) AND (SELECT count(*) FROM public.sowrix_ops_v5_checks WHERE organization_id=p_org)>=100 THEN
  RAISE EXCEPTION 'Tenant check limit reached' USING ERRCODE='54000'; END IF;
 INSERT INTO public.sowrix_ops_v5_checks(organization_id,asset_id,enabled,interval_seconds,timeout_seconds,failure_confirm,recovery_confirm,thresholds,created_by)
 VALUES(p_org,p_asset,(p_data->>'enabled')::boolean,(p_data->>'interval_seconds')::int,(p_data->>'timeout_seconds')::int,(p_data->>'failure_confirm')::int,(p_data->>'recovery_confirm')::int,p_data->'thresholds',auth.uid())
 ON CONFLICT(asset_id) DO UPDATE SET enabled=excluded.enabled,interval_seconds=excluded.interval_seconds,timeout_seconds=excluded.timeout_seconds,
 failure_confirm=excluded.failure_confirm,recovery_confirm=excluded.recovery_confirm,thresholds=excluded.thresholds,revision=public.sowrix_ops_v5_checks.revision+1,
 next_due=now(),failures=0,recoveries=0,retries=0,health='UNKNOWN' RETURNING * INTO c;
 -- Fence a prior in-flight definition without removing its historical run.
 UPDATE public.sowrix_ops_v5_runs SET state='cancelled',finished_at=clock_timestamp() WHERE check_id=c.id AND state='leased';
 UPDATE public.sowrix_ops_v5_checks SET lease_id=NULL,lease_until=NULL,owner=NULL WHERE id=c.id;
 UPDATE public.sowrix_def_devices SET interval_seconds=c.interval_seconds WHERE id=p_asset;
 SELECT * INTO c FROM public.sowrix_ops_v5_checks WHERE id=c.id;
 PERFORM public.sowrix_def_audit_write(p_org,'ops_v5_configure',c.id::text,p_data);
 INSERT INTO public.sowrix_ops_v5_timeline(organization_id,check_id,event,actor_id,details) VALUES(p_org,c.id,'configured',auth.uid(),p_data);
 RETURN to_jsonb(c)-'lease_id'-'owner';
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_window(p_org uuid,p_asset uuid,p_start text,p_end text,p_id uuid DEFAULT NULL,p_enabled boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w public.sowrix_ops_v5_windows;start_at timestamptz;end_at timestamptz;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'configure');
 PERFORM 1 FROM public.sowrix_def_orgs WHERE organization_id=p_org FOR UPDATE;
 IF p_start IS NULL OR p_end IS NULL OR p_start !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-](0[0-9]|1[0-5]):[0-5][0-9])$'
 OR p_end !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-](0[0-9]|1[0-5]):[0-5][0-9])$' THEN
  RAISE EXCEPTION 'Explicit timezone required' USING ERRCODE='22023'; END IF;
 start_at:=p_start::timestamptz;end_at:=p_end::timestamptz;
 IF p_enabled IS NULL OR NOT isfinite(start_at) OR NOT isfinite(end_at) OR end_at<=start_at OR end_at>start_at+interval '30 days' THEN
  RAISE EXCEPTION 'Invalid maintenance window' USING ERRCODE='22023'; END IF;
 IF p_asset IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE organization_id=p_org AND id=p_asset) THEN RAISE EXCEPTION 'Asset not permitted' USING ERRCODE='42501'; END IF;
 IF p_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v5_windows WHERE organization_id=p_org AND id=p_id) THEN RAISE EXCEPTION 'Window not permitted' USING ERRCODE='42501'; END IF;
 IF p_enabled AND EXISTS(SELECT 1 FROM public.sowrix_ops_v5_windows WHERE organization_id=p_org AND enabled AND (p_id IS NULL OR id<>p_id)
  AND (p_asset IS NULL OR asset_id IS NULL OR asset_id=p_asset) AND starts_at<end_at AND ends_at>start_at) THEN
  RAISE EXCEPTION 'Overlapping maintenance window' USING ERRCODE='22023'; END IF;
 IF p_id IS NULL AND (SELECT count(*) FROM public.sowrix_ops_v5_windows WHERE organization_id=p_org AND enabled AND ends_at>now())>=100 THEN RAISE EXCEPTION 'Window limit reached' USING ERRCODE='54000'; END IF;
 INSERT INTO public.sowrix_ops_v5_windows(id,organization_id,asset_id,starts_at,ends_at,enabled,actor_id)
 VALUES(coalesce(p_id,gen_random_uuid()),p_org,p_asset,start_at,end_at,p_enabled,auth.uid())
 ON CONFLICT(id) DO UPDATE SET asset_id=excluded.asset_id,starts_at=excluded.starts_at,ends_at=excluded.ends_at,enabled=excluded.enabled,actor_id=auth.uid() RETURNING * INTO w;
 UPDATE public.sowrix_ops_v5_checks SET failures=0,recoveries=0 WHERE organization_id=p_org AND (p_asset IS NULL OR asset_id=p_asset);
 PERFORM public.sowrix_def_audit_write(p_org,'ops_v5_maintenance',w.id::text,to_jsonb(w));
 RETURN to_jsonb(w);
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_collector(p_token text)
RETURNS public.sowrix_def_collectors LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.sowrix_def_collectors;
BEGIN
 IF p_token IS NULL OR p_token !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'Collector not authorized' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.sowrix_def_collectors WHERE token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') FOR UPDATE;
 IF c.id IS NULL OR c.status<>'active' OR (c.token_expires_at IS NOT NULL AND c.token_expires_at<=now()) OR NOT EXISTS(
  SELECT 1 FROM public.sowrix_def_orgs o JOIN public.clients x ON x.id=o.organization_id WHERE o.organization_id=c.organization_id AND o.enabled AND x.status='active') THEN
  RAISE EXCEPTION 'Collector not authorized' USING ERRCODE='42501'; END IF;
 RETURN c;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_claim(p_token text,p_owner uuid,p_limit integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
#variable_conflict use_column
DECLARE col public.sowrix_def_collectors;c public.sowrix_ops_v5_checks;d public.sowrix_def_devices; jobs jsonb:='[]'; active_count integer; token uuid;
BEGIN
 col:=public.sowrix_ops_v5_collector(p_token);
 IF p_owner IS NULL OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 4 THEN RAISE EXCEPTION 'Invalid worker limits' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM public.sowrix_def_orgs WHERE organization_id=col.organization_id FOR UPDATE;
 UPDATE public.sowrix_def_collectors SET last_seen=now() WHERE id=col.id;
 -- Expired claims are fenced. Lost execution does not invent a device observation.
 FOR c IN SELECT x.* FROM public.sowrix_ops_v5_checks x JOIN public.sowrix_def_devices d ON d.id=x.asset_id
  WHERE x.organization_id=col.organization_id AND d.collector_id=col.id AND x.lease_id IS NOT NULL AND x.lease_until<=now() FOR UPDATE OF x LOOP
  UPDATE public.sowrix_ops_v5_runs SET state='expired',finished_at=clock_timestamp() WHERE id=c.lease_id AND state='leased';
  UPDATE public.sowrix_ops_v5_checks SET lease_id=NULL,lease_until=NULL,owner=NULL,health='UNKNOWN',failures=0,recoveries=0,
   retries=least(retries+1,3),next_due=now()+CASE WHEN retries<3 THEN least(300,5*power(2,retries)) ELSE interval_seconds END * interval '1 second',last_outcome='expired' WHERE id=c.id;
  INSERT INTO public.sowrix_ops_v5_timeline(organization_id,check_id,event,run_id,details) VALUES(c.organization_id,c.id,'lease_expired',c.lease_id,'{"device_failure_confirmed":false}');
 END LOOP;
 SELECT count(*) INTO active_count FROM public.sowrix_ops_v5_checks WHERE organization_id=col.organization_id AND lease_until>now();
 FOR c IN SELECT x.* FROM public.sowrix_ops_v5_checks x JOIN public.sowrix_def_devices d ON d.id=x.asset_id
  WHERE x.organization_id=col.organization_id AND x.enabled AND x.next_due<=now() AND x.lease_id IS NULL
   AND d.collector_id=col.id AND d.site_id=col.site_id AND d.enabled
  ORDER BY x.next_due,x.id FOR UPDATE OF x SKIP LOCKED LIMIT least(p_limit,greatest(0,8-active_count)) LOOP
  SELECT * INTO d FROM public.sowrix_def_devices WHERE id=c.asset_id;
  token:=gen_random_uuid();
  UPDATE public.sowrix_ops_v5_checks SET lease_id=token,owner=p_owner,lease_until=now()+(c.timeout_seconds+30)*interval '1 second' WHERE id=c.id;
  INSERT INTO public.sowrix_ops_v5_runs(id,organization_id,check_id,owner,collector_id,definition,revision) VALUES(token,c.organization_id,c.id,p_owner,col.id,
   jsonb_build_object('collector_id',d.collector_id,'site_id',d.site_id,'protocol',d.protocol,'target',d.target,'settings',d.settings),c.revision);
  jobs:=jobs||jsonb_build_array(jsonb_build_object('id',token,'check_id',c.id,'timeout_seconds',c.timeout_seconds,'device',jsonb_build_object(
   'id',d.id,'name',d.name,'kind',d.kind,'protocol',d.protocol,'target',d.target,'settings',d.settings,'interval_seconds',c.interval_seconds)));
 END LOOP;
 RETURN jsonb_build_object('jobs',jobs);
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_finish(p_token text,p_owner uuid,p_run uuid,p_result jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE col public.sowrix_def_collectors;c public.sowrix_ops_v5_checks;r public.sowrix_ops_v5_runs;d public.sowrix_def_devices;
 outcome text;s jsonb;tm timestamptz;candidate text;v numeric;t jsonb;measures jsonb;doc jsonb;ev uuid;inc uuid;existed boolean;maint boolean;
 bad integer;good integer;state text;v_receipt jsonb;event_name text;
BEGIN
 col:=public.sowrix_ops_v5_collector(p_token);
 PERFORM 1 FROM public.sowrix_def_orgs WHERE organization_id=col.organization_id FOR UPDATE;
 SELECT x.* INTO c FROM public.sowrix_ops_v5_checks x JOIN public.sowrix_ops_v5_runs y ON y.check_id=x.id
  JOIN public.sowrix_def_devices z ON z.id=x.asset_id WHERE y.id=p_run AND x.organization_id=col.organization_id AND z.collector_id=col.id AND z.site_id=col.site_id FOR UPDATE OF x;
 SELECT * INTO r FROM public.sowrix_ops_v5_runs WHERE id=p_run FOR UPDATE;
 IF c.id IS NULL OR p_owner IS NULL OR r.owner<>p_owner THEN RAISE EXCEPTION 'Job not permitted' USING ERRCODE='42501'; END IF;
 IF r.receipt IS NOT NULL THEN
  IF r.input IS DISTINCT FROM p_result THEN RAISE EXCEPTION 'Conflicting completion' USING ERRCODE='22023'; END IF;
  RETURN r.receipt||'{"duplicate":true}'::jsonb;
 END IF;
 SELECT * INTO d FROM public.sowrix_def_devices WHERE id=c.asset_id;
 IF r.state<>'leased' OR c.lease_id IS DISTINCT FROM p_run OR c.owner IS DISTINCT FROM p_owner OR c.lease_until<=now() OR r.revision<>c.revision OR NOT c.enabled OR NOT d.enabled THEN
  RAISE EXCEPTION 'Job cancelled or lease expired' USING ERRCODE='42501'; END IF;
 IF r.definition IS DISTINCT FROM jsonb_build_object('collector_id',d.collector_id,'site_id',d.site_id,'protocol',d.protocol,'target',d.target,'settings',d.settings) THEN
  RAISE EXCEPTION 'Asset definition changed during execution' USING ERRCODE='42501'; END IF;
 IF jsonb_typeof(p_result) IS DISTINCT FROM 'object' OR octet_length(p_result::text)>16000 OR NOT(p_result ?& ARRAY['outcome','sample']) OR (SELECT count(*) FROM jsonb_object_keys(p_result))<>2
 OR jsonb_typeof(p_result->'outcome') IS DISTINCT FROM 'string' OR p_result->>'outcome' NOT IN ('completed','timeout','cancelled','unavailable') THEN
  RAISE EXCEPTION 'Invalid completion' USING ERRCODE='22023'; END IF;
 outcome:=p_result->>'outcome';s:=p_result->'sample';candidate:='UNKNOWN';tm:=NULL;
 IF outcome='completed' THEN
  IF jsonb_typeof(s) IS DISTINCT FROM 'object' OR NOT(s ?& ARRAY['device_id','observed_at','status','metrics']) OR (SELECT count(*) FROM jsonb_object_keys(s))<>4
  OR s->>'device_id' IS DISTINCT FROM c.asset_id::text OR jsonb_typeof(s->'status') IS DISTINCT FROM 'string' OR s->>'status' NOT IN ('up','down','unknown','unsupported')
  OR jsonb_typeof(s->'observed_at') IS DISTINCT FROM 'string' OR s->>'observed_at' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-](0[0-9]|1[0-5]):[0-5][0-9])$'
  OR jsonb_typeof(s->'metrics') IS DISTINCT FROM 'object' OR (SELECT count(*) FROM jsonb_object_keys(s->'metrics'))>100 THEN
   RAISE EXCEPTION 'Invalid observation' USING ERRCODE='22023'; END IF;
  tm:=(s->>'observed_at')::timestamptz;
  IF NOT isfinite(tm) OR tm<r.started_at-interval '2 seconds' OR tm>clock_timestamp()+interval '2 seconds'
   OR tm>r.started_at+(c.timeout_seconds+2)*interval '1 second'
   OR (c.last_observed IS NOT NULL AND tm<=c.last_observed) THEN RAISE EXCEPTION 'Observation outside job or out of order' USING ERRCODE='22023'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_each(s->'metrics') m WHERE m.key !~ '^[a-z][a-z0-9_]{0,63}$'
   OR CASE WHEN jsonb_typeof(m.value)='number' THEN abs(m.value::text::numeric)>1e15
     OR (public.sowrix_ops_v5_unit(m.key) IS NOT NULL AND m.value::text::numeric<0)
     OR (public.sowrix_ops_v5_unit(m.key)='percent' AND m.value::text::numeric>100) ELSE true END) THEN
   RAISE EXCEPTION 'Invalid numeric metrics' USING ERRCODE='22023'; END IF;
  -- V4 writer validates all numeric bounds, metric names and units independently.
  SELECT coalesce(jsonb_object_agg(key,jsonb_build_object('value',value,'status','OBSERVED','unit',coalesce(public.sowrix_ops_v5_unit(key),'unspecified'))),'{}') INTO measures FROM jsonb_each(s->'metrics');
  IF s->>'status' IN ('unknown','unsupported') THEN measures:='{}'; END IF;
  doc:=jsonb_build_object('schema_version',1,'organization_id',col.organization_id,'asset_id',d.id,'source_id',col.id,'source_key','scheduler:'||p_run::text,
   'category','monitoring','observation_type','collector_sample','observed_at',s->>'observed_at','status',CASE s->>'status' WHEN 'up' THEN 'PASS' WHEN 'down' THEN 'FAIL' WHEN 'unsupported' THEN 'UNAVAILABLE' ELSE 'UNKNOWN' END,
   'measurements',measures,'attributes',jsonb_build_object('scheduler_run',p_run,'check_id',c.id),'confidence','UNKNOWN',
   'methodology','Credential-bound existing collector adapter; source-authenticated observation, not independent attestation',
   'provenance','authenticated_collector','parents','[]'::jsonb,'archive_id',NULL);
  ev:=((public.sowrix_ops_v4_write(doc,NULL,col.id))->'record'->>'id')::uuid;
  INSERT INTO public.sowrix_def_samples(organization_id,device_id,observed_at,status,metrics) VALUES(col.organization_id,d.id,tm,s->>'status',s->'metrics');
  UPDATE public.sowrix_def_devices SET status=s->>'status',latest_metrics=s->'metrics',last_observed=tm,last_seen=now(),latest_message='Scheduled observation' WHERE id=d.id;
  candidate:=CASE s->>'status' WHEN 'down' THEN 'DOWN' WHEN 'up' THEN 'UP' ELSE 'UNKNOWN' END;
  IF candidate='UP' THEN
   FOR t IN SELECT jsonb_array_elements(c.thresholds) LOOP
    IF NOT(s->'metrics' ? (t->>'metric')) THEN candidate:='UNKNOWN';EXIT; END IF;
    v:=(s->'metrics'->>(t->>'metric'))::numeric;
    IF (t->>'direction'='above' AND v>=(t->>'critical')::numeric) OR (t->>'direction'='below' AND v<=(t->>'critical')::numeric) THEN candidate:='DOWN';
    ELSIF candidate<>'DOWN' AND ((t->>'direction'='above' AND v>=(t->>'warning')::numeric) OR (t->>'direction'='below' AND v<=(t->>'warning')::numeric)) THEN candidate:='DEGRADED'; END IF;
   END LOOP;
  END IF;
 ELSIF s IS DISTINCT FROM 'null'::jsonb THEN RAISE EXCEPTION 'No observation may be invented for unsuccessful execution' USING ERRCODE='22023';
 END IF;
 maint:=EXISTS(SELECT 1 FROM public.sowrix_ops_v5_windows WHERE organization_id=c.organization_id AND enabled
  AND ((starts_at<=now() AND ends_at>now()) OR (tm IS NOT NULL AND starts_at<=tm AND ends_at>tm)) AND (asset_id IS NULL OR asset_id=c.asset_id));
 -- Gaps reset confirmation. Timeout/cancellation is a collector/job problem, not confirmed device down.
 bad:=CASE WHEN candidate IN ('DOWN','DEGRADED') AND NOT maint THEN CASE WHEN c.last_finished>=now()-greatest(c.interval_seconds*3,45)*interval '1 second' THEN least(c.failures+1,10) ELSE 1 END ELSE 0 END;
 good:=CASE WHEN candidate='UP' AND NOT maint THEN CASE WHEN c.last_finished>=now()-greatest(c.interval_seconds*3,45)*interval '1 second' THEN least(c.recoveries+1,10) ELSE 1 END ELSE 0 END;
 SELECT id INTO inc FROM public.sowrix_def_incidents WHERE device_id=c.asset_id AND rule_key='scheduler:'||c.id::text AND status<>'resolved';
 existed:=inc IS NOT NULL;state:=candidate;event_name:=CASE WHEN maint THEN 'suppressed' ELSE 'observation' END;
 IF NOT maint AND candidate IN ('DOWN','DEGRADED') AND bad>=c.failure_confirm THEN
  PERFORM public.sowrix_def_incident(c.organization_id,c.asset_id,'scheduler:'||c.id::text,d.name||' scheduled check requires review',true,jsonb_build_object('evidence_id',ev,'health',candidate,'run_id',p_run));
  SELECT id INTO inc FROM public.sowrix_def_incidents WHERE device_id=c.asset_id AND rule_key='scheduler:'||c.id::text AND status<>'resolved';
  UPDATE public.sowrix_def_incidents SET severity=CASE WHEN candidate='DOWN' THEN 'critical' ELSE 'warning' END WHERE id=inc;
  event_name:=CASE WHEN existed THEN 'deduplicated' ELSE 'alert_opened' END;
 ELSIF NOT maint AND candidate='UP' AND existed THEN
  IF good>=c.recovery_confirm THEN
   PERFORM public.sowrix_def_incident(c.organization_id,c.asset_id,'scheduler:'||c.id::text,'',false,jsonb_build_object('evidence_id',ev,'run_id',p_run));event_name:='recovered';
  ELSE state:='DEGRADED';event_name:='recovery_pending'; END IF;
 END IF;
 UPDATE public.sowrix_ops_v5_checks SET lease_id=NULL,lease_until=NULL,owner=NULL,last_finished=clock_timestamp(),last_outcome=outcome,health=state,
  failures=bad,recoveries=good,last_observed=coalesce(tm,last_observed),evidence_id=coalesce(ev,evidence_id),
  retries=CASE WHEN outcome IN ('timeout','unavailable') THEN least(retries+1,3) ELSE 0 END,
  next_due=now()+CASE WHEN outcome IN ('timeout','unavailable') AND retries<3 THEN least(300,5*power(2,retries)) ELSE interval_seconds END*interval '1 second'
 WHERE id=c.id;
 v_receipt:=jsonb_build_object('run_id',p_run,'state',outcome,'evidence_id',ev,'duplicate',false);
 UPDATE public.sowrix_ops_v5_runs SET state=outcome,finished_at=clock_timestamp(),evidence_id=ev,receipt=v_receipt,input=p_result WHERE id=p_run;
 UPDATE public.sowrix_def_collectors SET last_seen=now() WHERE id=col.id;
 INSERT INTO public.sowrix_ops_v5_timeline(organization_id,check_id,event,run_id,incident_id,evidence_id,details)
 VALUES(c.organization_id,c.id,event_name,p_run,inc,ev,jsonb_build_object('health',state,'outcome',outcome,'maintenance',maint,'failures',bad,'recoveries',good));
 RETURN v_receipt;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_ack(p_org uuid,p_check uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE inc uuid;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'operate');
 PERFORM 1 FROM public.sowrix_ops_v5_checks WHERE organization_id=p_org AND id=p_check FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Check not permitted' USING ERRCODE='42501'; END IF;
 UPDATE public.sowrix_def_incidents SET status='acknowledged',acknowledged_by=auth.uid(),updated_at=now()
 WHERE organization_id=p_org AND rule_key='scheduler:'||p_check::text AND status='open' RETURNING id INTO inc;
 IF inc IS NOT NULL THEN
  INSERT INTO public.sowrix_ops_v5_timeline(organization_id,check_id,event,actor_id,incident_id) VALUES(p_org,p_check,'acknowledged',auth.uid(),inc);
  PERFORM public.sowrix_def_audit_write(p_org,'ops_v5_acknowledged',inc::text);
 END IF;
 RETURN jsonb_build_object('acknowledged',inc IS NOT NULL);
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v5_snapshot(p_org uuid,p_before bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE checks jsonb;runs jsonb;windows jsonb;timeline jsonb;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'read');
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.id),'[]') INTO checks FROM (
  SELECT x.id,x.organization_id,x.asset_id,d.name,x.enabled,x.interval_seconds,x.timeout_seconds,x.failure_confirm,x.recovery_confirm,x.thresholds,x.next_due,x.last_observed,x.last_finished,x.last_outcome,x.evidence_id,
   CASE WHEN NOT x.enabled OR NOT d.enabled THEN 'DISABLED'
    WHEN EXISTS(SELECT 1 FROM public.sowrix_ops_v5_windows w WHERE w.organization_id=p_org AND w.enabled AND w.starts_at<=now() AND w.ends_at>now() AND (w.asset_id IS NULL OR w.asset_id=x.asset_id)) THEN 'MAINTENANCE'
    WHEN x.last_observed IS NULL THEN 'UNKNOWN'
    WHEN x.last_observed<now()-greatest(x.interval_seconds*3,45)*interval '1 second' THEN 'STALE'
    ELSE x.health END effective_health,
   CASE WHEN col.status<>'active' THEN 'DISABLED' WHEN col.last_seen IS NULL OR col.last_seen<now()-interval '60 seconds' THEN 'STALE' ELSE 'CONNECTED' END collector_health,
   x.lease_until,(x.lease_until>now()) running
  FROM public.sowrix_ops_v5_checks x JOIN public.sowrix_def_devices d ON d.id=x.asset_id JOIN public.sowrix_def_collectors col ON col.id=d.collector_id WHERE x.organization_id=p_org
 ) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.started_at DESC,q.id DESC),'[]') INTO runs FROM (
  SELECT id,organization_id,check_id,collector_id,state,started_at,finished_at,evidence_id FROM public.sowrix_ops_v5_runs WHERE organization_id=p_org ORDER BY started_at DESC,id DESC LIMIT 100) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.starts_at DESC),'[]') INTO windows FROM (
  SELECT * FROM public.sowrix_ops_v5_windows WHERE organization_id=p_org ORDER BY (enabled AND ends_at>now()) DESC,starts_at DESC LIMIT 100) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.id DESC),'[]') INTO timeline FROM (
  SELECT * FROM public.sowrix_ops_v5_timeline WHERE organization_id=p_org AND (p_before IS NULL OR id<p_before) ORDER BY id DESC LIMIT 100) q;
 RETURN jsonb_build_object('organization_id',p_org,'server_time',clock_timestamp(),'checks',checks,'runs',runs,'windows',windows,'timeline',timeline,
  'limits',jsonb_build_object('max_checks',100,'max_tenant_jobs',8,'max_worker_jobs',4,'min_interval_seconds',15));
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v5_unit(text),public.sowrix_ops_v5_thresholds(jsonb),public.sowrix_ops_v5_collector(text),public.sowrix_ops_v5_configure(uuid,uuid,jsonb),public.sowrix_ops_v5_window(uuid,uuid,text,text,uuid,boolean),public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb),public.sowrix_ops_v5_ack(uuid,uuid),public.sowrix_ops_v5_snapshot(uuid,bigint) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v5_configure(uuid,uuid,jsonb),public.sowrix_ops_v5_window(uuid,uuid,text,text,uuid,boolean),public.sowrix_ops_v5_ack(uuid,uuid),public.sowrix_ops_v5_snapshot(uuid,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) TO service_role;

-- Reuse the existing delivery worker and outbox. Preserve the previous claim implementation
-- by OID/name for exact rollback; filter scheduled incidents only, leaving legacy alerts intact.
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v5_prior_claim_alerts()') IS NULL THEN
  ALTER FUNCTION public.sowrix_def_claim_alerts() RENAME TO sowrix_ops_v5_prior_claim_alerts;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v5_prior_claim_alerts() FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.sowrix_def_claim_alerts()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE items jsonb;item jsonb;result jsonb:='[]';c public.sowrix_ops_v5_checks;incident public.sowrix_def_incidents;until_time timestamptz;reason text;
BEGIN
 items:=public.sowrix_ops_v5_prior_claim_alerts();
 FOR item IN SELECT jsonb_array_elements(items) LOOP
  SELECT i.* INTO incident FROM public.sowrix_def_incidents i JOIN public.sowrix_def_outbox q ON q.incident_id=i.id WHERE q.id=(item->>'id')::uuid;
  SELECT * INTO c FROM public.sowrix_ops_v5_checks WHERE organization_id=incident.organization_id AND 'scheduler:'||id::text=incident.rule_key;
  IF c.id IS NULL THEN result:=result||jsonb_build_array(item);CONTINUE; END IF;
  SELECT max(ends_at) INTO until_time FROM public.sowrix_ops_v5_windows WHERE organization_id=c.organization_id AND enabled AND starts_at<=now() AND ends_at>now() AND (asset_id IS NULL OR asset_id=c.asset_id);
  reason:=CASE WHEN incident.status='resolved' THEN 'resolved' WHEN until_time IS NOT NULL THEN 'maintenance'
   WHEN NOT c.enabled THEN 'disabled' WHEN c.last_observed IS NULL OR c.last_observed<now()-greatest(c.interval_seconds*3,45)*interval '1 second' OR c.health='UNKNOWN' THEN 'unavailable' END;
  IF reason IS NULL THEN result:=result||jsonb_build_array(item);CONTINUE; END IF;
  UPDATE public.sowrix_def_outbox SET status=CASE WHEN reason='resolved' THEN 'failed' ELSE 'pending' END,
   attempts=CASE WHEN reason='resolved' THEN 5 ELSE greatest(0,attempts-1) END,
   lease_until=NULL,next_attempt_at=coalesce(until_time,now()+interval '5 minutes') WHERE id=(item->>'id')::uuid;
  INSERT INTO public.sowrix_ops_v5_timeline(organization_id,check_id,event,incident_id,details)
   VALUES(c.organization_id,c.id,'notification_suppressed',incident.id,jsonb_build_object('reason',reason,'outbox_id',item->>'id'));
 END LOOP;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_claim_alerts() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_def_claim_alerts() TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
