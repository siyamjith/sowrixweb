-- R102 Stage 4: accepted quotation -> project creation.
-- Atomic + idempotent: quotation row lock prevents concurrent duplicate projects.
-- Requires existing R101/R102 schema (migrations through 65) and quotation/project RLS.
BEGIN;

CREATE OR REPLACE FUNCTION public.sowrix_r102_create_project_from_quote(p_quotation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $$
DECLARE
 q public.quotations%ROWTYPE;
 p public.projects%ROWTYPE;
 created_now boolean := false;
BEGIN
 IF auth.uid() IS NULL OR public.sowrix_access_role() NOT IN ('admin','super_admin') THEN
  RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';
 END IF;
 SELECT * INTO q FROM public.quotations WHERE id=p_quotation_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Quotation not found or access unavailable' USING ERRCODE='P0002'; END IF;
 IF q.status<>'accepted' THEN RAISE EXCEPTION 'Only accepted quotations can create projects' USING ERRCODE='23514'; END IF;
 IF q.valid_until IS NULL OR q.valid_until<current_date THEN
  RAISE EXCEPTION 'Accepted quotation must have a current validity date' USING ERRCODE='23514';
 END IF;
 IF q.client_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.clients c WHERE c.id=q.client_id) THEN
  RAISE EXCEPTION 'Quotation must have a valid client' USING ERRCODE='23514';
 END IF;
 IF q.project_id IS NOT NULL THEN
  SELECT * INTO p FROM public.projects WHERE id=q.project_id AND client_id=q.client_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Linked project could not be verified' USING ERRCODE='23514'; END IF;
  RETURN jsonb_build_object('created',false,'project_id',p.id,'project_name',p.name,'client_id',p.client_id,'quotation_id',q.id,'quotation_number',q.quotation_number,'subtotal',q.subtotal,'tax_amount',q.tax_amount,'total_amount',q.total_amount);
 END IF;
 INSERT INTO public.projects(name,client_id,description,status,priority,start_date,due_date,manager_id)
 VALUES(q.title,q.client_id,q.description,'planned','medium',NULL,NULL,NULL,NULL)
 RETURNING * INTO p;
 UPDATE public.quotations SET project_id=p.id,updated_at=now() WHERE id=q.id;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r102_accepted_quotation_project_created','project',p.id::text,
  jsonb_build_object('quotation_id',q.id,'quotation_number',q.quotation_number,'client_id',q.client_id,'subtotal',q.subtotal,'tax_amount',q.tax_amount,'total_amount',q.total_amount));
 created_now:=true;
 RETURN jsonb_build_object('created',created_now,'project_id',p.id,'project_name',p.name,'client_id',p.client_id,'quotation_id',q.id,'quotation_number',q.quotation_number,'subtotal',q.subtotal,'tax_amount',q.tax_amount,'total_amount',q.total_amount);
END;
$$;
REVOKE ALL ON FUNCTION public.sowrix_r102_create_project_from_quote(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_r102_create_project_from_quote(uuid) TO authenticated;

COMMIT;
