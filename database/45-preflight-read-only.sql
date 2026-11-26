-- R45 read-only preflight. Must check source types/roles before writing migration.
SELECT table_name,column_name,data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name IN ('clients','employees','user_roles','payroll_records')
 AND column_name IN ('id','user_id','role','email','employee_code','sowrix_code','period','net_amount')
 ORDER BY table_name,column_name;
SELECT 'employees' kind,count(*) rows,count(*) FILTER(WHERE user_id IS NULL) unlinked FROM public.employees
UNION ALL SELECT 'clients',count(*),count(*) FILTER (WHERE auth_user_id IS NULL) FROM public.clients;
SELECT role::text,count(*) FROM public.user_roles GROUP BY role ORDER BY role;
