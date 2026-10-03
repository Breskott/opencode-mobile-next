#!/usr/bin/env python3
"""frames.py VIDEO.mp4 OUTDIR [--fps 10] [--stable 2.0] [--roi y0,y1]

Timing from a device screen recording (`adb shell screenrecord`), for builds
that have no OCTRACE (1.0.44+50 and older). Used by the issue #87 proof
(docs/qa/issue-87-proof-2026-09-25).

1. ffmpeg samples the video at --fps (default 10) into OUTDIR/f_00001.png ...
2. Each frame is compared with the previous one (grayscale, 1/4 size, the
   status bar's top 5 % and the gesture bar's bottom 3 % masked out, or only
   the rows y0..y1 as fractions of the height with --roi).
3. Prints and writes OUTDIR/timeline.csv: time_s, diff (mean absolute
   difference, 0..255), changed (diff > 0.5).

Summary lines:
  first_change  the first frame that differs from the one before it
                (the tap / am start becoming visible)
  settled       the last change before the screen stays unchanged for
                --stable seconds (default 2.0) to the end of the video
  settle_time   settled - first_change
--length is the recording length: screenrecord writes no frames while the
screen is still, so a video ends at its last change. A screen with a looping
animation never settles; then `settled` is empty and
the timeline has to be read by eye (the frames are kept for that).
"""
import argparse
import csv
import glob
import os
import subprocess

import numpy as np
from PIL import Image


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('video')
    ap.add_argument('outdir')
    ap.add_argument('--fps', type=float, default=10.0)
    ap.add_argument('--stable', type=float, default=2.0)
    ap.add_argument('--roi', default=None)
    ap.add_argument('--threshold', type=float, default=0.5)
    ap.add_argument('--length', type=float, default=0.0,
                    help='recording length in s; screenrecord writes no frames while the screen is still, so the video can end early')
    a = ap.parse_args()
    os.makedirs(a.outdir, exist_ok=True)
    for f in glob.glob(os.path.join(a.outdir, 'f_*.png')):
        os.remove(f)
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', a.video, '-vf',
                    'fps=%g' % a.fps, os.path.join(a.outdir, 'f_%05d.png')], check=True)
    files = sorted(glob.glob(os.path.join(a.outdir, 'f_*.png')))
    prev = None
    rows = []
    for i, f in enumerate(files):
        im = Image.open(f).convert('L')
        w, h = im.size
        im = np.asarray(im.resize((w // 4, h // 4)), dtype=np.int16)
        hh = im.shape[0]
        if a.roi:
            y0, y1 = (float(x) for x in a.roi.split(','))
            im = im[int(hh * y0):int(hh * y1)]
        else:
            im = im[int(hh * 0.05):int(hh * 0.97)]
        d = 0.0 if prev is None else float(np.abs(im - prev).mean())
        prev = im
        rows.append((i / a.fps, d, d > a.threshold))
    with open(os.path.join(a.outdir, 'timeline.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['time_s', 'diff', 'changed'])
        for t, d, c in rows:
            w.writerow(['%.1f' % t, '%.2f' % d, int(c)])
    changes = [t for t, d, c in rows if c]
    end = max(rows[-1][0] if rows else 0, a.length)
    first = changes[0] if changes else None
    settled = None
    if changes and end - changes[-1] >= a.stable:
        settled = changes[-1]
    print('frames', len(rows), 'duration %.1f' % end)
    print('first_change', '' if first is None else '%.1f' % first)
    print('settled', '' if settled is None else '%.1f' % settled)
    print('settle_time', '' if first is None or settled is None else '%.1f' % (settled - first))
    print('changes', ' '.join('%.1f' % t for t in changes))


if __name__ == '__main__':
    main()
