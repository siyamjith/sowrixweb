-- R46.5 preflight: all values must be TRUE before applying migration.
SELECT to_regprocedure('public.sowrix_r464_admin_overview()') IS NOT NULL AS r464_installed,
 to_regprocedure('public.sowrix_user_record_access(uuid,text,jsonb)') IS NOT NULL AS scoped_access,
 to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NOT NULL AS secure_session,
 to_regclass('public.sowrix_org_memberships') IS NOT NULL AS membership_table,
 to_regclass('public.audit_logs') IS NOT NULL AS audit_ledger;
