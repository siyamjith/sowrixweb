-- Additive read-only operational projection. No customer/evidence row mutations.
BEGIN;
DO $$ BEGIN IF to_regprocedure('public.sowrix_ops_v10_query(uuid,jsonb)') IS NULL THEN RAISE EXCEPTION 'Install V10 first'; END IF; END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v101_monitor(p_org uuid,p_filter jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE site uuid:=(p_filter->>'site_id')::uuid;lo timestamptz:=(p_filter->>'from_at')::timestamptz;hi timestamptz:=(p_filter->>'to_at')::timestamptz;
 ids uuid[];assets uuid[];checks jsonb;runs jsonb;collectors jsonb;windows jsonb;timeline jsonb;sites jsonb;stats jsonb;ct integer;rt integer;colt integer;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'read');
 IF jsonb_typeof(p_filter)<>'object' OR (SELECT count(*) FROM jsonb_object_keys(p_filter))<>9 OR NOT(p_filter ?& ARRAY['site_id','search','health','offset','limit','run_offset','collector_offset','from_at','to_at'])
 OR p_filter->>'search' IS NULL OR length(p_filter->>'search')>100 OR p_filter->>'search'~'[[:cntrl:]]'
 OR p_filter->>'health' IS NULL OR p_filter->>'health' NOT IN ('','UP','DOWN','DEGRADED','UNKNOWN','STALE','MAINTENANCE','DISABLED')
 OR lo IS NULL OR hi IS NULL OR NOT isfinite(lo) OR NOT isfinite(hi) OR hi<=lo OR hi-lo>interval '31 days' OR hi>now()+interval '2 minutes'
 OR p_filter->>'from_at'!~'(Z|[+-][0-9]{2}:[0-9]{2})$' OR p_filter->>'to_at'!~'(Z|[+-][0-9]{2}:[0-9]{2})$'
 THEN RAISE EXCEPTION 'Invalid monitoring dashboard filter' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_each(p_filter) WHERE key IN ('offset','run_offset','collector_offset','limit') AND (jsonb_typeof(value)<>'number' OR value::text!~'^[0-9]+$'))
 OR (p_filter->>'limit')::integer NOT BETWEEN 1 AND 100 OR (p_filter->>'offset')::integer NOT BETWEEN 0 AND 100000 OR (p_filter->>'run_offset')::integer NOT BETWEEN 0 AND 100000 OR (p_filter->>'collector_offset')::integer NOT BETWEEN 0 AND 100000
 THEN RAISE EXCEPTION 'Invalid dashboard page' USING ERRCODE='22023'; END IF;
 IF site IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sowrix_def_sites s WHERE s.organization_id=p_org AND s.id=site) THEN RAISE EXCEPTION 'Site not authorized' USING ERRCODE='42501'; END IF;
 SELECT coalesce(array_agg(c.id),ARRAY[]::uuid[]),coalesce(array_agg(c.asset_id),ARRAY[]::uuid[]) INTO ids,assets
 FROM public.sowrix_ops_v5_checks c JOIN public.sowrix_ops_v10_assets a ON a.check_id=c.id AND a.organization_id=c.organization_id
 WHERE c.organization_id=p_org AND (site IS NULL OR a.site_id=site) AND strpos(lower(a.name),lower(p_filter->>'search'))>0 AND (p_filter->>'health'='' OR a.health=p_filter->>'health');
 ct:=cardinality(ids);
 SELECT count(*) INTO rt FROM public.sowrix_ops_v5_runs r WHERE r.organization_id=p_org AND r.check_id=ANY(ids) AND r.started_at>=lo AND r.started_at<=hi;
 SELECT count(*) INTO colt FROM public.sowrix_def_collectors c WHERE c.organization_id=p_org AND (site IS NULL OR c.site_id=site);
 SELECT jsonb_build_object('checks',ct,'pending',count(*) FILTER(WHERE c.enabled AND a.health NOT IN ('DISABLED','MAINTENANCE') AND c.next_due<=now() AND (c.lease_until IS NULL OR c.lease_until<=now())),
 'running',count(*) FILTER(WHERE c.lease_until>now()),'down',count(*) FILTER(WHERE a.health='DOWN'),'degraded',count(*) FILTER(WHERE a.health='DEGRADED'),'stale',count(*) FILTER(WHERE a.health='STALE'),'unknown',count(*) FILTER(WHERE a.health='UNKNOWN'),'maintenance',count(*) FILTER(WHERE a.health='MAINTENANCE'),
 'retries',count(*) FILTER(WHERE c.retries>0),'completed_runs',(SELECT count(*) FROM public.sowrix_ops_v5_runs r WHERE r.organization_id=p_org AND r.check_id=ANY(ids) AND r.started_at BETWEEN lo AND hi AND r.state='completed'),
 'failed_runs',(SELECT count(*) FROM public.sowrix_ops_v5_runs r WHERE r.organization_id=p_org AND r.check_id=ANY(ids) AND r.started_at BETWEEN lo AND hi AND r.state IN ('timeout','unavailable','expired')),
 'cancelled_runs',(SELECT count(*) FROM public.sowrix_ops_v5_runs r WHERE r.organization_id=p_org AND r.check_id=ANY(ids) AND r.started_at BETWEEN lo AND hi AND r.state='cancelled'),
 'collectors',colt,'connected_collectors',(SELECT count(*) FROM public.sowrix_def_collectors c WHERE c.organization_id=p_org AND (site IS NULL OR c.site_id=site) AND c.status='active' AND c.last_seen>=now()-interval '60 seconds')) INTO stats
 FROM public.sowrix_ops_v5_checks c JOIN public.sowrix_ops_v10_assets a ON a.organization_id=c.organization_id AND a.check_id=c.id WHERE c.organization_id=p_org AND c.id=ANY(ids);
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.name,q.id),'[]') INTO checks FROM (
 SELECT c.id,c.organization_id,c.asset_id,a.site_id,a.name,a.site_name,a.health,a.collector_health,a.collector_id,c.enabled,c.interval_seconds,c.timeout_seconds,c.next_due,c.last_observed,c.last_finished,c.last_outcome,c.retries,c.failures,c.recoveries,c.lease_until,c.evidence_id
 FROM public.sowrix_ops_v5_checks c JOIN public.sowrix_ops_v10_assets a ON a.organization_id=c.organization_id AND a.check_id=c.id WHERE c.organization_id=p_org AND c.id=ANY(ids)
 ORDER BY a.name,c.id LIMIT (p_filter->>'limit')::integer OFFSET (p_filter->>'offset')::integer) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.started_at DESC,q.id DESC),'[]') INTO runs FROM (
 SELECT r.id,r.organization_id,c.asset_id,d.site_id,d.name,r.check_id,r.collector_id,r.state,r.started_at,r.finished_at,r.evidence_id
 FROM public.sowrix_ops_v5_runs r JOIN public.sowrix_ops_v5_checks c ON c.id=r.check_id AND c.organization_id=r.organization_id JOIN public.sowrix_def_devices d ON d.id=c.asset_id AND d.organization_id=c.organization_id
 WHERE r.organization_id=p_org AND r.check_id=ANY(ids) AND r.started_at BETWEEN lo AND hi ORDER BY r.started_at DESC,r.id DESC LIMIT (p_filter->>'limit')::integer OFFSET (p_filter->>'run_offset')::integer) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.name,q.id),'[]') INTO collectors FROM (
 SELECT c.id,c.organization_id,c.site_id,c.name,s.name site_name,c.last_seen,CASE WHEN c.status<>'active' THEN 'DISABLED' WHEN c.last_seen IS NULL OR c.last_seen<now()-interval '60 seconds' THEN 'STALE' ELSE 'CONNECTED' END health
 FROM public.sowrix_def_collectors c JOIN public.sowrix_def_sites s ON s.organization_id=c.organization_id AND s.id=c.site_id WHERE c.organization_id=p_org AND (site IS NULL OR c.site_id=site)
 ORDER BY c.name,c.id LIMIT (p_filter->>'limit')::integer OFFSET (p_filter->>'collector_offset')::integer) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.starts_at DESC,q.id),'[]') INTO windows FROM (
 SELECT w.id,w.organization_id,w.asset_id,w.starts_at,w.ends_at,w.enabled FROM public.sowrix_ops_v5_windows w WHERE w.organization_id=p_org AND (w.asset_id IS NULL OR w.asset_id=ANY(assets)) ORDER BY w.starts_at DESC,w.id LIMIT 100) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.id DESC),'[]') INTO timeline FROM (
 SELECT t.id,t.organization_id,t.check_id,t.at,t.event,t.evidence_id,t.incident_id FROM public.sowrix_ops_v5_timeline t WHERE t.organization_id=p_org AND t.check_id=ANY(ids) AND t.at BETWEEN lo AND hi ORDER BY t.id DESC LIMIT 100) q;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.name,q.id),'[]') INTO sites FROM (SELECT s.id,s.organization_id,s.name FROM public.sowrix_def_sites s WHERE s.organization_id=p_org ORDER BY s.name,s.id LIMIT 10000) q;
 RETURN jsonb_build_object('organization_id',p_org,'server_time',clock_timestamp(),'summary',stats,'checks',checks,'runs',runs,'collectors',collectors,'windows',windows,'timeline',timeline,'sites',sites,
 'check_total',ct,'run_total',rt,'collector_total',colt,'limits',jsonb_build_object('max_tenant_jobs',8,'max_worker_jobs',4,'max_retry_backoff_steps',3,'timeline_limit',100,'window_limit',100,'site_limit',10000),
 'scheduler_health_scope','Database due times and job leases only; worker process heartbeat unavailable','read_only',true);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v101_monitor(uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v101_monitor(uuid,jsonb) TO authenticated;
COMMIT;
