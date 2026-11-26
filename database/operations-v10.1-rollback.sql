BEGIN;
-- Remove only this read-only projection; retain every registry/evidence/run record.
DROP FUNCTION IF EXISTS public.sowrix_ops_v101_monitor(uuid,jsonb);
COMMIT;
