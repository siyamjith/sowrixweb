-- Read only: run before migration 16 in the target project. No credentials printed.
BEGIN READ ONLY;
SELECT name FROM public.sowrix_upgrade_markers ORDER BY name;
SELECT c.relname AS table_name,a.attname AS column_name,pg_catalog.format_type(a.atttypid,a.atttypmod) AS type
FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN ('employees','employee_profiles','attendance_records','tasks','projects','support_tickets','contact_enquiries','notifications') AND a.attnum>0 AND NOT a.attisdropped ORDER BY c.relname,a.attnum;
SELECT 'directory_without_auth_link' AS issue,count(*) FROM public.employees e WHERE e.user_id IS NULL OR NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=e.user_id)
UNION ALL SELECT 'duplicate_directory_auth_links',count(*) FROM(SELECT user_id FROM public.employees WHERE user_id IS NOT NULL GROUP BY user_id HAVING count(*)>1)d
UNION ALL SELECT 'attendance_without_auth_user',count(*) FROM public.attendance_records a WHERE NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=a.employee_user_id)
UNION ALL SELECT 'attendance_missing_resolved_name_or_id',count(*) FROM public.attendance_records a WHERE coalesce(nullif(public.sowrix_identity_internal(a.employee_user_id)->>'full_name',''),nullif(a.full_name,'')) IS NULL OR coalesce(nullif(public.sowrix_identity_internal(a.employee_user_id)->>'employee_code',''),nullif(a.employee_code,'')) IS NULL;
SELECT tablename,policyname,cmd,permissive,qual,with_check FROM pg_policies WHERE schemaname='public' AND tablename IN ('tasks','projects','support_tickets','clients','contact_enquiries','notifications','interviews','job_applications') ORDER BY tablename,policyname;
COMMIT;
