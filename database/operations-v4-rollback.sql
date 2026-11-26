-- Disable only V4 entry points. Retain evidence, relationships, sources and all V1-V3 data.
BEGIN;
DROP FUNCTION IF EXISTS public.sowrix_ops_v4_ingest(text,jsonb);
DROP FUNCTION IF EXISTS public.sowrix_ops_v4_append(jsonb);
DROP FUNCTION IF EXISTS public.sowrix_ops_v4_list(uuid,uuid,integer,timestamptz,uuid);
DROP FUNCTION IF EXISTS public.sowrix_ops_v4_source(uuid,uuid,text,uuid,text,boolean);
DROP FUNCTION IF EXISTS public.sowrix_ops_v4_write(jsonb,uuid,uuid);
DROP FUNCTION IF EXISTS public.sowrix_ops_v4_validate(jsonb);
COMMIT;
