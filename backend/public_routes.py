"""Known SPA paths only. Never serve source/configuration as a fallback."""
import re

PUBLIC_PATH_PATTERN = r'^/(?:about|services|industries|solutions|portfolio|blog|defensowrix|careers|contact|privacy|terms|cookies|disclaimer|quote|compare|faq|stories|login|workspace|admin|hr|employee|client-portal|client-projects|client-tickets|client-invoices|client-quotes|client-amc|client-documents|client-defensowrix|portal|client)(?:/[A-Za-z0-9_-]+)*/?$'
PUBLIC_PATH = re.compile(PUBLIC_PATH_PATTERN)
ROUTE_ALIASES = {
    '/client': '/client-portal', '/client/dashboard': '/client-portal',
    '/client/login': '/login', '/portal': '/client-portal',
    '/portal/login': '/login', '/portal/dashboard': '/client-portal',
    '/portal/projects': '/client-projects', '/portal/tickets': '/client-tickets',
    '/portal/invoices': '/workspace/invoices', '/portal/quotes': '/workspace/tools/quotes',
    '/portal/amc': '/workspace/amc', '/client-amc': '/workspace/amc',
    '/portal/documents': '/workspace/tools/documents',
}

# The reference marketing experience lives at /; the authenticated legacy SPA
# remains available at /app. URL fragments never reach the HTTP server.
APP_SHELL_PATHS = frozenset(('/app', '/app/index.html'))
PUBLIC_REFERENCE_ROUTE_HASHES = {
    '/about':'about', '/services':'services', '/industries':'industries',
    '/solutions':'solutions', '/portfolio':'portfolio', '/blog':'insights',
    '/defensowrix':'defensowrix',
}

def is_app_shell_path(path: str) -> bool:
    return path in APP_SHELL_PATHS

# R46: preserve legacy bookmarks while retiring their demo experiences.
LEGACY_PUBLIC_REDIRECTS = {
    '/quote': '/contact', '/compare': '/services',
    '/faq': '/services', '/stories': '/portfolio',
    '/discover/blog': '/blog', '/discover/portfolio': '/portfolio',
    '/discover/careers': '/careers',
}
