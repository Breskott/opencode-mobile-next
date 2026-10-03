"""Lays each captured frame sequence side by side into one strip image.

    python3 tool/capture/motion_strip.py docs/qa/motion-app-2026-09-25

Reads <dir>/frames/<sequence>/NN-<ms>ms.png (from tool/capture/motion_app_test.dart)
and writes <dir>/<sequence>.png: the frames at half size, left to right, each
labelled with its time. Needs Pillow.
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

root = sys.argv[1]
for seq in sorted(glob.glob(os.path.join(root, 'frames', '*'))):
    paths = sorted(glob.glob(os.path.join(seq, '*.png')))
    if not paths:
        continue
    frames = []
    for path in paths:
        im = Image.open(path).convert('RGB')
        frames.append((im.resize((im.width // 2, im.height // 2), Image.LANCZOS),
                       os.path.basename(path).split('-', 1)[1][:-4]))
    w, h = frames[0][0].size
    gap, label = 6, 22
    strip = Image.new('RGB', (len(frames) * (w + gap) - gap, h + label), (20, 20, 20))
    draw = ImageDraw.Draw(strip)
    for i, (im, ms) in enumerate(frames):
        x = i * (w + gap)
        strip.paste(im, (x, label))
        draw.text((x + 4, 4), ms, fill=(230, 230, 230))
    out = os.path.join(root, os.path.basename(seq) + '.png')
    strip.save(out, optimize=True)
    print(out)
