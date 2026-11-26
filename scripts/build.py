"""Reproducibly extend the supplied website; no remote requests or deployment."""
import base64, gzip, hashlib, json, re, runpy
from pathlib import Path
from public_experience_build import integrate as integrate_public_experience
from public_knowledge_review import validate as validate_public_knowledge
ROOT=Path(__file__).resolve().parents[1]
public_knowledge=validate_public_knowledge(json.loads((ROOT/'src/sowrix-public-knowledge.json').read_text(encoding='utf-8')))
public_reference_path=ROOT/'reference-build'/'index.html'
if not public_reference_path.is_file():raise RuntimeError('Approved standalone reference build is required')
RELEASE=runpy.run_path(str(ROOT/'backend/version.py'))['RELEASE']
routes=runpy.run_path(str(ROOT/'backend/public_routes.py'))
source=(ROOT/"original"/"index(5).html").read_text(encoding="utf-8")
# Public company contact only; original archives and account records are untouched.
source=source.replace('sowrixtechnologies@gmail.com','contact@sowrix.in')
login_back='<a href="#/">← Back to website</a>'
if source.count(login_back)!=1:raise RuntimeError('Login return link insertion point mismatch')
source=source.replace(login_back,'<a href="/">← Back to website</a>',1)
workspace_exit='<a href="#/">Public website ↗</a>'
if source.count(workspace_exit)!=1:raise RuntimeError('Expected retained workspace exit link')
source=source.replace(workspace_exit,'<a href="/">Public website ↗</a>',1)
public_documents={}
post_source=source.split('const POSTS=[',1)[1].split('const BLOG_CATS=',1)[0]
for slug,title,desc,body in re.findall(
        r"\{slug:'([a-z0-9-]+)',cat:'[^']+',title:'([^']+)',\s*desc:'([^']+)',[\s\S]*?body:`([^`]+)`",post_source):
    public_documents['/blog/'+slug]={'title':title,'excerpt':desc,'html':body}
legal_source=source.split('function pageLegal(kind){',1)[1].split('const l=L[kind]',1)[0]
for key,title,desc,body in re.findall(r"(\w+):\{t:'([^']+)',d:'([^']+)',\s*h:`([^`]+)`",legal_source):
    public_documents['/'+key]={'title':title.replace('&amp;','&'),'excerpt':desc,'html':body}
if set(public_documents)!={'/privacy','/terms','/cookies','/disclaimer','/blog/small-office-network-setup-guide',
                           '/blog/3-2-1-backup-rule-explained','/blog/website-vs-web-app-vs-mobile-app'}:
    raise RuntimeError('Reviewed public article or legal source inventory changed')
for document in public_documents.values():
    body=document['html']
    if re.search(r'<(?:script|style|iframe|img|object|svg|form|link)\b|\s(?:on\w+|style)\s*=|javascript:',body,re.I):
        raise RuntimeError('Unexpected markup in retained public documents')
    document['html']=re.sub(r'href="#/([a-z-]+)"',r'href="/\1"',body)
# R39: compile safe CSV-import controls into the retained browser-only legacy views.
# Original customer-supplied HTML stays unchanged; source overrides live in src/inline-3.js.
legacy=(ROOT/'src/inline-3.js').read_text(encoding='utf-8')
# Keep the original template immutable while compiling the maintained article renderer.
def article_renderer(text):
    start=text.index('async function pagePost(slug)')
    end=re.search(r'\n(?:async )?function \w+\(',text[start+1:])
    if not end:raise RuntimeError('Expected a boundary after the retained article renderer')
    return text[start:start+1+end.start()]
original_article=article_renderer(source)
source=source.replace(original_article,article_renderer(legacy),1)
# The authentication page is rendered from the retained original HTML. Keep
# its trusted handlers, but replace only the presentation function with the
# reviewed source override so generated assets cannot drift from source.
login_start='function pageLogin(){'
login_end='function initSowrixLogin(){'
if source.count(login_start)!=1 or source.count(login_end)!=1:
    raise RuntimeError('Expected one login renderer and initializer in retained source')
override_start=legacy.index(login_start)
override_end=legacy.index(login_end,override_start)
login_override=legacy[override_start:override_end]
source_start=source.index(login_start)
source_end=source.index(login_end,source_start)
source=source[:source_start]+login_override+source[source_end:]
early_toggle_anchor=" if(form.dataset.bound==='1') return;"
early_toggle_patch=""" const earlyPasswordToggle=document.getElementById('sowrixPasswordToggle');
 const earlyPasswordField=document.getElementById('sowrixLoginPassword');
 if (earlyPasswordToggle && earlyPasswordField && earlyPasswordToggle.dataset.bound!=='1') {
  earlyPasswordToggle.dataset.bound='1';
  earlyPasswordToggle.addEventListener('click',()=>{
   const visible=earlyPasswordField.type==='text';
   earlyPasswordField.type=visible?'password':'text';
   earlyPasswordToggle.textContent=visible?'Show':'Hide';
   earlyPasswordToggle.setAttribute('aria-pressed',String(!visible));
  });
 }
 if(form.dataset.bound==='1') return;"""
if source.count(early_toggle_anchor)!=1:
    raise RuntimeError('Expected one login duplicate-binding guard in retained initializer')
source=source.replace(early_toggle_anchor,early_toggle_patch,1)
toggle_anchor=" form.dataset.bound='1';"
toggle_patch=""" form.dataset.bound='1';
 const passwordToggle=document.getElementById('sowrixPasswordToggle');
 const passwordField=document.getElementById('sowrixLoginPassword');
 if (passwordToggle && passwordField && passwordToggle.dataset.bound!=='1') {
  passwordToggle.dataset.bound='1';
  passwordToggle.addEventListener('click',()=>{
   const visible=passwordField.type==='text';
   passwordField.type=visible?'password':'text';
   passwordToggle.textContent=visible?'Show':'Hide';
   passwordToggle.setAttribute('aria-pressed',String(!visible));
  });
 }"""
if source.count(toggle_anchor)!=1:
    raise RuntimeError('Expected one login binding anchor in retained initializer')
source=source.replace(toggle_anchor,toggle_patch,1)
active_login_anchor="initSowrixLogin=function(){\n const form=document.getElementById('sowrixLoginForm');"
active_login_patch="""initSowrixLogin=function(){
 const toggle=document.getElementById('sowrixPasswordToggle');
 const password=document.getElementById('sowrixLoginPassword');
 if (toggle && password && toggle.dataset.visibilityBound!=='1') {
  toggle.dataset.visibilityBound='1';
  toggle.addEventListener('click',()=>{
   const visible=password.type==='text';
   password.type=visible?'password':'text';
   toggle.textContent=visible?'Show':'Hide';
   toggle.setAttribute('aria-pressed',String(!visible));
  });
 }
 const form=document.getElementById('sowrixLoginForm');"""
if source.count(active_login_anchor)!=1:
    raise RuntimeError('Expected one active login initializer override')
source=source.replace(active_login_anchor,active_login_patch,1)
def r39_patch(old,new,count=1):
    global source
    if source.count(old)!=count:raise RuntimeError(f'R39 legacy override mismatch {source.count(old)} / {count}: {old[:60]}')
    source=source.replace(old,new)
r39_patch('<button class="btn btn-ghost btn-sm" id="workspaceExport" type="button">Export CSV</button>', '<button class="btn btn-ghost btn-sm" id="workspaceExport" type="button">Export CSV</button><button class="btn btn-ghost btn-sm" id="workspaceImport" type="button">Import CSV</button>')
# Use reviewed handler code from corresponding source overlay.
start=" document.getElementById('workspaceImport')?.addEventListener('click',()=>{"
end=" document.getElementById('workspaceExport').addEventListener('click',()=>{"
section=legacy[legacy.index(start):legacy.index(end,legacy.index(start))]
r39_patch(end,section+end)
r39_patch('<button class="btn btn-primary" id="reportExportAll">Export summary CSV</button>', '<button class="btn btn-primary" id="reportExportAll">Export summary CSV</button><button class="btn btn-ghost" id="reportImportSummary" type="button" title="Calculated summary: import source records instead">Import CSV</button>',2)
r39_patch('${label} CSV</button>', '${label} CSV</button><button class="btn btn-ghost btn-sm" type="button" data-report-import="${key}" data-report-label="${label}">Import CSV</button>',2)
start=" document.getElementById('reportImportSummary')?.addEventListener('click',()=>{"
end=" root.closest('.admin-layout')?.querySelectorAll('[data-report-export]')"
section=legacy[legacy.index(start):legacy.index(end,legacy.index(start))]
r39_patch(end,section+end,2)
# Phase 7A: the retained legacy admin dashboard copy predates the reviewed
# source override and still ships fabricated metrics ("+12 this week",
# "Last login: just now", hardcoded audit rows). Replace the whole pageAdmin
# presentation section with the reviewed source override — same pattern as the
# R39 login renderer harvest. The Early Access nav injection below anchors into
# the spliced content, so this runs first. The replaced section is unreachable
# dead code (route aliasing canonicalizes /admin before rendering), but the
# shipped artifact must not carry fabricated business content.
pa_start='function pageAdmin(){'
pa_end='function pageHR(){'
if source.count(pa_start)!=1 or source.count(pa_end)!=1:
    raise RuntimeError('Expected one legacy admin dashboard renderer and next section in retained source')
