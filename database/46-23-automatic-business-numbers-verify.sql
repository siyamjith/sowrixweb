-- Read only. A new insert requires a separately authorized staging-only test.
SELECT t.tgrelid::regclass AS source_table,t.tgname AS trigger_name,
       t.tgenabled AS enabled FROM pg_trigger t
 WHERE t.tgname IN ('sowrix_r4623_number_invoice','sowrix_r4623_number_quote',
                    'sowrix_r4623_number_ticket') ORDER BY 1;
SELECT sequencename,last_value FROM pg_sequences WHERE schemaname='public'
  AND sequencename IN ('sowrix_r4623_invoice_seq','sowrix_r4623_quote_seq',
                       'sowrix_r4623_ticket_seq') ORDER BY sequencename;
SELECT 'invoice' AS kind,COUNT(*) AS issued FROM public.invoices
 WHERE invoice_number ~ '^SW/INV/[0-9]{4,}$'
UNION ALL SELECT 'quotation',COUNT(*) FROM public.quotations
 WHERE quotation_number ~ '^SW/QT/[0-9]{4,}$'
UNION ALL SELECT 'ticket',COUNT(*) FROM public.support_tickets
 WHERE ticket_number ~ '^SW/TK/[0-9]{4,}$';
