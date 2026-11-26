-- R96: invitation-only client account linking. Apply in staging after migrations 12 and 45.
-- No existing client records, memberships or DEFENSOWRIX entitlements are changed.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_client_invite_authorize(uuid,boolean)') IS NULL
 OR to_regprocedure('public.sowrix_bind_client_login(uuid,uuid,uuid)') IS NULL
 OR to_regprocedure('public.sowrix_access_role()') IS NULL
 OR to_regprocedure('public.sowrix_r45_client_code_trigger()') IS NULL THEN
  RAISE EXCEPTION 'Install and verify matching migrations 12 and 45 first';
 END IF;
END $$;
-- Restrictive policies supplement, not replace, existing module and MFA policies.
DROP POLICY IF EXISTS sowrix_r96_client_insert ON public.clients;
CREATE POLICY sowrix_r96_client_insert ON public.clients AS RESTRICTIVE FOR INSERT TO authenticated
 WITH CHECK (public.sowrix_access_admin() AND public.sowrix_access_role() IN ('admin','super_admin'));
DROP POLICY IF EXISTS sowrix_r96_client_update ON public.clients;
CREATE POLICY sowrix_r96_client_update ON public.clients AS RESTRICTIVE FOR UPDATE TO authenticated
 USING (public.sowrix_access_admin() AND public.sowrix_access_role() IN ('admin','super_admin'))
 WITH CHECK (public.sowrix_access_admin() AND public.sowrix_access_role() IN ('admin','super_admin'));
-- Browser callers cannot bypass invitation identity verification by writing a user UUID.
CREATE OR REPLACE FUNCTION public.sowrix_r96_client_link_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF coalesce(auth.role(),'') IN ('authenticated','anon') THEN
  IF TG_OP='INSERT' THEN
   IF NEW.auth_user_id IS NOT NULL THEN RAISE EXCEPTION 'Use Set up client login' USING ERRCODE='42501'; END IF;
  ELSIF NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id THEN
   RAISE EXCEPTION 'Use the verified client invitation workflow' USING ERRCODE='42501';
  END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sowrix_r96_client_link_guard() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS sowrix_r96_client_link_guard ON public.clients;
CREATE TRIGGER sowrix_r96_client_link_guard BEFORE INSERT OR UPDATE OF auth_user_id ON public.clients
 FOR EACH ROW EXECUTE FUNCTION public.sowrix_r96_client_link_guard();
NOTIFY pgrst,'reload schema';
COMMIT;
