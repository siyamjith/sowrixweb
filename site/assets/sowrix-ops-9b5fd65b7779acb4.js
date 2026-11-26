/* SOWRIX R46.5 — scoped search, document register, employee requests and client dashboard.
   No service credentials, default public data, direct tables or unattended approvals. */
(()=>{'use strict';if(window.SOWRIXR465)return;
 const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const user=()=>window.__sxUser||null,active=()=>Boolean(user()?.id);
 const role=()=>String(user()?.role||'').toLowerCase();
 const admin=()=>['admin','super_admin'].includes(role()),hr=()=>admin()||['hr','hr_staff','hr_manager'].includes(role());
 const client=()=>role()==='client';
 const stamp=value=>{const d=new Date(value);return Number.isFinite(d.valueOf())?d.toLocaleString('en-IN'):'—';};
 const call=async(name,args={})=>{
  const uid=user()?.id;if(!uid||!window.sowrixSupabase)throw Error('Sign in to a SOWRIX workspace first.');
  const {data,error}=await window.sowrixSupabase.rpc(name,args);
  if(user()?.id!==uid)throw Error('Account changed. Reopen this tool.');
  if(error)throw Error('Tool unavailable or permission denied. Check R46.5 migration and session.');
  return data;
 };
 let host,launch,returnFocus,sessionId='';
 const loading=()=>'<p role="status">Loading authorized records…</p>';
 function status(message){const el=host?.querySelector('[data-r465-status]');if(el)el.textContent=message;}
 function close(){host?.remove();host=null;if(launch)launch.setAttribute('aria-expanded','false');if(returnFocus?.isConnected)returnFocus.focus();returnFocus=null;}
 function frame(title,content){if(!active())return;close();returnFocus=document.activeElement;
  host=document.createElement('div');host.className='sx-r465-overlay';host.innerHTML=`<section class="sx-r465-panel" role="dialog" aria-modal="true" aria-labelledby="sx-r465-title"><header><div><small>SOWRIX · SECURE WORKSPACE</small><h2 id="sx-r465-title">${esc(title)}</h2></div><button data-r465-close aria-label="Close enterprise tools" type="button">✕</button></header><main>${content}<p data-r465-status role="status" aria-live="polite"></p></main><footer>Private workspace · Requests require review · Client access is scoped on the server</footer></section>`;
  document.body.appendChild(host);host.querySelector('[data-r465-close]').onclick=close;
  host.onclick=e=>{if(e.target===host)close();};
  host.onkeydown=e=>{if(e.key==='Escape'){e.preventDefault();close();}if(e.key==='Tab'){const els=[...host.querySelectorAll('button,input,select,textarea,a[href]')].filter(x=>!x.disabled&&x.getClientRects().length);if(!els.length)return;if(e.shiftKey&&document.activeElement===els[0]){e.preventDefault();els.at(-1).focus();}if(!e.shiftKey&&document.activeElement===els.at(-1)){e.preventDefault();els[0].focus();}}};
  host.querySelector('[data-r465-close]').focus();launch?.setAttribute('aria-expanded','true');return host.querySelector('main');
 }
 function back(main){main?.querySelector('[data-r465-back]')?.addEventListener('click',home);}
 const docAllowed=(action='view')=>user()?.role!=='admin'||sowrixActionAllowed(user(),'documents',action);
 function home(){const menu=[['business','Business Center'],['search','Unified Search'],['documents','Document Register']];
  if(client())menu.push(['client','My Client Services']);else menu.push(['requests','Employee Self-Service']);
  if(admin())menu.push(['ops','System & Operations Pulse']);
  menu.push(['suite','R46.6 Enterprise Suite']);
  menu.push(['growth','R46.7 Business Growth Center']);
  const b=frame('Workspace tools',`<p>Search and review only records your account may access. No demo customer records or automatic approvals.</p><div class="sx-r465-grid">${menu.filter(([key])=>key!=='documents'||docAllowed()).map(([key,title])=>`<button data-r465-route="${key}">${title}</button>`).join('')}</div>`);
  b?.querySelectorAll('[data-r465-route]').forEach(x=>x.onclick=()=>open(x.dataset.r465Route));
 }
 async function search(){const b=frame('Unified Search',`<p>Search your authorized projects, support tickets, invoice numbers and published knowledge titles.</p><form data-r465-search><label>Search term<input name="query" minlength="2" maxlength="80" required autocomplete="off" placeholder="Project or ticket title"></label><button>Search</button></form><div data-r465-results></div><button data-r465-back>Back</button>`);back(b);
  b.querySelector('form').onsubmit=async e=>{e.preventDefault();const btn=b.querySelector('form button'),result=b.querySelector('[data-r465-results]');btn.disabled=true;result.textContent='Searching…';
   try{const data=await call('sowrix_r465_search',{p_query:e.target.elements.query.value});if(!b.isConnected)return;
    result.innerHTML=`<div class="sx-r465-list">${(data||[]).map(x=>`<article><strong>${esc(x.title)}</strong><p>${esc(x.kind)} · ${esc(x.state)}</p><small>${stamp(x.ts)}</small></article>`).join('')||'<p>No accessible matches.</p>'}</div>`;
   }catch(err){result.textContent=err.message;}finally{btn.disabled=false;}};
 }
 async function documents(){if(!docAllowed())return home();const b=frame('Document Register',loading());try{const [rows,orgs]=await Promise.all([call('sowrix_r465_document_list'),admin()&&docAllowed('create')?call('sowrix_r465_organization_choices'):Promise.resolve([])]);if(!b.isConnected)return;
  b.innerHTML=`<p>Metadata register only. File bytes remain in the existing private document Storage workflow. A separate Admin must approve before client sharing.</p>
   <div class="sx-r465-list">${rows.map(x=>`<article><strong>${esc(x.title)}</strong><p>${esc(x.category)} · ${esc(x.state)} · version ${Number(x.version_no)||1} · ${esc(x.audience)}</p><small>${x.expires_on?'Expires '+esc(x.expires_on):'No expiry'} · ${stamp(x.updated_at)}</small>
    ${docAllowed('edit')&&(x.is_owner||admin())?`<details><summary>New version</summary><form data-r465-version="${esc(x.id)}"><label>Change summary<textarea name="summary" required minlength="10" maxlength="1000"></textarea></label><button>Submit new draft version</button></form></details>`:''}
    ${admin()&&docAllowed('approve')&&x.state==='draft'&&!x.is_owner?`<button data-r465-approve="${esc(x.id)}">Approve for stated audience</button>`:''}</article>`).join('')||'<p>No documents visible to your account.</p>'}</div>
   ${!client()&&docAllowed('create')?`<details><summary>Create document metadata</summary><form data-r465-document><label>Title<input name="title" minlength="4" maxlength="150" required></label><label>Category<select name="category"><option value="contract">Contract</option><option value="policy">Policy</option><option value="report">Report</option><option value="other">Other</option></select></label><label>Audience<select name="audience"><option value="internal">Internal staff</option>${admin()&&orgs.length?'<option value="client_shared">Approved client organization</option>':''}</select></label>${admin()&&orgs.length?`<label>Client organization (only used for client-shared records)<select name="org"><option value="">Select a client…</option>${orgs.map(org=>`<option value="${esc(org.id)}">${esc(org.organization_name)}</option>`).join('')}</select></label>`:''}<label>Version summary<textarea name="summary" minlength="10" maxlength="1000" required></textarea></label><label>Expiry date (optional)<input type="date" name="expires"></label><button>Create review draft</button></form></details>`:''}
   <button data-r465-back>Back</button><p data-r465-status role="status" aria-live="polite"></p>`;back(b);
   // Admin chooses only organizations returned by a permission-protected RPC.
   b.querySelector('[data-r465-document]')?.addEventListener('submit',async e=>{e.preventDefault();const f=e.target,btn=f.querySelector('button');btn.disabled=true;
    try{await call('sowrix_r465_document_create',{p_title:f.elements.title.value,p_category:f.elements.category.value,p_audience:f.elements.audience.value,p_summary:f.elements.summary.value,p_org:f.elements.audience.value==='client_shared'?(f.elements.org?.value||null):null,p_expires:f.elements.expires.value||null});await documents();status('Draft created; independent review is required.');}
    catch(err){status(err.message);btn.disabled=false;}});
   b.querySelectorAll('[data-r465-version]').forEach(f=>f.onsubmit=async e=>{e.preventDefault();const btn=f.querySelector('button');btn.disabled=true;
    try{await call('sowrix_r465_document_version',{p_document:f.dataset.r465Version,p_summary:f.elements.summary.value});await documents();status('New version saved as draft.');}
    catch(err){status(err.message);btn.disabled=false;}});
   b.querySelectorAll('[data-r465-approve]').forEach(btn=>btn.onclick=async()=>{btn.disabled=true;
    try{await call('sowrix_r465_document_approve',{p_document:btn.dataset.r465Approve});await documents();status('Document metadata approved.');}
    catch(err){status(err.message);btn.disabled=false;}});
  }catch(err){status(err.message);}}
 async function requests(){if(client())return home();const b=frame('Employee Self-Service',loading());try{const rows=await call('sowrix_r465_request_list');if(!b.isConnected)return;
  b.innerHTML=`<p>Attendance correction, HR question and document requests are reviewed manually. No official attendance or payroll record is changed by this tool.</p>
  <div class="sx-r465-list">${rows.map(x=>`<article><strong>${esc(x.category.replaceAll('_',' '))}</strong><p>${esc(x.message)}</p><small>${esc(x.state)} · ${stamp(x.created_at)}</small>${x.review_note?`<p>Review note: ${esc(x.review_note)}</p>`:''}
   ${hr()&&x.state==='pending'?`<div><button data-r465-review="${esc(x.id)}" data-decision="true">Mark reviewed</button><button data-r465-review="${esc(x.id)}" data-decision="false">Decline</button></div>`:''}</article>`).join('')||'<p>No requests yet.</p>'}</div>
  <details><summary>Submit self-service request</summary><form data-r465-request><label>Request type<select name="category"><option value="attendance_review">Attendance review</option><option value="hr_question">HR question</option><option value="document_request">Document request</option></select></label><label>Details<textarea name="message" required minlength="10" maxlength="1500"></textarea></label><button>Submit for review</button></form></details><button data-r465-back>Back</button><p data-r465-status role="status" aria-live="polite"></p>`;back(b);
  b.querySelector('[data-r465-request]').onsubmit=async e=>{e.preventDefault();const f=e.target,btn=f.querySelector('button');btn.disabled=true;
   try{await call('sowrix_r465_request_submit',{p_category:f.elements.category.value,p_message:f.elements.message.value});await requests();status('Request submitted for HR review.');}
   catch(err){status(err.message);btn.disabled=false;}};
  b.querySelectorAll('[data-r465-review]').forEach(btn=>btn.onclick=async()=>{btn.disabled=true;
   try{await call('sowrix_r465_request_review',{p_id:btn.dataset.r465Review,p_accept:btn.dataset.decision==='true',p_note:''});await requests();status('Review saved. No source attendance record changed.');}
   catch(err){status(err.message);btn.disabled=false;}});
 }catch(err){status(err.message);}}
 async function clientView(){if(!client())return home();const b=frame('My Client Services',loading());try{const d=await call('sowrix_r465_client_dashboard');if(!b.isConnected)return;
  b.innerHTML=`<p>Your organization-scoped service summary. Billing amounts and private documents require their original access controls.</p>
   <div class="sx-r465-stats">${[['Active projects',d.active_projects],['Open support tickets',d.open_tickets],['Outstanding invoices',d.unpaid_invoices]].map(([label,n])=>`<div><span>${esc(label)}</span><strong>${Number(n)||0}</strong></div>`).join('')}</div><h3>Recent accessible projects</h3>
   <div class="sx-r465-list">${(d.recent_projects||[]).map(p=>`<article><strong>${esc(p.name)}</strong><p>${esc(p.status)}</p><small>${stamp(p.updated_at)}</small></article>`).join('')||'<p>No project records visible.</p>'}</div><button data-r465-back>Back</button>`;back(b);
 }catch(err){status(err.message);}}
 async function operations(){if(!admin())return home();const b=frame('System & Operations Pulse',loading());try{const d=await call('sowrix_r465_ops_summary');if(!b.isConnected)return;
  b.innerHTML=`<p>Actual database workflow counts; this is not a claim that emails, backups, payment providers or monitoring collectors are online.</p>
   <div class="sx-r465-stats">${[['Pending HR requests',d.pending_staff_requests],['Documents awaiting approval',d.pending_document_approvals],['Expiring documents (30d)',d.expiring_documents_30d],['Expired documents',d.expired_documents]].map(([label,n])=>`<div><span>${esc(label)}</span><strong>${Number(n)||0}</strong></div>`).join('')}</div>
   <p>Technical readiness can be checked on the <code>/api/defensowrix/health</code> endpoint; backup encryption, third-party delivery and recovery still require operator evidence.</p><button data-r465-back>Back</button>`;back(b);
 }catch(err){status(err.message);}}
 function open(where){if(where==='business'){if(window.SOWRIXR464?.home){close();window.SOWRIXR464.home();}else status('Business Center is unavailable. Reload the workspace.');return;}if(where==='growth'){close();window.dispatchEvent(new Event('sowrix:r467-open'));return;}if(where==='suite'){close();window.dispatchEvent(new Event('sowrix:r466-open'));return;}
  const screens={search,documents,requests,client:clientView,ops:operations};if(!screens[where])return;
  Promise.resolve().then(()=>screens[where]()).catch(e=>{home();status(e.message);});}
 const isDefensowrix=()=>/^#\/(?:client-defensowrix|workspace\/defensowrix)(?:\/|$)/.test(location.hash);
 function mount(){const id=user()?.id||'';if(id!==sessionId){close();sessionId=id;}
  // Defensowrix has a dedicated sidebar entry; never layer a floating button over it.
  if(!id||isDefensowrix()){launch?.remove();launch=null;return;}
  // Other staff portals have a navigation area; keep tools there when available.
  const nav=document.querySelector('.sx-sidebar .sx-nav');
  if(nav){if(launch?.isConnected&&launch.parentElement===nav)return;
   launch?.remove();launch=document.createElement('button');launch.className='sx-r465-nav-launch';launch.type='button';launch.textContent='Workspace tools';launch.setAttribute('aria-label','Open workspace tools');launch.setAttribute('aria-expanded','false');launch.setAttribute('aria-haspopup','dialog');launch.onclick=home;nav.appendChild(launch);return;
  }
  if(launch?.isConnected&&launch.classList.contains('sx-r465-launch'))return;
  // Layouts without a staff sidebar retain one small, accessible fallback control.
  launch?.remove();launch=document.createElement('button');launch.type='button';launch.className='sx-r465-launch';launch.textContent='Workspace tools';launch.setAttribute('aria-label','Open workspace tools');launch.setAttribute('aria-expanded','false');launch.setAttribute('aria-haspopup','dialog');launch.onclick=home;document.body.appendChild(launch);
 }
 window.addEventListener('hashchange',()=>{close();mount();});window.addEventListener('pagehide',close);
 document.addEventListener('visibilitychange',()=>{if(!document.hidden)mount();});
 document.addEventListener('DOMContentLoaded',mount,{once:true});setInterval(mount,5000);if(document.readyState!=='loading')mount();
 window.SOWRIXR465={home,open,close};
})();
