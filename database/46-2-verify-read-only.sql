-- Run AFTER migration in staging. Presence is not a substitute for RLS/MFA testing.
SELECT to_regclass('public.sowrix_r462_config') IS NOT NULL AS config_present,
       to_regclass('public.sowrix_r462_routing_pool') IS NOT NULL AS routing_pool_present,
       to_regclass('public.sowrix_r462_approvals') IS NOT NULL AS approvals_present,
       to_regprocedure('public.sowrix_r462_route_tickets()') IS NOT NULL AS scheduler_present,
       to_regprocedure('public.sowrix_r462_admin_pulse()') IS NOT NULL AS dashboard_present,
       to_regprocedure('public.sowrix_r462_project_progress(uuid)') IS NOT NULL AS client_progress_present;
SELECT c.auto_route, c.sla_alerts, count(p.user_id) FILTER (WHERE p.enabled) AS authorized_staff_opted_in
FROM public.sowrix_r462_config c LEFT JOIN public.sowrix_r462_routing_pool p ON true
WHERE c.id GROUP BY c.auto_route,c.sla_alerts;
