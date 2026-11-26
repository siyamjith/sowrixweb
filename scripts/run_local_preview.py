"""Run aiohttp locally with synthetic, non-provider configuration only."""
import argparse, os, runpy, sys
from cryptography.fernet import Fernet

SAFE_ENV = {
    "HOST": "127.0.0.1", "PORT": "8161",
    "PUBLIC_ORIGIN": "http://127.0.0.1:8161", "LOCAL_DEV": "true",
    "SUPABASE_URL": "", "SUPABASE_SELF_HOSTED_ORIGIN": "",
    "SUPABASE_PUBLISHABLE_KEY": "", "SUPABASE_SERVICE_ROLE_KEY": "",
    "GEMINI_API_KEY": "", "RESEND_API_KEY": "", "MEDIAMTX_WHEP_URL": "",
    "MEDIAMTX_AUTH_SECRET": "", "TURN_URLS": "", "TURN_SHARED_SECRET": "",
    "ALERT_EMAIL_ENABLED": "false", "BUSINESS_EMAIL_ENABLED": "false",
    "BUSINESS_NOTIFICATIONS_ENABLED": "false", "SOWRIX_R462_AUTOMATION_ENABLED": "false",
    "SOWRIX_R463_BUSINESS_AI_ENABLED": "false", "SOWRIX_PUBLIC_AI_ENABLED": "false",
    "SOWRIX_EARLY_ACCESS_ENABLED": "false",
}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--port', type=int, default=8161)
args = parser.parse_args()
if not 1024 <= args.port <= 65535:
    parser.error('Choose an unprivileged local port from 1024 to 65535.')
SAFE_ENV.update(PORT=str(args.port), PUBLIC_ORIGIN=f'http://127.0.0.1:{args.port}')
os.environ.update(SAFE_ENV)
os.environ["SOWRIX_SESSION_KEY"] = Fernet.generate_key().decode("ascii")
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(root, "backend"))
os.chdir(root)
runpy.run_path(os.path.join(root, "backend", "server.py"), run_name="__main__")
