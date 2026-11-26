"""R46.3 opt-in count-only operations commentary, never transmits customer/employee data.

The database RLS/role-gated RPC is the ONLY authority. No browser-supplied
role, count, user text, resume, identifier, or model selection is trusted.
"""
import json
from aiohttp import web

RPC_BY_MODE = {
    'admin': 'sowrix_r462_admin_pulse',
    'hr': 'sowrix_r463_hr_snapshot',
}
METRIC_KEYS = {
    'admin': ('open_tickets', 'pending_approvals', 'active_projects', 'open_applications',
              'unassigned_tickets', 'overdue_tasks', 'unpaid_invoices', 'expiring_amcs'),
    'hr': ('new_candidates', 'under_review', 'shortlisted', 'total_open_candidates'),
}


def scrub_metrics(data, mode):
    """Serialize an allowlisted schema; reject identifying and malformed inputs."""
    if mode not in METRIC_KEYS or not isinstance(data, dict):
        raise ValueError('Invalid summary')
    result = {}
    for key in METRIC_KEYS[mode]:
        number = data.get(key)
        if type(number) is not int or number < 0 or number > 100_000_000:
            raise ValueError('Invalid count in authorized summary')
        result[key] = number
    return result


async def ai_insights(request):
    gateway = request.app['gateway']
    gateway.check_csrf(request)
    tokens = await gateway.session(request)
    user_id = tokens['user']['id']
    gateway.rate('business-ai:' + user_id, 3, 300)
    data = await request.json()
    if not isinstance(data, dict) or set(data) != {'mode'} or data['mode'] not in RPC_BY_MODE:
        raise web.HTTPBadRequest(text='Select the Admin or HR summary')
    mode = data['mode']
    settings = gateway.s
    if not settings.business_ai_enabled or not settings.ai_key:
        raise web.HTTPServiceUnavailable(text='Optional business AI is disabled. Count-only local insights remain available.')
    # This is a user-credentialed DB RPC. It enforces secure session, MFA and the
    # current Admin/HR module permission; no service-role bypass is possible.
    snapshot = await gateway.p.rpc(RPC_BY_MODE[mode], {}, token=tokens['access_token'])
    metrics = scrub_metrics(snapshot, mode)
    instructions = (
        'You are an operations assistant. The supplied JSON contains aggregated counts only. '
        'Do not invent facts, percentages, employee traits, candidates, customers or performance scores. '
        'Give 2-4 short, actionable suggestions, and clearly distinguish data from recommendations. '
        'Do not make hiring, payroll, invoice settlement or access control decisions. '
        'Never request secrets, personal information or external links. Plain text only, under 900 characters.'
    )
    payload = {
        'systemInstruction': {'parts': [{'text': instructions}]},
        'contents': [{'role': 'user', 'parts': [{'text': json.dumps({'role_scope': mode, 'counts': metrics})}]}],
        'generationConfig': {'maxOutputTokens': 370, 'temperature': 0.2},
    }
    client = gateway.p.client
    async with client.post(
        'https://generativelanguage.googleapis.com/v1beta/models/' + settings.ai_model + ':generateContent',
        headers={'x-goog-api-key': settings.ai_key}, json=payload, allow_redirects=False,
    ) as response:
        if response.status != 200:
            raise web.HTTPServiceUnavailable(text='AI provider unavailable; use local insights instead.')
        raw = await response.content.read(24_001)
        if len(raw) > 24_000:
            raise web.HTTPBadGateway(text='AI response exceeded the safety limit')
    answer = json.loads(raw)['candidates'][0]['content']['parts'][0]['text']
    if not isinstance(answer, str) or not (1 <= len(answer) <= 1800):
        raise ValueError('Invalid AI response')
    return web.json_response({'mode': mode, 'text': answer[:900], 'review_required': True,
                              'data_policy': 'Aggregated counts only; no resumes or user records sent'})
