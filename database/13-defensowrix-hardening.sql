-- Release 13: additive hardening. Apply after 11 and 12, in staging first.
-- Preserves existing sites, device IDs, roles, and monitoring history.
BEGIN;
DO $$
DECLARE predicate text;
BEGIN
 IF to_regprocedure('public.sowrix_client_invite_authorize(uuid,boolean)') IS NULL
 OR to_regprocedure('public.sowrix_def_request(text,uuid,jsonb)') IS NULL THEN
  RAISE EXCEPTION 'Install matching releases 11 and 12 before release 13';
 END IF;
 -- Capture the previously manual client/Super Admin role compatibility repair.
 SELECT pg_get_expr(conbin,conrelid) INTO predicate FROM pg_constraint
 WHERE conrelid='public.user_roles'::regclass AND conname='user_roles_role_check' AND contype='c';
 IF predicate IS NOT NULL AND (position('client' in predicate)=0 OR position('super_admin' in predicate)=0) THEN
  ALTER TABLE public.user_roles DROP CONSTRAINT user_roles_role_check;
  EXECUTE 'ALTER TABLE public.user_roles ADD CONSTRAINT user_roles_role_check CHECK (('
    ||predicate||') OR role::text IN (''client'',''super_admin''))';
 END IF;
 IF to_regprocedure('public.sowrix_def_request_v12(text,uuid,jsonb)') IS NULL THEN
  ALTER FUNCTION public.sowrix_def_request(text,uuid,jsonb) RENAME TO sowrix_def_request_v12;
 END IF;
 IF to_regprocedure('public.sowrix_def_collector_v11(text,text,jsonb)') IS NULL THEN
  ALTER FUNCTION public.sowrix_def_collector(text,text,jsonb) RENAME TO sowrix_def_collector_v11;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_request_v12(text,uuid,jsonb),public.sowrix_def_collector_v11(text,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;

-- Lock by tenant and normalized name; reject new duplicates without deleting old ones.
CREATE OR REPLACE FUNCTION public.sowrix_def_site_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 NEW.name=btrim(NEW.name);
 IF TG_OP='UPDATE' AND NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
  RAISE EXCEPTION 'A site cannot be moved to another organization';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(NEW.organization_id::text||':'||lower(NEW.name),0));
 IF EXISTS(SELECT 1 FROM public.sowrix_def_sites s WHERE s.organization_id=NEW.organization_id
  AND lower(btrim(s.name))=lower(NEW.name) AND s.id<>NEW.id) THEN
  IF TG_OP='INSERT' OR lower(NEW.name) IS DISTINCT FROM lower(btrim(OLD.name)) THEN
   RAISE EXCEPTION 'A site with this name already exists in this organization. Edit the existing site.' USING ERRCODE='23505';
  END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_site_guard() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS sowrix_def_site_guard ON public.sowrix_def_sites;
CREATE TRIGGER sowrix_def_site_guard BEFORE INSERT OR UPDATE ON public.sowrix_def_sites
 FOR EACH ROW EXECUTE FUNCTION public.sowrix_def_site_guard();

ALTER TABLE public.sowrix_def_events ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}';
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.sowrix_def_events'::regclass AND conname='sowrix_def_event_metadata') THEN
  ALTER TABLE public.sowrix_def_events ADD CONSTRAINT sowrix_def_event_metadata
   CHECK(jsonb_typeof(metadata)='object' AND octet_length(metadata::text)<=4096);
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS sowrix_def_events_source_time ON public.sowrix_def_events(organization_id,source,observed_at DESC,id);
CREATE INDEX IF NOT EXISTS sowrix_def_audit_org_time ON public.sowrix_def_audit(organization_id,created_at DESC,id);

