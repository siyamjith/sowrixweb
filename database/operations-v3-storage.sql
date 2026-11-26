-- V3 additive persistence: archives are evidence references, not live authorization.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v2_context(uuid)') IS NULL OR to_regprocedure('public.sowrix_ops_v2_ingest(text,jsonb)') IS NULL THEN
  RAISE EXCEPTION 'Install V2 security migration first';
 END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.sowrix_ops_v3_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 organization_id uuid NOT NULL REFERENCES public.sowrix_def_orgs(organization_id),
 device_id uuid NOT NULL,
 kind text NOT NULL CHECK(kind IN ('engineer_session','engineer_evidence','engineer_approval_record','soc_event','soc_finding','soc_case','endpoint_inventory','endpoint_telemetry')),
 source_key text NOT NULL CHECK(source_key ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,119}$'),
 observed_at timestamptz NOT NULL CHECK(isfinite(observed_at)),
 summary text NOT NULL CHECK(length(btrim(summary)) BETWEEN 1 AND 500 AND octet_length(summary)<=2000),
 attributes jsonb NOT NULL DEFAULT '{}' CHECK(jsonb_typeof(attributes)='object' AND octet_length(attributes::text)<=8192),
 parent_id uuid,
 actor_id uuid NOT NULL REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT now(),
 provenance text NOT NULL DEFAULT 'manual_archive' CHECK(provenance='manual_archive'),
 UNIQUE(organization_id,device_id,id), UNIQUE(organization_id,kind,source_key),
 FOREIGN KEY(organization_id,device_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 FOREIGN KEY(organization_id,device_id,parent_id) REFERENCES public.sowrix_ops_v3_records(organization_id,device_id,id),
 CHECK((kind IN ('engineer_evidence','engineer_approval_record','soc_finding','endpoint_telemetry'))=(parent_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS sowrix_ops_v3_record_history ON public.sowrix_ops_v3_records(organization_id,kind,created_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS sowrix_ops_v3_record_asset ON public.sowrix_ops_v3_records(organization_id,device_id,created_at DESC);
ALTER TABLE public.sowrix_ops_v3_records ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_ops_v3_records FROM PUBLIC,anon,authenticated,service_role;
-- No direct client or service-role table permissions, even on rollback.
CREATE OR REPLACE FUNCTION public.sowrix_ops_v3_require(p_org uuid,p_cap text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR p_org IS NULL OR NOT EXISTS (
  SELECT 1 FROM public.sowrix_def_orgs o JOIN public.clients c ON c.id=o.organization_id
  WHERE o.organization_id=p_org AND o.enabled AND c.status='active')
 OR NOT coalesce(public.sowrix_def_can(p_org,'read'),false)
 OR NOT coalesce(public.sowrix_def_can(p_org,p_cap),false) THEN
  RAISE EXCEPTION 'Resource not found or access not permitted' USING ERRCODE='42501';
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v3_require(uuid,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v3_append(p_org uuid,p_device uuid,p_kind text,p_source_key text,p_observed_at timestamptz,p_summary text,p_attributes jsonb,p_parent uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.sowrix_ops_v3_records; parent_kind text;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'operate');
 IF p_kind IS NULL OR p_kind NOT IN ('engineer_session','engineer_evidence','engineer_approval_record','soc_event','soc_finding','soc_case','endpoint_inventory','endpoint_telemetry')
 OR p_source_key IS NULL OR p_source_key !~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,119}$'
 OR p_observed_at IS NULL OR NOT isfinite(p_observed_at) OR p_observed_at>now()+interval '2 minutes'
 OR p_summary IS NULL OR length(btrim(p_summary)) NOT BETWEEN 1 AND 500 OR octet_length(p_summary)>2000
 OR jsonb_typeof(p_attributes) IS DISTINCT FROM 'object' OR octet_length(p_attributes::text)>8192
 OR (p_kind IN ('engineer_evidence','engineer_approval_record','soc_finding','endpoint_telemetry')) IS DISTINCT FROM (p_parent IS NOT NULL) THEN
  RAISE EXCEPTION 'Invalid archive record' USING ERRCODE='22023';
 END IF;
 IF (SELECT count(*) FROM jsonb_object_keys(p_attributes))>32 OR EXISTS(SELECT 1 FROM jsonb_each(p_attributes) a WHERE a.key !~ '^[a-z][a-z0-9_]{0,63}$' OR a.key ~ '(password|secret|token|credential|private_key|authorization|cookie)' OR CASE jsonb_typeof(a.value) WHEN 'string' THEN length(a.value #>> '{}')>500 WHEN 'number' THEN abs(a.value::text::numeric)>1e15 WHEN 'boolean' THEN false ELSE true END) THEN
  RAISE EXCEPTION 'Invalid archive attributes' USING ERRCODE='22023';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE organization_id=p_org AND id=p_device) THEN
  RAISE EXCEPTION 'Resource not found or access not permitted' USING ERRCODE='42501';
 END IF;
 IF p_parent IS NOT NULL THEN
  SELECT kind INTO parent_kind FROM public.sowrix_ops_v3_records WHERE organization_id=p_org AND device_id=p_device AND id=p_parent;
  IF parent_kind IS NULL THEN RAISE EXCEPTION 'Resource not found or access not permitted' USING ERRCODE='42501'; END IF;
  IF parent_kind IS DISTINCT FROM (CASE WHEN p_kind IN ('engineer_evidence','engineer_approval_record') THEN 'engineer_session' WHEN p_kind='soc_finding' THEN 'soc_event' ELSE 'endpoint_inventory' END) THEN
   RAISE EXCEPTION 'Invalid parent record type' USING ERRCODE='22023';
  END IF;
 END IF;
 INSERT INTO public.sowrix_ops_v3_records(organization_id,device_id,kind,source_key,observed_at,summary,attributes,parent_id,actor_id)
 VALUES(p_org,p_device,p_kind,p_source_key,p_observed_at,btrim(p_summary),p_attributes,p_parent,auth.uid())
 ON CONFLICT(organization_id,kind,source_key) DO NOTHING RETURNING * INTO r;
 IF r.id IS NULL THEN
  SELECT * INTO r FROM public.sowrix_ops_v3_records WHERE organization_id=p_org AND kind=p_kind AND source_key=p_source_key;
  IF r.id IS NULL OR r.device_id IS DISTINCT FROM p_device OR r.observed_at IS DISTINCT FROM p_observed_at OR r.summary IS DISTINCT FROM btrim(p_summary) OR r.attributes IS DISTINCT FROM p_attributes OR r.parent_id IS DISTINCT FROM p_parent THEN
   RAISE EXCEPTION 'Archive source key conflict' USING ERRCODE='22023';
  END IF;
  RETURN jsonb_build_object('record',to_jsonb(r),'duplicate',true);
 END IF;
 PERFORM public.sowrix_def_audit_write(p_org,'ops_v3_archive_append',r.id::text,jsonb_build_object('kind',p_kind,'provenance','manual_archive'));
 RETURN jsonb_build_object('record',to_jsonb(r),'duplicate',false);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v3_append(uuid,uuid,text,text,timestamptz,text,jsonb,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v3_append(uuid,uuid,text,text,timestamptz,text,jsonb,uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v3_list(p_org uuid,p_kind text,p_limit integer,p_before_at timestamptz,p_before_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE items jsonb;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'read');
 IF p_kind IS NULL OR p_kind NOT IN ('engineer_session','engineer_evidence','engineer_approval_record','soc_event','soc_finding','soc_case','endpoint_inventory','endpoint_telemetry') OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
 OR (p_before_at IS NULL) IS DISTINCT FROM (p_before_id IS NULL) OR (p_before_at IS NOT NULL AND NOT isfinite(p_before_at)) THEN
  RAISE EXCEPTION 'Invalid archive query' USING ERRCODE='22023';
 END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.created_at DESC,q.id DESC),'[]'::jsonb) INTO items FROM (
  SELECT * FROM public.sowrix_ops_v3_records WHERE organization_id=p_org AND kind=p_kind
   AND (p_before_at IS NULL OR (created_at,id)<(p_before_at,p_before_id)) ORDER BY created_at DESC,id DESC LIMIT p_limit
 ) q;
 RETURN jsonb_build_object('organization_id',p_org,'kind',p_kind,'records',items);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v3_list(uuid,text,integer,timestamptz,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v3_list(uuid,text,integer,timestamptz,uuid) TO authenticated;
COMMIT;
