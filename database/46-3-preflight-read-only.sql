-- Safe read-only preflight. Record results before any migration.
SELECT current_database() AS db,
 to_regprocedure('public.sowrix_r462_admin_pulse()') IS NOT NULL AS r462_installed,
 to_regprocedure('public.sowrix_user_record_access(uuid,text,jsonb)') IS NOT NULL AS record_scope,
 to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NOT NULL AS secure_session,
 to_regclass('public.job_applications') IS NOT NULL AS applications_table,
 to_regclass('public.support_tickets') IS NOT NULL AS tickets_table,
 to_regclass('public.projects') IS NOT NULL AS projects_table;
