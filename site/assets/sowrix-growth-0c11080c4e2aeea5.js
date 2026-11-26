/* SOWRIX R46.7 — Business Growth Center. Private RPCs enforce every authorization.
   No payment, legal e-signature, provisioning, public-email or calendar action occurs here. */
(()=>{'use strict';if(window.SOWRIXR467)return;
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const user=()=>window.__sxUser||null,role=()=>String(user()?.role||'').toLowerCase();
 const admin=()=>['admin','super_admin'].includes(role()),client=()=>role()==='client';
 const time=v=>{if(!v)return 'Not scheduled';const d=new Date(v);return Number.isFinite(d.getTime())?d.toLocaleString('en-IN'):'—'};
 let layer=null,returnFocus=null,originalUser='';
 const form=(name,label,type='text',attrs='')=>`<label>${esc(label)}<input name="${name}" type="${type}" ${attrs}></label>`;
 async function rpc(name,args={}){const uid=user()?.id;if(!uid||!window.sowrixSupabase)throw Error('Sign in to your SOWRIX workspace.');
  const {data,error}=await window.sowrixSupabase.rpc(name,args);
  if(uid!==user()?.id)throw Error('Account changed; reopen this tool.');
  if(error)throw Error('Access denied or R46.7 migration not installed. Contact an administrator.');return data;
 }
 const crmAllowed=(action='view')=>role()!=='admin'||sowrixActionAllowed(user(),'crm',action);
 const enquiryAllowed=()=>role()!=='admin'||sowrixActionAllowed(user(),'enquiries','view');
 const board=section=>rpc('sowrix_r467_board',{p_section:section});
 const apply=(action,data)=>rpc('sowrix_r467_apply',{p_action:action,p_data:data});
 function close(){layer?.remove();layer=null;if(returnFocus?.isConnected)returnFocus.focus();returnFocus=null;}
 function frame(title,body){close();originalUser=user()?.id||'';if(!originalUser)return null;returnFocus=document.activeElement;
  layer=document.createElement('div');layer.className='sx-r467-overlay';layer.innerHTML=`<section class="sx-r467-panel" role="dialog" aria-modal="true" aria-labelledby="sx-r467-title"><header><div><small>SOWRIX TECHNOLOGIES · R46.7</small><h2 id="sx-r467-title">${esc(title)}</h2></div><button type="button" data-close aria-label="Close Growth Center">✕</button></header><main>${body}<p class="sx-r467-message" role="status" aria-live="polite"></p></main><footer>Secured by account permissions · No unattended external actions</footer></section>`;
  document.body.appendChild(layer);layer.querySelector('[data-close]').onclick=close;layer.onclick=e=>{if(e.target===layer)close()};
  layer.onkeydown=e=>{if(e.key==='Escape'){e.preventDefault();close()}if(e.key==='Tab'){
   const items=[...layer.querySelectorAll('button,input,select,textarea,a[href],summary')].filter(x=>!x.disabled&&x.getClientRects().length);
   if(items.length&&e.shiftKey&&document.activeElement===items[0]){e.preventDefault();items.at(-1).focus()}
   else if(items.length&&!e.shiftKey&&document.activeElement===items.at(-1)){e.preventDefault();items[0].focus()}
  }};layer.querySelector('[data-close]').focus();return layer.querySelector('main');
 }
 function note(msg){const el=layer?.querySelector('.sx-r467-message');if(el)el.textContent=msg;}
 const back='<button type="button" data-back>← Growth Center</button>';
 const noRows='<p>No authorized records yet.</p>';
 function wireBack(el){el?.querySelector('[data-back]')?.addEventListener('click',home)}
 async function start(section,title,template){const b=frame(title,'<p role="status">Loading authorized data…</p>');
  try{const d=await board(section);if(!b?.isConnected||originalUser!==user()?.id)return null;
   b.innerHTML=template(d)+back+'<p class="sx-r467-message" role="status" aria-live="polite"></p>';wireBack(b);return b;
  }catch(e){note(e.message);return null}
 }
 function bindForm(main,selector,action,parse,refresh){main?.querySelector(selector)?.addEventListener('submit',async e=>{e.preventDefault();
  const btn=e.currentTarget.querySelector('[type="submit"]');btn.disabled=true;
  try{const okay=await apply(action,parse(e.currentTarget.elements));if(okay===false)throw Error('No change was made. Refresh records.');
   await refresh();note('Saved. External notifications and payments are not sent by this action.');}
  catch(err){note(err.message);btn.disabled=false}
 })}
 function bindActions(main,selector,action,parse,refresh){main?.querySelectorAll(selector).forEach(btn=>btn.onclick=async()=>{
  btn.disabled=true;try{const ok=await apply(action,parse(btn));if(ok===false)throw Error('Record unchanged.');await refresh();note('Change saved.');}
  catch(err){note(err.message);btn.disabled=false}
 })}
 const orgSelect=orgs=>`<label>Client organization<select name="organization_id" required><option value="">Select client</option>${orgs.map(x=>`<option value="${esc(x.id)}">${esc(x.organization_name)}</option>`).join('')}</select></label>`;
 function home(){const routes=admin()?[['crm','Sales CRM'],['consultations','Consultation requests'],['messages','Client communication'],['agreements','Agreement review'],['analytics','Business analytics'],['security','Security monitoring'],['status','Public status updates']]:client()?[['consultations','Consultation requests'],['messages','Client communication'],['agreements','My agreements']]:[];
  const b=frame('Business Growth Center',`<p>Turn approved client enquiries into managed sales opportunities. Meeting requests require confirmation, and document acknowledgement is not a legal signature.</p><div class="sx-r467-grid">${routes.filter(([k])=>(k!=='crm'||crmAllowed())&&(!['analytics','security'].includes(k)||role()==='super_admin')).map(([k,t])=>`<button data-open="${k}" type="button">${esc(t)} →</button>`).join('')||'<p>No tools available for this role.</p>'}</div><p><small>Public website visitors can request a consultation through the existing Contact page.</small></p>`);
  b?.querySelectorAll('[data-open]').forEach(x=>x.onclick=()=>open(x.dataset.open));
 }
 // R102.1: pipeline metrics are scoped to the records returned by the authorized board.
 const stages=['new','contacted','qualified','proposal','won','lost'];
 const overdue=(lead,now)=>!['won','lost'].includes(lead.stage)&&!!lead.next_followup_at&&Number.isFinite(Date.parse(lead.next_followup_at))&&Date.parse(lead.next_followup_at)<now;
 const pipelineStats=(rows,now)=>({total:rows.length,overdue:rows.filter(l=>overdue(l,now)).length,qualified:rows.filter(l=>l.stage==='qualified').length,won:rows.filter(l=>l.stage==='won').length});
 const pipelineMatch=(lead,filter,now)=>filter==='all'||(filter==='overdue'?overdue(lead,now):lead.stage===filter);
 const conversionAllowed=()=>admin()&&['crm:view','crm:edit','clients:view','clients:create','enquiries:view'].every(k=>{const [m,a]=k.split(':');return sowrixActionAllowed(user(),m,a)});
 const conversionMessage=r=>r?.status==='duplicate_review'?'Matching client name or email found. Review Client Management; no new record created.':r?.status==='created'||r?.status==='already_converted'?`Client record ${r.client_code} is available. Login invitation and DEFENSOWRIX access are separate.`:'Conversion not confirmed. Refresh records.';
 async function crm(){if(!admin()||!crmAllowed())return home();const actor=user()?.id;const canCreate=crmAllowed('create')&&enquiryAllowed(),canEdit=crmAllowed('edit');const [leads,enquiries]=await Promise.all([board('crm'),canCreate?board('enquiries'):Promise.resolve([])]);
  const canConvert=conversionAllowed();let conversionReady=false,converted=new Map();
  if(canConvert){try{const rows=await rpc('sowrix_r102_conversion_status',{p_leads:leads.map(l=>l.id)});if(!Array.isArray(rows))throw Error('Invalid conversion response');converted=new Map(rows.map(r=>[r.lead_id,r.client_code]));conversionReady=true;}catch(e){conversionReady=false;}}
  if(actor!==user()?.id||!admin()||!crmAllowed())return;
  const now=Date.now(),stats=pipelineStats(leads,now);
  const b=frame('Sales CRM & Follow-ups',`<p>Real website enquiries only. Marking a lead “won” does not create an organization or charge a customer. Authorized staff can explicitly convert won leads into client records. Follow-up times are tracked; sending remains disabled until verified.</p>
  ${canConvert&&!conversionReady?'<p role="status">Client conversion unavailable. Ask an administrator to verify migration 65.</p>':''}
  <p><small>Summary covers only the loaded records (up to 120 leads), not company-wide totals.</small></p>
  <div class="sx-r467-stats">${[['Loaded leads',stats.total],['Qualified',stats.qualified],['Won',stats.won],['Overdue follow-ups',stats.overdue]].map(([label,value])=>`<article><span>${label}</span><strong>${value}</strong></article>`).join('')}</div>
  <label>Filter sales pipeline<select data-pipeline-filter>${['all','overdue',...stages].map(s=>`<option value="${s}">${s==='all'?'All loaded leads':s==='overdue'?'Overdue follow-ups':s}</option>`).join('')}</select></label><p data-pipeline-count role="status"></p>
  <div class="sx-r467-list">${leads.map((l,i)=>`<article data-lead-index="${i}"><h3>${esc(l.contact_name)} · ${esc(l.company||'Individual')}</h3><p>${esc(l.service_interest||'Technology services')}</p><small>Follow-up: ${time(l.next_followup_at)} · Notes: ${Number(l.note_count)||0}</small>
   <label>Sales stage<select data-stage="${esc(l.id)}" ${canEdit?'':'disabled'}>${stages.map(s=>`<option value="${s}" ${l.stage===s?'selected':''}>${s}</option>`).join('')}</select></label>
   ${canEdit&&l.stage!=='won'&&l.stage!=='lost'?`<form data-followup="${esc(l.id)}">${form('when','Next follow-up','datetime-local')}<button type="submit">Set follow-up</button></form>`:''}
   ${converted.has(l.id)?`<p>Converted client: <strong>${esc(converted.get(l.id))}</strong></p>`:conversionReady&&l.stage==='won'?`<form data-convert="${esc(l.id)}"><label><input type="checkbox" name="confirm" required> I confirm this won lead should become a client record.</label><button type="submit">Create client record</button><small>No login invitation or DEFENSOWRIX activation is sent.</small></form>`:''}
   ${canEdit?`<form data-note="${esc(l.id)}"><label>Internal note<textarea name="body" minlength="5" maxlength="1200" required rows="2"></textarea></label><button type="submit">Add note</button></form>`:''}</article>`).join('')||noRows}</div>
  ${canCreate?`<details><summary>Add existing website enquiry to pipeline</summary><form data-create><label>Untracked enquiries<select name="enquiry_id" required><option value="">Choose enquiry</option>${enquiries.map(e=>`<option value="${esc(e.id)}">${esc(e.name)} · ${esc(e.service_interest||'General')} · ${time(e.created_at)}</option>`).join('')}</select></label><button type="submit">Create lead</button></form></details>`:''}
  ${back}<p class="sx-r467-message" role="status" aria-live="polite"></p>`);wireBack(b);
  const filter=b?.querySelector('[data-pipeline-filter]');
  function showPipeline(){if(!filter)return;let count=0;for(const card of b.querySelectorAll('[data-lead-index]')){const visible=pipelineMatch(leads[Number(card.dataset.leadIndex)],filter.value,Date.now());card.hidden=!visible;if(visible)count++;}b.querySelector('[data-pipeline-count]').textContent=`Showing ${count} of ${leads.length} loaded leads`;}
  if(filter){filter.onchange=showPipeline;showPipeline();}
  b?.querySelectorAll('[data-convert]').forEach(f=>f.addEventListener('submit',async e=>{e.preventDefault();const btn=f.querySelector('[type=submit]');if(!conversionAllowed()||!f.elements.confirm.checked){note('Conversion permission and confirmation required.');return;}btn.disabled=true;try{const r=await rpc('sowrix_r102_convert_client',{p_lead:f.dataset.convert,p_confirm:true});if(r?.status==='created'||r?.status==='already_converted'){await crm();note(conversionMessage(r));}else{note(conversionMessage(r));btn.disabled=false;}}catch(err){note(err.message);btn.disabled=false;}}));
  bindForm(b,'[data-create]','lead_create',f=>({enquiry_id:f.enquiry_id.value}),crm);
  b?.querySelectorAll('[data-stage]').forEach(x=>x.onchange=async()=>{x.disabled=true;try{const changed=await apply('lead_stage',{id:x.dataset.stage,stage:x.value});if(changed!==true)throw Error('Stage not saved. Refresh and try again.');await crm();note('Stage saved; no account automatically created.')}catch(e){const previous=leads.find(l=>l.id===x.dataset.stage);if(previous)x.value=previous.stage;note(e.message);x.disabled=false}});
  b?.querySelectorAll('[data-followup]').forEach(x=>bindForm(b,`[data-followup="${x.dataset.followup}"]`,'lead_followup',f=>({id:x.dataset.followup,when:f.when.value?new Date(f.when.value).toISOString():''}),crm));
  b?.querySelectorAll('[data-note]').forEach(x=>bindForm(b,`[data-note="${x.dataset.note}"]`,'lead_note',f=>({id:x.dataset.note,body:f.body.value}),crm));
 }
 async function consultations(){if(!admin()&&!client())return home();const [rows,orgs]=await Promise.all([board('consultations'),rpc('sowrix_r467_org_choices')]);
  const b=frame('Consultation Requests',`<p>Time requests are not confirmed bookings until a company Admin reviews them. Times are displayed in your device's local timezone.</p><div class="sx-r467-list">${rows.map(x=>`<article><h3>${esc(x.subject)}</h3><p>${esc(x.organization_name)} · ${time(x.preferred_at)}</p><small>${esc(x.state)}</small>
   ${admin()&&x.state==='requested'?`<div class="sx-r467-actions"><button data-appointment="${esc(x.id)}" data-state="confirmed">Confirm</button><button data-appointment="${esc(x.id)}" data-state="declined">Decline</button></div>`:''}</article>`).join('')||noRows}</div>
   <details><summary>Request a consultation</summary><form data-create>${orgSelect(orgs)}${form('subject','What would you like to discuss?','text','minlength="5" maxlength="160" required')}${form('preferred_at','Preferred local date & time','datetime-local','required')}<button type="submit">Request time</button></form></details>
  ${back}<p class="sx-r467-message" role="status" aria-live="polite"></p>`);wireBack(b);
  bindForm(b,'[data-create]','consultation_request',f=>({organization_id:f.organization_id.value,subject:f.subject.value,preferred_at:new Date(f.preferred_at.value).toISOString()}),consultations);
  bindActions(b,'[data-appointment]','consultation_state',x=>({id:x.dataset.appointment,state:x.dataset.state}),consultations);
 }
 async function messages(){if(!admin()&&!client())return home();const [rows,orgs]=await Promise.all([board('messages'),rpc('sowrix_r467_org_choices')]);
  const b=frame('Client Communication Center',`<p>Messages stay in the private client organization workspace. This is not encrypted end-to-end chat or email delivery.</p><div class="sx-r467-list">${rows.map(x=>`<article><h3>${esc(x.subject)}</h3><small>${esc(x.organization_name)} · ${time(x.created_at)} · ${esc(x.author)}</small><p class="sx-r467-body">${esc(x.body)}</p></article>`).join('')||noRows}</div>
  <details><summary>Post message to client workspace</summary><form data-create>${orgSelect(orgs)}${form('subject','Subject','text','minlength="4" maxlength="120" required')}<label>Message<textarea name="body" minlength="3" maxlength="2000" required rows="4"></textarea></label><button type="submit">Post in workspace</button></form></details>
  ${back}<p class="sx-r467-message" role="status" aria-live="polite"></p>`);wireBack(b);
  bindForm(b,'[data-create]','message_create',f=>({organization_id:f.organization_id.value,subject:f.subject.value,body:f.body.value}),messages);
 }
 async function agreements(){if(!admin()&&!client())return home();const [rows,orgs]=await Promise.all([board('agreements'),admin()?rpc('sowrix_r467_org_choices'):Promise.resolve([])]);
  const b=frame('Agreement Review',`<p><strong>Not a legal e-signature system.</strong> Client acknowledgement means “viewed” only. Verified legally binding signing requires an approved e-sign provider and independent evidence.</p>
  <div class="sx-r467-list">${rows.map(x=>`<article><h3>${esc(x.title)}</h3><p>${esc(x.organization_name)} · Reference: ${esc(x.document_reference)}</p><small>${esc(x.state)} · ${x.acknowledged?'Acknowledged viewed':'Not acknowledged'}</small>
   ${admin()&&x.state==='draft'?`<button data-agreement="${esc(x.id)}" data-state="review">Send for internal review</button>`:''}
   ${admin()&&x.state==='review'&&!x.is_creator?`<button data-agreement="${esc(x.id)}" data-state="approved">Independent approval</button>`:''}
   ${client()&&x.state==='approved'&&!x.acknowledged?`<button data-ack="${esc(x.id)}">Acknowledge viewed (not signature)</button>`:''}</article>`).join('')||noRows}</div>
  ${admin()?`<details><summary>Create agreement review draft</summary><form data-create>${orgSelect(orgs)}${form('title','Agreement title','text','minlength="5" maxlength="140" required')}${form('document_reference','Private document reference (not a download URL)','text','minlength="5" maxlength="250" required')}<button type="submit">Create review draft</button></form></details>`:''}
  ${back}<p class="sx-r467-message" role="status" aria-live="polite"></p>`);wireBack(b);
  bindForm(b,'[data-create]','agreement_create',f=>({organization_id:f.organization_id.value,title:f.title.value,document_reference:f.document_reference.value}),agreements);
  bindActions(b,'[data-agreement]','agreement_review',x=>({id:x.dataset.agreement,state:x.dataset.state}),agreements);
  bindActions(b,'[data-ack]','agreement_ack',x=>({id:x.dataset.ack}),agreements);
 }
 async function analytics(){if(role()!=='super_admin')return home();const b=await start('analytics','Business Analytics',d=>{
  const values=[['Website enquiries',d.enquiries],['CRM leads',d.leads],['Qualified leads',d.qualified],['Won (manually marked)',d.won],['Overdue follow-ups',d.followups_due],['Consultation requests',d.consultations_requested],['Messages (7 days)',d.open_client_messages],['Feedback responses',d.feedback_count],['Recent audit entries (24h)',d.recent_audit_events]];
  return `<p>Counts from authorized database records, not financial revenue. No guessed conversion rate or unverified uptime.</p><div class="sx-r467-stats">${values.map(([label,value])=>`<article><span>${esc(label)}</span><strong>${Number(value)||0}</strong></article>`).join('')}</div><p>Ticket feedback average: <strong>${d.feedback_mean===null?'Not available':esc(d.feedback_mean)+' / 5'}</strong> (${Number(d.feedback_count)||0} submitted ratings).</p>`});return b;
 }
 async function security(){if(role()!=='super_admin')return home();const b=await start('security','Security Operations Overview',d=>{
  const values=[['Captured audit events (24h)',d.audit_events_24h],['Possible access failures (24h)',d.possible_access_failures_24h],['R46.7 activity records (24h)',d.business_actions_24h],['Agreements awaiting review',d.unreviewed_agreements],['Unpublished service notices',d.unpublished_notices]];
  return `<p>Read-only counts from application audit records. This dashboard is NOT a comprehensive intrusion detector; failed logins outside this application's log require provider telemetry. Review upstream authentication, MFA, web logs and backup alerts separately.</p><div class="sx-r467-stats">${values.map(([name,value])=>`<article><span>${esc(name)}</span><strong>${Number(value)||0}</strong></article>`).join('')}</div>`;
 });return b;}
 async function status(){if(!admin())return home();const rows=await board('status');
  const b=frame('Public Service Status Updates',`<p><strong>Not automated uptime monitoring.</strong> Publish only independently verified incidents/maintenance notices. A separate Admin must approve publication.</p><p>View public notice page: <a href="/status.html" target="_blank" rel="noopener">SOWRIX service status</a></p>
  <div class="sx-r467-list">${rows.map(x=>`<article><h3>${esc(x.service)} · ${esc(x.category)}</h3><p>${esc(x.message)}</p><small>${x.published?'Published':'Draft'} · ${time(x.created_at)}</small>${!x.published?`<button data-publish="${esc(x.id)}">Approve & publish (second Admin)</button>`:`<button data-unpublish="${esc(x.id)}">Unpublish notice</button>`}</article>`).join('')||noRows}</div>
  <details><summary>Draft service notice</summary><form data-create>${form('service','Service','text','minlength="3" maxlength="80" required')}<label>Category<select name="category"><option value="notice">Notice</option><option value="maintenance">Maintenance</option><option value="degraded">Degraded service</option><option value="incident">Incident</option><option value="resolved">Resolved issue</option></select></label><label>Public message (never include customer identities)<textarea name="message" minlength="10" maxlength="500" required></textarea></label><button type="submit">Create draft</button></form></details>
  ${back}<p class="sx-r467-message" role="status" aria-live="polite"></p>`);wireBack(b);
  bindForm(b,'[data-create]','status_create',f=>({service:f.service.value,category:f.category.value,message:f.message.value}),status);
  bindActions(b,'[data-publish]','status_publish',x=>({id:x.dataset.publish}),status);
  bindActions(b,'[data-unpublish]','status_unpublish',x=>({id:x.dataset.unpublish}),status);
 }
 function open(name){if(!user()?.id)return;const routes={crm,consultations,messages,agreements,analytics,security,status};if(!routes[name])return;
  if(!admin()&&(!client()||!['consultations','messages','agreements'].includes(name)))return home();
  Promise.resolve().then(()=>routes[name]()).catch(err=>{home();note(err.message)})
 }
 window.addEventListener('sowrix:r467-open',()=>{window.SOWRIXR465?.close?.();window.SOWRIXR466?.close?.();home()});
 window.addEventListener('hashchange',close);window.addEventListener('pagehide',close);
 window.SOWRIXR467={home,open,close};
})();
