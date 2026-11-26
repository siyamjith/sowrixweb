-- SOWRIX R28 — opt-in employee self-attendance quick actions.
-- REVIEW AND BACK UP database before applying. Do not run before migration 11/16.
-- This function NEVER accepts an arbitrary employee identifier from the client.
BEGIN;
CREATE OR REPLACE FUNCTION public.sowrix_employee_attendance_action(p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_role text;
  v_day date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
  v_clock time := (now() AT TIME ZONE 'Asia/Kolkata')::time(0);
  v_name text;
  v_code text;
  v_row public.attendance_records%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_action NOT IN ('in','out') OR p_action IS NULL THEN RAISE EXCEPTION 'Invalid action' USING ERRCODE='22023'; END IF;
  v_role := public.sowrix_access_role();
  IF v_role <> 'employee' OR NOT public.sowrix_has_permission('attendance','view') THEN
    RAISE EXCEPTION 'Employee attendance access required' USING ERRCODE='42501';
  END IF;
  SELECT full_name, employee_code INTO v_name,v_code
    FROM public.employees WHERE user_id=v_uid AND employment_status='active' LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active employee profile required' USING ERRCODE='42501'; END IF;
  -- Serialize same-user operations to prevent accidental repeated check-ins.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_uid::text || v_day::text, 0));
  SELECT * INTO v_row FROM public.attendance_records
    WHERE employee_user_id=v_uid AND attendance_date=v_day FOR UPDATE;
  IF p_action='in' THEN
    IF FOUND THEN
      IF v_row.check_in IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'already',true,'action','in','date',v_day); END IF;
      UPDATE public.attendance_records SET check_in=v_clock,status='present',updated_at=now()
      WHERE id=v_row.id;
    ELSE
      INSERT INTO public.attendance_records(employee_user_id,attendance_date,check_in,status,full_name,employee_code)
      VALUES(v_uid,v_day,v_clock,'present',v_name,v_code);
    END IF;
  ELSE
    IF NOT FOUND OR v_row.check_in IS NULL THEN RAISE EXCEPTION 'Check in first' USING ERRCODE='22023'; END IF;
    IF v_row.check_out IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'already',true,'action','out','date',v_day); END IF;
    UPDATE public.attendance_records SET check_out=v_clock,updated_at=now() WHERE id=v_row.id;
  END IF;
  RETURN jsonb_build_object('ok',true,'already',false,'action',p_action,'date',v_day);
END;
$$;
REVOKE ALL ON FUNCTION public.sowrix_employee_attendance_action(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sowrix_employee_attendance_action(text) TO authenticated;
COMMIT;
