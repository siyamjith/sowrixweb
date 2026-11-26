-- Read-only validation AFTER applying migration 16 in isolated staging.
-- Aggregate/schema output only. Results do not replace role/tenant negative tests.
SELECT name FROM public.sowrix_upgrade_markers WHERE name IN ('work-notifications-v16','amc-management-v1');
SELECT c.module,c.table_name,c.assignee_field,
 has_column_privilege('authenticated','public.'||c.table_name,c.assignee_field,'UPDATE') AS direct_assignment_update_must_be_false
FROM public.sowrix_work_catalog c ORDER BY c.module;
SELECT n.nspname,c.relname,c.relrowsecurity AS rls_must_be_true,
 has_table_privilege('authenticated',c.oid,'SELECT') AS direct_select_must_be_false
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN ('sowrix_staff_org_scopes','sowrix_business_events','sowrix_business_notifications','sowrix_business_outbox','sowrix_ticket_replies');
SELECT p.proname,p.prosecdef,p.proconfig,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute_must_be_false
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('sowrix_assign_work','sowrix_work_candidates','sowrix_work_status','sowrix_inbox','sowrix_ticket_reply','sowrix_claim_business_mail');
SELECT status,count(*) AS jobs FROM public.sowrix_business_outbox GROUP BY status ORDER BY status;
SELECT count(*) AS processing_leases_expired FROM public.sowrix_business_outbox WHERE status='processing' AND lease_until<now();
SELECT count(*) AS accepted_not_yet_confirmed FROM public.sowrix_business_outbox WHERE status='accepted';
SELECT module,count(*) AS configured_responsible_staff FROM public.sowrix_event_recipients GROUP BY module;
SELECT module,count(*) AS explicit_customer_scopes FROM public.sowrix_staff_org_scopes WHERE enabled GROUP BY module;
