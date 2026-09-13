# v3: next-gen layout on the app's own tokens. No fake OS chrome, SVG icons only.
HEAD = """<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600&family=JetBrains+Mono:wght@400&display=swap">
  <style>
    body { margin: 0; background: #101310; color: #e3e8e4; font-family: Roboto, system-ui, sans-serif; font-size: 15px; line-height: 1.45; }
    a { color: #83cdaa; } a:hover { color: #a6dcc0; }
    .display { font-family: 'Space Grotesk', 'Segoe UI', system-ui, sans-serif; }
    .mono { font-family: 'JetBrains Mono', 'Courier New', monospace; direction: ltr; }
  </style>
</helmet>
"""
TAIL = "</x-dc>\n</body>\n</html>\n"
BG="#101310"; SURF="#151a17"; CARD="#1c241f"; CARD2="#232d27"; ACC="#83cdaa"; ONACC="#052117"; MUTED="#9aa69f"; TEXT="#e3e8e4"; LINE="#26302a"; ERR="#ffb4ab"; WARN="#e9c46a"; OK="#86d8a5"; BLUE="#9cc4ff"
TINT_ACC="#1b2d24"; TINT_WARN="#2b2410"; TINT_ERR="#3a1f1f"; TINT_BLUE="#1c2634"

def icon(name, size=22, color=TEXT):
    p = {
        'back': '<path d="M15 5l-7 7 7 7"/>', 'more': '<circle cx="12" cy="5" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="12" cy="19" r="1.6"/>',
        'chevron': '<path d="M9 6l6 6-6 6"/>', 'check': '<path d="M5 12l5 5L20 7"/>', 'dot': '<circle cx="12" cy="12" r="4"/>',
        'ring': '<circle cx="12" cy="12" r="7"/>', 'question': '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.7.4-1 1-1 1.7M12 17v.5"/>',
        'home': '<path d="M4 11l8-7 8 7v9H4z"/>', 'files': '<path d="M4 6h6l2 2h8v10H4z"/>', 'activity': '<path d="M3 12h4l3-7 4 14 3-7h4"/>', 'grid': '<circle cx="6" cy="6" r="1.6"/><circle cx="12" cy="6" r="1.6"/><circle cx="18" cy="6" r="1.6"/><circle cx="6" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="18" cy="12" r="1.6"/>',
        'team': '<circle cx="9" cy="8" r="3"/><circle cx="16.5" cy="9.5" r="2.2"/><path d="M4 19c0-3 2.2-5 5-5s5 2 5 5"/><path d="M15 18c0-2 1.3-3.3 3-3.3s3 1.3 3 3.3"/>',
        'folder': '<path d="M3.5 6.5h6l2 2h9v9.5a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 18z"/>', 'bolt': '<path d="M13.2 2.5 5.8 13h5.6l-.6 8.5L18.2 11h-5.6z"/>',
        'monitor': '<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/>', 'bell': '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
        'moon': '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>', 'stop': '<rect x="7" y="7" width="10" height="10" rx="2"/>', 'play': '<path d="M8 5l11 7-11 7z"/>',
        'terminal': '<path d="M5 7l5 5-5 5M12 17h7"/>', 'send': '<path d="M12 19V5M5 12l7-7 7 7"/>', 'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
        'alert': '<circle cx="12" cy="12" r="9"/><path d="M12 8v5M12 16v.5"/>', 'search': '<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/>',
    }
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink: 0;">{p[name]}</svg>'

def phone(inner, h): return f'<div style="width: 390px; min-height: {h}px; background: {BG}; display: flex; flex-direction: column; box-sizing: border-box;">{inner}</div>'
def write(name, body, h): open(name,'w').write(HEAD + phone(body, h) + TAIL)

def appbar(title, right="", back=False, sub="", size=24):
    lead = f'<div style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;">{icon("back")}</div>' if back else ""
    subh = f'<div style="font-size: 13px; color: {MUTED}; margin-top: 2px;">{sub}</div>' if sub else ""
    return f'<div style="display: flex; align-items: center; gap: 8px; padding: 20px 12px 10px 16px;">{lead}<div style="flex-grow: 1; min-width: 0;"><div class="display" style="font-size: {size}px; font-weight: 600; letter-spacing: -.01em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">{title}</div>{subh}</div>{right}</div>'

