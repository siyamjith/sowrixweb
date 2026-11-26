BEGIN READ ONLY;
SELECT sig,coalesce(strpos(pg_get_functiondef(to_regprocedure(sig)),'R101.6D')>0,false) AS guard_present FROM unnest(ARRAY['public.sowrix_set_staff_scope(uuid,uuid,text,boolean,text)','public.sowrix_set_event_recipient(text,uuid,boolean)','public.sowrix_retry_business_mail(uuid)','public.sowrix_business_delivery_status()','public.sowrix_work_admin_settings()','public.sowrix_r462_configure(boolean,boolean)','public.sowrix_r462_pool_member(uuid,boolean)','public.sowrix_early_access_admin(text,jsonb)','public.sowrix_manage_dw_interest(text,jsonb)']) sig;
SELECT tablename,policyname,permissive,cmd FROM pg_policies WHERE policyname LIKE 'sowrix_r1016d_%';
SELECT has_table_privilege('authenticated','public.sowrix_early_access_requests','UPDATE') AS direct_update_still_granted;
ROLLBACK;
