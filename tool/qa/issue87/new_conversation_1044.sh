#!/usr/bin/env bash
# new_conversation_1044.sh "Prompt%swith%sspaces"  (HIDEKB=1 hides the keyboard after typing)
# 1.0.44+50 on a 1080x2400 emulator: back to the Work tab, tap the pinned
# "New conversation" button (not a conversation row of that title), tap the
# composer, type the prompt. DEV defaults to emulator-5556. Issue #87 proof.
U="python3 $(dirname "$0")/../aiteam_builtin/ui.py ${DEV:-emulator-5556}"; A="$HOME/Android/Sdk/platform-tools/adb -s ${DEV:-emulator-5556}"
$A shell input keyevent 4; sleep 1; $A shell input keyevent 4; sleep 1
$A shell am start -n io.github.eslamasabry.opencode_mobile/.MainActivity >/dev/null; sleep 2
$U tap "Work Tab" >/dev/null 2>&1; sleep 2
$U list | grep -q "\[42,1991\]\[660,2117\] true  | New conversation" && $A shell input tap 350 2054; sleep 4
$A shell input tap 540 2110; sleep 1.5
$A shell input text "$1"; sleep 1.5; [ -n "$HIDEKB" ] && $A shell input keyevent 4 && sleep 1
