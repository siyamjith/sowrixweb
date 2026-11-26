-- SOWRIX R46: SAFE READ-ONLY preflight; run in staging BEFORE migration 46.
-- No data modifications. Inspect errors/absence and confirm R45 was applied.
SELECT to_regprocedure('public.sowrix_business_reminders()') AS r16_reminder_scheduler,
       to_regprocedure('public.sowrix_emit_event(text,uuid,text,text,uuid[],uuid)') AS r16_event_dedup,
       to_regprocedure('public.sowrix_require_secure_session(boolean)') AS secure_session,
       to_regclass('public.sowrix_business_outbox') AS mail_outbox,
       to_regclass('public.sowrix_r45_payroll_reviews') AS r45_payroll_review;
SELECT 'tasks' AS area, count(*) AS total FROM public.tasks
UNION ALL SELECT 'projects',count(*) FROM public.projects
UNION ALL SELECT 'tickets',count(*) FROM public.support_tickets
UNION ALL SELECT 'invoices',count(*) FROM public.invoices
UNION ALL SELECT 'amc',count(*) FROM public.sowrix_amc_contracts;
SELECT module, count(*) AS configured_recipients
 FROM public.sowrix_event_recipients GROUP BY module ORDER BY module;
SELECT status,count(*) AS jobs FROM public.sowrix_business_outbox GROUP BY status ORDER BY status;
