-- SOWRIX R46.5 additive enterprise workflows, to run ONLY in restored staging first.
-- Explicit operator approval required. No mail, funds, payroll writes, deletes or device actions.
BEGIN;
DO $$BEGIN
 IF to_regprocedure('public.sowrix_r464_admin_overview()') IS NULL
 OR to_regprocedure('public.sowrix_user_record_access(uuid,text,jsonb)') IS NULL
 OR to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NULL
 OR to_regclass('public.sowrix_org_memberships') IS NULL THEN
  RAISE EXCEPTION 'R46.4 enterprise/R16 access migrations required; no R46.5 changes were applied';
 END IF;
END$$;

-- Permission-aware unified search: server-side length limits, result caps, no UUIDs rendered in UI.
-- Only the user's accessible records are considered. Avoid broad SECURITY DEFINER table exposure.
CREATE OR REPLACE FUNCTION public.sowrix_r465_search(p_query text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE q text;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_user_active(auth.uid()) THEN RAISE EXCEPTION 'Active workspace required' USING ERRCODE='42501'; END IF;
 q:=btrim(coalesce(p_query,''));
 IF length(q)<2 OR length(q)>80 OR q LIKE '%\%%' ESCAPE '\' OR q LIKE '%\_%' ESCAPE '\' THEN RAISE EXCEPTION 'Search must be 2-80 characters' USING ERRCODE='22023'; END IF;
 -- All text is returned as data and must be HTML-escaped by the browser.
 RETURN coalesce((WITH matches AS (
  SELECT 'project'::text kind, left(p.name,140) title, left(p.status,40) state,p.updated_at ts
   FROM public.projects p WHERE p.name ILIKE '%'||q||'%' AND public.sowrix_user_record_access(auth.uid(),'projects',to_jsonb(p))
  UNION ALL
  SELECT 'ticket',left(t.subject,140),left(t.status,40),t.updated_at
   FROM public.support_tickets t WHERE (t.subject ILIKE '%'||q||'%' OR t.ticket_number ILIKE '%'||q||'%')
     AND public.sowrix_user_record_access(auth.uid(),'tickets',to_jsonb(t))
  UNION ALL
  SELECT 'invoice',left(i.invoice_number,140),left(i.status,40),i.updated_at
   FROM public.invoices i WHERE i.invoice_number ILIKE '%'||q||'%'
     AND public.sowrix_user_record_access(auth.uid(),'invoices',to_jsonb(i))
  UNION ALL
  SELECT 'article',left(k.title,140),'Published',k.updated_at
   FROM public.sowrix_r464_knowledge k WHERE k.published AND k.title ILIKE '%'||q||'%'
    AND (k.audience='all_signed_in' OR public.sowrix_access_role()<>'client')
 ) SELECT jsonb_agg(x ORDER BY x.ts DESC) FROM
    (SELECT kind,title,state,ts FROM matches ORDER BY ts DESC LIMIT 40) x), '[]'::jsonb);
END $fn$;

-- Document register stores metadata ONLY. Existing private Storage/uploader stays the file source.
-- This module deliberately never makes an unauthenticated download URL or publicly serves binaries.
CREATE TABLE IF NOT EXISTS public.sowrix_r465_documents(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), owner_id uuid NOT NULL REFERENCES auth.users(id),
 organization_id uuid REFERENCES public.clients(id), title text NOT NULL CHECK(length(title) BETWEEN 4 AND 150),
 category text NOT NULL CHECK(category IN ('contract','policy','report','other')),
 audience text NOT NULL CHECK(audience IN ('internal','client_shared')),
 expires_on date, state text NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','approved')),
 version_no integer NOT NULL DEFAULT 1 CHECK(version_no>=1),
 approved_by uuid REFERENCES auth.users(id), approved_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(audience<>'client_shared' OR organization_id IS NOT NULL)
);
CREATE TABLE IF NOT EXISTS public.sowrix_r465_document_versions(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),document_id uuid NOT NULL REFERENCES public.sowrix_r465_documents(id),
 version_no integer NOT NULL,summary text NOT NULL CHECK(length(summary) BETWEEN 10 AND 1000),
 authored_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(document_id,version_no)
);
CREATE INDEX IF NOT EXISTS sowrix_r465_documents_expiry ON public.sowrix_r465_documents(expires_on) WHERE state='approved';
CREATE INDEX IF NOT EXISTS sowrix_r465_docs_owner ON public.sowrix_r465_documents(owner_id,updated_at DESC);
CREATE INDEX IF NOT EXISTS sowrix_r465_docs_org ON public.sowrix_r465_documents(organization_id,state);
ALTER TABLE public.sowrix_r465_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_r465_document_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_r465_documents,public.sowrix_r465_document_versions FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.sowrix_r465_organization_choices() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.organization_name) FROM (
  SELECT id,left(organization_name,140) organization_name FROM public.clients
  WHERE status='active' ORDER BY organization_name LIMIT 100)x),'[]'::jsonb);
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r465_document_list() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_user_active(auth.uid()) THEN RAISE EXCEPTION 'Active user required' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.updated_at DESC) FROM (
 SELECT d.id,d.title,d.category,d.audience,d.state,d.version_no,d.expires_on,d.updated_at,
  d.owner_id=auth.uid() AS is_owner
 FROM public.sowrix_r465_documents d
 WHERE public.sowrix_access_admin() OR d.owner_id=auth.uid()
   OR (d.state='approved' AND d.audience='client_shared' AND EXISTS (
     SELECT 1 FROM public.sowrix_org_memberships m
     WHERE m.user_id=auth.uid() AND m.organization_id=d.organization_id AND m.status='active'))
 ORDER BY d.updated_at DESC LIMIT 100
 ) x),'[]'::jsonb);
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r465_document_create(
 p_title text,p_category text,p_audience text,p_summary text,p_org uuid DEFAULT NULL,p_expires date DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE doc uuid;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() AND NOT (public.sowrix_access_role()<>'client' AND public.sowrix_has_module_access('documents'))
 THEN RAISE EXCEPTION 'Staff document permission required' USING ERRCODE='42501'; END IF;
 IF length(btrim(coalesce(p_title,''))) NOT BETWEEN 4 AND 150 OR
 length(btrim(coalesce(p_summary,''))) NOT BETWEEN 10 AND 1000 OR
 p_category NOT IN ('contract','policy','report','other') OR p_audience NOT IN ('internal','client_shared') OR
 (p_audience='client_shared' AND p_org IS NULL) OR
 (p_expires IS NOT NULL AND p_expires < current_date)
 THEN RAISE EXCEPTION 'Invalid document metadata' USING ERRCODE='22023'; END IF;
 -- Only Admin can prepare client-shared metadata (cross-organization scope).
 IF p_audience='client_shared' AND NOT public.sowrix_access_admin() THEN
  RAISE EXCEPTION 'Admin must review client document scope' USING ERRCODE='42501';END IF;
 IF p_org IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.clients WHERE id=p_org AND status='active')
 THEN RAISE EXCEPTION 'Organization unavailable' USING ERRCODE='42501'; END IF;
 INSERT INTO public.sowrix_r465_documents(owner_id,organization_id,title,category,audience,expires_on)
 VALUES(auth.uid(),p_org,btrim(p_title),p_category,p_audience,p_expires) RETURNING id INTO doc;
 INSERT INTO public.sowrix_r465_document_versions(document_id,version_no,summary,authored_by)
 VALUES(doc,1,btrim(p_summary),auth.uid());
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r465_document_draft','documents','record',jsonb_build_object('client_shared',p_audience='client_shared'));
 RETURN doc;
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r465_document_version(p_document uuid,p_summary text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE d public.sowrix_r465_documents%ROWTYPE;next_no integer;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 SELECT * INTO d FROM public.sowrix_r465_documents WHERE id=p_document FOR UPDATE;
 IF NOT FOUND OR (d.owner_id<>auth.uid() AND NOT public.sowrix_access_admin()) THEN
  RAISE EXCEPTION 'Document unavailable' USING ERRCODE='42501';END IF;
 IF length(btrim(coalesce(p_summary,''))) NOT BETWEEN 10 AND 1000 THEN RAISE EXCEPTION 'Invalid version summary' USING ERRCODE='22023';END IF;
 next_no:=d.version_no+1;
 UPDATE public.sowrix_r465_documents SET version_no=next_no,state='draft',approved_by=NULL,approved_at=NULL,updated_at=now() WHERE id=p_document;
 INSERT INTO public.sowrix_r465_document_versions(document_id,version_no,summary,authored_by)
 VALUES(p_document,next_no,btrim(p_summary),auth.uid());
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r465_document_new_version','documents','record',jsonb_build_object('version',next_no));
 RETURN next_no;
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r465_document_approve(p_document uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE d public.sowrix_r465_documents%ROWTYPE;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin approval required' USING ERRCODE='42501';END IF;
 SELECT * INTO d FROM public.sowrix_r465_documents WHERE id=p_document FOR UPDATE;
 IF NOT FOUND OR d.state<>'draft' THEN RETURN false;END IF;
 IF d.owner_id=auth.uid() OR EXISTS(SELECT 1 FROM public.sowrix_r465_document_versions v
  WHERE v.document_id=d.id AND v.version_no=d.version_no AND v.authored_by=auth.uid())
 THEN RAISE EXCEPTION 'Independent reviewer required' USING ERRCODE='42501';END IF;
 UPDATE public.sowrix_r465_documents SET state='approved',approved_by=auth.uid(),approved_at=now(),updated_at=now() WHERE id=p_document;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r465_document_approved','documents','record',jsonb_build_object('version',d.version_no));
 RETURN true;
END $fn$;

-- Employee self-service: review queue, NOT an automatic official attendance correction.
CREATE TABLE IF NOT EXISTS public.sowrix_r465_staff_requests(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),created_by uuid NOT NULL REFERENCES auth.users(id),
 category text NOT NULL CHECK(category IN ('attendance_review','hr_question','document_request')),
 message text NOT NULL CHECK(length(message) BETWEEN 10 AND 1500),
 state text NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','reviewed','declined')),
 reviewer_id uuid REFERENCES auth.users(id),review_note text NOT NULL DEFAULT '' CHECK(length(review_note)<=500),
 created_at timestamptz NOT NULL DEFAULT now(),reviewed_at timestamptz
);
CREATE INDEX IF NOT EXISTS sowrix_r465_staff_requests_pending ON public.sowrix_r465_staff_requests(created_at DESC) WHERE state='pending';
ALTER TABLE public.sowrix_r465_staff_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_r465_staff_requests FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.sowrix_r465_request_submit(p_category text,p_message text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE rid uuid;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF public.sowrix_access_role()='client' OR NOT public.sowrix_user_active(auth.uid()) THEN
  RAISE EXCEPTION 'Employee access required' USING ERRCODE='42501';END IF;
 IF p_category NOT IN ('attendance_review','hr_question','document_request') OR
    length(btrim(coalesce(p_message,''))) NOT BETWEEN 10 AND 1500 THEN RAISE EXCEPTION 'Invalid request' USING ERRCODE='22023';END IF;
 -- Prevent accidental repeated button-submissions from filling the queue.
 IF (SELECT count(*) FROM public.sowrix_r465_staff_requests WHERE created_by=auth.uid() AND state='pending')>=10
 THEN RAISE EXCEPTION 'Please resolve existing requests first' USING ERRCODE='22023';END IF;
 INSERT INTO public.sowrix_r465_staff_requests(created_by,category,message)
 VALUES(auth.uid(),p_category,btrim(p_message)) RETURNING id INTO rid;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r465_staff_request','hr','record',jsonb_build_object('category',p_category));
 RETURN rid;
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r465_request_list() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE reviewer boolean;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 reviewer:=public.sowrix_access_admin() OR public.sowrix_access_role() IN ('hr','hr_staff','hr_manager');
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.created_at DESC) FROM (
 SELECT r.id,r.category,r.message,r.state,r.review_note,r.created_at,
 CASE WHEN reviewer THEN r.created_by::text ELSE NULL END AS requester_id
 FROM public.sowrix_r465_staff_requests r
 WHERE reviewer OR r.created_by=auth.uid()
 ORDER BY r.created_at DESC LIMIT 80)x),'[]'::jsonb);
