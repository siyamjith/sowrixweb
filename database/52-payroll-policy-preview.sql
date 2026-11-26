-- Optional, additive staging candidate. No seeded rates, payment states or payroll writes.
BEGIN;
CREATE TABLE IF NOT EXISTS public.sowrix_payroll_preview_rules (
 version integer PRIMARY KEY CHECK (version > 0),
 effective_month date NOT NULL UNIQUE CHECK (extract(day FROM effective_month)=1),
 reference text NOT NULL CHECK (length(btrim(reference)) BETWEEN 5 AND 200),
 day_weights jsonb NOT NULL CHECK (jsonb_typeof(day_weights)='object' AND octet_length(day_weights::text)<=4096),
 created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sowrix_payroll_salary_revisions (
 employee_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 effective_from date NOT NULL,
 reference text NOT NULL CHECK (length(btrim(reference)) BETWEEN 5 AND 200),
 basic numeric(14,2) NOT NULL CHECK (basic BETWEEN 0.01 AND 999999999999.99),
 hra numeric(14,2) NOT NULL CHECK (hra BETWEEN 0 AND 999999999999.99),
 dearness numeric(14,2) NOT NULL CHECK (dearness BETWEEN 0 AND 999999999999.99),
 travel numeric(14,2) NOT NULL CHECK (travel BETWEEN 0 AND 999999999999.99),
 special numeric(14,2) NOT NULL CHECK (special BETWEEN 0 AND 999999999999.99),
 other_earnings numeric(14,2) NOT NULL CHECK (other_earnings BETWEEN 0 AND 999999999999.99),
 created_by uuid NOT NULL DEFAULT auth.uid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(employee_user_id,effective_from)
);

ALTER TABLE public.sowrix_payroll_preview_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_payroll_salary_revisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_payroll_preview_rules, public.sowrix_payroll_salary_revisions FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.sowrix_payroll_preview_rules, public.sowrix_payroll_salary_revisions TO authenticated;
-- Provision test rules by reviewed migration owner only. No application write API.
GRANT INSERT (employee_user_id,effective_from,reference,basic,hra,dearness,travel,special,other_earnings)
 ON public.sowrix_payroll_salary_revisions TO authenticated;

DROP POLICY IF EXISTS payroll_preview_rule_read ON public.sowrix_payroll_preview_rules;
CREATE POLICY payroll_preview_rule_read ON public.sowrix_payroll_preview_rules FOR SELECT TO authenticated
 USING (public.sowrix_access_admin() AND public.sowrix_has_module_access('payroll'));
DROP POLICY IF EXISTS payroll_preview_salary_read ON public.sowrix_payroll_salary_revisions;
CREATE POLICY payroll_preview_salary_read ON public.sowrix_payroll_salary_revisions FOR SELECT TO authenticated
 USING (public.sowrix_access_admin() AND public.sowrix_has_module_access('payroll'));
DROP POLICY IF EXISTS payroll_preview_salary_insert ON public.sowrix_payroll_salary_revisions;
CREATE POLICY payroll_preview_salary_insert ON public.sowrix_payroll_salary_revisions FOR INSERT TO authenticated
 WITH CHECK (public.sowrix_access_admin() AND public.sowrix_has_permission('payroll','create') AND created_by=auth.uid()
  AND (SELECT count(*) FROM public.employees e WHERE e.user_id=employee_user_id)=1);

CREATE OR REPLACE FUNCTION public.sowrix_audit_payroll_salary_revision()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(NEW.created_by,'payroll_salary_revision_added','payroll_salary_revision',NEW.employee_user_id::text,
   jsonb_build_object('effective_from',NEW.effective_from));
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION public.sowrix_audit_payroll_salary_revision() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS sowrix_payroll_salary_revision_audit ON public.sowrix_payroll_salary_revisions;
CREATE TRIGGER sowrix_payroll_salary_revision_audit AFTER INSERT ON public.sowrix_payroll_salary_revisions
 FOR EACH ROW EXECUTE FUNCTION public.sowrix_audit_payroll_salary_revision();

CREATE OR REPLACE FUNCTION public.sowrix_payroll_policy_preview(p_employee uuid,p_month text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $fn$
DECLARE
 first_day date; last_day date; start_day date; joined date; employee_status text;
 p public.sowrix_payroll_preview_rules%ROWTYPE;
 s public.sowrix_payroll_salary_revisions%ROWTYPE;
 missing integer; ambiguous integer; paid numeric; loss numeric;
 earned_basic numeric; gross numeric; scheduled numeric;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() OR NOT public.sowrix_has_module_access('payroll')
   OR NOT public.sowrix_has_module_access('attendance') OR NOT public.sowrix_has_module_access('leaves')
 THEN RAISE EXCEPTION 'Payroll preview is not assigned' USING ERRCODE='42501'; END IF;
 IF p_employee IS NULL OR p_month IS NULL OR p_month !~ '^20[0-9]{2}-(0[1-9]|1[0-2])$'
 THEN RAISE EXCEPTION 'Invalid payroll period or employee' USING ERRCODE='22023'; END IF;
 first_day := (p_month||'-01')::date;
 last_day := (first_day+interval '1 month - 1 day')::date;
 SELECT * INTO p FROM public.sowrix_payroll_preview_rules WHERE effective_month<=first_day ORDER BY effective_month DESC LIMIT 1;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','blocked','reason','No versioned preview policy covers this period.'); END IF;
 IF p.day_weights='{}' OR EXISTS (
   SELECT 1 FROM jsonb_each(p.day_weights) j WHERE length(j.key)>40
   OR CASE WHEN jsonb_typeof(j.value)='number' THEN (j.value::text)::numeric NOT IN (0,0.5,1) ELSE true END
 ) THEN RETURN jsonb_build_object('status','blocked','reason','Stored preview policy is invalid.'); END IF;
 SELECT min(e.joining_date), min(e.employment_status) INTO joined,employee_status
 FROM public.employees e WHERE e.user_id=p_employee HAVING count(*)=1;
 IF NOT FOUND OR joined IS NULL OR employee_status IS DISTINCT FROM 'active' OR joined>last_day
 THEN RETURN jsonb_build_object('status','blocked','reason','A verified active employment interval is required; exit months are not calculated.'); END IF;
 start_day:=greatest(first_day,joined);
 SELECT * INTO s FROM public.sowrix_payroll_salary_revisions
 WHERE employee_user_id=p_employee AND effective_from<=start_day ORDER BY effective_from DESC LIMIT 1;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','blocked','reason','No salary revision covers the first eligible day.'); END IF;
 IF EXISTS (SELECT 1 FROM public.sowrix_payroll_salary_revisions WHERE employee_user_id=p_employee AND effective_from>start_day AND effective_from<=last_day)
 THEN RETURN jsonb_build_object('status','blocked','reason','A mid-period salary revision requires a reviewed split calculation.'); END IF;
 IF EXISTS (SELECT 1 FROM public.leave_requests l WHERE l.employee_user_id=p_employee AND lower(l.status) IN ('approved','pending','requested','submitted','under_review')
  AND l.start_date<=last_day AND l.end_date>=start_day)
 THEN RETURN jsonb_build_object('status','blocked','reason','Approved or unresolved leave overlaps this period. Its pay classification is not verified by this preview.'); END IF;
 SELECT count(*) FILTER (WHERE n=0),count(*) FILTER (WHERE n>1 OR (n=1 AND weight IS NULL)),sum(weight)
 INTO missing,ambiguous,paid FROM (
   SELECT d, count(a.id) n, max((p.day_weights->>lower(btrim(a.status)))::numeric) weight
   FROM generate_series(0,last_day-start_day) d
   LEFT JOIN public.attendance_records a ON a.employee_user_id=p_employee AND a.attendance_date=start_day+d
   GROUP BY d
 ) days;
 IF missing<>0 OR ambiguous<>0 THEN RETURN jsonb_build_object('status','blocked','reason','Attendance must have one recognized status per eligible calendar day.','missing_days',missing,'ambiguous_days',ambiguous); END IF;
 scheduled:=last_day-first_day+1;
 loss:=(last_day-start_day+1)-paid;
 earned_basic:=round(s.basic*paid/scheduled,2);
 gross:=earned_basic+round(s.hra*paid/scheduled,2)+round(s.dearness*paid/scheduled,2)
  +round(s.travel*paid/scheduled,2)+round(s.special*paid/scheduled,2)+round(s.other_earnings*paid/scheduled,2);
 RETURN jsonb_build_object('status','preview','policy_version',p.version,'salary_effective_from',s.effective_from,
   'calendar_days',scheduled,'eligible_days',last_day-start_day+1,'paid_days',paid,'loss_of_pay_days',loss,
   'earned_basic',earned_basic,'indicative_gross',gross,'net_payable',NULL,'ctc',NULL,'posting_enabled',false);
END $fn$;
REVOKE ALL ON FUNCTION public.sowrix_payroll_policy_preview(uuid,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sowrix_payroll_policy_preview(uuid,text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
