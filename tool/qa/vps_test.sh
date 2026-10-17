#!/usr/bin/env bash
# Run test files on the build server instead of this machine.
#
#   tool/qa/vps_test.sh test/foo_test.dart test/bar_test.dart [-- flutter test args]
#
# Copies this worktree as it is now (uncommitted edits included; build/,
# .dart_tool/ and .git/ left out) to ~/wt/<worktree name> on OC_VPS_HOST, runs
# `flutter test` there and prints the result. Golden (screenshot) files are
# refused: the server's CPU rasterizes glyph edges ~0.2% differently, so
# goldens only compare on the machine that wrote them; run those here under
# tool/qa/machine_lock.sh. Needs key-only SSH to OC_VPS_HOST, whose
# ~/.profile puts the pinned Flutter on PATH.
set -euo pipefail
# The worktree is the one you run it from, so any checkout can use one copy.
root="$(git rev-parse --show-toplevel)"
# The build server's ssh target is private: it comes from the environment or
# from tool/qa/build-server.env (git-ignored) or ~/.config/oc-app/build-server.env.
for _env in "$(git rev-parse --show-toplevel 2>/dev/null)/tool/qa/build-server.env" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/oc-app/build-server.env"; do
  [ -f "$_env" ] && { . "$_env"; break; }
done
host="${OC_VPS_HOST:-${OC_VPS_HOST:-}}"
[ -n "$host" ] || { echo "$(basename "$0"): set OC_VPS_HOST (or tool/qa/build-server.env)" >&2; exit 64; }
jobs="${OC_VPS_JOBS:-4}"
files=()
extra=()
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--" ]]; then shift; extra=("$@"); break; fi
  files+=("$1"); shift
done
((${#files[@]} > 0)) || { echo "vps_test: name the test files to run" >&2; exit 64; }
cd "$root"
for f in "${files[@]}"; do
  [[ -f "$f" ]] || { echo "vps_test: no such file: $f" >&2; exit 64; }
  if grep -qIi golden "$f"; then
    echo "vps_test: $f compares goldens; run it here under machine_lock" >&2
    exit 65
  fi
done
name="$(basename "$root")"
ssh -o BatchMode=yes "$host" "mkdir -p ~/wt"
rsync -a --delete --exclude build/ --exclude .dart_tool/ --exclude .git/ \
  --exclude 'test/**/failures/' --exclude android/key.properties \
  "$root/" "$host:wt/$name/"
quoted=$(printf '%q ' "${files[@]}" ${extra[@]+"${extra[@]}"})
ssh -o BatchMode=yes "$host" "bash -lc 'cd ~/wt/$name && flutter pub get >/dev/null 2>&1 && (cd widgetbook 2>/dev/null && flutter pub get >/dev/null 2>&1 || true) && flutter test -j $jobs $quoted'"
