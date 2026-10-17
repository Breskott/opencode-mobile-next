#!/usr/bin/env python3
"""Deterministic OpenAI-compatible model for the notification proof.
keywords in the last user message:  plan -> todowrite then slow text;
slow -> slow text; run -> bash tool call (needs approval); anything else -> quick text."""
import json, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SLOW = ' '.join(['The lighthouse keeper counted the steps and trimmed the wick again.'] * 14)
TODOS = [{'id': '1', 'content': 'Read the spec', 'status': 'completed', 'priority': 'high'},
         {'id': '2', 'content': 'Write the model', 'status': 'completed', 'priority': 'high'},
         {'id': '3', 'content': 'Wire the controller', 'status': 'completed', 'priority': 'high'},
         {'id': '4', 'content': 'Add the tests', 'status': 'completed', 'priority': 'medium'},
         {'id': '5', 'content': 'Update the docs', 'status': 'completed', 'priority': 'low'},
         {'id': '6', 'content': 'Running the tests', 'status': 'in_progress', 'priority': 'high'}]

def text_of(m):
    c = m.get('content')
    if isinstance(c, list):
        return ' '.join(p.get('text', '') for p in c if isinstance(p, dict))
    return c or ''

class H(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *a): pass
    def _json(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header('content-type', 'application/json')
        self.send_header('content-length', str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path.rstrip('/').endswith('/models'):
            return self._json({'object': 'list', 'data': [{'id': 'stream', 'object': 'model'}]})
        self._json({'error': 'not found'}, 404)
    def do_POST(self):
        n = int(self.headers.get('content-length') or 0)
        body = json.loads(self.rfile.read(n) or b'{}')
        msgs = body.get('messages', [])
        system = ' '.join(text_of(m) for m in msgs if m.get('role') == 'system').lower()
        users = [text_of(m) for m in msgs if m.get('role') == 'user']
        last = (users[-1] if users else '').strip()
        tool_names = [tc['function']['name'] for m in msgs if m.get('role') == 'assistant'
                      for tc in (m.get('tool_calls') or [])]
        after_tool = bool(msgs) and msgs[-1].get('role') == 'tool'
        call = None
        if 'title' in system and 'generate' in system:
            reply, step = last[:28] or 'Chat', 0
        elif after_tool:
            reply, step = ('Done. Dark theme added to Settings.' if 'bash' in tool_names else SLOW), \
                          (0 if 'bash' in tool_names else 0.9)
        elif 'plan' in last.lower():
            reply, step, call = '', 0, ('todowrite', {'todos': TODOS})
        elif 'run' in last.lower():
            reply, step, call = '', 0, ('bash', {'command': 'npm run build', 'description': 'Build the app'})
        elif 'slow' in last.lower():
            reply, step = SLOW, 0.9
        else:
            reply, step = 'All 6 tasks done, tests pass.', 0
        cid = 'chatcmpl-mock-%d' % int(time.time() * 1000)
        if not body.get('stream'):
            return self._json({'id': cid, 'object': 'chat.completion', 'created': int(time.time()), 'model': 'stream',
                               'choices': [{'index': 0, 'finish_reason': 'stop', 'message': {'role': 'assistant', 'content': reply}}],
                               'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'total_tokens': 15}})
        self.send_response(200); self.send_header('content-type', 'text/event-stream')
        self.send_header('cache-control', 'no-cache'); self.send_header('connection', 'close'); self.end_headers()
        def send(o):
            self.wfile.write(b'data: ' + json.dumps(o).encode() + b'\n\n'); self.wfile.flush()
        base = {'id': cid, 'object': 'chat.completion.chunk', 'created': int(time.time()), 'model': 'stream'}
        send(dict(base, choices=[{'index': 0, 'delta': {'role': 'assistant', 'content': ''}}]))
        if call:
            send(dict(base, choices=[{'index': 0, 'delta': {'tool_calls': [{'index': 0, 'id': 'call_%d' % int(time.time()), 'type': 'function',
                      'function': {'name': call[0], 'arguments': json.dumps(call[1])}}]}}]))
            send(dict(base, choices=[{'index': 0, 'delta': {}, 'finish_reason': 'tool_calls'}],
                      usage={'prompt_tokens': 10, 'completion_tokens': 5, 'total_tokens': 15}))
        else:
            words = reply.split(' ')
            for i in range(0, len(words), 4):
                send(dict(base, choices=[{'index': 0, 'delta': {'content': ' '.join(words[i:i + 4]) + ' '}}]))
                if step: time.sleep(step)
            send(dict(base, choices=[{'index': 0, 'delta': {}, 'finish_reason': 'stop'}],
                      usage={'prompt_tokens': 10, 'completion_tokens': 5, 'total_tokens': 15}))
        self.wfile.write(b'data: [DONE]\n\n'); self.wfile.flush(); self.close_connection = True

if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
