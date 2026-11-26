"""Validate reviewed public knowledge before the build emits any artifacts."""
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
SOURCES = (
    'reference-build/standalone/01-head.html', 'reference-build/standalone/02-home.html',
    'reference-build/standalone/03-views.html', 'reference-build/standalone/04-shell.html',
    'reference-build/standalone/05-data.js', 'reference-build/standalone/06-app.js',
    'reference-build/index.html',
    'src/inline-3.js', 'src/sowrix-public-ui.js', 'src/sowrix-public-route-bridge.js',
    'backend/public_routes.py', '.env.example', 'deployment/sowrix.production.env.example',
    'src/sowrix-public-knowledge.json',
)


def digest(root=ROOT):
    h = hashlib.sha256()
    for name in SOURCES:
        h.update(name.encode() + b'\0')
        h.update(hashlib.sha256((root / name).read_bytes()).digest())
    return h.hexdigest()


def validate(kb, root=ROOT, check_review=True):
    def require(condition, label):
        if not condition:
            raise ValueError('Public knowledge: ' + label)

    views = (root / SOURCES[2]).read_text(encoding='utf-8')
    reference = (root / 'reference-build/index.html').read_text(encoding='utf-8')
    shell = (root / SOURCES[3]).read_text(encoding='utf-8')
    product = kb['products'][0]
    require(len(kb['products']) == 1 and product['id'] == 'defensowrix'
            and product['availability'] == 'under_development' and product['early_access'] == 'not_open'
            and all(x in product['answer'].lower() for x in ('coming soon', 'not open', 'not available')),
            'DEFENSOWRIX and Early Access availability must match approved closed state')
    require(all(re.search(r'data-product-availability="coming-soon"[^>]*>[\s\S]*?</span>Coming Soon</p>',x) for x in (views, reference)),
            'Coming Soon public copy missing')
    for name in SOURCES[-3:-1]:
        require('SOWRIX_EARLY_ACCESS_ENABLED=false' in (root / name).read_text(encoding='utf-8').splitlines(),
                f'Early Access baseline must be off in {name}')
    company = kb['company']
    require(company['email'] == 'contact@sowrix.in' and company['domain'] == 'sowrix.in'
            and 'mailto:'+company['email'] in shell and 'mailto:'+company['email'] in reference, 'official contact drift')
    pages = {p['id'] for p in kb['pages']}
    required_pages = {'home','about','services','industries','solutions','portfolio','insights','defensowrix','contact','careers'}
    require(pages == required_pages and len(kb['pages']) == len(required_pages),
            'required public pages missing or unreviewed page added')
    require(all(f'id="view-{page}"' in reference for page in pages-{'contact','careers'}),
            'approved page mount missing from rendered reference')
    services = kb['services']
    ids = {s['id'] for s in services}
    require(len(services) == 6 and len(ids) == 6 and ids == set(kb['conversation']['service_signals']),
            'six reviewed service pillars and signal groups required')
    data = (root / SOURCES[4]).read_text(encoding='utf-8')
    require(all(s['id'] in data and s['name'] in data and s['id'] in reference
                and s['page_link'] == '#/services/'+s['id'] for s in services),
            'pillar IDs/names must match the approved website')
    cards = kb['conversation']['cards']
    require({'product','pricing','domain','support','ai_core','consultation','private','clarify'} <= cards.keys(),
            'required guidance missing')
    require(all(c.get('keywords') and c.get('tamil') and c.get('tanglish') and
                (name == 'product' or c.get('english')) for name,c in cards.items()), 'localized guidance missing')
    require({'careers','client','contact','about','industries','solutions','portfolio','privacy'} <= {x['id'] for x in kb['topics']},
            'required knowledge topics missing')
    approved_hashes = {'/','contact','defensowrix-request'} | {'/'+x for x in pages if x not in ('careers','contact','home')}
    approved_hashes |= {'/services/'+x for s in services for x in (s['id'],s['short_slug'])}
    links = [p['href'] for p in kb['pages']+kb['topics']] + [c['href'] for c in cards.values() if c['href']]
    links += [s[k] for s in services for k in ('page_link','consultation_link')]
    for link in links:
        u = urlsplit(link)
        require(not u.scheme and not u.netloc and not u.query and (
            (u.fragment in approved_hashes and u.path in ('','/')) or
            (u.path == '/app' and u.fragment == '/login') or
            (not u.fragment and u.path in ('/','/careers','/status.html','/privacy'))), 'unapproved link: '+link)
    require({s['url'] for s in kb['social_links']} == {'https://x.com/sowrixtech','https://www.youtube.com/@Sowrix'},
            'external links are restricted to official social accounts')
    require(not re.search(r'SUPABASE_|RESEND_API_KEY|GEMINI_API_KEY|BEGIN [A-Z ]*PRIVATE KEY|recovery/|docs/',json.dumps(kb)),
            'internal material is not public knowledge')
    if check_review:
        expected = (root / 'scripts/public_knowledge_review.sha256').read_text(encoding='ascii').strip()
        require(digest(root) == expected, 'approved inputs changed; review the knowledge and update the review digest')
    return kb


if __name__ == '__main__':
    import sys
    kb=json.loads((ROOT / SOURCES[-1]).read_text(encoding='utf-8'))
    if sys.argv[1:] == ['--digest']:
        validate(kb,check_review=False)
        print(digest())
    else:
        validate(kb)
        print('Public knowledge review verified')