def dotword(text, col):
    return f'<div style="display: inline-flex; align-items: center; gap: 7px; font-size: 13px; font-weight: 500; color: {col};"><span style="width: 8px; height: 8px; border-radius: 50%; background: {col};"></span><span>{text}</span></div>'
def pill(text, tint, col):
    return f'<div style="display: inline-flex; align-items: center; gap: 6px; height: 28px; padding: 0 11px; border-radius: 999px; background: {tint}; color: {col}; font-size: 12px; font-weight: 600; white-space: nowrap;"><span style="width: 6px; height: 6px; border-radius: 50%; background: {col};"></span>{text}</div>'
def bar(pct): return f'<div style="height: 6px; border-radius: 3px; background: {LINE}; overflow: hidden;"><div style="width: {pct}%; height: 100%; background: {ACC}; border-radius: 3px;"></div></div>'
def btn(text, kind="primary", wide=False, ic=None, h=48):
    if kind=="primary": bg,fg,border=ACC,ONACC,""
    elif kind=="warn": bg,fg,border=WARN,"#211203",""
    elif kind=="blue": bg,fg,border=BLUE,"#061326",""
    else: bg,fg,border="transparent",TEXT,"border: 1px solid #3a463f;"
    i = icon(ic,18,fg) if ic else ""
    return f'<div style="display: inline-flex; align-items: center; justify-content: center; gap: 8px; min-height: {h}px; padding: 0 20px; border-radius: {h//2}px; background: {bg}; color: {fg}; font-weight: 600; font-size: 15px; {border} {"width: 100%; box-sizing: border-box;" if wide else ""}">{i}<span>{text}</span></div>'
def mark(letter, col=ACC, tint=TINT_ACC, size=34):
    return f'<div class="mono" style="width: {size}px; height: {size}px; border-radius: 10px; background: {tint}; color: {col}; font-size: 13px; font-weight: 500; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">{letter}</div>'
def owner(letter):
    return f'<div class="mono" style="width: 26px; height: 26px; border-radius: 50%; border: 1px solid {LINE}; color: {MUTED}; font-size: 11px; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">{letter}</div>'
def card(inner, pad="18px", gap="12px", bg=CARD, border=""):
    return f'<div style="background: {bg}; border-radius: 14px; padding: {pad}; display: flex; flex-direction: column; gap: {gap}; {border}">{inner}</div>'
def section(t, right=""):
    r = f'<div style="font-size: 13px; color: {MUTED};">{right}</div>' if right else ""
    return f'<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 2px 2px 2px;"><div style="font-size: 13px; font-weight: 500; color: {MUTED};">{t}</div>{r}</div>'
def navbar(active):
    cells=""
    for k,t in [('home','Workspace'),('files','Files'),('activity','Activity'),('grid','More')]:
        on = t.lower()==active
        cells += f'<div style="display: flex; flex-direction: column; align-items: center; gap: 4px; flex: 1 1 0; padding: 10px 0;"><div style="padding: 4px 18px; border-radius: 16px; background: {"#2a3b32" if on else "transparent"};">{icon(k,22, TEXT if on else MUTED)}</div><div style="font-size: 12px; font-weight: 500; color: {TEXT if on else MUTED};">{t}</div></div>'
    return f'<div style="margin-top: auto; display: flex; padding: 6px 8px 14px 8px; background: #141a16; border-top: 1px solid {LINE};">{cells}</div>'
def segbar(active):
    cells=""
    for t in ['Work','Agents','Timeline','Details']:
        on = t==active
        cells += f'<div style="flex: 1 1 0; text-align: center; padding: 10px 0; border-radius: 999px; font-size: 14px; font-weight: 600; background: {"#2a3b32" if on else "transparent"}; color: {TEXT if on else MUTED};">{t}</div>'
    return f'<div style="margin-top: auto; display: flex; gap: 4px; padding: 8px 12px 16px 12px; background: #141a16; border-top: 1px solid {LINE};">{cells}</div>'