pa_source_start=source.index(pa_start)
pa_source_end=source.index(pa_end,pa_source_start)
pa_legacy_start=legacy.index(pa_start)
pa_legacy_end=legacy.index(pa_end,pa_legacy_start)
source=source[:pa_source_start]+legacy[pa_legacy_start:pa_legacy_end]+source[pa_source_end:]
# Phase 7A: the dead HR dashboard identity chip must not ship a fabricated
# last-login claim either; keep only the role label.
r39_patch('Human Resources · Last login: just now','Human Resources')
# Phase 7A: remove the dangling initAdminBlog trigger. The function was never
# defined; route aliasing canonicalizes /admin/blog before this line can run,
# so removing it is behavior-preserving and eliminates a landmine.
blog_trigger="if(raw.startsWith('/admin/blog'))initAdminBlog();"
if source.count(blog_trigger)!=1:raise RuntimeError('Expected one dangling blog initializer trigger')
source=source.replace(blog_trigger,'',1)

# Capture the approved asset before replacing the landing markup that embeds it.
# A clean build must not depend on a brochure left by a previous build.
original_brochure=re.search(r'data:application/vnd\.openxmlformats-officedocument\.presentationml\.presentation;base64,([A-Za-z0-9+/=]+)',source)
if not original_brochure:raise RuntimeError('Approved brochure missing from the supplied original')
# Premium is a frontend edition of the same R16 backend, not a schema release.
DESIGN_EDITION='R35-FULL-WIDTH-INSIGHTS'
source=source.replace('<head>','<head>\n<script id="sowrix-design-boot">(()=>{const h=document.documentElement;h.classList.add("sx-design","r20","r21","r23");h.dataset.sxTheme="light";try{if(localStorage.getItem("sowrix-theme")==="dark"){h.classList.add("sx-user-dark");h.dataset.sxTheme="dark";}}catch{}})();</script>',1)
# Reviewed source overrides keep the supplied original intact. No blind global
# substitution of duplicate legacy declarations; replace each script once.
for name in ("sowrix-full-platform-runtime-v2", "sowrix-suite", "sowrix-v4-auth", "sowrix-v5-motion", "sowrix-site-integration", "sowrix-v4-access", "sowrix-public-data", "sowrix-public-ui", "sowrix-consultations"):
    source,n=re.subn(r'<script id="'+re.escape(name)+r'">[\s\S]*?</script>',
        lambda _,name=name:'<script id="'+name+'">\n'+((ROOT/'src/sowrix-index6-images.js').read_text(encoding='utf-8') if name=='sowrix-site-integration' else '')+(ROOT/('src/'+name+'.js')).read_text(encoding='utf-8')+'\n</script>',source)
    if n!=1:raise RuntimeError('Expected source integration point: '+name)
landing_marker='const sowrixLandingMarkup='
start=source.index(landing_marker)+len(landing_marker)
_,landing_length=json.JSONDecoder().raw_decode(source[start:])
source=source[:start]+json.dumps((ROOT/'src/sowrix-r21-home.html').read_text(encoding='utf-8'),ensure_ascii=False)+source[start+landing_length:]
# Replace the old ambient-motion CSS rather than stacking a second particle system.
source,n=re.subn(r'<style id="sowrix-motion-styles">[\s\S]*?</style>',
    '<style id="sowrix-motion-styles">/* Replaced by the bounded Premium design layer. */</style>',source)
if n!=1:raise RuntimeError('Expected one legacy motion stylesheet')
# Keep fonts optional and non-blocking; system fallbacks remain fully usable.
source=re.sub(r'https://fonts.googleapis.com/css2\?[^"\s>]*',lambda m:'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Manrope:wght@400;500;600;700;800&display=swap',source,count=1)
source=re.sub(r'<link[^>]+(?:fonts.googleapis.com|fonts.gstatic.com)[^>]*>', '', source)
sdk_path=ROOT/"node_modules/@supabase/supabase-js/dist/umd/supabase.js"
if not sdk_path.is_file():sdk_path=ROOT/"src/vendor-supabase-pinned.js"
sdk=sdk_path.read_text(encoding="utf-8")
def script(name,text):
    return '<script id="'+name+'">\n'+text.replace("</script","<\\/script")+'\n</script>'
route_bootstrap="""(()=>{'use strict';const path=location.pathname;if(path==='/'||path==='/index.html')return;
 const known=new RegExp(PATTERN),aliases=ALIASES;if(!known.test(path))return;
 // Preserve recovery/invitation token fragments for the existing exchange handler.
 if(location.hash&&!location.hash.startsWith('#/'))return;
 const route=path.replace(/\\/$/,'');history.replaceState(null,'','/app'+location.search+(location.hash||'#'+(aliases[route]||route)));
})();""".replace('PATTERN',json.dumps(routes['PUBLIC_PATH_PATTERN'])).replace('ALIASES',json.dumps(routes['ROUTE_ALIASES'],separators=(',',':')))
source=source.replace('<head>','<head>\n'+script('sowrix-r15-routing',route_bootstrap),1)
pattern=r'<script\s+async\s+src="https://cdn\.jsdelivr\.net/npm/@supabase/supabase-js@2"[^>]*></script>'
sdk_public=ROOT/'site/assets/vendor-supabase.v2.js'
sdk_public.parent.mkdir(parents=True,exist_ok=True)
sdk_public.write_bytes(sdk.encode('utf-8'))
# Begin fetching the pinned runtime early while HTML is still streaming.
source=source.replace('<head>','<head>\n<link rel="preload" href="/assets/vendor-supabase.v2.js" as="script">',1)
replacement='<script id="sowrix-sdk-pinned" src="/assets/vendor-supabase.v2.js"></script>\n'+script("sowrix-server-session",(ROOT/"src/defensowrix-session.js").read_text(encoding='utf-8'))
source,count=re.subn(pattern,lambda _:replacement,source)
if count!=1:raise RuntimeError("Expected one Supabase SDK loader; inspect source before building")
old="await checked(s().auth.signInWithPassword({email:user.email,password:d.current}));"
new="await checked(s().auth.reauthenticate({password:d.current}));"
if source.count(old)!=1:raise RuntimeError("Expected account-security password handler")
source=source.replace(old,new)
source=source.replace("Built for businesses across India","Built for businesses, everywhere")
source=source.replace('Twelve service lines, one accountable team.','Connected service lines, one accountable team.')
source=source.replace('Twelve service lines under one accountable team', 'Connected technology services under one accountable team')
source=source.replace('<span class="tag">Technology. Innovation. Solutions.</span>','<span class="tag">AI. Automation. Technology.</span>')
# The supplied X icon pointed to Contact rather than an actual social account.
# Hide this unconfigured destination; preserve the other supplied links.
source,count=re.subn(r'<a href="#/contact" aria-label="SOWRIX on X">[\s\S]*?</a>', '',source)
if count!=1:raise RuntimeError('Review the unconfigured social-link integration point')
source=source.replace('minlength="8" autocomplete="new-password" required placeholder="At least 8 characters"','minlength="12" autocomplete="new-password" required placeholder="At least 12 characters"')
def replace_once(old,new):
    global source
    if source.count(old)!=1:raise RuntimeError("Expected one client onboarding integration point: "+old[:70])
    source=source.replace(old,new)
replace_once("raw.slice(raw.index('?')+1)","raw.slice(raw.indexOf('?')+1)")
replace_once("location.pathname+location.search+'#'+alias);raw=alias;",
             "location.pathname+location.search+'#'+alias+(location.hash.includes('?')?location.hash.slice(location.hash.indexOf('?')):''));raw=alias;")
replace_once("document.body.classList.toggle('workspace-active',raw.startsWith('/workspace')||raw.startsWith('/client-'));",
             "const adminSurface=/^\\/admin(?:\\/|$)/.test(raw);"
             "document.body.classList.toggle('workspace-active',adminSurface||raw.startsWith('/workspace')||raw.startsWith('/client-'));")
replace_once(" if(raw.startsWith('/admin') && (!user",
             " if(version!==sowrixRenderVersion)return;\n if(raw.startsWith('/admin') && (!user")
replace_once("if(!matched)matched=page404(raw);",
             """if(!matched)matched=adminSurface?{title:'Page not found | SOWRIX',noindex:true,
 html:'<section class="sx-panel"><div class="sx-panel-body"><h1>Workspace page not found</h1><p>Open a page from the sidebar or return to the dashboard.</p><a class="sx-btn" href="#/workspace">Dashboard</a></div></section>'}:page404(raw);""")
