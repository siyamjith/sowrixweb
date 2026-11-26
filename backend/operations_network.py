"""V6 network API: existing session/JWT boundary, no probes in the gateway."""
from aiohttp import web
from operations_v1.network import profile,availability,stamp
if __package__:
    from .operations_security import BASE,body,call_rpc,uuid_text
    from .operations_storage import timestamp
else:
    from operations_security import BASE,body,call_rpc,uuid_text
    from operations_storage import timestamp

MATRIX=[
    dict(adapter='tcp_availability',implemented=True,lab_tested=True,hardware_verified=False,scope='Explicit TCP connection only; no interface or packet-loss inference'),
    dict(adapter='icmp_availability',implemented=True,lab_tested=False,hardware_verified=False,scope='Existing locally approved fixed ping; no portable packet-loss/RTT parser'),
    dict(adapter='prometheus',implemented=True,lab_tested=True,hardware_verified=False,scope='Explicit normalized network series and selected IF-MIB interface fields'),
    dict(adapter='snmpv3_exporter',implemented=True,lab_tested=True,hardware_verified=False,scope='Exporter HTTP fixture and authPriv reference validation; SNMP wire/hardware unverified'),
    dict(adapter='vendor_api',implemented=True,lab_tested=True,hardware_verified=False,scope='HTTPS bearer reference with versioned JSON bridge contract; raw vendor APIs pending'),
]
def exact(data,keys):
    if type(data) is not dict or set(data)!=set(keys.split()):raise ValueError('Invalid fields')
async def handle(request):
    g=request.app['gateway'];g.check_csrf(request);tokens=await g.session(request);g.rate('ops-v6-user:'+tokens['user']['id'],30)
    action=request.match_info['action']
    try:
        data=await body(request,12000);org=uuid_text(data.get('organization_id'))
        if action=='configure':
            exact(data,'organization_id asset_id configuration');payload=dict(p_org=org,p_asset=uuid_text(data['asset_id']),p_data=profile(data['configuration']))
        elif action=='link':
            exact(data,'organization_id relationship');edge=data['relationship'];exact(edge,'source target interface_index relation enabled')
            edge={**edge,'source':uuid_text(edge['source']),'target':uuid_text(edge['target'])}
            if edge['relation'] not in ('uplink','wan','controller') or type(edge['enabled']) is not bool or (edge['interface_index'] is not None and (type(edge['interface_index']) is not int or not 1<=edge['interface_index']<=4096)):raise ValueError()
            payload=dict(p_org=org,p_data=edge)
        else:
            exact(data,'organization_id asset_id before_at before_id')
            if (data['before_at'] is None)!=(data['before_id'] is None):raise ValueError()
            payload=dict(p_org=org,p_asset=uuid_text(data['asset_id']) if data['asset_id'] else None,p_before=timestamp(data['before_at']).isoformat() if data['before_at'] else None,p_before_id=uuid_text(data['before_id']) if data['before_id'] else None)
    except (ValueError,TypeError,OverflowError):raise web.HTTPBadRequest(text='Invalid network monitoring request') from None
    result=await call_rpc(request,'sowrix_ops_v6_'+action,payload,token=tokens['access_token'])
    if type(result) is not dict or result.get('organization_id')!=org:raise web.HTTPServiceUnavailable(text='Network scope not confirmed')
    if action=='snapshot':
        limits={'nodes':100,'links':256,'history':100,'interfaces':800,'alerts':100}
        if any(type(result.get(k)) is not list or len(result[k])>n or any(type(row) is not dict or row.get('organization_id')!=org for row in result[k]) for k,n in limits.items()):raise web.HTTPServiceUnavailable(text='Network records not confirmed')
        try:
            now=stamp(result['server_time']);summaries={}
            for node in result['nodes']:
                rows=[dict(observed_at=r['observed_at'],status=r['status']) for r in result['history'] if r['asset_id']==node['asset_id']]
                oldest=min((stamp(r['observed_at']) for r in rows),default=now)
                summaries[node['asset_id']]=availability(rows,oldest.isoformat(),now.isoformat(),max(45,node.get('interval_seconds',60)*3)) if oldest<now else dict(uptime_percent=None,coverage_percent=0,unavailable_seconds=None)
        except (ValueError,KeyError,TypeError,OverflowError):raise web.HTTPServiceUnavailable(text='Network history not confirmed') from None
        result={**result,'availability':summaries,'capability_matrix':MATRIX,'hardware_verified':False}
    return web.json_response({'data':result})
def register(app):app.router.add_post(BASE+'/network/{action:configure|link|snapshot}',handle)
