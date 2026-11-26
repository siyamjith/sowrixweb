-- R102 Stage 5: accepted quotation + linked project -> one draft invoice.
-- No invoice is sent, settled, or marked paid by this workflow.
-- Apply only to a backed-up staging database after migrations through 66 are verified.
BEGIN;

CREATE TABLE IF NOT EXISTS public.sowrix_r102_quotation_invoice_links (
 quotation_id uuid PRIMARY KEY REFERENCES public.quotations(id) ON DELETE RESTRICT,
 invoice_id uuid NOT NULL UNIQUE REFERENCES public.invoices(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now(),
 created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT
);
REVOKE ALL ON TABLE public.sowrix_r102_quotation_invoice_links FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_r102_create_draft_invoice_from_quote(
 p_quotation_id uuid,
 p_due_date date
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE
 q public.quotations%ROWTYPE;
 i public.invoices%ROWTYPE;
 existing_link public.sowrix_r102_quotation_invoice_links%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL OR public.sowrix_access_role() NOT IN ('admin','super_admin') THEN
  RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';
 END IF;
 IF p_due_date IS NULL OR p_due_date < current_date THEN
  RAISE EXCEPTION 'Invoice due date must be today or later' USING ERRCODE='22007';
 END IF;
 SELECT * INTO q FROM public.quotations WHERE id=p_quotation_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Quotation not found or access unavailable' USING ERRCODE='P0002'; END IF;
 IF q.status<>'accepted' THEN RAISE EXCEPTION 'Only accepted quotations can create draft invoices' USING ERRCODE='23514'; END IF;
 IF q.valid_until IS NULL OR q.valid_until<current_date THEN
  RAISE EXCEPTION 'Accepted quotation must have a current validity date' USING ERRCODE='23514';
 END IF;
 IF q.project_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.projects p WHERE p.id=q.project_id AND p.client_id=q.client_id) THEN
  RAISE EXCEPTION 'Quotation must be linked to its matching client project first' USING ERRCODE='23514';
 END IF;
 IF q.client_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.clients c WHERE c.id=q.client_id) THEN
  RAISE EXCEPTION 'Quotation must have a valid client' USING ERRCODE='23514';
 END IF;
 IF q.subtotal IS NULL OR q.subtotal<0 OR coalesce(q.tax_amount,0)<0 OR q.total_amount IS NULL OR q.total_amount<0 OR round(q.subtotal+coalesce(q.tax_amount,0),2)<>round(q.total_amount,2) THEN
  RAISE EXCEPTION 'Quotation amounts are invalid or inconsistent' USING ERRCODE='23514';
 END IF;
 SELECT * INTO existing_link FROM public.sowrix_r102_quotation_invoice_links WHERE quotation_id=q.id;
 IF FOUND THEN
  SELECT * INTO i FROM public.invoices WHERE id=existing_link.invoice_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Existing quotation invoice link is inconsistent; manual review required' USING ERRCODE='23514'; END IF;
  RETURN jsonb_build_object('created',false,'invoice_id',i.id,'invoice_number',i.invoice_number,'quotation_id',q.id,'project_id',q.project_id,'status',i.status,'due_date',i.due_date);
 END IF;
 INSERT INTO public.invoices(client_id,project_id,description,issue_date,due_date,subtotal,tax_amount,total_amount,status,notes)
 VALUES(q.client_id,q.project_id,left(q.title||CASE WHEN coalesce(q.description,'')<>'' THEN E'\n\n'||q.description ELSE '' END,20000),current_date,p_due_date,q.subtotal,coalesce(q.tax_amount,0),q.total_amount,'draft',left('Draft generated from accepted quotation '||q.quotation_number||'. Review before sending.',2000))
 RETURNING * INTO i;
 INSERT INTO public.sowrix_r102_quotation_invoice_links(quotation_id,invoice_id,created_by)
 VALUES(q.id,i.id,auth.uid());
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r102_accepted_quotation_draft_invoice_created','invoice',i.id::text,
  jsonb_build_object('quotation_id',q.id,'quotation_number',q.quotation_number,'project_id',q.project_id,'client_id',q.client_id,'subtotal',q.subtotal,'tax_amount',coalesce(q.tax_amount,0),'total_amount',q.total_amount,'due_date',p_due_date,'status','draft'));
 RETURN jsonb_build_object('created',true,'invoice_id',i.id,'invoice_number',i.invoice_number,'quotation_id',q.id,'project_id',q.project_id,'status',i.status,'due_date',i.due_date);
END;
$$;
REVOKE ALL ON FUNCTION public.sowrix_r102_create_draft_invoice_from_quote(uuid,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sowrix_r102_create_draft_invoice_from_quote(uuid,date) TO authenticated;

COMMIT;