replace_once(" document.getElementById('main').innerHTML=matched.html;",
             """ if(adminSurface&&user){
  window.__sxUser={...user,role:sowrixNormalizeRole(user.role),user:{id:user.id,email:user.email}};
  matched=sowrixAdminWorkspacePage(matched,raw.replace(/\\/$/,''),window.__sxUser);
 }
 document.getElementById('main').innerHTML=matched.html;
 if(adminSurface&&user)sowrixBindAdminWorkspace(document.querySelector('#main > .sx-app'));""")
# These historical route entries are always canonicalized or superseded by
# the workspace runtime. Keep the supplied original untouched for recovery.
router_start=source.index("const ROUTES=[")
router_end=source.index("\n];",router_start)
superseded={
    'pageUpgradeModule(', 'pageEmployeePortal()', 'pageAdminPortfolio()',
    'pageAdmin()', 'pageAdminBlog()', 'pageHR()', 'pageHRSalary()',
    'pageHRApplications()', 'pageHRCandidates()', 'pageWorkspaceReports()',
    'pageWorkspace(m[1])', "pageAdminCollection('audit')",
    "pageAdminCollection('careers')", "pageAdminCollection('applications')",
    "pageAdminCollection('services')", "pageAdminCollection('leads')",
}
route_rows=source[router_start:router_end].splitlines(keepends=True)
source=source[:router_start]+''.join(row for row in route_rows if not any(name in row for name in superseded))+source[router_end:]
source=source.replace("matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth'","(window.SOWRIXDesign?.motionOff()??matchMedia('(prefers-reduced-motion:reduce)').matches)?'auto':'smooth'")
source=source.replace('window.scrollTo(0,0);',"if(window.SOWRIXExperience?.restoreScroll)window.SOWRIXExperience.restoreScroll();else window.scrollTo(0,0);")
replace_once("esc(error.message||'Please try again.')","esc('Please refresh this page or return home. Your saved records have not been changed.')")
# R46.11.1: log the real exception locally, without leaking private details to visitors.
# Public UI enhancement failures should not replace a successfully rendered page.
replace_once("}catch(error){if(version!==sowrixRenderVersion)return;document.getElementById('main').innerHTML=",
             "}catch(error){console.error('SOWRIX route render failure', location.hash, error);if(version!==sowrixRenderVersion)return;document.getElementById('main').innerHTML=")
replace_once("initSowrixLanding();window.sowrixInitPremium?.(raw);",
             "try{initSowrixLanding();}catch(uiError){console.warn('SOWRIX service enhancement skipped',uiError);}"+
             "try{window.sowrixInitPremium?.(raw);}catch(uiError){console.warn('SOWRIX premium enhancement skipped',uiError);}")

replace_once('if (typeof render === "function") {\n  render();',
    'if (typeof render === "function") {\n  if (!/^#\\/(?:client-defensowrix|workspace\\/defensowrix)(?:\\/|$)/.test(location.hash)) render();')
replace_once("const visibleFields=cfg.fields.filter(f=>", "const visibleFields=cfg.fields.filter(f=>!(cfg.key==='clients'&&f[0]==='auth_user_id')&&!(cfg.key==='amc'&&record&&f[0]==='client_id')&&")
replace_once("r.auth_user_id?'Send sign-in link':'Set up client login'", "r.auth_user_id?'Resend invitation':'Invite Client'")
replace_once("then use Set up client login.", "then use Invite Client. Configure RESEND_API_KEY and CLIENT_FROM_EMAIL on the Python server, and install 12-client-invitations.sql for this upgrade.")
replace_once("const files=['SOWRIX-SECURITY-BACKEND-COMPLETE.sql',", "const files=['12-client-invitations.sql','SOWRIX-SECURITY-BACKEND-COMPLETE.sql',")
source,count=re.subn(r'<script id="sowrix-release-repair">[\s\S]*?</script>',lambda _:script("sowrix-release-repair",(ROOT/"src/defensowrix-client-invitations.js").read_text(encoding='utf-8')),source)
if count!=1:raise RuntimeError("Expected one invitation handler")
upgrade=(ROOT/"database/12-client-invitations.sql").read_text(encoding='utf-8')
hardening=(ROOT/"database/13-defensowrix-hardening.sql").read_text(encoding='utf-8')
work=(ROOT/'database/16-work-and-notifications.sql').read_text(encoding='utf-8')
source=source.replace('</body>','<script type="text/plain" id="sowrix-r16-preflight-sql">'+(ROOT/'database/16-preflight-read-only.sql').read_text(encoding='utf-8')+'</script>\n</body>',1)
amc=(ROOT/"database/15-amc-management.sql").read_text(encoding='utf-8')
source=source.replace('</body>','<script type="text/plain" id="sowrix-download-12-client-invitations.sql">'+upgrade+'</script>\n</body>',1)
source=source.replace('</body>','<script type="text/plain" id="sowrix-download-13-defensowrix-hardening.sql">'+hardening+'</script>\n</body>',1)
source=source.replace("const files=['12-client-invitations.sql',", "const files=['13-defensowrix-hardening.sql','12-client-invitations.sql',",1)
complete=(ROOT/"original/SOWRIX-SECURITY-BACKEND-COMPLETE.sql").read_text(encoding='utf-8')+"\n"+(ROOT/"database/11-defensowrix.sql").read_text(encoding='utf-8')+"\n"+upgrade+"\n"+hardening+"\n"+amc+"\n"+work
source,count=re.subn(r'(<script type="text/plain" id="sowrix-download-SOWRIX-SECURITY-BACKEND-COMPLETE\.sql">)[\s\S]*?(</script>)',
    lambda m:m[1]+complete+m[2],source)
if count!=1:raise RuntimeError("Complete backend download must be updated exactly once")
(ROOT/"database/SOWRIX-DEFENSOWRIX-BACKEND-COMPLETE.sql").write_bytes(complete.encode('utf-8'))
source=source.replace('</body>','<script type="text/plain" id="sowrix-download-15-amc-management.sql">'+amc+'</script>\n</body>',1)
source=source.replace("const files=['13-defensowrix-hardening.sql',","const files=['15-amc-management.sql','13-defensowrix-hardening.sql',",1)
source=source.replace("</head>",'<style id="sowrix-defensowrix-style">\n'+(ROOT/"src/defensowrix.css").read_text(encoding='utf-8')+"\n</style>\n</head>",1)
portal_script=(ROOT/"src/defensowrix-portal.js").read_text(encoding='utf-8')
portal_script=portal_script.replace('href="#/">Public website','href="/">Public website').replace('class="df-brand" href="#/"','class="df-brand" href="/"')
source=source.replace("</body>",script("sowrix-defensowrix-capabilities",(ROOT/"src/defensowrix-capabilities.js").read_text(encoding='utf-8'))+"\n"+script("sowrix-defensowrix-portal",portal_script)+"\n</body>",1)
source=source.replace("</head>",'<style id="sowrix-r14-style">'+(ROOT/"src/sowrix-r14.css").read_text(encoding='utf-8')+'</style>\n</head>',1)
source=source.replace('</head>','<style id="sowrix-r15-style">'+(ROOT/'src/sowrix-r15.css').read_text(encoding='utf-8')+'</style>\n</head>',1)
source=source.replace("</body>",script("sowrix-r14",(ROOT/"src/sowrix-r14.js").read_text(encoding='utf-8'))+'\n</body>',1)
source=source.replace('</head>','<style id="sowrix-work-style">'+(ROOT/'src/sowrix-work.css').read_text(encoding='utf-8')+'</style>\n</head>',1)
source=source.replace('</body>',script('sowrix-work',(ROOT/'src/sowrix-work.js').read_text(encoding='utf-8'))+'\n</body>',1)
source=source.replace('</body>','<style id="sowrix-design-style">'+(ROOT/'src/sowrix-design.css').read_text(encoding='utf-8')+'</style>\n'+script('sowrix-design',(ROOT/'src/sowrix-design.js').read_text(encoding='utf-8'))+'\n</body>',1)
source=source.replace('</body>','<style id="sowrix-experience-style">'+(ROOT/'src/sowrix-experience.css').read_text(encoding='utf-8')+'</style>\n'+script('sowrix-experience',(ROOT/'src/sowrix-experience.js').read_text(encoding='utf-8'))+'\n</body>',1)
# R19's data-driven activity widget is retained; its old visual stylesheet is not shipped.
source=source.replace('</body>',script('sowrix-r19',(ROOT/'src/sowrix-r19.js').read_text(encoding='utf-8'))+'\n</body>',1)
# Define new public templates before the existing first render. Preserve the router itself.
render_index=source.index('if (typeof render === "function") {')
script_start=source.rfind('<script',0,render_index)
source=source[:script_start]+script('sowrix-r46-24-catalog',(ROOT/'src/sowrix-r46-24-catalog.js').read_text(encoding='utf-8'))+'\n'+script('sowrix-r20-public',(ROOT/'src/sowrix-r20-public.js').read_text(encoding='utf-8'))+'\n'+script('sowrix-r24-service-pages',(ROOT/'src/sowrix-r24-services.js').read_text(encoding='utf-8'))+'\n'+source[script_start:]
source=source.replace('</body>','<style id="sowrix-r20-style">'+(ROOT/'src/sowrix-r20.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r21.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-index6-home.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r23.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r24.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r25.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r26.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r28.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r29.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r30.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r31.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r32.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r33.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r34.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r35.css').read_text(encoding='utf-8')+'</style>\n'+script('sowrix-r21',(ROOT/'src/sowrix-r21.js').read_text(encoding='utf-8'))+'\n'+script('sowrix-r20',(ROOT/'src/sowrix-r20.js').read_text(encoding='utf-8'))+'\n'+script('sowrix-index6-motion',(ROOT/'src/sowrix-index6-motion.js').read_text(encoding='utf-8'))+'\n'+script('sowrix-r23',(ROOT/'src/sowrix-r23.js').read_text(encoding='utf-8'))+'\n'+script('sowrix-r28',(ROOT/'src/sowrix-r28.js').read_text(encoding='utf-8'))+'\n'+script('sowrix-r29',(ROOT/'src/sowrix-r29.js').read_text(encoding='utf-8'))+'\n'+script('sowrix-r32',(ROOT/'src/sowrix-r32.js').read_text(encoding='utf-8'))+'\n</body>',1)

