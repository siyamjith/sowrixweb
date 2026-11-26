-- Additive V4 evidence ledger; run only in isolated fixtures until separately approved.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v3_require(uuid,text)') IS NULL THEN
  RAISE EXCEPTION 'Install V3 first';
 END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v4_sources (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 organization_id uuid NOT NULL REFERENCES public.sowrix_def_orgs(organization_id),
 asset_id uuid NOT NULL, category text NOT NULL CHECK(category IN ('monitoring','engineer','soc','endpoint')),
 actor_id uuid NOT NULL REFERENCES auth.users(id), label text NOT NULL CHECK(length(label) BETWEEN 1 AND 100),
 enabled boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(organization_id,asset_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 UNIQUE(organization_id,id), UNIQUE(organization_id,asset_id,category,actor_id,label)
);
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v4_evidence (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 asset_id uuid NOT NULL, source_id uuid NOT NULL, collector_id uuid,
 actor_id uuid REFERENCES auth.users(id), source_key text NOT NULL,
 category text NOT NULL CHECK(category IN ('monitoring','engineer','soc','endpoint')),
 observed_at timestamptz NOT NULL CHECK(isfinite(observed_at)),
 ingested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 document jsonb NOT NULL CHECK(jsonb_typeof(document)='object' AND octet_length(document::text)<=16000),
 integrity_hash text NOT NULL CHECK(integrity_hash ~ '^[0-9a-f]{64}$'),
 FOREIGN KEY(organization_id,asset_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 UNIQUE(organization_id,asset_id,id), UNIQUE(organization_id,source_id,source_key),
 CHECK((collector_id IS NULL)<>(actor_id IS NULL))
);
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v4_relationships (
 organization_id uuid NOT NULL, asset_id uuid NOT NULL, child_id uuid NOT NULL, parent_id uuid NOT NULL,
 PRIMARY KEY(child_id,parent_id), CHECK(child_id<>parent_id),
 FOREIGN KEY(organization_id,asset_id,child_id) REFERENCES public.sowrix_ops_v4_evidence(organization_id,asset_id,id),
 FOREIGN KEY(organization_id,asset_id,parent_id) REFERENCES public.sowrix_ops_v4_evidence(organization_id,asset_id,id)
);
CREATE INDEX IF NOT EXISTS sowrix_ops_v4_history ON public.sowrix_ops_v4_evidence(organization_id,ingested_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS sowrix_ops_v4_asset_history ON public.sowrix_ops_v4_evidence(organization_id,asset_id,ingested_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS sowrix_ops_v4_parent_history ON public.sowrix_ops_v4_relationships(organization_id,parent_id);
ALTER TABLE public.sowrix_ops_v4_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_ops_v4_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_ops_v4_relationships ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_ops_v4_sources,public.sowrix_ops_v4_evidence,public.sowrix_ops_v4_relationships FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v4_source(p_org uuid,p_asset uuid,p_category text,p_actor uuid,p_label text,p_enabled boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.sowrix_ops_v4_sources;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'configure');
 IF p_category IS NULL OR p_category NOT IN ('monitoring','engineer','soc','endpoint') OR p_actor IS NULL
 OR p_label IS NULL OR length(btrim(p_label)) NOT BETWEEN 1 AND 100 OR p_enabled IS NULL THEN
  RAISE EXCEPTION 'Invalid source binding' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE organization_id=p_org AND id=p_asset AND enabled)
 OR NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor) THEN
  RAISE EXCEPTION 'Resource not found or access not permitted' USING ERRCODE='42501'; END IF;
 INSERT INTO public.sowrix_ops_v4_sources(organization_id,asset_id,category,actor_id,label,enabled)
 VALUES(p_org,p_asset,p_category,p_actor,btrim(p_label),p_enabled)
 ON CONFLICT(organization_id,asset_id,category,actor_id,label) DO UPDATE SET enabled=excluded.enabled RETURNING * INTO s;
 PERFORM public.sowrix_def_audit_write(p_org,'ops_v4_source_binding',s.id::text,jsonb_build_object('enabled',p_enabled,'actor_id',p_actor));
 RETURN to_jsonb(s);
END $$;

-- Also validate direct provider callers; gateway validation is not a security boundary for SQL.
CREATE OR REPLACE FUNCTION public.sowrix_ops_v4_validate(p jsonb)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE m record; parent jsonb; stamp timestamptz;
BEGIN
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR octet_length(p::text)>16000 THEN
  RAISE EXCEPTION 'Invalid evidence' USING ERRCODE='22023'; END IF;
 IF NOT (p ?& ARRAY['schema_version','organization_id','asset_id','source_id','source_key','category','observation_type','observed_at','status','measurements','confidence','methodology','provenance','parents','archive_id','attributes'])
 OR (SELECT count(*) FROM jsonb_object_keys(p))<>16 OR p->'schema_version' IS DISTINCT FROM '1'::jsonb THEN
  RAISE EXCEPTION 'Invalid evidence schema' USING ERRCODE='22023'; END IF;
 FOR m IN SELECT key,value FROM jsonb_each(p) WHERE key IN ('organization_id','asset_id','source_id') LOOP
  IF jsonb_typeof(m.value) IS DISTINCT FROM 'string' OR (m.value #>> '{}') !~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' THEN
   RAISE EXCEPTION 'Invalid identifier' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF jsonb_typeof(p->'category') IS DISTINCT FROM 'string' OR p->>'category' NOT IN ('monitoring','engineer','soc','endpoint')
 OR jsonb_typeof(p->'source_key') IS DISTINCT FROM 'string' OR p->>'source_key' !~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,119}$'
 OR jsonb_typeof(p->'observation_type') IS DISTINCT FROM 'string' OR p->>'observation_type' !~ '^[a-z][a-z0-9_]{0,63}$'
 OR jsonb_typeof(p->'status') IS DISTINCT FROM 'string' OR p->>'status' NOT IN ('PASS','WARNING','FAIL','UNKNOWN','OBSERVED','UNAVAILABLE','REVIEW_REQUIRED')
 OR jsonb_typeof(p->'confidence') IS DISTINCT FROM 'string' OR p->>'confidence' NOT IN ('UNKNOWN','LOW')
 OR jsonb_typeof(p->'provenance') IS DISTINCT FROM 'string' OR p->>'provenance' NOT IN ('imported_claim','inferred_finding','authenticated_collector')
 OR jsonb_typeof(p->'methodology') IS DISTINCT FROM 'string' OR length(p->>'methodology') NOT BETWEEN 1 AND 500 OR p->>'methodology' ~ '[[:cntrl:]]'
 OR jsonb_typeof(p->'observed_at') IS DISTINCT FROM 'string' OR p->>'observed_at' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-](0[0-9]|1[0-5]):[0-5][0-9])$' THEN
  RAISE EXCEPTION 'Invalid evidence fields' USING ERRCODE='22023'; END IF;
 stamp:=(p->>'observed_at')::timestamptz;
 IF NOT isfinite(stamp) OR stamp<'1970-01-01Z'::timestamptz OR stamp>now()+interval '2 minutes' THEN
  RAISE EXCEPTION 'Invalid observation time' USING ERRCODE='22023'; END IF;
 IF jsonb_typeof(p->'parents') IS DISTINCT FROM 'array' OR jsonb_array_length(p->'parents')>16 THEN
  RAISE EXCEPTION 'Invalid parents' USING ERRCODE='22023'; END IF;
 FOR parent IN SELECT jsonb_array_elements(p->'parents') LOOP
  IF jsonb_typeof(parent) IS DISTINCT FROM 'string' OR parent #>> '{}' !~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' THEN
   RAISE EXCEPTION 'Invalid parent' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF (SELECT count(DISTINCT value) FROM jsonb_array_elements(p->'parents'))<>jsonb_array_length(p->'parents')
 OR (p->>'provenance'='inferred_finding' AND (jsonb_array_length(p->'parents')=0 OR p->>'status'<>'REVIEW_REQUIRED'))
 OR (p->>'provenance' IN ('imported_claim','authenticated_collector') AND p->>'confidence'<>'UNKNOWN') THEN
  RAISE EXCEPTION 'Invalid evidence confidence or lineage' USING ERRCODE='22023'; END IF;
 IF p->'archive_id'<>'null'::jsonb AND (jsonb_typeof(p->'archive_id') IS DISTINCT FROM 'string' OR p->>'archive_id' !~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$') THEN
  RAISE EXCEPTION 'Invalid archive reference' USING ERRCODE='22023'; END IF;
 IF jsonb_typeof(p->'attributes') IS DISTINCT FROM 'object' OR (SELECT count(*) FROM jsonb_object_keys(p->'attributes'))>32 THEN
  RAISE EXCEPTION 'Invalid attributes' USING ERRCODE='22023'; END IF;
 FOR m IN SELECT key,value FROM jsonb_each(p->'attributes') LOOP
  IF m.key !~ '^[a-z][a-z0-9_]{0,63}$' OR m.key ~ '(password|secret|token|credential|private_key|authorization|cookie)' OR (CASE jsonb_typeof(m.value)
   WHEN 'string' THEN length(m.value #>> '{}')>500 OR (m.value #>> '{}') ~ '[[:cntrl:]]'
   WHEN 'number' THEN abs(m.value::text::numeric)>1e15 WHEN 'boolean' THEN false ELSE true END) THEN
   RAISE EXCEPTION 'Invalid attribute' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF jsonb_typeof(p->'measurements') IS DISTINCT FROM 'object' OR (SELECT count(*) FROM jsonb_object_keys(p->'measurements'))>100 THEN
  RAISE EXCEPTION 'Invalid measurements' USING ERRCODE='22023'; END IF;
 FOR m IN SELECT key,value FROM jsonb_each(p->'measurements') LOOP
  IF m.key !~ '^[a-z][a-z0-9_]{0,63}$' OR m.key ~ '(password|secret|token|credential|private_key|authorization|cookie)'
  OR jsonb_typeof(m.value) IS DISTINCT FROM 'object' OR NOT (m.value ?& ARRAY['value','unit','status']) OR (SELECT count(*) FROM jsonb_object_keys(m.value))<>3
  OR jsonb_typeof(m.value->'unit') IS DISTINCT FROM 'string' OR m.value->>'unit' NOT IN ('percent','ms','bytes','count','ratio','code','unspecified')
  OR jsonb_typeof(m.value->'status') IS DISTINCT FROM 'string' OR m.value->>'status' NOT IN ('OBSERVED','UNAVAILABLE') THEN
   RAISE EXCEPTION 'Invalid measurement' USING ERRCODE='22023'; END IF;
  IF m.value->>'status'='UNAVAILABLE' THEN
   IF m.value->'value' IS DISTINCT FROM 'null'::jsonb OR p->>'status'='PASS' THEN RAISE EXCEPTION 'Unavailable is not healthy' USING ERRCODE='22023'; END IF;
  ELSE
   IF jsonb_typeof(m.value->'value') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Invalid numeric measurement' USING ERRCODE='22023'; END IF;
   IF abs((m.value->>'value')::numeric)>1e15 OR (m.value->>'unit'='percent' AND (m.value->>'value')::numeric NOT BETWEEN 0 AND 100)
   OR p->>'status' IN ('UNKNOWN','UNAVAILABLE') THEN RAISE EXCEPTION 'Invalid numeric observation' USING ERRCODE='22023'; END IF;
  END IF;
 END LOOP;
END $$;

-- Private writer. SQL constructs authoritative ingestion identity and hash.
CREATE OR REPLACE FUNCTION public.sowrix_ops_v4_write(p jsonb,p_actor uuid,p_collector uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.sowrix_ops_v4_evidence; doc jsonb; parent jsonb; org uuid; asset uuid; source uuid;
BEGIN
 PERFORM public.sowrix_ops_v4_validate(p);
 org:=(p->>'organization_id')::uuid; asset:=(p->>'asset_id')::uuid; source:=(p->>'source_id')::uuid;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE organization_id=org AND id=asset AND enabled) THEN
  RAISE EXCEPTION 'Resource not found or access not permitted' USING ERRCODE='42501'; END IF;
 IF p->'archive_id'<>'null'::jsonb AND (p->>'provenance'<>'imported_claim' OR NOT EXISTS(
  SELECT 1 FROM public.sowrix_ops_v3_records WHERE organization_id=org AND device_id=asset AND id=(p->>'archive_id')::uuid)) THEN
  RAISE EXCEPTION 'Archive reference not permitted' USING ERRCODE='42501'; END IF;
 FOR parent IN SELECT jsonb_array_elements(p->'parents') LOOP
  IF NOT EXISTS(SELECT 1 FROM public.sowrix_ops_v4_evidence WHERE organization_id=org AND asset_id=asset AND id=(parent #>> '{}')::uuid) THEN
   RAISE EXCEPTION 'Parent evidence not permitted' USING ERRCODE='42501'; END IF;
 END LOOP;
 doc:=p || jsonb_build_object('observed_at',to_char((p->>'observed_at')::timestamptz AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"+00:00"'),
                             'authorized_source_identity',coalesce(p_actor,p_collector),'collector_id',p_collector);
 INSERT INTO public.sowrix_ops_v4_evidence(organization_id,asset_id,source_id,collector_id,actor_id,source_key,category,observed_at,document,integrity_hash)
 VALUES(org,asset,source,p_collector,p_actor,p->>'source_key',p->>'category',(p->>'observed_at')::timestamptz,doc,encode(sha256(convert_to(doc::text,'UTF8')),'hex'))
 ON CONFLICT(organization_id,source_id,source_key) DO NOTHING RETURNING * INTO r;
 IF r.id IS NULL THEN
  SELECT * INTO r FROM public.sowrix_ops_v4_evidence WHERE organization_id=org AND source_id=source AND source_key=p->>'source_key';
  IF r.id IS NULL OR r.document IS DISTINCT FROM doc THEN RAISE EXCEPTION 'Evidence key conflict' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('record',to_jsonb(r),'duplicate',true);
 END IF;
 INSERT INTO public.sowrix_ops_v4_relationships SELECT org,asset,r.id,(value #>> '{}')::uuid FROM jsonb_array_elements(p->'parents');
 INSERT INTO public.sowrix_def_audit(organization_id,actor_id,action,target_id,details)
 VALUES(org,p_actor,'ops_v4_evidence',r.id::text,jsonb_build_object('collector_id',p_collector,'integrity_hash',r.integrity_hash,'provenance',p->>'provenance'));
 RETURN jsonb_build_object('record',to_jsonb(r),'duplicate',false);
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v4_append(p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.sowrix_ops_v4_sources; org uuid;
BEGIN
 PERFORM public.sowrix_ops_v4_validate(p_data);
 org:=(p_data->>'organization_id')::uuid;
 PERFORM public.sowrix_ops_v3_require(org,'operate');
 SELECT * INTO s FROM public.sowrix_ops_v4_sources WHERE organization_id=org AND id=(p_data->>'source_id')::uuid FOR SHARE;
 IF s.id IS NULL OR NOT s.enabled OR s.actor_id<>auth.uid() OR s.asset_id<>(p_data->>'asset_id')::uuid
 OR s.category<>p_data->>'category' OR p_data->>'provenance'='authenticated_collector' THEN
  RAISE EXCEPTION 'Source not authorized' USING ERRCODE='42501'; END IF;
 RETURN public.sowrix_ops_v4_write(p_data,auth.uid(),NULL);
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_ops_v4_list(p_org uuid,p_asset uuid,p_limit integer,p_before_at timestamptz,p_before_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE records jsonb;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'read');
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR (p_before_at IS NULL)<>(p_before_id IS NULL)
 OR (p_before_at IS NOT NULL AND NOT isfinite(p_before_at)) THEN RAISE EXCEPTION 'Invalid page' USING ERRCODE='22023'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.ingested_at DESC,q.id DESC),'[]'::jsonb) INTO records FROM (
  SELECT * FROM public.sowrix_ops_v4_evidence WHERE organization_id=p_org AND (p_asset IS NULL OR asset_id=p_asset)
  AND (p_before_at IS NULL OR (ingested_at,id)<(p_before_at,p_before_id)) ORDER BY ingested_at DESC,id DESC LIMIT p_limit
 ) q;
 RETURN jsonb_build_object('organization_id',p_org,'records',records);
END $$;

-- Existing collector credential, V2 checks, legacy samples and ledger commit atomically.
CREATE OR REPLACE FUNCTION public.sowrix_ops_v4_ingest(p_token text,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb; c public.sowrix_def_collectors; s jsonb; measures jsonb; doc jsonb;
BEGIN
 result:=public.sowrix_ops_v2_ingest(p_token,p_data);
 IF coalesce((result->>'duplicate')::boolean,false) THEN RETURN result; END IF;
 SELECT * INTO c FROM public.sowrix_def_collectors WHERE token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex');
 FOR s IN SELECT jsonb_array_elements(p_data->'samples') LOOP
  SELECT coalesce(jsonb_object_agg(key,jsonb_build_object('value',value,'unit',CASE WHEN key IN ('cpu_percent','memory_percent','disk_percent') THEN 'percent' WHEN key LIKE '%_ms' THEN 'ms' ELSE 'unspecified' END,'status','OBSERVED')),'{}'::jsonb)
   INTO measures FROM jsonb_each(s->'metrics');
  -- Failed/unavailable sample states are never upgraded by measurements.
  IF s->>'status' IN ('unknown','unsupported') THEN measures:='{}'; END IF;
  doc:=jsonb_build_object('schema_version',1,'organization_id',c.organization_id,'asset_id',s->>'device_id','source_id',c.id,
   'source_key',(s->>'device_id')||':'||to_char((s->>'observed_at')::timestamptz AT TIME ZONE 'UTC','YYYYMMDD"T"HH24MISSUS"Z"'),'category','monitoring','observation_type','collector_sample',
   'observed_at',s->>'observed_at','status',CASE s->>'status' WHEN 'up' THEN 'PASS' WHEN 'down' THEN 'FAIL' WHEN 'unsupported' THEN 'UNAVAILABLE' ELSE 'UNKNOWN' END,
   'measurements',measures,'confidence','UNKNOWN','methodology','Authenticated collector report; measurement truth is not independently attested',
   'provenance','authenticated_collector','parents','[]'::jsonb,'archive_id',NULL,'attributes','{}'::jsonb);
  PERFORM public.sowrix_ops_v4_write(doc,NULL,c.id);
 END LOOP;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v4_validate(jsonb),public.sowrix_ops_v4_write(jsonb,uuid,uuid),public.sowrix_ops_v4_source(uuid,uuid,text,uuid,text,boolean),public.sowrix_ops_v4_append(jsonb),public.sowrix_ops_v4_list(uuid,uuid,integer,timestamptz,uuid),public.sowrix_ops_v4_ingest(text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v4_source(uuid,uuid,text,uuid,text,boolean),public.sowrix_ops_v4_append(jsonb),public.sowrix_ops_v4_list(uuid,uuid,integer,timestamptz,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v4_ingest(text,jsonb) TO service_role;
COMMIT;
