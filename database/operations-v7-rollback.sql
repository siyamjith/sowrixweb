-- Disable only V7 APIs and restore V6 wrappers. Keep all customer/evidence data.
BEGIN;
DROP FUNCTION IF EXISTS public.sowrix_ops_v7_snapshot(uuid,uuid,timestamptz,uuid,timestamptz,uuid);
DROP FUNCTION IF EXISTS public.sowrix_ops_v7_import(jsonb);
DROP FUNCTION IF EXISTS public.sowrix_ops_v7_configure(uuid,uuid,jsonb);
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v7_prior_finish(text,uuid,uuid,jsonb)') IS NOT NULL THEN
  DROP FUNCTION public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb);ALTER FUNCTION public.sowrix_ops_v7_prior_finish(text,uuid,uuid,jsonb) RENAME TO sowrix_ops_v5_finish;
  DROP FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer);ALTER FUNCTION public.sowrix_ops_v7_prior_claim(text,uuid,integer) RENAME TO sowrix_ops_v5_claim;
  DROP FUNCTION public.sowrix_ops_v5_unit(text);ALTER FUNCTION public.sowrix_ops_v7_prior_unit(text) RENAME TO sowrix_ops_v5_unit;
 END IF;
END $$;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
