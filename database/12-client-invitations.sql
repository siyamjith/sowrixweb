-- Targeted client invitation repair after the matching SOWRIX release 10/11.
-- No accounts or messages are created by this migration. Existing data is preserved.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NULL
 OR to_regprocedure('public.sowrix_client_invite_context(uuid,uuid)') IS NULL
 OR to_regprocedure('public.sowrix_bind_client_login(uuid,uuid,uuid)') IS NULL THEN
  RAISE EXCEPTION 'Matching SOWRIX security foundation is missing. Review the complete backend installation first.';
 END IF;
END $$;

-- Hosted Auth email is varchar; a RETURNS TABLE text column requires an explicit cast.
CREATE OR REPLACE FUNCTION public.sowrix_client_account_picker()
RETURNS TABLE(user_id uuid,email text,full_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF auth.uid() IS NULL OR NOT public.sowrix_access_admin() OR NOT public.sowrix_has_module_access('clients') THEN
  RAISE EXCEPTION 'Client account assignment access required' USING ERRCODE='42501';
 END IF;
 RETURN QUERY SELECT u.id,u.email::text,
  coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'),''),nullif(btrim(u.raw_user_meta_data->>'name'),''),u.email::text)::text
 FROM auth.users u JOIN public.user_roles r ON r.user_id=u.id
 WHERE lower(r.role::text)='client' ORDER BY u.email LIMIT 500;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_client_account_picker() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_client_account_picker() TO authenticated;

-- Caller-JWT gate. The gateway must pass this BEFORE any service-role Auth call.
CREATE OR REPLACE FUNCTION public.sowrix_client_invite_authorize(p_client_id uuid,p_send boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.clients;
BEGIN
 PERFORM public.sowrix_require_secure_session(p_send);
 IF NOT public.sowrix_access_admin() OR NOT public.sowrix_has_module_access('clients')
 OR NOT (public.sowrix_has_permission('clients','create') OR public.sowrix_has_permission('clients','edit')) THEN
  RAISE EXCEPTION 'Administrator client-management access is required' USING ERRCODE='42501';
 END IF;
 SELECT * INTO c FROM public.clients WHERE id=p_client_id;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Client not found or access not permitted' USING ERRCODE='42501'; END IF;
 IF c.status IS DISTINCT FROM 'active' THEN RAISE EXCEPTION 'Activate this client before sending an invitation' USING ERRCODE='22023'; END IF;
 IF coalesce(c.email,'') !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]{2,}$' THEN
  RAISE EXCEPTION 'Save a valid client email before sending an invitation' USING ERRCODE='22023';
 END IF;
 RETURN jsonb_build_object('actor_id',auth.uid(),'client_id',c.id,'email',lower(btrim(c.email)),'linked',c.auth_user_id IS NOT NULL);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_client_invite_authorize(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_client_invite_authorize(uuid,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_client_invite_audit(p_actor_id uuid,p_client_id uuid,p_outcome text,p_provider_id text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' OR p_outcome NOT IN ('accepted','failed','unknown') THEN
  RAISE EXCEPTION 'Trusted invitation worker required' USING ERRCODE='42501';
 END IF;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(p_actor_id,'client_invitation_'||p_outcome,'clients',p_client_id::text,
  jsonb_build_object('email_status',p_outcome,'provider_message_id',left(p_provider_id,120)));
END $$;
REVOKE ALL ON FUNCTION public.sowrix_client_invite_audit(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_client_invite_audit(uuid,uuid,text,text) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