# ---------- 1 Workspace ----------
ws = appbar("Workspace", f'<div class="mono" style="width: 36px; height: 36px; border-radius: 50%; background: {TINT_ACC}; color: {ACC}; display: flex; align-items: center; justify-content: center; font-size: 12px;">ES</div>')
hero = f'''<div style="display: flex; align-items: center; gap: 10px;">{dotword('AI Team · Gas City', MUTED)}<div style="flex-grow: 1;"></div>{pill('1 needs you', TINT_WARN, WARN)}</div>
<div class="display" style="font-size: 34px; font-weight: 600; letter-spacing: -.02em; line-height: 1.1;">72% done.</div>
<div style="font-size: 15px; color: {MUTED};">5 agents are working. Wolf is waiting for your decision on storage.</div>
{bar(72)}
<div style="display: flex; align-items: center; gap: 12px;">{btn('Decide', 'primary', False, 'bolt')}<div style="flex-grow: 1;"></div><div style="font-size: 13px; color: {MUTED};">1 blocker · 34 min</div></div>'''
ws += f'''<div style="padding: 0 16px; display: flex; flex-direction: column; gap: 12px;">
<div style="display: flex; align-items: center; gap: 12px; padding: 12px 14px; background: {SURF}; border-radius: 14px;">{mark('', MUTED, CARD2, 38).replace('></div>', '>'+icon('folder',20,MUTED)+'</div>')}<div style="flex-grow: 1;"><div style="font-weight: 600;">opencode_mobile</div><div class="mono" style="font-size: 12px; color: {MUTED};">~/Storage/Code/oc_app</div></div><div style="color: {ACC}; font-weight: 600;">Manage</div></div>
{card(hero, "18px", "14px", TINT_ACC, f"border: 1px solid #2f4a3c;")}
{section('Recent sessions', 'See all')}
<div style="background: {SURF}; border-radius: 14px;">
<div style="display: flex; align-items: center; gap: 12px; padding: 14px 14px; border-bottom: 1px solid {LINE};">{mark('D')}<div style="flex-grow: 1; min-width: 0;"><div style="font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">Delegate multiply function in calc.py</div><div style="font-size: 13px; color: {MUTED};">Just now</div></div>{icon('chevron',18,MUTED)}</div>
<div style="display: flex; align-items: center; gap: 12px; padding: 14px 14px; border-bottom: 1px solid {LINE};">{mark('S', BLUE, TINT_BLUE)}<div style="flex-grow: 1; min-width: 0;"><div style="font-weight: 500;">Sync engine retry handling</div><div style="font-size: 13px; color: {MUTED};">10m ago</div></div>{icon('chevron',18,MUTED)}</div>
<div style="display: flex; align-items: center; gap: 12px; padding: 14px 14px;">{mark('A')}<div style="flex-grow: 1; min-width: 0;"><div style="font-weight: 500;">Android background handoff</div><div style="font-size: 13px; color: {MUTED};">Earlier · unread result</div></div>{icon('chevron',18,MUTED)}</div></div>
</div>''' + navbar('workspace')
write('Main.dc.html', ws, 844)

# ---------- 2 Run ----------
def steprow(state, title, sub="", status=""):
    if state=='done': d=f'<div style="width: 22px; height: 22px; border-radius: 50%; background: {ACC}; display: flex; align-items: center; justify-content: center;">{icon("check",14,ONACC)}</div>'
    elif state=='now': d=f'<div style="width: 22px; height: 22px; border-radius: 50%; border: 2px solid {ACC}; box-shadow: 0 0 0 4px {TINT_ACC}; box-sizing: border-box; display: flex; align-items: center; justify-content: center;"><div style="width: 6px; height: 6px; border-radius: 50%; background: {ACC};"></div></div>'
    else: d=f'<div style="width: 22px; height: 22px; border-radius: 50%; border: 2px solid #3a463f; box-sizing: border-box;"></div>'
    s = f'<div style="font-size: 13px; color: {MUTED};">{sub}</div>' if sub else ""
    col = ACC if state=='now' else MUTED
    return f'<div style="display: flex; align-items: center; gap: 14px; padding: 12px 4px;">{d}<div style="flex-grow: 1;"><div style="font-weight: {600 if state=="now" else 500}; color: {TEXT if state!="todo" else MUTED};">{title}</div>{s}</div><div style="font-size: 12px; color: {col};">{status}</div></div>'
