-- R46.7 BEFORE migration: pure READ-ONLY preflight on a restored staging database.
SELECT 'r466_suite' AS dependency, to_regprocedure('public.sowrix_r466_board(text)') IS NOT NULL AS present
UNION ALL SELECT 'authenticated_access',to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NOT NULL
UNION ALL SELECT 'role_checks',to_regprocedure('public.sowrix_access_role()') IS NOT NULL
UNION ALL SELECT 'client_memberships',to_regclass('public.sowrix_org_memberships') IS NOT NULL
UNION ALL SELECT 'real_enquiries',to_regclass('public.contact_enquiries') IS NOT NULL
UNION ALL SELECT 'client_directory',to_regclass('public.clients') IS NOT NULL
UNION ALL SELECT 'ticket_feedback',to_regclass('public.sowrix_r464_feedback') IS NOT NULL
UNION ALL SELECT 'audit_logs',to_regclass('public.audit_logs') IS NOT NULL
UNION ALL SELECT 'notifications',to_regclass('public.notifications') IS NOT NULL;
SELECT table_name,column_name,data_type FROM information_schema.columns
WHERE table_schema='public' AND (
(table_name='contact_enquiries' AND column_name IN('id','name','company','service_interest','created_at')) OR
(table_name='clients' AND column_name IN('id','organization_name','status')) OR
(table_name='notifications' AND column_name IN('user_id','category','title','body')))
ORDER BY table_name,column_name;
