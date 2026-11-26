-- Read-only Stage 5 installation and invoice-link verification.
SELECT to_regclass('public.sowrix_r102_quotation_invoice_links') AS link_table,
       to_regprocedure('public.sowrix_r102_create_draft_invoice_from_quote(uuid,date)') AS draft_invoice_rpc;
SELECT l.quotation_id,q.quotation_number,l.invoice_id,i.invoice_number,i.status,i.client_id,i.project_id,i.total_amount,i.due_date,l.created_at
FROM public.sowrix_r102_quotation_invoice_links l
JOIN public.quotations q ON q.id=l.quotation_id
JOIN public.invoices i ON i.id=l.invoice_id
ORDER BY l.created_at DESC LIMIT 100;
SELECT quotation_id,count(*) AS invoice_links FROM public.sowrix_r102_quotation_invoice_links
GROUP BY quotation_id HAVING count(*)>1;
