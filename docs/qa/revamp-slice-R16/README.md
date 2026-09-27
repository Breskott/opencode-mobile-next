# revamp-slice-R16: R16 Account, demo, capabilities, note and context pages say things once (2026-09-27)

## 1. Scope

- Unit: `slice-R16` (wave 3, tier 1, screen-revamp). Finish line: the Codex
  account, offline demo, Available on this server, Note for the agent and
  Active context pages each say every thing once, and every action names
  what it acts on. Non-goal: new backend calls (Codex sign-out, per-feature
  "get it" flows); chat files.
- Files changed: `lib/demo/demo_copy.dart`,
  `lib/ui/screens/{active_context,agent_account,demo,server_capabilities,session_note}_screen.dart`,
  `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`),
  `test/r16_says_things_once_test.dart` (new), and expectation updates in
  `test/{active_context,demo_isolation,server_capabilities_screen,session_note}_test.dart`.
- Pages (map ids): agent-account, demo, server-capabilities, session-note,
  session-note-discard-dialog (unchanged), active-context,
  active-context-message.
- Specs followed: STANDARDS.md KIT-33 (technical notes in one Details fold),
  COPY-30 (KitBidi on names), LAY-8 (Close at the end), PROC-13 (ARB key
  delete only when every reference is in the write set); owner rules
  2026-09-27 (nothing shown twice, actions name their target, English only).
- Contract problems (PROC-20):
  1. PROC-13 says never commit `lib/l10n/app_localizations*.dart`; this
     unit's task text says "run gen-l10n and commit the generated files".
     Followed the task text (newer). Integrator: regenerate after merge.
  2. `test/server_capabilities_screen_test.dart` "no backend name appears in
     the words of the screen" conflicts with the R16 acceptance copy
     "Missing features work on other OpenCode servers." The new key
     `capabilityScreenIntroWithGaps` is left out of that list with a comment
     (the kit's own "Works on …" line already names hosts).
  3. "The X means 'Leave demo'": `KitTopBar`'s Close exit always reads
     "Close" (`kitTopBarClose`) and has no label parameter; changing
     `kit_top_bar.dart` is outside this write set. The demo therefore uses
     `exit: none` plus one top-bar action "Leave demo" with the close icon
     (sits at the end, where Close sits). Proposed: an optional
     `exitLabel` on `KitTopBar`, then the demo returns to
     `exit: KitTopBarExit.close, exitLabel: l10n.demoScreenLeave`.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - agent-account: signed-out note shown twice → done
    (`r16…` "Codex account: the sign-in note is said once"); unsupported
    detail shown twice (body + Details) → done (same change); actionsMissing
    "sign out" → deferred: `AgentAccountController`/gateway have no sign-out
    call (no owner); "copy device code" → already present.
  - demo: set-up menu item removed, X = Leave demo, Reset on the status line,
    disclosure without "Nothing is saved." → done (`r16…` "demo: the X
    leaves the demo…"). statesMissing "keyboard hides Set up" → no longer
    applies: Leave demo is always reachable and returns to the servers page
    where setup starts.
  - server-capabilities: hosts line once → done (`r16…` three
    "capabilities:" tests); actionsMissing "per missing feature: update
    server, switch server…" → only "Add a server that has these" (existing,
    capability-gated); the rest deferred (no enable flows registered).
  - session-note: Save only when changed, sessionNoteUnchanged deleted,
    Delete saved note stays → done (`r16…` "note: Save note appears only…").
  - active-context: intro reworded, count line dropped → done (`r16…`
    "active context: plain intro…"); active-context-message: "{Role}
    message" title, disclaimer into Details → done (same test + golden).
- Moved or removed items (owner rule 2026-09-27):
  - demo: "Set up your own server" top-bar menu item removed (duplicate of
    the finished notice and of the X); "Reset demo" moved from the top bar
    to the demo's status line ("Simulated · nothing is saved"), which is
    about the same demo; the X became "Leave demo".
  - agent-account: `agentAccountSignInNote` and
    `agentAccountUnsupportedDetail` removed from the Details fold (each is
    already the page body in its state).
  - server-capabilities: per-row "Works on …" removed where it matched the
    most common answer; the intro says it once.
  - session-note: disabled "Save note" with "Change the note to save it."
    removed while nothing changed.
  - active-context: "N messages" caption removed (the search field counts
    results; the filter menu says "All messages · N"); message disclaimer
    moved into Details.
- States per page (STATE-20): unchanged from base except as above; covered
  by the existing page tests (loading, error, empty, changed) and the R16
  tests/goldens for the changed states.
- Deferred states (STATE-21): none new.

## 2. Builds

- Branch `revamp/slice-R16`, base `643a5104`, code head: see `git log`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 3
checkpoint record.

## 4. Runs

See the build record returned to the coordinator (owner decision
2026-09-27: only this unit's new test file is run, once).

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/r16_says_things_once_test.dart` behaviour group | passes | 7 passed | PASS |
| 2 | `test/r16_says_things_once_test.dart` gallery (`--update-goldens`, then looked at) | renders | 16 rendered, all opened and looked at | PASS |
| 3 | `flutter analyze` on the changed files | no issues | no issues | PASS |

Not run (owner decision): the edited shared page tests
(`active_context_test`, `demo_isolation_test`, `server_capabilities_screen_test`,
`session_note_test`, `agent_account_widget_test`), ratchet, design-standard
and l10n tests.

## 5. Evidence

- Changed test expectations (TEST-19):
  - `session_note_test` "repository replacement disables a stale note
    review": disabled Save → no Save at all (nothing edited).
  - `active_context_test` staged revert: "1 message"/"3 messages" captions →
    row keys (count line dropped).
  - `server_capabilities_screen_test` "one list…": files row "Works on"
    findsOneWidget → findsNothing; worktrees row has it; intro sentence once.
  - `demo_isolation_test`: `DemoCopy.exit/reset/disclosure` → "Leave demo"
    tooltip, `demo-reset` key, disclosure literal.
- Goldens (new, this unit's own; account uses a fixed "Last checked"): `test/goldens/r16_{account_signed_out,
  capabilities_codex,note_unchanged,context_message}[_1280x800]_{dark,light}.png`.
- Golden drift in other units' files (not regenerated, R07):
  `test/revamp/goldens/system_server_capabilities*` (intro sentence, fewer
  "Works on" lines) and any screen-chat/usage golden that renders these
  pages.
- Accessibility: "Leave demo" and "Reset demo" are labelled actions (was an
  unlabelled "Close" and a top-bar icon); no new controls without labels.
- Privacy and security: n/a: no credentials, stored data, links or
  notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/r16_says_things_once_test.dart
$F analyze lib/ui/screens lib/demo test/r16_says_things_once_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The edited shared page tests were updated by reading, not run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/slice-R16` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | `revamp/slice-R16` |
| Deployed | No | |
| Released | No | |
