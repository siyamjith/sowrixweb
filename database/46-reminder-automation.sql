-- SOWRIX R46: additive, idempotent reminder schedule + authorized automation-health RPC.
-- Prerequisites: migration 16 (work/notifications), migration 45; tested backup and staging.
-- No actual mail is sent by this SQL. The existing private business worker must be
-- explicitly configured and restarted to enqueue/deliver consented notifications.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_business_reminders()') IS NULL
    OR to_regprocedure('public.sowrix_emit_event(text,uuid,text,text,uuid[],uuid)') IS NULL
    OR to_regclass('public.sowrix_business_outbox') IS NULL
    OR to_regclass('public.sowrix_r45_payroll_reviews') IS NULL THEN
  RAISE EXCEPTION 'R46 requires work/notifications migration 16 and payroll/IDs migration 45';
 END IF;
END $$;

-- One event per record + date + milestone. Duplicate hourly scheduler runs are
-- handled by the existing sowrix_business_events unique constraint.
-- Prior R16's one-day event key is preserved to avoid duplicate reminders on upgrade.
CREATE OR REPLACE FUNCTION public.sowrix_business_reminders() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $r46$
DECLARE r record; emitted integer:=0; recipients uuid[]; organization_users uuid[]; event_key text;
BEGIN
 IF auth.role()<>'service_role' THEN
  RAISE EXCEPTION 'Server scheduler required' USING ERRCODE='42501';
 END IF;
 FOR r IN
  SELECT 'tasks'::text AS module,t.id,t.due_date AS due_on,t.assignee_id AS owner_id,
      NULL::uuid AS organization_id,d.days_before,0 AS legacy_notice_days
  FROM public.tasks t CROSS JOIN unnest(ARRAY[3,1,0,-1,-7]) d(days_before)
  WHERE t.due_date=current_date+d.days_before AND t.status NOT IN ('done','cancelled')
  UNION ALL
  SELECT 'projects',p.id,p.due_date,p.manager_id,p.client_id,d.days_before,0
  FROM public.projects p CROSS JOIN unnest(ARRAY[3,1,0,-1,-7]) d(days_before)
  WHERE p.due_date=current_date+d.days_before AND p.status NOT IN ('completed','archived')
  UNION ALL
  SELECT 'invoices',i.id,i.due_date,NULL::uuid,i.client_id,d.days_before,0
  FROM public.invoices i CROSS JOIN unnest(ARRAY[7,3,1,0,-3]) d(days_before)
  WHERE i.due_date=current_date+d.days_before
    AND i.status IN ('sent','partially_paid','overdue')
  UNION ALL
  SELECT 'amc',a.id,a.ends_on,NULL::uuid,a.client_id,d.days_before,a.renewal_notice_days
  FROM public.sowrix_amc_contracts a CROSS JOIN unnest(ARRAY[30,15,7,1]) d(days_before)
  WHERE a.ends_on=current_date+d.days_before
    AND a.status='active'
    AND d.days_before<=coalesce(a.renewal_notice_days,0)
 LOOP
  SELECT coalesce(array_agg(user_id),'{}'::uuid[]) INTO recipients
  FROM public.sowrix_event_recipients WHERE module=r.module;
  recipients:=recipients||ARRAY[r.owner_id];
  IF r.module IN ('invoices','amc') THEN
   SELECT coalesce(array_agg(m.user_id),'{}'::uuid[]) INTO organization_users
   FROM public.sowrix_org_memberships m
   WHERE m.organization_id=r.organization_id AND m.status='active';
   recipients:=recipients||organization_users;
  END IF;
  -- The previous scheduler used 'due:YYYY-MM-DD' for the one-day event,
  -- and for the configured AMC renewal_notice_days event.
  event_key:=CASE WHEN r.days_before=1
      OR (r.module='amc' AND r.days_before=r.legacy_notice_days)
      THEN 'due:'||r.due_on::text
      ELSE 'due:'||r.due_on::text||':r46:'||r.days_before::text END;
  IF public.sowrix_emit_event(r.module,r.id,'reminder',event_key,recipients) IS NOT NULL THEN
   emitted:=emitted+1;
  END IF;
 END LOOP;
 -- Once-only routing escalation for newly unassigned tickets (no auto-assignment).
 -- 30-day cutoff prevents a sudden flood of old historical tickets on upgrade.
 FOR r IN SELECT t.id FROM public.support_tickets t
          WHERE t.assignee_id IS NULL
            AND t.status NOT IN ('closed','resolved','cancelled')
            AND t.created_at BETWEEN now()-interval '30 days' AND now()-interval '1 hour'
          ORDER BY t.created_at DESC LIMIT 250
 LOOP
  SELECT coalesce(array_agg(user_id),'{}'::uuid[]) INTO recipients
    FROM public.sowrix_event_recipients WHERE module='tickets';
  IF public.sowrix_emit_event('tickets',r.id,'escalation',
        'r46:unassigned-after-1h',recipients) IS NOT NULL THEN emitted:=emitted+1;END IF;
 END LOOP;
 RETURN emitted;
END
$r46$;

-- Admin-only, count-only automation overview: never returns customer records,
-- addresses, ticket details or salary. Existing MFA/session checks stay enforced.
CREATE OR REPLACE FUNCTION public.sowrix_r46_automation_health() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $health$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN
  RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';
 END IF;
 RETURN jsonb_build_object(
  'generated_at',now(),
  'mail_outbox',(SELECT coalesce(jsonb_object_agg(status,n),'{}'::jsonb)
    FROM (SELECT status,count(*) AS n FROM public.sowrix_business_outbox GROUP BY status)x),
  'unassigned_tickets',(SELECT count(*) FROM public.support_tickets
    WHERE assignee_id IS NULL AND status NOT IN ('closed','resolved','cancelled')),
  'overdue_tasks',(SELECT count(*) FROM public.tasks
    WHERE due_date<current_date AND status NOT IN ('done','cancelled')),
  'overdue_projects',(SELECT count(*) FROM public.projects
    WHERE due_date<current_date AND status NOT IN ('completed','archived')),
  'due_invoices',(SELECT count(*) FROM public.invoices
    WHERE due_date<=current_date AND status IN ('sent','partially_paid','overdue')),
  'amc_next_30_days',(SELECT count(*) FROM public.sowrix_amc_contracts
    WHERE ends_on BETWEEN current_date AND current_date+30 AND status='active'),
  'reminder_events_today',(SELECT count(*) FROM public.sowrix_business_events
    WHERE kind='reminder' AND created_at>=current_date AND created_at<current_date+1)
 );
END
$health$;
REVOKE ALL ON FUNCTION public.sowrix_business_reminders() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_business_reminders() TO service_role;
REVOKE ALL ON FUNCTION public.sowrix_r46_automation_health() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_r46_automation_health() TO authenticated;
COMMIT;
