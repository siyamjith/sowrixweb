"""R46.2 opt-in server scheduler. No user-data reads, writes or emails at import.

Cron/worker is intentionally single-instance. Database row locks and event unique
keys protect assignment and SLA events from retry duplication.
"""
import asyncio
import logging

LOG = logging.getLogger('sowrix.operations')

async def operations_cycle(provider, settings):
    if not (settings.ready and settings.operations_automation_enabled):
        return {'routing': 0, 'sla': 0, 'skipped': True}
    routed = await provider.rpc('sowrix_r462_route_tickets', {}, service=True)
    alerted = await provider.rpc('sowrix_r462_sla_alerts', {}, service=True)
    snapshot = await provider.rpc('sowrix_r462_record_daily_snapshot', {}, service=True)
    # R46.7: opt-in idempotent IN-APP sales follow-up notifications; never sends email.
    crm_alerts = 0
    if getattr(settings,'r467_followup_alerts_enabled',False):
        crm_alerts = int(await provider.rpc('sowrix_r467_followup_reminders',{},service=True) or 0)
    return {'routing': int(routed or 0), 'sla': int(alerted or 0), 'daily_snapshot': bool(snapshot), 'crm_alerts': crm_alerts, 'skipped': False}

async def operations_worker(provider, settings):
    # Startup delay allows migrations/configuration to settle. The system does
    # not run at all unless the operator explicitly enables its private flag.
    await asyncio.sleep(45)
    while True:
        try:
            result = await operations_cycle(provider, settings)
            LOG.info('R46.2 operations cycle: routed=%d sla=%d', result['routing'], result['sla'])
        except (ValueError, TypeError, KeyError, RuntimeError):
            LOG.warning('R46.2 operation cycle rejected; verify R46.2 DB migration')
        except Exception:
            LOG.warning('R46.2 operation cycle unavailable; verify provider connectivity')
        await asyncio.sleep(300)
