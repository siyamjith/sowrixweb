"""Reuse compiled reference chrome without leaking its CSS into portal screens."""
import html
import json
import re


def integrate(source, reference, root, script):
    header = re.search(r'<header id="site-nav"[^>]*>[\s\S]*?</header>', reference)
    footer = re.search(r'<footer\b[\s\S]*?</footer>', reference)
    menu_start = reference.find('<div id="mmenu"')
    menu_end = reference.find('<main ', menu_start)
    if not header or not footer or menu_start < 0 or menu_end < menu_start:
        raise RuntimeError('Compiled reference header/footer/menu integration points missing')
    css = '\n'.join(re.findall(r'<style\b[^>]*>([\s\S]*?)</style>', reference))
    if not css or '{{' in css:
        raise RuntimeError('Compiled reference stylesheet is required')
    # Shadow roots keep Tailwind preflight, utility classes and variables away
    # from the existing portal DOM. Logos/icons are reused byte-for-byte.
    css = css.replace(':root', ':host') + '\n:host{display:block;font-family:Inter,ui-sans-serif,system-ui,sans-serif}.sx-reference-theme{color:var(--foreground);background:var(--background)}'
    css += '\n#theme-toggle .theme-icon{display:grid;place-items:center;opacity:0}#theme-toggle .theme-icon svg{width:18px;height:18px}.sx-reference-theme:not(.dark) #theme-toggle .icon-sun,.sx-reference-theme.dark #theme-toggle .icon-moon{opacity:1;transform:none}'
    search_start = reference.find('<div id="public-search"', header.end())
    navigation = re.search(r'<script id="phase4-reference-navigation">([\s\S]*?)/\* REFERENCE_NAV_BOOT \*/', reference)
    if not navigation or not header.end() <= search_start < menu_start:
        raise RuntimeError('Shared reference navigation missing')
    header_html = header.group(0) + reference[search_start:menu_end]
    footer_html = footer.group(0)
    knowledge = json.loads((root/'src/sowrix-public-knowledge.json').read_text(encoding='utf-8'))
    pillars = ''.join('<li><a href="/#/services" class="inline-flex min-h-9 items-center gap-2 text-sm font-medium text-muted-foreground transition-colors hover:text-brand dark:hover:text-brand-accent">' + html.escape(item['name']) + '</a></li>' for item in knowledge['services'])
    footer_html = footer_html.replace('id="footer-pillars"></ul>', 'id="footer-pillars">'+pillars+'</ul>')
    header_html = header_html.replace('href="#', 'href="/#')
    footer_html = footer_html.replace('href="#', 'href="/#')
    chrome = dict(header=header_html, footer=footer_html, css=css)
    module = (root/'src/sowrix-public-experience.js').read_text(encoding='utf-8')
    if module.count('__SOWRIX_REFERENCE_CHROME__') != 1:
        raise RuntimeError('Public experience payload marker mismatch')
    module = module.replace('__SOWRIX_REFERENCE_CHROME__', json.dumps(chrome, ensure_ascii=False))
    module = module.replace('/* SHARED_REFERENCE_NAVIGATION */', navigation[1])
    gate = '<style id="sowrix-public-experience-gate">html.sx-public-flow body>.hdr,html.sx-public-flow body>.foot{display:none!important}</style>'
    source = source.replace('</head>', gate+script('sowrix-public-experience',module)+'\n</head>',1)
    stylesheet = (root/'src/sowrix-public-experience.css').read_text(encoding='utf-8')
    source = source.replace('</body>','<style id="sowrix-public-experience-style">\n'+stylesheet+'\n</style>\n</body>',1)
    insertion = "document.getElementById('main').innerHTML=matched.html;"
    if source.count(insertion) != 1:
        raise RuntimeError('Public presentation render hook is not unique')
    source = source.replace(insertion,insertion+'\n window.SOWRIXPublicExperience.sync(raw);',1)
    return source
