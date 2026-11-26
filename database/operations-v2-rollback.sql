-- Disable only V2 RPCs after reverting the gateway/portal to V1.
-- Existing telemetry, incidents, audits and tenant data are deliberately preserved.
BEGIN;
DROP FUNCTION IF EXISTS public.sowrix_ops_v2_ingest(text,jsonb);
DROP FUNCTION IF EXISTS public.sowrix_ops_v2_context(uuid);
COMMIT;
