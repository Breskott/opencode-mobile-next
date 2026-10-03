# Motion parts adopted across the app (2026-09-25)

## Scope

Closes the gaps that [motion-app-2026-09-25](../motion-app-2026-09-25/README.md)
left ("`KitRefresh`, `KitAnimatedRows` and `KitReveal` around notices are not adopted
in any screen yet"; the chat's raw `HapticFeedback`; celebrations on the ordinary
entrance; the unused `RetainedTabView`). Rules: design standard §10 (now with a
"Motion parts" paragraph) and the frozen kit (`lib/ui/kit/motion/*`,
`kit_illustration.dart`); the kit itself is unchanged. Out of scope (another agent
adopts there): `workspace_screen.dart`, `settings_screen.dart`,
`settings/plugins_screen.dart`, `screens/team/*`, `widgets/team_*`.

| Part | Where it is used now | What the person sees |
|---|---|---|
| **`KitRefresh`** (34 `RefreshIndicator`s replaced) | Terminals (list and empty), run result, session context, tools, review workspace (2), development services, Projects, session relations, usage, All conversations, saved permissions, project health, Inbox, active context, worktrees, Termux processes, Files (6), Library: skills (2), references (2), integrations, commands (2); managed workspaces; the chat's command launcher (2) | Pulling a list draws the portal in with the finger, the spark lands when armed, it breathes while reloading and shrinks away. Every screen reloads exactly what it did (same `onRefresh`, same `notificationPredicate` in the review workspace). |
| **`KitReveal`** | `ProductRefreshBody` (the "Couldn't refresh" banner of Terminals, Library commands/skills/references, review workspace); the run result's refresh banner; the terminal session's connection banner; the chat's one status line (connection, a message not sent, a prompt error, staged revert, subagent, sharing); Add server: the save failure, the connection check's verdict, Codex's verdict, the pairing notice and pairing failure, the missing-password notice; Servers: the connect failure over the list | These parts unfold in and fold away instead of pushing the page down in one frame. Always mounted (child `null` when hidden), so the content under them keeps its place and state: the run result's body used to be rebuilt when its banner was inserted above it. |
| **`KitAnimatedRows`** (only changes after the first paint animate) | Inbox: the requests waiting on the person (team gates, permissions, questions, forms, with their section label) and the running conversations; All conversations: the rows of each folder card (a search or a loaded page restarts the rows, so those show at once); Projects (a search restarts them); Servers: saved servers; Terminals: the session list; chat: queued and waiting messages (the strip is always mounted, so the first unfolds and the last folds away) | A request answered elsewhere, a server forgotten, a terminal removed fold away where they were; a new one unfolds in. |
| **`KitHaptics`** | Chat: `send(context)` on send (obeys Settings › Vibration), `done(context)` when a reply the person waited for finishes (was a raw `lightImpact`); setup ready: `done(context)` once when the screen arrives | A light tick on send; Android's soft CONFIRM on a finished reply and on setup ready. None under reduced motion for the finish. |
| **`KitMotion.celebration`** | Setup ready's `SetupReadyScene` (`PhoneSetupHero.entranceDuration`); Add server's "paired" moment (`ServersLinkState.linked`) | The finished moment draws in over 1.4 s instead of 0.9 s. |
| Removed | `lib/ui/widgets/retained_tab_view.dart` and `test/retained_tab_view_test.dart` (nothing used it); `tool/capture/motion_app_test.dart` keeps the old crossfade inline for its "before" strip | — |

Not adopted, on purpose: `KitAnimatedRows` on long lazily built lists (Files, the
chat transcript, the Work tab); a reveal on Termux setup's errors (a long wizard where
the error replaces a step, not a line over content).

## Builds

- Branch `ds/motion-adopt` from `2730891b` (feat/phone-setup-v2), with
  feat/phone-setup-v2 at `019f643a` merged in (kit effects: the Appearance choices
  that `KitMotion`, `KitIllustration` and `KitHaptics` obey).
- No APK, no emulator, no Gradle (other agents share the PC).

## Devices

