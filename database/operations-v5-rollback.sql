-- Retain all definitions, runs, maintenance, timelines, evidence and existing customer tables.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v5_prior_claim_alerts()') IS NOT NULL THEN
  DROP FUNCTION public.sowrix_def_claim_alerts();
  ALTER FUNCTION public.sowrix_ops_v5_prior_claim_alerts() RENAME TO sowrix_def_claim_alerts;
 END IF;
END $$;
GRANT EXECUTE ON FUNCTION public.sowrix_def_claim_alerts() TO service_role;
DROP FUNCTION IF EXISTS public.sowrix_ops_v5_snapshot(uuid,bigint);
DROP FUNCTION IF EXISTS public.sowrix_ops_v5_ack(uuid,uuid);
DROP FUNCTION IF EXISTS public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb);
DROP FUNCTION IF EXISTS public.sowrix_ops_v5_claim(text,uuid,integer);
DROP FUNCTION IF EXISTS public.sowrix_ops_v5_window(uuid,uuid,text,text,uuid,boolean);
DROP FUNCTION IF EXISTS public.sowrix_ops_v5_configure(uuid,uuid,jsonb);
DROP FUNCTION IF EXISTS public.sowrix_ops_v5_collector(text);
DROP FUNCTION IF EXISTS public.sowrix_ops_v5_thresholds(jsonb);
DROP FUNCTION IF EXISTS public.sowrix_ops_v5_unit(text);
NOTIFY pgrst,'reload schema';
COMMIT;
