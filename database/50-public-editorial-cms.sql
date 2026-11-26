-- Additive website editorial data. No writes to operational, tenant or recruitment tables.
BEGIN;
CREATE TABLE public.sowrix_cms_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 kind text NOT NULL CHECK(kind IN ('services','industries','solutions','portfolio','insights','careers','announcements','contact','seo','knowledge')),
 slug text NOT NULL CHECK(slug ~ '^[a-z0-9][a-z0-9-]{0,63}$'),
 head integer NOT NULL CHECK(head>0),
 published integer,
 archived boolean NOT NULL DEFAULT false,
 UNIQUE(kind,slug),
 CHECK (NOT archived OR published IS NULL)
);
CREATE TABLE public.sowrix_cms_revisions (
 entry uuid REFERENCES public.sowrix_cms_entries(id),
 version integer NOT NULL,
 author uuid NOT NULL,
 data jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(entry,version)
);
CREATE TABLE public.sowrix_cms_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 entry uuid NOT NULL REFERENCES public.sowrix_cms_entries(id),
 version integer NOT NULL,
 actor uuid NOT NULL,
 action text NOT NULL,
 at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON public.sowrix_cms_events(entry,id DESC);
ALTER TABLE public.sowrix_cms_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_cms_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sowrix_cms_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sowrix_cms_entries,public.sowrix_cms_revisions,public.sowrix_cms_events FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.sowrix_cms_admin(p_action text,p_kind text,p_slug text,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE e public.sowrix_cms_entries; r public.sowrix_cms_revisions; payload jsonb; who uuid:=auth.uid(); v integer; k text;
BEGIN
 PERFORM public.sowrix_require_secure_session(false);
 IF who IS NULL OR NOT coalesce(public.sowrix_user_active(who),false) OR NOT coalesce(public.sowrix_access_admin(),false) THEN
  RAISE EXCEPTION 'CMS admin required' USING ERRCODE='42501';
 END IF;
 IF p_kind IS NULL OR p_kind NOT IN ('services','industries','solutions','portfolio','insights','careers','announcements','contact','seo','knowledge') THEN
  RAISE EXCEPTION 'Invalid kind' USING ERRCODE='22023';
 END IF;
 IF p_action='list' THEN
  RETURN coalesce((SELECT jsonb_agg(x ORDER BY x.slug) FROM
   (SELECT slug,head,published,archived FROM public.sowrix_cms_entries WHERE kind=p_kind ORDER BY slug LIMIT 500) x),'[]'::jsonb);
 END IF;
 IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9-]{0,63}$' OR
   (p_kind='seo' AND p_slug NOT IN ('home','about','services','industries','solutions','portfolio','insights','careers','defensowrix')) THEN
  RAISE EXCEPTION 'Invalid slug' USING ERRCODE='22023';
 END IF;
 SELECT * INTO e FROM public.sowrix_cms_entries WHERE kind=p_kind AND slug=p_slug FOR UPDATE;
 IF p_action='preview' THEN
  IF e.id IS NULL THEN RAISE EXCEPTION 'Missing entry' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('entry',to_jsonb(e),
   'revision',(SELECT data FROM public.sowrix_cms_revisions WHERE entry=e.id AND version=e.head),
   'history',(SELECT coalesce(jsonb_agg(h ORDER BY h.id DESC),'[]'::jsonb) FROM
    (SELECT id,version,action,actor,at FROM public.sowrix_cms_events WHERE entry=e.id ORDER BY id DESC LIMIT 100) h));
 END IF;
 IF p_action NOT IN ('save','publish','unpublish','archive','restore') OR jsonb_typeof(p_data) IS DISTINCT FROM 'object'
    OR octet_length(p_data::text)>15000 OR jsonb_typeof(p_data->'head') IS DISTINCT FROM 'number' THEN
  RAISE EXCEPTION 'Invalid request' USING ERRCODE='22023';
 END IF;
 IF (p_data->>'head')::integer<>coalesce(e.head,0) THEN RAISE EXCEPTION 'Revision conflict' USING ERRCODE='40001'; END IF;
 IF p_action='save' THEN
  IF coalesce(e.archived,false) THEN RAISE EXCEPTION 'Restore an archived entry first' USING ERRCODE='22023'; END IF;
  payload:=p_data->'content';
  IF jsonb_typeof(payload) IS DISTINCT FROM 'object' OR jsonb_typeof(payload->'title') IS DISTINCT FROM 'string'
    OR length(btrim(payload->>'title')) NOT BETWEEN 3 AND 120 OR jsonb_typeof(payload->'body') IS DISTINCT FROM 'string'
    OR length(btrim(payload->>'body')) NOT BETWEEN 10 AND 3000 THEN
   RAISE EXCEPTION 'Invalid plain text fields' USING ERRCODE='22023';
  END IF;
  FOR k IN SELECT jsonb_object_keys(payload) LOOP
   IF k NOT IN ('title','body','image','question_en','question_ta','question_tl','answer_ta','answer_tl')
     OR jsonb_typeof(payload->k)<>'string' OR payload->>k ~ '[<>]' OR length(payload->>k)>3000
     OR (k NOT IN ('title','body','image') AND p_kind<>'knowledge')
     OR (k LIKE 'question_%' AND length(btrim(payload->>k)) NOT BETWEEN 8 AND 180) THEN
    RAISE EXCEPTION 'Invalid content field' USING ERRCODE='22023';
   END IF;
  END LOOP;
  IF coalesce(payload->>'image','') NOT IN ('','services','solutions','portfolio','insights','careers','contact')
    OR (p_kind IN ('knowledge','seo') AND coalesce(payload->>'image','')<>'')
    OR (p_kind='knowledge' AND (NOT payload ? 'question_en'
       OR (payload ? 'question_ta')<>(payload ? 'answer_ta') OR (payload ? 'question_tl')<>(payload ? 'answer_tl')
       OR coalesce(length(btrim(payload->>'answer_ta')),10)<10 OR coalesce(length(btrim(payload->>'answer_tl')),10)<10))
    OR (p_kind='seo' AND length(payload->>'body')>320) THEN
   RAISE EXCEPTION 'Invalid media, translation or metadata' USING ERRCODE='22023';
  END IF;
  IF e.id IS NULL THEN
   INSERT INTO public.sowrix_cms_entries(kind,slug,head) VALUES(p_kind,p_slug,1) RETURNING * INTO e;
   v:=1;
  ELSE
   UPDATE public.sowrix_cms_entries SET head=head+1 WHERE id=e.id RETURNING head INTO v;
  END IF;
  INSERT INTO public.sowrix_cms_revisions(entry,version,author,data) VALUES(e.id,v,who,payload);
 ELSE
  IF e.id IS NULL THEN RAISE EXCEPTION 'Missing entry' USING ERRCODE='22023'; END IF;
  v:=e.head;
  IF p_action='publish' THEN
   SELECT * INTO r FROM public.sowrix_cms_revisions WHERE entry=e.id AND version=e.head;
   IF e.archived OR r.author=who THEN RAISE EXCEPTION 'Independent reviewer required' USING ERRCODE='42501'; END IF;
   UPDATE public.sowrix_cms_entries SET published=head WHERE id=e.id;
  ELSIF p_action='unpublish' THEN
   UPDATE public.sowrix_cms_entries SET published=NULL WHERE id=e.id;
  ELSIF p_action='archive' THEN
   UPDATE public.sowrix_cms_entries SET published=NULL,archived=true WHERE id=e.id;
  ELSIF p_action='restore' THEN
   SELECT * INTO r FROM public.sowrix_cms_revisions WHERE entry=e.id AND version=(p_data->>'version')::integer;
   IF NOT FOUND THEN RAISE EXCEPTION 'Missing revision' USING ERRCODE='22023'; END IF;
   UPDATE public.sowrix_cms_entries SET head=head+1,archived=false WHERE id=e.id RETURNING head INTO v;
   INSERT INTO public.sowrix_cms_revisions(entry,version,author,data) VALUES(e.id,v,who,r.data);
  END IF;
 END IF;
 INSERT INTO public.sowrix_cms_events(entry,version,actor,action) VALUES(e.id,v,who,p_action);
 RETURN jsonb_build_object('saved',true,'head',v);
END $$;
REVOKE ALL ON FUNCTION public.sowrix_cms_admin(text,text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_cms_admin(text,text,text,jsonb) TO authenticated;

CREATE FUNCTION public.sowrix_cms_published(p_kind text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(x ORDER BY x.slug),'[]'::jsonb) FROM (
  SELECT e.slug,r.data AS content FROM public.sowrix_cms_entries e
  JOIN public.sowrix_cms_revisions r ON r.entry=e.id AND r.version=e.published
  WHERE e.kind=p_kind AND NOT e.archived ORDER BY e.slug LIMIT 100
 ) x
$$;
REVOKE ALL ON FUNCTION public.sowrix_cms_published(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sowrix_cms_published(text) TO service_role;
COMMIT;
