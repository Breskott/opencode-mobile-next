#!/usr/bin/env bash
# Full Flutter suite split between this machine and the build server.
#
#   tool/qa/run_tests_split.sh
#
# Golden (screenshot) tests stay on this machine: the server's CPU rasterizes
# glyph edges a fraction of a pixel differently (about 0.2% of pixels), so a
# golden only compares on the machine that wrote it. Every test file that
# mentions a golden, or imports a test helper that does, runs here; all other
# test files run on the server. A file that fails on the server is run again
# here before it counts, so a machine difference never reads as a failure.
#
# The committed HEAD goes to the private git remote OC_SPLIT_REMOTE (default
# "vps"; never a public remote) as refs/heads/split/<sha>, and the server
# tests exactly that commit in OC_SPLIT_REPO. Prints every failing file as
# "FAILED <path>" and exits non-zero unless all passed.
# Logs: build/traycer/split-<UTC time>/.
#
# Needs a clean tree (it tests the commit, not the working copy) and key-only
# SSH to OC_SPLIT_HOST, whose ~/.profile puts the pinned Flutter on PATH.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
# The build server's ssh target is private: it comes from the environment or
# from tool/qa/build-server.env (git-ignored) or ~/.config/oc-app/build-server.env.
for _env in "$(git rev-parse --show-toplevel 2>/dev/null)/tool/qa/build-server.env" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/oc-app/build-server.env"; do
  [ -f "$_env" ] && { . "$_env"; break; }
done
host="${OC_SPLIT_HOST:-${OC_VPS_HOST:-}}"
[ -n "$host" ] || { echo "$(basename "$0"): set OC_VPS_HOST (or tool/qa/build-server.env)" >&2; exit 64; }
remote="${OC_SPLIT_REMOTE:-vps}"
remote_repo="${OC_SPLIT_REPO:-Storage/Code/oc_app}"
remote_jobs="${OC_SPLIT_REMOTE_JOBS:-6}"
local_jobs="${OC_SPLIT_LOCAL_JOBS:-3}"
flutter="${FLUTTER:-$HOME/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter}"
cd "$root"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "run_tests_split: commit first; the split tests HEAD, not the working copy" >&2
  exit 64
fi
sha="$(git rev-parse HEAD)"
out="$root/build/traycer/split-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$out"

# Route: golden files (direct, or through a helper that mentions goldens) here.
find test -name '*_test.dart' | sort >"$out/all.txt"
grep -rlIi golden test --include='*.dart' | grep -v '_test\.dart$' |
  xargs -r -n1 basename | sort -u >"$out/golden-helpers.txt"
{
  grep -lIi golden $(cat "$out/all.txt") || true
  if [[ -s "$out/golden-helpers.txt" ]]; then
    grep -lIF -f "$out/golden-helpers.txt" $(cat "$out/all.txt") || true
  fi
} | sort -u >"$out/local.txt"
comm -23 "$out/all.txt" "$out/local.txt" >"$out/remote.txt"
echo "run_tests_split: $(wc -l <"$out/local.txt") files here, $(wc -l <"$out/remote.txt") on the server ($sha)"

git push -q -f "$remote" "HEAD:refs/heads/split/$sha"

# The server half, in the background; stdin carries its file list.
ssh -o BatchMode=yes "$host" "bash -c '
  set -uo pipefail; . ~/.profile
  cd ~/$remote_repo || exit 70
  git fetch -q origin refs/heads/split/$sha && git checkout -q --detach $sha || exit 70
  flutter pub get >/dev/null 2>&1 || exit 70
  (cd widgetbook && flutter pub get >/dev/null 2>&1) || true
  mapfile -t files
  flutter test -j $remote_jobs --reporter=failures-only \"\${files[@]}\" > ~/runs/split-$sha.log 2>&1
  echo REMOTE_EXIT=\$?
  grep -oE \"test/[A-Za-z0-9_/.-]+_test\\.dart\" <(grep -F \"[E]\" ~/runs/split-$sha.log) | sort -u | sed \"s/^/REMOTE_FAILED /\"
'" <"$out/remote.txt" >"$out/remote.log" 2>&1 &
remote_pid=$!

# This machine's half, under one machine_lock test slot.
"$root/tool/qa/machine_lock.sh" test -- "$flutter" test -j "$local_jobs" \
  --reporter=failures-only $(cat "$out/local.txt") >"$out/local.log" 2>&1 || true
wait "$remote_pid" || true

grep -F '[E]' "$out/local.log" | grep -oE 'test/[A-Za-z0-9_/.-]+_test\.dart' |
  sort -u >"$out/local-failed.txt" || true
sed -n 's/^REMOTE_FAILED //p' "$out/remote.log" | sort -u >"$out/remote-failed.txt"
status=0
grep -q '^REMOTE_EXIT=' "$out/remote.log" || { echo "run_tests_split: the server run did not finish (see remote.log)" >&2; status=1; }

# A server failure only counts if it also fails here.
: >"$out/recheck-failed.txt"
if [[ -s "$out/remote-failed.txt" ]]; then
  echo "run_tests_split: re-running $(wc -l <"$out/remote-failed.txt") server failure(s) here"
  "$root/tool/qa/machine_lock.sh" test -- "$flutter" test -j "$local_jobs" \
    --reporter=failures-only $(cat "$out/remote-failed.txt") >"$out/recheck.log" 2>&1 || true
  grep -F '[E]' "$out/recheck.log" | grep -oE 'test/[A-Za-z0-9_/.-]+_test\.dart' |
    sort -u >"$out/recheck-failed.txt" || true
fi
sort -u "$out/local-failed.txt" "$out/recheck-failed.txt" | sed 's/^/FAILED /' | tee "$out/failed.txt"
[[ -s "$out/failed.txt" ]] && status=1
echo "run_tests_split: $( [[ $status == 0 ]] && echo passed || echo failed ) ($sha, logs in $out)"
exit "$status"
