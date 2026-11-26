-- Reversible feature disable: preserve salary revisions, policy versions and all existing payroll.
BEGIN;
REVOKE EXECUTE ON FUNCTION public.sowrix_payroll_policy_preview(uuid,text) FROM authenticated;
REVOKE SELECT ON public.sowrix_payroll_preview_rules, public.sowrix_payroll_salary_revisions FROM authenticated;
REVOKE INSERT (employee_user_id,effective_from,reference,basic,hra,dearness,travel,special,other_earnings)
 ON public.sowrix_payroll_salary_revisions FROM authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
