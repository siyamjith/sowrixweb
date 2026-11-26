-- Preserve all network profiles, interface/metric history, topology and V1–V5 records.
BEGIN;
DROP FUNCTION IF EXISTS public.sowrix_ops_v6_snapshot(uuid,uuid,timestamptz,uuid);
DROP FUNCTION IF EXISTS public.sowrix_ops_v6_link(uuid,jsonb);
DROP FUNCTION IF EXISTS public.sowrix_ops_v6_configure(uuid,uuid,jsonb);
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_ops_v6_prior_finish(text,uuid,uuid,jsonb)') IS NOT NULL THEN
  DROP FUNCTION public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb);ALTER FUNCTION public.sowrix_ops_v6_prior_finish(text,uuid,uuid,jsonb) RENAME TO sowrix_ops_v5_finish;
  DROP FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer);ALTER FUNCTION public.sowrix_ops_v6_prior_claim(text,uuid,integer) RENAME TO sowrix_ops_v5_claim;
  DROP FUNCTION public.sowrix_ops_v4_validate(jsonb);ALTER FUNCTION public.sowrix_ops_v6_prior_validate(jsonb) RENAME TO sowrix_ops_v4_validate;
  DROP FUNCTION public.sowrix_ops_v5_unit(text);ALTER FUNCTION public.sowrix_ops_v6_prior_unit(text) RENAME TO sowrix_ops_v5_unit;
 END IF;
END $$;
GRANT EXECUTE ON FUNCTION public.sowrix_ops_v5_claim(text,uuid,integer),public.sowrix_ops_v5_finish(text,uuid,uuid,jsonb) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
