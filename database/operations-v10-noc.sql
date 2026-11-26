-- Read-only NOC projection. No polling, customer row changes or historical copies.
BEGIN;
DO $$ BEGIN IF to_regprocedure('public.sowrix_ops_v9_snapshot(uuid,uuid,timestamptz,uuid)') IS NULL THEN RAISE EXCEPTION 'Install V9 first'; END IF; END $$;
CREATE INDEX IF NOT EXISTS sowrix_ops_v10_inventory ON public.sowrix_def_devices(organization_id,site_id,name,id);
CREATE INDEX IF NOT EXISTS sowrix_ops_v10_live_evidence ON public.sowrix_ops_v4_evidence(organization_id,asset_id,observed_at DESC,id DESC) WHERE document->>'provenance'='authenticated_collector' AND document->>'observation_type'='collector_sample';
CREATE OR REPLACE VIEW public.sowrix_ops_v10_assets AS
SELECT d.organization_id,d.id asset_id,d.name,d.kind,d.site_id,s.name site_name,d.collector_id,
 coalesce(h.configuration->>'category',CASE WHEN f.asset_id IS NOT NULL THEN 'firewall' WHEN e.asset_id IS NOT NULL THEN CASE WHEN e.configuration->>'device_class'='server' THEN 'server' ELSE 'endpoint' END WHEN n.asset_id IS NOT NULL THEN 'network' WHEN d.kind='api' THEN 'service' ELSE d.kind END) category,
 CASE WHEN NOT d.enabled OR c.enabled=false OR h.enabled=false OR e.enabled=false OR f.enabled=false OR n.enabled=false THEN 'DISABLED'
 WHEN EXISTS(SELECT 1 FROM public.sowrix_ops_v5_windows w WHERE w.organization_id=d.organization_id AND w.enabled AND w.starts_at<=now() AND w.ends_at>now() AND (w.asset_id IS NULL OR w.asset_id=d.id)) THEN 'MAINTENANCE'
 WHEN c.id IS NULL OR c.last_observed IS NULL THEN 'UNKNOWN'
 WHEN c.last_observed<now()-greatest(c.interval_seconds*3,45)*interval '1 second' THEN 'STALE'
 ELSE CASE WHEN c.health IN ('UP','DOWN','DEGRADED','UNKNOWN','STALE','MAINTENANCE','DISABLED') THEN c.health ELSE 'UNKNOWN' END END health,
 CASE WHEN col.status<>'active' THEN 'DISABLED' WHEN col.last_seen IS NULL OR col.last_seen<now()-interval '60 seconds' THEN 'STALE' ELSE 'CONNECTED' END collector_health,
 col.last_seen collector_last_seen,c.id check_id,c.interval_seconds,c.next_due,c.last_observed,c.last_finished,c.last_outcome,c.lease_until,c.evidence_id,
 coalesce(h.configuration,e.configuration,f.configuration,n.configuration,'{}'::jsonb) capability,
 (SELECT max(ev.observed_at) FROM public.sowrix_ops_v4_evidence ev WHERE ev.organization_id=d.organization_id AND ev.asset_id=d.id AND ev.document->>'provenance'='authenticated_collector' AND ev.document->>'observation_type'='collector_sample' AND ev.document->>'status'='PASS') last_successful_observation