# R46.1: Put existing self-hosted font CSS in a separately cacheable resource.
# The six approved font payloads remain unchanged and no third-party fonts are fetched.
font_css=(ROOT/'src/sowrix-r20-fonts.css').read_bytes()
font_digest=hashlib.sha256(font_css).hexdigest()
font_name=f'sowrix-fontfaces-{font_digest[:16]}.css'
font_public=ROOT/'site'/'assets'/font_name
font_public.parent.mkdir(parents=True,exist_ok=True)
font_public.write_bytes(font_css)
if source.count('<style id="sowrix-r20-style">')!=1:raise RuntimeError('Expected one R20 presentation style')
source=source.replace('<style id="sowrix-r20-style">',
    '<link rel="stylesheet" id="sowrix-r46-1-fonts" href="/assets/'+font_name+'">\n<style id="sowrix-r20-style">',1)
# R37 keeps the navigation CSS lightweight; styling is applied to all protected routes.
source=source.replace('</head>','<style id="sowrix-r37-style">'+(ROOT/'src/sowrix-r37.css').read_text(encoding='utf-8')+'</style>\n</head>',1)
# R39: shared CSV import with preview, permissions and controlled writes.
source=source.replace('</head>','<style id="sowrix-r39-style">'+(ROOT/'src/sowrix-r39.css').read_text(encoding='utf-8')+'</style>\n</head>',1)
source=source.replace('</body>',script('sowrix-r39-csv-import',(ROOT/'src/sowrix-csv-import.js').read_text(encoding='utf-8'))+'\n</body>',1)


# Load presentation styles before any route markup. Keeping them after the large
# inline application scripts caused a visible unstyled frame during navigation.
for style_id in ('sowrix-design-style','sowrix-experience-style','sowrix-r20-style'):
    match=re.search(r'<style id="'+style_id+r'">[\s\S]*?</style>',source)
    if not match:raise RuntimeError('Missing presentation stylesheet: '+style_id)
    tag=match[0]
    source=source[:match.start()]+source[match.end():]
    source=source.replace('</head>',tag+'\n</head>',1)

# R43: PWA: one install prompt when supported; protect private pages from offline caching.
source=source.replace('</head>', '<link rel="manifest" href="/manifest.webmanifest">\n<meta name="theme-color" content="#071b42">\n<style id="sowrix-r43-pwa-style">'+(ROOT/'src/sowrix-r43-pwa.css').read_text(encoding='utf-8')+'</style>\n</head>', 1)
source=source.replace('</body>', script('sowrix-r43-pwa',(ROOT/'src/sowrix-r43-pwa.js').read_text(encoding='utf-8'))+'\n</body>',1)

# R45: authenticated ID badges and payroll view styling; no fake users or pay records.
source=source.replace('</head>', '<style id="sowrix-r45-style">'+(ROOT/'src/sowrix-r45.css').read_text(encoding='utf-8')+'</style>\n'+script('sowrix-r45-identity',(ROOT/'src/sowrix-r45-identity.js').read_text(encoding='utf-8'))+'\n</head>',1)

# R46: preserve contact behavior but retire the deprecated marketing label.
source=source.replace('>Request a Quote ${ic(\'arrow\',16)}</a>', '>Contact SOWRIX ${ic(\'arrow\',16)}</a>')
# R46: preserve all backend/portal code; add early retired-route handling and responsive layer.
source=source.replace('</head>',script('sowrix-r46-route-cleanup',(ROOT/'src/sowrix-r46-route-cleanup.js').read_text(encoding='utf-8'))+'\n<style id="sowrix-r46-style">'+(ROOT/'src/sowrix-r46.css').read_text(encoding='utf-8')+'</style>\n</head>',1)

# R46.1: keyboard skip link and scoped readability/focus polish. Never touch portal data.
if source.count('<body>')!=1 or source.count('id="main"')!=1:
    raise RuntimeError('Missing unique R46.1 accessible content entry')
source=source.replace('<body>','<body>\n<a class="sx-r46-1-skip" href="#main">Skip to main content</a>',1)
source=source.replace('</head>', '<style id="sowrix-r46-1-style">'+(ROOT/'src/sowrix-r46-1.css').read_text(encoding='utf-8')+'</style>\n</head>',1)

# R46.2: privileged dashboards use existing gateway/session + database RLS.
# No new authority is granted by frontend visibility; no fake finance or HR actions.
source=source.replace('</head>', '<style id="sowrix-r46-2-style">'+(ROOT/'src/sowrix-r46-2.css').read_text(encoding='utf-8')+'</style>\n</head>',1)
source=source.replace('</body>',script('sowrix-r46-2',(ROOT/'src/sowrix-r46-2.js').read_text(encoding='utf-8'))+'\n</body>',1)

# R46.3: externalized, content-addressed assistant assets. Site remains
# privacy-first; browser files never include provider keys or customer data.
assistant_assets=[]
# Remove obsolete generated assistant hashes from previous local builds. This
# affects compiled public assets only, never user uploads, references or source.
for stale in (ROOT/'site'/'assets').glob('sowrix-assist-*'):
    if stale.is_file() and stale.suffix in ('.js','.css'):
        stale.unlink()
for ext in ('css','js'):
    data=(ROOT/'src'/('sowrix-r46-3-assist.'+ext)).read_bytes()
    if ext=='js':
        kb=public_knowledge
        data=data.replace(b'__SOWRIX_PUBLIC_KNOWLEDGE__',json.dumps(kb,ensure_ascii=False,separators=(',',':')).encode('utf-8'))
    asset='sowrix-assist-'+hashlib.sha256(data).hexdigest()[:16]+'.'+ext
    location=ROOT/'site'/'assets'/asset
    location.parent.mkdir(parents=True,exist_ok=True)
    location.write_bytes(data)
    assistant_assets.append('assets/'+asset)
source=source.replace('</head>', '<link rel="stylesheet" href="/'+assistant_assets[0]+'">\n</head>',1)
source=source.replace('</body>', '<script defer src="/'+assistant_assets[1]+'"></script>\n</body>',1)

# R46.4: the enterprise workspace has its own small fingerprinted payload.
# Keep all confidential records behind authenticated RPCs; these files contain
# no keys, private records or user-specific HTML.
enterprise_assets=[]
for stale in (ROOT/'site'/'assets').glob('sowrix-enterprise-*'):
    if stale.is_file() and stale.suffix in ('.js','.css'): stale.unlink()
for ext in ('css','js'):
    data=(ROOT/'src'/('sowrix-r46-4-enterprise.'+ext)).read_bytes()
    asset='sowrix-enterprise-'+hashlib.sha256(data).hexdigest()[:16]+'.'+ext
    path=ROOT/'site'/'assets'/asset
    path.write_bytes(data)
    enterprise_assets.append('assets/'+asset)
# R47: fingerprint the isolated Early Access Admin module as an enterprise
# runtime asset so the existing allowlisted enterprise asset route serves it.
ea_data=(ROOT/'src'/'sowrix-early-access-admin.js').read_bytes()
ea_asset='sowrix-enterprise-'+hashlib.sha256(ea_data).hexdigest()[:16]+'.js'
(ROOT/'site'/'assets'/ea_asset).write_bytes(ea_data)
enterprise_assets.append('assets/'+ea_asset)
source=source.replace('</head>', '<link rel="stylesheet" href="/'+enterprise_assets[0]+'">\n</head>',1)
source=source.replace('</head>', '<script src="/'+enterprise_assets[2]+'"></script>\n</head>',1)
source=source.replace('</body>', '<script defer src="/'+enterprise_assets[1]+'"></script>\n</body>',1)

# Protected Admin integration points are unique and checked. The Admin route
# itself still runs through the application's existing auth/role guard.
ea_nav='''            <a href="#/admin/enquiries">
              ${ic('phone')}
              Contact Enquiries
            </a>'''
