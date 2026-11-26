-- R101 Stage 6C: staging candidate; apply after 61. No business data changes.
BEGIN;
DO $check$
BEGIN
 IF strpos(pg_get_functiondef('public.sowrix_has_permission(text,text)'::regprocedure),'R101.6B recruitment and business content grants')=0 THEN RAISE EXCEPTION 'Install migration 61 first'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid='storage.objects'::regclass AND relrowsecurity) THEN RAISE EXCEPTION 'Storage RLS required'; END IF;
 IF (SELECT count(*) FROM storage.buckets WHERE id IN ('sowrix-private','resumes') AND NOT public)<>2 THEN RAISE EXCEPTION 'Both private buckets required'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='sowrix_storage_session_required' AND permissive='RESTRICTIVE') THEN RAISE EXCEPTION 'Storage session guard required'; END IF;
END $check$;
-- Restrictive overlays never grant access. Existing owner, session and object policies still apply.
DROP POLICY IF EXISTS sowrix_r1016c_private_read ON storage.objects;
CREATE POLICY sowrix_r1016c_private_read ON storage.objects AS RESTRICTIVE FOR SELECT TO authenticated USING (
 bucket_id<>'sowrix-private' OR public.sowrix_access_role() IS DISTINCT FROM 'admin' OR
 split_part(name,'/',1)=auth.uid()::text OR public.sowrix_has_permission('documents','view'));
DROP POLICY IF EXISTS sowrix_r1016c_resume_read ON storage.objects;
CREATE POLICY sowrix_r1016c_resume_read ON storage.objects AS RESTRICTIVE FOR SELECT TO authenticated USING (
 bucket_id<>'resumes' OR public.sowrix_access_role() IS DISTINCT FROM 'admin' OR public.sowrix_has_permission('applications','view'));
DROP POLICY IF EXISTS sowrix_r1016c_resume_delete ON storage.objects;
CREATE POLICY sowrix_r1016c_resume_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING (
 bucket_id<>'resumes' OR public.sowrix_access_role() IS DISTINCT FROM 'admin' OR public.sowrix_has_permission('applications','delete'));
DROP POLICY IF EXISTS sowrix_r1016c_document_metadata ON public.sowrix_ui_records;
CREATE POLICY sowrix_r1016c_document_metadata ON public.sowrix_ui_records AS RESTRICTIVE FOR SELECT TO authenticated USING (
 kind<>'document' OR public.sowrix_access_role() IS DISTINCT FROM 'admin' OR public.sowrix_has_permission('documents','view'));
-- Mixed company-wide aggregates cannot be safely scoped by a single module grant.
-- Reserve these specific legacy summaries for Super Admin until scoped replacements exist.
DO $rpc$
DECLARE sig text; f text; anchor text:='PERFORM public.sowrix_require_secure_session(false);'; guard text;
BEGIN
 FOREACH sig IN ARRAY ARRAY['public.sowrix_r462_admin_pulse()','public.sowrix_r462_activity()','public.sowrix_r464_admin_overview()','public.sowrix_r467_board(text)','public.sowrix_r463_hr_snapshot()'] LOOP
  f:=pg_get_functiondef(to_regprocedure(sig));
  IF f IS NULL THEN RAISE EXCEPTION 'Missing RPC: %',sig; END IF;
  IF strpos(f,'R101.6C summary guard')>0 THEN CONTINUE; END IF;
  guard:=CASE WHEN sig='public.sowrix_r467_board(text)' THEN $$IF public.sowrix_access_role()='admin' AND p_section IN ('analytics','security') THEN RAISE EXCEPTION 'Company-wide summary reserved for Super Admin' USING ERRCODE='42501'; END IF;$$
  WHEN sig='public.sowrix_r463_hr_snapshot()' THEN $$IF public.sowrix_access_role()='admin' THEN RAISE EXCEPTION 'Unscoped HR summary reserved for Super Admin or authorized HR' USING ERRCODE='42501'; END IF;$$
  ELSE $$IF public.sowrix_access_role() IS DISTINCT FROM 'super_admin' THEN RAISE EXCEPTION 'Company-wide summary reserved for Super Admin' USING ERRCODE='42501'; END IF;$$ END;
  IF (length(f)-length(replace(f,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'Unexpected RPC definition: %',sig; END IF;
  EXECUTE replace(f,anchor,anchor||E'\n /* R101.6C summary guard */ '||guard);
 END LOOP;
END $rpc$;
COMMIT;
