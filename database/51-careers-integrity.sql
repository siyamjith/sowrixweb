-- Additive. Keep existing jobs and applications; audit old orphan rows before VALIDATE.
BEGIN;
ALTER TABLE public.job_applications ADD CONSTRAINT sowrix_application_vacancy_fk
 FOREIGN KEY(job_id) REFERENCES public.jobs(id) ON DELETE RESTRICT NOT VALID;

CREATE FUNCTION public.sowrix_guard_vacancy() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF NEW.status NOT IN ('draft','published','closed','archived') OR NEW.status IS NULL
    OR length(btrim(NEW.title)) NOT BETWEEN 3 AND 160
    OR length(btrim(NEW.description)) NOT BETWEEN 10 AND 12000 THEN
  RAISE EXCEPTION 'Invalid vacancy fields' USING ERRCODE='22023';
 END IF;
 IF TG_OP='UPDATE' AND OLD.status='archived' AND NEW IS DISTINCT FROM OLD THEN
  RAISE EXCEPTION 'Archived vacancies cannot be changed' USING ERRCODE='22023';
 END IF;
 IF NEW.status='published' AND
   (coalesce(length(btrim(NEW.location)),0)=0 OR coalesce(length(btrim(NEW.employment_type)),0)=0) THEN
  RAISE EXCEPTION 'Location and employment type are required to publish' USING ERRCODE='22023';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER sowrix_validate_vacancy BEFORE INSERT OR UPDATE ON public.jobs
 FOR EACH ROW EXECUTE FUNCTION public.sowrix_guard_vacancy();
REVOKE ALL ON FUNCTION public.sowrix_guard_vacancy() FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.sowrix_guard_application_vacancy() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE vacancy_status text;
BEGIN
 IF TG_OP='UPDATE' THEN
  IF NEW.job_id IS DISTINCT FROM OLD.job_id THEN
   RAISE EXCEPTION 'Application vacancy is immutable' USING ERRCODE='22023';
  END IF;
 ELSE
  SELECT status INTO vacancy_status FROM public.jobs WHERE id=NEW.job_id FOR SHARE;
  IF vacancy_status IS DISTINCT FROM 'published' THEN
   RAISE EXCEPTION 'Vacancy is not accepting applications' USING ERRCODE='22023';
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER sowrix_validate_application_vacancy BEFORE INSERT OR UPDATE OF job_id ON public.job_applications
 FOR EACH ROW EXECUTE FUNCTION public.sowrix_guard_application_vacancy();
REVOKE ALL ON FUNCTION public.sowrix_guard_application_vacancy() FROM PUBLIC,anon,authenticated;
COMMIT;
