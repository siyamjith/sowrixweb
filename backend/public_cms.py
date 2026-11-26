"""Revisioned, public-only editorial notices with a separate approved FAQ lane."""
import re
from html import escape
from html.parser import HTMLParser

from aiohttp import web

KINDS = frozenset('services industries solutions portfolio insights careers announcements contact seo knowledge'.split())
SLUG = re.compile(r'[a-z0-9][a-z0-9-]{0,63}')
IMAGES = frozenset(('services', 'solutions', 'portfolio', 'insights', 'careers', 'contact'))
NO_STORE = {'Cache-Control': 'no-store'}
CONTACT_PATTERNS = {
    'primary-phone': r'\+[1-9][0-9]{7,14}',
    'secondary-phone': r'\+[1-9][0-9]{7,14}',
    'social-x': r'https://x\.com/[A-Za-z0-9_]{1,15}',
    'social-youtube': r'https://www\.youtube\.com/@[A-Za-z0-9_.-]{2,60}',
    'social-instagram': r'https://www\.instagram\.com/[A-Za-z0-9_.]{1,30}/?',
    'social-linkedin': r'https://(?:www\.)?linkedin\.com/company/[A-Za-z0-9-]{2,80}/?',
    'business-email': r'contact@sowrix\.in',
}
CONTACT_LIMITS = {'company-name': 48, 'company-description': 320, 'office-address': 240, 'business-hours': 160}
STATIC_ARTICLE_SLUGS = frozenset({
    'small-office-network-setup-guide', '3-2-1-backup-rule-explained',
    'website-vs-web-app-vs-mobile-app',
})


class ArticleText(HTMLParser):
    """Read legacy rich text as plain paragraphs, never as executable markup."""
    def __init__(self):
        super().__init__()
        self.parts = []
        self.hidden = []

    def handle_starttag(self, tag, attrs):
        if tag in {'script','style','template','iframe'}:
            self.hidden.append(tag)
        elif not self.hidden and tag in {'p','li','br','h1','h2','h3','h4','blockquote','div'}:
            self.parts.append('\n')

    def handle_endtag(self, tag):
        if self.hidden and self.hidden[-1] == tag:
            self.hidden.pop()

    def handle_data(self, data):
        if not self.hidden:
            self.parts.append(data)


def legacy_article_text(body):
    if not isinstance(body, str):
        return ''
    parser = ArticleText()
    parser.feed(body[:60000])
    parser.close()
    return ''.join(parser.parts)
SERVICE_FIELD = re.compile(
    r'(it-infra-network|software-app-development|cybersecurity-data-protection|hardware-support-surveillance|'
    r'digital-marketing-growth-analytics|ai-automation-integration)'
    r'--(tagline|challenges|benefits|offerings|deliverables|use-cases)'
)


def valid_service_field(slug, body):
    match = SERVICE_FIELD.fullmatch(slug)
    if not match and not slug.startswith('legacy-'):
        return True
    if not match and not re.fullmatch(r'legacy-[a-z0-9][a-z0-9-]*--deliverables',slug):
        return False
    if not isinstance(body, str):
        return False
    lines = [line.strip() for line in body.splitlines() if line.strip()]
    return (1 <= len(lines) <= (1 if match and match[2] == 'tagline' else 12)
            and all(len(line) <= 180 and line.isprintable() for line in lines))


def valid_contact(slug, body):
    if not isinstance(body, str):
        return False
    text = body.strip()
    if slug in CONTACT_PATTERNS:
        return re.fullmatch(CONTACT_PATTERNS[slug], text) is not None
    if slug in CONTACT_LIMITS:
        return 1 <= len(text) <= CONTACT_LIMITS[slug] and all(c.isprintable() for c in text)
    return True


def home_metadata(html, row, origin, path='/'):
    """Modify only head metadata; leave hashed inline scripts/styles untouched."""
    if not isinstance(row, dict) or not all(isinstance(row.get(k), str) for k in ('title', 'body')):
        return html
    head, separator, rest = html.partition('</head>')
    if not separator:
        return html
    title = escape(row['title'][:120] + ' | SOWRIX Technologies')
    description = escape(row['body'][:320])
    canonical = escape(origin.rstrip('/') + path)
    head = re.sub(r'<title>[^<]*</title>', lambda _: '<title>'+title+'</title>', head, count=1)
    updates = {'name="description"': description, 'property="og:title"': title,
               'property="og:description"': description, 'property="og:url"': canonical,
               'name="twitter:title"': title, 'name="twitter:description"': description}
    if row.get('image') in {'/assets/sx-' + name + '.webp' for name in IMAGES}:
        image = escape(origin.rstrip('/') + row['image'])
        updates.update({'property="og:image"': image, 'name="twitter:image"': image})
    updates['property="og:type"'] = 'article' if row.get('article') else 'website'
    for attr in ('property="og:image"', 'name="twitter:image"'):
        updates.setdefault(attr,escape(origin.rstrip('/')+'/assets/sowrix-original.png'))
    for attr, value in updates.items():
        tag = f'<meta {attr} content="{value}">'
        head, count = re.subn(r'<meta\s+' + re.escape(attr) + r'[^>]*>',lambda _: tag, head, count=1)
        if not count:
            head += '\n' + tag
    head = re.sub(r'<link\s+rel="canonical"[^>]*>', '', head)
    head += f'\n<link rel="canonical" href="{canonical}">\n'
    return head + separator + rest


