-- R46.23 additive business numbering (PostgreSQL / existing Supabase project).
-- APPLY ONLY after a verified backup, migration 45 and the read-only preflight.
-- Runs atomically. No existing invoices, quotations or client/employee IDs are renumbered.
-- These display identifiers never replace UUID authorization, tenant RLS or MFA.
BEGIN;

-- LOCK prevents invoice/quotation/ticket inserts while counters are aligned to
-- historical, already-issued SW numbers. Install during a short maintenance window.
LOCK TABLE public.invoices, public.quotations, public.support_tickets
  IN SHARE ROW EXCLUSIVE MODE;

CREATE SEQUENCE IF NOT EXISTS public.sowrix_r4623_invoice_seq START WITH 1;
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r4623_quote_seq START WITH 1;
CREATE SEQUENCE IF NOT EXISTS public.sowrix_r4623_ticket_seq START WITH 1;
REVOKE ALL ON SEQUENCE public.sowrix_r4623_invoice_seq,
 public.sowrix_r4623_quote_seq, public.sowrix_r4623_ticket_seq
 FROM PUBLIC, anon, authenticated;

-- Reject ambiguous already-issued SOWRIX numbers before adding constraints.
-- Legacy custom number formats are left exactly as they are.
DO $check$
BEGIN
 IF EXISTS (SELECT 1 FROM public.invoices WHERE invoice_number ~ '^SW/INV/[0-9]{4,}$'
             GROUP BY invoice_number HAVING count(*)>1) THEN
   RAISE EXCEPTION 'Duplicate existing SW/INV invoice numbers: stop and reconcile in staging';
 END IF;
 IF EXISTS (SELECT 1 FROM public.quotations WHERE quotation_number ~ '^SW/QT/[0-9]{4,}$'
             GROUP BY quotation_number HAVING count(*)>1) THEN
   RAISE EXCEPTION 'Duplicate existing SW/QT quotation numbers: stop and reconcile in staging';
 END IF;
 IF EXISTS (SELECT 1 FROM public.support_tickets WHERE ticket_number ~ '^SW/TK/[0-9]{4,}$'
             GROUP BY ticket_number HAVING count(*)>1) THEN
   RAISE EXCEPTION 'Duplicate existing SW/TK ticket numbers: stop and reconcile in staging';
 END IF;
END;
$check$;

-- Preserve the current sequence state on repeated deployments. For a fresh
-- sequence with no matching historical code, leave is_called=false (first ID=0001).
DO $align$
DECLARE highest bigint; last_num bigint; already_called boolean;
BEGIN
 SELECT COALESCE(MAX(substring(invoice_number FROM '^SW/INV/([0-9]{4,18})$')::bigint),0)
 INTO highest FROM public.invoices;
 SELECT last_value,is_called INTO last_num,already_called FROM public.sowrix_r4623_invoice_seq;
 IF highest>0 THEN
   PERFORM setval('public.sowrix_r4623_invoice_seq'::regclass,
      GREATEST(highest,CASE WHEN already_called THEN last_num ELSE 0 END),true);
 END IF;
 SELECT COALESCE(MAX(substring(quotation_number FROM '^SW/QT/([0-9]{4,18})$')::bigint),0)
 INTO highest FROM public.quotations;
 SELECT last_value,is_called INTO last_num,already_called FROM public.sowrix_r4623_quote_seq;
 IF highest>0 THEN
   PERFORM setval('public.sowrix_r4623_quote_seq'::regclass,
      GREATEST(highest,CASE WHEN already_called THEN last_num ELSE 0 END),true);
 END IF;
 SELECT COALESCE(MAX(substring(ticket_number FROM '^SW/TK/([0-9]{4,18})$')::bigint),0)
 INTO highest FROM public.support_tickets;
 SELECT last_value,is_called INTO last_num,already_called FROM public.sowrix_r4623_ticket_seq;
 IF highest>0 THEN
   PERFORM setval('public.sowrix_r4623_ticket_seq'::regclass,
      GREATEST(highest,CASE WHEN already_called THEN last_num ELSE 0 END),true);
 END IF;
END;
$align$;

-- Unique constraints only apply to this release's automatically issued formats.
-- Existing customer-specific legacy numbers remain untouched, even if duplicate.
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_r4623_invoice_number_unique
 ON public.invoices(invoice_number) WHERE invoice_number ~ '^SW/INV/[0-9]{4,}$';
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_r4623_quote_number_unique
 ON public.quotations(quotation_number) WHERE quotation_number ~ '^SW/QT/[0-9]{4,}$';
