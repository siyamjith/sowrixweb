-- Run in SQL Editor BEFORE migration. Read-only, no changes to existing records.
SELECT
 current_database() AS db,
 to_regprocedure('public.sowrix_business_reminders()') IS NOT NULL AS r16_r46_notifications,
 to_regprocedure('public.sowrix_r46_automation_health()') IS NOT NULL AS r46_health,
 to_regprocedure('public.sowrix_staff_eligible(uuid,text,uuid)') IS NOT NULL AS scoped_staff,
 to_regclass('public.sowrix_r45_payroll_reviews') IS NOT NULL AS r45_payroll_review,
 to_regclass('public.sowrix_ticket_replies') IS NOT NULL AS ticket_discussion,
 to_regclass('public.sowrix_org_memberships') IS NOT NULL AS tenant_memberships;
