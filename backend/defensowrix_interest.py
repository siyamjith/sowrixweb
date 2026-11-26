"""Business-interest requests. No product provisioning or email delivery."""
import csv
import io
import re
import uuid
from datetime import datetime

from aiohttp import web

SOLUTIONS = (
    'Infrastructure Monitoring', 'AI Engineer Troubleshooting',
    'SOC Security Operations', 'Complete DEFENSOWRIX Platform',
)
STATUSES = ('new', 'under_review', 'contacted', 'discussion_scheduled',
            'awaiting_availability', 'approved', 'closed')
PRIVATE = {'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff'}
REFERENCE = re.compile(r'SW/DR/[0-9]{4,}')


def text(value, low, high):
    if not isinstance(value, str):
        raise ValueError()
    value = value.strip()
    if not low <= len(value) <= high or '\x00' in value:
        raise ValueError()
    return value


async def body(request):
    if request.content_type != 'application/json':
        raise web.HTTPUnsupportedMediaType()
    if request.content_length is None or request.content_length > 32768:
        raise web.HTTPRequestEntityTooLarge(max_size=32768, actual_size=request.content_length or 0)
    try:
        data = await request.json()
        if not isinstance(data, dict):
            raise ValueError()
        return data
    except (ValueError, UnicodeDecodeError):
        raise web.HTTPBadRequest(text='Invalid request.')


def register_interest(app, settings, upstream_error, digest):
    async def invoke(name, payload, **kwargs):
        try:
            return await app['gateway'].p.rpc(name, payload, **kwargs)
        except upstream_error as exc:
            if exc.status in (401, 403) and not kwargs.get('service'):
                raise web.HTTPForbidden(text='Authorized enquiries administrator required.')
            if exc.status in (400, 404, 409) and not kwargs.get('service'):
                raise web.HTTPBadRequest(text='Operation could not be applied. Check the request and status.')
            raise web.HTTPServiceUnavailable(text='The operation could not be confirmed. Please retry.')

    async def submit(request):
        if (request.headers.get('Origin') != settings.public_origin or
                request.headers.get('Sec-Fetch-Site', 'same-origin') not in ('same-origin', 'none')):
            raise web.HTTPForbidden()
        gateway = app['gateway']
        gateway.rate('dw-interest-ip:' + digest(request.remote or 'unknown'), 6, 3600)
        data = await body(request)
        fields = {'full_name': (2, 120), 'company_name': (2, 160), 'business_email': (5, 254),
                  'phone': (8, 24), 'infrastructure': (5, 500), 'requirements': (20, 4000)}
        try:
            if set(data) != {*fields, 'solution', 'device_count', 'consent', 'submission_key', 'website'}:
                raise ValueError()
            clean = {k: text(data[k], *bounds) for k, bounds in fields.items()}
            clean['business_email'] = clean['business_email'].lower()
            count = data['device_count']
            if (data['website'] != '' or data['consent'] is not True or data['solution'] not in SOLUTIONS
                    or type(count) is not int or not 0 <= count <= 10000000
                    or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]{2,}', clean['business_email'])
                    or not re.fullmatch(r'\+?[0-9][0-9 ()-]{7,22}', clean['phone'])
                    or not 8 <= sum(ch.isdigit() for ch in clean['phone']) <= 15):
                raise ValueError()
            key = str(uuid.UUID(data['submission_key']))
        except (ValueError, TypeError, AttributeError):
            raise web.HTTPBadRequest(text='Check your request details and contact consent.')
        gateway.rate('dw-interest-email:' + digest(clean['business_email']), 4, 3600)
        clean.update(solution=data['solution'], device_count=count, consent=True)
        result = await invoke('sowrix_submit_dw_interest', {'p_record': clean, 'p_key': key}, service=True)
        if isinstance(result, dict) and result.get('conflict') is True:
            raise web.HTTPConflict(text='A matching request could not be accepted. Contact SOWRIX if you need help.')
        if not isinstance(result, dict) or result.get('accepted') is not True or not REFERENCE.fullmatch(str(result.get('reference', ''))):
            raise web.HTTPServiceUnavailable(text='The request could not be confirmed as saved.')
        return web.json_response({'reference': result['reference']}, status=201, headers=PRIVATE)

    async def manage(request):
        gateway = app['gateway']
        tokens = await gateway.session(request)
        gateway.check_csrf(request)
        gateway.rate('dw-interest-admin:' + digest(tokens['user']['id']), 60, 60)
        data = await body(request)
        try:
            action = data['action']
            clean = {}
            if action in ('list', 'export', 'counts', 'employees'):
                if action in ('list', 'export'):
                    clean['search'] = text(data.get('search', ''), 0, 160)
                    status = data.get('status', '')
                    if status not in ('', *STATUSES):
                        raise ValueError()
                    clean['status'] = status
                    page = data.get('page', 1)
                    if type(page) is not int or not 1 <= page <= 1000:
                        raise ValueError()
                    clean['page'] = page
            elif action in ('detail', 'update', 'link_client'):
                clean['id'] = str(uuid.UUID(data['id']))
                if action == 'link_client':
                    clean['client_id'] = str(uuid.UUID(data['client_id']))
                if action == 'update':
                    if data['status'] not in STATUSES:
                        raise ValueError()
                    clean['status'] = data['status']
                    clean['assignee'] = str(uuid.UUID(data['assignee'])) if data.get('assignee') else None
                    clean['note'] = text(data.get('note', ''), 0, 2000)
                    clean['discussion'] = None
                    if data.get('discussion'):
                        when = datetime.fromisoformat(data['discussion'])
                        if when.utcoffset() is None:
                            raise ValueError()
                        clean['discussion'] = when.isoformat()
            else:
                raise ValueError()
        except (ValueError, TypeError, AttributeError, KeyError, OverflowError):
            raise web.HTTPBadRequest(text='Invalid request operation.')
        result = await invoke('sowrix_manage_dw_interest', {'p_action': action, 'p_data': clean},
                              token=tokens['access_token'])
        if action == 'export':
            if not isinstance(result, list) or any(not isinstance(row, dict) for row in result):
                raise web.HTTPServiceUnavailable()
            columns = ('reference', 'company_name', 'full_name', 'business_email', 'phone',
                       'solution', 'device_count', 'status', 'discussion', 'created_at')
            def cell(v):
                value = '' if v is None else str(v)
                return "'" + value if value.lstrip().startswith(('=', '+', '-', '@')) or value.startswith(('\t', '\r', '\n')) else value
            out = io.StringIO(newline='')
            writer = csv.writer(out, quoting=csv.QUOTE_ALL)
            writer.writerow(columns)
            writer.writerows([cell(row.get(k)) for k in columns] for row in result)
            return web.Response(text=out.getvalue(), content_type='text/csv',
                                headers={**PRIVATE, 'Content-Disposition': 'attachment; filename="defensowrix-requests.csv"'})
        return web.json_response({'data': result}, headers=PRIVATE)

    app.router.add_post('/api/public/defensowrix-request', submit)
    app.router.add_post('/api/admin/defensowrix-requests', manage)
