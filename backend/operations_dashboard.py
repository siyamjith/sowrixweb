"""V10.1 session/JWT/CSRF scoped read-only dashboard; no collector execution."""
from aiohttp import web
from operations_v1.dashboard import query,validate
if __package__:
    from .operations_security import BASE,body,call_rpc
else:
    from operations_security import BASE,body,call_rpc
async def handle(request):
    g=request.app['gateway'];g.check_csrf(request);tokens=await g.session(request);g.rate('ops-v101-user:'+tokens['user']['id'],30)
    try:org,f=query(await body(request,8000))
    except (ValueError,TypeError,OverflowError):raise web.HTTPBadRequest(text='Invalid dashboard filter') from None
    result=await call_rpc(request,'sowrix_ops_v101_monitor',dict(p_org=org,p_filter=f),token=tokens['access_token'])
    try:validate(result,org,f)
    except (ValueError,TypeError,KeyError,OverflowError):raise web.HTTPServiceUnavailable(text='Monitoring dashboard scope not confirmed') from None
    return web.json_response({'data':result},headers={'Cache-Control':'no-store'})
def register(app):app.router.add_post(BASE+'/monitor/query',handle)