run = appbar("Offline-first sessions", icon('more',22,MUTED), back=True, sub="Run · convoy", size=21)
run += f'''<div style="padding: 4px 16px 20px 16px; display: flex; flex-direction: column; gap: 12px;">
<div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap;">{pill('Working', TINT_ACC, OK)}<div style="height: 28px; padding: 0 11px; border-radius: 999px; border: 1px solid {LINE}; display: inline-flex; align-items: center; gap: 6px; font-size: 12px; color: {MUTED};"><b style="color: {TEXT};">34</b> min</div><div style="height: 28px; padding: 0 11px; border-radius: 999px; border: 1px solid {LINE}; display: inline-flex; align-items: center; gap: 6px; font-size: 12px; color: {MUTED};"><b style="color: {TEXT};">12</b> / 18 done</div></div>
<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px;">
<div style="background: {CARD}; border-radius: 14px; padding: 14px 16px;">{dotword('Working', OK)}<div class="display" style="font-size: 30px; font-weight: 600; margin-top: 6px;">5</div></div>
<div style="background: {CARD}; border-radius: 14px; padding: 14px 16px;">{dotword('Blocked', WARN)}<div class="display" style="font-size: 30px; font-weight: 600; margin-top: 6px;">2</div></div></div>
<div style="display: flex; align-items: center; gap: 12px; padding: 14px 16px; background: {TINT_WARN}; border-radius: 14px; border: 1px solid #4a3d1c;">{mark('W', WARN, '#3a2f12')}<div style="flex-grow: 1; min-width: 0;"><div style="font-weight: 600;">Wolf needs a decision</div><div style="font-size: 13px; color: {MUTED};">Which persistence strategy for the tests?</div></div>{btn('Decide','primary',False,None,40)}</div>
{section('Execution', 'Next: testing')}
<div style="background: {CARD}; border-radius: 14px; padding: 6px 14px;">
{steprow('done','Requirements','','done')}{steprow('done','Architecture','','done')}{steprow('done','Data model','','done')}{steprow('done','Implementation','','done')}{steprow('now','Testing','4 of 6 tasks','active')}{steprow('todo','Review and merge','','queued')}</div>
</div>''' + segbar('Work')
write('RunOverview.dc.html', run, 900)

# ---------- 3 Work ----------
def group(title, tint, col, rows):
    return f'<div style="background: {CARD}; border-radius: 14px; overflow: hidden;"><div style="height: 34px; display: flex; align-items: center; padding: 0 14px; font-size: 12px; font-weight: 600; background: {tint}; color: {col};">{title}</div>{rows}</div>'
def task(col, title, sub, own, dim=False):
    return f'<div style="display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-bottom: 1px solid {LINE};"><span style="width: 8px; height: 8px; border-radius: 50%; background: {col}; flex-shrink: 0;"></span><div style="flex-grow: 1; min-width: 0;"><div style="font-weight: 500; color: {MUTED if dim else TEXT};">{title}</div><div style="font-size: 13px; color: {MUTED};">{sub}</div></div>{owner(own)}</div>'
work = appbar("Work", icon('more',22,MUTED), sub="Offline-first sessions · 18 items")
work += f'''<div style="padding: 4px 16px 20px 16px; display: flex; flex-direction: column; gap: 10px;">
{group('Needs input · 1', TINT_WARN, WARN, task(WARN,'Database tests','Wolf is waiting for a decision','W'))}
{group('Blocked · 1', TINT_WARN, WARN, task(WARN,'Conflict resolution','Waits on Sync engine','F'))}
{group('Working · 3', TINT_ACC, OK, task(OK,'Sync engine','Building retry logic','F')+task(OK,'Android integration','Implementing notifications','B')+task(OK,'Background sync','Optimising battery usage','R'))}
{group('Ready · 2', TINT_BLUE, BLUE, task(BLUE,'Unit tests','Ready to run','—')+task(BLUE,'Integration tests','Ready to run','—'))}
{group('Done · 12', CARD2, MUTED, task(MUTED,'Requirements','Completed','M',True)+task(MUTED,'Architecture','Completed','M',True)+task(MUTED,'Database','Completed','C',True))}
</div>''' + segbar('Work')
write('WorkList.dc.html', work, 1000)