if source.count(ea_nav)!=1:raise RuntimeError('Early Access Admin navigation insertion point mismatch')
source=source.replace(ea_nav,ea_nav+'''\n            <a href="#/admin/early-access">${ic('shield')} DEFENSOWRIX Early Access</a>''',1)
ea_route=" [/^\\/admin\\/enquiries\\/?$/,()=>pageAdminCollection('enquiries'),'/admin/enquiries/'],"
if source.count(ea_route)!=1:raise RuntimeError('Early Access Admin route insertion point mismatch')
source=source.replace(ea_route,ea_route+"\n [/^\\/admin\\/early-access\\/?$/,()=>pageAdminEarlyAccess(),'/admin/early-access/'],",1)
ea_init=" if(raw.startsWith('/admin/enquiries'))initAdminCollection('enquiries');"
if source.count(ea_init)!=1:raise RuntimeError('Early Access Admin initializer insertion point mismatch')
source=source.replace(ea_init,ea_init+"if(raw.startsWith('/admin/early-access'))initAdminEarlyAccess();",1)
cms_route=next(line.strip() for line in legacy.splitlines() if "'/admin/editorial/'" in line and 'sowrix-cms-admin' in line)
source=source.replace(ea_route,ea_route+'\n '+cms_route,1)
source=source.replace(ea_init,ea_init+"\n if(raw==='/admin/editorial'||raw==='/admin/editorial/')window.SOWRIXEditorialAdmin?.();",1)
source=source.replace(ea_nav,ea_nav+'\n            <a href="#/admin/editorial">Public CMS</a>',1)
dw_route=next(line.strip() for line in legacy.splitlines() if "'/admin/defensowrix-requests/'" in line and 'pageAdminDwInterest' in line)
if 'function initAdminDwInterest(){' not in source:
    raise RuntimeError('DEFENSOWRIX requests renderer missing from built Admin code')
source=source.replace(ea_route,ea_route+'\n '+dw_route,1)
source=source.replace(ea_init,ea_init+"\n if(raw==='/admin/defensowrix-requests'||raw==='/admin/defensowrix-requests/')initAdminDwInterest();",1)
source=source.replace(ea_nav,ea_nav+'\n            <a href="#/admin/defensowrix-requests">DEFENSOWRIX Requests</a>',1)

# R46.5: content-addressed enterprise tools, loaded separately from main HTML.
ops_assets=[]
for stale in (ROOT/'site'/'assets').glob('sowrix-ops-*'):
    if stale.is_file() and stale.suffix in ('.js','.css'): stale.unlink()
for ext in ('css','js'):
    data=(ROOT/'src'/('sowrix-r46-5-ops.'+ext)).read_bytes()
    name='sowrix-ops-'+hashlib.sha256(data).hexdigest()[:16]+'.'+ext
    (ROOT/'site'/'assets'/name).write_bytes(data)
    ops_assets.append('assets/'+name)
source=source.replace('</head>', '<link rel="stylesheet" href="/'+ops_assets[0]+'">\n</head>',1)
source=source.replace('</body>', '<script defer src="/'+ops_assets[1]+'"></script>\n</body>',1)

# R46.6: six new permission-protected modules use fingerprinted cached assets.
# No personal records, credentials, or mutable runtime content are bundled.
suite_assets=[]
for stale in (ROOT/'site'/'assets').glob('sowrix-suite46-*'):
    if stale.is_file() and stale.suffix in ('.js','.css'):stale.unlink()
for ext in ('css','js'):
    data=(ROOT/'src'/('sowrix-r46-6-suite.'+ext)).read_bytes()
    name='sowrix-suite46-'+hashlib.sha256(data).hexdigest()[:16]+'.'+ext
    (ROOT/'site'/'assets'/name).write_bytes(data)
    suite_assets.append('assets/'+name)
source=source.replace('</head>','<link rel="stylesheet" href="/'+suite_assets[0]+'">\n</head>',1)
source=source.replace('</body>','<script defer src="/'+suite_assets[1]+'"></script>\n</body>',1)

# R46.7: content-addressed, authenticated growth suite. Never embed customer data.
growth_assets=[]
for stale in (ROOT/'site'/'assets').glob('sowrix-growth-*'):
    if stale.is_file() and stale.suffix in ('.js','.css'):stale.unlink()
for ext in ('css','js'):
    data=(ROOT/'src'/('sowrix-r46-7-growth.'+ext)).read_bytes()
    name='sowrix-growth-'+hashlib.sha256(data).hexdigest()[:16]+'.'+ext
    (ROOT/'site'/'assets'/name).write_bytes(data)
    growth_assets.append('assets/'+name)
source=source.replace('</head>','<link rel="stylesheet" href="/'+growth_assets[0]+'">\n</head>',1)
source=source.replace('</body>','<script defer src="/'+growth_assets[1]+'"></script>\n</body>',1)

# R45: replace the original inline employee invitation form with the no-manual-ID workflow.
# This is separate from src/inline-12.js because the original HTML is built as a source stream.
for old,new in (
 ('<p>Send an account invitation to a team member.</p>','<p>Send an invitation. The server assigns a permanent SW/EM/0001-format ID after migration 45.</p>'),
 ("[['email','Email','email'],['full_name','Full name','text'],['employee_code','Employee code','text'],['department','Department','text'],['designation','Designation','text']]", "[['email','Email','email'],['full_name','Full name','text'],['department','Department','text'],['designation','Designation','text']]"),
 ("status.textContent='Invitation sent. Employee ID and profile are synced to Employee Directory now; the employee can set a password from the email link.';", "status.textContent='Invitation sent. Assigned ID: '+(data?.employee_code||'verify in directory')+'. Employee can set a password from the email link.';"),
):
    if source.count(old)!=1:raise RuntimeError('R45 invite update needs an exact original source match: '+old[:70])
    source=source.replace(old,new)

# R26 logo reliability: direct asset paths prevent an empty logo when inline JavaScript is blocked.
# The existing embedded branding constant remains untouched to preserve script hashes.
for old, new, expected in (
    ('<img data-sowrix-logo="src" alt="SOWRIX logo">', '<img src="/assets/sowrix-original.png" alt="SOWRIX Technologies original logo" loading="eager" decoding="async">', 2),
    ('<link rel="icon" data-sowrix-logo="href">', '<link rel="icon" type="image/png" href="/assets/sowrix-original.png">', 1),
    ('<link rel="apple-touch-icon" data-sowrix-logo="href">', '<link rel="apple-touch-icon" href="/assets/sowrix-original.png">', 1),
):
    actual=source.count(old)
    if actual != expected: raise RuntimeError(f'Unexpected logo markup count ({actual}/{expected}): {old}')
    source=source.replace(old,new)

# The backend is required for protected data. No provider token persistence or alternative fake login.
output=ROOT/"site";output.mkdir(exist_ok=True)
# R43: reproducibly publish PWA assets from reviewed src/pwa, not prior site output.
for name, destination in (
    ('manifest.webmanifest','manifest.webmanifest'),
    ('offline.html','offline.html'),
    ('sw.js','sw.js'),
    ('sowrix-pwa-192.png','assets/sowrix-pwa-192.png'),
    ('sowrix-pwa-512.png','assets/sowrix-pwa-512.png'),
):
    target=output/destination
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes((ROOT/'src'/'pwa'/name).read_bytes())

# Remove obsolete duplicate preview assets left by earlier local builds.
for stale in (ROOT/'site/assets').glob('sx-ref-service-visual-*.webp'):
    stale.unlink(missing_ok=True)

# R46.12: build the ten photographic service visuals from independent, optimized assets.
# Never embed a reference page screenshot as the actual UI.
for item in sorted((ROOT/'src/service-reference-assets').glob('service-visual-*.webp')):
    target=output/'assets'/('sx-ref-'+item.name.replace('service-visual-','service-'))
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(item.read_bytes())
# Validate the explicit source-of-truth service identity manifest before publishing.
service_manifest=json.loads((ROOT/'src/service-reference-assets/manifest.json').read_text(encoding='utf-8'))
expected_services=['IT Infrastructure','Software Development','Mobile Applications','Cybersecurity','CCTV & Security','Hardware & Support','Digital Marketing','AI & Automation','E-Waste Solutions','Data Recovery']
if len(service_manifest['services'])!=10 or [x['name'] for x in service_manifest['services']]!=expected_services:
    raise RuntimeError('Service artwork sequence differs from approved ten service references')
for item in service_manifest['services']:
    index=item['id']
    if not (len(index)==2 and index.isdigit()):raise RuntimeError('Invalid service artwork id')
    for ext in ('webp','jpg'):
        p=ROOT/'src/service-reference-assets'/('service-visual-'+index+'.'+ext)
        if hashlib.sha256(p.read_bytes()).hexdigest()!=item[ext+'_sha256']:
            raise RuntimeError('Service artwork identity mismatch: '+item['name']+' ('+ext+')')
