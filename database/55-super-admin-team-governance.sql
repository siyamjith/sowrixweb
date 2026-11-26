-- R101 stage 1: centralize team permission administration. Staging first.
BEGIN;
DO $migration$
DECLARE sig text; oid_fn regprocedure; definition text; marker text; guard text;
BEGIN
 guard := 'IF public.sowrix_access_role() IS DISTINCT FROM ''super_admin'' THEN RAISE EXCEPTION ''Super Admin access required'' USING ERRCODE=''42501''; END IF;';
 FOREACH sig IN ARRAY ARRAY['public.sowrix_save_team_access(uuid,text,jsonb,text,boolean,bigint,text,text)','public.sowrix_team_access_v4()','public.sowrix_list_team_access()'] LOOP
  oid_fn := to_regprocedure(sig);
  IF oid_fn IS NULL THEN RAISE EXCEPTION 'Missing prerequisite: %',sig; END IF;
  definition := pg_get_functiondef(oid_fn);
  IF strpos(definition,guard)>0 THEN CONTINUE; END IF;
  marker := CASE WHEN sig LIKE '%save_team_access%' THEN 'PERFORM public.sowrix_require_secure_session(true);' ELSE 'PERFORM public.sowrix_require_secure_session(false);' END;
  IF (length(definition)-length(replace(definition,marker,'')))/length(marker) <> 1 THEN
   RAISE EXCEPTION 'Unexpected function definition for %; review installed migration',sig;
  END IF;
  EXECUTE replace(definition,marker,marker||E'\n '||guard);
 END LOOP;
END $migration$;
COMMIT;
