#!/usr/bin/env python3
"""timestats.py DUMP.txt [LAYER_SUBSTRING]

Frame figures for a Flutter app from `dumpsys SurfaceFlinger --timestats -dump`.

Why not `dumpsys gfxinfo`: Flutter draws into its own SurfaceView, so HWUI's
gfxinfo sees none of its frames ("Total frames rendered: 0" on 1.0.44+50,
checked 2026-09-25). SurfaceFlinger's TimeStats counts every buffer the
Flutter layer presents. Reset and enable before a scenario, dump after:

  adb shell dumpsys SurfaceFlinger --timestats -enable -clear
  … scenario …
  adb shell dumpsys SurfaceFlinger --timestats -dump > ts.txt

For the layer whose name contains LAYER_SUBSTRING (default: the app's
`SurfaceView[io.github.eslamasabry.opencode_mobile/...](BLAST)`), prints
one CSV line:
  frames, avg_fps, dropped, p50_ms, p90_ms, p99_ms, over_17ms_pct, over_34ms_pct
from the present-to-present histogram (the time between two frames the
layer showed; a bucket's lower bound is used, so percentiles are floors).
`over_17ms` = intervals that missed at least one 60 Hz vsync; `over_34ms`
= at least two. Idle pauses between gestures also count as long intervals,
so a scenario must keep the screen moving (continuous flings, a streaming
reply) for these to mean "jank".
"""
import re
import sys


def hist(line):
    out = []
    for k, v in re.findall(r'(\d+)ms=(\d+)', line):
        out.append((int(k), int(v)))
    return out


def pct(h, q):
    n = sum(v for _, v in h)
    if n == 0:
        return ''
    need = q * n
    acc = 0
    for k, v in h:
        acc += v
        if acc >= need:
            return k
    return h[-1][0]


def main():
    text = open(sys.argv[1]).read().splitlines()
    want = sys.argv[2] if len(sys.argv) > 2 else 'SurfaceView[io.github.eslamasabry.opencode_mobile'
    i = 0
    found = None
    while i < len(text):
        if text[i].startswith('layerName = ') and want in text[i] and 'Background' not in text[i]:
            found = i
            break
        i += 1
    if found is None:
        print('frames,avg_fps,dropped,p50_ms,p90_ms,p99_ms,over_17ms_pct,over_34ms_pct')
        print('0,,,,,,,')
        return
    vals = {}
    h = []
    j = found + 1
    while j < len(text) and not text[j].startswith('layerName = '):
        m = re.match(r'(\w+) = ([\d.]+)', text[j])
        if m:
            vals.setdefault(m.group(1), m.group(2))
        if text[j].startswith('present2present histogram'):
            h = hist(text[j + 1])
        j += 1
    n = sum(v for _, v in h)
    over17 = sum(v for k, v in h if k >= 17)
    over34 = sum(v for k, v in h if k >= 34)
    print('frames,avg_fps,dropped,p50_ms,p90_ms,p99_ms,over_17ms_pct,over_34ms_pct')
    print('%s,%s,%s,%s,%s,%s,%s,%s' % (
        vals.get('totalFrames', ''), vals.get('averageFPS', ''), vals.get('droppedFrames', ''),
        pct(h, 0.5), pct(h, 0.9), pct(h, 0.99),
        '%.1f' % (100.0 * over17 / n) if n else '', '%.1f' % (100.0 * over34 / n) if n else ''))


if __name__ == '__main__':
    main()
