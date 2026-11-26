"""Durable business mail dispatch; no account/data mutations at import.
Provider acceptance is not inbox delivery. No credentials or email bodies logged.
"""
import asyncio
import json
import logging
import re
import time
import aiohttp

LOG = logging.getLogger('sowrix.business_notifications')

async def business_worker(provider, settings):
    """Independent task: provider delays must not block stream revocation checks."""
    next_reminder = 0
    while True:
        await asyncio.sleep(30)
        if not (settings.ready and settings.business_notifications_enabled):
            continue
        due = time.monotonic() >= next_reminder
        try:
            await business_cycle(provider, settings, reminders=due)
            if due:
                next_reminder = time.monotonic() + 3600
        except Exception:
            LOG.warning('Business notification worker failed; inspect delivery status')

async def bounded_body(response, limit=16384):
    data = bytearray()
    while len(data) <= limit:
        chunk = await response.content.read(min(4096, limit + 1 - len(data)))
        if not chunk:
            break
        data.extend(chunk)
    return bytes(data)

async def deliver_business_mail(provider, settings):
    if not (settings.business_email_enabled and settings.resend_key and settings.business_email_from):
        return
    # Five 12-second calls fit the two-minute lease even when upstream times out.
    jobs = await provider.rpc('sowrix_claim_business_mail', {'p_limit': 5}, service=True)
    for job in jobs:
        accepted, provider_id, error = False, None, 'provider_failure'
        email = job.get('email')
        recipient = email.strip().lower() if isinstance(email, str) else ''
        # Local/staging must explicitly allow every recipient. No test mail escapes.
        allow = {v.strip().lower() for v in settings.business_email_allowlist.split(',') if v.strip()}
        if len(recipient) > 254 or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]{2,}', recipient):
            error = 'invalid_recipient'
        elif settings.local_dev and recipient not in allow:
            error = 'staging_recipient_not_allowed'
        elif allow and recipient not in allow:
            error = 'recipient_not_allowed'
        else:
            try:
                async with provider.client.post('https://api.resend.com/emails',
                    headers={'Authorization': 'Bearer '+settings.resend_key,
                             'Idempotency-Key': 'sowrix-business-'+job['id']},
                    json={'from': settings.business_email_from, 'to': [recipient],
                          'subject': 'SOWRIX account update',
                          'text': 'You have a SOWRIX notification. Sign in to review your authorized updates.\n'+settings.public_origin+'/app#/workspace/notifications'},
                    timeout=aiohttp.ClientTimeout(total=12), allow_redirects=False) as response:
                    # Read bounded bytes even when an upstream sends a large error body.
                    body = await bounded_body(response)
                    if len(body)>16384:
                        error = 'provider_response_too_large'
                    elif response.status in (200,201,202):
                        data=json.loads(body)
                        if isinstance(data,dict) and isinstance(data.get('id'),str) and re.fullmatch(r'[A-Za-z0-9_-]{1,200}',data['id']):
                            accepted,provider_id=True,data['id']
                        else:
                            error='provider_acceptance_unconfirmed'
                    else:
                        error='provider_http_'+str(response.status)
            except (aiohttp.ClientError,TimeoutError,ValueError,KeyError):
                error='provider_result_unknown'
        await provider.rpc('sowrix_finish_business_mail',{
            'p_id':job['id'],'p_lease':job['lease_token'],'p_accepted':accepted,
            'p_provider_id':provider_id,'p_error':None if accepted else error},service=True)

async def business_cycle(provider,settings,reminders=False):
    if reminders:
        await provider.rpc('sowrix_business_reminders',{},service=True)
    await deliver_business_mail(provider,settings)
    await check_business_delivery(provider,settings)

async def check_business_delivery(provider,settings):
    if not (settings.business_email_enabled and settings.resend_key):
        return
    rows=await provider.rpc('sowrix_business_delivery_pending',{},service=True)
    for row in rows:
        provider_id=row.get('provider_id','')
        if not re.fullmatch(r'[A-Za-z0-9_-]{1,200}',provider_id):
            continue
        try:
            async with provider.client.get('https://api.resend.com/emails/'+provider_id,
                headers={'Authorization':'Bearer '+settings.resend_key},
                timeout=aiohttp.ClientTimeout(total=12),allow_redirects=False) as response:
                body=await bounded_body(response)
                if response.status!=200 or len(body)>16384:
                    continue
                data=json.loads(body)
                if not isinstance(data,dict) or data.get('id')!=provider_id:
                    continue
                event=data.get('last_event')
                if event not in ('delivered','bounced','failed','suppressed','complained'):
                    continue
            await provider.rpc('sowrix_business_delivery_confirm',{'p_id':row['id'],'p_provider_id':provider_id,'p_event':event},service=True)
        except (aiohttp.ClientError,TimeoutError,ValueError):
            LOG.warning('Business email delivery status could not be checked')
