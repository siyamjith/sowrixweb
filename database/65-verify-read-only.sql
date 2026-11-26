-- Read-only installation inventory; does not establish correct authorization by itself.
SELECT to_regclass('public.sowrix_r102_conversions') AS ledger,
 to_regprocedure('public.sowrix_r102_conversion_status(uuid[])') AS status_rpc,
 to_regprocedure('public.sowrix_r102_convert_client(uuid,boolean)') AS conversion_rpc;
SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.sowrix_r102_conversions');
SELECT conname,pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid=to_regclass('public.sowrix_r102_conversions');
SELECT routine_name,grantee,privilege_type FROM information_schema.routine_privileges WHERE routine_schema='public' AND routine_name IN ('sowrix_r102_conversion_status','sowrix_r102_convert_client') ORDER BY routine_name,grantee;
SELECT tgname,tgenabled FROM pg_trigger WHERE tgrelid='public.clients'::regclass AND tgname='sowrix_r45_client_assign';
