/* R46.6 Enterprise Suite — authenticated, bounded metadata workflows.
   Execution, payments, email, and network monitoring are deliberately NOT triggered here. */
(()=>{'use strict';if(window.SOWRIXR466)return;
 const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const current=()=>window.__sxUser||null,role=()=>String(current()?.role||'').toLowerCase();
 const admin=()=>['admin','super_admin'].includes(role());
 const client=()=>role()==='client';
 const hr=()=>admin()||['hr','hr_manager','hr_staff'].includes(role());
 const date=x=>x?esc(/^\d{4}-\d{2}-\d{2}$/.test(String(x))?x:new Date(x).toLocaleDateString('en-IN')):'Not set';
 const format=(name,title,kind='text',extra='')=>`<label>${esc(title)}<input name="${name}" type="${kind}" ${extra}></label>`;
 let dialog=null,focus=null,uid='';
 async function rpc(fn,args){const id=current()?.id;if(!id||!window.sowrixSupabase)throw Error('Sign in to your SOWRIX workspace.');
  const {data,error}=await window.sowrixSupabase.rpc(fn,args);
  if(id!==current()?.id)throw Error('Session changed. Reopen the tool.');
  if(error)throw Error('Action unavailable or access denied. Check the R46.6 migration and your permissions.');
  return data;
 }
 const board=section=>rpc('sowrix_r466_board',{p_section:section});
 const apply=(action,payload)=>rpc('sowrix_r466_apply',{p_action:action,p_data:payload});
 function close(){if(dialog?.isConnected)dialog.remove();dialog=null;if(focus?.isConnected)focus.focus();focus=null;}
 function view(title,html){close();uid=current()?.id||'';if(!uid)return null;focus=document.activeElement;
  dialog=document.createElement('div');dialog.className='sx-r466-backdrop';
  dialog.innerHTML=`<section class="sx-r466-modal" role="dialog" aria-modal="true" aria-labelledby="sx-r466-title"><header><div><small>SOWRIX TECHNOLOGIES · R46.6</small><h2 id="sx-r466-title">${esc(title)}</h2></div><button type="button" data-close aria-label="Close operations suite">✕</button></header><main>${html}<p class="sx-r466-status" role="status" aria-live="polite"></p></main><footer>Authenticated workspace · Every action is permission-checked by Supabase · No automatic external activity</footer></section>`;
  document.body.appendChild(dialog);dialog.querySelector('[data-close]').onclick=close;
  dialog.onclick=e=>{if(e.target===dialog)close();};
  dialog.onkeydown=e=>{if(e.key==='Escape'){close();return;}if(e.key==='Tab'){
   const items=[...dialog.querySelectorAll('button,input,select,textarea,a[href]')].filter(x=>!x.disabled&&x.getClientRects().length);
   if(items.length&&e.shiftKey&&document.activeElement===items[0]){e.preventDefault();items.at(-1).focus();}
   if(items.length&&!e.shiftKey&&document.activeElement===items.at(-1)){e.preventDefault();items[0].focus();}
  }};
  dialog.querySelector('[data-close]').focus();return dialog.querySelector('main');
 }
 function note(s){const el=dialog?.querySelector('.sx-r466-status');if(el)el.textContent=s;}
 function back(main){main?.querySelector('[data-back]')?.addEventListener('click',home);}
 const backButton='<button type="button" data-back>← Enterprise Suite</button>';
 const empty='<p>No authorized records yet.</p>';
 async function load(section,title,draw){const b=view(title,'<p role="status">Loading authorized data…</p>');
  try{const data=await board(section);if(!b?.isConnected||uid!==current()?.id)return;
   b.innerHTML=draw(data)+backButton+'<p class="sx-r466-status" role="status" aria-live="polite"></p>';back(b);
  }catch(e){note(e.message);}return b;
 }
 function submit(main,selector,action,parse,refresh){const el=main?.querySelector(selector);if(!el)return;
  el.addEventListener('submit',async e=>{e.preventDefault();const btn=el.querySelector('[type="submit"]');btn.disabled=true;
   try{const ok=await apply(action,parse(el.elements));if(ok===false)throw Error('Record no longer available. Refresh the page.');
    await refresh();note('Saved successfully. No external message or payment was sent.');
   }catch(err){note(err.message);btn.disabled=false;}});
 }
 function actionButtons(main,selector,action,parse,refresh){main?.querySelectorAll(selector).forEach(btn=>btn.addEventListener('click',async()=>{
  btn.disabled=true;try{const ok=await apply(action,parse(btn));if(ok===false)throw Error('Record may have changed.');await refresh();note('Change saved.');}
  catch(e){note(e.message);btn.disabled=false;}}));}
 async function orgOptions(){if(!admin())return [];return await rpc('sowrix_r465_organization_choices');}
 const options=items=>`<label>Client organization<select name="organization_id" required><option value="">Choose active client</option>${items.map(o=>`<option value="${esc(o.id)}">${esc(o.organization_name)}</option>`).join('')}</select></label>`;
 function home(){if(!current()?.id)return;
  const menus=(admin()||client())?[['onboarding','Customer onboarding'],['subscriptions','Service subscriptions']]:[];
  if(!client())menus.push(['assets','Asset register'],['announcements','Company announcements']);
  if(admin())menus.push(['rules','Automation builder'],['compliance','Security & compliance center']);
  const b=view('Business Operations Suite',`<p>Manage live workspace metadata with explicit actions and role checks. Rules require independent approval and remain non-executing until an operator connects a tested scheduler.</p><div class="sx-r466-grid">${menus.map(([key,name])=>`<button type="button" data-section="${key}">${esc(name)} →</button>`).join('')}</div>`);
  b?.querySelectorAll('[data-section]').forEach(x=>x.onclick=()=>open(x.dataset.section));
 }
 const steps=[['contact_confirmed','Client contact confirmed'],['scope_approved','Service scope approved'],['credentials_ready','Secure access ready'],['kick_off_complete','Kickoff completed']];
 async function onboarding(){const [orgs,rows]=await Promise.all([orgOptions(),board('onboarding')]);
  const b=view('Customer Onboarding',`<p>Only company admins can update onboarding milestones. Client accounts see their own organization progress.</p>
   <div class="sx-r466-list">${rows.map(x=>`<article><h3>${esc(x.organization_name)}</h3><p>${steps.filter(([key])=>x[key]).length}/4 completed</p><div class="sx-r466-steps">${steps.map(([key,label])=>`<label><input type="checkbox" data-step="${key}" data-id="${esc(x.id)}" ${x[key]?'checked':''} ${!admin()?'disabled':''}>${esc(label)}</label>`).join('')}</div></article>`).join('')||empty}</div>
   ${admin()?`<details><summary>Begin onboarding for a client</summary><form data-create>${options(orgs)}<button type="submit">Create onboarding record</button></form></details>`:''}
   ${backButton}<p class="sx-r466-status" role="status" aria-live="polite"></p>`);back(b);
  submit(b,'[data-create]','onboard_create',f=>({organization_id:f.organization_id.value}),onboarding);
  b?.querySelectorAll('[data-step]').forEach(el=>el.onchange=async()=>{el.disabled=true;
   try{await apply('onboard_step',{id:el.dataset.id,step:el.dataset.step,value:el.checked});await onboarding();note('Milestone updated.');}
   catch(e){el.checked=!el.checked;note(e.message);el.disabled=false;}});
 }
 async function subscriptions(){const [orgs,rows]=await Promise.all([orgOptions(),board('subscriptions')]);
  const b=view('Service Subscriptions',`<p>Subscription records are informational. Payments and contract renewals are not executed by this panel.</p><div class="sx-r466-list">${rows.map(x=>`<article><h3>${esc(x.service_name)}</h3><p>${esc(x.organization_name)} · ${esc(x.plan_label)}</p><p>Renewal: ${date(x.renewal_on)} · <strong>${esc(x.status)}</strong></p>
   ${admin()?`<label>Admin status<select data-sub="${esc(x.id)}">${['pending','active','paused','expired'].map(s=>`<option value="${s}" ${x.status===s?'selected':''}>${s}</option>`).join('')}</select></label>`:''}</article>`).join('')||empty}</div>
   ${admin()?`<details><summary>Add subscription</summary><form data-create>${options(orgs)}${format('service_name','Service name','text','required minlength="3" maxlength="140"')}${format('plan_label','Plan label','text','required minlength="2" maxlength="100"')}${format('renewal_on','Renewal date (optional)','date')}<button type="submit">Save subscription</button></form></details>`:''}
   ${backButton}<p class="sx-r466-status" role="status" aria-live="polite"></p>`);back(b);
  submit(b,'[data-create]','subscription_create',f=>({organization_id:f.organization_id.value,service_name:f.service_name.value,plan_label:f.plan_label.value,renewal_on:f.renewal_on.value}),subscriptions);
  b?.querySelectorAll('[data-sub]').forEach(el=>el.onchange=async()=>{el.disabled=true;
   try{await apply('subscription_status',{id:el.dataset.sub,status:el.value});await subscriptions();note('Subscription metadata updated; not a payment confirmation.');}
   catch(e){note(e.message);el.disabled=false;}});
 }
 async function assets(){const [staff,rows]=await Promise.all([admin()?rpc('sowrix_r466_staff_choices'):Promise.resolve([]),board('assets')]);
  const b=view('Company Asset Register',`<p>Staff see only equipment assigned to them. Admin can assign equipment to active employees.</p><div class="sx-r466-list">${rows.map(x=>`<article><h3>${esc(x.asset_tag)} · ${esc(x.asset_name)}</h3><p>${esc(x.category)} · ${esc(x.state)} · Warranty: ${date(x.warranty_end)}</p>
   ${admin()?`<label>Assigned employee<select data-asset="${esc(x.id)}"><option value="">Unassigned</option>${staff.map(s=>`<option value="${esc(s.id)}" ${x.assigned_to===s.id?'selected':''}>${esc(s.full_name)} · ${esc(s.employee_code)}</option>`).join('')}</select></label>`:''}</article>`).join('')||empty}</div>
   ${admin()?`<details><summary>Register asset</summary><form data-create><p>Asset tag is assigned automatically when saved.</p>${format('asset_name','Asset name','text','minlength="3" maxlength="150" required')}<label>Type<select name="category">${['laptop','desktop','network','software','equipment','other'].map(s=>`<option>${s}</option>`).join('')}</select></label>${format('warranty_end','Warranty expiry (optional)','date')}<button type="submit">Register asset</button></form></details>`:''}
   ${backButton}<p class="sx-r466-status" role="status" aria-live="polite"></p>`);back(b);
  submit(b,'[data-create]','asset_create',f=>({asset_name:f.asset_name.value,category:f.category.value,warranty_end:f.warranty_end.value}),assets);
  b?.querySelectorAll('[data-asset]').forEach(el=>el.onchange=async()=>{el.disabled=true;
   try{await apply('asset_assign',{id:el.dataset.asset,assigned_to:el.value});await assets();note('Assignment updated.');}
   catch(e){note(e.message);el.disabled=false;}});
 }
 async function announcements(){const rows=await board('announcements');
  const b=view('Company Announcements',`<p>Official staff notices with individual read acknowledgement. No broadcast email is sent.</p><div class="sx-r466-list">${rows.map(x=>`<article><h3>${esc(x.title)}</h3><p>${esc(x.body)}</p><small>${date(x.created_at)} · ${x.acknowledged?'Read acknowledged':'Acknowledgement pending'}</small>
   ${!x.acknowledged?`<button type="button" data-ack="${esc(x.id)}">Mark as read</button>`:''}</article>`).join('')||empty}</div>
   ${hr()?`<details><summary>Publish staff notice</summary><form data-create>${format('title','Notice title','text','required minlength="4" maxlength="140"')}<label>Message<textarea name="body" required minlength="10" maxlength="1500" rows="4"></textarea></label>${format('expires_on','Expires on (optional)','date')}<button type="submit">Publish for staff</button></form></details>`:''}
   ${backButton}<p class="sx-r466-status" role="status" aria-live="polite"></p>`);back(b);
  submit(b,'[data-create]','announcement_publish',f=>({title:f.title.value,body:f.body.value,expires_on:f.expires_on.value}),announcements);
  actionButtons(b,'[data-ack]','announcement_ack',el=>({id:el.dataset.ack}),announcements);
 }
 async function rules(){if(!admin())return home();const rows=await board('rules');
  const b=view('Safe Workflow Rule Builder',`<p><strong>Approval is not execution.</strong> Rules are reviewed metadata only; no scheduler, notifications, or financial actions are automatically triggered.</p><div class="sx-r466-list">${rows.map(x=>`<article><h3>${esc(x.name)}</h3><p>${esc(x.event_kind)} → ${esc(x.action_kind)} · <strong>${esc(x.state)}</strong></p>${x.state==='draft'&&!x.is_creator?`<button data-rule="${esc(x.id)}" data-decision="approved">Approve draft</button><button data-rule="${esc(x.id)}" data-decision="disabled">Decline</button>`:''}</article>`).join('')||empty}</div>
   <details><summary>Create safe rule draft</summary><form data-create>${format('name','Rule name','text','required minlength="4" maxlength="100"')}<label>Event<select name="event_kind">${['ticket_created','ticket_overdue','invoice_overdue','amc_renewal_due','task_overdue'].map(s=>`<option>${s}</option>`).join('')}</select></label><label>Action<select name="action_kind"><option value="notify_internal">Notify internal team (future integration)</option><option value="queue_review">Queue manual review (future integration)</option></select></label><button type="submit">Create draft rule</button></form></details>
   ${backButton}<p class="sx-r466-status" role="status" aria-live="polite"></p>`);back(b);
  submit(b,'[data-create]','rule_create',f=>({name:f.name.value,event_kind:f.event_kind.value,action_kind:f.action_kind.value}),rules);
  actionButtons(b,'[data-rule]','rule_review',x=>({id:x.dataset.rule,state:x.dataset.decision}),rules);
 }
 async function compliance(){if(!admin())return home();const d=await board('compliance');
  const stats=[['Unfinished client onboarding',d.pending_onboarding],['Subscriptions renewing within 30 days',d.renewals_30d],['Asset warranty expiring within 30 days',d.warranties_30d],['Published staff notices',d.unacknowledged_announcements]];
  const b=view('Security & Compliance Center',`<p>Manual evidence register only. A “verified” label here is NOT independent certification and does not prove live MFA, backups, or security testing.</p><div class="sx-r466-stats">${stats.map(([k,v])=>`<article><small>${esc(k)}</small><strong>${Number(v)||0}</strong></article>`).join('')}</div>
   <div class="sx-r466-list">${(d.controls||[]).map(x=>`<article><h3>${esc(x.control_name)}</h3><p>${esc(x.state)} — ${esc(x.evidence_note)}</p><small>Last edited: ${date(x.updated_at)}</small></article>`).join('')||empty}</div>
   <details><summary>Record an evidence check</summary><form data-create>${format('control_name','Control name','text','required minlength="5" maxlength="140"')}<label>Internal evidence note<textarea name="evidence_note" maxlength="500"></textarea></label><label>Status<select name="state"><option value="planned">Planned</option><option value="in_review">In review</option><option value="verified">Internally verified</option></select></label><button type="submit">Save audit entry</button></form></details>
   ${backButton}<p class="sx-r466-status" role="status" aria-live="polite"></p>`);back(b);
  submit(b,'[data-create]','compliance_record',f=>({control_name:f.control_name.value,evidence_note:f.evidence_note.value,state:f.state.value}),compliance);
 }
 function open(name){if(!current()?.id)return;const routes={onboarding,subscriptions,assets,announcements,rules,compliance};if(!routes[name])return;
  if(client()&&name!=='onboarding'&&name!=='subscriptions')return home();
  if(!admin()&&!client()&&['onboarding','subscriptions'].includes(name))return home();
  if(!admin()&&['rules','compliance'].includes(name))return home();
  Promise.resolve().then(()=>routes[name]()).catch(err=>{if(current()?.id){home();note(err.message);}});
 }
 window.addEventListener('sowrix:r466-open',()=>{window.SOWRIXR465?.close?.();home();});
 window.addEventListener('hashchange',close);window.addEventListener('pagehide',close);
 window.SOWRIXR466={home,open,close};
})();
