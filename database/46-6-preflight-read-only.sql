-- Read-only preflight. Run in Supabase SQL editor BEFORE 46-6-enterprise.sql.
-- Does not create, update, or delete any records.
SELECT 'r46_5_dashboard' AS dependency,
       to_regprocedure('public.sowrix_r465_client_dashboard()') IS NOT NULL AS present
UNION ALL SELECT 'secure_session',to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NOT NULL
UNION ALL SELECT 'role_access',to_regprocedure('public.sowrix_access_role()') IS NOT NULL
UNION ALL SELECT 'admin_access',to_regprocedure('public.sowrix_access_admin()') IS NOT NULL
UNION ALL SELECT 'user_active',to_regprocedure('public.sowrix_user_active(uuid)') IS NOT NULL
UNION ALL SELECT 'client_memberships',to_regclass('public.sowrix_org_memberships') IS NOT NULL
UNION ALL SELECT 'client_directory',to_regclass('public.clients') IS NOT NULL
UNION ALL SELECT 'employee_directory',to_regclass('public.employees') IS NOT NULL
UNION ALL SELECT 'audit_logs',to_regclass('public.audit_logs') IS NOT NULL;
SELECT column_name,data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name='employees'
AND column_name IN ('user_id','sowrix_code','employee_code','full_name','employment_status')
ORDER BY column_name;
