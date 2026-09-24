# Empty, quiet and failure moments drawn (2026-09-25)

## Scope

Spec: [`docs/design/motion-and-illustration-2026-09-25.md`](../../design/motion-and-illustration-2026-09-25.md),
slice **C: Empty and quiet states**, on the foundation of design standard §10
([`design-standard.md`](../../design/design-standard.md)). The owner: "be more creative —
add animations, cool graphics that you create with svgs or whatever (they could even move
etc)". Earlier screens were "very ugly" and "adhoc".

### The drawings (new, `lib/ui/kit/scenes/`)

One drawing per kind of state, reused wherever the state is the same. Line art in the
brand's stroke on one soft accent wash, muted outlines, the accent for the one thing that
matters. Each draws itself in once (`KitMotion.entrance`, 900 ms) and then rests; none of
them loops. Goldens: `test/goldens/states_<name>_{dark,light}.png`.

| Drawing | Class | Entrance | Used for |
|---|---|---|---|
| Folded sheet with a block caret on its last line, a spark | `StatesSheetScene` | the sheets draw, the lines write in, the caret appears, the spark pops | no conversations yet: Work, All conversations, a new chat |
| Open folder with a spark rising out of it | `StatesFolderScene` | the folder draws, the spark rises and settles | no project yet (Work's folder chooser, "no projects" inline), an empty folder (Files) |
| Inbox tray, a sheet settling into it, a check | `StatesTrayScene` | the sheet drops in with a small give, the check draws itself | Inbox all caught up |
| Magnifier resting on a blank part of a page | `StatesSearchScene` | the page draws, the magnifier slides in and lands | a search with no match (All conversations, Files, Symbols) |
| Terminal window with `>_` | `StatesTerminalScene` | the window draws, `>` writes, the cursor blinks twice and rests lit | no terminal on the server, This phone's terminal not set up |
| The same window, dimmed (`ended: true`) | `StatesTerminalScene` | as above, no live cursor | a shell that ended |
| A plug pulled from its socket, a small spark in the gap | `StatesUnpluggedScene` | the cables draw, the plug eases back with a give, the spark ticks appear | not answering, could not load (Work, All conversations, Files, server Terminal, Chat, Inbox "status incomplete") |
| The brand's brackets, small, a spark travelling inside | `StatesWorkingScene` (48-unit box) | brackets draw, spark lands; **while a reply streams** the brackets breathe a unit and the spark circles, one breath (`KitMotion.breath`, 4 s) per loop | the chat's working mark beside Stop |

Shared parts (`states_parts.dart`): the wash, the folded sheet and its flap, the
four-pointed spark, short tick strokes.

### What changed on screen

| # | State | Before | After | Where |
|---|---|---|---|---|
| 1 | Work, no conversations yet | chat icon in a tonal circle | the folded sheet (inline, 88 dp) | `workspace_screen.dart` |
| 2 | Work, no project yet | folders icon in a circle | the open folder (140 dp); a project list that failed is the unplugged cable | `_WorkspaceFolderChooser` |
| 3 | Work, not answering with nothing listed | placeholder rows forever under "… isn't answering" | placeholder rows for the 8 s grace, then the unplugged cable, "Your conversations will be back / They show here again as soon as the server answers." (new strings, en + ar); the status line above keeps Restart / Try again | `_firstLoadRows` (the same `GraceTimer` rule as the status line) |
| 4 | Inbox, all caught up | a check-circle icon | the tray with the settling sheet (140 dp); "status incomplete" is the unplugged cable | `activity_screen.dart` `_ActivityStatus` |
| 5 | All conversations, none yet | centred icon, text and a tonal Refresh | `KitStateView` with the sheet, Refresh as a tertiary | `global_sessions_screen.dart` |
| 6 | All conversations, no match | centred icon, tonal Clear search | the magnifier, Clear search as the secondary | same |
| 7 | All conversations, could not load | red icon, the raw error, tonal Try again | the unplugged cable, "Couldn't load conversations", the reason under it, Try again (primary), Report a bug | same |
| 8 | Files, empty folder / no match / no symbols / could not load | `ProductEmptyState` / `ProductErrorState` icons | the open folder / the magnifier / the magnifier / the unplugged cable ("Couldn't open this folder", "Couldn't search symbols") | `files_screen.dart` |
| 9 | Terminal (server), none yet / could not list | terminal icon, tonal New terminal / red error | the terminal window, New terminal as the secondary / the unplugged cable, "Couldn't list the terminals" | `terminal_screen.dart` |
| 10 | This phone's terminal, not set up | terminal icon in a circle | the terminal window (140 dp) | `local_terminal_screen.dart` |
| 11 | This phone's terminal, shell ended | terminal icon (inline) | the dimmed terminal window (inline, 88 dp) | same |
| 12 | Chat, empty conversation | project name, caret, facts, tip, starters | the same, with the folded sheet (88 dp) above the name when there is room; the compact (keyboard-up) line has none | `chat/empty_chat.dart` |
| 13 | Chat, could not load | error icon in a circle | the unplugged cable | `chat/chat_states.dart` |
| 14 | Chat, a reply being written | a gradient sweeping round the composer's border and a breathing glow (3.6 s, outside `KitMotion`) | the drawn working mark (28 dp) beside Stop moves; the ring stays lit and still, so the screen has one ambient loop; "Assistant is working" is still announced by the ring | `chat/composer.dart` `_WorkingMark`, `_ComposerActivity` |

Presentation only: no state, navigation or copy changed except the five new titles/lines
(rows 3, 7, 8, 9). The retry, clear-search and report-a-bug actions do what they did.

### Decisions

- **"Could not load" is the unplugged cable too.** The load failures on these screens come
  over the connection ("OpenCode is unreachable"); one drawing for "the server did not
  give it" reads the same everywhere. The file viewer's error keeps `ProductErrorState`
  (its failures are about the file, not the connection).
- **The Inbox is `activity_screen.dart`.** The brief's write set names
  `attention_overview_screen.dart` (Server attention); the spec's "Inbox: all caught up"
  lives in `activity_screen.dart` (`_ActivityStatus`), which no other slice owns. Only
  that widget changed. Server attention's "No saved servers" keeps its icon: none of the
  state drawings means "no servers" (slice B draws servers).
- **The terminal blinks within its entrance.** A resting state must not loop, so the
  cursor's "blinking prompt" is two blinks inside the 900 ms entrance, ending lit.
- **The composer ring stopped sweeping.** §10 allows one ambient loop per screen; the
  drawn mark is the loop and uses `KitMotion.breath`. The ring keeps its colour and glow.
- **`product_states.dart` is unchanged.** Routing `ProductEmptyState` to a drawing would
  have to guess a drawing from an icon for 20 other screens; the screens in this slice
  use `KitStateView(illustration:)` directly.

## Builds

- Branch `ds/motion-states` from `feat/phone-setup-v2` @ `cf1d7464` (the §10 foundation).
  Commits listed by `git log cf1d7464..ds/motion-states`. No APK built.

## Devices

None. Widget tests and rendered images only (`flutter test`, pinned Shorebird Flutter
`91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC).

## Runs

| # | Step | Expected | Actual |
|---|---|---|---|
| 1 | Each screen state above in a widget test (`test/motion_states_test.dart`) | the drawing for its kind of state (`KitIllustration.scene`) | PASS (15) |
| 2 | Work tab with loops allowed (`KitMotion.loops = true`), no conversations | the entrance plays and nothing keeps running | PASS |
| 3 | Work tab reconnecting with nothing listed: 0 s, then 9 s | placeholder rows, no drawing / no rows, the unplugged state and its words | PASS |
| 4 | Chat busy with loops allowed, then the run ends | the mark is ambient and animating / the mark is gone and nothing runs | PASS |
| 5 | Chat busy under reduced motion | the mark is shown, nothing runs | PASS |
| 6 | Scenes (`test/kit_states_scenes_test.dart`): 8 goldens × dark/light; a resting scene stops after its entrance with loops allowed; the working mark loops only when allowed; the terminal's cursor is off before it arrives, off in both blinks, lit in the finished frame, never lit when ended | as stated | PASS (20) |
| 7 | `test/design_standard_test.dart`: the scene files have goldens; `ProductErrorState(`/`ProductEmptyState(` do not come back to All conversations and the server Terminal; scene files hold no ticker, timer or controller of their own | clean | PASS |
| 8 | Rows 1-5 against `cf1d7464` (the scene files and the tests copied in) | fail | FAIL as expected: 15 of 15 ([tests-without-fix.txt](tests-without-fix.txt)) |
| 9 | Goldens that changed, regenerated and looked at: `work_empty`, `work_chooser`, `shell_reconnecting` (Inbox with "status incomplete"), `chat_empty`, `chat_load_error`, `chat_permission` (busy composer: mark, still ring), dark + light | deliberate | looked at, kept |
| 10 | Every test file that covers the touched screens, the l10n and the design standard (200 files, `-j 2`) | pass | PASS: 2751 passed, 13 skipped ([tests-with-fix.txt](tests-with-fix.txt)) |
| 11 | `flutter analyze lib test` | clean | PASS |

## Evidence

- `before-N-<state>-<theme>.png` / `after-N-<state>-<theme>.png`: the same state rendered by
  `tool/capture/motion_states_test.dart` on `cf1d7464` and on this branch, 412×915, dark
  and light, real fonts: 1 Work empty, 2 Work no project, 3 Work not answering with
  nothing listed (after 9 s), 4 Inbox all caught up, 5 All conversations none yet,
  6 no match, 7 could not load, 8 Files empty folder, 9 server Terminal none,
  10 This phone's terminal not set up, 11 shell ended, 12 Chat empty, 13 Chat could not
  load, 14 Chat with a reply being written (the mark beside Stop).
- `test/goldens/states_{sheet,folder,tray,search,terminal,terminal_ended,unplugged,working}_{dark,light}.png`:
  each drawing's finished frame.
- [tests-with-fix.txt](tests-with-fix.txt), [tests-without-fix.txt](tests-without-fix.txt).

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 2 test/motion_states_test.dart test/kit_states_scenes_test.dart \
  test/design_standard_test.dart test/goldens/work_tab_golden_test.dart \
  test/goldens/work_parts_golden_test.dart test/goldens/chat_states_golden_test.dart
# Renders (after):
$F test --concurrency=1 tool/capture/motion_states_test.dart
# The old code: export it, add the scene files and the new tests, run them.
git archive cf1d7464 lib test tool assets packages pubspec.yaml pubspec.lock l10n.yaml \
  analysis_options.yaml LICENSES shorebird.yaml PRIVACY.md THIRD_PARTY_NOTICES.md \
  | tar -x -C "$OLD"
cp lib/ui/kit/scenes/states_*.dart "$OLD/lib/ui/kit/scenes/"
cp test/motion_states_test.dart test/kit_states_scenes_test.dart "$OLD/test/"
cp tool/capture/motion_states_test.dart "$OLD/tool/capture/"
(cd "$OLD" && $F pub get &&
  $F test --concurrency=1 --dart-define=MOTION_STATES_CAPTURE=before \
    tool/capture/motion_states_test.dart &&
  $F test test/motion_states_test.dart)   # fails: no drawings on the old screens
# Goldens, deliberately:
$F test --update-goldens test/kit_states_scenes_test.dart \
  test/goldens/work_tab_golden_test.dart test/goldens/work_parts_golden_test.dart \
  test/goldens/chat_states_golden_test.dart
```

## NOT proven

- **On device:** no emulator or phone run, no APK. The entrances, the terminal's blink and
  the working mark's loop were checked frame by frame in tests and in still renders only;
  their feel at 60/120 Hz and any `gfxinfo` cost are the coordinator's integrated run.
- The working mark is 28 dp; at 1× in the renders it is small. Its legibility at the
  phone's density was not seen.
- The Arabic strings for the six new keys are the agent's translation, not reviewed by a
  native speaker. RTL renders were not made (the drawings are not mirrored; none has a
  reading direction except the terminal prompt, which stays LTR like a terminal).
- Server attention's "No saved servers" and the file viewer's error keep their icons.
- `docs/design/ui-ledger/ledger.json` was not regenerated; the part file
  `e-workspace.json` carries the changed All conversations rows.
