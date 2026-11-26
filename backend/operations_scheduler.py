"""V5 fixed scheduler RPC boundary; never runs network probes in the gateway."""
import re
from aiohttp import web
if __package__:
    from .operations_security import BASE,body,call_rpc,uuid_text,validate_batch
    from .operations_storage import timestamp
else:
    from operations_security import BASE,body,call_rpc,uuid_text,validate_batch
    from operations_storage import timestamp

async def user(request):
    g=request.app['gateway'];g.check_csrf(request);tokens=await g.session(request)
    g.rate('ops-v5-user:'+tokens['user']['id'],30)
    return tokens

def exact(data,fields):
    if type(data) is not dict or set(data)!=set(fields.split()):raise ValueError('Invalid fields')

async def session_action(request):
    tokens=await user(request);action=request.match_info['action']
    try:
        data=await body(request,8000);org=uuid_text(data.get('organization_id'))
        if action=='configure':
            exact(data,'organization_id asset_id configuration');p={'p_org':org,'p_asset':uuid_text(data['asset_id']),'p_data':data['configuration']}
            conf=data['configuration'];exact(conf,'enabled interval_seconds timeout_seconds failure_confirm recovery_confirm thresholds')
            if type(conf['enabled']) is not bool or any(type(conf[k]) is not int or not lo<=conf[k]<=hi for k,lo,hi in [('interval_seconds',15,3600),('timeout_seconds',1,8),('failure_confirm',1,10),('recovery_confirm',1,10)]):raise ValueError()
            if type(conf['thresholds']) is not list or len(conf['thresholds'])>8:raise ValueError()
            # The direct-provider SQL RPC owns the authoritative unit and threshold validation.
        elif action=='window':
            exact(data,'organization_id asset_id starts_at ends_at id enabled')
            start=timestamp(data['starts_at']);end=timestamp(data['ends_at'])
            if end<=start or type(data['enabled']) is not bool:raise ValueError()
            p=dict(p_org=org,p_asset=uuid_text(data['asset_id']) if data['asset_id'] else None,p_start=start.isoformat(),p_end=end.isoformat(),p_id=uuid_text(data['id']) if data['id'] else None,p_enabled=data['enabled'])
        elif action=='ack':
            exact(data,'organization_id check_id');p=dict(p_org=org,p_check=uuid_text(data['check_id']))
        elif action=='snapshot':
            exact(data,'organization_id before')
            if data['before'] is not None and (type(data['before']) is not int or not 1<=data['before']<=2**63-1):raise ValueError()
            p=dict(p_org=org,p_before=data['before'])
        else:raise web.HTTPNotFound()
    except (ValueError,TypeError,OverflowError):raise web.HTTPBadRequest(text='Invalid scheduler request') from None
    result=await call_rpc(request,'sowrix_ops_v5_'+action,p,token=tokens['access_token'])
    if type(result) is not dict:raise web.HTTPServiceUnavailable(text='Scheduler response not confirmed')
    if action=='snapshot':
        if result.get('organization_id')!=org or any(type(result.get(k)) is not list or len(result[k])>100 for k in ('checks','runs','windows','timeline')) or any(type(row) is not dict or row.get('organization_id')!=org for k in ('checks','runs','windows','timeline') for row in result[k]):
            raise web.HTTPServiceUnavailable(text='Scheduler tenant scope not confirmed')
    elif action in ('configure','window') and result.get('organization_id')!=org:
        raise web.HTTPServiceUnavailable(text='Scheduler configuration scope not confirmed')
    elif action=='ack' and type(result.get('acknowledged')) is not bool:raise web.HTTPServiceUnavailable(text='Acknowledgement not confirmed')
    return web.json_response({'data':result})

async def collector_action(request):
    g=request.app['gateway'];g.rate('ops-v5-worker:'+(request.remote or 'unknown'),600)
    match=re.fullmatch(r'Bearer ([0-9a-f]{64})',request.headers.get('Authorization',''))
    if not match:raise web.HTTPUnauthorized(text='Collector authentication required')
    action=request.match_info['action']
    try:
        data=await body(request,20000);owner=uuid_text(data.get('owner'))
        if action=='claim':
            exact(data,'owner limit')
            if type(data['limit']) is not int or not 1<=data['limit']<=4:raise ValueError()
            p=dict(p_token=match[1],p_owner=owner,p_limit=data['limit'])
        elif action=='finish':
            exact(data,'owner run_id result');p=dict(p_token=match[1],p_owner=owner,p_run=uuid_text(data['run_id']),p_result=data['result'])
            if type(data['result']) is dict and 'hardware' in data['result']:
                exact(data['result'],'outcome sample hardware')
                from operations_v1.hardware import metadata
                metadata(data['result']['hardware'])
                if data['result']['outcome']!='completed':raise ValueError()
            elif type(data['result']) is dict and 'endpoint' in data['result']:
                exact(data['result'],'outcome sample endpoint')
                from operations_v1.endpoint import metadata
                metadata(data['result']['endpoint'])
                if data['result']['outcome']!='completed':raise ValueError()
            elif type(data['result']) is dict and 'firewall' in data['result']:
                exact(data['result'],'outcome sample firewall')
                from operations_v1.firewall import metadata
                metadata(data['result']['firewall'])
                if data['result']['outcome']!='completed':raise ValueError()
            else:exact(data['result'],'outcome sample')
            if data['result']['outcome']=='completed':
                validate_batch({'sequence':1,'samples':[data['result']['sample']]})
            elif data['result']['outcome'] not in ('timeout','unavailable','cancelled') or data['result']['sample'] is not None:raise ValueError()
        else:raise web.HTTPNotFound()
    except (ValueError,TypeError,OverflowError):raise web.HTTPBadRequest(text='Invalid scheduler job request') from None
    result=await call_rpc(request,'sowrix_ops_v5_'+action,p,service=True)
    if type(result) is not dict:raise web.HTTPServiceUnavailable(text='Scheduler receipt not confirmed')
    if action=='claim' and (set(result)!={'jobs'} or type(result['jobs']) is not list or len(result['jobs'])>data['limit']):raise web.HTTPServiceUnavailable(text='Job lease not confirmed')
    if action=='finish' and (result.get('run_id')!=p['p_run'] or type(result.get('duplicate')) is not bool or result.get('state') not in ('completed','timeout','unavailable','cancelled')):raise web.HTTPServiceUnavailable(text='Job completion not confirmed')
    if action=='finish' and result['state']=='completed':
        try:uuid_text(result.get('evidence_id'))
        except ValueError:raise web.HTTPServiceUnavailable(text='Job evidence not confirmed') from None
    return web.json_response(result)

def register(app):
    app.router.add_post(BASE+'/scheduler/{action:configure|window|ack|snapshot}',session_action)
    app.router.add_post(BASE+'/scheduler/collectors/{action:claim|finish}',collector_action)