# R46.13: sync the same canonical 10 service photographs into detailed service pages.
# No old or mismatched image assets are allowed to survive a fresh build.
for item in sorted((ROOT/'src/service-reference-assets').glob('service-visual-*.jpg')):
    target=output/'assets'/('index6-'+item.name.replace('service-visual-','service-'))
    target.write_bytes(item.read_bytes())

# R46.14 — page-specific editorial illustrations: copied from reviewed source.
# No caption-keyword guessing, no third-party hotlinks, no customer-specific claims.
for illustration in sorted((ROOT/'src/editorial-visuals').glob('sx-*.webp')):
    (output/'assets'/illustration.name).write_bytes(illustration.read_bytes())

# The existing public brochure is a download, not part of first-page rendering.
# Preserve its bytes and serve it only when requested.
downloads=output/'downloads';downloads.mkdir(exist_ok=True)
(downloads/'SOWRIX-Corporate-Brochure.pptx').write_bytes(base64.b64decode(original_brochure[1],validate=True))
source=source.replace(original_brochure[0],'/downloads/SOWRIX-Corporate-Brochure.pptx')
# R32: Heavy *public* SQL downloads do not belong in the page's critical payload.
# Keep their exact bytes in same-origin files; fetch only on explicit download.
reference_downloads=downloads/'reference';reference_downloads.mkdir(exist_ok=True)
external_plain={
 'sowrix-download-SOWRIX-SECURITY-BACKEND-COMPLETE.sql':'sowrix-complete.sql',
 'sowrix-access-sql':'sowrix-access.sql',
 'sowrix-suite-sql':'sowrix-suite.sql',
 'sowrix-download-10-security-foundation.sql':'sowrix-foundation.sql',
}
for element_id,filename in external_plain.items():
    pattern=r'(<script\b[^>]*\btype="text/plain"[^>]*\bid="'+re.escape(element_id)+r'"[^>]*>)([\s\S]*?)(</script>)'
    matches=list(re.finditer(pattern,source))
    if len(matches)!=1: raise RuntimeError('Missing unique public download: '+element_id)
    body=matches[0].group(2)
    (reference_downloads/filename).write_bytes(body.encode('utf-8'))
    marker=matches[0].group(1).replace('>',f' data-source-url="/downloads/reference/{filename}">',1)
    source=source[:matches[0].start()]+marker+matches[0].group(3)+source[matches[0].end():]
# R40: read-only People Operations views for authorized Admin/HR roles.
# Match exactly the existing routes; don't change their access policy or data.
needle_page='function pageWorkspace(kind){'
needle_init='function initWorkspace(kind){'
if source.count(needle_page)!=1 or source.count(needle_init)!=1:
    raise RuntimeError('R40 requires one workspace route and one initializer')
source=source.replace(needle_page,needle_page+"\n if ((kind==='attendance'||kind==='payroll') && window.SOWRIXOps) return window.SOWRIXOps.page(kind);",1)
source=source.replace(needle_init,needle_init+"\n if ((kind==='attendance'||kind==='payroll') && window.SOWRIXOps) return window.SOWRIXOps.init(kind);",1)
source=source.replace('</head>', '<style id="sowrix-r40-people-style">\n'+(ROOT/'src/sowrix-r40-people.css').read_text(encoding='utf-8')+'\n'+(ROOT/'src/sowrix-r42-attendance.css').read_text(encoding='utf-8')+'\n</style>\n'+script('sowrix-r41-payroll',(ROOT/'src/sowrix-r41-payroll.js').read_text(encoding='utf-8'))+script('sowrix-r40-people',(ROOT/'src/sowrix-r40-people.js').read_text(encoding='utf-8'))+script('sowrix-r45-payroll-review',(ROOT/'src/sowrix-r45-payroll-review.js').read_text(encoding='utf-8'))+script('sowrix-r42-attendance',(ROOT/'src/sowrix-r42-attendance.js').read_text(encoding='utf-8'))+'\n</head>', 1)
source=source.replace('</head>','<style id="sowrix-admin-workspace-style">\n'+(ROOT/'src/sowrix-admin-workspace.css').read_text(encoding='utf-8')+'\n</style>\n</head>',1)
source=source.replace('</head>',script('sowrix-payroll-policy-preview',(ROOT/'src/sowrix-payroll-policy-preview.js').read_text(encoding='utf-8'))+'\n</head>',1)
# R46.2: externalize approved, expensive presentation styles (preserving each
# position in the cascade), so pages can reuse them from the browser cache.
# Keep R20 CSS inline because historical render/visual tests inspect its content.
cache_css=[]
for style_id in ('sowrix-design-style','sowrix-experience-style',
                 'sowrix-r40-people-style','sowrix-defensowrix-style'):
    pattern=r'<style id="'+style_id+r'">([\s\S]*?)</style>'
    match=re.search(pattern,source)
    if not match:raise RuntimeError('R46.2 could not find expected style: '+style_id)
    css=match[1].encode('utf-8')
    digest=hashlib.sha256(css).hexdigest()
    filename='assets/sowrix-public-'+digest[:16]+'.css'
    (output/filename).write_bytes(css)
    cache_css.append(filename)
    source=source[:match.start()]+'<link rel="stylesheet" id="'+style_id+'" href="/'+filename+'">'+source[match.end():]

# R46.2 SEO: obsolete prototype domain must never leak into published links.
# Official domain is intentionally not guessed. Browser sets the actual HTTPS origin.
old_origin='https://sowrix-technologies.siyamjith8754.chatgpt.site'
source=re.sub(r'<link rel="canonical" href="'+re.escape(old_origin)+r'/">','',source)
source=re.sub(r'<meta property="og:url" content="'+re.escape(old_origin)+r'/">','',source)
source=source.replace(old_origin+'/assets/sowrix-logo.png','/assets/sowrix-original.png')
# Search registry is already a JSON literal embedded by R35. Convert old URLs to
# a safe sentinel and hydrate them at runtime to the actual origin.
registry=re.search(r'(<script id="sowrix-search-registry">window\.SOWRIX_SEARCH=)([\s\S]*?)(</script>)',source)
if not registry:raise RuntimeError('R46.2 missing legacy SEO registry')
raw=registry[2].strip().removesuffix(';')
json.loads(raw) # ensure that the original registry remains valid JSON
serialized=json.dumps(raw.replace(old_origin,'__SOWRIX_SITE_ORIGIN__'))
source=source[:registry.start()]+registry[1]+'JSON.parse('+serialized+'.replaceAll("__SOWRIX_SITE_ORIGIN__",location.origin));'+registry[3]+source[registry.end():]
source=re.sub(r'(<script type="application/ld\+json" id="route-schema">)[\s\S]*?(</script>)',
    r'\1{"@context":"https://schema.org","@graph":[]}\2',source,count=1)
source=source.replace("const SITE='"+old_origin+"';",'const SITE=location.origin;')
source=source.replace("sameAs:'"+old_origin+"/'", "sameAs:location.origin+'/'")
# Canonical route URL is a clean crawlable path, not a fragment URL.
legacy="const configured=window.SOWRIX_BACKEND_CONFIG?.publicSiteUrl;const base=configured||location.origin+location.pathname;const url=base.replace(/#.*$/,'')+'#'+route;"
modern="const configured=window.SOWRIX_BACKEND_CONFIG?.publicSiteUrl;const base=typeof configured==='string'&&/^https:\\/\\//.test(configured)?new URL(configured).origin:location.origin;const url=base+(route==='/'?'/':route.replace(/\\/$/,'')+'/');"
# Prefer a plain source replacement, and fail rather than silently serving stale SEO.
if source.count(legacy)!=1:raise RuntimeError('R46.2 expected one SEO head updater')
source=source.replace(legacy,modern,1)
# R46.26: the legacy SEO updater blanked both social images on every public route.
# Use the original same-origin logo unless a configured absolute HTTPS image exists.
seo_old="window.SOWRIX_BACKEND_CONFIG?.socialImageUrl||''"
seo_new="((window.SOWRIX_BACKEND_CONFIG?.socialImageUrl||'').startsWith('https://')?window.SOWRIX_BACKEND_CONFIG.socialImageUrl:location.origin+'/assets/sowrix-original.png')"
if source.count(seo_old)!=2:raise RuntimeError('Unexpected social-image SEO updater; review before replacing')
source=source.replace(seo_old,seo_new)
if old_origin in source:raise RuntimeError('Legacy template canonical host survived R46.2 cleanup')
# R46.7: standalone public trust, case-study and status pages.
# No unverified claims, no inline scripts, no guessed production domain.
page_src=ROOT/'src'/'r467-public'
for public_name,source_name in (
 ('status.html','status.html'),('trust.html','trust.html'),('case-studies.html','case-studies.html'),
 ('r467-public.css','common.css'),('r467-status.js','status.js')):
    (output/public_name).write_bytes((page_src/source_name).read_bytes())
