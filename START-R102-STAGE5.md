# R102 Stage 5 — Accepted Quotation → Draft Invoice

Builds on the Stage 4 release. An Admin/Super Admin can create one draft invoice only after an accepted quotation has been linked to its matching project and client.

## Behavior
- The quotation list shows **Create Draft Invoice** only for accepted quotations that already have a linked project.
- The administrator confirms a due date and explicitly confirms draft creation.
- The database rechecks administrator role, accepted status, current quotation validity, matching project/client, and amount consistency.
- The invoice copies the existing quotation subtotal, tax and total; invoice numbering remains database-generated.
- A unique quotation-to-invoice ledger plus quotation row lock makes retries idempotent; one quotation cannot create multiple invoices through this workflow.
- The invoice is created as `draft`. This workflow does not send email, issue/send the invoice, mark it paid, record a payment, or change the quotation.
- Audit event: `r102_accepted_quotation_draft_invoice_created`.

## Database
- Requires migrations through 66 and the Stage 4 project-creation RPC.
- Back up and restore-test staging before applying `database/67-r102-quotation-draft-invoice.sql`.
- Review `database/67-verify-read-only.sql` after installation.
- Do not apply to production until staging acceptance is complete.

## Staging acceptance (not performed by offline tests)
1. Admin/Super Admin creates a draft invoice from a valid accepted quotation linked to its matching project.
2. Confirm client/project, description, subtotal, tax, total, due date, draft status and automatic invoice number.
3. Retry/double-click and concurrent requests: exactly one invoice and one link.
4. Reject draft/sent/rejected/expired quotations, missing project/client, mismatched project/client, inconsistent amounts, past due dates and non-admin callers.
5. Verify invoice RLS, audit event, invoice permissions and client visibility; verify no email, payment or status transition occurs.
6. Verify existing R102 Stage 1–4 and R101 acceptance suites.

Offline tests do not prove live Supabase authorization, RLS, triggers, concurrency, or email/payment isolation.
