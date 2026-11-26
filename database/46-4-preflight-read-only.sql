-- Run in Supabase SQL editor before the R46.4 migration. Must return all true.
SELECT to_regprocedure('public.sowrix_r462_decide_approval(uuid,boolean,text)') IS NOT NULL AS r462_approval,
       to_regprocedure('public.sowrix_r463_client_snapshot()') IS NOT NULL AS r463_client,
       to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NOT NULL AS secure_session,
       to_regclass('public.leave_requests') IS NOT NULL AS leaves,
       to_regclass('public.payroll_records') IS NOT NULL AS payroll,
       to_regclass('public.support_tickets') IS NOT NULL AS tickets;
