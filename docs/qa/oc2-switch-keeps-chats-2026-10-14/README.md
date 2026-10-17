# Switch to OpenCode 2 keeps the chats (2026-10-14)

Blocker B1 of `docs/design/oc1-decommission-plan-2026-10-14.md`, plus three capability flags.

## What changed

- `lib/domain/opencode_history_copy.dart`: one POSIX `sh` snippet. Both start paths run it inside Ubuntu, after the isolated
  OpenCode 2 folders are made and before `serve`: `BuiltinLinux.serverScript` (in-app) and the Termux server runner
  (`manager_script.dart`, through `proot-distro login ... sh -s`).
  - Runs only when `/root/.oc-opencode2/data/opencode/opencode.db` does not exist and OpenCode 1's
    `~/.local/share/opencode/opencode.db` does.
  - Copies `opencode.db`, `-wal`, `-shm` into a scratch folder inside the OpenCode 2 folder, then moves them into place with
    `opencode.db` last (a half copy never looks like a database). Never moves or deletes OpenCode 1's files. Any failure
    is swallowed, so the start is never blocked.
- `GET /api/experimental/migration/v1` is read by `Api2OperationsGateway.historyMigrationStatus()` (`HistoryMigrationGateway`).
  The phone page (`this_phone_screen.dart`) polls it while connected and shows one quiet line in the existing status row:
  "Bringing your earlier chats across (3 of 12)..." or, on `error`, "Your earlier chats could not be brought across. They are
  still safe in OpenCode 1." with the server text under the existing Details fold. `completed` shows nothing.
- No Kotlin change. `NativeServerRecipe.restorationScript()` (cold-start restore after Android kills the app) is untouched: the
  database already exists by then, so the copy would be a no-op there. Patchable with Shorebird.
- The Termux manager script changed, so its pinned hash in `test/builtin_linux_test.dart` and the dependent hashes in
  `test/fixtures/termux_script_hashes.json` were refreshed (only manager-bearing scripts changed).

## Live proof (build server, scratch dirs, ports 4301-4303, no model key)

1. OpenCode 1.19.0 (`opencode-ai@1.19.0`) served on 4301 with `HOME` in the scratch dir; one session created through
   `POST /session` ("switch-proof chat"). Its data folder held `opencode.db`, `-wal` (251 KB) and `-shm`.
2. OpenCode 1 stopped by exact PID (it needed a second TERM after 5 s; its WAL stays on disk after stop, which is why all three
   files are copied).
3. The generated snippet (extracted from the Dart constant, only the OpenCode 2 path pointed at the scratch dir) ran: exit 0, all
   three files present, byte-identical to OpenCode 1's (`cmp`). A second run was a no-op (md5 unchanged).
4. `@opencode/cli@2.0.29` served on 4302 with `XDG_DATA_HOME` on the copied folder: `GET /api/experimental/migration/v1` ->
   `{"status":"completed"}` on the first poll; `GET /api/session` listed `ses_ec61d58f... "switch-proof chat"` with its
   original directory; `/api/info` version 2.0.29.
5. Control (what the old switch did): 2.0.29 on an empty isolated folder -> `completed`, **0 sessions**.
6. Servers stopped by exact PID; all three ports closed. Logs holding the per-run password and the password file were deleted.

Not proven here: a large history (running progress labels), Android/proot itself (the snippet is plain `sh`, `cp`, `mv`,
`mkdir`), a database added after OpenCode 2 already marked the migration done (the guard skips it on purpose).

## Capability flags (2.0.29)

`gitInit`, `worktreeCreate`, `shellSettings` are true in `api2ServerCapabilities`. Each is covered by a gateway test against a
fake HTTP server (`test/api2_stable_flags_gateway_test.dart`): `POST /vcs/init?provider=git` (409 counts as done);
`POST /worktree {projectID, name}` -> `{directory}`; `GET /config/shell` + `GET /config` (last document with `info.shell` wins) and
`PATCH /experimental/config {shell}` that refuses any path not listed as `acceptable` and clears with `null`. Stale comments
(beta-18600, "reports no VCS", the `{strategy, directory}` worktree note) were rewritten.

## Tests

`test/opencode_history_copy_test.dart` (script placement before first start, the guard, the snippet run in a scratch home:
three files, db-only, no overwrite, no-op without a source; status mapping; page line; gateway path),
`test/api2_stable_flags_gateway_test.dart`. With the two script edits reverted the placement tests fail; with the Part 2 edits
reverted the flag assertions fail.
