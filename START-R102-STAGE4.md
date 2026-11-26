# R102 Stage 4 — Accepted Quotation → Project Creation

Builds on Stage 3. The workspace shows **Create Project** only for accepted, unlinked quotations and only to Admin/Super Admin. The user must confirm before invoking the database RPC.

The RPC locks the quotation row, verifies the caller role, accepted status, current validity, and client reference, and creates a project using quotation title/scope and the existing client. It links the quotation to the project and writes an audit event in one transaction. A second/retried call returns the already-linked project instead of creating a duplicate. The quoted amount is returned in the RPC result for review but is not written into the project table because the existing projects schema has no quotation amount columns.

## Database
- Stage 3 has no migration.
- Apply `database/66-r102-accepted-quotation-project-creation.sql` only to a backed-up staging database with prior migrations through 65 verified.
- Run `database/66-verify-read-only.sql` to verify installation and existing links.
- Do not run against production before acceptance.

## Acceptance tests pending
- Accepted valid quote with client and no project: creates one project and links quote.
- Confirm project title, description/scope, client match and planned status.
- Verify amount/tax remain unchanged on quotation.
- Double click/concurrent retry: exactly one project, subsequent call returns existing link.
- Reject draft/sent/rejected/expired quote, missing client, and non-admin role.
- Verify RLS, audit event, and project/quotation module permissions.
- Live staging database tests have not been run.
\n\n## Next stage\nStage 5 adds a guarded, idempotent accepted-quotation-to-draft-invoice workflow. See `START-R102-STAGE5.md`.\n