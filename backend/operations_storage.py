"""V3 archival API. Archived metadata is never an action, trusted telemetry, or approval."""
import json
import math
import re
from datetime import datetime, timezone, timedelta
from aiohttp import web
if __package__:
    from .operations_security import body, uuid_text, call_rpc, BASE
else:
    from operations_security import body, uuid_text, call_rpc, BASE

KINDS=frozenset(('engineer_session','engineer_evidence','engineer_approval_record','soc_event','soc_finding','soc_case','endpoint_inventory','endpoint_telemetry'))
CHILDREN=frozenset(('engineer_evidence','engineer_approval_record','soc_finding','endpoint_telemetry'))
STAMP=re.compile(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{1,6})?(?:Z|[+-](?:0[0-9]|1[0-5]):[0-5][0-9])')

def timestamp(value):
    if not isinstance(value,str) or not STAMP.fullmatch(value): raise ValueError('Explicit timestamp required')
    return datetime.fromisoformat(value.replace('Z','+00:00')).astimezone(timezone.utc)

def attributes(value):
    if not isinstance(value,dict) or len(value)>32: raise ValueError('Invalid attributes')
    for k,v in value.items():
        if not re.fullmatch(r'[a-z][a-z0-9_]{0,63}',k) or re.search(r'password|secret|token|credential|private_key|authorization|cookie',k): raise ValueError('Invalid attribute name')
        if type(v) is str:
            if len(v)>500 or '\x00' in v: raise ValueError('Invalid text')
        elif type(v) is bool: pass
        elif type(v) in (int,float):
            if abs(v)>1e15 or not math.isfinite(v): raise ValueError('Invalid number')
        else: raise ValueError('Only scalar metadata allowed')
    if len(json.dumps(value,ensure_ascii=False).encode('utf-8'))>8192: raise ValueError('Attributes too large')
    return value

def parse(data,append):
    keys={'organization_id','kind'} | ({'device_id','source_key','observed_at','summary','attributes','parent_id'} if append else {'limit','before_at','before_id'})
    if set(data)!=keys or not isinstance(data['kind'],str) or data['kind'] not in KINDS: raise ValueError('Invalid archive request')
    result={'p_org':uuid_text(data['organization_id']),'p_kind':data['kind']}
    if append:
        stamp=timestamp(data['observed_at'])
        if stamp>datetime.now(timezone.utc)+timedelta(minutes=2): raise ValueError('Future observation')
        source,summary=data['source_key'],data['summary']
        if not isinstance(source,str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.:-]{0,119}',source): raise ValueError('Invalid source')
        if not isinstance(summary,str) or not 1<=len(summary.strip())<=500 or len(summary.encode('utf-8'))>2000 or '\x00' in summary: raise ValueError('Invalid summary')
        parent=data['parent_id']
        if (parent is not None)!=(data['kind'] in CHILDREN): raise ValueError('Invalid parent')
        result.update(p_device=uuid_text(data['device_id']),p_source_key=source,p_observed_at=stamp.isoformat(),p_summary=summary.strip(),p_attributes=attributes(data['attributes']),p_parent=uuid_text(parent) if parent is not None else None)
    else:
        limit=data['limit']; at=data['before_at']; ident=data['before_id']
        if type(limit) is not int or not 1<=limit<=100 or (at is None)!=(ident is None): raise ValueError('Invalid page')
        result.update(p_limit=limit,p_before_at=timestamp(at).isoformat() if at is not None else None,p_before_id=uuid_text(ident) if ident is not None else None)
    return result

def confirmed(record,payload):
    if not isinstance(record,dict) or set(record)!={'id','organization_id','device_id','kind','source_key','observed_at','summary','attributes','parent_id','actor_id','created_at','provenance'} or record.get('organization_id')!=payload['p_org'] or record.get('kind')!=payload['p_kind'] or record.get('provenance')!='manual_archive': return False
    try:
        uuid_text(record['id']);uuid_text(record['device_id']);uuid_text(record['actor_id']);attributes(record['attributes']);timestamp(record['created_at']);timestamp(record['observed_at'])
        if not isinstance(record['summary'],str) or not 1<=len(record['summary'])<=500 or not isinstance(record['source_key'],str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.:-]{0,119}',record['source_key']): return False
        if (record['parent_id'] is not None)!=(record['kind'] in CHILDREN): return False
        if record['parent_id'] is not None: uuid_text(record['parent_id'])
        if 'p_device' in payload and (record['device_id']!=payload['p_device'] or record.get('source_key')!=payload['p_source_key'] or record.get('summary')!=payload['p_summary'] or record.get('parent_id')!=payload['p_parent'] or record.get('attributes')!=payload['p_attributes'] or timestamp(record['observed_at'])!=timestamp(payload['p_observed_at'])): return False
    except (KeyError, ValueError, TypeError, OverflowError): return False
    return True

async def handle(request,append):
    g=request.app['gateway'];g.check_csrf(request);tokens=await g.session(request)
    g.rate('ops-v3-user:'+tokens['user']['id'],30)
    try: payload=parse(await body(request,16000),append)
    except (ValueError,TypeError,OverflowError): raise web.HTTPBadRequest(text='Invalid archive request') from None
    result=await call_rpc(request,'sowrix_ops_v3_append' if append else 'sowrix_ops_v3_list',payload,token=tokens['access_token'])
    if append:
        valid=isinstance(result,dict) and set(result)=={'record','duplicate'} and type(result.get('duplicate')) is bool and confirmed(result.get('record'),payload)
    else:
        valid=isinstance(result,dict) and set(result)=={'organization_id','kind','records'} and result.get('organization_id')==payload['p_org'] and result.get('kind')==payload['p_kind'] and isinstance(result.get('records'),list) and len(result['records'])<=payload['p_limit'] and all(confirmed(r,payload) for r in result['records'])
    if not valid: raise web.HTTPServiceUnavailable(text='Archive response not confirmed')
    return web.json_response({'data':result})

async def append(request): return await handle(request,True)
async def list_records(request): return await handle(request,False)

def register(app):
    app.router.add_post(BASE+'/storage/append',append)
    app.router.add_post(BASE+'/storage/list',list_records)
