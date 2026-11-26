-- Read APIs only; all registry, evidence, checks, alerts and indexes retained.
BEGIN;
DROP FUNCTION IF EXISTS public.sowrix_ops_v10_export_audit(uuid,uuid);
DROP FUNCTION IF EXISTS public.sowrix_ops_v10_query(uuid,jsonb);
DROP VIEW IF EXISTS public.sowrix_ops_v10_assets;
NOTIFY pgrst,'reload schema';COMMIT;
