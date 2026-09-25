#!/usr/bin/env python3
"""sse_log.py BASE_URL OUT.tsv [DIRECTORY]

Logs every OpenCode 1 `/event` server-sent event with the PC's clock
(epoch seconds), its type and, for message parts, the part type and text
length, so "send → first token" can be split into the server's share and the
app's share. Text itself is never written (only lengths). Stop it with
SIGTERM / SIGINT (by its PID). Used by the issue #87 proof.

OpenCode 1's /event only carries the events of one project instance (the
server's working folder unless DIRECTORY is given), so pass the folder of
the project the conversation is in.

Columns: host_time, type, kind (part type | delta | info), message id,
text length (or role for `info`), session id.
"""
import json
import sys
import time
import urllib.parse
import urllib.request


def main():
    base, out = sys.argv[1], sys.argv[2]
    url = base.rstrip('/') + '/event'
    if len(sys.argv) > 3:
        url += '?directory=' + urllib.parse.quote(sys.argv[3])
    with open(out, 'a', buffering=1) as fh:
        resp = urllib.request.urlopen(url, timeout=3600)
        for raw in resp:
            line = raw.decode('utf-8', 'replace').strip()
            if not line.startswith('data:'):
                continue
            t = time.time()
            try:
                ev = json.loads(line[5:])
            except ValueError:
                continue
            typ = ev.get('type', '?')
            props = ev.get('properties', {}) or {}
            part = props.get('part') or {}
            info = props.get('info') or {}
            sid = props.get('sessionID') or part.get('sessionID') or info.get('sessionID') or ''
            extra = ''
            if part:
                extra = '%s\t%s\t%d' % (part.get('type', ''), part.get('messageID', ''),
                                        len(part.get('text', '') or ''))
            elif 'delta' in props:
                extra = 'delta\t%s\t%d' % (props.get('messageID', ''), len(props.get('delta') or ''))
            elif info:
                extra = 'info\t%s\t%s' % (info.get('id', ''), info.get('role', ''))
            extra = '\t'.join((extra.split('\t') + ['', '', ''])[:3])
            fh.write('%.3f\t%s\t%s\t%s\n' % (t, typ, extra, sid))


if __name__ == '__main__':
    main()
