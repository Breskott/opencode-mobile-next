import os,pathlib,json,subprocess,socket,secrets,time,urllib.request,urllib.error,base64,sqlite3,signal,re
root=pathlib.Path('/tmp/oc2-pinned18600-check')
results=[]
for mode in ['explicit-db','default-db']:
 d=root/mode
 for name in ['home','data','cache','state','config','tmp','project','override-config','database']:
  (d/name).mkdir(parents=True,exist_ok=True)
 # Deliberately constructed process environment: no caller environment, config or auth.
 env={'PATH':'/usr/bin:/bin','HOME':str(d/'home'),'XDG_DATA_HOME':str(d/'data'),'XDG_CACHE_HOME':str(d/'cache'),'XDG_CONFIG_HOME':str(d/'config'),'XDG_STATE_HOME':str(d/'state'),'TMPDIR':str(d/'tmp'),'OPENCODE_CONFIG_DIR':str(d/'override-config'),'NO_COLOR':'1','TERM':'dumb'}
 if mode=='explicit-db':env['OPENCODE_DB']=str(d/'database'/'isolated.db')
 v=subprocess.run([str(root/'opencode2'),'--version'],env=env,cwd=d/'project',capture_output=True,text=True,timeout=25)
 assert v.returncode==0,(v.returncode,'version command failed')
 version=v.stdout.strip();assert re.fullmatch(r'(opencode2 v)?0\.0\.0-beta-18600',version), 'unexpected version format'
 with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
 password=secrets.token_urlsafe(32);env['OPENCODE_PASSWORD']=password
 p=subprocess.Popen([str(root/'opencode2'),'serve','--hostname','127.0.0.1','--port',str(port)],env=env,cwd=d/'project',stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
 (d/'pid').write_text(str(p.pid))
 status={'mode':mode,'version':version,'pid':p.pid,'port':port,'environment':'constructed from allowlist; child-only HOME; four XDG roots + TMPDIR + OPENCODE_CONFIG_DIR; no inherited provider/auth config','health':None}
 def request(auth):
  q=urllib.request.Request(f'http://127.0.0.1:{port}/api/health')
  if auth:q.add_header('Authorization','Basic '+base64.b64encode(('opencode:'+password).encode()).decode())
  try:
   with urllib.request.urlopen(q,timeout=2) as r:return r.status,r.read().decode()
  except urllib.error.HTTPError as e:return e.code,e.read().decode()
 try:
  until=time.monotonic()+60
  while time.monotonic()<until:
   if p.poll() is not None:raise RuntimeError('server exited before health')
   try:
    code,body=request(True)
    if code==200:
     parsed=json.loads(body);status['health']={'status':code,'version':parsed.get('version'),'healthy':parsed.get('healthy'),'applicationStatus':parsed.get('status')};break
   except (OSError,urllib.error.URLError):pass
   time.sleep(.35)
  if status['health'] is None:raise RuntimeError('authenticated health not ready within 60 seconds')
  status['unauthenticatedHealthStatus']=request(False)[0]
  assert status['unauthenticatedHealthStatus']==401
  assert status['health']['version']=='0.0.0-beta-18600'
  expected=(d/'database'/'isolated.db') if mode=='explicit-db' else (d/'data'/'opencode'/'opencode.db')
  status['expectedDatabase']=str(expected)
  status['databaseExists']=expected.is_file();assert expected.is_file()
  status['databaseFiles']=[str(x.relative_to(d)) for x in d.rglob('*.db')]
  if mode=='explicit-db':assert not (d/'data'/'opencode'/'opencode.db').exists()
  status['createdRoots']={x:(d/x).exists() and any((d/x).iterdir()) for x in ['home','data','cache','state','config','tmp','override-config']}
  with sqlite3.connect('file:'+str(expected)+'?mode=ro',uri=True) as db:
   status['databaseTableNames']=[row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
  status['result']='passed'
 except Exception as e:status['result']='failed';status['error']=str(e)
 finally:
  p.terminate()
  try:out,err=p.communicate(timeout=12)
  except subprocess.TimeoutExpired:p.kill();out,err=p.communicate(timeout=8)
  status['stopped']=p.poll() is not None
  status['suppliedPasswordAppearedInStdout']=password in out
  status['suppliedPasswordAppearedInStderr']=password in err
  status['passwordLinePrinted']=bool(re.search(r'server password',out,re.I))
  # Only allowlisted startup messages retained. All other raw stdout/stderr discarded.
  status['stdoutLineKinds']=['server listening' if 'server listening' in line else 'server password (value suppressed)' if 'server password' in line else 'other (suppressed)' for line in out.splitlines()]
  status['stderrLineCount']=len(err.splitlines())
  (d/'pid').unlink()
  results.append(status)
  (root/'results.json').write_text(json.dumps(results,indent=2))
  print(json.dumps({k:status.get(k) for k in ['mode','result','version','health','unauthenticatedHealthStatus','databaseFiles','createdRoots','suppliedPasswordAppearedInStdout','suppliedPasswordAppearedInStderr','passwordLinePrinted','stopped','error']}),flush=True)
 if status['result']!='passed':break
