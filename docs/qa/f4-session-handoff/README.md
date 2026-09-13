# F4 — Session handoff, phone ⇄ computer

Branch `feature/f4-session-handoff` (base `dev` 6c20ed7). Scope:
[docs/backlog/innovation-2026-09-06.md](../../backlog/innovation-2026-09-06.md) §F4.

## Finish line

- **F4-S1 · Continue on computer.** The chat session menu ("Session actions")
  gains *Continue on computer*: a sheet with the exact terminal command that
  resumes this session on the computer running the server, in the existing
  mono copy block, plus a pointer to the existing export/import route for
  moves between *different* servers.
- **F4-S2 · Open on another phone.** The same group gains *Open on another
  phone*: a QR (and the same link as text) of
  `opencode-mobile://session?profile=<id>&session=<id>`, carrying route
  identifiers only. Android registers a `VIEW` filter for that scheme; on
  receipt the app opens the exact session when the saved server exists
  locally, and shows an honest "not saved on this phone" state with a way to
  Servers when it does not. Nothing is ever sent, created or resumed on the
  user's behalf on any path.

## Non-goals

- Running the command from the phone (Termux, SSH) — copy only, per the
  backlog ("v2 has no TUI-navigation endpoint, so handoff is command-copy
  only").
- Moving a session between servers — that stays the existing export/import
  pair; the S1 sheet links to it instead of duplicating it.
- Identifying the *server* in the link (address, fingerprint). Profile ids
  are per-phone; see *Limitations*.
- Encoding a link anywhere other than the chat menu (no notification, widget
  or share-sheet emission).

## Verified CLI syntax

Both binaries are installed on this machine. The `opencode2` shim in
`~/.bun/bin` refuses to run ("postinstall script was not run"), so the
platform binary from `@opencode-ai/cli-linux-x64` was executed directly; it
self-updated between the first and second run (beta-19086 → beta-19242) and
prints identical flags in both.

```
$ opencode --version
1.18.25

$ opencode --help   (excerpt: the default TUI command and its session flags)
  opencode [project]           start opencode tui                                          [default]
Positionals:
  project  path to start opencode in                                                        [string]
  -c, --continue      continue the last session                                            [boolean]
  -s, --session       session id to continue                                                [string]
      --fork          fork the session when continuing (use with --continue or --session)  [boolean]
```

```
$ opencode2 --version
opencode2 v0.0.0-beta-19242        (first run printed v0.0.0-beta-19086)

$ opencode2 --help   (excerpt: usage and the session flags)
USAGE
  opencode2 <subcommand> [flags] [<directory>]
  directory string    Directory to start OpenCode in (optional)
  --standalone            Run with a private server instead of the background service
  --server string         Connect to a server URL instead of the background service
  --continue, -c          Continue the last session
  --session, -s string    Session ID to continue
```

`opencode run --help` (v1) and `opencode2 run --help` (v2) expose the same
`-s, --session` flag for the non-interactive runner; the sheet emits the
interactive form because "continue at my desk" means the TUI.

Derived command (both products, only the binary name differs):

```
cd '<session directory>' && opencode --session '<session id>'
cd '<session directory>' && opencode2 --session '<session id>'
```

Why `cd` rather than the positional: sessions are location-scoped in both
products, `cd` is unambiguous in any POSIX shell, and it keeps the worktree
case honest — a git-worktree session's `directory` *is* the worktree, so the
command lands in it. The directory is single-quoted (`'` → `'\''`) and was
exercised against bash with a path containing spaces and a quote. The session
id must match `^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`, so it can never be read as
a flag; the sheet shows an honest state instead when it does not.

Not offered (honest states in the sheet): no directory reported by the server;
control characters in the directory; an OpenCode 2 managed-workspace session
(`wrk_…`, whose folder belongs to the workspace host); and a Codex backend,
which has no `--session` CLI at all (new capability flag, see below).

## What changed

Product:

- `lib/domain/session_handoff.dart` — new pure unit: `SessionResumeCommand`
  (v1/v2 builders, quoting, unavailable reasons) and `SessionLink`
  (strict encode/decode of the deep link).
- `lib/ui/widgets/session_handoff_sheets.dart` — `ContinueOnComputerSheet`
  (reuses `AgentCommandBlock` for the mono copy block; pops `'export'` to
  hand over to the existing `SessionExportScreen`), `ContinueOnPhoneSheet`,
  and `SessionLinkQr` (a `CustomPainter` over the `qr` encoder; black on a
  white card with a 4-module quiet zone regardless of theme).
- `lib/ui/screens/chat/attention_card.dart` — two new rows in the
  "Session actions" group (`continue-computer`, `continue-phone`).
- `lib/ui/screens/chat_screen.dart` — dispatch for the two rows. The CLI name
  follows `serverFlavor` (copy only: "opencode" vs "opencode2"); availability
  follows the new `ServerCapabilities.cliSessionResume` (default true, false
  for Codex in `lib/codex/gateway.dart`). The export button is shown only
  when `capabilities.sessionImportExport` and the repository's
  `sessionExportSupported` both hold.
- `lib/platform/session_link.dart` — `SessionLinkIntent`, the Dart half of
  the new `oc/link` channel (`consumeSessionLink` on start, live `linked`
  pushes), mirroring `LaunchShortcut`. Parses strictly; malformed payloads
  never become pending.
- `lib/main.dart` — `_scheduleSessionLinkRoute`/`_openSessionForLink`:
  active server → `pushNamed('/chat/<id>')`; another saved server →
  `connect()` then home + chat (mirrors the servers screen tap); credential
  re-entry or a failed connect → Servers + notice; unknown server →
  `MaterialBanner` "not saved on this phone" with *Open Servers* / *Dismiss*;
  connection still settling → retained with a one-time "opening once the
  server connects" notice, re-evaluated on controller changes.
- **Manifest edit (expected by the backlog, recorded here):**
  `android/app/src/main/AndroidManifest.xml` adds one `intent-filter` on
  `MainActivity` — `VIEW` + `DEFAULT` + `BROWSABLE` with
  `<data android:scheme="opencode-mobile" android:host="session"/>`. No path
  prefix, no mime type. Confirmed present in the merged release manifest.
- `MainActivity.kt` — `captureSessionLink` accepts only `ACTION_VIEW` with
  that scheme/host, forwards the URI text (never extras), clears the intent's
  action and data before parking so a configuration change cannot replay it;
  `oc/link` channel with the same readiness handshake as `oc/shortcut`.
- `pubspec.yaml` — **one new dependency, `qr: 3.0.2`** (BSD-3-Clause, pure
  Dart, no platform plugin, no transitive deps; row added to
  `THIRD_PARTY_NOTICES.md`). Justification: nothing in the tree could *encode*
  a QR — `mobile_scanner` only decodes, and no `qr_flutter`/`qr` was present
  even transitively. `qr` was chosen over `qr_flutter` because the painter is
  ~40 lines in-repo and avoids a widget layer we do not need.
- Localization: 22 `handoffUi*` keys in `lib/l10n/app_en.arb`; Arabic in
  [messages_ar.json](messages_ar.json). `tool/assemble_arabic_arb.py` now
  lists this slice's fragment (its glob only covered `docs/qa/e7-*`).
  `python3 tool/assemble_arabic_arb.py` → `missing 0; placeholder mismatches
  0`; `flutter gen-l10n` regenerated the three `app_localizations*.dart`.

Tests (new):

- `test/session_handoff_domain_test.dart` — builders: v1/v2, spaces and
  metacharacters, embedded `'`, worktree directory, managed workspace
  unavailable, missing/blank/control-character directory, flag-like session
  ids; link round-trip, strict parse, 17 malformed shapes, oversize.
- `test/session_handoff_sheet_layout_test.dart` — both sheets at 320 dp in
  LTR, RTL (Arabic), 2.5x LTR and 2.5x RTL: no exceptions, copy targets
  ≥48 dp and inside the viewport, copying writes exactly the command / link,
  export pops `'export'` with nothing copied, honest states for managed
  workspace, missing directory (v1 naming) and an unbuildable link.
- `test/session_link_test.dart` — channel: cold-start drain once, live push,
  malformed never pending, missing plugin, inert off Android.
- `test/session_link_routing_test.dart` — shell routing: active server →
  exact `ChatScreen(sessionID)` with empty initial text and no create/prompt;
  unknown server → banner, *Open Servers* pushes `ServersScreen`, *Dismiss*
  leaves everything alone; another saved server → real `connect()` through
  fakes, profile switches, exact session opens, still no create/prompt;
  failed connect → Servers + notice; password re-entry → Servers + notice with
  the active connection untouched; malformed link never reaches routing.
- `test/session_link_native_contract_test.dart` — pins the manifest filter
  (exactly one `VIEW` filter, scheme/host, no path/mime widening) and the
  Kotlin contract (scheme/host constants, channel/method names, consume
  before park, readiness gate, only the URI text crosses).

Tests (extended): `test/chat_menu_hierarchy_test.dart` (both rows reachable,
also at 320 dp/2.5x LTR+RTL), `test/codex_chat_capabilities_test.dart`
(*Continue on computer* absent for Codex).

## Evidence

- `flutter analyze --no-pub` → No issues found.
- `dart format` on all changed Dart files.
- Focused + neighbouring tests, `flutter test --no-pub --concurrency=4`:
  `session_handoff_domain_test` (14), `session_handoff_sheet_layout_test`
  (13), `session_link_test` (5), `session_link_routing_test` (7),
  `session_link_native_contract_test` (5), `chat_menu_hierarchy_test`,
  `codex_chat_capabilities_test`, `launch_shortcut_routing_test`,
  `launch_shortcut_native_contract_test`, `share_intent_native_contract_test`
  → **+72, all passed**. Then `background_notification_navigation_test`,
  `share_intent_test`, `session_command_handoff_test`, `launch_shortcut_test`
  → +36 passed; `codex_gateway_test`, `api2_gateway_mappers_test`,
  `connection_v2_gateway_test` → +55 passed.
- Android: `gradle -p android :app:compileReleaseKotlin --no-daemon
  --max-workers=2 -Dorg.gradle.jvmargs=-Xmx2g` with JAVA_HOME =
  `/usr/lib/jvm/java-17-openjdk-amd64` → **BUILD SUCCESSFUL in 2m 31s**
  (foreground). The gitignored `android/gradlew` is absent in this worktree,
  so the wrapper's own distribution
  (`~/.gradle/wrapper/dists/gradle-9.5.0-all/…/bin/gradle`, the version in
  `gradle-wrapper.properties`) was invoked directly. `:app:processReleaseManifest`
  → BUILD SUCCESSFUL; the merged manifest carries the new filter.
- Shell quoting exercised for real: `cd '<scratch>/it'\''s here/My Projects'
  && pwd` resolved in bash.

## Limitations

- **Profile ids are per-phone.** The link's `profile` is the sending phone's
  saved-entry id (a timestamp minted at save time). Another phone resolves it
  only if it holds an entry with the same id, which today means the same
  phone (e.g. a link kept in notes/clipboard, or a second install that copied
  the profile list). A genuinely cross-phone match would need the link to
  identify the *server*; the backlog scopes the link to route ids and any
  server fingerprint needs a privacy review, so the receiver's "not saved on
  this phone" state with *Open Servers* is the honest behaviour for now.
- The resume command was verified from `--help` on both installed binaries,
  not by resuming a live session end to end; the sheet's footnote names the
  verified versions and tells the user to check `<binary> --help` for
  `--session` if theirs differs.
- `opencode2 --session` resolves against the background service (or
  `--standalone`); the sheet does not add either flag and does not claim which
  one the user's machine needs.
- Windows shells: the command is POSIX-quoted; PowerShell 7 accepts
  `cd '…' && …` but older PowerShell and cmd.exe do not. Copy says "terminal on
  the computer that runs this server" without promising a shell.
- Switching to another saved server on link receipt retires the current
  connection first, exactly as tapping that server in Servers would; a failed
  switch therefore leaves the app on the Servers screen with a notice rather
  than silently restoring the previous connection.
- No on-device QR scan of the app's own link was exercised (no emulator in
  this checkout); the QR is the `qr` encoder's module matrix painted at ≤240 dp
  with a 4-module quiet zone, which the pairing scanner's ML Kit backend reads
  routinely.
