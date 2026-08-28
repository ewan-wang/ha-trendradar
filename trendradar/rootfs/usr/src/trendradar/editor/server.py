#!/usr/bin/env python3
"""TrendRadar Hass-Addon — visual config editor webserver.

Serves:
  GET  /                       → editor index.html (and other static assets via SimpleHTTPRequestHandler)
  GET  /api/files              → {filename: content} for the 3 editable config files
  GET  /api/status             → {status: ok, config_dir: ..., addon_version: ...}
  POST /api/files              → save one or more of the 3 files (JSON body)
  POST /api/restart            → POST to Supervisor /addons/self/restart (causes container restart)

All file paths are validated against ALLOWED_FILES; no path traversal is possible.
"""
import http.server
import json
import os
import socketserver
import sys
import threading
import urllib.request
import urllib.error
from pathlib import Path

CONFIG_DIR = Path(os.environ.get('CONFIG_DIR', '/share/trendradar/config'))
EDITOR_DIR = Path(os.environ.get('EDITOR_DIR', '/usr/src/trendradar/editor'))
PORT       = int(os.environ.get('EDITOR_PORT', '8089'))
SUP_TOKEN  = os.environ.get('SUPERVISOR_TOKEN', '')
ADDON_VERSION = os.environ.get('ADDON_VERSION', 'dev')

ALLOWED_FILES = {
    'config.yaml',
    'frequency_words.txt',
    'timeline.yaml',
}

_lock = threading.Lock()  # serialize writes to avoid half-written files


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(EDITOR_DIR), **kwargs)

    def log_message(self, fmt, *args):
        # HA Supervisor captures stderr → add-on log tab.
        sys.stderr.write('[editor] %s - %s\n' % (self.address_string(), fmt % args))

    # ------------------------------------------------------------------ GET
    def do_GET(self):
        if self.path == '/api/files':
            with _lock:
                payload = {
                    name: (CONFIG_DIR / name).read_text(encoding='utf-8')
                    for name in sorted(ALLOWED_FILES)
                    if (CONFIG_DIR / name).is_file()
                }
            return self._json({'status': 'ok', 'files': payload})

        if self.path == '/api/status':
            return self._json({
                'status': 'ok',
                'config_dir': str(CONFIG_DIR),
                'addon_version': ADDON_VERSION,
                'editor_port': PORT,
                'has_supervisor_token': bool(SUP_TOKEN),
            })

        # everything else → served as static files from EDITOR_DIR
        return super().do_GET()

    # ------------------------------------------------------------------ POST
    def do_POST(self):
        if self.path == '/api/files':
            return self._save_files()
        if self.path == '/api/restart':
            return self._restart_addon()
        return self._json({'status': 'error', 'message': 'not found'}, code=404)

    # ------------------------------------------------------------------ helpers
    def _read_body(self):
        length = int(self.headers.get('Content-Length', 0))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode('utf-8'))
        except Exception as e:
            raise ValueError(f'invalid JSON body: {e}') from e

    def _save_files(self):
        try:
            body = self._read_body()
        except ValueError as e:
            return self._json({'status': 'error', 'message': str(e)}, code=400)

        files = body.get('files') if isinstance(body, dict) and 'files' in body else body
        if not isinstance(files, dict):
            return self._json({'status': 'error', 'message': 'expected {"files": {name: content}}'}, code=400)

        saved, rejected = [], []
        with _lock:
            for name, content in files.items():
                if name not in ALLOWED_FILES:
                    rejected.append(name)
                    continue
                if not isinstance(content, str):
                    rejected.append(name)
                    continue
                path = CONFIG_DIR / name
                path.parent.mkdir(parents=True, exist_ok=True)
                tmp = path.with_suffix(path.suffix + '.tmp')
                tmp.write_text(content, encoding='utf-8')
                os.replace(tmp, path)
                saved.append(name)

        return self._json({'status': 'ok', 'saved': saved, 'rejected': rejected})

    def _restart_addon(self):
        if not SUP_TOKEN:
            return self._json({
                'status': 'error',
                'message': 'SUPERVISOR_TOKEN missing — not running under HA Supervisor',
            }, code=503)
        url = 'http://supervisor/addons/self/restart'
        req = urllib.request.Request(url, method='POST', headers={
            'Authorization': f'Bearer {SUP_TOKEN}',
        })
        try:
            with urllib.request.urlopen(req, timeout=5) as r:
                return self._json({'status': 'restarting', 'supervisor_code': r.status})
        except urllib.error.HTTPError as e:
            return self._json({'status': 'error', 'message': f'supervisor returned {e.code}', 'body': e.read().decode('utf-8', 'replace')}, code=502)
        except Exception as e:
            return self._json({'status': 'error', 'message': f'request failed: {e}'}, code=502)

    def _json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        self.wfile.write(body)


class ThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    EDITOR_DIR.mkdir(parents=True, exist_ok=True)
    httpd = ThreadingServer(('0.0.0.0', PORT), Handler)
    sys.stderr.write(
        f'[editor] listening on 0.0.0.0:{PORT}  '
        f'config_dir={CONFIG_DIR}  editor_dir={EDITOR_DIR}  '
        f'supervisor_token={"present" if SUP_TOKEN else "ABSENT"}\n'
    )
    sys.stderr.flush()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()