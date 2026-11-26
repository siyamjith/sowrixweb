/* SOWRIX R46.4 - permission-checked company tools. No credentials, sample
   customer rows, salary calculations or external calls beyond scoped RPCs. */
(()=>{'use strict';
 if(window.SOWRIXR464)return;
 const escape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const who=()=>window.__sxUser||null;
 const role=()=>String(who()?.role||'').toLowerCase();
 const admin=()=>['admin','super_admin'].includes(role());
 const signed=()=>Boolean(who()?.id);
 const inr=n=>Number.isFinite(Number(n))?new Intl.NumberFormat('en-IN',{style:'currency',currency:'INR'}).format(Number(n)):'—';
 const date=d=>{const o=new Date(d);return Number.isFinite(o.valueOf())?o.toLocaleDateString('en-IN'):'—';};
 const rpc=async(name,params={})=>{
  const user=who()?.id;
  if(!user||!window.sowrixSupabase)throw Error('Sign in to a SOWRIX workspace.');
  const {data,error}=await window.sowrixSupabase.rpc(name,params);
  if(who()?.id!==user)throw Error('Session changed. Reopen this tool.');
  if(error)throw Error('Request unavailable. Check module permissions, server connection and R46.4 migration.');
  return data;
 };
 let overlay=null,trigger=null,focusReturn=null,boundUser='',stream=null,notifyChannel=null;
 function note(msg){const target=overlay?.querySelector('[data-r464-status]');if(target)target.textContent=msg;}
 function close(){if(overlay){overlay.remove();overlay=null;}if(trigger)trigger.setAttribute('aria-expanded','false');if(focusReturn?.isConnected)focusReturn.focus();focusReturn=null;}
 function render(title,html){
  if(!signed())throw Error('Sign in to continue.');
  close();focusReturn=document.activeElement;
  overlay=document.createElement('div');overlay.className='sx-r464-shade';
  overlay.innerHTML=`<section class="sx-r464-modal" role="dialog" aria-modal="true" aria-labelledby="sx-r464-heading">
     <header><div><small>SOWRIX TECHNOLOGIES · BUSINESS</small><h2 id="sx-r464-heading">${escape(title)}</h2></div><button type="button" data-r464-close aria-label="Close tools">✕</button></header>
     <main>${html}<p data-r464-status role="status" aria-live="polite"></p></main>
     <footer>Secure workspace · Access verified by server · No automatic money transfers</footer></section>`;
  document.body.appendChild(overlay);
  overlay.querySelector('[data-r464-close]').onclick=close;
  overlay.addEventListener('keydown',e=>{
    if(e.key==='Escape'){e.preventDefault();close();return;}
    if(e.key==='Tab'){
      const items=[...overlay.querySelectorAll('button,input,select,textarea,a[href]')].filter(x=>!x.disabled&&!x.hidden&&x.getClientRects().length);
      if(!items.length)return;
      if(e.shiftKey&&document.activeElement===items[0]){e.preventDefault();items.at(-1).focus();}
      if(!e.shiftKey&&document.activeElement===items.at(-1)){e.preventDefault();items[0].focus();}
    }
  });
  overlay.querySelector('[data-r464-close]').focus();trigger?.setAttribute('aria-expanded','true');
  return overlay.querySelector('main');
 }
 function buttons(){return `<div class="sx-r464-grid">
  ${admin()?'<button type="button" data-r464-nav="control">Company Control Center</button><button type="button" data-r464-nav="proposals">Proposal drafts & approvals</button>':''}
  <button type="button" data-r464-nav="knowledge">Knowledge Base</button>
  ${role()==='client'?'<button type="button" data-r464-nav="feedback">Ticket feedback</button>':''}
  ${role()!=='client'?'<button type="button" data-r464-nav="work">My work summary</button><button type="button" data-r464-nav="leave">My leave usage</button><button type="button" data-r464-nav="payslip">My payslip preview</button>':''}
  ${admin()?'<button type="button" data-r464-nav="feedback">Feedback overview</button>':''}
  </div>`;}
 function home(){const body=render('Business Center',`<p>Choose a secure tool. The dashboard shows real authorized records only; disabled or unavailable modules are never simulated.</p>${buttons()}`);
  body.querySelectorAll('[data-r464-nav]').forEach(button=>button.onclick=()=>navigate(button.dataset.r464Nav));}
 async function control(){if(!admin())return home();const b=render('Company Control Center','<p data-r464-loading>Loading authorized business insights…</p>');
  try{const [pulse,extra]=await Promise.all([rpc('sowrix_r462_admin_pulse'),rpc('sowrix_r464_admin_overview')]);
   if(!b.isConnected)return;
   const pairs=[['Open support tickets',pulse.open_tickets],['Tickets without owner',pulse.unassigned_tickets],['Overdue tasks',pulse.overdue_tasks],['Pending approvals',pulse.pending_approvals],['AMC renewals (30d)',pulse.expiring_amcs],['Draft proposals',extra.proposal_drafts],['Published articles',extra.knowledge_articles],['Feedback received',extra.feedback_count]];
   b.innerHTML=`<p>Live role-verified totals · refreshed on request. Financial and personnel decisions require review.</p><div class="sx-r464-stats">${pairs.map(([label,value])=>`<div><span>${escape(label)}</span><strong>${Number(value)||0}</strong></div>`).join('')}</div>
      <p>Average service feedback: <strong>${extra.feedback_average==null?'Not enough feedback':escape(extra.feedback_average)+' / 5'}</strong></p>
      <div class="sx-r464-actions"><button data-r464-open-pulse>Open Business Pulse</button><button data-r464-refresh>Refresh totals</button><button data-r464-back>Back</button></div><p data-r464-status role="status" aria-live="polite"></p>`;
   b.querySelector('[data-r464-open-pulse]').onclick=()=>{close();window.SOWRIXR462?.openPulse?.().catch(()=>{});};
   b.querySelector('[data-r464-refresh]').onclick=control;b.querySelector('[data-r464-back]').onclick=home;
  }catch(e){note(e.message);}
 }
 async function knowledge(){const b=render('SOWRIX Knowledge Base','<p>Loading approved internal guidance…</p>');
  try{const articles=await rpc('sowrix_r464_knowledge_list');if(!b.isConnected)return;
   b.innerHTML=`<p>Only published articles available to your role appear here. Drafts are visible to Admin.</p>
    <div class="sx-r464-items">${articles.map(x=>`<article><h3>${escape(x.title)}</h3><small>${escape(x.published?'Published':'Draft')} · ${date(x.updated_at)}</small><p class="sx-r464-copy">${escape(x.body)}</p></article>`).join('')||'<p>No approved articles yet.</p>'}</div>
    ${admin()?`<details><summary>Add knowledge article</summary><form data-r464-kb><label>Title<input name="title" minlength="4" maxlength="120" required></label><label>Article<textarea name="body" minlength="10" maxlength="6000" rows="5" required></textarea></label><label>Audience<select name="audience"><option value="staff">Staff only</option><option value="all_signed_in">All signed-in users</option></select></label><label><input name="publish" type="checkbox"> Publish after review</label><button type="submit">Save article</button></form></details>`:''}
    <button data-r464-back>Back to tools</button><p data-r464-status role="status" aria-live="polite"></p>`;
   b.querySelector('[data-r464-back]').onclick=home;
   const form=b.querySelector('[data-r464-kb]');if(form)form.onsubmit=async e=>{e.preventDefault();const btn=form.querySelector('button');btn.disabled=true;
    try{await rpc('sowrix_r464_knowledge_save',{p_title:form.elements.title.value,p_body:form.elements.body.value,p_audience:form.elements.audience.value,p_publish:form.elements.publish.checked});await knowledge();note('Article saved.');}
    catch(err){note(err.message);btn.disabled=false;}};
  }catch(err){note(err.message);}
 }
 async function proposals(){if(!admin())return home();const b=render('Proposal drafts & independent approvals','<p>Loading proposal records…</p>');
  try{const [records,enquiries]=await Promise.all([rpc('sowrix_r464_proposal_list'),rpc('sowrix_r464_enquiry_candidates')]);if(!b.isConnected)return;
   b.innerHTML=`<p>Drafts do not contact customers. A *different* authorized Admin must approve; publishing/sending remains manual.</p>
    <div class="sx-r464-items">${records.map(p=>`<article><h3>${escape(p.title)}</h3><small>${escape(p.state)} · ${date(p.created_at)} · ${p.estimated_amount==null?'Amount not estimated':inr(p.estimated_amount)}</small><p class="sx-r464-copy">${escape(p.scope)}</p>
    ${p.state==='draft'?`<div class="sx-r464-actions"><button data-r464-proposal="${escape(p.id)}" data-approve="true">Approve</button><button data-r464-proposal="${escape(p.id)}" data-approve="false">Return</button></div>`:''}</article>`).join('')||'<p>No proposals yet.</p>'}</div>
    ${enquiries.length?`<details><summary>Generate draft from an existing enquiry</summary><p>No price is invented and no customer message is sent.</p><form data-r464-enquiry-form><label>Authorized enquiry<select name="enquiry">${enquiries.map(e=>`<option value="${escape(e.id)}">${escape(e.service)} · ${date(e.created_at)}</option>`).join('')}</select></label><button type="submit">Generate private proposal draft</button></form></details>`:''}
    <details><summary>Prepare a new proposal draft</summary><form data-r464-proposal-form><label>Proposal title<input name="title" minlength="4" maxlength="150" required></label><label>Scope and deliverables<textarea name="scope" minlength="10" maxlength="8000" rows="5" required></textarea></label><label>Estimated amount (INR; optional)<input type="number" name="amount" min="0" max="999999999999" step=".01"></label><button type="submit">Save private draft</button></form></details>
    <button data-r464-back>Back to tools</button><p data-r464-status role="status" aria-live="polite"></p>`;
   b.querySelector('[data-r464-back]').onclick=home;
   const enquiryForm=b.querySelector('[data-r464-enquiry-form]');if(enquiryForm)enquiryForm.onsubmit=async e=>{e.preventDefault();const btn=enquiryForm.querySelector('button');btn.disabled=true;
    try{await rpc('sowrix_r464_proposal_from_enquiry',{p_enquiry:enquiryForm.elements.enquiry.value});await proposals();note('Proposal draft generated from existing enquiry. Review its scope and price before sharing.');}
    catch(err){note(err.message);btn.disabled=false;}};
   const form=b.querySelector('[data-r464-proposal-form]');form.onsubmit=async e=>{e.preventDefault();const btn=form.querySelector('button');btn.disabled=true;
    try{await rpc('sowrix_r464_proposal_draft',{p_title:form.elements.title.value,p_scope:form.elements.scope.value,p_amount:form.elements.amount.value===''?null:Number(form.elements.amount.value)});await proposals();note('Draft saved. Independent review required.');}
    catch(err){note(err.message);btn.disabled=false;}};
   b.querySelectorAll('[data-r464-proposal]').forEach(btn=>btn.onclick=async()=>{const approve=btn.dataset.approve==='true';const reason=window.prompt('Short reason for independent proposal review (max 500 characters):','');if(reason===null)return;if(reason.length>500){note('Reason too long.');return;}
    btn.disabled=true;try{const ok=await rpc('sowrix_r464_proposal_decide',{p_id:btn.dataset.r464Proposal,p_approve:approve,p_note:reason});if(ok)await proposals();note(ok?'Decision saved. No email sent.':'This proposal was already reviewed.');}catch(err){note(err.message);btn.disabled=false;}});
  }catch(err){note(err.message);}
 }
 async function work(){const b=render('My work & attendance summary','<p>Loading your own work metrics…</p>');
  try{const d=await rpc('sowrix_r464_my_work_summary');if(!b.isConnected)return;
   b.innerHTML=`<p>Work visibility only. These figures are not employment rankings or automatic performance decisions.</p><div class="sx-r464-stats">${[['Assigned open tasks',d.assigned_open_tasks],['Completed tasks',d.completed_tasks],['Overdue tasks',d.overdue_tasks],['Recorded attendance days this month',d.attendance_days_this_month]].map(([label,val])=>`<div><span>${escape(label)}</span><strong>${Number(val)||0}</strong></div>`).join('')}</div><button data-r464-back>Back</button>`;
   b.querySelector('[data-r464-back]').onclick=home;
  }catch(e){note(e.message);}
 }
 async function leave(){const b=render('My approved leave usage','<p>Loading leave calendar counts…</p>');
  try{const d=await rpc('sowrix_r464_my_leave_usage');if(!b.isConnected)return;
   b.innerHTML=`<p><strong>${Number(d.approved_requests)||0}</strong> approved requests and <strong>${Number(d.approved_calendar_days)||0}</strong> calendar days since January 1.</p><p>Potential attendance/leave conflicts requiring HR review: <strong>${Number(d.possible_attendance_conflicts)||0}</strong>.<br>Annual entitlement, paid/unpaid classification, holidays and half-days are <strong>not calculated</strong>. HR must configure the official policy before showing a leave balance.</p><button data-r464-back>Back</button>`;
   b.querySelector('[data-r464-back]').onclick=home;
  }catch(e){note(e.message);}
 }
 function payslipPrint(data){
  // Deliberate user-initiated print preview; never auto-send or store payroll data.
  const html=`<!doctype html><html lang="en"><meta charset="utf-8"><title>SOWRIX payroll preview</title><style>body{font:16px system-ui;margin:30px;color:#172f5f}h1{color:#1156b3}dl{display:grid;grid-template-columns:1fr 1fr;gap:12px}dt{font-weight:bold}dd{margin:0}footer{margin-top:50px;font-size:13px}</style>
   <h1>SOWRIX TECHNOLOGIES</h1><h2>Employee payroll record preview</h2><p>Not a statutory payslip or proof of payment. Review with authorized HR.</p><dl>
   ${[['Employee',data.employee_name],['Employee code',data.employee_code],['Period',data.period],['Basic amount',inr(data.basic)],['Allowances',inr(data.allowances)],['Deductions',inr(data.deductions)],['Net',inr(data.net)],['Record status',data.status]].map(([key,val])=>`<dt>${escape(key)}</dt><dd>${escape(val||'—')}</dd>`).join('')}</dl><footer>Private employee-only export · Generated on request · Verify all deductions, tax and statutory details with HR.</footer></html>`;
  const link=document.createElement('a'),url=URL.createObjectURL(new Blob([html],{type:'text/html;charset=utf-8'}));
  link.href=url;link.download=`SOWRIX-Payroll-Preview-${data.period}.html`;document.body.appendChild(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1500);
 }
 function payslip(){const b=render('Private employee payslip preview',`<p>Only your own <strong>finalized or paid</strong> payroll record is shown. This is a printable preview, not a statutory payslip or salary transfer.</p><form data-r464-payslip><label>Payroll month<input type="month" name="period" required></label><button>Load my record</button></form><div data-r464-record></div>`);
  const field=b.querySelector('[name="period"]');field.value=new Date().toISOString().slice(0,7);
  b.querySelector('form').onsubmit=async e=>{e.preventDefault();const btn=e.target.querySelector('button');btn.disabled=true;
   const result=b.querySelector('[data-r464-record]');result.textContent='Checking the private payroll record…';
   try{const d=await rpc('sowrix_r464_my_payslip',{p_period:field.value});if(!b.isConnected)return;
    result.innerHTML=`<div class="sx-r464-stats">${[['Name',d.employee_name],['Employee ID',d.employee_code],['Basic',inr(d.basic)],['Allowances',inr(d.allowances)],['Deductions',inr(d.deductions)],['Net',inr(d.net)],['State',d.status]].map(([k,v])=>`<div><span>${escape(k)}</span><strong>${escape(v||'—')}</strong></div>`).join('')}</div><button data-r464-export>Save private printable preview</button>`;
    result.querySelector('[data-r464-export]').onclick=()=>payslipPrint(d);
    const pdf=document.createElement('button');pdf.type='button';pdf.textContent='Download private PDF preview';result.appendChild(pdf);
    pdf.onclick=async()=>{pdf.disabled=true;try{
      const res=await fetch('/api/employee/payroll-preview.pdf?period='+encodeURIComponent(field.value),{credentials:'same-origin',cache:'no-store'});
      if(!res.ok)throw Error('Private PDF unavailable. Check your session and finalized payroll record.');
      const bytes=await res.blob(),url=URL.createObjectURL(bytes),a=document.createElement('a');
      a.href=url;a.download='SOWRIX-Payroll-Preview-'+field.value+'.pdf';document.body.appendChild(a);a.click();a.remove();
      setTimeout(()=>URL.revokeObjectURL(url),3000);
    }catch(err){result.insertAdjacentText('beforeend',err.message);}finally{pdf.disabled=false;}};
   }catch(err){result.textContent=err.message;}finally{btn.disabled=false;}};
 }
 async function feedback(){const b=render('Service feedback','<p>Loading authorized ticket feedback options…</p>');
  try{
   if(admin()){
    const totals=await rpc('sowrix_r464_admin_overview');if(!b.isConnected)return;
    b.innerHTML=`<p>Total client feedback: <strong>${Number(totals.feedback_count)||0}</strong></p><p>Average (no customer identity disclosed): <strong>${totals.feedback_average==null?'No responses yet':escape(totals.feedback_average)+' / 5'}</strong></p><button data-r464-back>Back</button>`;
    b.querySelector('[data-r464-back]').onclick=home;return;
   }
   const tickets=await rpc('sowrix_r464_feedback_options');if(!b.isConnected)return;
   b.innerHTML=`<p>Feedback is optional, once per resolved ticket. Your message is visible to authorized company reviewers.</p>${tickets.length?`<form data-r464-feedback><label>Resolved ticket<select name="ticket">${tickets.map(t=>`<option value="${escape(t.id)}">${escape(t.ticket_number||'Ticket')} · ${escape(t.subject.slice(0,90))}</option>`).join('')}</select></label><label>Rating<select name="rating"><option value="5">5 — Excellent</option><option value="4">4 — Good</option><option value="3">3 — Okay</option><option value="2">2 — Needs improvement</option><option value="1">1 — Poor</option></select></label><label>Optional comment<textarea name="comment" rows="3" maxlength="500"></textarea></label><button>Submit feedback</button></form>`:'<p>No eligible resolved tickets awaiting feedback.</p>'}<button data-r464-back>Back</button><p data-r464-status role="status" aria-live="polite"></p>`;
   b.querySelector('[data-r464-back]').onclick=home;
   const form=b.querySelector('form');if(form)form.onsubmit=async e=>{e.preventDefault();const btn=form.querySelector('button');btn.disabled=true;
    try{const ok=await rpc('sowrix_r464_feedback_submit',{p_ticket:form.elements.ticket.value,p_rating:Number(form.elements.rating.value),p_comment:form.elements.comment.value});await feedback();note(ok?'Thank you. Feedback saved.':'Feedback already exists.');}
    catch(err){note(err.message);btn.disabled=false;}};
  }catch(err){note(err.message);}
 }
 function navigate(screen){const handlers={home,control,knowledge,proposals,feedback,leave,work,payslip};if(!handlers[screen])return;
  Promise.resolve().then(()=>handlers[screen]()).catch(err=>{if(signed()){home();note(err.message);}});}
 // BroadcastChannel sync between browser tabs; Supabase Realtime is optional.
 // Existing polling remains in place when websocket/channel isn't configured.
 function ping(){window.dispatchEvent(new CustomEvent('sowrix:work-updated'));window.dispatchEvent(new CustomEvent('sowrix:business-updated'));try{notifyChannel?.postMessage({event:'update'});}catch{}}
 function subscription(uid){
  if(stream){try{stream.close();}catch{}stream=null;}
  if(notifyChannel){try{notifyChannel.close();}catch{}notifyChannel=null;}
  if(!uid)return;
  try{notifyChannel=new BroadcastChannel('sowrix-business-events');notifyChannel.onmessage=e=>{if(e.data?.event==='update'){
   window.dispatchEvent(new CustomEvent('sowrix:work-updated'));window.dispatchEvent(new CustomEvent('sowrix:business-updated'));}};}catch{}
  // Same-origin authenticated SSE: count-only changes on server every ~10 s.
  // Legacy 30-second polling is retained when the backend or migration is absent.
  if(typeof EventSource!=='undefined')try{
   stream=new EventSource('/api/notifications/stream',{withCredentials:true});
   let last=null;
   stream.addEventListener('inbox',e=>{try{const data=JSON.parse(e.data);const key=JSON.stringify(data);if(last!==null&&key!==last)ping();last=key;}catch{}});
   stream.onerror=()=>{ /* EventSource reconnects with browser backoff; polling is fallback. */ };
  }catch{stream=null;}
 }
 function mount(){const u=who()?.id||'';
  if(boundUser!==u){close();boundUser=u;subscription(u);}
  // Business Center stays accessible through the unified Workspace tools menu.
  // Retire the separate fixed launcher so it cannot obscure sidebar content.
  if(trigger){trigger.remove();trigger=null;}
 }
 window.addEventListener('hashchange',()=>{close();mount();});
 window.addEventListener('pagehide',()=>{close();subscription('');});
 document.addEventListener('visibilitychange',()=>{if(!document.hidden)mount();});
 document.addEventListener('DOMContentLoaded',mount,{once:true});
 setInterval(mount,5000);if(document.readyState!=='loading')mount();
 window.SOWRIXR464={home,navigate,close};
})();
