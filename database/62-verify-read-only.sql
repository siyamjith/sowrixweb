BEGIN READ ONLY;
SELECT schemaname,tablename,policyname,permissive,cmd,qual FROM pg_policies WHERE policyname LIKE 'sowrix_r1016c_%' ORDER BY policyname;
SELECT sig,coalesce(strpos(pg_get_functiondef(to_regprocedure(sig)),'R101.6C summary guard')>0,false) AS guard_present FROM unnest(ARRAY['public.sowrix_r462_admin_pulse()','public.sowrix_r462_activity()','public.sowrix_r464_admin_overview()','public.sowrix_r467_board(text)','public.sowrix_r463_hr_snapshot()']) sig;
SELECT id,public FROM storage.buckets WHERE id IN ('sowrix-private','resumes');
ROLLBACK;
