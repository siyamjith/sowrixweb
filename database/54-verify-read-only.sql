-- Read-only installation and padding checks; does not advance counters.
SELECT public.sowrix_r100_format('1')='0001' AS first_number, public.sowrix_r100_format('10000')='10000' AS no_truncation;
SELECT event_object_table,trigger_name,event_manipulation FROM information_schema.triggers WHERE trigger_schema='public' AND trigger_name LIKE 'sowrix_r100_%' ORDER BY 1,2,3;
SELECT table_name,column_name FROM information_schema.columns WHERE table_schema='public' AND column_name='sowrix_reference' ORDER BY 1;
