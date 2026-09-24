#!/usr/bin/env python3
"""monitor.py DEVICE SECONDS INTERVAL LOGFILE [REGEX] [STOP_REGEX]

Every INTERVAL seconds: the app's process count (procs.py) and the screen
labels matching REGEX, one line, appended to LOGFILE. Stops after SECONDS
or once a label matches STOP_REGEX, then reports the peak count and any
logcat line where Android killed a phantom process or a program died of
SIGSYS/seccomp.
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ADB = os.environ.get('ADB', os.path.expanduser('~/Android/Sdk/platform-tools/adb'))
KILLS = re.compile(r'Killing PhantomProcess|Trimming phantom|SIGSYS|seccomp|signal 31|Bad system call', re.I)


def main():
    dev, seconds, interval, logfile = sys.argv[1], int(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
    rx = re.compile(sys.argv[5] if len(sys.argv) > 5 else 'Create|done|Waiting|Working|agent', re.I)
    stop = re.compile(sys.argv[6], re.I) if len(sys.argv) > 6 and sys.argv[6] else None
    end = time.time() + seconds
    peak = 0
    with open(logfile, 'a') as log:
        while time.time() < end:
            p = subprocess.run(['python3', f'{HERE}/procs.py', dev], capture_output=True, text=True).stdout.strip()
            m = re.search(r'processes=(\d+)', p)
            if m:
                peak = max(peak, int(m.group(1)))
            out = subprocess.run(['python3', f'{HERE}/ui.py', dev, 'list'], capture_output=True, text=True).stdout
            labels = [line.split('  | ', 1)[-1] for line in out.splitlines()]
            line = f'{p} || ' + ' || '.join(l[:160] for l in labels if rx.search(l))
            print(line, flush=True)
            log.write(line + '\n')
            log.flush()
            if stop and any(stop.search(l) for l in labels):
                break
            time.sleep(interval)
        logcat = subprocess.run([ADB, '-s', dev, 'logcat', '-d'], capture_output=True, text=True).stdout
        bad = [l for l in logcat.splitlines() if KILLS.search(l)]
        summary = f'peak processes={peak}; logcat kills/SIGSYS lines={len(bad)}'
        print(summary)
        log.write(summary + '\n')
        for l in bad[-10:]:
            print('  ', l[:200])
            log.write('  ' + l[:200] + '\n')


if __name__ == '__main__':
    main()
