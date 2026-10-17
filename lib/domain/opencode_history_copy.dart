/// Carries OpenCode 1 chats into OpenCode 2's own data folder.
///
/// OpenCode 2 converts OpenCode 1 history by itself on every start, but only
/// from the `opencode.db` it finds in its own `$XDG_DATA_HOME/opencode/`
/// (probed on 2.0.29: `docs/qa/oc2-switch-keeps-chats-2026-10-14/`). The
/// switch gives OpenCode 2 an isolated data folder, so without this copy the
/// old chats stay behind.
///
/// POSIX `sh`, meant to run inside the Ubuntu container before OpenCode 2's
/// first start, after OpenCode 1 has stopped:
///
/// - runs only when OpenCode 2 has no `opencode.db` yet, so it never
///   overwrites and a second switch is a no-op;
/// - copies, never moves: OpenCode 1's folder stays whole for switching back;
/// - stages the database with its `-wal` and `-shm` files in a scratch folder
///   and moves them into place with `opencode.db` last, so a half copy never
///   looks like a database;
/// - refuses a fresh start on any copy failure; never starts with missing history.
///
/// Existing targets remain untouched on ordinary restarts. Explicit moves must
/// run [openCode1HistorySwitchCheckScript] first, before stopping OpenCode 1.
const openCode1HistoryCopyScript = r'''
oc1_dir="${HOME:-/root}/.local/share/opencode"
oc2_dir=/root/.oc-opencode2/data/opencode
if [ ! -e "$oc2_dir/opencode.db" ] && [ -f "$oc1_dir/opencode.db" ]; then
  history_copy_failed() {
    echo '[oc-history-copy-failed] Your earlier conversations could not be copied. They are still safe in Older OpenCode. Free some space and try again.' >&2
    exit 74
  }
  # A previous interrupted copy is not a known-empty target.
  if [ -e "$oc2_dir/opencode.db-wal" ] || [ -e "$oc2_dir/opencode.db-shm" ]; then
    history_copy_failed
  fi
  mkdir -p "$oc2_dir" || history_copy_failed
  stage="$oc2_dir/.oc1-copy.$$"
  # Do not reuse an interrupted staging folder or follow a stale symlink.
  mkdir "$stage" || history_copy_failed
  if ! { cp "$oc1_dir/opencode.db" "$stage/opencode.db" \
    && { [ ! -f "$oc1_dir/opencode.db-wal" ] || cp "$oc1_dir/opencode.db-wal" "$stage/opencode.db-wal"; } \
    && { [ ! -f "$oc1_dir/opencode.db-shm" ] || cp "$oc1_dir/opencode.db-shm" "$stage/opencode.db-shm"; }; }; then
    rm -rf "$stage"
    history_copy_failed
  fi
  if ! { { [ ! -f "$stage/opencode.db-wal" ] || mv "$stage/opencode.db-wal" "$oc2_dir/opencode.db-wal"; } \
    && { [ ! -f "$stage/opencode.db-shm" ] || mv "$stage/opencode.db-shm" "$oc2_dir/opencode.db-shm"; } \
    && mv "$stage/opencode.db" "$oc2_dir/opencode.db"; }; then
    rm -rf "$stage"
    history_copy_failed
  fi
  rm -rf "$stage"
fi
''';

const openCode1HistorySwitchBlockedMessage =
    'Cannot move your conversations because OpenCode 2 already has a separate '
    'history. Stay on Older OpenCode to keep using these conversations. '
    'Both histories are safe; neither was changed.';

/// Read-only admission for an explicit move from Older OpenCode to OpenCode 2.
/// Run before stopping the old server or changing its profile/credentials.
/// The current OC2 API reports migration status but has no verified merge path
/// for two existing histories. Refusing leaves both generations usable.
const openCode1HistorySwitchCheckScript = r'''
oc1_dir="${HOME:-/root}/.local/share/opencode"
oc2_dir=/root/.oc-opencode2/data/opencode
# Unknown locations must not be mistaken for an absent history.
for history_dir in "$oc1_dir" "$oc2_dir"; do
  if [ -L "$history_dir" ] || { [ -e "$history_dir" ] && { [ ! -d "$history_dir" ] || [ ! -r "$history_dir" ] || [ ! -x "$history_dir" ]; }; } \
    || [ -L "$history_dir/opencode.db" ]; then
    echo '[oc-history-switch-blocked] Cannot check your earlier conversations safely. Stay on Older OpenCode and try again. Neither history was changed.' >&2
    exit 74
  fi
done
if [ -e "$oc1_dir/opencode.db" ] && [ -e "$oc2_dir/opencode.db" ]; then
  echo '[oc-history-switch-blocked] Cannot move your conversations because OpenCode 2 already has a separate history. Stay on Older OpenCode to keep using these conversations. Both histories are safe; neither was changed.' >&2
  exit 74
fi
''';

/// Read-only result of the same check used immediately before a move.
/// Unknown or failed checks never authorize a promise that chats will move.
enum OpenCodeHistorySwitchAdmission {
  allowed,
  separateHistory,
  unavailable;

  static OpenCodeHistorySwitchAdmission fromResult(
    int exitCode,
    String output,
  ) {
    if (exitCode == 0) return allowed;
    if (exitCode == 74 &&
        output.contains(openCode1HistorySwitchBlockedMessage)) {
      return separateHistory;
    }
    return unavailable;
  }
}
