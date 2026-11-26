/* Public status feed: unverified or offline != operational. Text-only safe rendering. */
(()=>{'use strict';const root=document.getElementById('status-feed');const summary=document.getElementById('status-summary');if(!root||!summary)return;
 function entry(service,category,message,when){const li=document.createElement('li');li.className='status-entry';const h=document.createElement('strong');h.textContent=`${service} · ${category}`;li.append(h);const p=document.createElement('p');p.textContent=message;li.append(p);const small=document.createElement('small');const d=new Date(when);small.textContent=Number.isFinite(d.getTime())?d.toLocaleString('en-IN'):'Time unavailable';li.append(small);return li;}
  summary.setAttribute('role','status');root.setAttribute('aria-busy','true');
  fetch('/api/public/status',{method:'GET',credentials:'omit',cache:'no-store',signal:AbortSignal.timeout(8000),headers:{Accept:'application/json'}})
  .then(async res=>{if(!res.ok)throw Error('No connected status feed');const data=await res.json();if(!Array.isArray(data))throw Error('Invalid status feed');if(data.length===0){summary.textContent='No current verified notices published. Live service availability has not been independently confirmed here.';return;}
  summary.textContent='Manually reviewed notices. This page does not certify live uptime.';
  data.slice(0,20).forEach(x=>root.append(entry(String(x.service||'Service'),String(x.category||'Notice'),String(x.message||''),x.created_at)));
  }).catch(()=>{summary.textContent='Live notices are not currently available. This is NOT confirmation that services are operating normally. Please contact SOWRIX for support.'})
  .finally(()=>root.setAttribute('aria-busy','false'));
})();
