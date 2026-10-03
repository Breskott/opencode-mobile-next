#!/usr/bin/env bash
# termux_emulator_prep.sh EMULATOR_SERIAL [APK_DIR]
#
# Puts Termux on an x86_64 EMULATOR the way the app's "OpenCode in Termux"
# path expects a person to have it, so that path (and the Termux AI Team) can
# be proven without the owner's phone. Issue #87 proof, 2026-09-25.
#
# What the app checks (android/.../MainActivity.kt capabilities(),
# lib/termux/bridge.dart):
#   installed           package com.termux present
#   protocolSupported   versionName >= 0.109
#   serviceAvailable    com.termux.app.RunCommandService exported
#   permissionGranted   OUR app holds com.termux.permission.RUN_COMMAND
#                       (granted later, in our app's own flow)
# and RUN_COMMAND only runs when ~/.termux/termux.properties has
# allow-external-apps=true (TermuxBridge.unlockCommand writes the same line).
#
# Steps:
#   1. refuse anything that is not an emulator-NNNN serial (never a phone);
#   2. download Termux 0.118.3 x86_64 from termux/termux-app's GitHub
#      release and check its SHA-256 against the release's sha256sums;
#   3. install it; open it once so it unpacks its bootstrap (the first run
#      needs the network, ~1 min on an emulator);
#   4. write allow-external-apps=true. The GitHub build is debuggable, so
#      `run-as com.termux` can write the file directly; for a non-debuggable
#      (F-Droid) build the script types the same command into the Termux
#      window with `input text` instead;
#   5. restart Termux so it reads the property, and print what it now has.
# It does NOT install our app, grant RUN_COMMAND, run pkg, or install
# OpenCode: that is what the app's setup must prove.
set -euo pipefail
DEV=${1:?usage: termux_emulator_prep.sh emulator-5554 [apk_dir]}
DIR=${2:-${TMPDIR:-/tmp}/termux-apk}
case $DEV in emulator-[0-9]*) ;; *) echo "refusing: $DEV is not an emulator" >&2; exit 2 ;; esac
ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb} -s $DEV"
VER=v0.118.3
APK="termux-app_${VER}+github-debug_x86_64.apk"
SUMS="termux-app_${VER}+github-debug_sha256sums"
[ "$($ADB shell getprop ro.product.cpu.abi | tr -d '\r')" = x86_64 ] || { echo "not x86_64" >&2; exit 2; }

mkdir -p "$DIR"
if [ ! -f "$DIR/$APK" ]; then
  gh release download -R termux/termux-app "$VER" -p "$APK" -p "$SUMS" -D "$DIR" --clobber
fi
(cd "$DIR" && grep " $APK\$" "$SUMS" | sha256sum -c -)

if $ADB shell pm list packages com.termux | grep -qx 'package:com.termux'; then
  echo "Termux already installed: $($ADB shell dumpsys package com.termux | grep -m1 versionName | tr -d ' \r')"
else
  $ADB install "$DIR/$APK"
fi

# 3. First run: the bootstrap unpacks into files/usr.
$ADB shell am start -n com.termux/.app.TermuxActivity >/dev/null
debuggable=0
if $ADB shell run-as com.termux true 2>/dev/null; then debuggable=1; fi
echo "waiting for the bootstrap (debuggable=$debuggable)"
for i in $(seq 1 120); do
  if [ $debuggable = 1 ]; then
    $ADB shell run-as com.termux test -x files/usr/bin/bash 2>/dev/null && break
  else
    # Without run-as, give it a fixed time and look at the screen afterwards.
    [ "$i" -ge 45 ] && break
  fi
  sleep 2
done

# 4. allow-external-apps=true
LINE='allow-external-apps=true'
if [ $debuggable = 1 ]; then
  $ADB shell run-as com.termux sh -c "'mkdir -p files/home/.termux && touch files/home/.termux/termux.properties && (grep -q ^$LINE files/home/.termux/termux.properties || echo $LINE >> files/home/.termux/termux.properties)'"
else
  $ADB shell am start -n com.termux/.app.TermuxActivity >/dev/null
  sleep 2
  $ADB shell "input text 'mkdir%s-p%s~/.termux%s&&%secho%s$LINE%s>>%s~/.termux/termux.properties%s&&%stermux-reload-settings'"
  $ADB shell input keyevent 66
  sleep 3
fi

# 5. Restart so the property is read, then report.
$ADB shell am force-stop com.termux
$ADB shell am start -n com.termux/.app.TermuxActivity >/dev/null
sleep 5
echo "--- state"
$ADB shell dumpsys package com.termux | grep -E -m2 'versionName|versionCode' | tr -d '\r'
$ADB shell dumpsys package com.termux | grep -q 'pkgFlags=.*DEBUGGABLE' && echo 'build: debuggable (GitHub build)'
$ADB shell cmd package resolve-activity --brief com.termux | tail -1
$ADB shell dumpsys package com.termux | grep -q 'RunCommandService' && echo "RunCommandService: present"
if [ $debuggable = 1 ]; then
  echo "termux.properties: $($ADB shell run-as com.termux cat files/home/.termux/termux.properties | tr -d '\r' | grep -v '^#' | tr '\n' ' ')"
  echo "bootstrap: $($ADB shell run-as com.termux ls files/usr/bin | wc -l) programs in usr/bin"
fi
