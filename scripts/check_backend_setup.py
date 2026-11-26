"""Read-only R94 configuration and generated-site check; never print secrets."""
import argparse
import asyncio
import hashlib
import json
import os
import re
import socket
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

REQUIRED = ('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY', 'SUPABASE_SERVICE_ROLE_KEY', 'SOWRIX_SESSION_KEY')


def env_issues(path, environ):
    """Report ambiguous settings without exposing values."""
    seen = set()
    issues = []
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        if not line.strip() or line.lstrip().startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        key = key.strip()
        if not re.fullmatch(r'[A-Z][A-Z0-9_]+', key):
            issues.append('Invalid environment variable name (value hidden)')
            continue
        if key in seen:
            issues.append('Duplicate setting: ' + key)
        seen.add(key)
        if key in REQUIRED and key in environ and environ[key] != value.strip().strip('"').strip("'"):
            issues.append('Process environment overrides file setting: ' + key)
    return issues


def check_assets(root):
    site = root / 'site'
    data = json.loads((site / 'build.json').read_text(encoding='utf-8'))
    files = {'index.html': data['output_sha256'], **data['design_assets'], **data['public_assets']}
    for name, expected in files.items():
        path = (site / name).resolve()
        if not path.is_relative_to(site.resolve()) or not path.is_file():
            raise ValueError('Missing or invalid generated asset')
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError('Generated asset hash mismatch')
    return len(files)


async def remote_check(settings):
    import aiohttp
    from backend.server import Provider
    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=15), trust_env=False) as client:
        provider = Provider(settings, client)
        # No row data is requested, no mutation or login attempt is performed.
        for table, column in [('sowrix_def_sessions', 'token_hash'), ('sowrix_def_orgs', 'id')]:
            try:
                rows = await provider.table('GET', table, 'select='+column+'&limit=0')
                if not isinstance(rows, list) or rows:
                    print('[FAIL] Unexpected read-only result:', table)
                    return False
                print('[PASS] Read-only table query:', table)
            except Exception:
                print('[FAIL] Read-only table query:', table, '(provider error; details hidden)')
                return False
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--remote', action='store_true', help='Opt in to zero-row Supabase table checks')
    parser.add_argument('--check-port', action='store_true', help='Check whether the local bind address is available')
    args = parser.parse_args()
    print('SOWRIX R94 PRE-FLIGHT (no secret values displayed)')
    try:
        from backend.server import Settings
        from cryptography.fernet import Fernet
    except ImportError:
        print('[FAIL] Python dependencies missing. Run python -m pip install -r requirements.lock')
        return 1
    path = ROOT / '.env'
    ok = True
    if path.is_file():
        for issue in env_issues(path, os.environ):
            print('[FAIL]', issue)
            ok = False
    else:
        print('[INFO] No .env file; checking process environment only.')
    try:
        settings = Settings.from_env()
    except Exception:
        print('[FAIL] Configuration could not be parsed; check .env formatting and numeric settings.')
        return 1
    for key, value in zip(REQUIRED, (settings.supabase_url, settings.public_key, settings.service_key, settings.session_key)):
        valid = bool(value)
        if key == 'SOWRIX_SESSION_KEY' and valid:
            try:
                Fernet(value.encode())
            except Exception:
                valid = False
        print('[PASS]' if valid else '[FAIL]', key, 'present/valid format' if valid else 'missing or invalid')
        ok &= valid
    try:
        settings.validate()
        print('[PASS] Backend configuration validation')
    except Exception:
        print('[FAIL] Backend configuration validation (check origin, local mode and key format)')
        ok = False
    try:
        print('[PASS] Generated site hashes:', check_assets(ROOT))
    except Exception:
        print('[FAIL] Generated site integrity; run python scripts/build.py in the development package')
        ok = False
    if args.check_port and settings.local_dev:
        try:
            host = os.getenv('HOST', '127.0.0.1')
            if host not in ('127.0.0.1', 'localhost', '::1'):
                raise ValueError('Not loopback')
            with socket.socket(socket.AF_INET6 if host == '::1' else socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.bind((host, int(os.getenv('PORT', '8158'))))
            print('[PASS] Local bind address available')
        except (OSError, ValueError, OverflowError):
            print('[FAIL] Local bind address unavailable or invalid; stop the existing SOWRIX server or review HOST/PORT')
            ok = False
    if args.remote and ok:
        ok = asyncio.run(remote_check(settings))
    print('READY' if ok else 'NOT READY')
    print('This does not verify user login, MFA, RLS, every migration or optional integrations.')
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
