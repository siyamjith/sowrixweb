"""Bounded upload format checks, not a malware scanner or a safe-file guarantee.

Storage RLS still authorizes every forwarded request with the caller's token.
Direct Supabase uploads and malware quarantine need separate hosted controls.
"""
import io
import struct
import zipfile
from email import policy
from email.parser import BytesParser
from pathlib import PurePosixPath
from aiohttp import web

MIB = 1024 * 1024
PRIVATE_LIMIT = 10 * MIB
RESUME_LIMIT = 5 * MIB
MULTIPART_OVERHEAD = 64 * 1024
TYPES = {'pdf': 'application/pdf', 'png': 'image/png', 'jpg': 'image/jpeg',
         'jpeg': 'image/jpeg', 'webp': 'image/webp', 'doc': 'application/msword',
         'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'}

def upload_path(path, method):
    """Match only ordinary object uploads, not sign/list/copy/update-metadata APIs."""
    if method not in ('POST', 'PUT'):
        return None
    prefix = '/storage/v1/object/'
    if not path.startswith(prefix):
        return None
    bucket, separator, key = path[len(prefix):].partition('/')
    return (bucket, key) if separator and bucket in ('sowrix-private', 'resumes') else None

def _bad(message='File content does not match its supported format'):
    raise web.HTTPBadRequest(text=message)

def _file_content(raw, content_type):
    if not content_type.lower().startswith('multipart/form-data'):
        return raw, content_type.split(';', 1)[0].strip().lower()
    if len(content_type) > 500 or '\r' in content_type or '\n' in content_type:
        _bad('Invalid multipart upload')
    message = BytesParser(policy=policy.default).parsebytes(
        b'Content-Type: ' + content_type.encode('ascii') + b'\r\nMIME-Version: 1.0\r\n\r\n' + raw)
    if not message.is_multipart() or message.defects:
        _bad('Invalid multipart upload')
    parts = list(message.iter_parts())
    if len(parts) > 4:
        _bad('Upload one file at a time')
    files = []
    for part in parts:
        if part.is_multipart() or part.defects or part.get('Content-Transfer-Encoding'):
            _bad('Unsupported multipart upload')
        content = part.get_payload(decode=True)
        if not isinstance(content, bytes):
            _bad('Invalid multipart upload')
        if part.get_filename() is not None:
            files.append((content, part.get_content_type()))
        elif part.get_param('name', header='content-disposition') not in ('cacheControl', 'metadata') or len(content) > 8192:
            _bad('Unsupported upload metadata')
    if len(files) != 1:
        _bad('Upload exactly one file')
    return files[0]

def validate_upload(raw, content_type, bucket, key):
    content, mime = _file_content(raw, content_type)
    limit = RESUME_LIMIT if bucket == 'resumes' else PRIVATE_LIMIT
    if len(content) > limit:
        raise web.HTTPRequestEntityTooLarge(max_size=limit, actual_size=len(content))
    if not content:
        _bad('The uploaded file is empty')
    suffix = PurePosixPath(key).suffix.lower().lstrip('.')
    allowed = ('pdf', 'doc', 'docx') if bucket == 'resumes' else ('pdf', 'png', 'jpg', 'jpeg', 'webp')
    if suffix not in allowed or mime != TYPES.get(suffix):
        _bad('Use an allowed file extension and matching content type')
    if suffix == 'pdf':
        valid = content.startswith(b'%PDF-') and b'%%EOF' in content[-2048:]
    elif suffix == 'png':
        valid = len(content) >= 33 and content.startswith(b'\x89PNG\r\n\x1a\n') and content[12:16] == b'IHDR' and content.endswith(b'IEND\xaeB`\x82')
    elif suffix in ('jpg', 'jpeg'):
        valid = len(content) >= 12 and content.startswith(b'\xff\xd8\xff') and content.endswith(b'\xff\xd9')
    elif suffix == 'webp':
        valid = len(content) >= 20 and content[:4] == b'RIFF' and content[8:12] == b'WEBP' and struct.unpack('<I', content[4:8])[0] == len(content) - 8 and content[12:16] in (b'VP8 ', b'VP8L', b'VP8X')
    elif suffix == 'doc':
        valid = content.startswith(b'\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1') and 'WordDocument'.encode('utf-16-le') in content
    else:
        try:
            with zipfile.ZipFile(io.BytesIO(content)) as archive:
                entries = archive.infolist()
                names = [entry.filename for entry in entries]
                valid = (len(entries) <= 2000 and len(names) == len(set(names)) and
                    '[Content_Types].xml' in names and 'word/document.xml' in names and
                    sum(entry.file_size for entry in entries) <= 50 * MIB and
                    all(not entry.flag_bits & 1 and not entry.filename.startswith(('/', '\\')) and
                        '..' not in PurePosixPath(entry.filename.replace('\\', '/')).parts and
                        not entry.filename.lower().endswith('vbaproject.bin') and
                        entry.file_size <= max(4096, entry.compress_size * 100) for entry in entries))
        except (ValueError, OSError, zipfile.BadZipFile):
            valid = False
    if not valid:
        _bad()
    return {'bytes': len(content), 'content_type': mime}
