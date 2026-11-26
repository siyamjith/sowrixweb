-- R102 Stage 4 read-only verification. No writes performed.
SELECT to_regprocedure('public.sowrix_r102_create_project_from_quote(uuid)') AS function_installed;
SELECT q.id,q.quotation_number,q.status,q.valid_until,q.client_id,q.project_id,
       p.name AS linked_project_name,p.status AS linked_project_status,p.client_id AS project_client_id
FROM public.quotations q
LEFT JOIN public.projects p ON p.id=q.project_id
WHERE q.status='accepted'
ORDER BY q.updated_at DESC;
SELECT p.id,p.name,p.client_id,p.status,p.created_at
FROM public.projects p
WHERE EXISTS(SELECT 1 FROM public.quotations q WHERE q.project_id=p.id)
ORDER BY p.created_at DESC;