# ---------- 4 Agent ----------
def ev(title, sub, last=False):
    d = f'<div style="width: 14px; height: 14px; border-radius: 50%; border: 2px solid {WARN if last else "#3a463f"}; box-sizing: border-box; margin-top: 3px; {"box-shadow: 0 0 0 4px "+TINT_WARN+";" if last else ""}"></div>'
    return f'<div style="display: flex; gap: 12px; padding: 8px 0;">{d}<div><div style="font-weight: 500;">{title}</div><div style="font-size: 13px; color: {MUTED};">{sub}</div></div></div>'
def opt(title, sub, sel=False):
    inner = f'<div style="width: 8px; height: 8px; border-radius: 50%; background: {ACC};"></div>' if sel else ''
    r = f'<div style="width: 18px; height: 18px; border-radius: 50%; border: 2px solid {ACC if sel else MUTED}; box-sizing: border-box; display: flex; align-items: center; justify-content: center; flex-shrink: 0; margin-top: 2px;">{inner}</div>'
    box = f'border: 1px solid #2f4a3c;' if sel else ''
    return f'<div style="display: flex; gap: 12px; padding: 12px 14px; border-radius: 12px; background: {TINT_ACC if sel else CARD2}; {box}">{r}<div><div style="font-weight: 600;">{title}</div><div style="font-size: 13px; color: {MUTED};">{sub}</div></div></div>'
ag = appbar("Wolf", icon('more',22,MUTED), back=True, sub="Agent · polecat · Codex · gpt-5.6-terra", size=22)
ag += f'''<div style="padding: 4px 16px 0 16px; display: flex; flex-direction: column; gap: 12px;">
<div style="display: flex; gap: 14px; align-items: center;">{mark('W', ACC, TINT_ACC, 60)}<div style="flex-grow: 1;">{pill('Waiting for you', TINT_WARN, WARN)}<div style="font-weight: 600; margin-top: 8px;">Database tests</div><div style="font-size: 13px; color: {MUTED};">Ready to proceed once you choose the persistence target.</div><div style="display: flex; align-items: center; gap: 8px; margin-top: 8px; font-size: 12px; color: {MUTED};">Context 79%<div style="width: 90px; height: 4px; border-radius: 2px; background: {LINE}; overflow: hidden;"><div style="width: 79%; height: 100%; background: {ACC};"></div></div></div></div></div>
{card(ev('Read the migration plan and existing tests','2 files · 41m ago')+ev('Ran the migration test suite','18 passed, 2 failed · 12m ago')+ev('Asked which persistence strategy the tests should target','4m ago', True), "6px 16px", "0")}
{card(f'<div class="display" style="font-size: 18px; font-weight: 600;">Which persistence strategy?</div><div style="font-size: 13px; color: {MUTED};">This choice controls how the tests store and verify data.</div>'+opt('SQLite','Lightweight, fast, recommended',True)+opt('Filesystem','Simple, no external dependencies')+opt('Server-only','Matches production, more complex'), "16px", "8px")}
</div>
<div style="margin-top: auto; display: flex; gap: 8px; padding: 12px 16px 16px 16px; background: #141a16; border-top: 1px solid {LINE};"><div style="flex-grow: 1; min-height: 48px; border-radius: 24px; border: 1px solid #3a463f; display: flex; align-items: center; padding: 0 16px; color: {MUTED}; font-size: 14px;">Add a note (optional)</div>{btn('Send answer','primary',False,'send')}</div>'''
write('Agent.dc.html', ag, 1000)

