#!/usr/bin/env python3
"""flow.py DEVICE STEP...  -- scripted steps of the AI Team emulator proof.

Steps:
  launch               start the app
  plugins              Settings tab, then Settings > Plugins
  tap:TEXT             tap the first node labelled TEXT (scrolls to find it)
  wait:TEXT[:SECONDS]  wait until a node labelled TEXT shows
  type:TEXT            type TEXT into the focused field
  back                 Android Back
  shot:FILE            save a screenshot to FILE (a .png path)
  list                 print the labelled nodes

Example (the Android 15 run, docs/qa/aiteam-builtin-2026-09-24/README.md):
  flow.py emulator-5556 launch tap:"On this phone" tap:Customize \\
      tap:"AI Team ~" tap:Done tap:"Set up"
"""
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ADB = os.environ.get('ADB', os.path.expanduser('~/Android/Sdk/platform-tools/adb'))
PKG = 'io.github.eslamasabry.opencode_mobile'


def ui(dev, *args):
    return subprocess.run(['python3', f'{HERE}/ui.py', dev, *args], capture_output=True, text=True)


def adb(dev, *args):
    subprocess.run([ADB, '-s', dev, *args], capture_output=True)


def tap(dev, text, scroll=True):
    for _ in range(8):
        result = ui(dev, 'tap', text)
        if result.returncode == 0:
            print(result.stdout.strip())
            time.sleep(1.5)
            return True
        if not scroll:
            break
        # Scroll the page, never over an open keyboard (gesture typing).
        adb(dev, 'shell', 'input', 'swipe', '540', '1800', '540', '900', '300')
        time.sleep(1)
    print('not found:', text)
    return False


def wait(dev, text, seconds):
    end = time.time() + seconds
    while time.time() < end:
        if text.lower() in ui(dev, 'list').stdout.lower():
            return True
        time.sleep(2)
    print('timeout waiting for', text)
    return False


def main():
    dev = sys.argv[1]
    for step in sys.argv[2:]:
        if step == 'launch':
            adb(dev, 'shell', 'monkey', '-p', PKG, '-c', 'android.intent.category.LAUNCHER', '1')
            time.sleep(4)
        elif step == 'plugins':
            tap(dev, 'Settings Tab', scroll=False)
            tap(dev, 'Plugins AI Team')
            time.sleep(2)
        elif step.startswith('tap:'):
            tap(dev, step[4:])
        elif step.startswith('wait:'):
            parts = step[5:].split(':')
            wait(dev, parts[0], int(parts[1]) if len(parts) > 1 else 60)
        elif step.startswith('type:'):
            adb(dev, 'shell', 'input', 'text', step[5:].replace(' ', '%s'))
            time.sleep(1)
        elif step == 'back':
            adb(dev, 'shell', 'input', 'keyevent', '4')
            time.sleep(1.5)
        elif step.startswith('shot:'):
            with open(step[5:], 'wb') as f:
                f.write(subprocess.run([ADB, '-s', dev, 'exec-out', 'screencap', '-p'],
                                       capture_output=True).stdout)
            print('saved', step[5:])
        elif step == 'list':
            print(ui(dev, 'list').stdout)


if __name__ == '__main__':
    main()
