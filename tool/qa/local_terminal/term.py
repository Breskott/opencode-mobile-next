#!/usr/bin/env python3
"""term.py DEVICE STEP...  -- drives the local terminal for its device proof
(docs/qa/local-terminal-2026-09-24/README.md).

Steps:
  type:TEXT        type TEXT into the focused terminal (adb input text; the
                   device shell never expands it)
  enter            the Enter key
  key:NAME         an Android key event (DEL, TAB, DPAD_UP, ESCAPE...)
  tap:X,Y          a tap at screen pixels
  wait:SECONDS     pause
  shot:NAME        screenshot, the terminal kept readable and small, saved
                   as OUT/NAME.png (OUT is $OUT or the record's folder)
  gfx:reset        dumpsys gfxinfo PKG reset
  gfx:NAME         dumpsys gfxinfo PKG saved as OUT/NAME.txt
  sf:NAME          SurfaceFlinger frame latency of the app's surface, saved
                   as OUT/NAME.txt with a summary line
  procs:NAME       every process of the app's user, saved as OUT/NAME.txt
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
OUT = os.environ.get('OUT', os.path.join(ROOT, 'docs', 'qa', 'local-terminal-2026-09-24'))
ADB = os.environ.get('ADB', os.path.expanduser('~/Android/Sdk/platform-tools/adb'))
PKG = 'io.github.eslamasabry.opencode_mobile'


def adb(dev, *args, text=True):
    return subprocess.run([ADB, '-s', dev, *args], capture_output=True, text=text)


def device_quote(value):
    """One argument for the device's shell, never expanded there."""
    return "'" + value.replace("'", "'\\''") + "'"


def type_text(dev, value):
    # `input text` reads %s as a space; a literal % is sent as \%.
    arg = value.replace('%', '\\%').replace(' ', '%s')
    adb(dev, 'shell', 'input text ' + device_quote(arg))


def shot(dev, name):
    raw = adb(dev, 'exec-out', 'screencap', '-p', text=False).stdout
    path = os.path.join(OUT, name + '.png')
    try:
        from PIL import Image
        import io
        image = Image.open(io.BytesIO(raw))
        image = image.resize((image.width // 2, image.height // 2), Image.LANCZOS)
        image = image.convert('P', palette=Image.ADAPTIVE, colors=64)
        image.save(path, optimize=True)
    except ImportError:
        with open(path, 'wb') as out:
            out.write(raw)
    print('saved', path)


def procs(dev, name):
    out = adb(dev, 'shell', 'ps -A -o PID,PPID,USER,RSS,NAME,ARGS').stdout
    rows = [line.split(None, 5) for line in out.splitlines()[1:]]
    user = next((r[2] for r in rows if len(r) > 4 and r[4] == PKG), None)
    mine = [r for r in rows if user and r[2] == user]
    body = '\n'.join(
        '%6s %6s %-10s %8s %-24s %s' % (r[0], r[1], r[2], r[3], r[4], (r[5] if len(r) > 5 else '')[:150])
        for r in mine)
    summary = '%d processes of %s (the app itself included)' % (len(mine), user)
    with open(os.path.join(OUT, name + '.txt'), 'w') as f:
        f.write(summary + '\n   PID   PPID USER            RSS NAME                     ARGS (cut at 150)\n' + body + '\n')
    print(summary)
    print(body)


def surface_latency(dev, name):
    layers = adb(dev, 'shell', 'dumpsys SurfaceFlinger --list').stdout.splitlines()
    candidates = [l for l in layers if PKG in l and ('SurfaceView' in l or 'MainActivity' in l)]
    report = []
    for layer in candidates:
        out = adb(dev, 'shell', 'dumpsys SurfaceFlinger --latency ' + device_quote(layer)).stdout
        rows = [list(map(int, l.split())) for l in out.splitlines()[1:] if len(l.split()) == 3]
        rows = [r for r in rows if r[1] not in (0, 9223372036854775807)]
        present = [r[1] for r in rows]
        gaps = [(b - a) / 1e6 for a, b in zip(present, present[1:])]
        if gaps:
            gaps_sorted = sorted(gaps)
            p = lambda q: gaps_sorted[min(len(gaps_sorted) - 1, int(q * len(gaps_sorted)))]
            report.append('%s: %d frames, frame gap ms p50 %.1f p90 %.1f p99 %.1f max %.1f, >33ms %d' % (
                layer, len(present), p(.5), p(.9), p(.99), max(gaps), sum(1 for g in gaps if g > 33.4)))
        else:
            report.append('%s: no frames' % layer)
    with open(os.path.join(OUT, name + '.txt'), 'w') as f:
        f.write('\n'.join(report) + '\n')
    print('\n'.join(report))


def main():
    dev = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for step in sys.argv[2:]:
        if step.startswith('type:'):
            type_text(dev, step[5:])
        elif step == 'enter':
            adb(dev, 'shell', 'input keyevent ENTER')
        elif step.startswith('key:'):
            adb(dev, 'shell', 'input keyevent ' + step[4:])
        elif step.startswith('tap:'):
            x, y = step[4:].split(',')
            adb(dev, 'shell', 'input tap %s %s' % (x, y))
        elif step.startswith('wait:'):
            time.sleep(float(step[5:]))
        elif step.startswith('shot:'):
            shot(dev, step[5:])
        elif step == 'gfx:reset':
            adb(dev, 'shell', 'dumpsys gfxinfo ' + PKG + ' reset')
        elif step.startswith('gfx:'):
            out = adb(dev, 'shell', 'dumpsys gfxinfo ' + PKG).stdout
            with open(os.path.join(OUT, step[4:] + '.txt'), 'w') as f:
                f.write(out)
            for line in out.splitlines():
                if re.match(r'\s*(Total frames rendered|Janky frames|\d+th percentile|Number )', line):
                    print(line.strip())
        elif step.startswith('sf:'):
            surface_latency(dev, step[3:])
        elif step.startswith('procs:'):
            procs(dev, step[6:])
        else:
            raise SystemExit('unknown step: ' + step)
        time.sleep(0.3)


if __name__ == '__main__':
    main()
