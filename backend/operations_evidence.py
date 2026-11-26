"""V4 uses the existing session/CSRF and collector credential boundaries."""
import re
from aiohttp import web
try:
    from operations_v1.evidence import validate, utc, uid, CATEGORIES, FIELDS
except ModuleNotFoundError as error:
    if __package__ or error.name!='operations_v1': raise
    # Support the existing `python backend/server.py` launcher as well as -m.
    import sys
    from pathlib import Path
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
    from operations_v1.evidence import validate, utc, uid, CATEGORIES, FIELDS
if __package__:
    from .operations_security import body, call_rpc, BASE, validate_batch
else:
    from operations_security import body, call_rpc, BASE, validate_batch

def confirmed(record, org):
    try:
        if type(record) is not dict or set(record)!={'id','organization_id','asset_id','source_id','collector_id','actor_id','source_key','category','observed_at','ingested_at','document','integrity_hash'}:
            return False
        for name in ('id','organization_id','asset_id','source_id'): uid(record[name])
        if record['organization_id']!=org: return False
        utc(record['observed_at']); utc(record['ingested_at'])
        if type(record['integrity_hash']) is not str or not re.fullmatch(r'[0-9a-f]{64}',record['integrity_hash']): return False
        doc=record['document']
        if type(doc) is not dict or set(doc)!=FIELDS|{'authorized_source_identity','collector_id'}: return False
        imported=dict(doc); del imported['authorized_source_identity']; del imported['collector_id']
        if doc['provenance']=='authenticated_collector':
            if record['actor_id'] is not None or uid(record['collector_id'])!=record['source_id'] or doc['authorized_source_identity']!=record['collector_id'] or doc['collector_id']!=record['collector_id']: return False
            if doc['category']!='monitoring' or doc['observation_type']!='collector_sample' or doc['archive_id'] is not None or doc['parents']: return False
            imported['provenance']='imported_claim'
        elif record['collector_id'] is not None or doc['collector_id'] is not None or uid(record['actor_id'])!=doc['authorized_source_identity']: return False
        validate(imported)
        return all(record[k]==doc[k] for k in ('organization_id','asset_id','source_id','source_key','category')) and utc(record['observed_at'])==utc(doc['observed_at'])
    except (ValueError,TypeError,KeyError,OverflowError): return False

async def session(request):
    g=request.app['gateway']; g.check_csrf(request); tokens=await g.session(request)
    g.rate('ops-v4-user:'+tokens['user']['id'],30)
    return tokens

async def append(request):
    tokens=await session(request)
    try: data=validate(await body(request,16000))
    except (ValueError,TypeError,OverflowError): raise web.HTTPBadRequest(text='Invalid evidence') from None
    result=await call_rpc(request,'sowrix_ops_v4_append',{'p_data':data},token=tokens['access_token'])
    if type(result) is not dict or set(result)!={'record','duplicate'} or type(result['duplicate']) is not bool or not confirmed(result['record'],data['organization_id']):
        raise web.HTTPServiceUnavailable(text='Evidence ingestion not confirmed')
    record=result['record']
    if record['actor_id']!=tokens['user']['id'] or any(record['document'][k]!=v for k,v in data.items() if k!='observed_at') or utc(record['observed_at'])!=data['observed_at']:
        raise web.HTTPServiceUnavailable(text='Evidence receipt mismatch')
    return web.json_response({'data':result})

async def history(request):
    tokens=await session(request)
    try:
        data=await body(request,2048)
        if set(data)!={'organization_id','asset_id','limit','before_at','before_id'}: raise ValueError()
        org=uid(data['organization_id']); asset=uid(data['asset_id']) if data['asset_id'] is not None else None
        if type(data['limit']) is not int or not 1<=data['limit']<=100 or (data['before_at'] is None)!=(data['before_id'] is None): raise ValueError()
        at=utc(data['before_at']) if data['before_at'] is not None else None
        before=uid(data['before_id']) if data['before_id'] is not None else None
    except (ValueError,TypeError,OverflowError): raise web.HTTPBadRequest(text='Invalid evidence page') from None
    result=await call_rpc(request,'sowrix_ops_v4_list',dict(p_org=org,p_asset=asset,p_limit=data['limit'],p_before_at=at,p_before_id=before),token=tokens['access_token'])
    if type(result) is not dict or set(result)!={'organization_id','records'} or result['organization_id']!=org or type(result['records']) is not list or len(result['records'])>data['limit'] or any(not confirmed(r,org) or (asset is not None and r['asset_id']!=asset) for r in result['records']):
        raise web.HTTPServiceUnavailable(text='Evidence page not confirmed')
    return web.json_response({'data':result})

async def source(request):
    tokens=await session(request)
    try:
        data=await body(request,2048)
        if set(data)!={'organization_id','asset_id','category','actor_id','label','enabled'} or data['category'] not in CATEGORIES or type(data['enabled']) is not bool or type(data['label']) is not str or not 1<=len(data['label'].strip())<=100: raise ValueError()
        payload=dict(p_org=uid(data['organization_id']),p_asset=uid(data['asset_id']),p_category=data['category'],p_actor=uid(data['actor_id']),p_label=data['label'].strip(),p_enabled=data['enabled'])
    except (ValueError,TypeError): raise web.HTTPBadRequest(text='Invalid source binding') from None
    result=await call_rpc(request,'sowrix_ops_v4_source',payload,token=tokens['access_token'])
    try:
        uid(result['id']); utc(result['created_at'])
        if set(result)!={'id','organization_id','asset_id','category','actor_id','label','enabled','created_at'} or any(result[k]!=data[k] for k in ('organization_id','asset_id','category','actor_id','enabled')) or result['label']!=payload['p_label']: raise ValueError()
    except (ValueError,TypeError,KeyError): raise web.HTTPServiceUnavailable(text='Source binding not confirmed') from None
    return web.json_response({'data':result})

async def ingest(request):
    g=request.app['gateway']; g.rate('ops-v4-collector-ip:'+(request.remote or 'unknown'),120)
    token=re.fullmatch(r'Bearer ([0-9a-f]{64})',request.headers.get('Authorization',''))
    if not token: raise web.HTTPUnauthorized(text='Collector authentication required')
    try: data=validate_batch(await body(request,500000))
    except (ValueError,TypeError,OverflowError): raise web.HTTPBadRequest(text='Invalid collector evidence') from None
    result=await call_rpc(request,'sowrix_ops_v4_ingest',{'p_token':token[1],'p_data':data},service=True)
    if type(result) is not dict or type(result.get('accepted')) is not int or not 0<=result['accepted']<=len(data['samples']) or type(result.get('duplicate',False)) is not bool or (result.get('duplicate',False) and result['accepted']!=0) or (not result.get('duplicate',False) and (type(result.get('sequence')) is not int or result.get('sequence')!=data['sequence'])):
        raise web.HTTPServiceUnavailable(text='Collector evidence not confirmed')
    return web.json_response({'accepted':result['accepted'],'duplicate':result.get('duplicate',False),'sequence':data['sequence']})

def register(app):
    for path,handler in [('append',append),('list',history),('source',source),('collectors/ingest',ingest)]:
        app.router.add_post(BASE+'/evidence/'+path,handler)