async def read_body(request, limit=16000):
    if request.content_type != 'application/json' or not 0 < (request.content_length or 0) <= limit:
        raise web.HTTPBadRequest(text='Invalid request size or content type.')
    try:
        data = await request.json()
        if not isinstance(data, dict):
            raise ValueError
        return data
    except (ValueError, UnicodeError):
        raise web.HTTPBadRequest(text='Invalid request format.')


def project(kind, item):
    if not isinstance(item, dict) or not isinstance(item.get('slug'), str) or not SLUG.fullmatch(item['slug']):
        return None
    data = item.get('content')
    if not isinstance(data, dict) or not all(isinstance(data.get(k), str) for k in ('title', 'body')):
        return None
    if kind == 'contact' and not valid_contact(item['slug'], data['body']):
        return None
    if kind == 'services' and (SERVICE_FIELD.fullmatch(item['slug']) or item['slug'].startswith('legacy-')):
        if not valid_service_field(item['slug'], data['body']) or data.get('image'):
            return None
    slug = item['slug']
    body = data['body']
    if kind == 'contact' and (slug in CONTACT_PATTERNS or slug in CONTACT_LIMITS):
        body = body.strip()
    result = {'slug': slug, 'title': data['title'][:120], 'body': body[:3000]}
    if kind == 'knowledge':
        for key in ('question_en', 'question_ta', 'question_tl', 'answer_ta', 'answer_tl'):
            if isinstance(data.get(key), str):
                result[key] = data[key][:180 if key.startswith('question_') else 3000]
    if kind != 'knowledge' and isinstance(data.get('image'), str) and data['image'] in IMAGES:
        result['image'] = '/assets/sx-' + data['image'] + '.webp'
    return result


def register(app, upstream_error, digest):
    async def rpc(name, payload, **opts):
        try:
            return await app['gateway'].p.rpc(name, payload, **opts)
        except upstream_error as exc:
            if not opts.get('service') and exc.status in (401, 403):
                raise web.HTTPForbidden(text='An authorized CMS administrator and independent publication reviewer are required.')
            if not opts.get('service') and exc.status in (400, 409):
                raise web.HTTPConflict(text='Operation not applied. Check the fields or reload the latest revision.')
            raise web.HTTPServiceUnavailable(text='The CMS is temporarily unavailable.')

    async def published(kind):
        rows = await rpc('sowrix_cms_published', {'p_kind': kind}, service=True)
        if not isinstance(rows, list):
            raise web.HTTPServiceUnavailable(text='Publication could not be checked.')
        return rows[:100]

    async def index(request):
        kind = request.match_info['kind']
        if kind not in KINDS:
            raise web.HTTPNotFound()
        app['gateway'].rate('cms-public:' + digest(request.remote or 'unknown'), 150, 60)
        rows = await published(kind)
        return web.json_response({'items': [row for item in rows if (row := project(kind, item))]}, headers=NO_STORE)

    async def admin(request):
        gateway = app['gateway']
        session = await gateway.session(request)
        gateway.check_csrf(request)
        gateway.rate('cms-admin:' + digest(session['user']['id']), 90, 60)
        data = await read_body(request)
        action, kind, slug = (data.get(k) for k in ('action', 'kind', 'slug'))
        if (action not in ('list', 'preview', 'save', 'publish', 'unpublish', 'archive', 'restore')
                or not isinstance(kind, str) or kind not in KINDS
                or (action != 'list' and (not isinstance(slug, str) or not SLUG.fullmatch(slug)))):
            raise web.HTTPBadRequest(text='Invalid CMS operation or record key.')
        payload = {k: data[k] for k in ('head', 'version', 'content') if k in data}
        if action == 'save' and kind == 'contact':
            content = payload.get('content')
            if not isinstance(content, dict) or not valid_contact(slug, content.get('body')):
                raise web.HTTPBadRequest(text='Invalid public company setting. Check the format or length; the official email cannot be changed here.')
        if action == 'save' and kind == 'services' and (SERVICE_FIELD.fullmatch(slug) or slug.startswith('legacy-')):
            content = payload.get('content')
            if (not isinstance(content, dict) or not valid_service_field(slug, content.get('body'))
                    or content.get('image')):
                raise web.HTTPBadRequest(text='Use up to 12 lines of 180 characters, or one line for a tagline, with no image.')
        result = await rpc('sowrix_cms_admin', {'p_action': action, 'p_kind': kind,
                           'p_slug': slug if action != 'list' else None, 'p_data': payload},
                           token=session['access_token'])
        if not isinstance(result, (dict, list)):
            raise web.HTTPServiceUnavailable(text='The CMS did not confirm the operation.')
        return web.json_response({'data': result}, headers=NO_STORE)

    app.router.add_get('/api/public/editorial/{kind}', index)
    app.router.add_post('/api/admin/editorial', admin)
