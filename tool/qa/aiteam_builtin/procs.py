#!/usr/bin/env python3
"""procs.py DEVICE [ROUNDS INTERVAL]

Counts the app's processes the way Android's phantom-process limit sees
them: every process of the app's user except the app itself. Android 12+
stops an app's child processes past 32 in all (oldest first, which is the
OpenCode server), so the AI Team proof samples this over time.
"""
import os
import subprocess
import sys
import time
from collections import Counter

ADB = os.environ.get('ADB', os.path.expanduser('~/Android/Sdk/platform-tools/adb'))
PKG = 'io.github.eslamasabry.opencode_mobile'


def sample(dev):
    out = subprocess.run([ADB, '-s', dev, 'shell', 'ps', '-A', '-o', 'PID,PPID,USER,RSS,ARGS'],
                         capture_output=True, text=True).stdout.splitlines()
    rows = [line.split(None, 4) for line in out[1:] if line.strip()]
    main = [r for r in rows if len(r) == 5 and r[4].strip() == PKG]
    if not main:
        return None
    user = main[0][2]
    mine = [r for r in rows if len(r) >= 4 and r[2] == user]
    children = [r for r in mine if r[0] != main[0][0]]
    names = Counter((r[4].split()[0].split('/')[-1] if len(r) == 5 else '?') for r in children)
    rss = sum(int(r[3]) for r in mine if r[3].isdigit()) // 1024
    return user, len(mine), len(children), rss, names


def main():
    dev = sys.argv[1]
    rounds = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    interval = float(sys.argv[3]) if len(sys.argv) > 3 else 0
    for i in range(rounds):
        s = sample(dev)
        stamp = time.strftime('%H:%M:%S')
        if s is None:
            print(stamp, 'app not running', flush=True)
        else:
            user, total, children, rss, names = s
            top = ', '.join(f'{k}×{v}' for k, v in names.most_common(12))
            print(f'{stamp} user={user} processes={total} children={children} rss={rss}MB | {top}',
                  flush=True)
        if i + 1 < rounds:
            time.sleep(interval)


if __name__ == '__main__':
    main()
