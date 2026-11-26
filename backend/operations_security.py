"""V2 gateway boundary. No probes, AI execution, or credential issuance."""
import json
import math
import re
from datetime import datetime, timedelta, timezone
from uuid import UUID
from aiohttp import web

CAPABILITIES = ('read', 'operate', 'configure', 'members', 'live', 'ai')
BASE = '/api/operations/v1'


def _reject_duplicates(pairs):
    out = {}
    for key, value in pairs:
        if key in out:
            raise ValueError('Duplicate field')
        out[key] = value
    return out


def _invalid_constant(value):
    raise ValueError('Non-finite JSON')


async def body(request, limit):
    if request.content_type != 'application/json':
        raise web.HTTPUnsupportedMediaType(text='JSON required')
    raw = await request.read()
    if len(raw) > limit:
        raise web.HTTPRequestEntityTooLarge(max_size=limit, actual_size=len(raw))
    try:
        value = json.loads(raw.decode('utf-8'), object_pairs_hook=_reject_duplicates,
                           parse_constant=_invalid_constant)
    except (ValueError, RecursionError):
        raise web.HTTPBadRequest(text='Invalid JSON') from None
    if not isinstance(value, dict):
        raise web.HTTPBadRequest(text='JSON object required')
    return value


def uuid_text(value):
    if not isinstance(value, str) or not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', value):
        raise ValueError('Invalid identifier')
    return str(UUID(value))


def validate_batch(data, now=None):
    """Strict monitoring sample subset of the existing collector contract."""
    now = now or datetime.now(timezone.utc)
    if set(data) != {'sequence', 'samples'}:
        raise ValueError('Invalid fields')
    seq = data['sequence']
    if type(seq) is not int or not 1 <= seq <= 2**63-1:
        raise ValueError('Invalid sequence')
    samples = data['samples']
    if not isinstance(samples, list) or not 1 <= len(samples) <= 100:
        raise ValueError('Invalid sample count')
    result, seen = [], set()
    for sample in samples:
        if not isinstance(sample, dict) or set(sample) != {'device_id', 'observed_at', 'status', 'metrics'}:
            raise ValueError('Invalid sample fields')
        device = uuid_text(sample['device_id'])
        ts = sample['observed_at']
        if not isinstance(ts, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-](?:0[0-9]|1[0-5]):[0-5][0-9])', ts):
            raise ValueError('Explicit timestamp required')
        stamp = datetime.fromisoformat(ts.replace('Z', '+00:00')).astimezone(timezone.utc)
        if not now-timedelta(hours=24) <= stamp <= now+timedelta(minutes=2):
            raise ValueError('Timestamp outside spool window')
        key = (device, stamp)
        if key in seen:
            raise ValueError('Duplicate sample')
        seen.add(key)
        status, metrics = sample['status'], sample['metrics']
        if status not in ('up', 'down', 'unknown', 'unsupported'):
            raise ValueError('Invalid status')
        if not isinstance(metrics, dict) or len(metrics) > 100:
            raise ValueError('Invalid metrics')
        for k, v in metrics.items():
            if not re.fullmatch(r'[a-z][a-z0-9_]{0,63}', k) or type(v) not in (int,float) or abs(v)>1e15 or not math.isfinite(v):
                raise ValueError('Invalid metric')
        if len(json.dumps(metrics, separators=(',', ':'))) > 8192:
            raise ValueError('Metrics too large')
        result.append({'device_id':device,'observed_at':stamp.isoformat(),'status':status,'metrics':metrics})
    return {'sequence':seq,'samples':result}


async def call_rpc(request, name, payload, **kwargs):
    gateway = request.app['gateway']
    try:
        return await gateway.p.rpc(name, payload, **kwargs)
    except (json.JSONDecodeError, UnicodeDecodeError, RecursionError):
        raise web.HTTPServiceUnavailable(text='Invalid operations provider response') from None
    except request.app['operations_upstream_error'] as error:
        if error.status in (401,403):
            raise web.HTTPForbidden(text='Resource not found or access not permitted') from None
        if error.status in (400,422):
            raise web.HTTPBadRequest(text='Invalid operations request') from None
        if error.status == 429:
            raise web.HTTPTooManyRequests(text='Operations service busy') from None
        raise web.HTTPServiceUnavailable(text='Operations V2 unavailable. Check migration and service configuration.') from None


async def context(request):
    gateway = request.app['gateway']
    gateway.check_csrf(request)
    tokens = await gateway.session(request)
    gateway.rate('ops-v2-user:'+tokens['user']['id'], 30)
    data = await body(request, 2048)
    try:
        if set(data) != {'organization_id'}:
            raise ValueError()
        org = uuid_text(data['organization_id'])
    except ValueError:
        raise web.HTTPBadRequest(text='Select a valid organization') from None
    # Database evaluates actual user JWT, membership, MFA and tenant capabilities.
    result = await call_rpc(request, 'sowrix_ops_v2_context', {'p_org':org}, token=tokens['access_token'])
    if not isinstance(result, dict) or result.get('organization_id') != org or result.get('release') != 'V2.0.0' or not isinstance(result.get('capabilities'), list) or 'read' not in result['capabilities'] or any(c not in CAPABILITIES for c in result['capabilities']) or len(set(result['capabilities'])) != len(result['capabilities']):
        raise web.HTTPServiceUnavailable(text='Operations authorization not confirmed')
    return web.json_response({'data':{'release':'V2.0.0','organization_id':org,'capabilities':result['capabilities']}})


async def ingest(request):
    gateway = request.app['gateway']
    gateway.rate('ops-v2-collector-ip:'+(request.remote or 'unknown'),120)
    match = re.fullmatch(r'Bearer ([0-9a-f]{64})', request.headers.get('Authorization',''))
    if not match:
        raise web.HTTPUnauthorized(text='Collector authentication required')
    data = await body(request, 500_000)
    try:
        payload = validate_batch(data)
    except (ValueError, OverflowError, TypeError):
        raise web.HTTPBadRequest(text='Invalid monitoring evidence') from None
    result = await call_rpc(request, 'sowrix_ops_v2_ingest', {'p_token':match[1],'p_data':payload}, service=True)
    # Only expose bounded acknowledgement; never send credentials or identity data.
    if not isinstance(result, dict) or type(result.get('accepted')) is not int or not 0 <= result['accepted'] <= len(payload['samples']) or type(result.get('duplicate',False)) is not bool:
        raise web.HTTPServiceUnavailable(text='Ingestion not confirmed')
    if result.get('duplicate',False):
        if result['accepted'] != 0:
            raise web.HTTPServiceUnavailable(text='Ingestion not confirmed')
    elif type(result.get('sequence')) is not int or result['sequence'] != payload['sequence']:
        raise web.HTTPServiceUnavailable(text='Ingestion not confirmed')
    return web.json_response({'accepted':result['accepted'],'duplicate':result.get('duplicate',False),'sequence':payload['sequence']})


def register(app, upstream_error):
    app['operations_upstream_error'] = upstream_error
    app.router.add_post(BASE+'/security/context', context)
    app.router.add_post(BASE+'/collectors/ingest', ingest)
