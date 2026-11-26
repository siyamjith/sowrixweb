-- Read-only launch inventory. Run after schema preflight in the intended project.
-- Outputs schema/policy presence and aggregate counts, never secret values or PII.
BEGIN READ ONLY;
SELECT expected.table_name, to_regclass('public.'||expected.table_name) IS NOT NULL AS present,
 coalesce(c.relrowsecurity,false) AS rls_enabled
FROM unnest(ARRAY['clients','projects','tasks','support_tickets','employees','attendance_records','leave_requests','payroll_records','job_applications','invoices','sowrix_amc_contracts','sowrix_org_memberships','sowrix_def_sessions','sowrix_def_devices','sowrix_def_audit']) expected(table_name)
LEFT JOIN pg_class c ON c.oid=to_regclass('public.'||expected.table_name);
SELECT signature,to_regprocedure(signature) IS NOT NULL AS present FROM unnest(ARRAY[
 'public.sowrix_team_access_v4()','public.sowrix_permission_snapshot()',
 'public.sowrix_my_identity()','public.sowrix_people_display(uuid[])',
 'public.sowrix_submit_consultation(jsonb,uuid)',
 'public.sowrix_client_invite_authorize(uuid,boolean)',
 'public.sowrix_def_request(text,uuid,jsonb)']) required(signature);
SELECT required.table_name,required.column_name,
 EXISTS(SELECT 1 FROM information_schema.columns c WHERE c.table_schema='public' AND c.table_name=required.table_name AND c.column_name=required.column_name) AS present
FROM (VALUES('attendance_records','full_name'),('attendance_records','employee_code'),('leave_requests','full_name'),('leave_requests','employee_code'),('payroll_records','full_name'),('payroll_records','employee_code'),('interviews','interviewer_employee_code')) required(table_name,column_name);
SELECT id,public,file_size_limit,allowed_mime_types FROM storage.buckets WHERE id IN ('sowrix-private','resumes');
SELECT tablename,policyname,permissive,roles,cmd FROM pg_policies
 WHERE schemaname IN ('public','storage') AND tablename IN ('sowrix_amc_contracts','invoices','support_tickets','attendance_records','job_applications','objects') ORDER BY tablename,policyname;
SELECT name,applied_at FROM public.sowrix_upgrade_markers WHERE name IN ('granular-access-v4','amc-management-v1');
SELECT c.module_key,EXISTS(SELECT 1 FROM public.sowrix_access_modules m WHERE m.module_key=c.module_key) AS parent_present
 FROM public.sowrix_permission_catalog c WHERE module_key IN ('profile','amc','employees','attendance','invoices');
SELECT 'attendance records with no linked directory name/ID' AS review_item,count(*) AS records_to_review
 FROM public.attendance_records a WHERE NOT EXISTS(SELECT 1 FROM public.employees e WHERE e.user_id=a.employee_user_id AND nullif(btrim(e.full_name),'') IS NOT NULL AND nullif(btrim(e.employee_code),'') IS NOT NULL);
-- This count is a review signal, not proof of lost data: legacy/metadata resolver
-- fallbacks can still supply a display name. Review the actual identity links.
COMMIT;
