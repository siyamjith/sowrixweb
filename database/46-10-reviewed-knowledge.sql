-- SOWRIX R46.10: published public FAQ with independent Admin review.
-- Additive. Apply manually after backing up and restoring R46.7+ staging database.
-- Does not call Gemini, send email, mutate previous tables or grant direct table access.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.sowrix_require_secure_session(boolean)') IS NULL
    OR to_regprocedure('public.sowrix_access_admin()') IS NULL
    OR to_regprocedure('public.sowrix_user_active(uuid)') IS NULL
    OR to_regprocedure('public.sowrix_r467_board(text)') IS NULL
 THEN RAISE EXCEPTION 'Install and verify earlier SOWRIX migrations before R46.10'; END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.sowrix_r4610_public_faq (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 question text NOT NULL CHECK(length(btrim(question)) BETWEEN 8 AND 180),
 answer text NOT NULL CHECK(length(btrim(answer)) BETWEEN 20 AND 1200),
 category text NOT NULL DEFAULT 'general' CHECK(category IN ('general','services','careers','contact','support','privacy')),
 state text NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','review','published','retracted')),
 created_by uuid NOT NULL REFERENCES auth.users(id),
 reviewed_by uuid REFERENCES auth.users(id),
 reviewed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sowrix_r4610_faq_public_idx
 ON public.sowrix_r4610_public_faq(state,updated_at DESC);
CREATE TABLE IF NOT EXISTS public.sowrix_r4610_faq_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 faq_id uuid NOT NULL REFERENCES public.sowrix_r4610_public_faq(id),
 action text NOT NULL CHECK(action IN ('draft','review','publish','retract')),
 actor_id uuid NOT NULL REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sowrix_r4610_public_faq ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_r4610_faq_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_r4610_public_faq FROM PUBLIC,anon,authenticated;
REVOKE ALL ON public.sowrix_r4610_faq_audit FROM PUBLIC,anon,authenticated;

-- Public response includes ONLY reviewed, published, bounded FAQ text. It has
-- no relation to customer records and exposes neither author nor reviewer IDs.
CREATE OR REPLACE FUNCTION public.sowrix_r4610_public_faq() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.updated_at DESC) FROM (
   SELECT left(question,180) AS question,left(answer,1200) AS answer,category,updated_at
   FROM public.sowrix_r4610_public_faq
   WHERE state='published' ORDER BY updated_at DESC LIMIT 40
 ) x),'[]'::jsonb);
END $fn$;

CREATE OR REPLACE FUNCTION public.sowrix_r4610_faq_board() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_user_active(auth.uid()) OR NOT public.sowrix_access_admin()
 THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
 RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.updated_at DESC) FROM (
  SELECT id,question,answer,category,state,created_at,updated_at,
         created_by=auth.uid() AS is_creator,
         reviewed_at IS NOT NULL AS was_reviewed
  FROM public.sowrix_r4610_public_faq ORDER BY updated_at DESC LIMIT 100
 ) x),'[]'::jsonb);
END $fn$;

-- Review is independent: creator cannot publish their own draft. Published
-- content is immutable; revised information must be re-created and reviewed.
CREATE OR REPLACE FUNCTION public.sowrix_r4610_faq_apply(p_action text,p_data jsonb DEFAULT '{}'::jsonb)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v_id uuid;v_question text;v_answer text;v_category text;v_ok boolean;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF NOT public.sowrix_user_active(auth.uid()) OR NOT public.sowrix_access_admin()
 THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
 IF p_data IS NULL OR jsonb_typeof(p_data) <> 'object' OR length(p_data::text)>2200
 THEN RAISE EXCEPTION 'Invalid FAQ input' USING ERRCODE='22023'; END IF;
 IF p_action='draft' THEN
  v_question=btrim(p_data->>'question');v_answer=btrim(p_data->>'answer');
  v_category=coalesce(p_data->>'category','general');
  IF length(v_question) NOT BETWEEN 8 AND 180 OR length(v_answer) NOT BETWEEN 20 AND 1200
     OR v_category NOT IN ('general','services','careers','contact','support','privacy')
  THEN RAISE EXCEPTION 'Invalid FAQ fields' USING ERRCODE='22023'; END IF;
  -- FAQ content is for public display: private customer/employee details must not be entered.
  INSERT INTO public.sowrix_r4610_public_faq(question,answer,category,created_by)
    VALUES(v_question,v_answer,v_category,auth.uid()) RETURNING id INTO v_id;
 ELSIF p_action IN ('review','publish','retract') THEN
  v_id=NULLIF(p_data->>'id','')::uuid;
  IF v_id IS NULL THEN RAISE EXCEPTION 'Missing FAQ id' USING ERRCODE='22023'; END IF;
  IF p_action='review' THEN
   UPDATE public.sowrix_r4610_public_faq SET state='review',updated_at=now()
    WHERE id=v_id AND state='draft' AND created_by=auth.uid();
  ELSIF p_action='publish' THEN
   UPDATE public.sowrix_r4610_public_faq SET state='published',reviewed_by=auth.uid(),
       reviewed_at=now(),updated_at=now()
    WHERE id=v_id AND state='review' AND created_by<>auth.uid();
  ELSE
   UPDATE public.sowrix_r4610_public_faq SET state='retracted',updated_at=now()
    WHERE id=v_id AND state='published';
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'FAQ state or independent review check failed' USING ERRCODE='42501'; END IF;
 ELSE RAISE EXCEPTION 'Unknown FAQ action' USING ERRCODE='22023'; END IF;
 INSERT INTO public.sowrix_r4610_faq_audit(faq_id,action,actor_id)
 VALUES(v_id,p_action,auth.uid());
 RETURN true;
END $fn$;

REVOKE ALL ON FUNCTION public.sowrix_r4610_public_faq() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r4610_public_faq() TO anon,authenticated;
REVOKE ALL ON FUNCTION public.sowrix_r4610_faq_board() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r4610_faq_board() TO authenticated;
REVOKE ALL ON FUNCTION public.sowrix_r4610_faq_apply(text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_r4610_faq_apply(text,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