None. Widget tests and rendered frames only (pinned Shorebird Flutter
`91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC).

## Runs

| # | Run | Expected | Actual |
|---|---|---|---|
| 1 | `test/motion_adopt_test.dart` (6 tests): pulling the terminal list draws the kit's disc (no stock spinner), reloads once, leaves nothing running; a failed refresh unfolds (mid-height between 0 and open at 100 ms), settles, the kept list gives way by exactly the banner's height, folds away after Try again; terminal rows show at full height on the first paint with no frame scheduled, a new one unfolds and a removed one folds away; a queued chat message present on open is at rest, one arriving unfolds; chat send ticks `lightImpact` and a finished reply gives `successNotification`; none under reduced motion | pass | PASS |
| 2 | `test/phone_setup_ready_screen_test.dart` (+1 test): the ready drawing's `entranceDuration` is `KitMotion.celebration`; one `successNotification` when the screen arrives, not repeated on typing; none under reduced motion | pass | PASS |
| 3 | Runs 1–2 on the pre-change product (`lib/ui/screens` and `product_states.dart` from `019f643a`) | the new behaviours fail | FAIL, 6 tests (`failing-first-without-change.txt`): no kit refresh indicator; no reveal around the refresh banner; no keyed animated terminal rows; no animated queued row; the finished reply gave `lightImpact` twice instead of `lightImpact` then `successNotification`; the ready drawing took 0.9 s, not 1.4 s |
| 4 | The 165 test files that import a changed screen or widget (`-j 2`) | pass | 7 tests failed first, all tests that looked or tapped in the same frame a part now unfolds or folds: `chat_live_events_test` (3: tap the status line's menu / Details right after it arrives; one place says the error while the status line is still folding), `chat_states_standard_test` (the dismissed "not sent" line), `first_run_welcome_test` and `server_codex_connect_flow_test` (a stale verdict gone in the next frame), `first_run_auto_test_test` (the Test button found while the verdict above it was still unfolding). No product bug: each now waits `KitMotion.standard` (or settles) before looking; all pass. |
| 5 | Full suite and analyzer | pass | PASS (below) |

### Final gate

PASS on `22a13f82` (the code of this branch; the commit after it adds only these
docs and design standard §10's paragraph):

- `flutter analyze lib test`: no issues.
- All 420 test files (`find test -name '*_test.dart' | sort`, split into 8 chunks,
  each `flutter test --no-pub -j 2`, run one after another), 976 s:

| Chunk | Files | Exit | Seconds |
|---|---|---|---|
| chunk_00 | 55 | 0 | 80 |
| chunk_01 | 51 | 0 | 91 |
| chunk_02 | 49 | 0 | 99 |
| chunk_03 | 52 | 0 | 103 |
| chunk_04 | 52 | 0 | 95 |
| chunk_05 | 50 | 0 | 174 |
| chunk_06 | 56 | 0 | 192 |
| chunk_07 | 55 | 0 | 142 |

No golden changed: every adopted part is instant on the first paint, so the resting
frames the goldens capture are the same.

## Evidence

- `failing-first-without-change.txt`: run 3.
- Frame strips (412 × 915 dp at half size, dark, time above each frame), before and
  after, drawn by `tool/capture/motion_adopt_test.dart` with the same widgets the
  screens use:
  - `before-pull-to-refresh.png` / `after-pull-to-refresh.png`: the stock Material
    spinner vs the portal drawing itself in with the pull (16–64 ms), breathing while
    it reloads, shrinking away when done.
  - `before-refresh-failure.png` / `after-refresh-failure.png`: the banner arrives in
    one frame and the list jumps 50 dp vs the banner unfolding over 250 ms with the
    list following.
  - `before-row-arrives.png` / `after-row-arrives.png`: the new terminal row appears
    and pushes the rest down at once vs unfolding and fading in (half height and faint
    at 100 ms, settled at 250 ms).
  The single frames are regenerated under `frames/` and not committed.

## Measure on a device (coordinator)

Profile or release build of the merged branch, on the emulator used for issue #87
(and the owner's phone if possible), same data and build type as the `dev` baseline:

```sh
PKG=<applicationId>
adb shell dumpsys gfxinfo $PKG reset
# … do the scenario …
adb shell dumpsys gfxinfo $PKG > gfx-<scenario>-<before|after>.txt
# Record: Total frames rendered, Janky frames (%), 50th/90th/95th/99th percentile,
# Number Slow UI thread, Slow issue draw commands.
```

| # | Scenario | What to do | Pass |
|---|---|---|---|
| 1 | Pull to refresh | Inbox, All conversations, Terminals, Library › Skills: pull slowly to arm, release, 5 times each. | Janky % and p90 no worse than before; no frame > 32 ms while the disc follows the finger (one small layer repaints; the list is untouched). |
| 2 | Refresh failure | Stop the server, pull Terminals (or Library › Commands) to get "Couldn't refresh", restart it, tap Try again; 5 times. | The banner unfolds and folds without a jump; p90 no worse; no frame > 32 ms during the 250 ms. |
| 3 | Rows arriving | Inbox open while a conversation asks a permission and it is answered on another device; Servers: add a server then forget it; Terminals: start and remove one; chat: send two messages while a reply runs (queued), then let them go. | Each row unfolds/folds in 250 ms; Janky % no worse than the same actions on `dev`. |
| 4 | All conversations | Scroll to the end so a page loads; type a search. | The page and the search results appear at once (no animation), scrolling unchanged from `dev`. |
| 5 | Chat status line | Stop the server with a chat open (wait 8 s for "isn't answering"), restart it. | The line unfolds and folds; the transcript scroll is not disturbed. |
| 6 | Haptics | Send a chat message; let a reply finish; finish phone setup (ready screen); pair a server. | A light tick on send; a soft confirmation on a finished reply and on setup ready (Android 11+). None with Remove animations on (finish) or with Settings › Vibration off (both). |
| 7 | Reduced motion | Remove animations on; repeat 1–3. | Everything appears and leaves at once; the pull disc still follows the finger but does not breathe. |

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 2 test/motion_adopt_test.dart test/phone_setup_ready_screen_test.dart
# Failing first: the pre-change screens, the same tests
git checkout 019f643a -- lib/ui/screens lib/ui/widgets/product_states.dart
$F test -j 2 test/motion_adopt_test.dart test/phone_setup_ready_screen_test.dart  # 6 fail
git checkout HEAD -- lib/ui
# Frames and strips
$F test --concurrency=1 tool/capture/motion_adopt_test.dart
python3 tool/capture/motion_strip.py docs/qa/motion-adopt-2026-09-25
```

## NOT proven

- **Nothing on a device.** No frame timing, no `gfxinfo`, no haptic felt: the table
  above is for the coordinator. "No dropped frames" is a design claim (a clip and one
  small part's height; rows keep their width, so they are not laid out again), not a
  measurement.
- Pull to refresh is driven by a real drag in one test (Terminals); the other 33
  sites call the same `onRefresh` through `RefreshIndicator.noSpinner`, which the
  existing tests of those screens exercise.
- The servers list, Inbox, All conversations and Projects row motions are covered by
  their screens' existing tests (which still pass) and by the part's own tests in
  `test/kit_motion_app_test.dart`, not by a new animation assertion per screen.
- Add server's "paired" celebration length is set but not asserted by a test.
- The workspace, settings, plugins and AI Team screens are another agent's adoption.
