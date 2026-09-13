#!/data/data/com.termux/files/usr/bin/bash
# AI Team hybrid layout: gc/bd/dolt run natively in Termux; only the OpenCode
# agent process runs inside the glibc rootfs. Forwards cwd and GC_* env.
# The ACP provider does not run the pack's pre_start, so make an agent's
# work dir under .gc/worktrees a git worktree of the rig here (idempotent).
case "$PWD" in *"/.gc/worktrees/"*) in_wt=1;; *) in_wt=;; esac
if [ -n "$GC_RIG_ROOT" ] && [ -n "$in_wt" ] && [ ! -e "$PWD/.git" ]; then
  setup=$(ls -d "$HOME"/.gc/cache/repos/*/gastown/assets/scripts/worktree-setup.sh 2>/dev/null | head -1)
  base=${GC_ALIAS##*/}
  [ -n "$setup" ] && sh "$setup" "$GC_RIG_ROOT" "$PWD" "$base" --sync >> "$HOME/.aiteam-wrapper.log" 2>&1
fi
envf=$(mktemp "$HOME/.aiteam-env.XXXXXX")
env | grep -E '^(GC_|OPENCODE_|BEADS_|TERM=|LANG=|HOME=)' | grep -vE '^GC_BIN=' > "$envf"
echo 'GC_BIN=/usr/local/bin/gc' >> "$envf"
exec proot-distro login --work-dir "$PWD" --shared-tmp opencode-ubuntu -- bash -c 'set -a; . "$1"; set +a; rm -f "$1"; shift; exec /usr/local/bin/opencode "$@"' _ "$envf" "$@"
