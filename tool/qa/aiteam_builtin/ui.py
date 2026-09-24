#!/usr/bin/env python3
"""ui.py DEVICE [list | tap TEXT [N] | find TEXT]

Reads the app's screen through uiautomator (Flutter exposes its semantics
labels there): `list` prints every labelled node with its bounds, `tap`
taps the centre of the Nth node whose text or description contains TEXT.
Used by the AI Team emulator proof (docs/qa/aiteam-builtin-2026-09-24).
"""
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ADB = os.environ.get('ADB', os.path.expanduser('~/Android/Sdk/platform-tools/adb'))


def dump(dev):
    out = ''
    for _ in range(3):
        out = subprocess.run([ADB, '-s', dev, 'exec-out', 'uiautomator', 'dump', '/dev/tty'],
                             capture_output=True, text=True).stdout
        i, j = out.find('<?xml'), out.rfind('</hierarchy>')
        if i >= 0 and j >= 0:
            return ET.fromstring(out[i:j + len('</hierarchy>')])
    raise SystemExit('uiautomator dump failed: ' + out[:200])


def nodes(root):
    for n in root.iter('node'):
        label = (n.get('text') or '') + ' | ' + (n.get('content-desc') or '')
        if label.strip(' |'):
            yield n, label.replace('\n', ' ')


def centre(n):
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', n.get('bounds')))
    return (x1 + x2) // 2, (y1 + y2) // 2


def main():
    dev = sys.argv[1]
    cmd = sys.argv[2] if len(sys.argv) > 2 else 'list'
    root = dump(dev)
    if cmd == 'list':
        for n, label in nodes(root):
            print(n.get('bounds'), n.get('clickable'), label[:140])
        return
    text = sys.argv[3]
    idx = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    hits = [n for n, label in nodes(root) if text.lower() in label.lower()]
    if len(hits) <= idx:
        raise SystemExit('not found: ' + text)
    x, y = centre(hits[idx])
    print('found', hits[idx].get('bounds'), (hits[idx].get('text') or hits[idx].get('content-desc'))[:80])
    if cmd == 'tap':
        subprocess.run([ADB, '-s', dev, 'shell', 'input', 'tap', str(x), str(y)])


if __name__ == '__main__':
    main()
