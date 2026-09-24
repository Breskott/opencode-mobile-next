#!/usr/bin/env python3
"""procwatch.py -- the app's processes over time, with a per-process record.

  procwatch.py sample DEVICE SECONDS INTERVAL OUT.log
      Every INTERVAL seconds for SECONDS, append one block to OUT.log:
        @ HH:MM:SS total=N children=M
        PID PPID ELAPSED ARGS            (one line per process of the app's uid)
      `total` includes the app's own process (the number Run 2 reported);
      `children` leaves it out (what Android's phantom-process limit counts).
      Run it detached (setsid nohup ... &); it stops by itself.

  procwatch.py summary OUT.log [TOP]
      min / median / max of `total`, the samples at or over 29, and the
      process breakdown (by command, then every row) of the TOP highest
      samples (default 1).

  procwatch.py kills DEVICE
      Android's phantom-process kills and SIGSYS lines in logcat.

procs.py prints only counts; this keeps every row so a peak can be explained.
"""
import os
import re
import statistics
import subprocess
import sys
import time
from collections import Counter

ADB = os.environ.get('ADB', os.path.expanduser('~/Android/Sdk/platform-tools/adb'))
PKG = 'io.github.eslamasabry.opencode_mobile'


def rows(dev):
    out = subprocess.run(
        [ADB, '-s', dev, 'shell', 'ps', '-A', '-o', 'PID,PPID,USER,ETIME,ARGS'],
        capture_output=True, text=True, timeout=30).stdout.splitlines()
    parsed = [line.split(None, 4) for line in out[1:] if line.strip()]
    parsed = [r for r in parsed if len(r) == 5]
    main = [r for r in parsed if r[4].strip() == PKG]
    if not main:
        return None, []
    user = main[0][2]
    return main[0][0], [r for r in parsed if r[2] == user]


def sample(dev, seconds, interval, path):
    end = time.time() + seconds
    with open(path, 'a') as log:
        while time.time() < end:
            started = time.time()
            stamp = time.strftime('%H:%M:%S')
            try:
                app, mine = rows(dev)
            except Exception as error:  # adb hiccup: note it, keep going
                log.write(f'@ {stamp} error={error!r}\n')
                log.flush()
                time.sleep(interval)
                continue
            if app is None:
                log.write(f'@ {stamp} app-not-running\n')
            else:
                log.write(f'@ {stamp} total={len(mine)} children={len(mine) - 1}\n')
                for pid, ppid, _user, etime, args in mine:
                    log.write(f'{pid} {ppid} {etime} {args[:200]}\n')
            log.flush()
            time.sleep(max(0.0, interval - (time.time() - started)))


def blocks(path):
    current = None
    with open(path) as log:
        for line in log:
            line = line.rstrip('\n')
            if line.startswith('@ '):
                if current:
                    yield current
                m = re.match(r'@ (\S+) total=(\d+)', line)
                current = {'time': line.split()[1], 'total': int(m.group(2)) if m else None,
                           'rows': []}
            elif current is not None and line:
                current['rows'].append(line)
    if current:
        yield current


def command(row):
    args = row.split(None, 3)[3] if len(row.split(None, 3)) == 4 else row
    words = args.split()
    first = words[0].split('/')[-1] if words else '?'
    if first in ('sh', 'bash') and len(words) > 1:
        rest = ' '.join(words[1:])
        script = re.search(r'([\w.-]+\.sh)', rest)
        if script:
            return f'{first} {script.group(1)}'
        return f'{first} {rest[:40]}'
    if first in ('gc', 'git', 'opencode', 'bd') and len(words) > 1:
        return f'{first} {words[1]}'
    return first


def summary(path, top):
    samples = [b for b in blocks(path) if b['total'] is not None]
    if not samples:
        print('no samples')
        return
    totals = [b['total'] for b in samples]
    print(f'{len(samples)} samples {samples[0]["time"]}..{samples[-1]["time"]}: '
          f'min {min(totals)}, median {statistics.median(totals):g}, max {max(totals)}')
    over = [b for b in samples if b['total'] >= 29]
    print(f'samples at or over 29: {len(over)}' +
          (': ' + ', '.join(f'{b["time"]}={b["total"]}' for b in over) if over else ''))
    for b in sorted(samples, key=lambda b: -b['total'])[:top]:
        print(f'\n--- {b["time"]} total={b["total"]}')
        counts = Counter(command(r) for r in b['rows'])
        print('by command: ' + ', '.join(f'{k}×{v}' for k, v in counts.most_common()))
        for r in b['rows']:
            print('  ' + r[:180])


def kills(dev):
    out = subprocess.run([ADB, '-s', dev, 'logcat', '-d'], capture_output=True, text=True).stdout
    hits = [l for l in out.splitlines() if re.search(r'Killing PhantomProcess|SIGSYS|seccomp', l)]
    print(f'{len(hits)} matching lines')
    for line in hits:
        print(line)


def main():
    cmd = sys.argv[1]
    if cmd == 'sample':
        sample(sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), sys.argv[5])
    elif cmd == 'summary':
        summary(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 1)
    elif cmd == 'kills':
        kills(sys.argv[2])
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == '__main__':
    main()
