#!/usr/bin/env bash
# measure.sh DEVICE OUTDIR SCENARIO RUN
#
# One timed repetition of an issue #87 scenario on an emulator, for builds
# with or without OCTRACE. Each run records the screen (adb screenrecord,
# on the device), then tool/qa/issue87/frames.py turns the video into a
# change timeline (10 fps) and prints first_change / settled / settle_time.
# The frames stay in OUTDIR/<scenario>-<run>/ for reading by eye.
#
# Scenarios (labels are the 1.0.44+50 ones; the candidate build may differ,
# where it has OCTRACE use that instead — see the README):
#   cold      force-stop, Home, then `am start -W` (also prints TotalTime =
#             the `Displayed` time). Ends on the Work tab.
#   project   on the Work tab, tap the other-project chip (CHIP=label, or
#             CHIP_XY="x y" when the label is a substring of another, as
#             "proj" of "proj2"). Ends on the Work tab of that project.
#   settings  on the Work tab, tap the Settings tab.
#   send      in an open conversation whose composer already holds the text,
#             tap Send; the SSE log (sse_log.py) runs alongside so the model's
#             share can be separated from the app's.
#   gfx-stream  SurfaceFlinger timestats while the reply's text streams: from
#             the assistant's text part appearing on the SSE log to
#             session.idle (each wait at most SECS, default 90).
#             The composer must hold the long prompt.
#   gfx-scroll  SurfaceFlinger timestats while flinging a long chat 10 times
#             up and 10 times down (the long chat must be open).
#
# PROJECT_DIR = the server-side folder of the open project (for the SSE log).
#
# Rules this obeys (AGENTS.md / machine rules): one device, always -s; no
# pattern kills on the PC.
set -euo pipefail
DEV=$1; OUT=$2; SC=$3; RUN=$4
ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb} -s $DEV"
PKG=io.github.eslamasabry.opencode_mobile
HERE=$(cd "$(dirname "$0")" && pwd)
UI="python3 $HERE/../aiteam_builtin/ui.py $DEV"
mkdir -p "$OUT"
D="$OUT/$SC-$RUN"; mkdir -p "$D"

send_xy() { # centre of the Send button, found before the timed part
  $UI find 'Send' | grep -o '\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]' | head -1 |
    tr '[],' '   ' | awk '{print int(($1+$3)/2), int(($2+$4)/2)}'
}

rec() { # seconds, then the action as a command string
  local secs=$1; shift
  $ADB shell rm -f /sdcard/i87.mp4
  $ADB shell screenrecord --time-limit "$secs" /sdcard/i87.mp4 &
  local rp=$!
  sleep 1.5
  date +%s.%N > "$D/action_host_time"
  eval "$@"
  wait $rp || true
  sleep 1
  $ADB pull /sdcard/i87.mp4 "$D/video.mp4" >/dev/null
  python3 "$HERE/frames.py" --length "$secs" "$D/video.mp4" "$D/frames" | tee "$D/summary.txt"
}

case $SC in
  cold)
    $ADB shell am force-stop $PKG
    $ADB shell input keyevent 3
    sleep 3
    rec 16 "$ADB shell am start -W -n $PKG/.MainActivity | tee $D/am_start.txt"
    grep -E 'TotalTime|LaunchState' "$D/am_start.txt"
    ;;
  project)
    if [ -n "${CHIP_XY:-}" ]; then rec 12 "$ADB shell input tap $CHIP_XY"
    else rec 12 "$UI tap \"${CHIP:?set CHIP or CHIP_XY}\""; fi
    ;;
  settings)
    rec 10 "$UI tap 'Settings Tab'"
    ;;
  send)
    python3 "$HERE/sse_log.py" "${BASE:-http://127.0.0.1:4096}" "$D/sse.tsv" ${PROJECT_DIR:+"$PROJECT_DIR"} &
    sp=$!
    sleep 1
    xy=$(send_xy)
    rec "${SECS:-30}" "$ADB shell input tap $xy"
    kill "$sp" 2>/dev/null || true
    ;;
  gfx-stream)
    $ADB shell dumpsys SurfaceFlinger --timestats -enable -clear >/dev/null
    $ADB shell dumpsys gfxinfo $PKG reset >/dev/null
    python3 "$HERE/sse_log.py" "${BASE:-http://127.0.0.1:4096}" "$D/sse.tsv" ${PROJECT_DIR:+"$PROJECT_DIR"} &
    sp=$!
    sleep 1
    xy=$(send_xy)
    date +%s.%N > "$D/action_host_time"
    $ADB shell input tap $xy
    # Window = the reply's text streaming only: clear when the assistant's
    # text part appears (a `text` part of length 0 on the SSE log; the
    # user's own text part is never empty), dump at session.idle. The wait
    # for the model before it (a spinner, model-dependent) is left out.
    # The conversation is the session of the first user message after the tap.
    sid=''
    for i in $(seq 1 100); do
      sid=$(awk -F'\t' '$3=="info" && $5=="user" && $6!=""{print $6; exit}' "$D/sse.tsv" 2>/dev/null)
      [ -n "$sid" ] && break
      sleep 0.2
    done
    echo "$sid" > "$D/session_id"
    for i in $(seq 1 $(( ${SECS:-90} * 5 ))); do
      awk -F'\t' -v s="$sid" '$2=="message.part.updated" && $3=="text" && $5==0 && $6==s{f=1} END{exit !f}' "$D/sse.tsv" && break
      sleep 0.2
    done
    date +%s.%N > "$D/window_start_host_time"
    $ADB shell dumpsys SurfaceFlinger --timestats -clear >/dev/null
    for i in $(seq 1 $(( ${SECS:-90} * 5 ))); do
      awk -F'\t' -v s="$sid" '$2=="session.idle" && $6==s{f=1} END{exit !f}' "$D/sse.tsv" && break
      sleep 0.2
    done
    date +%s.%N > "$D/window_end_host_time"
    $ADB shell dumpsys SurfaceFlinger --timestats -dump > "$D/timestats.txt"
    $ADB shell dumpsys gfxinfo $PKG framestats > "$D/gfxinfo.txt"
    $ADB shell dumpsys SurfaceFlinger --timestats -disable >/dev/null
    kill "$sp" 2>/dev/null || true
    python3 "$HERE/timestats.py" "$D/timestats.txt" | tee "$D/summary.txt"
    grep -E 'Total frames rendered|Janky frames:' "$D/gfxinfo.txt" | tee -a "$D/summary.txt"
    ;;
  gfx-scroll)
    $ADB shell dumpsys SurfaceFlinger --timestats -enable -clear >/dev/null
    $ADB shell dumpsys gfxinfo $PKG reset >/dev/null
    for i in 1 2 3 4 5 6 7 8 9 10; do $ADB shell input swipe 540 700 540 1800 120; sleep 0.4; done
    for i in 1 2 3 4 5 6 7 8 9 10; do $ADB shell input swipe 540 1800 540 700 120; sleep 0.4; done
    $ADB shell dumpsys SurfaceFlinger --timestats -dump > "$D/timestats.txt"
    $ADB shell dumpsys gfxinfo $PKG framestats > "$D/gfxinfo.txt"
    $ADB shell dumpsys SurfaceFlinger --timestats -disable >/dev/null
    python3 "$HERE/timestats.py" "$D/timestats.txt" | tee "$D/summary.txt"
    grep -E 'Total frames rendered|Janky frames:' "$D/gfxinfo.txt" | tee -a "$D/summary.txt"
    ;;
  *) echo "unknown scenario $SC" >&2; exit 2 ;;
esac
