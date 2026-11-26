-- Run before/after migration 42 in Supabase SQL Editor. No data changes.
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name IN ('attendance_records','employees','sowrix_attendance_metadata')
ORDER BY table_name, ordinal_position;

SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS signature
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('sowrix_attendance_review_save','sowrix_employee_attendance_action')
ORDER BY p.proname;

SELECT tablename, policyname, permissive, cmd
FROM pg_policies
WHERE schemaname='public' AND tablename IN ('attendance_records','sowrix_attendance_metadata')
ORDER BY tablename, policyname;

SELECT to_regclass('public.sowrix_attendance_metadata') IS NOT NULL AS metadata_table_installed,
       to_regprocedure('public.sowrix_attendance_review_save(uuid,timestamptz,text,time,time,text,text,boolean,text)') IS NOT NULL AS audited_edit_rpc_installed;
