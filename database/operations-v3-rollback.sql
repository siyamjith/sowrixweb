-- Non-destructive rollback: disable V3 interfaces, retain archive rows and all old tables.
BEGIN;
DROP FUNCTION IF EXISTS public.sowrix_ops_v3_list(uuid,text,integer,timestamptz,uuid);
DROP FUNCTION IF EXISTS public.sowrix_ops_v3_append(uuid,uuid,text,text,timestamptz,text,jsonb,uuid);
DROP FUNCTION IF EXISTS public.sowrix_ops_v3_require(uuid,text);
COMMIT;