# robots intentionally blocks private application routes and permits approved public ones.
robots="""User-agent: *
Disallow: /admin
Disallow: /hr
Disallow: /employee
Disallow: /portal
Disallow: /client
Disallow: /workspace
Disallow: /api
Disallow: /downloads/reference
"""
import os
public_site_url=os.environ.get('SOWRIX_PUBLIC_SITE_URL','').strip().rstrip('/')
if public_site_url:
    from urllib.parse import urlsplit
    parts=urlsplit(public_site_url)
    if parts.scheme!='https' or not parts.netloc or parts.username or parts.password or parts.query or parts.fragment or parts.path:
        raise RuntimeError('SOWRIX_PUBLIC_SITE_URL must be a clean HTTPS origin (e.g. https://your-domain.example)')
    from xml.sax.saxutils import escape as xml_escape
    paths=['/','/about','/services','/industries','/solutions','/portfolio','/blog','/careers','/contact','/privacy','/terms','/cookies','/disclaimer','/trust.html','/case-studies.html','/status.html']
    # Public catalog only: never expose client/employee/HR/admin paths to a crawler.
    # A site owner must set the final HTTPS origin; never guess their domain.
    service_slugs=('it-infrastructure','network-solutions','website-development','web-application-development',
        'mobile-app-development','cybersecurity','cctv-security','hardware-it-support',
        'digital-marketing','ai-automation','e-waste-management','data-recovery',
        'cloud-hosting','business-process-automation','ai-solutions','data-analytics','digital-transformation')
    industry_slugs=('corporate-offices','manufacturing','healthcare','education','hotels-hospitality',
        'retail','banking-financial-services','government-public-sector','transportation-logistics',
        'residential-communities','startups','smb')
    source_catalog=(ROOT/'src/sowrix-r24-services.js').read_text(encoding='utf-8')
    for slug in service_slugs:
        if "'"+slug+"':" not in source_catalog:raise RuntimeError('Sitemap service route missing: '+slug)
    source_industries=(ROOT/'src/sowrix-r20-public.js').read_text(encoding='utf-8')+(ROOT/'src/sowrix-r46-24-catalog.js').read_text(encoding='utf-8')
    for slug in industry_slugs:
        if slug not in source_industries:raise RuntimeError('Sitemap industry route missing: '+slug)
    paths+=['/services/'+slug for slug in service_slugs]
    paths+=['/industries/'+slug for slug in industry_slugs]
    sitemap='<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'+''.join('<url><loc>'+xml_escape(public_site_url+path)+'</loc></url>\n' for path in paths)+'</urlset>\n'
    (output/'sitemap.xml').write_bytes(sitemap.encode('utf-8'))
    robots+='Sitemap: '+public_site_url+'/sitemap.xml\n'
else:
    # Don't publish stale or wrong-domain sitemap links.
    (output/'sitemap.xml').unlink(missing_ok=True)
(output/'robots.txt').write_bytes(robots.encode('utf-8'))
# R46.12: independently authored service explorer, not screenshot-as-interface.
# Insert after other styles so its accessible responsive three-column layout wins cascade.
service_css=(ROOT/'src/sowrix-r46-12-services.css').read_text(encoding='utf-8')
source=source.replace('</body>','<style id="sowrix-r4612-services">\n'+service_css+'\n</style>\n</body>',1)
# Apply the maintained navigation enhancement before extracting shared SPA chrome.
reference_template=public_reference_path.read_text(encoding='utf-8')
reference_template=re.sub(r'href="#/(privacy|terms|cookies|disclaimer)"',r'href="/\1"',reference_template)
services_chevron='>Services <span aria-hidden="true">⌄</span></button>'
if reference_template.count(services_chevron)!=1:
    raise RuntimeError('Expected one Services chevron in the approved reference')
reference_template=reference_template.replace(services_chevron,
    '>Services <span aria-hidden="true"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" focusable="false"><path d="m6 9 6 6 6-6"/></svg></span></button>',1)
reference_template=reference_template.replace('</head>','<style id="sowrix-service-chevron">#pillar-menu-toggle{display:inline-flex;align-items:center;gap:.45rem}#pillar-menu-toggle>span{display:inline-flex;flex:none}#pillar-menu-toggle svg{display:block}</style>\n</head>',1)
menu_click='toggle.addEventListener("click",function(){menu.hidden=!menu.hidden;toggle.setAttribute("aria-expanded",String(!menu.hidden))});'
if reference_template.count(menu_click)!=1:
    raise RuntimeError('Expected one Services menu handler')
reference_template=reference_template.replace(menu_click,'''var menuHover=false, menuTimer;
    var openMenu=function(){menu.hidden=false;toggle.setAttribute("aria-expanded","true")};
    toggle.addEventListener("click",function(){if(menu.hidden||menuHover){openMenu();menuHover=false}else closeMenu()});
    toggle.parentElement.addEventListener("pointerenter",function(e){
      if(e.pointerType!=="mouse"||!desktop.matches)return;
      clearTimeout(menuTimer);menuTimer=setTimeout(function(){if(menu.hidden){openMenu();menuHover=true}},140);
    });
    toggle.parentElement.addEventListener("pointerleave",function(){
      clearTimeout(menuTimer);if(menuHover&&!menu.contains(root.activeElement)){closeMenu();menuHover=false}
    });''',1)
source=integrate_public_experience(source,reference_template,ROOT,script)
premium_css=(ROOT/'src/sowrix-portal-premium.css').read_text(encoding='utf-8')
source=source.replace('</body>','<style id="sowrix-portal-premium">'+premium_css+'</style>\n</body>',1)
editorial_script=script('sowrix-editorial',(ROOT/'src/sowrix-editorial.js').read_text(encoding='utf-8'))
source=source.replace('</body>','<style id="sowrix-editorial-style">'+(ROOT/'src/sowrix-editorial.css').read_text(encoding='utf-8')+'</style>'+editorial_script+'\n</body>',1)
(output/"index.html").write_bytes(source.encode('utf-8'))
(output/"index.html.gz").write_bytes(gzip.compress(source.encode(),compresslevel=9,mtime=0))
# Keep the authenticated SPA artifact intact; aiohttp serves this separate public root.
if not public_reference_path.is_file():raise RuntimeError('Approved public reference HTML is missing')
reference_html=reference_template
reference_bridge=(ROOT/'src/sowrix-public-route-bridge.js').read_text(encoding='utf-8')
reference_html=reference_html.replace('<head>','<head>\n'+script('sowrix-public-route-bridge',reference_bridge),1)
if '{{' in reference_html or 'https://x.com/sowrixtech' not in reference_html or 'https://www.youtube.com/@Sowrix' not in reference_html:
    raise RuntimeError('Approved reference artifact is incomplete')
# Keep the existing one-assistant implementation and knowledge base on the
# approved root without copying its source into the reference package.
assistant_link='<link rel="stylesheet" href="/'+assistant_assets[0]+'">'
assistant_script='<script defer src="/'+assistant_assets[1]+'"></script>'
if 'data-sx-assist-launch' in reference_html:raise RuntimeError('Reference already contains a SOWRIX assistant mount')
if '</head>' not in reference_html or '</body>' not in reference_html:raise RuntimeError('Reference HTML insertion points are missing')
reference_html=reference_html.replace('</head>',assistant_link+
    '\n<link rel="manifest" href="/manifest.webmanifest">\n<link rel="apple-touch-icon" href="/assets/sowrix-pwa-192.png">\n'
    '<style id="sowrix-r43-pwa-style">'+(ROOT/'src/sowrix-r43-pwa.css').read_text(encoding='utf-8')+'</style>\n</head>',1)
reference_html=reference_html.replace('</body>',editorial_script+'\n'+assistant_script+'\n'+
    script('sowrix-r43-pwa',(ROOT/'src/sowrix-r43-pwa.js').read_text(encoding='utf-8'))+'\n</body>',1)
(output/'public-reference.html').write_bytes(reference_html.encode('utf-8'))
(output/'public-reference.html.gz').write_bytes(gzip.compress(reference_html.encode('utf-8'),compresslevel=9,mtime=0))
reference_hashes=[]
for match in re.finditer(r'<script\b([^>]*)>([\s\S]*?)</script\s*>',reference_html,re.I):
    if re.search(r'\bsrc=',match[1],re.I) or re.search(r'type=["\'](?:text/plain|application/ld\+json|application/json)["\']',match[1],re.I):continue
    reference_hashes.append("'sha256-"+base64.b64encode(hashlib.sha256(match[2].encode()).digest()).decode()+"'")
reference_style_hashes=[]
for match in re.finditer(r'<style\b[^>]*>([\s\S]*?)</style\s*>',reference_html,re.I):
    reference_style_hashes.append("'sha256-"+base64.b64encode(hashlib.sha256(match[1].encode()).digest()).decode()+"'")
reference_csp='; '.join([
    "default-src 'self'", "script-src 'self' "+' '.join(reference_hashes),
    "style-src 'self' "+' '.join(reference_style_hashes),
    "font-src 'self' data:", "img-src 'self' data: blob: https:",
    "connect-src 'self'", "object-src 'none'", "base-uri 'self'",
    "frame-ancestors 'none'", "form-action 'self'"])
