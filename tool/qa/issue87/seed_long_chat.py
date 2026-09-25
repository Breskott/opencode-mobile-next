#!/usr/bin/env python3
"""seed_long_chat.py PROJECT_DIR [TURNS] [PROVIDER/MODEL]

Makes the "Long chat for scrolling" conversation the gfx-scroll scenario
scrolls: TURNS (default 8) questions, each answered by the model with ~400
words of markdown (headings, a list, a code block), through an OpenCode 1
server on http://127.0.0.1:4096 (BASE env to change). Issue #87 proof.

The baseline used opencode/nemotron-3.5-lightning-free and stopped after 8
answered turns (~30,000 characters of replies; one more turn was aborted).
A free model can take 20-220 s per turn, so run it in the background.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

BASE = os.environ.get('BASE', 'http://127.0.0.1:4096')
D = sys.argv[1]
TURNS = int(sys.argv[2]) if len(sys.argv) > 2 else 8
PROVIDER, MODEL = (sys.argv[3] if len(sys.argv) > 3 else 'opencode/nemotron-3.5-lightning-free').split('/', 1)
TOPICS = ['git rebase vs merge', 'how HTTP caching works', 'Python generators', 'SQL indexes',
          'TCP handshakes', 'Linux file permissions', 'unit vs integration tests',
          'regular expressions', 'Docker layers', 'REST API versioning', 'memory leaks in Dart',
          'binary search', 'Unicode and UTF-8', 'CI pipelines', 'code review etiquette']


def req(method, path, body=None, timeout=600):
    url = BASE + path + ('&' if '?' in path else '?') + 'directory=' + urllib.parse.quote(D)
    r = urllib.request.Request(url, method=method,
                               data=json.dumps(body).encode() if body is not None else None,
                               headers={'content-type': 'application/json'})
    return json.load(urllib.request.urlopen(r, timeout=timeout))


s = req('POST', '/session', {'title': 'Long chat for scrolling'})
print('session', s['id'], flush=True)
for i, t in enumerate(TOPICS[:TURNS]):
    t0 = time.time()
    try:
        r = req('POST', '/session/%s/message' % s['id'], {
            'model': {'providerID': PROVIDER, 'modelID': MODEL},
            'parts': [{'type': 'text', 'text': 'Without using any tools, explain %s in about 400 words '
                       'of markdown with headings, a bullet list and one short code block.' % t}]})
        n = sum(len(p.get('text', '')) for p in r.get('parts', []))
        print(i, t, '%.1fs' % (time.time() - t0), n, 'chars', flush=True)
    except Exception as e:  # keep going; a free model sometimes errors
        print(i, t, 'ERR', e, flush=True)
