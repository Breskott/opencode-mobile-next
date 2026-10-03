#!/bin/bash
# The local terminal's device checks (docs/design/local-terminal-2026-09-24.md,
# Proof), run on an open "This phone" terminal whose Ubuntu has vim and htop
# (apt-get install -y vim htop). Screen coordinates are for a 1080x2400
# portrait screen (Pixel 6 AVD). Each step writes into $OUT (default: the QA
# record's folder). Usage: proof.sh DEVICE CHECK...   (checks: 1 2 3 4 5 6 7)
set -eu
DEV=$1; shift
HERE=$(cd "$(dirname "$0")" && pwd)
T="python3 $HERE/term.py $DEV"
ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb} -s $DEV"
ESC=67,1344; UP=742,1344; TAB=67,1459; CTRL=202,1459; COPY=891,212
for check in "$@"; do
  case $check in
    1)
      $T "type:clear; ls --color /" enter "type:echo \$TERM; tput cols; tput lines" enter wait:2 shot:01-ls-term-cols-portrait
      $ADB shell settings put system accelerometer_rotation 0
      $ADB shell settings put system user_rotation 1; sleep 3
      $ADB shell input keyevent BACK; sleep 2
      $T "type:tput cols; tput lines" enter wait:2 shot:01-cols-landscape
      $ADB shell settings put system user_rotation 0; sleep 3
      $T tap:540,900 wait:1 ;;
    2)
      $T "type:clear; rm -f hello.txt; vim hello.txt" enter wait:3 "type:i" "type:Hello from vim on this phone" wait:1 shot:02-vim-typing \
        tap:$ESC wait:1 "type::wq" wait:1 shot:02-vim-wq enter wait:2 "type:cat hello.txt" enter wait:1 shot:02-vim-saved ;;
    3)
      $T "type:clear; htop -d 5" enter wait:3
      $ADB shell dumpsys SurfaceFlinger --latency-clear; sleep 10
      $T sf:03-htop-10s-sf shot:03-htop "type:q" wait:2 shot:03-htop-quit ;;
    4)
      $T "type:clear" enter gfx:reset wait:1 gfx:04-gfxinfo-before
      $ADB shell dumpsys SurfaceFlinger --latency-clear
      $T "type:time seq 1 200000" enter wait:8 sf:04-seq200k-sf gfx:04-gfxinfo-after shot:04-seq200k-done
      $T "type:clear" enter
      $ADB shell dumpsys SurfaceFlinger --latency-clear
      $T "type:time seq 1 2000000" enter wait:3 tap:$CTRL "type:c" wait:2 shot:04-seq2m-ctrl-c sf:04-seq2m-flood-sf ;;
    5)
      $T "type:clear" enter "type:ls /us" tap:$TAB wait:1 "type:lo" tap:$TAB wait:1 shot:05-tab-completion enter \
        "type:echo first" enter "type:echo second" enter tap:$UP tap:$UP wait:1 shot:05-up-arrow-history enter \
        "type:sleep 100" enter wait:2 tap:$CTRL "type:c" wait:1 tap:$CTRL "type:r" "type:hello" wait:1 shot:05-ctrl-c-then-ctrl-r \
        enter wait:1 shot:05-ctrl-r-ran ;;
    6)
      $T "type:clear" enter "type:python3 -c \"print('long:'+'-'.join(str(i) for i in range(40))); print('\\u4e2d\\u6587\\u5b57\\u7b26'*8); print('\\U0001F600\\U0001F680a'*12); print('end')\"" enter wait:2 shot:06-long-line-cjk-emoji ;;
    7)
      # Scrollback full first (the case that failed before 0fd36b9f), then clear.
      $T "type:seq 1 20000" enter wait:6 "type:clear; echo selectme-copied-text" enter wait:1
      $ADB shell input swipe 150 484 150 484 1200; sleep 1
      $T shot:07-selected tap:$COPY wait:1 "type:echo pasted: " ;;
    *) echo "unknown check $check" >&2; exit 2 ;;
  esac
done
