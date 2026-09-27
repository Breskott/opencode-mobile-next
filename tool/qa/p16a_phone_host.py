#!/usr/bin/env python3
"""Private loopback host for the explicitly authorized P1.6a physical probe.

Build with scratch/defines.json. Atomically publish request.json containing
id/op/script/timeout; the response is saved as <id>.json. Use one outstanding
request and never print secrets or raw login output. This helper performs no
adb operations or device cleanup. See the gate report for the exact serial.
"""
import argparse
import http.server
import json
import pathlib
import re
import secrets

parser = argparse.ArgumentParser()
parser.add_argument('scratch', type=pathlib.Path)
parser.add_argument('--reuse-token', action='store_true',
                    help='Resume the same private host token for an existing probe APK')
args = parser.parse_args()
D = args.scratch.resolve()
D.mkdir(mode=0o700, parents=True, exist_ok=True)
if D.stat().st_mode & 0o077:
    raise SystemExit('Scratch directory must have mode 0700')
if args.reuse_token:
    TOKEN = json.loads((D / 'defines.json').read_text())['P16A_TOKEN']
else:
    if (D / 'defines.json').exists():
        raise SystemExit('Use fresh scratch or explicitly --reuse-token')
    TOKEN = secrets.token_hex(32)
    (D / 'defines.json').write_text(json.dumps({
        'P16A_PHYSICAL': 'true', 'P16A_TOKEN': TOKEN,
    }))
    (D / 'daemon-secret').write_text(secrets.token_hex(32))
for name in ['defines.json', 'daemon-secret']:
    (D / name).chmod(0o600)


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *unused):
        pass

    def reply(self, code, data=b''):
        self.send_response(code)
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        if data:
            self.wfile.write(data)

    def authorized(self):
        if not secrets.compare_digest(
            self.headers.get('Authorization', ''), 'Bearer ' + TOKEN
        ):
            self.reply(403)
            return False
        return True

    def body(self):
        # Dart HttpClient.write normally sends chunked bodies. Bound reads and
        # accept no trailers; this is a private JSON protocol, not a proxy.
        limit = 1024 * 1024
        if self.headers.get('Transfer-Encoding', '').lower() == 'chunked':
            data = bytearray()
            while True:
                size = int(self.rfile.readline(128).split(b';')[0], 16)
                if size < 0 or len(data) + size > limit:
                    raise ValueError('Body too large')
                if size == 0:
                    if self.rfile.readline(128) != b'\r\n':
                        raise ValueError('Unexpected trailers')
                    return bytes(data)
                block = self.rfile.read(size)
                if len(block) != size or self.rfile.read(2) != b'\r\n':
                    raise ValueError('Invalid chunk')
                data.extend(block)
        size = int(self.headers.get('Content-Length', '0'))
        if size < 0 or size > limit:
            raise ValueError('Body too large')
        return self.rfile.read(size)

    def do_GET(self):
        if not self.authorized():
            return
        request = D / 'request.json'
        if self.path != '/request':
            self.reply(404)
        elif not request.exists():
            self.reply(204)
        else:
            data = request.read_bytes()
            request.unlink()
            self.reply(200, data)

    def do_POST(self):
        if not self.authorized():
            return
        try:
            data = self.body()
            obj = json.loads(data)
            if self.path == '/ready':
                (D / 'ready.json').write_bytes(data)
            elif self.path == '/response':
                ident = obj.get('id')
                if not isinstance(ident, str) or not re.fullmatch(r'[A-Za-z0-9_-]+', ident):
                    raise ValueError('Invalid response id')
                (D / (ident + '.json')).write_bytes(data)
            else:
                self.reply(404)
                return
        except (ValueError, TypeError):
            self.reply(400)
            return
        self.reply(200)


http.server.ThreadingHTTPServer(('127.0.0.1', 18761), Handler).serve_forever()