# ---------- 5 Activity ----------
def feed(letter, col, tint, title, sub, action, kind):
    return f'<div style="display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-bottom: 1px solid {LINE};">{mark(letter, col, tint)}<div style="flex-grow: 1; min-width: 0;"><div style="font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">{title}</div><div style="font-size: 13px; color: {MUTED}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">{sub}</div></div>{btn(action, kind, False, None, 40)}</div>'
act = appbar("Activity", "")
act += f'''<div style="padding: 0 16px; display: flex; flex-direction: column; gap: 12px;">
<div style="display: flex; gap: 8px;">{pill('Needs you · 3', TINT_ACC, ACC)}<div style="height: 28px; padding: 0 12px; border-radius: 999px; border: 1px solid {LINE}; display: inline-flex; align-items: center; font-size: 12px; font-weight: 600; color: {MUTED};">All activity</div></div>
<div style="background: {CARD}; border-radius: 14px; overflow: hidden;">
{feed('W', WARN, '#3a2f12', 'Storage strategy', 'Wolf · Offline-first sessions · 2m ago', 'Decide', 'warn')}
{feed('N', ERR, TINT_ERR, 'Run failed: 2 tests failing', 'Nova · Android notification redesign · 18m ago', 'Retry', 'ghost')}
{feed('F', BLUE, TINT_BLUE, 'Sync engine ready for review', 'Fox · Offline-first sessions · 1h ago', 'Review', 'blue').replace(f'border-bottom: 1px solid {LINE};','')}
</div>
{section('Earlier today', 'See all')}
<div style="background: {SURF}; border-radius: 14px; padding: 6px 14px;">
<div style="display: flex; align-items: center; gap: 12px; padding: 10px 0;">{icon('check',18,OK)}<div style="flex-grow: 1; color: {MUTED};">Bear finished Android integration</div><div style="font-size: 12px; color: {MUTED};">10:47</div></div>
<div style="display: flex; align-items: center; gap: 12px; padding: 10px 0;">{icon('check',18,OK)}<div style="flex-grow: 1; color: {MUTED};">Test suite passed 182/182</div><div style="font-size: 12px; color: {MUTED};">10:46</div></div>
<div style="display: flex; align-items: center; gap: 12px; padding: 10px 0;">{icon('play',18,MUTED)}<div style="flex-grow: 1; color: {MUTED};">Codex started database tests</div><div style="font-size: 12px; color: {MUTED};">10:41</div></div></div>
</div>''' + navbar('activity')
write('NeedsYou.dc.html', act, 844)

# ---------- 6 Phone setup ----------
ph = appbar("Termux setup", "", back=True)
ph += f'''<div style="padding: 8px 16px 20px 16px; display: flex; flex-direction: column; gap: 14px;">
<div style="display: flex; flex-direction: column; align-items: center; gap: 12px; padding: 12px 0 4px 0;"><div style="width: 76px; height: 76px; border-radius: 24px; background: {TINT_ACC}; border: 1px solid #2f4a3c; display: flex; align-items: center; justify-content: center;">{icon('terminal',32,ACC)}</div><div class="display" style="font-size: 22px; font-weight: 600;">OpenCode is ready</div><div style="font-size: 14px; color: {MUTED};">Connected on this phone.</div></div>
{btn('Open Workspace','primary',True)}
{card(f'<div>{pill("Optional · experimental", CARD2, MUTED)}</div><div class="display" style="font-size: 19px; font-weight: 600; line-height: 1.25;">Run an AI team on this phone?</div><div style="font-size: 14px; color: {MUTED};">Several agents can work on the project while you supervise. It is slower than a computer, Android may pause it when the screen is off, and it needs about 60 MB.</div><div style="display: flex; gap: 8px;"><div style="flex: 1 1 0;">{btn("Not now","ghost",True)}</div><div style="flex: 1 1 0;">{btn("Set up","primary",True)}</div></div>', "18px", "12px", TINT_ACC, "border: 1px solid #2f4a3c;")}
</div>'''
write('PhoneSetup.dc.html', ph, 844)

