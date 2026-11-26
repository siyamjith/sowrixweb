"""V10 session-bound read-only NOC and audited CSV export."""
from aiohttp import web
from operations_v1.noc import query,report,csv_report
if __package__:
    from .operations_security import BASE,body,call_rpc
else:
    from operations_security import BASE,body,call_rpc

async def handle(request):
    g=request.app['gateway'];g.check_csrf(request);tokens=await g.session(request);g.rate('ops-v10-user:'+tokens['user']['id'],30)
    try:org,f=query(await body(request,8000))
    except (ValueError,TypeError,OverflowError):raise web.HTTPBadRequest(text='Invalid NOC query') from None
    export=request.match_info['action']=='export'
    if export and f['view']!='report':raise web.HTTPBadRequest(text='Select an asset report')
    result=await call_rpc(request,'sowrix_ops_v10_query',dict(p_org=org,p_filter=f),token=tokens['access_token'])
    if type(result) is not dict or result.get('organization_id')!=org:raise web.HTTPServiceUnavailable(text='NOC scope not confirmed')
    for key,bound in (('nodes',100),('history',5000),('incidents',100),('timeline',100),('links',1001),('sites',10000)):
        if type(result.get(key)) is not list or len(result[key])>bound or any(type(row) is not dict or row.get('organization_id')!=org for row in result[key]):raise web.HTTPServiceUnavailable(text='NOC records not confirmed')
    if f['asset_id'] and any(row.get('asset_id')!=f['asset_id'] for k in ('history','nodes','incidents','timeline') for row in result[k]):raise web.HTTPServiceUnavailable(text='NOC asset scope not confirmed')
    if f['view'] in ('report','detail'):
        try:result['report']=report(result['history'],f['from_at'],f['to_at'],result.get('report_interval_seconds',60),result.get('history_truncated',False))
        except (ValueError,TypeError,KeyError,OverflowError):raise web.HTTPServiceUnavailable(text='NOC evidence not valid') from None
    if export:
        # The RPC repeats authorization and records the actor; no service-token export.
        await call_rpc(request,'sowrix_ops_v10_export_audit',dict(p_org=org,p_asset=f['asset_id']),token=tokens['access_token'])
        return web.json_response({'data':{'organization_id':org,'asset_id':f['asset_id'],'csv':csv_report(org,f['asset_id'],result['report'])}},headers={'Cache-Control':'no-store'})
    return web.json_response({'data':result},headers={'Cache-Control':'no-store'})

def register(app):app.router.add_post(BASE+'/noc/{action:query|export}',handle)
