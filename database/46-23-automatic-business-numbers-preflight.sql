-- Read only; review before 46-23-automatic-business-numbers.sql.
SELECT table_name, column_name, data_type, is_nullable FROM information_schema.columns
 WHERE table_schema='public'
 AND ((table_name='invoices' AND column_name IN ('invoice_number','subtotal','tax_amount','total_amount'))
   OR (table_name='quotations' AND column_name IN ('quotation_number','subtotal','tax_amount','total_amount'))
   OR (table_name='support_tickets' AND column_name='ticket_number'))
 ORDER BY table_name,column_name;
SELECT 'invoice' AS kind,invoice_number AS value,COUNT(*) AS duplicates
 FROM public.invoices WHERE invoice_number ~ '^SW/INV/[0-9]{4,}$'
 GROUP BY invoice_number HAVING COUNT(*)>1
UNION ALL
SELECT 'quotation',quotation_number,COUNT(*)
 FROM public.quotations WHERE quotation_number ~ '^SW/QT/[0-9]{4,}$'
 GROUP BY quotation_number HAVING COUNT(*)>1
UNION ALL
SELECT 'ticket',ticket_number,COUNT(*)
 FROM public.support_tickets WHERE ticket_number ~ '^SW/TK/[0-9]{4,}$'
 GROUP BY ticket_number HAVING COUNT(*)>1;
SELECT 'invoices' AS record_type,COUNT(*) AS count FROM public.invoices
UNION ALL SELECT 'quotations',COUNT(*) FROM public.quotations
UNION ALL SELECT 'tickets',COUNT(*) FROM public.support_tickets;