END $fn$;
CREATE OR REPLACE FUNCTION public.sowrix_r465_request_review(p_id uuid,p_accept boolean,p_note text DEFAULT '')
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE r public.sowrix_r465_staff_requests%ROWTYPE;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT (public.sowrix_access_admin() OR public.sowrix_access_role() IN ('hr','hr_staff','hr_manager'))
 THEN RAISE EXCEPTION 'HR review required' USING ERRCODE='42501';END IF;
 IF length(coalesce(p_note,''))>500 THEN RAISE EXCEPTION 'Review note too long' USING ERRCODE='22023';END IF;
 SELECT * INTO r FROM public.sowrix_r465_staff_requests WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR r.state<>'pending' THEN RETURN false;END IF;
 IF r.created_by=auth.uid() THEN RAISE EXCEPTION 'Cannot review own request' USING ERRCODE='42501'; END IF;
 UPDATE public.sowrix_r465_staff_requests SET state=CASE WHEN p_accept THEN 'reviewed' ELSE 'declined' END,
  reviewer_id=auth.uid(),reviewed_at=now(),review_note=coalesce(p_note,'') WHERE id=p_id;
 INSERT INTO public.audit_logs(actor_id,action,target_type,target_id,details)
 VALUES(auth.uid(),'r465_staff_request_review','hr','record',jsonb_build_object('accepted_for_review',p_accept));
 RETURN true;
