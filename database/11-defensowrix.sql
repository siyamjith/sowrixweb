-- Defensowrix 11. Additive migration after SOWRIX release 10.
-- Run in staging first. This file does not provision any platform administrators.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_secure_session_allowed()') IS NULL THEN
  RAISE EXCEPTION 'Install the matching release 10 foundation before Defensowrix 11';
 END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.sowrix_def_platform_admins (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_orgs (
 organization_id uuid PRIMARY KEY REFERENCES public.clients(id),
 kind text NOT NULL DEFAULT 'customer' CHECK (kind IN ('customer','msp')),
 enabled boolean NOT NULL DEFAULT false,
 device_limit integer NOT NULL DEFAULT 100 CHECK(device_limit BETWEEN 1 AND 10000),
 ai_budget_cents integer NOT NULL DEFAULT 0 CHECK(ai_budget_cents BETWEEN 0 AND 100000),
 live_enabled boolean NOT NULL DEFAULT false,
 notification_emails text[] NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_members (
 organization_id uuid NOT NULL REFERENCES public.sowrix_def_orgs(organization_id),
 user_id uuid NOT NULL REFERENCES auth.users(id),
 role text NOT NULL CHECK(role IN ('customer_admin','operator','viewer')),
 live_access boolean NOT NULL DEFAULT false,
 ai_access boolean NOT NULL DEFAULT false,
 enabled boolean NOT NULL DEFAULT true,
 PRIMARY KEY(organization_id,user_id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_delegations (
 msp_id uuid NOT NULL REFERENCES public.sowrix_def_orgs(organization_id),
 organization_id uuid NOT NULL REFERENCES public.sowrix_def_orgs(organization_id),
 capabilities text[] NOT NULL DEFAULT '{read}' CHECK(capabilities <@ ARRAY['read','operate','configure','live','ai']),
 enabled boolean NOT NULL DEFAULT true,
 expires_at timestamptz,
 PRIMARY KEY(msp_id,organization_id), CHECK(msp_id<>organization_id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_sites (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL REFERENCES public.sowrix_def_orgs(organization_id),
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 100), location text NOT NULL DEFAULT '',
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(organization_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_collectors (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 site_id uuid NOT NULL, name text NOT NULL CHECK(length(name) BETWEEN 1 AND 100),
 token_hash text NOT NULL UNIQUE, token_expires_at timestamptz,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','active','revoked')),
 last_seen timestamptz, version text, last_sequence bigint NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(organization_id,site_id) REFERENCES public.sowrix_def_sites(organization_id,id),
 UNIQUE(organization_id,site_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_devices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 site_id uuid NOT NULL, collector_id uuid NOT NULL,
 device_code text NOT NULL DEFAULT ('SWX-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 100),
 kind text NOT NULL CHECK(kind IN ('server','laptop','router','switch','firewall','api','storage','backup','camera','recorder','other')),
 protocol text NOT NULL CHECK(protocol IN ('icmp','tcp','https','prometheus','snmp_exporter','backup_json','onvif','rtsp')),
 target text NOT NULL CHECK(length(target) BETWEEN 1 AND 500),
 settings jsonb NOT NULL DEFAULT '{}' CHECK(jsonb_typeof(settings)='object' AND octet_length(settings::text)<=4096),
 interval_seconds integer NOT NULL DEFAULT 60 CHECK(interval_seconds BETWEEN 15 AND 3600),
 enabled boolean NOT NULL DEFAULT true,
 status text NOT NULL DEFAULT 'unknown' CHECK(status IN ('unknown','up','down','unsupported')),
 last_seen timestamptz, last_observed timestamptz, latest_metrics jsonb NOT NULL DEFAULT '{}',
 latest_message text NOT NULL DEFAULT '', failure_count integer NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(organization_id,id), UNIQUE(organization_id,device_code),
 FOREIGN KEY(organization_id,site_id,collector_id) REFERENCES public.sowrix_def_collectors(organization_id,site_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_samples (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, organization_id uuid NOT NULL, device_id uuid NOT NULL,
 observed_at timestamptz NOT NULL, received_at timestamptz NOT NULL DEFAULT now(),
 status text NOT NULL CHECK(status IN ('up','down','unknown','unsupported')),
 metrics jsonb NOT NULL DEFAULT '{}',
 FOREIGN KEY(organization_id,device_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 UNIQUE(device_id,observed_at)
);
CREATE INDEX IF NOT EXISTS sowrix_def_samples_history ON public.sowrix_def_samples(organization_id,device_id,observed_at DESC);
CREATE INDEX IF NOT EXISTS sowrix_def_samples_retention ON public.sowrix_def_samples(received_at);
CREATE TABLE IF NOT EXISTS public.sowrix_def_rules (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 device_id uuid NOT NULL, name text NOT NULL CHECK(length(name) BETWEEN 1 AND 100),
 metric text NOT NULL CHECK(metric ~ '^[a-z][a-z0-9_]{0,63}$'),
 comparison text NOT NULL CHECK(comparison IN ('gt','lt','eq')),
 threshold numeric NOT NULL, samples_required integer NOT NULL DEFAULT 3 CHECK(samples_required BETWEEN 1 AND 30),
 hits integer NOT NULL DEFAULT 0, enabled boolean NOT NULL DEFAULT true,
 FOREIGN KEY(organization_id,device_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 UNIQUE(organization_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_incidents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 device_id uuid NOT NULL, rule_key text NOT NULL,
 title text NOT NULL, severity text NOT NULL DEFAULT 'warning' CHECK(severity IN ('info','warning','critical')),
 status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','acknowledged','resolved')),
 opened_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 acknowledged_by uuid REFERENCES auth.users(id), resolved_at timestamptz,
 evidence jsonb NOT NULL DEFAULT '{}',
 FOREIGN KEY(organization_id,device_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 UNIQUE(organization_id,id)
);
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_def_incident_dedup ON public.sowrix_def_incidents(device_id,rule_key) WHERE status<>'resolved';
CREATE INDEX IF NOT EXISTS sowrix_def_incident_org ON public.sowrix_def_incidents(organization_id,opened_at DESC);
CREATE TABLE IF NOT EXISTS public.sowrix_def_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL, device_id uuid NOT NULL,
 source_id text NOT NULL CHECK(length(source_id) BETWEEN 1 AND 120),
 observed_at timestamptz NOT NULL, received_at timestamptz NOT NULL DEFAULT now(),
 severity text NOT NULL CHECK(severity IN ('info','warning','critical')),
 source text NOT NULL CHECK(length(source)<=80), message text NOT NULL CHECK(length(message)<=2000),
 FOREIGN KEY(organization_id,device_id) REFERENCES public.sowrix_def_devices(organization_id,id),
 UNIQUE(device_id,source_id)
);
CREATE INDEX IF NOT EXISTS sowrix_def_events_org ON public.sowrix_def_events(organization_id,observed_at DESC);
CREATE TABLE IF NOT EXISTS public.sowrix_def_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, organization_id uuid,
 actor_id uuid, action text NOT NULL, target_id text, details jsonb NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_outbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL,
 incident_id uuid NOT NULL, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','sending','sent','failed')),
 attempts integer NOT NULL DEFAULT 0, next_attempt_at timestamptz NOT NULL DEFAULT now(), lease_until timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(), delivered_at timestamptz,
 UNIQUE(incident_id),
 FOREIGN KEY(organization_id,incident_id) REFERENCES public.sowrix_def_incidents(organization_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_streams (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL, device_id uuid NOT NULL,
 user_id uuid NOT NULL REFERENCES auth.users(id), token_hash text NOT NULL UNIQUE,
 expires_at timestamptz NOT NULL DEFAULT now()+interval '5 minutes', revoked_at timestamptz,
 FOREIGN KEY(organization_id,device_id) REFERENCES public.sowrix_def_devices(organization_id,id)
);
CREATE TABLE IF NOT EXISTS public.sowrix_def_ai_runs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), organization_id uuid NOT NULL, incident_id uuid NOT NULL,
 user_id uuid NOT NULL REFERENCES auth.users(id), reserved_cents integer NOT NULL CHECK(reserved_cents>0),
 actual_cents integer CHECK(actual_cents>=0), status text NOT NULL DEFAULT 'reserved' CHECK(status IN ('reserved','complete','failed')),
 result jsonb, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(organization_id,incident_id) REFERENCES public.sowrix_def_incidents(organization_id,id)
);
-- Session ciphertext can be read only by the server's service role.
CREATE TABLE IF NOT EXISTS public.sowrix_def_sessions (
 token_hash text PRIMARY KEY, user_id uuid NOT NULL REFERENCES auth.users(id),
 encrypted_tokens text NOT NULL, csrf_hash text NOT NULL, expires_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.sowrix_def_platform()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.sowrix_secure_session_allowed() AND public.sowrix_access_role()='super_admin'
  AND EXISTS(SELECT 1 FROM public.sowrix_def_platform_admins WHERE user_id=auth.uid())
$$;
CREATE OR REPLACE FUNCTION public.sowrix_def_can(p_org uuid,p_cap text DEFAULT 'read')
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE allowed boolean:=false;
BEGIN
 IF p_cap NOT IN ('read','operate','configure','members','live','ai') OR NOT public.sowrix_secure_session_allowed() THEN RETURN false; END IF;
 IF public.sowrix_def_platform() THEN RETURN true; END IF;
 IF public.sowrix_access_role() IS DISTINCT FROM 'client' THEN RETURN false; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_orgs d JOIN public.clients c ON c.id=d.organization_id
  WHERE d.organization_id=p_org AND d.enabled AND c.status='active') THEN RETURN false; END IF;
 SELECT EXISTS(SELECT 1 FROM public.sowrix_def_members m JOIN public.sowrix_org_memberships b
  ON b.organization_id=m.organization_id AND b.user_id=m.user_id
  WHERE m.organization_id=p_org AND m.user_id=auth.uid() AND m.enabled AND b.status='active'
  AND (m.role<>'customer_admin' OR (auth.jwt()->>'aal'='aal2' AND EXISTS(SELECT 1 FROM auth.mfa_factors WHERE user_id=auth.uid() AND status::text='verified')))
  AND (p_cap='read' OR (p_cap='operate' AND m.role IN ('customer_admin','operator'))
    OR (p_cap IN ('configure','members') AND m.role='customer_admin')
    OR (p_cap='live' AND m.live_access) OR (p_cap='ai' AND m.ai_access))) INTO allowed;
 IF NOT allowed AND p_cap<>'members' THEN
 SELECT EXISTS(SELECT 1 FROM public.sowrix_def_delegations d
  JOIN public.sowrix_def_orgs o ON o.organization_id=d.msp_id AND o.kind='msp' AND o.enabled
  JOIN public.clients c ON c.id=o.organization_id AND c.status='active'
  JOIN public.sowrix_def_members m ON m.organization_id=d.msp_id AND m.user_id=auth.uid() AND m.enabled
  JOIN public.sowrix_org_memberships b ON b.organization_id=m.organization_id AND b.user_id=m.user_id AND b.status='active'
  WHERE d.organization_id=p_org AND d.enabled AND (d.expires_at IS NULL OR d.expires_at>now()) AND p_cap=ANY(d.capabilities)
  AND auth.jwt()->>'aal'='aal2' AND EXISTS(SELECT 1 FROM auth.mfa_factors WHERE user_id=auth.uid() AND status::text='verified')
  AND (p_cap='read' OR (p_cap='operate' AND m.role IN ('customer_admin','operator'))
   OR (p_cap='configure' AND m.role='customer_admin')
   OR (p_cap='live' AND m.live_access) OR (p_cap='ai' AND m.ai_access))) INTO allowed;
 END IF;
 IF p_cap IN ('configure','members','live','ai') AND (auth.jwt()->>'aal' IS DISTINCT FROM 'aal2' OR NOT EXISTS(SELECT 1 FROM auth.mfa_factors WHERE user_id=auth.uid() AND status::text='verified')) THEN RETURN false; END IF;
 RETURN allowed;
END $$;

CREATE OR REPLACE FUNCTION public.sowrix_def_audit_write(p_org uuid,p_action text,p_target text,p_details jsonb DEFAULT '{}')
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 INSERT INTO public.sowrix_def_audit(organization_id,actor_id,action,target_id,details)
 VALUES(p_org,auth.uid(),p_action,p_target,p_details)
$$;
REVOKE ALL ON FUNCTION public.sowrix_def_audit_write(uuid,text,text,jsonb) FROM PUBLIC,anon,authenticated;

-- All writes use validated RPC operations. Raw table mutation grants are absent.
DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['platform_admins','orgs','members','delegations','sites','collectors','devices','samples','rules','incidents','events','audit','outbox','streams','ai_runs','sessions'] LOOP
  EXECUTE format('ALTER TABLE public.sowrix_def_%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.sowrix_def_%I FROM PUBLIC,anon,authenticated',t);
  EXECUTE format('GRANT ALL ON public.sowrix_def_%I TO service_role',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['sites','devices','samples','rules','incidents','events'] LOOP
  EXECUTE format('DROP POLICY IF EXISTS def_read ON public.sowrix_def_%I',t);
  EXECUTE format('CREATE POLICY def_read ON public.sowrix_def_%I FOR SELECT TO authenticated USING(public.sowrix_def_can(organization_id,''read''))',t);
  EXECUTE format('GRANT SELECT ON public.sowrix_def_%I TO authenticated',t);
 END LOOP;
END $$;
REVOKE ALL ON public.sowrix_def_samples_id_seq,public.sowrix_def_audit_id_seq FROM PUBLIC,anon,authenticated;
GRANT USAGE,SELECT ON public.sowrix_def_samples_id_seq,public.sowrix_def_audit_id_seq TO service_role;

CREATE OR REPLACE FUNCTION public.sowrix_def_bootstrap(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.user_roles WHERE user_id=p_user_id AND role::text='super_admin') THEN
  RAISE EXCEPTION 'Select an existing SOWRIX Super Admin account';
 END IF;
 INSERT INTO public.sowrix_def_platform_admins(user_id) VALUES(p_user_id) ON CONFLICT DO NOTHING;
 PERFORM public.sowrix_def_audit_write(NULL,'platform_bootstrap',p_user_id::text);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_bootstrap(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_bootstrap(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.sowrix_def_request(p_action text,p_org uuid DEFAULT NULL,p_data jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
#variable_conflict use_column
DECLARE result jsonb; v_id uuid; s public.sowrix_def_sites; c public.sowrix_def_collectors;
 d public.sowrix_def_devices; inc public.sowrix_def_incidents; role_name text; target_user uuid;
 secret text; cap text; o public.sowrix_def_orgs; amount integer; spent bigint; allowed_caps text[];
BEGIN
 IF auth.uid() IS NULL OR NOT public.sowrix_secure_session_allowed() THEN
  RAISE EXCEPTION 'Verified active sign-in required' USING ERRCODE='42501';
 END IF;
 IF jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>20000 THEN RAISE EXCEPTION 'Invalid request'; END IF;
 IF p_action='context' THEN
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',x.organization_id,'name',x.organization_name,'kind',x.kind,
   'capabilities',x.capabilities,'live_enabled',x.live_enabled) ORDER BY x.organization_name),'[]') INTO result FROM (
    SELECT o.organization_id,c.organization_name,o.kind,o.live_enabled,
     ARRAY(SELECT k FROM unnest(ARRAY['read','operate','configure','members','live','ai']) k WHERE public.sowrix_def_can(o.organization_id,k)) capabilities
    FROM public.sowrix_def_orgs o JOIN public.clients c ON c.id=o.organization_id
    WHERE public.sowrix_def_can(o.organization_id,'read')
  )x;
  RETURN jsonb_build_object('release',11,'platform_admin',public.sowrix_def_platform(),'organizations',result,
   'requires_mfa',public.sowrix_access_role()<>'client' OR EXISTS(SELECT 1 FROM public.sowrix_def_members WHERE user_id=auth.uid() AND enabled AND role='customer_admin'),
   'role',public.sowrix_access_role(),'user_id',auth.uid(),
   'available_clients',CASE WHEN public.sowrix_def_platform() THEN (SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',organization_name)),'[]') FROM public.clients WHERE status='active') ELSE '[]'::jsonb END);
 END IF;
 IF p_action='organization.config' THEN
  IF NOT public.sowrix_def_platform() THEN RAISE EXCEPTION 'SOWRIX platform administration required' USING ERRCODE='42501'; END IF;
  SELECT to_jsonb(x) INTO result FROM public.sowrix_def_orgs x WHERE organization_id=p_org;
  RETURN coalesce(result,'{}');
 END IF;
 IF p_action IN ('organization.save','delegation.save') THEN
  IF NOT public.sowrix_def_platform() THEN RAISE EXCEPTION 'SOWRIX platform administration required' USING ERRCODE='42501'; END IF;
  PERFORM public.sowrix_require_secure_session(true);
  IF p_action='organization.save' THEN
   IF jsonb_typeof(coalesce(p_data->'notification_emails','[]'))<>'array'
    OR jsonb_array_length(coalesce(p_data->'notification_emails','[]'))>10
    OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(coalesce(p_data->'notification_emails','[]')) e
      WHERE length(e)>254 OR e !~ '^[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
    RAISE EXCEPTION 'Use up to ten valid approved notification email addresses';
   END IF;
   INSERT INTO public.sowrix_def_orgs(organization_id,kind,enabled,device_limit,ai_budget_cents,live_enabled,notification_emails)
   VALUES(p_org,coalesce(p_data->>'kind','customer'),coalesce((p_data->>'enabled')::boolean,true),
    coalesce((p_data->>'device_limit')::integer,100),coalesce((p_data->>'ai_budget_cents')::integer,0),
    coalesce((p_data->>'live_enabled')::boolean,false),
    ARRAY(SELECT jsonb_array_elements_text(coalesce(p_data->'notification_emails','[]'))))
   ON CONFLICT(organization_id) DO UPDATE SET enabled=EXCLUDED.enabled,device_limit=EXCLUDED.device_limit,
    ai_budget_cents=EXCLUDED.ai_budget_cents,live_enabled=EXCLUDED.live_enabled,notification_emails=EXCLUDED.notification_emails;
   -- Kind is immutable once assigned: it is an authorization relationship.
   IF (SELECT kind FROM public.sowrix_def_orgs WHERE organization_id=p_org) IS DISTINCT FROM coalesce(p_data->>'kind','customer') THEN RAISE EXCEPTION 'Organization kind cannot be changed'; END IF;
  ELSE
   IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_orgs WHERE organization_id=(p_data->>'msp_id')::uuid AND kind='msp')
    OR NOT EXISTS(SELECT 1 FROM public.sowrix_def_orgs WHERE organization_id=p_org AND kind='customer') THEN RAISE EXCEPTION 'Select an MSP and a customer'; END IF;
   allowed_caps=ARRAY(SELECT jsonb_array_elements_text(coalesce(p_data->'capabilities','["read"]')));
   INSERT INTO public.sowrix_def_delegations(msp_id,organization_id,capabilities,enabled,expires_at)
   VALUES((p_data->>'msp_id')::uuid,p_org,allowed_caps,coalesce((p_data->>'enabled')::boolean,true),(p_data->>'expires_at')::timestamptz)
   ON CONFLICT(msp_id,organization_id) DO UPDATE SET capabilities=EXCLUDED.capabilities,enabled=EXCLUDED.enabled,expires_at=EXCLUDED.expires_at;
  END IF;
  PERFORM public.sowrix_def_audit_write(p_org,p_action,p_org::text);
  RETURN jsonb_build_object('ok',true);
 END IF;
 cap:=CASE WHEN p_action IN ('site.save','device.save','device.disable','collector.enroll','collector.revoke','rule.save') THEN 'configure'
  WHEN p_action='member.save' THEN 'members'
  WHEN p_action IN ('incident.acknowledge','incident.resolve') THEN 'operate'
  WHEN p_action='stream.create' THEN 'live'
  WHEN p_action IN ('ai.reserve','ai.list') THEN 'ai'
  ELSE 'read' END;
 IF p_org IS NULL OR NOT public.sowrix_def_can(p_org,cap) THEN RAISE EXCEPTION 'Resource not found or access not permitted' USING ERRCODE='42501'; END IF;
 -- Serialize quota changes, not concurrent dashboard reads.
 IF p_action IN ('device.save','collector.enroll','ai.reserve','stream.create') THEN
  SELECT * INTO o FROM public.sowrix_def_orgs WHERE organization_id=p_org FOR UPDATE;
 ELSE
  SELECT * INTO o FROM public.sowrix_def_orgs WHERE organization_id=p_org;
 END IF;
 IF p_action='overview' THEN
  RETURN jsonb_build_object('devices',(SELECT count(*) FROM public.sowrix_def_devices WHERE organization_id=p_org AND enabled),
   'up',(SELECT count(*) FROM public.sowrix_def_devices WHERE organization_id=p_org AND enabled AND status='up' AND last_observed>now()-greatest(interval_seconds*3,180)*interval '1 second'),
   'down',(SELECT count(*) FROM public.sowrix_def_devices WHERE organization_id=p_org AND enabled AND status='down' AND last_observed>now()-greatest(interval_seconds*3,180)*interval '1 second'),
   'incidents',(SELECT count(*) FROM public.sowrix_def_incidents WHERE organization_id=p_org AND status<>'resolved'),
   'collectors',(SELECT count(*) FROM public.sowrix_def_collectors WHERE organization_id=p_org AND status='active' AND last_seen>now()-interval '3 minutes'),
   'sites',(SELECT count(*) FROM public.sowrix_def_sites WHERE organization_id=p_org),
   'ai_budget_cents',o.ai_budget_cents,'device_limit',o.device_limit,'live_enabled',o.live_enabled,
   'retention',jsonb_build_object('samples_hours',24,'events_days',7,'audit_days',180),
   'notification_configured',cardinality(o.notification_emails)>0);
 ELSIF p_action='sites.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name),'[]') INTO result FROM public.sowrix_def_sites x WHERE organization_id=p_org;
 ELSIF p_action='devices.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name),'[]') INTO result FROM (
   SELECT d.*,s.name site_name,CASE WHEN d.last_observed IS NULL OR d.last_observed<now()-greatest(d.interval_seconds*3,180)*interval '1 second' THEN 'unknown' ELSE d.status END effective_status
   FROM public.sowrix_def_devices d JOIN public.sowrix_def_sites s ON s.id=d.site_id WHERE d.organization_id=p_org
   ORDER BY d.name LIMIT 500 OFFSET greatest(0,least(coalesce((p_data->>'offset')::integer,0),10000))
  )x;
 ELSIF p_action='collectors.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT id,site_id,name,status,last_seen,version,created_at FROM public.sowrix_def_collectors WHERE organization_id=p_org ORDER BY created_at DESC
  )x;
 ELSIF p_action='incidents.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT i.*,d.name device_name,d.device_code FROM public.sowrix_def_incidents i JOIN public.sowrix_def_devices d ON d.id=i.device_id
   WHERE i.organization_id=p_org ORDER BY i.opened_at DESC LIMIT 100 OFFSET greatest(0,least(coalesce((p_data->>'offset')::integer,0),10000))
  )x;
 ELSIF p_action='events.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT e.*,d.name device_name FROM public.sowrix_def_events e JOIN public.sowrix_def_devices d ON d.id=e.device_id
   WHERE e.organization_id=p_org ORDER BY e.observed_at DESC LIMIT 100 OFFSET greatest(0,least(coalesce((p_data->>'offset')::integer,0),10000))
  )x;
 ELSIF p_action='rules.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM public.sowrix_def_rules x WHERE organization_id=p_org;
 ELSIF p_action='history' THEN
  SELECT * INTO d FROM public.sowrix_def_devices WHERE id=(p_data->>'device_id')::uuid AND organization_id=p_org;
  IF d.id IS NULL THEN RAISE EXCEPTION 'Device not found'; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.observed_at),'[]') INTO result FROM (
   SELECT observed_at,status,metrics FROM public.sowrix_def_samples WHERE organization_id=p_org AND device_id=d.id ORDER BY observed_at DESC LIMIT 120
  )x;
 ELSIF p_action='members.list' THEN
  IF NOT public.sowrix_def_can(p_org,'members') THEN RAISE EXCEPTION 'Member administration required' USING ERRCODE='42501'; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT m.*,u.email FROM public.sowrix_def_members m JOIN auth.users u ON u.id=m.user_id WHERE m.organization_id=p_org
  )x;
 ELSIF p_action='audit.list' THEN
  IF NOT public.sowrix_def_can(p_org,'members') THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT * FROM public.sowrix_def_audit WHERE organization_id=p_org ORDER BY created_at DESC LIMIT 100
  )x;
 ELSIF p_action='member.save' THEN
  SELECT id INTO target_user FROM auth.users WHERE lower(email)=lower(btrim(p_data->>'email'));
  IF target_user IS NULL OR NOT EXISTS(SELECT 1 FROM public.user_roles WHERE user_id=target_user AND role::text='client') THEN RAISE EXCEPTION 'Provision this client account through SOWRIX first'; END IF;
  IF NOT public.sowrix_def_platform() AND NOT EXISTS(SELECT 1 FROM public.sowrix_org_memberships WHERE user_id=target_user AND organization_id=p_org AND status='active') THEN RAISE EXCEPTION 'SOWRIX must first link this account to the organization'; END IF;
  IF target_user=auth.uid() THEN RAISE EXCEPTION 'Another authorized administrator must change your own access'; END IF;
  role_name=p_data->>'role';
  IF role_name NOT IN ('customer_admin','operator','viewer') OR role_name IS NULL THEN RAISE EXCEPTION 'Invalid customer role'; END IF;
  INSERT INTO public.sowrix_org_memberships(organization_id,user_id,member_role,billing_access) VALUES(p_org,target_user,'member',false) ON CONFLICT DO NOTHING;
  INSERT INTO public.sowrix_def_members(organization_id,user_id,role,enabled,live_access,ai_access)
   VALUES(p_org,target_user,role_name,coalesce((p_data->>'enabled')::boolean,true),coalesce((p_data->>'live_access')::boolean,false),coalesce((p_data->>'ai_access')::boolean,false))
   ON CONFLICT(organization_id,user_id) DO UPDATE SET role=EXCLUDED.role,enabled=EXCLUDED.enabled,live_access=EXCLUDED.live_access,ai_access=EXCLUDED.ai_access;
  v_id=target_user;
 ELSIF p_action='site.save' THEN
  v_id=coalesce((p_data->>'id')::uuid,gen_random_uuid());
  IF EXISTS(SELECT 1 FROM public.sowrix_def_sites WHERE id=v_id AND organization_id<>p_org) THEN RAISE EXCEPTION 'Site not found'; END IF;
  INSERT INTO public.sowrix_def_sites(id,organization_id,name,location) VALUES(v_id,p_org,btrim(p_data->>'name'),left(coalesce(p_data->>'location',''),200))
   ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,location=EXCLUDED.location;
 ELSIF p_action='collector.enroll' THEN
  SELECT * INTO s FROM public.sowrix_def_sites WHERE id=(p_data->>'site_id')::uuid AND organization_id=p_org;
  IF s.id IS NULL THEN RAISE EXCEPTION 'Site not found'; END IF;
  IF (SELECT count(*) FROM public.sowrix_def_collectors WHERE organization_id=p_org AND status<>'revoked')>=100 THEN RAISE EXCEPTION 'Collector limit reached'; END IF;
  secret=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
  INSERT INTO public.sowrix_def_collectors(organization_id,site_id,name,token_hash,token_expires_at)
   VALUES(p_org,s.id,btrim(p_data->>'name'),encode(sha256(convert_to(secret,'UTF8')),'hex'),now()+interval '15 minutes') RETURNING id INTO v_id;
  PERFORM public.sowrix_def_audit_write(p_org,p_action,v_id::text);
  RETURN jsonb_build_object('id',v_id,'enrollment_token',secret,'expires_in_seconds',900);
 ELSIF p_action='collector.revoke' THEN
  UPDATE public.sowrix_def_collectors SET status='revoked' WHERE id=(p_data->>'id')::uuid AND organization_id=p_org RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'Collector not found'; END IF;
 ELSIF p_action='device.save' THEN
  SELECT * INTO c FROM public.sowrix_def_collectors WHERE id=(p_data->>'collector_id')::uuid AND organization_id=p_org AND status<>'revoked';
  IF c.id IS NULL THEN RAISE EXCEPTION 'Collector not found'; END IF;
  v_id=coalesce((p_data->>'id')::uuid,gen_random_uuid());
  IF EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE id=v_id AND organization_id<>p_org) THEN RAISE EXCEPTION 'Device not found'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE id=v_id AND enabled) AND (SELECT count(*) FROM public.sowrix_def_devices WHERE organization_id=p_org AND enabled)>=o.device_limit THEN RAISE EXCEPTION 'Device limit reached'; END IF;
  IF (p_data->'settings')::text ~* '(password|secret|token|authorization)' OR p_data->>'target' ~ '[@?#]' THEN RAISE EXCEPTION 'Keep credentials and query secrets in the collector local secret configuration'; END IF;
  INSERT INTO public.sowrix_def_devices(id,organization_id,site_id,collector_id,name,kind,protocol,target,settings,interval_seconds)
   VALUES(v_id,p_org,c.site_id,c.id,btrim(p_data->>'name'),p_data->>'kind',p_data->>'protocol',p_data->>'target',coalesce(p_data->'settings','{}'),coalesce((p_data->>'interval_seconds')::integer,60))
   ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,kind=EXCLUDED.kind,protocol=EXCLUDED.protocol,target=EXCLUDED.target,settings=EXCLUDED.settings,interval_seconds=EXCLUDED.interval_seconds,collector_id=EXCLUDED.collector_id,site_id=EXCLUDED.site_id,enabled=true,status='unknown',failure_count=0;
 ELSIF p_action='device.disable' THEN
  UPDATE public.sowrix_def_devices SET enabled=false WHERE id=(p_data->>'id')::uuid AND organization_id=p_org RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'Device not found'; END IF;
 ELSIF p_action='rule.save' THEN
  SELECT * INTO d FROM public.sowrix_def_devices WHERE id=(p_data->>'device_id')::uuid AND organization_id=p_org;
  IF d.id IS NULL THEN RAISE EXCEPTION 'Device not found'; END IF;
  v_id=coalesce((p_data->>'id')::uuid,gen_random_uuid());
  IF EXISTS(SELECT 1 FROM public.sowrix_def_rules WHERE id=v_id AND organization_id<>p_org) THEN RAISE EXCEPTION 'Rule not found'; END IF;
  INSERT INTO public.sowrix_def_rules(id,organization_id,device_id,name,metric,comparison,threshold,samples_required,enabled)
   VALUES(v_id,p_org,d.id,btrim(p_data->>'name'),p_data->>'metric',p_data->>'comparison',(p_data->>'threshold')::numeric,coalesce((p_data->>'samples_required')::integer,3),coalesce((p_data->>'enabled')::boolean,true))
   ON CONFLICT(id) DO UPDATE SET device_id=EXCLUDED.device_id,name=EXCLUDED.name,metric=EXCLUDED.metric,comparison=EXCLUDED.comparison,threshold=EXCLUDED.threshold,samples_required=EXCLUDED.samples_required,enabled=EXCLUDED.enabled,hits=0;
  UPDATE public.sowrix_def_incidents SET status='resolved',resolved_at=now(),updated_at=now(),evidence=evidence||'{"resolution":"Rule configuration changed; subsequent observations are evaluated under the new rule."}'::jsonb
   WHERE organization_id=p_org AND rule_key=v_id::text AND status<>'resolved';
 ELSIF p_action='incident.acknowledge' THEN
  UPDATE public.sowrix_def_incidents SET status='acknowledged',acknowledged_by=auth.uid(),updated_at=now()
   WHERE id=(p_data->>'id')::uuid AND organization_id=p_org AND status='open' RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'Open incident not found'; END IF;
 ELSIF p_action='incident.resolve' THEN
  IF length(btrim(coalesce(p_data->>'reason','')))<8 THEN RAISE EXCEPTION 'Enter a resolution reason of at least eight characters'; END IF;
  UPDATE public.sowrix_def_incidents SET status='resolved',resolved_at=now(),updated_at=now(),
   evidence=evidence||jsonb_build_object('manual_resolution',left(p_data->>'reason',500),'resolved_by',auth.uid())
   WHERE id=(p_data->>'id')::uuid AND organization_id=p_org AND status<>'resolved' RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'Active incident not found'; END IF;
 ELSIF p_action='stream.create' THEN
  IF NOT o.live_enabled THEN RAISE EXCEPTION 'Live viewing is not enabled for this organization'; END IF;
  SELECT * INTO d FROM public.sowrix_def_devices WHERE id=(p_data->>'device_id')::uuid AND organization_id=p_org AND kind IN ('camera','recorder') AND enabled;
  IF d.id IS NULL THEN RAISE EXCEPTION 'Camera not found'; END IF;
  IF (SELECT count(*) FROM public.sowrix_def_streams WHERE organization_id=p_org AND revoked_at IS NULL AND expires_at>now())>=4 THEN RAISE EXCEPTION 'Concurrent viewing limit reached'; END IF;
  secret=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
  INSERT INTO public.sowrix_def_streams(organization_id,device_id,user_id,token_hash) VALUES(p_org,d.id,auth.uid(),encode(sha256(convert_to(secret,'UTF8')),'hex')) RETURNING id INTO v_id;
  PERFORM public.sowrix_def_audit_write(p_org,p_action,d.id::text);
  RETURN jsonb_build_object('id',v_id,'token',secret,'path',p_org::text||'/'||d.id::text,'expires_in',300);
 ELSIF p_action='stream.revoke' THEN
  UPDATE public.sowrix_def_streams SET revoked_at=now() WHERE id=(p_data->>'id')::uuid AND organization_id=p_org AND user_id=auth.uid() RETURNING id INTO v_id;
 ELSIF p_action='ai.reserve' THEN
  SELECT * INTO inc FROM public.sowrix_def_incidents WHERE id=(p_data->>'incident_id')::uuid AND organization_id=p_org;
  IF inc.id IS NULL THEN RAISE EXCEPTION 'Incident not found'; END IF;
  amount=greatest(1,least(coalesce((p_data->>'reserve_cents')::integer,10),1000));
  SELECT coalesce(sum(coalesce(actual_cents,reserved_cents)),0) INTO spent FROM public.sowrix_def_ai_runs WHERE organization_id=p_org AND created_at>=date_trunc('month',now());
  IF spent+amount>o.ai_budget_cents THEN RAISE EXCEPTION 'Monthly AI budget reached or not configured'; END IF;
  IF (SELECT count(*) FROM public.sowrix_def_ai_runs WHERE organization_id=p_org AND status='reserved' AND created_at>now()-interval '10 minutes')>=2 THEN RAISE EXCEPTION 'Two investigations are already in progress'; END IF;
  INSERT INTO public.sowrix_def_ai_runs(organization_id,incident_id,user_id,reserved_cents) VALUES(p_org,inc.id,auth.uid(),amount) RETURNING id INTO v_id;
  PERFORM public.sowrix_def_audit_write(p_org,p_action,v_id::text);
  RETURN jsonb_build_object('id',v_id,'incident',to_jsonb(inc));
 ELSIF p_action='ai.list' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
   SELECT id,incident_id,status,result,actual_cents,reserved_cents,created_at FROM public.sowrix_def_ai_runs WHERE organization_id=p_org ORDER BY created_at DESC LIMIT 50
  )x;
 ELSIF p_action='export' THEN
  PERFORM public.sowrix_def_audit_write(p_org,'inventory_export',p_org::text);
  SELECT coalesce(jsonb_agg(jsonb_build_object('device_code',device_code,'name',name,'kind',kind,'status',CASE WHEN last_observed IS NULL OR last_observed<now()-greatest(interval_seconds*3,180)*interval '1 second' THEN 'unknown' ELSE status END,'last_seen',last_seen)),'[]')
   INTO result FROM public.sowrix_def_devices WHERE organization_id=p_org;
 ELSE RAISE EXCEPTION 'Unsupported operation';
 END IF;
 IF result IS NOT NULL THEN RETURN result; END IF;
 PERFORM public.sowrix_def_audit_write(p_org,p_action,v_id::text);
 RETURN jsonb_build_object('ok',true,'id',v_id);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_platform(),public.sowrix_def_can(uuid,text),public.sowrix_def_request(text,uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_def_platform(),public.sowrix_def_can(uuid,text),public.sowrix_def_request(text,uuid,jsonb) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sowrix_def_incident(p_org uuid,p_device uuid,p_key text,p_title text,p_bad boolean,p_evidence jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id uuid;
BEGIN
 IF p_bad THEN
  INSERT INTO public.sowrix_def_incidents(organization_id,device_id,rule_key,title,evidence,severity)
   VALUES(p_org,p_device,p_key,p_title,p_evidence,CASE WHEN p_key LIKE 'security:%' THEN 'critical' ELSE 'warning' END)
   ON CONFLICT(device_id,rule_key) WHERE status<>'resolved' DO UPDATE SET updated_at=now(),evidence=EXCLUDED.evidence RETURNING id INTO v_id;
  INSERT INTO public.sowrix_def_outbox(organization_id,incident_id) VALUES(p_org,v_id) ON CONFLICT DO NOTHING;
 ELSE
  UPDATE public.sowrix_def_incidents SET status='resolved',resolved_at=now(),updated_at=now(),evidence=p_evidence
   WHERE device_id=p_device AND rule_key=p_key AND status<>'resolved';
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_incident(uuid,uuid,text,text,boolean,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_def_collector(p_action text,p_token text,p_data jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.sowrix_def_collectors; d public.sowrix_def_devices; r public.sowrix_def_rules;
 sample jsonb; event jsonb; tm timestamptz; seq bigint; value numeric; bad boolean; secret text; inserted integer; total integer:=0;
BEGIN
 IF length(coalesce(p_token,''))<>64 OR octet_length(p_data::text)>500000 THEN RAISE EXCEPTION 'Invalid collector request' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.sowrix_def_collectors WHERE token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') FOR UPDATE;
 IF c.id IS NULL OR c.status='revoked' OR NOT EXISTS(SELECT 1 FROM public.sowrix_def_orgs o JOIN public.clients cl ON cl.id=o.organization_id WHERE o.organization_id=c.organization_id AND o.enabled AND cl.status='active') THEN RAISE EXCEPTION 'Collector is not authorized' USING ERRCODE='42501'; END IF;
 IF p_action='activate' THEN
  IF c.status<>'pending' OR c.token_expires_at<now() THEN RAISE EXCEPTION 'Enrollment token expired or already used'; END IF;
  secret=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
  UPDATE public.sowrix_def_collectors SET token_hash=encode(sha256(convert_to(secret,'UTF8')),'hex'),token_expires_at=NULL,status='active',last_seen=now(),version=left(p_data->>'version',40) WHERE id=c.id;
  PERFORM public.sowrix_def_audit_write(c.organization_id,'collector_activated',c.id::text);
  RETURN jsonb_build_object('collector_id',c.id,'organization_id',c.organization_id,'site_id',c.site_id,'credential',secret);
 END IF;
 IF c.status<>'active' THEN RAISE EXCEPTION 'Enrollment required'; END IF;
 UPDATE public.sowrix_def_collectors SET last_seen=now(),version=left(coalesce(p_data->>'version',version),40) WHERE id=c.id;
 IF p_action='config' THEN
  RETURN jsonb_build_object('collector_id',c.id,'organization_id',c.organization_id,'last_sequence',c.last_sequence,
   'devices',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'kind',kind,'protocol',protocol,'target',target,'settings',settings,'interval_seconds',interval_seconds)),'[]') FROM public.sowrix_def_devices WHERE collector_id=c.id AND enabled),
   'live_devices',(SELECT coalesce(jsonb_agg(DISTINCT st.device_id),'[]') FROM public.sowrix_def_streams st JOIN public.sowrix_def_devices dev ON dev.id=st.device_id JOIN public.sowrix_def_orgs o ON o.organization_id=st.organization_id WHERE dev.collector_id=c.id AND dev.enabled AND o.live_enabled AND st.expires_at>now() AND st.revoked_at IS NULL));
 END IF;
 IF p_action<>'ingest' THEN RAISE EXCEPTION 'Unsupported collector operation'; END IF;
 seq=(p_data->>'sequence')::bigint;
 IF seq IS NULL OR seq<1 THEN RAISE EXCEPTION 'Sequence required'; END IF;
 IF seq<=c.last_sequence THEN RETURN jsonb_build_object('accepted',0,'duplicate',true); END IF;
 IF jsonb_typeof(p_data->'samples')<>'array' OR jsonb_array_length(p_data->'samples')>100 THEN RAISE EXCEPTION 'At most 100 samples per batch'; END IF;
 FOR sample IN SELECT jsonb_array_elements(p_data->'samples') LOOP
  SELECT * INTO d FROM public.sowrix_def_devices WHERE id=(sample->>'device_id')::uuid AND collector_id=c.id AND organization_id=c.organization_id AND enabled FOR UPDATE;
  IF d.id IS NULL THEN RAISE EXCEPTION 'Device does not belong to this collector'; END IF;
  tm=(sample->>'observed_at')::timestamptz;
  IF tm IS NULL OR tm>now()+interval '2 minutes' OR tm<now()-interval '24 hours' THEN RAISE EXCEPTION 'Observation timestamp outside supported spool window'; END IF;
  IF sample->>'status' NOT IN ('up','down','unknown','unsupported') OR sample->>'status' IS NULL THEN RAISE EXCEPTION 'Invalid observation status'; END IF;
  IF jsonb_typeof(sample->'metrics')<>'object' OR octet_length((sample->'metrics')::text)>8192
   OR (SELECT count(*) FROM jsonb_object_keys(sample->'metrics'))>100
   OR EXISTS(SELECT 1 FROM jsonb_each(sample->'metrics') e WHERE e.key !~ '^[a-z][a-z0-9_]{0,63}$' OR jsonb_typeof(e.value)<>'number') THEN RAISE EXCEPTION 'Metrics must be bounded numeric fields'; END IF;
  INSERT INTO public.sowrix_def_samples(organization_id,device_id,observed_at,status,metrics)
   VALUES(c.organization_id,d.id,tm,sample->>'status',sample->'metrics') ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS inserted=ROW_COUNT;
  IF inserted=0 THEN CONTINUE; END IF;
  total=total+1;
  -- Historical spool data must not overwrite current state or create new live alerts.
  IF d.last_observed IS NOT NULL AND tm<=d.last_observed THEN CONTINUE; END IF;
  IF d.last_observed IS NULL OR tm-d.last_observed>greatest(d.interval_seconds*3,180)*interval '1 second' THEN UPDATE public.sowrix_def_rules SET hits=0 WHERE device_id=d.id; END IF;
  UPDATE public.sowrix_def_devices SET status=sample->>'status',last_seen=now(),last_observed=tm,latest_metrics=sample->'metrics',
   latest_message=left(coalesce(sample->>'message',''),200),failure_count=CASE WHEN sample->>'status'='down' THEN CASE WHEN tm-last_observed<=greatest(interval_seconds*3,180)*interval '1 second' THEN failure_count+1 ELSE 1 END ELSE 0 END
   WHERE id=d.id RETURNING * INTO d;
  IF tm<now()-greatest(d.interval_seconds*3,180)*interval '1 second' THEN CONTINUE; END IF;
  IF d.status='up' OR (d.status='down' AND d.failure_count>=3) THEN
   PERFORM public.sowrix_def_incident(c.organization_id,d.id,'availability',d.name||' is unavailable',d.failure_count>=3,jsonb_build_object('observed_at',tm,'status',d.status,'consecutive_failures',d.failure_count));
  END IF;
  FOR r IN SELECT * FROM public.sowrix_def_rules WHERE device_id=d.id AND enabled LOOP
   IF NOT sample->'metrics' ? r.metric OR d.status<>'up' THEN UPDATE public.sowrix_def_rules SET hits=0 WHERE id=r.id; CONTINUE; END IF;
   value=(sample->'metrics'->>r.metric)::numeric;
   bad=CASE r.comparison WHEN 'gt' THEN value>r.threshold WHEN 'lt' THEN value<r.threshold ELSE value=r.threshold END;
   UPDATE public.sowrix_def_rules SET hits=CASE WHEN bad THEN least(hits+1,samples_required) ELSE 0 END WHERE id=r.id RETURNING * INTO r;
   IF NOT bad OR r.hits>=r.samples_required THEN
    PERFORM public.sowrix_def_incident(c.organization_id,d.id,r.id::text,r.name,bad,jsonb_build_object('observed_at',tm,'metric',r.metric,'value',value,'threshold',r.threshold));
   END IF;
  END LOOP;
 END LOOP;
 IF p_data ? 'events' THEN
  IF jsonb_typeof(p_data->'events')<>'array' OR jsonb_array_length(p_data->'events')>100 THEN RAISE EXCEPTION 'At most 100 events per batch'; END IF;
  FOR event IN SELECT jsonb_array_elements(p_data->'events') LOOP
   SELECT * INTO d FROM public.sowrix_def_devices WHERE id=(event->>'device_id')::uuid AND collector_id=c.id AND enabled;
   IF d.id IS NULL THEN RAISE EXCEPTION 'Event device not found'; END IF;
   tm=(event->>'observed_at')::timestamptz;
   IF tm IS NULL OR tm>now()+interval '2 minutes' OR tm<now()-interval '24 hours' THEN RAISE EXCEPTION 'Event timestamp outside window'; END IF;
   INSERT INTO public.sowrix_def_events(organization_id,device_id,source_id,observed_at,severity,source,message)
    VALUES(c.organization_id,d.id,event->>'source_id',tm,event->>'severity',event->>'source',event->>'message') ON CONFLICT DO NOTHING;
   GET DIAGNOSTICS inserted=ROW_COUNT;
   IF inserted>0 AND event->>'severity'='critical' AND tm>now()-interval '5 minutes' THEN
    PERFORM public.sowrix_def_incident(c.organization_id,d.id,'security:'||left(event->>'source',80),
      d.name||': critical security event received',true,
      jsonb_build_object('source_id',event->>'source_id','source',event->>'source','message',event->>'message','observed_at',tm,'untrusted_log_content',true));
   END IF;
  END LOOP;
 END IF;
 UPDATE public.sowrix_def_collectors SET last_sequence=seq WHERE id=c.id;
 RETURN jsonb_build_object('accepted',total,'sequence',seq);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_collector(text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_collector(text,text,jsonb) TO service_role;

-- Verify a viewer against its original provider session as well as current permissions.
CREATE OR REPLACE FUNCTION public.sowrix_def_stream_check(p_id uuid,p_user uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.sowrix_def_streams;
BEGIN
 IF p_user IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Stream owner mismatch' USING ERRCODE='42501'; END IF;
 SELECT * INTO s FROM public.sowrix_def_streams WHERE id=p_id AND user_id=p_user AND expires_at>now() AND revoked_at IS NULL;
 IF s.id IS NULL OR NOT public.sowrix_def_can(s.organization_id,'live')
  OR NOT EXISTS(SELECT 1 FROM public.sowrix_def_orgs WHERE organization_id=s.organization_id AND enabled AND live_enabled)
  OR NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices d JOIN public.sowrix_def_collectors c ON c.id=d.collector_id AND c.status='active'
    JOIN public.clients cl ON cl.id=d.organization_id AND cl.status='active' WHERE d.id=s.device_id AND d.enabled) THEN RAISE EXCEPTION 'Stream access expired or revoked' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('id',s.id,'organization_id',s.organization_id,'device_id',s.device_id);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_stream_check(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_def_stream_check(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_def_maintenance()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE n integer;
BEGIN
 DELETE FROM public.sowrix_def_samples WHERE id IN (SELECT id FROM public.sowrix_def_samples WHERE received_at<now()-interval '24 hours' LIMIT 20000);
 GET DIAGNOSTICS n=ROW_COUNT;
 DELETE FROM public.sowrix_def_events WHERE id IN (SELECT id FROM public.sowrix_def_events WHERE received_at<now()-interval '7 days' LIMIT 20000);
 DELETE FROM public.sowrix_def_sessions WHERE expires_at<now();
 DELETE FROM public.sowrix_def_streams WHERE expires_at<now()-interval '1 day';
 DELETE FROM public.sowrix_def_audit WHERE created_at<now()-interval '180 days';
 UPDATE public.sowrix_def_ai_runs SET status='failed',actual_cents=reserved_cents,result='{"error":"Investigation interrupted; reserved budget retained until reconciliation."}' WHERE status='reserved' AND created_at<now()-interval '15 minutes';
 RETURN jsonb_build_object('samples_pruned',n);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_maintenance() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_maintenance() TO service_role;
CREATE OR REPLACE FUNCTION public.sowrix_def_claim_alerts()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ids uuid[]; result jsonb;
BEGIN
 SELECT array_agg(id) INTO ids FROM (
  SELECT q.id FROM public.sowrix_def_outbox q
  JOIN public.sowrix_def_orgs o ON o.organization_id=q.organization_id AND o.enabled AND cardinality(o.notification_emails)>0
  JOIN public.clients c ON c.id=o.organization_id AND c.status='active'
  WHERE q.next_attempt_at<=now() AND q.attempts<5
   AND (q.status='pending' OR (q.status='sending' AND q.lease_until<now()))
  ORDER BY q.created_at LIMIT 10 FOR UPDATE OF q SKIP LOCKED
 )x;
 UPDATE public.sowrix_def_outbox SET status='sending',attempts=attempts+1,lease_until=now()+interval '5 minutes' WHERE id=ANY(ids);
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',q.id,'attempts',q.attempts,'recipients',o.notification_emails,'title',i.title)),'[]')
 INTO result FROM public.sowrix_def_outbox q JOIN public.sowrix_def_orgs o ON o.organization_id=q.organization_id
 JOIN public.sowrix_def_incidents i ON i.id=q.incident_id WHERE q.id=ANY(ids);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_def_claim_alerts() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_def_claim_alerts() TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

