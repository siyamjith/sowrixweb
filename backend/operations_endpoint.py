"""V8 fixed endpoint RPCs; collection never executes in the gateway."""
from aiohttp import web
from operations_v1.endpoint import profile
from operations_v1.evidence import uid,utc
if __package__:
    from .operations_security import BASE,body,call_rpc
else:
    from operations_security import BASE,body,call_rpc
async def handle(request):
    g=request.app['gateway'];g.check_csrf(request);tokens=await g.session(request);g.rate('ops-v8-user:'+tokens['user']['id'],30);action=request.match_info['action']
    try:
        data=await body(request,8000);org=uid(data.get('organization_id'))
        if action=='configure':
            if set(data)!={'organization_id','asset_id','configuration'}:raise ValueError()
            payload=dict(p_org=org,p_asset=uid(data['asset_id']),p_data=profile(data['configuration']))
        else:
            if set(data)!={'organization_id','asset_id','before_at','before_id'} or (data['before_at'] is None)!=(data['before_id'] is None):raise ValueError()
            payload=dict(p_org=org,p_asset=uid(data['asset_id']) if data['asset_id'] else None,p_before=utc(data['before_at']) if data['before_at'] else None,p_before_id=uid(data['before_id']) if data['before_id'] else None)
    except (ValueError,TypeError,OverflowError):raise web.HTTPBadRequest(text='Invalid endpoint monitoring request') from None
    result=await call_rpc(request,'sowrix_ops_v8_'+action,payload,token=tokens['access_token'])
    if type(result) is not dict or result.get('organization_id')!=org:raise web.HTTPServiceUnavailable(text='Endpoint scope not confirmed')
    if action=='snapshot':
        for key in ('nodes','history','alerts'):
            if type(result.get(key)) is not list or len(result[key])>100 or any(type(row) is not dict or row.get('organization_id')!=org for row in result[key]):raise web.HTTPServiceUnavailable(text='Endpoint records not confirmed')
        if payload['p_asset'] and any(row.get('asset_id')!=payload['p_asset'] for key in ('history','alerts') for row in result[key]):raise web.HTTPServiceUnavailable(text='Endpoint asset scope not confirmed')
    return web.json_response({'data':result})
def register(app):app.router.add_post(BASE+'/endpoint/{action:configure|snapshot}',handle)