-- Local integration metadata remains untrusted evidence, never instructions.
CREATE OR REPLACE FUNCTION public.sowrix_def_collector(p_action text,p_token text,p_data jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e jsonb; m jsonb; result jsonb; cid uuid;
BEGIN
 IF jsonb_typeof(p_data) IS DISTINCT FROM 'object' OR octet_length(p_data::text)>500000 THEN RAISE EXCEPTION 'Invalid collector request'; END IF;
 IF p_data ? 'events' THEN
  IF jsonb_typeof(p_data->'events') IS DISTINCT FROM 'array' OR jsonb_array_length(p_data->'events')>100 THEN RAISE EXCEPTION 'At most 100 events per batch'; END IF;
  FOR e IN SELECT jsonb_array_elements(p_data->'events') LOOP
   m=coalesce(e->'metadata','{}');
   IF jsonb_typeof(m) IS DISTINCT FROM 'object' OR octet_length(m::text)>4096
    OR EXISTS(SELECT 1 FROM jsonb_object_keys(m) k WHERE k NOT IN ('rule_id','category','technique_ids','integration','action','untrusted')) THEN RAISE EXCEPTION 'Invalid event metadata'; END IF;
   IF m ? 'technique_ids' THEN
    IF jsonb_typeof(m->'technique_ids') IS DISTINCT FROM 'array' OR jsonb_array_length(m->'technique_ids')>20
     OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(m->'technique_ids') t WHERE t !~ '^T[0-9]{4}(\.[0-9]{3})?$') THEN RAISE EXCEPTION 'Invalid ATT&CK technique IDs'; END IF;
   END IF;
   IF EXISTS(SELECT 1 FROM jsonb_each(m) v WHERE v.key IN ('rule_id','category','integration','action')
     AND (jsonb_typeof(v.value)<>'string' OR length(v.value::text)>300)) THEN RAISE EXCEPTION 'Invalid integration metadata'; END IF;
  END LOOP;
 END IF;
 result=public.sowrix_def_collector_v11(p_action,p_token,p_data);
 IF p_action='ingest' AND NOT coalesce((result->>'duplicate')::boolean,false) THEN
  SELECT id INTO cid FROM public.sowrix_def_collectors WHERE token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex');
  FOR e IN SELECT jsonb_array_elements(coalesce(p_data->'events','[]')) LOOP
   UPDATE public.sowrix_def_events ev SET metadata=coalesce(e->'metadata','{}')||'{"untrusted":true}'::jsonb
    FROM public.sowrix_def_devices d WHERE d.id=ev.device_id AND d.collector_id=cid
    AND ev.device_id=(e->>'device_id')::uuid AND ev.source_id=e->>'source_id' AND ev.metadata='{}';
  END LOOP;
 END IF;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_collector(text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_collector(text,text,jsonb) TO service_role;

-- Browser-callable operations. Never accept executable SQL, SPL, KQL or commands.
CREATE OR REPLACE FUNCTION public.sowrix_def_request(p_action text,p_org uuid DEFAULT NULL,p_data jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
#variable_conflict use_variable
DECLARE result jsonb; q text; severity text; src text; technique text; dev uuid;
 start_at timestamptz; end_at timestamptz; take integer; skip integer; v_id uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT public.sowrix_secure_session_allowed() THEN RAISE EXCEPTION 'Verified active sign-in required' USING ERRCODE='42501'; END IF;
 IF p_action IS NULL OR jsonb_typeof(p_data) IS DISTINCT FROM 'object' OR octet_length(p_data::text)>20000 THEN RAISE EXCEPTION 'Invalid request'; END IF;
 IF p_action IN ('ai.reserve','stream.create') THEN RAISE EXCEPTION 'Use the authorized gateway endpoint' USING ERRCODE='42501'; END IF;
 IF p_action='context' THEN
  RETURN public.sowrix_def_request_v12(p_action,p_org,p_data)||'{"release":13}'::jsonb;
 END IF;
 IF p_action IN ('events.search','operations.status','audit.list','notification.retry') THEN
  IF p_org IS NULL OR NOT public.sowrix_def_can(p_org,'read') THEN RAISE EXCEPTION 'Resource not found or access not permitted' USING ERRCODE='42501'; END IF;
  IF p_action IN ('operations.status','notification.retry') AND NOT public.sowrix_def_can(p_org,'configure') THEN RAISE EXCEPTION 'Configuration permission required' USING ERRCODE='42501'; END IF;
  IF p_action='events.search' THEN
   IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_data) k WHERE k NOT IN ('query','severity','source','technique_id','device_id','from','to','limit','offset')) THEN RAISE EXCEPTION 'Unsupported search filter. Use the structured filters.'; END IF;
   q=coalesce(p_data->>'query','');severity=nullif(p_data->>'severity','');src=nullif(p_data->>'source','');technique=nullif(p_data->>'technique_id','');dev=nullif(p_data->>'device_id','')::uuid;
   IF length(q)>200 OR length(src)>80 OR (severity IS NOT NULL AND severity NOT IN ('info','warning','critical'))
    OR (technique IS NOT NULL AND technique !~ '^T[0-9]{4}(\.[0-9]{3})?$') THEN RAISE EXCEPTION 'Invalid event filter'; END IF;
   start_at=coalesce(nullif(p_data->>'from','')::timestamptz,now()-interval '7 days');
   end_at=coalesce(nullif(p_data->>'to','')::timestamptz,now()+interval '2 minutes');
   IF end_at<start_at OR end_at-start_at>interval '31 days' THEN RAISE EXCEPTION 'Choose a time range of at most 31 days'; END IF;
   take=greatest(1,least(coalesce((p_data->>'limit')::integer,100),100));skip=greatest(0,least(coalesce((p_data->>'offset')::integer,0),10000));
   SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.observed_at DESC,x.id),'[]') INTO result FROM (
    SELECT e.*,d.name device_name,d.device_code FROM public.sowrix_def_events e
    JOIN public.sowrix_def_devices d ON d.organization_id=e.organization_id AND d.id=e.device_id
    WHERE e.organization_id=p_org AND e.observed_at BETWEEN start_at AND end_at
     AND (severity IS NULL OR e.severity=severity) AND (src IS NULL OR e.source=src)
     AND (dev IS NULL OR e.device_id=dev) AND (technique IS NULL OR e.metadata->'technique_ids' ? technique)
     AND (q='' OR strpos(lower(e.message||' '||e.source||' '||d.name||' '||d.device_code||' '||e.metadata::text),lower(q))>0)
    ORDER BY e.observed_at DESC,e.id LIMIT take OFFSET skip
   ) x;
   PERFORM public.sowrix_def_audit_write(p_org,'events.search',NULL,jsonb_build_object('results',jsonb_array_length(result)));
   RETURN result;
  ELSIF p_action='audit.list' THEN
   IF NOT public.sowrix_def_can(p_org,'members') THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
   SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC,x.id DESC),'[]') INTO result FROM (
    SELECT * FROM public.sowrix_def_audit WHERE organization_id=p_org ORDER BY created_at DESC,id DESC
    LIMIT 100 OFFSET greatest(0,least(coalesce((p_data->>'offset')::integer,0),10000))
   ) x;
   RETURN result;
  ELSIF p_action='notification.retry' THEN
   UPDATE public.sowrix_def_outbox SET status='pending',attempts=0,next_attempt_at=now(),lease_until=NULL
    WHERE organization_id=p_org AND id=(p_data->>'id')::uuid AND status='failed' RETURNING id INTO v_id;
   IF v_id IS NULL THEN RAISE EXCEPTION 'Failed notification not found'; END IF;
   PERFORM public.sowrix_def_audit_write(p_org,p_action,v_id::text);
   RETURN jsonb_build_object('ok',true);
  ELSE
   RETURN jsonb_build_object('release',13,
    'duplicate_site_groups',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (
      SELECT min(name) name,count(*) count FROM public.sowrix_def_sites WHERE organization_id=p_org GROUP BY lower(btrim(name)) HAVING count(*)>1) x),
    'stale_collectors',(SELECT count(*) FROM public.sowrix_def_collectors WHERE organization_id=p_org AND status='active' AND (last_seen IS NULL OR last_seen<now()-interval '3 minutes')),
    'notifications',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (SELECT q.id,q.incident_id,q.status,q.attempts,q.created_at,q.next_attempt_at,q.delivered_at,i.title
      FROM public.sowrix_def_outbox q JOIN public.sowrix_def_incidents i ON i.organization_id=q.organization_id AND i.id=q.incident_id
      WHERE q.organization_id=p_org ORDER BY q.created_at DESC LIMIT 30)x),
    'retention',jsonb_build_object('samples_hours',24,'events_days',7,'audit_days',180),
    'boundary','Configuration checks do not certify production security. Hosted isolation, restore and device tests remain required.');
  END IF;
 END IF;
 RETURN public.sowrix_def_request_v12(p_action,p_org,p_data);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_request(text,uuid,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_def_request(text,uuid,jsonb) TO authenticated;

-- Only the server can reserve provider spending or create a media secret.
-- Claims come from a previously Auth-verified, encrypted server session.
-- The private implementation still rechecks Auth session, MFA and current roles.
CREATE OR REPLACE FUNCTION public.sowrix_def_internal_request(p_action text,p_org uuid,p_data jsonb,p_claims jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb; old_claims text:=current_setting('request.jwt.claims',true);
 old_sub text:=current_setting('request.jwt.claim.sub',true); old_role text:=current_setting('request.jwt.claim.role',true);
BEGIN
 IF p_action NOT IN ('ai.reserve','stream.create') OR p_action IS NULL
  OR p_claims->>'role' IS DISTINCT FROM 'authenticated' OR nullif(p_claims->>'sub','') IS NULL
  OR coalesce((p_claims->>'exp')::numeric,0)<extract(epoch FROM now())
  OR jsonb_typeof(p_data) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Invalid trusted request' USING ERRCODE='42501'; END IF;
 PERFORM set_config('request.jwt.claims',p_claims::text,true),set_config('request.jwt.claim.sub',p_claims->>'sub',true),set_config('request.jwt.claim.role','authenticated',true);
 result=public.sowrix_def_request_v12(p_action,p_org,p_data);
 PERFORM set_config('request.jwt.claims',coalesce(old_claims,''),true),set_config('request.jwt.claim.sub',coalesce(old_sub,''),true),set_config('request.jwt.claim.role',coalesce(old_role,''),true);
 RETURN result;
EXCEPTION WHEN OTHERS THEN
 PERFORM set_config('request.jwt.claims',coalesce(old_claims,''),true),set_config('request.jwt.claim.sub',coalesce(old_sub,''),true),set_config('request.jwt.claim.role',coalesce(old_role,''),true);
 RAISE;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_internal_request(text,uuid,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_internal_request(text,uuid,jsonb,jsonb) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