FROM public.sowrix_def_devices d JOIN public.sowrix_def_sites s ON s.id=d.site_id AND s.organization_id=d.organization_id
JOIN public.sowrix_def_collectors col ON col.id=d.collector_id AND col.organization_id=d.organization_id
LEFT JOIN public.sowrix_ops_v5_checks c ON c.asset_id=d.id AND c.organization_id=d.organization_id
LEFT JOIN public.sowrix_ops_v6_profiles n ON n.asset_id=d.id AND n.organization_id=d.organization_id
LEFT JOIN public.sowrix_ops_v7_profiles f ON f.asset_id=d.id AND f.organization_id=d.organization_id
LEFT JOIN public.sowrix_ops_v8_profiles e ON e.asset_id=d.id AND e.organization_id=d.organization_id
LEFT JOIN public.sowrix_ops_v9_profiles h ON h.asset_id=d.id AND h.organization_id=d.organization_id;
REVOKE ALL ON public.sowrix_ops_v10_assets FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v10_query(p_org uuid,p_filter jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v text:=p_filter->>'view';a uuid:=(p_filter->>'asset_id')::uuid;s uuid:=(p_filter->>'site_id')::uuid;
 lo timestamptz:=(p_filter->>'from_at')::timestamptz;hi timestamptz:=(p_filter->>'to_at')::timestamptz;
 lim int:=(p_filter->>'limit')::int;offn int:=(p_filter->>'offset')::int;result jsonb;filtered uuid[];history jsonb:='[]';events jsonb:='[]';incs jsonb:='[]';links jsonb:='[]';nodes jsonb;stats jsonb;site_stats jsonb;collector_stats jsonb;count_inc int;count_event int;truncated boolean:=false;
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'read');
 IF jsonb_typeof(p_filter)<>'object' OR NOT(p_filter ?& ARRAY['view','asset_id','site_id','category','health','search','sort','direction','offset','limit','from_at','to_at','incident_status','severity']) OR (SELECT count(*) FROM jsonb_object_keys(p_filter))<>14
 OR v IS NULL OR v NOT IN ('overview','detail','console','report') OR lim IS NULL OR lim NOT BETWEEN 1 AND 100 OR offn IS NULL OR offn NOT BETWEEN 0 AND 100000
 OR p_filter->>'sort' IS NULL OR p_filter->>'sort' NOT IN ('name','health','last_observed') OR p_filter->>'direction' IS NULL OR p_filter->>'direction' NOT IN ('asc','desc')
 OR length(p_filter->>'search')>100 OR p_filter->>'search' IS NULL OR p_filter->>'category' IS NULL OR length(p_filter->>'category')>40
 OR p_filter->>'health' IS NULL OR p_filter->>'health' NOT IN ('','UP','DOWN','DEGRADED','UNKNOWN','STALE','MAINTENANCE','DISABLED')
 OR p_filter->>'incident_status' IS NULL OR p_filter->>'incident_status' NOT IN ('','open','acknowledged','resolved') OR p_filter->>'severity' IS NULL OR p_filter->>'severity' NOT IN ('','info','warning','critical')
 OR lo IS NULL OR hi IS NULL OR NOT isfinite(lo) OR NOT isfinite(hi) OR hi<=lo OR hi-lo>interval '31 days' OR hi>now()+interval '2 minutes'
 OR (v IN ('detail','report') AND a IS NULL) THEN RAISE EXCEPTION 'Invalid bounded NOC query' USING ERRCODE='22023';END IF;
 IF s IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sowrix_def_sites WHERE organization_id=p_org AND id=s) OR a IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE organization_id=p_org AND id=a AND (s IS NULL OR site_id=s)) THEN RAISE EXCEPTION 'NOC scope not permitted' USING ERRCODE='42501';END IF;
 SELECT coalesce(array_agg(x.asset_id),ARRAY[]::uuid[]) INTO filtered FROM public.sowrix_ops_v10_assets x WHERE x.organization_id=p_org AND (a IS NULL OR x.asset_id=a) AND (s IS NULL OR x.site_id=s) AND (p_filter->>'category'='' OR x.category=p_filter->>'category') AND (p_filter->>'health'='' OR x.health=p_filter->>'health') AND (strpos(lower(x.name),lower(p_filter->>'search'))>0 OR (v='console' AND EXISTS(SELECT 1 FROM public.sowrix_def_incidents i WHERE i.organization_id=p_org AND i.device_id=x.asset_id AND strpos(lower(i.title),lower(p_filter->>'search'))>0))); 
 SELECT jsonb_build_object('total',count(*),'UP',count(*) FILTER(WHERE health='UP'),'DOWN',count(*) FILTER(WHERE health='DOWN'),'DEGRADED',count(*) FILTER(WHERE health='DEGRADED'),'UNKNOWN',count(*) FILTER(WHERE health='UNKNOWN'),'STALE',count(*) FILTER(WHERE health='STALE'),'MAINTENANCE',count(*) FILTER(WHERE health='MAINTENANCE'),'DISABLED',count(*) FILTER(WHERE health='DISABLED'),'scheduled',count(*) FILTER(WHERE check_id IS NOT NULL),'overdue',count(*) FILTER(WHERE health NOT IN ('DISABLED','MAINTENANCE') AND next_due<now()-interval '60 seconds' AND (lease_until IS NULL OR lease_until<now())),'running',count(*) FILTER(WHERE lease_until>now()),'services',count(*) FILTER(WHERE category='service'),'services_up',count(*) FILTER(WHERE category='service' AND health='UP')) INTO stats FROM public.sowrix_ops_v10_assets WHERE organization_id=p_org AND asset_id=ANY(filtered);
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]') INTO site_stats FROM(SELECT p_org organization_id,site_id,site_name,count(*) total,count(*) FILTER(WHERE health='UP') online FROM public.sowrix_ops_v10_assets WHERE organization_id=p_org AND asset_id=ANY(filtered) GROUP BY site_id,site_name ORDER BY site_name)q;
 SELECT jsonb_build_object('total',count(*),'connected',count(*) FILTER(WHERE status='active' AND last_seen>=now()-interval '60 seconds'),'stale',count(*) FILTER(WHERE status='active' AND (last_seen IS NULL OR last_seen<now()-interval '60 seconds')),'disabled',count(*) FILTER(WHERE status<>'active')) INTO collector_stats FROM public.sowrix_def_collectors WHERE organization_id=p_org AND (s IS NULL OR site_id=s) AND (a IS NULL OR id IN(SELECT collector_id FROM public.sowrix_def_devices WHERE organization_id=p_org AND id=a));
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]') INTO nodes FROM(SELECT * FROM public.sowrix_ops_v10_assets WHERE organization_id=p_org AND asset_id=ANY(filtered)
 ORDER BY CASE WHEN p_filter->>'sort'='name' AND p_filter->>'direction'='asc' THEN name END ASC,CASE WHEN p_filter->>'sort'='name' AND p_filter->>'direction'='desc' THEN name END DESC,CASE WHEN p_filter->>'sort'='health' AND p_filter->>'direction'='asc' THEN health END ASC,CASE WHEN p_filter->>'sort'='health' AND p_filter->>'direction'='desc' THEN health END DESC,CASE WHEN p_filter->>'sort'='last_observed' AND p_filter->>'direction'='asc' THEN last_observed END ASC NULLS LAST,CASE WHEN p_filter->>'sort'='last_observed' AND p_filter->>'direction'='desc' THEN last_observed END DESC NULLS LAST,asset_id LIMIT lim OFFSET offn)q;
 SELECT count(*) INTO count_inc FROM public.sowrix_def_incidents WHERE organization_id=p_org AND device_id=ANY(filtered) AND (p_filter->>'incident_status'='' OR status=p_filter->>'incident_status') AND (p_filter->>'severity'='' OR severity=p_filter->>'severity') AND opened_at>=lo AND opened_at<=hi;
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]') INTO incs FROM(SELECT id,organization_id,device_id asset_id,title,severity,status,opened_at,resolved_at,acknowledged_by,rule_key,(SELECT c.id FROM public.sowrix_ops_v5_checks c WHERE c.organization_id=p_org AND c.asset_id=device_id) check_id FROM public.sowrix_def_incidents WHERE organization_id=p_org AND device_id=ANY(filtered) AND (p_filter->>'incident_status'='' OR status=p_filter->>'incident_status') AND (p_filter->>'severity'='' OR severity=p_filter->>'severity') AND opened_at>=lo AND opened_at<=hi ORDER BY opened_at DESC,id LIMIT lim OFFSET CASE WHEN v='console' THEN offn ELSE 0 END)q;
 stats:=stats||jsonb_build_object('active_alerts',(SELECT count(*) FROM public.sowrix_def_incidents WHERE organization_id=p_org AND device_id=ANY(filtered) AND status='open'),'unresolved_incidents',(SELECT count(*) FROM public.sowrix_def_incidents WHERE organization_id=p_org AND device_id=ANY(filtered) AND status<>'resolved'));
 IF v IN ('detail','report') THEN
  SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.observed_at,q.evidence_id),'[]') INTO history FROM(SELECT ev.organization_id,ev.asset_id,ev.id evidence_id,ev.source_id,ev.collector_id,ev.observed_at,ev.ingested_at,ev.document->>'status' status,ev.document->>'provenance' provenance,ev.integrity_hash,ev.document->'measurements' measurements FROM public.sowrix_ops_v4_evidence ev WHERE ev.organization_id=p_org AND ev.asset_id=a AND ev.document->>'provenance'='authenticated_collector' AND ev.document->>'observation_type'='collector_sample' AND ev.observed_at>=lo-greatest(coalesce((SELECT interval_seconds FROM public.sowrix_ops_v5_checks WHERE organization_id=p_org AND asset_id=a),60)*3,45)*interval '1 second' AND ev.observed_at<=hi ORDER BY ev.observed_at,ev.id LIMIT 5001)q;
  truncated:=jsonb_array_length(history)>5000;IF truncated THEN history:=history-5000;END IF;
 END IF;
 SELECT count(*) INTO count_event FROM public.sowrix_ops_v5_timeline t JOIN public.sowrix_ops_v5_checks c ON c.id=t.check_id AND c.organization_id=t.organization_id WHERE t.organization_id=p_org AND c.asset_id=ANY(filtered) AND t.at>=lo AND t.at<=hi;
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]') INTO events FROM(SELECT t.id,t.organization_id,c.asset_id,t.event,t.at,t.incident_id,t.evidence_id,t.actor_id FROM public.sowrix_ops_v5_timeline t JOIN public.sowrix_ops_v5_checks c ON c.id=t.check_id AND c.organization_id=t.organization_id WHERE t.organization_id=p_org AND c.asset_id=ANY(filtered) AND t.at>=lo AND t.at<=hi ORDER BY t.id DESC LIMIT lim OFFSET CASE WHEN v='console' THEN offn ELSE 0 END)q;
 IF v='overview' THEN SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]') INTO links FROM(SELECT id,organization_id,source_asset,target_asset,interface_index,relation FROM public.sowrix_ops_v6_links WHERE organization_id=p_org AND enabled AND source_asset=ANY(filtered) AND target_asset=ANY(filtered) ORDER BY id LIMIT 1001)q;END IF;
 RETURN jsonb_build_object('organization_id',p_org,'server_time',clock_timestamp(),'summary',stats,'sites',site_stats,'collectors',collector_stats,'nodes',nodes,'total',cardinality(filtered),'incidents',incs,'incident_total',count_inc,'timeline',events,'timeline_total',count_event,'history',history,'history_truncated',truncated,'report_interval_seconds',coalesce((SELECT interval_seconds FROM public.sowrix_ops_v5_checks WHERE organization_id=p_org AND asset_id=a),60),'links',links,'topology_partial',cardinality(filtered)>lim OR jsonb_array_length(links)>1000,'assignment_supported',false,'scheduler_health_scope','Persisted jobs only; worker process liveness unavailable','read_only',true);
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_ops_v10_export_audit(p_org uuid,p_asset uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.sowrix_ops_v3_require(p_org,'read');
 IF NOT EXISTS(SELECT 1 FROM public.sowrix_def_devices WHERE organization_id=p_org AND id=p_asset) THEN RAISE EXCEPTION 'Export scope not permitted' USING ERRCODE='42501';END IF;
 PERFORM public.sowrix_def_audit_write(p_org,'ops_v10_export',p_asset::text,'{"format":"csv","scope":"authenticated availability segments"}');
 RETURN jsonb_build_object('organization_id',p_org,'asset_id',p_asset,'audited',true);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_ops_v10_export_audit(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v10_export_audit(uuid,uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.sowrix_ops_v10_query(uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v10_query(uuid,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';COMMIT;
