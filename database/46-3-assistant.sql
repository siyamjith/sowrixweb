-- SOWRIX R46.3: additive READ-ONLY aggregate views for HR and CLIENT assistants.
-- Apply only after tested 46-2-operations.sql on a restored staging DB.
-- No service role data to browser, no autonomous HR or financial decisions.
BEGIN;
DO $$BEGIN
 IF to_regprocedure('public.sowrix_r462_admin_pulse()') IS NULL
   OR to_regprocedure('public.sowrix_user_record_access(uuid,text,jsonb)') IS NULL THEN
  RAISE EXCEPTION 'R46.2 prerequisite functions missing';
 END IF;
END$$;

CREATE OR REPLACE FUNCTION public.sowrix_r463_hr_snapshot() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT (public.sowrix_access_admin() OR
    (public.sowrix_access_role() IN ('hr','hr_staff','hr_manager') AND
     public.sowrix_has_module_access('applications'))) THEN
  RAISE EXCEPTION 'HR summary unavailable' USING ERRCODE='42501';
 END IF;
 RETURN jsonb_build_object('new_candidates',
     (SELECT count(*) FROM public.job_applications WHERE status='applied'),
   'under_review',(SELECT count(*) FROM public.job_applications WHERE status='under_review'),
   'shortlisted',(SELECT count(*) FROM public.job_applications WHERE status='shortlisted'),
   'total_open_candidates',(SELECT count(*) FROM public.job_applications
     WHERE status IN ('applied','under_review','shortlisted')));
END $fn$;

CREATE OR REPLACE FUNCTION public.sowrix_r463_client_snapshot() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE open_projects int;open_tickets int;late_projects int;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF public.sowrix_access_role() IS DISTINCT FROM 'client' THEN
  RAISE EXCEPTION 'Client summary unavailable' USING ERRCODE='42501';
 END IF;
 -- Explicit record-level checks on every aggregate row; no tenant IDs or
 -- identifiable records leak in the response. DB role must not bypass session.
 SELECT count(*),count(*) FILTER(WHERE p.due_date<current_date AND p.status NOT IN ('completed','cancelled'))
 INTO open_projects,late_projects FROM public.projects p
 WHERE p.status NOT IN ('completed','cancelled')
   AND public.sowrix_user_record_access(auth.uid(),'projects',to_jsonb(p));
 SELECT count(*) INTO open_tickets FROM public.support_tickets t
 WHERE t.status NOT IN ('resolved','closed','cancelled')
   AND public.sowrix_user_record_access(auth.uid(),'tickets',to_jsonb(t));
 RETURN jsonb_build_object('open_projects',open_projects,'overdue_projects',late_projects,
                           'open_tickets',open_tickets);
END $fn$;

REVOKE ALL ON FUNCTION public.sowrix_r463_hr_snapshot(),public.sowrix_r463_client_snapshot()
 FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_r463_hr_snapshot(),public.sowrix_r463_client_snapshot()
 TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
