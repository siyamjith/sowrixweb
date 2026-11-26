-- R102 Stage 2. Staging candidate; apply after verified R101 migrations and migration 54.
BEGIN;
DO $$ BEGIN
 IF strpos(pg_get_functiondef('public.sowrix_has_permission(text,text)'::regprocedure),'R101.6B recruitment and business content grants')=0
 OR to_regprocedure('public.sowrix_r100_format(text)') IS NULL
 OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.clients'::regclass AND tgname='sowrix_r45_client_assign' AND tgenabled IN ('O','A'))
 THEN RAISE EXCEPTION 'Verify R100 and R101 permission migrations before conversion'; END IF;
END $$;
-- Separate permanent conversion ledger. No existing records modified; no login or entitlement created.
CREATE TABLE IF NOT EXISTS public.sowrix_r102_conversions (
 lead_id uuid PRIMARY KEY REFERENCES public.sowrix_r467_leads(id) ON DELETE RESTRICT,
 client_id uuid NOT NULL UNIQUE REFERENCES public.clients(id) ON DELETE RESTRICT,
 converted_by uuid NOT NULL REFERENCES auth.users(id),
 converted_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sowrix_r102_conversions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_r102_conversions FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_r102_conversion_status(p_leads uuid[]) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT coalesce(public.sowrix_user_active(auth.uid()),false) OR coalesce(public.sowrix_access_role(),'') NOT IN ('admin','super_admin')
 OR NOT coalesce(public.sowrix_has_permission('crm','view'),false) OR NOT coalesce(public.sowrix_has_permission('clients','view'),false)
 THEN RAISE EXCEPTION 'Conversion view denied' USING ERRCODE='42501'; END IF;
 IF p_leads IS NULL OR cardinality(p_leads)>120 THEN RAISE EXCEPTION 'Invalid lead selection' USING ERRCODE='22023'; END IF;
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('lead_id',m.lead_id,'client_code',c.sowrix_code)) FROM public.sowrix_r102_conversions m JOIN public.clients c ON c.id=m.client_id WHERE m.lead_id=ANY(p_leads)),'[]'::jsonb);
END $$;
CREATE OR REPLACE FUNCTION public.sowrix_r102_convert_client(p_lead uuid,p_confirm boolean) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $$
DECLARE l public.sowrix_r467_leads%ROWTYPE; e public.contact_enquiries%ROWTYPE; c public.clients%ROWTYPE; org text; mail text;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT coalesce(public.sowrix_user_active(auth.uid()),false) OR coalesce(public.sowrix_access_role(),'') NOT IN ('admin','super_admin')
 OR NOT coalesce(public.sowrix_has_permission('crm','view'),false) OR NOT coalesce(public.sowrix_has_permission('crm','edit'),false)
 OR NOT coalesce(public.sowrix_has_permission('clients','view'),false) OR NOT coalesce(public.sowrix_has_permission('clients','create'),false)
 OR NOT coalesce(public.sowrix_has_permission('enquiries','view'),false)
 THEN RAISE EXCEPTION 'Conversion permission denied' USING ERRCODE='42501'; END IF;
 IF p_lead IS NULL OR p_confirm IS DISTINCT FROM true THEN RAISE EXCEPTION 'Explicit confirmation required' USING ERRCODE='22023'; END IF;
 SELECT * INTO l FROM public.sowrix_r467_leads WHERE id=p_lead FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Lead unavailable' USING ERRCODE='22023'; END IF;
 SELECT cl.* INTO c FROM public.sowrix_r102_conversions m JOIN public.clients cl ON cl.id=m.client_id WHERE m.lead_id=l.id;
 IF FOUND THEN RETURN jsonb_build_object('status','already_converted','client_code',c.sowrix_code); END IF;
 IF l.stage IS DISTINCT FROM 'won' THEN RAISE EXCEPTION 'Only won leads can be converted' USING ERRCODE='22023'; END IF;
 SELECT * INTO e FROM public.contact_enquiries WHERE id=l.enquiry_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Enquiry unavailable' USING ERRCODE='22023'; END IF;
 org:=coalesce(nullif(btrim(e.company),''),nullif(btrim(e.name),'')); mail:=lower(btrim(coalesce(e.email,'')));
 IF org IS NULL OR length(org)>250 OR length(mail)>254 OR mail !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN RAISE EXCEPTION 'Review source enquiry details' USING ERRCODE='22023'; END IF;
 -- Serialize new client records during the duplicate check. Not a global uniqueness rule for manual client workflows.
 LOCK TABLE public.clients IN SHARE ROW EXCLUSIVE MODE;
 IF EXISTS(SELECT 1 FROM public.clients x WHERE lower(btrim(x.email))=mail OR lower(btrim(x.organization_name))=lower(org)) THEN
  RETURN jsonb_build_object('status','duplicate_review');
 END IF;
 INSERT INTO public.clients(organization_name,contact_person,email,phone,status,auth_user_id)
 VALUES(org,nullif(btrim(e.name),''),mail,nullif(btrim(e.phone),''),'active',NULL) RETURNING * INTO c;
 IF c.sowrix_code IS NULL OR c.sowrix_code !~ '^SW/CL/[0-9]{4,}$' THEN RAISE EXCEPTION 'Automatic client numbering unavailable'; END IF;
 INSERT INTO public.sowrix_r102_conversions(lead_id,client_id,converted_by) VALUES(l.id,c.id,auth.uid());
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r102_convert_client','clients',c.id::text,jsonb_build_object('lead_id',l.id,'client_code',c.sowrix_code));
 RETURN jsonb_build_object('status','created','client_code',c.sowrix_code);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_r102_conversion_status(uuid[]),public.sowrix_r102_convert_client(uuid,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r102_conversion_status(uuid[]),public.sowrix_r102_convert_client(uuid,boolean) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
