-- Read-only check. No changes or schema mutations.
SELECT
 to_regprocedure('public.sowrix_r467_board(text)') IS NOT NULL AS r467_installed,
 to_regprocedure('public.sowrix_r466_board(text)') IS NOT NULL AS r466_installed,
 to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NOT NULL AS secure_session_installed,
 to_regprocedure('public.sowrix_r4610_public_faq()') IS NOT NULL AS r4610_already_installed;
