-- Run only after R46.10 migration on staging. Inspect results as authorized operator.
SELECT to_regclass('public.sowrix_r4610_public_faq') IS NOT NULL AS faq_table_exists,
 to_regclass('public.sowrix_r4610_faq_audit') IS NOT NULL AS faq_audit_exists,
 to_regprocedure('public.sowrix_r4610_public_faq()') IS NOT NULL AS public_faq_function_exists,
 to_regprocedure('public.sowrix_r4610_faq_board()') IS NOT NULL AS admin_board_function_exists,
 to_regprocedure('public.sowrix_r4610_faq_apply(text,jsonb)') IS NOT NULL AS admin_mutation_function_exists;
SELECT tablename, rowsecurity FROM pg_tables
 WHERE schemaname='public' AND tablename IN ('sowrix_r4610_public_faq','sowrix_r4610_faq_audit');
