#!/usr/bin/env python3
"""mock_llm.py [PORT]  (default 4199, binds 127.0.0.1 only)

A deterministic OpenAI-compatible chat endpoint for timing the app, so the
model's own speed (free models queue for 2-70 s, and some deliver a whole
reply in one burst) does not decide the numbers. Issue #87 proof.

POST /v1/chat/completions (stream or not):
  - last user message contains "word ok"  -> "ok", first token after
    FIRST_TOKEN_MS (default 300 ms);
  - anything else -> a fixed ~4,000-character markdown story streamed as
    ~5-word chunks every CHUNK_MS (default 40 ms, i.e. ~20 s of streaming);
  - title requests (a system prompt about titles) -> "Timing run".
GET /v1/models lists the one model "stream".

Wire it into OpenCode with a project opencode.json:
  {"model": "mock/stream", "small_model": "mock/stream",
   "provider": {"mock": {"npm": "@ai-sdk/openai-compatible", "name": "Mock",
     "options": {"baseURL": "http://127.0.0.1:4199/v1", "apiKey": "none"},
     "models": {"stream": {"name": "Mock stream"}}}}}
"""
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

FIRST_TOKEN_MS = int(os.environ.get('FIRST_TOKEN_MS', '300'))
CHUNK_MS = int(os.environ.get('CHUNK_MS', '40'))

PARA = ("The keeper climbed the spiral stairs at dusk, counting each of the "
        "one hundred and twelve steps the way his father had taught him. "
        "Salt had crusted the brass rail again, and the wind pushed against "
        "the glass like a patient animal. He trimmed the wick, polished the "
        "lens with a soft cloth and wrote the time in the log: `18:42`, "
        "clear to the west, a low bank of fog to the north.")
STORY = '\n\n'.join(
    ['## The keeper of Gull Point'] +
    ['%s %s' % (PARA, 'Night %d passed without a ship in distress.' % (i + 1)) for i in range(4)] +
    ['- the lamp\n- the log\n- the long wait for morning'] +
    ['%s %s' % (PARA, 'By the %dth night he knew every sound the tower made.' % (i + 5)) for i in range(4)])


def chunks(text, words=5):
    parts = text.split(' ')
    for i in range(0, len(parts), words):
        yield ' '.join(parts[i:i + words]) + (' ' if i + words < len(parts) else '')


class H(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *a):
        sys.stderr.write('%.3f %s\n' % (time.time(), a[0] % a[1:]))

    def _json(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header('content-type', 'application/json')
        self.send_header('content-length', str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path.rstrip('/').endswith('/models'):
            return self._json({'object': 'list', 'data': [{'id': 'stream', 'object': 'model'}]})
        self._json({'error': 'not found'}, 404)

    def do_POST(self):
        n = int(self.headers.get('content-length') or 0)
        body = json.loads(self.rfile.read(n) or b'{}')
        msgs = body.get('messages', [])

        def text_of(m):
            c = m.get('content')
            if isinstance(c, list):
                return ' '.join(p.get('text', '') for p in c if isinstance(p, dict))
            return c or ''
        system = ' '.join(text_of(m) for m in msgs if m.get('role') == 'system').lower()
        users = [text_of(m) for m in msgs if m.get('role') == 'user']
        last = users[-1] if users else ''
        if 'title' in system and 'generate' in system:
            reply, first, step = 'Timing run', 0, 0
        elif 'word ok' in last.lower():
            reply, first, step = 'ok', FIRST_TOKEN_MS, 0
        else:
            reply, first, step = STORY, FIRST_TOKEN_MS, CHUNK_MS
        cid = 'chatcmpl-mock-%d' % int(time.time() * 1000)
        if not body.get('stream'):
            time.sleep(first / 1000.0)
            return self._json({'id': cid, 'object': 'chat.completion', 'created': int(time.time()),
                               'model': 'stream', 'choices': [{'index': 0, 'finish_reason': 'stop',
                               'message': {'role': 'assistant', 'content': reply}}],
                               'usage': {'prompt_tokens': 10, 'completion_tokens': len(reply) // 4,
                                         'total_tokens': 10 + len(reply) // 4}})
        self.send_response(200)
        self.send_header('content-type', 'text/event-stream')
        self.send_header('cache-control', 'no-cache')
        self.send_header('connection', 'close')
        self.end_headers()

        def send(obj):
            self.wfile.write(b'data: ' + json.dumps(obj).encode() + b'\n\n')
            self.wfile.flush()
        base = {'id': cid, 'object': 'chat.completion.chunk', 'created': int(time.time()), 'model': 'stream'}
        time.sleep(first / 1000.0)
        send(dict(base, choices=[{'index': 0, 'delta': {'role': 'assistant', 'content': ''}}]))
        for c in chunks(reply):
            send(dict(base, choices=[{'index': 0, 'delta': {'content': c}}]))
            if step:
                time.sleep(step / 1000.0)
        send(dict(base, choices=[{'index': 0, 'delta': {}, 'finish_reason': 'stop'}],
                  usage={'prompt_tokens': 10, 'completion_tokens': len(reply) // 4,
                         'total_tokens': 10 + len(reply) // 4}))
        self.wfile.write(b'data: [DONE]\n\n')
        self.wfile.flush()
        self.close_connection = True


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 4199
    ThreadingHTTPServer(('127.0.0.1', port), H).serve_forever()
