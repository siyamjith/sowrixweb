-- SOWRIX R40 - READ ONLY diagnostic; no database objects or records are modified.
-- Run as a trusted administrator in Supabase SQL Editor, never in public JS.
SELECT t.table_name, to_regclass('public.' || t.table_name) IS NOT NULL AS exists
FROM (VALUES ('employees'), ('attendance_records'), ('payroll_records'), ('leave_requests')) t(table_name)
ORDER BY t.table_name;

SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name IN ('employees','attendance_records','payroll_records')
  AND column_name IN ('id','employee_user_id','user_id','employee_code','full_name','department','designation',
                      'attendance_date','check_in','check_out','status','notes','period','basic_amount',
                      'allowances','deductions','net_amount','paid_at')
ORDER BY table_name, ordinal_position;

SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename IN ('employees','attendance_records','payroll_records')
ORDER BY tablename;

SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public' AND tablename IN ('employees','attendance_records','payroll_records')
ORDER BY tablename, policyname;
