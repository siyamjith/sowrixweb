"""V9 fixed hardware RPCs; collection never executes in the gateway."""
from aiohttp import web
from operations_v1.hardware import profile,SPECS
from operations_v1.evidence import uid,utc
if __package__:
    from .operations_security import BASE,body,call_rpc
else:
    from operations_security import BASE,body,call_rpc
MATRIX=[dict(vendor=v,category=c,implemented=True,fixture_tested=True,hardware_verified=False,status='Implemented contract; native integration pending',scope='Approved read-only exporter/HTTPS health mapping; no native vendor compatibility claim') for c,vs in [('printer',['Canon','HP','Epson','Brother','Ricoh','Xerox']),('recorder',['Authorized CCTV health provider']),('camera',['Authorized camera health provider']),('ups',['APC','Eaton','Vertiv']),('nas',['Synology','QNAP']),('environment',['Approved environmental health provider'])] for v in vs]

async def handle(request):
    g=request.app['gateway'];g.check_csrf(request);tokens=await g.session(request);g.rate('ops-v9-user:'+tokens['user']['id'],30);action=request.match_info['action']
    try:
        data=await body(request,8000);org=uid(data.get('organization_id'))
        if action=='configure':
            if set(data)!={'organization_id','asset_id','configuration'}:raise ValueError()
            payload=dict(p_org=org,p_asset=uid(data['asset_id']),p_data=profile(data['configuration']))
        else:
            if set(data)!={'organization_id','asset_id','before_at','before_id'} or (data['before_at'] is None)!=(data['before_id'] is None):raise ValueError()
            payload=dict(p_org=org,p_asset=uid(data['asset_id']) if data['asset_id'] else None,p_before=utc(data['before_at']) if data['before_at'] else None,p_before_id=uid(data['before_id']) if data['before_id'] else None)
    except (ValueError,TypeError,OverflowError):raise web.HTTPBadRequest(text='Invalid hardware monitoring request') from None
    result=await call_rpc(request,'sowrix_ops_v9_'+action,payload,token=tokens['access_token'])
    if type(result) is not dict or result.get('organization_id')!=org:raise web.HTTPServiceUnavailable(text='Hardware scope not confirmed')
    if action=='snapshot':
        for key in ('nodes','history','alerts','incidents'):
            if type(result.get(key)) is not list or len(result[key])>100 or any(type(row) is not dict or row.get('organization_id')!=org for row in result[key]):raise web.HTTPServiceUnavailable(text='Hardware records not confirmed')
        if payload['p_asset'] and any(row.get('asset_id')!=payload['p_asset'] for key in ('history','alerts','incidents') for row in result[key]):raise web.HTTPServiceUnavailable(text='Hardware asset scope not confirmed')
    if action=='snapshot':result={**result,'metric_specs':SPECS,'capability_matrix':MATRIX}
    return web.json_response({'data':result})
def register(app):app.router.add_post(BASE+'/hardware/{action:configure|snapshot}',handle)
