"""Firewall monitoring on existing session, V4 source and V5 collector boundaries."""
from aiohttp import web
from operations_v1.firewall import profile,event,VENDORS
from operations_v1.evidence import uid,utc
if __package__:
    from .operations_security import BASE,body,call_rpc
    from .operations_evidence import confirmed
else:
    from operations_security import BASE,body,call_rpc
    from operations_evidence import confirmed

MATRIX=[dict(vendor=v,implemented=['asset-bound HTTPS bridge','aggregate imported claims']+(['approved SNMPv3 exporter mapping'] if v=='SonicWall' else []),lab_tested=True,hardware_verified=False,native_api_supported=False,scope='Synthetic contracts only; direct vendor APIs and physical firmware compatibility unverified') for v in VENDORS]
def exact(d,keys):
    if type(d) is not dict or set(d)!=set(keys.split()):raise ValueError('Invalid fields')
async def handle(request):
    g=request.app['gateway'];g.check_csrf(request);tokens=await g.session(request);g.rate('ops-v7-user:'+tokens['user']['id'],30)
    action=request.match_info['action']
    try:
        data=await body(request,12000);org=uid(data.get('organization_id'))
        if action=='configure':
            exact(data,'organization_id asset_id configuration');payload=dict(p_org=org,p_asset=uid(data['asset_id']),p_data=profile(data['configuration']))
        elif action=='import':
            exact(data,'organization_id asset_id source_id event');doc=event(data['event'],dict(organization_id=org,asset_id=uid(data['asset_id']),source_id=uid(data['source_id'])));payload=dict(p_data=doc)
        else:
            exact(data,'organization_id asset_id before_at before_id event_before_at event_before_id')
            for a,b in [('before_at','before_id'),('event_before_at','event_before_id')]:
                if (data[a] is None)!=(data[b] is None):raise ValueError()
            payload=dict(p_org=org,p_asset=uid(data['asset_id']) if data['asset_id'] else None,p_before=utc(data['before_at']) if data['before_at'] else None,p_before_id=uid(data['before_id']) if data['before_id'] else None,p_event_before=utc(data['event_before_at']) if data['event_before_at'] else None,p_event_id=uid(data['event_before_id']) if data['event_before_id'] else None)
    except (ValueError,TypeError,OverflowError):raise web.HTTPBadRequest(text='Invalid firewall monitoring request') from None
    result=await call_rpc(request,'sowrix_ops_v7_'+action,payload,token=tokens['access_token'])
    if action=='import':
        if type(result) is not dict or type(result.get('duplicate')) is not bool or not confirmed(result.get('record'),org) or result['record']['actor_id']!=tokens['user']['id'] or utc(result['record']['observed_at'])!=doc['observed_at'] or any(result['record']['document'].get(k)!=v for k,v in doc.items() if k!='observed_at'):raise web.HTTPServiceUnavailable(text='Firewall import not confirmed')
    elif type(result) is not dict or result.get('organization_id')!=org:raise web.HTTPServiceUnavailable(text='Firewall scope not confirmed')
    if action=='snapshot':
        for key in ('nodes','history','events','alerts'):
            if type(result.get(key)) is not list or len(result[key])>100 or any(type(row) is not dict or row.get('organization_id')!=org for row in result[key]):raise web.HTTPServiceUnavailable(text='Firewall records not confirmed')
        if data['asset_id'] and any(row.get('asset_id')!=payload['p_asset'] for key in ('history','events','alerts') for row in result[key]):raise web.HTTPServiceUnavailable(text='Firewall asset scope not confirmed')
        if any(not confirmed(e,org) or e['document']['provenance']!='imported_claim' for e in result['events']):raise web.HTTPServiceUnavailable(text='Firewall event provenance not confirmed')
        result={**result,'capability_matrix':MATRIX,'hardware_verified':False}
    return web.json_response({'data':result})
def register(app):app.router.add_post(BASE+'/firewall/{action:configure|import|snapshot}',handle)