# ---------- 7 Settings ----------
def sw(on): return f'<div style="width: 46px; height: 26px; border-radius: 13px; background: {ACC if on else "#3a463f"}; position: relative; flex-shrink: 0;"><div style="position: absolute; top: 3px; {"right: 3px" if on else "left: 3px"}; width: 20px; height: 20px; border-radius: 50%; background: {ONACC if on else MUTED};"></div></div>'
def srow(ic, t, s, right, last=False):
    return f'<div style="display: flex; align-items: center; gap: 12px; padding: 14px 16px; {"" if last else "border-bottom: 1px solid "+LINE+";"}">{icon(ic,20,MUTED)}<div style="flex-grow: 1;"><div style="font-weight: 500;">{t}</div><div style="font-size: 13px; color: {MUTED};">{s}</div></div>{right}</div>'
st = appbar("AI Team · Gas City", icon('more',22,MUTED), sub="Development PC · 1.4.1", size=21)
st += f'''<div style="padding: 4px 16px 20px 16px; display: flex; flex-direction: column; gap: 12px;">
<div style="display: flex; align-items: center; gap: 12px; padding: 14px 16px; background: {CARD}; border-radius: 14px;">{mark('', ACC, TINT_ACC, 42).replace('></div>', '>'+icon('monitor',22,ACC)+'</div>')}<div style="flex-grow: 1;"><div style="font-weight: 600;">Development PC</div><div style="font-size: 13px; color: {MUTED};">Secure tailnet link · healthy</div></div>{pill('Connected', TINT_ACC, OK)}</div>
<div style="display: flex; align-items: center; gap: 10px; padding: 12px 16px; background: {TINT_ACC}; border: 1px solid #2f4a3c; border-radius: 14px;"><span style="width: 10px; height: 10px; border-radius: 50%; background: {ACC};"></span><span style="font-weight: 600; color: {ACC};">On</span><span style="margin-left: auto; font-size: 13px; color: {MUTED};">Watching and answering from this phone</span></div>
{section('Notifications')}
<div style="background: {CARD}; border-radius: 14px;">{srow('bell','Notify me','Decisions, failures, reviews, completions', sw(True))}{srow('moon','Keep the computer awake','The team runs as fast as your computer', sw(True), True)}</div>
{section('On this phone', 'Experimental')}
<div style="display: flex; align-items: center; gap: 12px; padding: 14px 16px; background: {CARD}; border-radius: 14px;">{mark('', MUTED, CARD2).replace('></div>', '>'+icon('stop',18,MUTED)+'</div>')}<div style="flex-grow: 1;"><div style="font-weight: 500;">Stopped</div><div style="font-size: 13px; color: {MUTED};">Not running on this phone.</div></div>{btn('Start','ghost',False,None,40)}</div>
<div style="display: flex; align-items: center; justify-content: center; min-height: 48px; border-radius: 24px; background: {TINT_ERR}; color: {ERR}; font-weight: 600;">Turn off for this server</div>
</div>'''
write('Settings.dc.html', st, 900)

import json
boards=[('Main.dc.html',844,'01 Workspace'),('RunOverview.dc.html',900,'02 Run'),('WorkList.dc.html',1000,'03 Work'),('Agent.dc.html',1000,'04 Agent · decision'),('NeedsYou.dc.html',844,'05 Activity · Needs you'),('PhoneSetup.dc.html',844,'06 Termux · optional step'),('Settings.dc.html',900,'07 Settings')]
arts=[]; x=0; y=0
for i,(f,h,t) in enumerate(boards):
    if i==4: x=0; y=1180
    arts.append({"file":f,"x":x,"y":y,"w":390,"h":h,"title":t}); x+=470
canvas={"artboards":arts,"annotations":[{"id":"note-v3","x":0,"y":-150,"w":470,"text":"v3 — next-gen layout on the app's own tokens.\nKept: hero number + sentence + one action; Working/Blocked pair; decision card; vertical steps with 'Next: testing'; tinted work groups; agent step log + pinned answer bar with optional note; one action per Activity row.\nDropped: fake OS chrome, glows, Mentions tab, fallback-worker card, emoji glyphs. Blocked is amber (red = failed only). Type ≥ 13px."}],"launch":{"view":"canvas"}}
json.dump(canvas,open('canvas.json','w'),indent=1); print('ok')