(output/'public-reference.csp.txt').write_text(reference_csp,encoding='utf-8')
hashes=[]
for match in re.finditer(r'<script\b([^>]*)>([\s\S]*?)</script\s*>',source,re.I):
    if re.search(r'type=["\'](?:text/plain|application/ld\+json)["\']',match[1]):continue
    hashes.append("'sha256-"+base64.b64encode(hashlib.sha256(match[2].encode()).digest()).decode()+"'")
csp="; ".join([
    "default-src 'self'", "script-src 'self' "+" ".join(hashes),
    # Existing marketing widgets still use inline event attributes; retain these explicitly.
    "script-src-attr 'unsafe-inline'", "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "font-src 'self' data: https://fonts.gstatic.com", "img-src 'self' data: blob: https:",
    "connect-src 'self'", "media-src 'self' blob:", "object-src 'none'", "base-uri 'self'",
    "frame-ancestors 'none'", "form-action 'self'", "frame-src https://www.google.com https://maps.google.com"])
(output/"csp.txt").write_bytes(csp.encode('utf-8'))
# Firebase serves the HTML itself; its headers must match the API-hosted copy.
hosting_file=ROOT/"deployment/firebase.example.json"
hosting=json.loads(hosting_file.read_text(encoding='utf-8'))
for rewrite in hosting['hosting']['rewrites']:
    if rewrite.get('source')=='/api/**' and 'run' in rewrite:rewrite['run']['pinTag']=True
public_headers=next(item for item in hosting["hosting"]["headers"] if item["source"]=="**")["headers"]
public_headers[:]=[item for item in public_headers if item["key"] not in ("Content-Security-Policy","Cache-Control","Permissions-Policy")]
public_headers.extend([
    {"key":"Content-Security-Policy","value":csp},
    {"key":"Cache-Control","value":"no-cache"},
    {"key":"Permissions-Policy","value":"camera=(), microphone=(), geolocation=()"}])
# Put the API-specific cache rule after the general HTML rule. The gateway also
# emits no-store; real CDN delivery remains a staging acceptance check.
hosting['hosting']['headers']=[item for item in hosting['hosting']['headers'] if item['source'] not in ('/sw.js','/manifest.webmanifest')]
hosting['hosting']['headers'].append({'source':'/sw.js','headers':[
  {'key':'Content-Type','value':'text/javascript; charset=utf-8'},
  {'key':'Cache-Control','value':'no-cache'},
  {'key':'Service-Worker-Allowed','value':'/'}]})
hosting['hosting']['headers'].append({'source':'/manifest.webmanifest','headers':[
  {'key':'Content-Type','value':'application/manifest+json; charset=utf-8'},
  {'key':'Cache-Control','value':'no-cache'}]})
hosting['hosting']['headers']=[item for item in hosting['hosting']['headers'] if not item['source'].startswith('/assets/sowrix-fontfaces-')]
hosting['hosting']['headers'].append({'source':'/assets/sowrix-fontfaces-*.css','headers':[
  {'key':'Content-Type','value':'text/css; charset=utf-8'},
  {'key':'Cache-Control','value':'public, max-age=31536000, immutable'},
  {'key':'X-Content-Type-Options','value':'nosniff'}]})
hosting['hosting']['headers']=[item for item in hosting['hosting']['headers'] if item['source']!='/assets/sowrix-public-*.css']
hosting['hosting']['headers'].append({'source':'/assets/sowrix-public-*.css','headers':[
 {'key':'Content-Type','value':'text/css; charset=utf-8'},
 {'key':'Cache-Control','value':'public, max-age=31536000, immutable'},
 {'key':'X-Content-Type-Options','value':'nosniff'}]})
for suffix,content_type in (('css','text/css; charset=utf-8'),('js','text/javascript; charset=utf-8')):
    hosting['hosting']['headers']=[item for item in hosting['hosting']['headers']
                                   if item['source']!='/assets/sowrix-assist-*.'+suffix]
    hosting['hosting']['headers'].append({'source':'/assets/sowrix-assist-*.'+suffix,'headers':[
        {'key':'Content-Type','value':content_type},
        {'key':'Cache-Control','value':'public, max-age=31536000, immutable'},
        {'key':'X-Content-Type-Options','value':'nosniff'}]})
for suffix,content_type in (('css','text/css; charset=utf-8'),('js','text/javascript; charset=utf-8')):
    hosting['hosting']['headers']=[item for item in hosting['hosting']['headers']
                                   if item['source']!='/assets/sowrix-enterprise-*.'+suffix]
    hosting['hosting']['headers'].append({'source':'/assets/sowrix-enterprise-*.'+suffix,'headers':[
        {'key':'Content-Type','value':content_type},
        {'key':'Cache-Control','value':'public, max-age=31536000, immutable'},
        {'key':'X-Content-Type-Options','value':'nosniff'}]})
for suffix,content_type in (('css','text/css; charset=utf-8'),('js','text/javascript; charset=utf-8')):
    hosting['hosting']['headers']=[item for item in hosting['hosting']['headers']
                                   if item['source']!='/assets/sowrix-ops-*.'+suffix]
    hosting['hosting']['headers'].append({'source':'/assets/sowrix-ops-*.'+suffix,'headers':[
        {'key':'Content-Type','value':content_type},
        {'key':'Cache-Control','value':'public, max-age=31536000, immutable'},
        {'key':'X-Content-Type-Options','value':'nosniff'}]})
for suffix,content_type in (('css','text/css; charset=utf-8'),('js','text/javascript; charset=utf-8')):
    hosting['hosting']['headers']=[item for item in hosting['hosting']['headers']
                                   if item['source']!='/assets/sowrix-suite46-*.'+suffix]
    hosting['hosting']['headers'].append({'source':'/assets/sowrix-suite46-*.'+suffix,'headers':[
      {'key':'Content-Type','value':content_type},
      {'key':'Cache-Control','value':'public, max-age=31536000, immutable'},
      {'key':'X-Content-Type-Options','value':'nosniff'}]})
for ext,mime in (('css','text/css; charset=utf-8'),('js','text/javascript; charset=utf-8')):
    hosting['hosting']['headers']=[entry for entry in hosting['hosting']['headers']
                                   if entry['source']!='/assets/sowrix-growth-*.'+ext]
    hosting['hosting']['headers'].append({'source':'/assets/sowrix-growth-*.'+ext,'headers':[
       {'key':'Content-Type','value':mime},{'key':'Cache-Control','value':'public, max-age=31536000, immutable'},
       {'key':'X-Content-Type-Options','value':'nosniff'}]})
hosting['hosting']['headers'].sort(key=lambda item:item['source']=='/api/**')
hosting_file.write_bytes((json.dumps(hosting,indent=2)+"\n").encode('utf-8'))
meta={"release":RELEASE,"source_sha256":hashlib.sha256((ROOT/"original/index(5).html").read_bytes()).hexdigest(),
      "output_sha256":hashlib.sha256(source.encode()).hexdigest(),"bytes":len(source.encode()),"inline_script_hashes":len(hashes)}
meta['design_edition']=DESIGN_EDITION
meta['distribution_version']='R46.26'
meta['feature_edition']='R46.26-PUBLIC-SEO-WEBP-NAVIGATION-STABILITY'
meta['previous_feature_edition']='R46.23-AUTOMATIC-BUSINESS-NUMBERING'
meta['performance_edition']='R37-FAST-NAV-LAUNCH-CANDIDATE'
meta['font_css_asset']='assets/'+font_name
meta['font_css_bytes']=len(font_css)
meta['css_assets']=cache_css
meta['assistant_assets']=assistant_assets
meta['enterprise_assets']=enterprise_assets
meta['ops_assets']=ops_assets
meta['suite_assets']=suite_assets
meta['growth_assets']=growth_assets
meta['design_assets']={path.relative_to(output).as_posix():hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted((output/'assets').glob('*')) if path.is_file() and path.suffix.lower() in {'.svg','.png','.webp','.jpg','.jpeg'}}
(output/'public-documents.json').write_bytes((json.dumps(public_documents,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
meta['public_assets']={name:hashlib.sha256((output/name).read_bytes()).hexdigest() for name in
      ('index.html','index.html.gz','csp.txt','public-reference.html','public-reference.html.gz','public-reference.csp.txt','public-documents.json','assets/vendor-supabase.v2.js','assets/'+font_name,*cache_css,*assistant_assets,*enterprise_assets,*ops_assets,*suite_assets,*growth_assets,'status.html','trust.html','case-studies.html','r467-public.css','r467-status.js','robots.txt',*(['sitemap.xml'] if public_site_url else []),'downloads/SOWRIX-Corporate-Brochure.pptx','manifest.webmanifest','sw.js','offline.html','downloads/reference/sowrix-complete.sql','downloads/reference/sowrix-access.sql','downloads/reference/sowrix-suite.sql','downloads/reference/sowrix-foundation.sql')}
(output/"build.json").write_bytes(json.dumps(meta,indent=2).encode('utf-8'))
print(json.dumps(meta))