END $fn$;

-- Client-specific business overview; no raw invoice values or cross-org joins returned.
CREATE OR REPLACE FUNCTION public.sowrix_r465_client_dashboard() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF public.sowrix_access_role()<>'client' THEN RAISE EXCEPTION 'Client session required' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object(
 'active_projects',(SELECT count(*) FROM public.projects p WHERE p.status NOT IN ('completed','cancelled') AND public.sowrix_user_record_access(auth.uid(),'projects',to_jsonb(p))),
 'open_tickets',(SELECT count(*) FROM public.support_tickets t WHERE t.status NOT IN ('resolved','closed','cancelled') AND public.sowrix_user_record_access(auth.uid(),'tickets',to_jsonb(t))),
 'unpaid_invoices',(SELECT count(*) FROM public.invoices i WHERE lower(i.status) NOT IN ('paid','cancelled','void','draft') AND public.sowrix_user_record_access(auth.uid(),'invoices',to_jsonb(i))),
 'recent_projects',(SELECT coalesce(jsonb_agg(x ORDER BY x.updated_at DESC),'[]'::jsonb) FROM
   (SELECT left(p.name,140) name,left(p.status,40) status,p.updated_at FROM public.projects p
    WHERE public.sowrix_user_record_access(auth.uid(),'projects',to_jsonb(p)) ORDER BY p.updated_at DESC LIMIT 10)x));
END $fn$;

-- Authorised admin diagnostics derived from private metadata only; no sensitive record content.
CREATE OR REPLACE FUNCTION public.sowrix_r465_ops_summary() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_access_admin() THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object(
 'pending_staff_requests',(SELECT count(*) FROM public.sowrix_r465_staff_requests WHERE state='pending'),
 'pending_document_approvals',(SELECT count(*) FROM public.sowrix_r465_documents WHERE state='draft'),
 'expiring_documents_30d',(SELECT count(*) FROM public.sowrix_r465_documents WHERE state='approved' AND expires_on BETWEEN current_date AND current_date+30),
 'expired_documents',(SELECT count(*) FROM public.sowrix_r465_documents WHERE state='approved' AND expires_on<current_date));
END $fn$;

DO $$DECLARE f record;BEGIN
 FOR f IN SELECT p.oid::regprocedure fn FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname LIKE 'sowrix_r465_%' LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon',f.fn);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.fn);
 END LOOP;
END$$;
NOTIFY pgrst,'reload schema';
COMMIT;
