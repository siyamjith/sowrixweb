# SOWRIX — Launch Package
Updated: 2026-11-26

## Included
- `site/`: compiled public website and portal frontend
- `backend/`: private Python backend
- `database/`: database migrations, including `66-r102-accepted-quotation-project-creation.sql`
- `scripts/`: setup and configuration checks
- `deployment/`: deployment templates
- `RUN-SOWRIX.cmd`, `CHECK-SOWRIX.cmd`
- `.env.example`, `requirements.lock`

## Local Windows start
1. Extract this folder to a writable location (avoid OneDrive-synced folders while testing).
2. Install Python 3.12 and ensure the Windows `py` launcher is available.
3. Copy `.env.example` to `.env`.
4. Fill the required Supabase URL and publishable key, and configure the private server secrets using your existing secure values. Never share `.env` or put server secrets in `site/`.
5. Keep `LOCAL_DEV=true` and `HOST=127.0.0.1` for local-only testing.
6. Double-click `RUN-SOWRIX.cmd`.
7. Open the local address shown by the backend (default `http://127.0.0.1:8158`).

## R102 database prerequisites (Stages 4–5)
Before enabling the quotation handoff workflow:
1. Take and verify a Supabase staging backup.
2. Confirm migrations 1–65 are installed and the required quotations, projects, clients, invoices, audit_logs, automatic invoice numbering, and `sowrix_access_role()` objects exist.
3. Review `database/66-r102-accepted-quotation-project-creation.sql`; apply migration 66 to staging only.
4. Verify Stage 4 with `database/66-verify-read-only.sql` and test accepted-quotation project creation, retry behavior, permissions and RLS.
5. Review `database/67-r102-quotation-draft-invoice.sql`; only after Stage 4 passes, apply migration 67 to staging.
6. Verify Stage 5 with `database/67-verify-read-only.sql`; test draft status, totals, due date, idempotency, role restrictions and client visibility.
7. Complete all acceptance checks in `START-R102-STAGE4.md` and `START-R102-STAGE5.md` before production approval.

Do not apply either migration to production merely by extracting this package. The audit did not connect to or modify your Supabase project.

## Tests
Node.js 22+ is recommended for the included JavaScript test commands. The full project ZIP contains the test suite. In the full project folder:
- `npm run test:offline`
- `npm run test:quotation-workflow`

The local launch package does not contain development dependencies or the complete test suite.

## Security
- Do not copy real `.env` values into support chats or ZIP files.
- Do not expose service-role keys, session keys, mail credentials, AI keys, TURN secrets, or backup keys in browser files.
- Keep the backend bound to localhost during local verification. Use a reviewed HTTPS deployment configuration for public hosting.
