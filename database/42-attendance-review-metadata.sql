-- SOWRIX R42: OPTIONAL additive attendance metadata and audited Admin-only corrections.
-- Run only after reviewing your current attendance schema, RLS permissions and backups.
-- This does not backfill or overwrite existing records. No payroll changes are made.
BEGIN;
CREATE TABLE IF NOT EXISTS public.sowrix_attendance_metadata (
 attendance_id uuid PRIMARY KEY REFERENCES public.attendance_records(id) ON DELETE RESTRICT,
 attendance_date date NOT NULL,
 shift_code text NOT NULL DEFAULT 'unassigned' CHECK (shift_code IN ('unassigned','first','day12','general','second','night')),
 vendor text CHECK (char_length(vendor)<=100),
 billable boolean,
 approved_by uuid,
 approved_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sowrix_attendance_metadata_date_idx ON public.sowrix_attendance_metadata(attendance_date);
ALTER TABLE public.sowrix_attendance_metadata ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_attendance_metadata FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.sowrix_attendance_metadata TO authenticated;
DROP POLICY IF EXISTS sowrix_attendance_metadata_read ON public.sowrix_attendance_metadata;
CREATE POLICY sowrix_attendance_metadata_read ON public.sowrix_attendance_metadata FOR SELECT TO authenticated
 USING (public.sowrix_has_permission('attendance','view') AND EXISTS(
  SELECT 1 FROM public.attendance_records a WHERE a.id=attendance_id));
-- No authenticated direct INSERT/UPDATE/DELETE grants. Only the function below can write.
CREATE OR REPLACE FUNCTION public.sowrix_attendance_review_save(
 p_record_id uuid,
 p_expected_updated_at timestamptz,
 p_status text,
 p_check_in time,
 p_check_out time,
 p_shift text,
 p_vendor text,
 p_billable boolean,
 p_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
 v_row public.attendance_records%ROWTYPE;
 v_old_metadata jsonb;
 v_new_metadata jsonb;
 v_month text;
BEGIN
 IF auth.uid() IS NULL OR public.sowrix_access_role() NOT IN ('super_admin','admin')
 OR NOT public.sowrix_has_permission('attendance','edit') THEN
   RAISE EXCEPTION 'Admin attendance edit permission required' USING ERRCODE='42501';
 END IF;
 IF p_record_id IS NULL THEN RAISE EXCEPTION 'Record ID is required' USING ERRCODE='22023'; END IF;
 IF p_status IS NULL OR p_status NOT IN ('present','absent','weekly_off','half_day','holiday','present_ot','holiday_ot',
 'present_rl','casual_leave','earned_leave','sick_leave','comp_off') THEN
   RAISE EXCEPTION 'Unsupported attendance status' USING ERRCODE='22023';
 END IF;
 IF coalesce(p_shift,'unassigned') NOT IN ('unassigned','first','day12','general','second','night') THEN
   RAISE EXCEPTION 'Unknown shift category' USING ERRCODE='22023';
 END IF;
 IF length(btrim(coalesce(p_reason,'')))<8 OR length(p_reason)>500 THEN
   RAISE EXCEPTION 'Provide a correction reason (8 to 500 characters)' USING ERRCODE='22023';
 END IF;
 IF char_length(coalesce(p_vendor,''))>100 THEN
   RAISE EXCEPTION 'Vendor field is too long' USING ERRCODE='22023';
 END IF;
 SELECT * INTO v_row FROM public.attendance_records WHERE id=p_record_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Record not found' USING ERRCODE='22023'; END IF;
 IF p_expected_updated_at IS NULL OR v_row.updated_at IS DISTINCT FROM p_expected_updated_at THEN
   RAISE EXCEPTION 'Attendance record changed; refresh before editing' USING ERRCODE='40001';
 END IF;
 -- Locked payroll periods require separate approved payroll-adjustment process.
 v_month:=to_char(v_row.attendance_date,'YYYY-MM');
 IF EXISTS (SELECT 1 FROM public.payroll_records p WHERE p.employee_user_id=v_row.employee_user_id
  AND p.period=v_month AND lower(p.status) IN ('paid','approved','processed','finalized')) THEN
   RAISE EXCEPTION 'Payroll is finalized for this employee and period; correction requires payroll review' USING ERRCODE='42501';
 END IF;
 SELECT to_jsonb(m) INTO v_old_metadata FROM public.sowrix_attendance_metadata m WHERE attendance_id=p_record_id;
 UPDATE public.attendance_records SET status=p_status,check_in=p_check_in,check_out=p_check_out,updated_at=now()
 WHERE id=p_record_id;
 INSERT INTO public.sowrix_attendance_metadata(attendance_id,attendance_date,shift_code,vendor,billable,approved_by,approved_at)
 VALUES(p_record_id,v_row.attendance_date,coalesce(p_shift,'unassigned'),nullif(btrim(coalesce(p_vendor,'')),''),p_billable,auth.uid(),now())
 ON CONFLICT(attendance_id) DO UPDATE SET attendance_date=excluded.attendance_date,shift_code=excluded.shift_code,vendor=excluded.vendor,
 billable=excluded.billable,approved_by=excluded.approved_by,approved_at=excluded.approved_at,updated_at=now();
 SELECT to_jsonb(m) INTO v_new_metadata FROM public.sowrix_attendance_metadata m WHERE attendance_id=p_record_id;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'attendance_corrected','attendance_records',p_record_id::text,
 jsonb_build_object('reason',btrim(p_reason),'date',v_row.attendance_date,
 'previous_status',v_row.status,'status',p_status,
 'previous_check_in',v_row.check_in,'check_in',p_check_in,
 'previous_check_out',v_row.check_out,'check_out',p_check_out,
 'previous_metadata',v_old_metadata,'new_metadata',v_new_metadata));
 RETURN jsonb_build_object('ok',true,'record_id',p_record_id,'updated_at',now());
END;
$$;
REVOKE ALL ON FUNCTION public.sowrix_attendance_review_save(uuid,timestamptz,text,time,time,text,text,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_attendance_review_save(uuid,timestamptz,text,time,time,text,text,boolean,text) TO authenticated;
COMMIT;
