#!/usr/bin/env python3
"""Isolated OC2 permission proof; uses a deterministic localhost model, no API key.

Usage: python3 tool/qa/relswitch_permission_probe.py --binary /path/to/opencode \
  --output /path/to/evidence.json
Requires OC2 2.0.29. Does not run Flutter, adb, or touch existing server data.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import Request, urlopen


def wait_for(check, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        time.sleep(0.05)
    raise AssertionError('Timed out waiting for synthetic probe condition')


def probe(binary):
    results = {'cases': []}
    with tempfile.TemporaryDirectory(prefix='relswitch-permission-') as folder:
        root = Path(folder)
        for name in ['home', 'data', 'config', 'cache', 'state', 'tmp', 'project', 'outside']:
            (root / name).mkdir()
        selected = {}

        class Provider(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                finished = any(m.get('role') == 'tool' for m in body.get('messages', []))
                if not body.get('tools') or finished:
                    delta = {'role': 'assistant', 'content': 'Synthetic probe complete.'}
                    finish = 'stop'
                else:
                    delta = {'role': 'assistant', 'tool_calls': [{
                        'index': 0, 'id': 'call_synthetic', 'type': 'function',
                        'function': {'name': selected['tool'],
                                     'arguments': json.dumps(selected['args'])}}]}
                    finish = 'tool_calls'
                self.send_response(200)
                self.send_header('Content-Type', 'text/event-stream')
                self.end_headers()
                for content, reason in [(delta, None), ({}, finish)]:
                    chunk = {'id': 'chatcmpl_synthetic', 'object': 'chat.completion.chunk',
                             'created': 1, 'model': 'proof',
                             'choices': [{'index': 0, 'delta': content, 'finish_reason': reason}]}
                    self.wfile.write(('data: ' + json.dumps(chunk) + '\n\n').encode())
                self.wfile.write(b'data: [DONE]\n\n')

        provider = ThreadingHTTPServer(('127.0.0.1', 0), Provider)
        threading.Thread(target=provider.serve_forever, daemon=True).start()
        config = root / 'config/opencode'
        config.mkdir()
        (config / 'opencode.json').write_text(json.dumps({
            'providers': {'proof': {
                'package': '@opencode/ai/providers/openai-compatible',
                'settings': {'baseURL': f'http://127.0.0.1:{provider.server_port}/v1',
                             'apiKey': 'synthetic-not-a-secret'},
                'models': {'proof': {'name': 'Proof', 'limit': {'context': 128000, 'output': 2048},
                                     'capabilities': {'tools': True}}}}},
            'agents': {'restricted': {'mode': 'primary', 'permissions': [
                {'action': 'shell', 'resource': '*', 'effect': 'deny'}]}}}))
        # Reserve an ephemeral port; the server binds after this socket closes.
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        env = {**{key: os.environ[key] for key in ['PATH', 'LANG', 'LC_ALL', 'TZ']
                  if key in os.environ}, **{key: str(root / value) for key, value in {
            'HOME': 'home', 'XDG_DATA_HOME': 'data', 'XDG_CONFIG_HOME': 'config',
            'XDG_CACHE_HOME': 'cache', 'XDG_STATE_HOME': 'state', 'TMPDIR': 'tmp'}.items()}}
        # The environment allowlist excludes inherited credentials and OPENCODE_* overrides.
        log = root / 'server.log'
        with log.open('w') as output:
            server = subprocess.Popen([str(binary), 'serve', '--hostname', '127.0.0.1',
                                       '--port', str(port)], cwd=root / 'project', env=env,
                                      stdout=output, stderr=subprocess.STDOUT)
        try:
            match = wait_for(lambda: re.search(r'server password\s*[:=]?\s*(\S+)', log.read_text()))
            auth = 'Basic ' + base64.b64encode(('opencode:' + match.group(1)).encode()).decode()

            def api(path, method='GET', body=None):
                request = Request(f'http://127.0.0.1:{port}' + path, method=method,
                                  data=None if body is None else json.dumps(body).encode(),
                                  headers={'Authorization': auth, 'Content-Type': 'application/json'})
                with urlopen(request, timeout=20) as response:
                    data = response.read()
                    return json.loads(data) if data else None

            results['version'] = api('/api/info')['version']
            assert results['version'] == '2.0.29', results['version']
            # Initialize location provider catalog before session model selection.
            wait_for(lambda: any(p['id'] == 'proof' for p in api('/api/provider')['data']))
            schema = api('/openapi.json')
            results['migration_methods'] = list(schema['paths']['/api/experimental/migration/v1'])
            results['migration_status'] = api('/api/experimental/migration/v1')
            ask = [{'action': '*', 'resource': '*', 'effect': 'ask'}]

            def synthesized(agent, original):
                info = api('/api/agent/' + agent)['data']
                assert info['id'] == agent
                return ask + [dict(rule, effect='ask') if rule['effect'] == 'allow' else rule
                              for rule in info['permissions'] + original]

            build_policy = synthesized('build', [])

            def session(rules):
                data = api('/api/session', 'POST', {
                    'title': 'Synthetic permission probe',
                    'location': {'directory': str(root / 'project')},
                    'model': {'providerID': 'proof', 'id': 'proof'}})['data']
                path = '/api/session/' + data['id']
                assert api(path, 'PATCH', {'permissions': rules}) is None
                assert api(path)['data']['permissions'] == rules
                return path

            for name, tool, location, mode in [
                ('default shell', 'shell', 'project', 'default'),
                ('asks first shell', 'shell', 'project', 'manual'),
                ('asks first project write', 'write', 'project', 'manual'),
                ('asks first outside write', 'write', 'outside', 'manual'),
                ('auto approve shell', 'shell', 'project', 'auto'),
            ]:
                target = root / location / (name.replace(' ', '-') + '.txt')
                selected.update(tool=tool, args=(
                    {'command': f"echo proof > '{target}'"} if tool == 'shell'
                    else {'path': str(target), 'content': 'proof\n'}))
                path = session([] if mode == 'default' else build_policy)
                api(path + '/prompt', 'POST', {'text': 'Run the synthetic proof tool.'})
                actions = []
                held = []
                deadline = time.monotonic() + 20
                idle = None
                while time.monotonic() < deadline:
                    pending = api(path + '/permission')['data']
                    for request in pending:
                        actions.append(request['action'])
                        held.append(not target.exists())
                        if mode == 'manual':
                            time.sleep(0.15)
                            assert not target.exists(), 'Tool ran before approval'
                        api(path + '/permission/' + request['id'] + '/reply',
                            'POST', {'decision': 'once'})
                    messages = api(path + '/message')['data']
                    idle = next((m for m in messages if m.get('type') == 'idle'), None)
                    if idle is not None:
                        break
                    time.sleep(0.05)
                assert idle is not None and idle['outcome'] == 'succeeded', 'No successful idle receipt'
                tool_part = next(part for message in messages if message.get('type') == 'assistant'
                                 for part in message.get('content', []) if part.get('type') == 'tool')
                assert tool_part['name'] == tool and tool_part['state']['status'] == 'completed'
                assert target.read_text() == 'proof\n'
                assert (not actions) if mode == 'default' else (actions and all(held))
                results['cases'].append({'name': name, 'permission_actions': actions,
                    'file_absent_until_approval': all(held) if held else None,
                    'reply': 'once' if actions else None, 'completed': True,
                    'effective_rules': [] if mode == 'default' else build_policy,
                    'tool': tool_part['name'], 'tool_status': tool_part['state']['status'],
                    'idle_outcome': idle['outcome'],
                    'approval_driver': 'scripted manual once' if mode == 'manual' else mode})

            def decision(path, agent='build'):
                return api(path + '/permission', 'POST', {
                    'action': 'shell', 'resources': ['synthetic-command'],
                    'save': ['synthetic-command'], 'agent': agent})['data']

            path = session(ask)
            unprotected = decision(path, 'restricted')
            assert unprotected['effect'] == 'ask'
            api(path + '/permission/' + unprotected['id'] + '/reply', 'POST', {'decision': 'reject'})
            protected = synthesized('restricted', [])
            api(path, 'PATCH', {'permissions': protected})
            assert decision(path, 'restricted')['effect'] == 'deny'
            # Agent swap derives a fresh policy from the original session rules.
            api(path + '/agent', 'POST', {'agent': 'build'})
            assert api(path)['data']['agent'] == 'build'
            metadata = {'oc.mobile.permissionRequests': {
                'version': 1, 'original': [], 'applied': build_policy}}
            api(path, 'PATCH', {'permissions': build_policy, 'metadata': metadata})
            readback = api(path)['data']
            assert readback['permissions'] == build_policy
            assert readback['metadata'] == metadata
            changed = decision(path, 'build')
            assert changed['effect'] == 'ask'
            api(path + '/permission/' + changed['id'] + '/reply', 'POST', {'decision': 'reject'})
            results['agent_deny'] = {'wildcard_ask_overrides_agent_deny': True,
                                     'synthesized_agent_deny_preserved': True,
                                     'agent_swap_recomputes_original_rules': True}
            results['metadata_patch_readback_verified'] = True
            api(path, 'PATCH', {'permissions': ask})
            requested = decision(path)
            assert requested['effect'] == 'ask'
            api(path + '/permission/' + requested['id'] + '/reply', 'POST', {'decision': 'always'})
            assert decision(path)['effect'] == 'allow'
            results['saved_always_grant_bypasses_session_ask'] = True
            document = json.loads((config / 'opencode.json').read_text())
            document['default_agent'] = 'restricted'
            (config / 'opencode.json').write_text(json.dumps(document))
            api('/api/location/reload', 'POST', {})
            wait_for(lambda: (rows := api('/api/agent')['data']) and rows[0]['id'] == 'restricted')
            fresh = api('/api/session', 'POST', {'title': 'Default agent selection proof',
                'location': {'directory': str(root / 'project')}})['data']
            fresh_path = '/api/session/' + fresh['id']
            fresh_read = api(fresh_path)['data']
            assert 'agent' not in fresh_read and 'permissions' not in fresh_read
            chosen = api('/api/agent')['data'][0]
            assert chosen['id'] == 'restricted' and chosen['mode'] == 'primary' and not chosen['hidden']
            effective = synthesized(chosen['id'], fresh_read.get('permissions', []))
            api(fresh_path, 'PATCH', {'permissions': effective})
            assert decision(fresh_path, chosen['id'])['effect'] == 'deny'
            results['default_agent'] = {'configured': 'restricted', 'first_agent': chosen['id'],
                'fresh_session_omits_agent_and_permissions': True,
                'synthesized_policy_preserves_default_deny': True}

            results['patch_readback_verified'] = True
        finally:
            server.terminate()  # Exact owned PID, never a process-name pattern.
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=5)
            provider.shutdown()
            provider.server_close()
            results['server_stopped_by_exact_pid'] = server.returncode is not None
    results['temporary_data_removed'] = not root.exists()
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    evidence = probe(args.binary.resolve())
    args.output.write_text(json.dumps(evidence, indent=2) + '\n')
    print(json.dumps(evidence, indent=2))


if __name__ == '__main__':
    main()