CREATE UNIQUE INDEX IF NOT EXISTS sowrix_r4623_ticket_number_unique
 ON public.support_tickets(ticket_number) WHERE ticket_number ~ '^SW/TK/[0-9]{4,}$';

-- Trigger runs on the server, even for CSV imports, direct REST writes and
-- concurrent requests. Never allow callers to pick or rewrite issued numbers.
CREATE OR REPLACE FUNCTION public.sowrix_r4623_business_number_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
BEGIN
 IF TG_TABLE_NAME = 'invoices' THEN
   IF TG_OP='INSERT' THEN
     NEW.invoice_number:='SW/INV/'||lpad(nextval('public.sowrix_r4623_invoice_seq'::regclass)::text,4,'0');
   ELSE
     NEW.invoice_number:=OLD.invoice_number;
   END IF;
   -- No discount column exists in the current schema. Keep totals aligned
   -- for new invoices or when amounts are edited; do not rewrite old totals.
   IF TG_OP='INSERT' THEN
     NEW.total_amount:=round(NEW.subtotal + COALESCE(NEW.tax_amount,0),2);
   ELSIF NEW.subtotal IS DISTINCT FROM OLD.subtotal
      OR NEW.tax_amount IS DISTINCT FROM OLD.tax_amount
      OR NEW.total_amount IS DISTINCT FROM OLD.total_amount THEN
     NEW.total_amount:=round(NEW.subtotal + COALESCE(NEW.tax_amount,0),2);
   END IF;
 ELSIF TG_TABLE_NAME = 'quotations' THEN
   IF TG_OP='INSERT' THEN
     NEW.quotation_number:='SW/QT/'||lpad(nextval('public.sowrix_r4623_quote_seq'::regclass)::text,4,'0');
   ELSE
     NEW.quotation_number:=OLD.quotation_number;
   END IF;
   IF TG_OP='INSERT' THEN
     NEW.total_amount:=round(NEW.subtotal + COALESCE(NEW.tax_amount,0),2);
   ELSIF NEW.subtotal IS DISTINCT FROM OLD.subtotal
      OR NEW.tax_amount IS DISTINCT FROM OLD.tax_amount
      OR NEW.total_amount IS DISTINCT FROM OLD.total_amount THEN
     NEW.total_amount:=round(NEW.subtotal + COALESCE(NEW.tax_amount,0),2);
   END IF;
 ELSIF TG_TABLE_NAME = 'support_tickets' THEN
   IF TG_OP='INSERT' THEN
     NEW.ticket_number:='SW/TK/'||lpad(nextval('public.sowrix_r4623_ticket_seq'::regclass)::text,4,'0');
   ELSIF NULLIF(btrim(OLD.ticket_number),'') IS NOT NULL THEN
     NEW.ticket_number:=OLD.ticket_number;
   ELSE
     NEW.ticket_number:='SW/TK/'||lpad(nextval('public.sowrix_r4623_ticket_seq'::regclass)::text,4,'0');
   END IF;
 ELSE
   RAISE EXCEPTION 'Unsupported numbering table' USING ERRCODE='22023';
 END IF;
 RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.sowrix_r4623_business_number_trigger()
 FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS sowrix_r4623_number_invoice ON public.invoices;
CREATE TRIGGER sowrix_r4623_number_invoice BEFORE INSERT OR UPDATE
 ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.sowrix_r4623_business_number_trigger();
DROP TRIGGER IF EXISTS sowrix_r4623_number_quote ON public.quotations;
CREATE TRIGGER sowrix_r4623_number_quote BEFORE INSERT OR UPDATE
 ON public.quotations FOR EACH ROW EXECUTE FUNCTION public.sowrix_r4623_business_number_trigger();
DROP TRIGGER IF EXISTS sowrix_r4623_number_ticket ON public.support_tickets;
CREATE TRIGGER sowrix_r4623_number_ticket BEFORE INSERT OR UPDATE
 ON public.support_tickets FOR EACH ROW EXECUTE FUNCTION public.sowrix_r4623_business_number_trigger();

-- Historical tickets without a number get a permanent one exactly once.
-- No existing nonempty number is changed. For invoices and quotations a prior
-- NOT NULL constraint guarantees a historical number is already present.
UPDATE public.support_tickets SET ticket_number=NULL
 WHERE NULLIF(btrim(ticket_number),'') IS NULL;

COMMENT ON FUNCTION public.sowrix_r4623_business_number_trigger() IS
 'R46.23 server-generated immutable invoice, quote and support-ticket display numbers; invoice and quote totals calculated from subtotal and tax.';
NOTIFY pgrst, 'reload schema';
COMMIT;
