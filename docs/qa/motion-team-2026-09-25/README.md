# AI Team: drawings and moments (motion slice D, 2026-09-25)

## Scope

- **Spec:** [`docs/design/motion-and-illustration-2026-09-25.md`](../../design/motion-and-illustration-2026-09-25.md), slice D; design standard §10.
- **Why:** the owner, on build 2052/2053: "be more creative — add animations, cool graphics … they could even move". The AI Team is the app's most characterful part, and every one of its waiting, empty and finished moments was the same icon in a tonal circle.
- **What this changes:** presentation only. The gateway, the data paths, the redesign's words and order ("Needs you" first; engine words only under Technical details) are unchanged. No new strings.

### The cast

A few line-drawn agents in the brand's stroke: a round head, a domed body, two dot eyes and nothing more. One accent for what matters (the planner, the empty slot, the agent who needs you), muted outlines for the rest, soft accent washes for fills. Drawn in code as `KitScene`s, so they follow dark and light and scale.

| Moment | Where | Drawing | Moves |
|---|---|---|---|
| No tasks yet | Home, the empty state (inline, 88 dp) | `TeamBoardScene`: three agents gathered at an empty board whose one accent slot (a "+" card) waits for a task | Draws in once (the board, its columns, the agents arriving one by one, the slot, a wave); then still |
| The planner planning ("Planning the steps…") | The planning card on the home | `TeamPlanningScene`: the planner (accent) and a teammate pass the task's card between them, eyes following it | Ambient while waiting; only the first card moves (one loop per screen). The board steps aside while a card is planning |
| The team starting | Home / run / agent state "The team host is starting" (page, 140 dp); the in-app AI Team section in Settings › Plugins while it turns on or starts; the Termux "On this phone" section while it starts | `TeamWakingScene`: three agents on a line whose eyes open under a spark that powers on | Ambient while starting: they breathe in turn, blink, and the spark's rays pulse |
| A task merged | The task's Overview, at its head (176 dp) | `TeamMergedScene`: the card drops in with a check, sparks fly out, both agents throw their arms up with happy eyes | Once per task, ever: remembered per profile under `oc.orchestration.<profileId>.celebrated` (also when the task merges while the Overview is open) |
| Needs you | The "Needs you" heading on the home and the task Overview | `TeamNudgeScene`: an agent (accent) rises from behind the block's top edge and waves | The wave plays the first time a question shows in this session (again for a new question); after that the agent stands still, hand up. Never a loop |
| No agents | Agents list, the empty state (inline) | `TeamRestScene`: one agent dozing, with its z's | Draws in once |
| Nothing running | Work tab card's one line | `TeamIdleScene`: two agents at ease, turned to each other (34 dp) | Draws in once |

### Files

| File | What |
|---|---|
| `lib/ui/kit/scenes/team_scenes.dart` (new) | `TeamCast` (the agent, a card, a spark stroke) and the seven scenes. Paths are built once (static); only transforms and paint change per frame |
| `lib/ui/widgets/team_moments.dart` (new) | `TeamCelebrations` (the once-per-task memory), `TeamMergedCelebration`, `TeamNeedsYouLabel` (the heading with its nudge) |
| `lib/ui/screens/team/team_home_screen.dart` | The empty state's drawing, the Needs-you heading, which planning card moves |
| `lib/ui/screens/team/start_run_sheet.dart` | The planning card's drawing (`TeamPlanningCard.ambient`) |
| `lib/ui/screens/team/run_screen.dart` | The celebration and the Needs-you heading on the Overview |
| `lib/ui/screens/team/team_states.dart` | "The team host is starting" wakes the team (ambient) |
| `lib/ui/screens/team/team_agents_screen.dart` | The agents list's empty drawing |
| `lib/ui/widgets/team_card.dart` | "Nothing running" with its small drawing |
| `lib/ui/widgets/builtin_team_section.dart`, `team_phone_section.dart` | The waking drawing beside the stage while the team starts on the phone |
| `test/support/team_golden_fixture.dart` | `TeamScene.starting`; shots `homeStarting`, `runMerged`, `cardIdle` |

### Decisions

- **Persistence and deletion.** The celebration memory is a string list under `oc.orchestration.<profileId>.celebrated` (the last 100 task ids). `ProfileStore.profileScopedPreferenceKeys` matches it (the `.<profileId>.` infix), so deleting the profile removes it, and it sits under the plugin's `oc.orchestration.<profileId>.` prefix, so turning AI Team off (`OrchestrationStore.sweep`) removes it too. No edit to `lib/state/connection.dart` was needed. Both are asserted in `test/team_motion_test.dart`.
- **The nudge's memory is this session only:** a question that waved once does not wave again until the app restarts. Persisting it would add a key per question for a small gain.
- **Durations.** Every drawing's entrance is `KitMotion.entrance` (900 ms) through `KitIllustration`, including the celebration: `KitIllustration` (frozen) has no celebration duration, and a second player just for it would duplicate the reduced-motion and ticker rules. Loops are `KitMotion.breath` (4 s).
- **Inline size.** Inline `KitStateView` drawings are 88 dp (the kit's size); the board scene is drawn with big, simple shapes to read at that size.
- **The empty home while a task is being planned** shows the planning card's drawing only (the board would be a second drawing saying the opposite).

## Builds

- **Branch:** `ds/motion-team`, from `feat/phone-setup-v2` at `cf1d7464`.
- **APK:** none built for this record.

## Devices

None. Tests, goldens and renders only.

## Runs

| # | Check | Expected | Actual |
|---|---|---|---|
| 1 | `test/team_motion_test.dart` on the old screens (the modified `lib/` files at `cf1d7464`, the new scene and moment files present), `tests-without-fix.txt` | The drawing for each state is missing | FAIL, 10 of 13 (the 3 that pass there: a failed host keeps its icon, the nudge's own widget test, and the working task not celebrating). The `ambient:` argument was dropped from that one run's copy so it compiles |
| 2 | `test/team_motion_test.dart` | Board for no tasks (still); waking for the host starting (ambient) and not for other failures; planning card moves, only the first, none for a refused one; the planning card moves and the board steps aside after "Give the team a task"; a merged task celebrates once, not on reopening, not after a restart, key swept by profile deletion and plugin off; a working task does not; the celebration settles with loops on; the nudge waves the first time and not again, stops by itself with loops on, waves again for a new question; reduced motion: nothing moves; rest for no agents; idle on the card | PASS (13) |
| 3 | Scene goldens `test/goldens/team_scenes_golden_test.dart` | Seven scenes, finished frame, dark and light | PASS (14 new goldens, each looked at) |
| 4 | Team goldens `test/goldens/team_golden_test.dart` | New: `team_home_starting`, `team_run_merged`, `team_card_idle`. Changed on purpose: `team_home_empty` (board), `team_home_loaded`, `team_home_loaded_phone`, `team_run_overview`, `team_start_run` (the nudge by "Needs you") | PASS after regeneration; every changed image looked at |
| 5 | Every `test/*team*_test.dart`, `test/goldens/team_*_golden_test.dart`, `design_standard`, `kit_illustration`, `ui_ledger_coverage`, `ui_glossary`, `aiteam_component`, `work_parts` goldens, `-j 2` | All pass | PASS, +853 −0 (48 files) |
| 6 | `flutter analyze lib test` | No issues | No issues |

### Suite result

48 files, `-j 2`: every `test/*team*_test.dart` (the builtin and Termux
section tests included), `test/goldens/team_*_golden_test.dart`,
`design_standard`, `kit_illustration`, `ui_ledger_coverage`, `ui_glossary`,
`aiteam_component` and `test/goldens/work_parts_golden_test.dart`:
**+853 −0**, 3 min 10 s. No existing expectation changed; the only changed
existing files are the five goldens of run 4, regenerated on purpose.
`flutter analyze lib test` and the two capture tools: no issues.

## Evidence

- **Before / after at 412 × 915**, dark and light (`before-N-*`, `after-N-*`):
  1. `home-empty`: the icon circle → the team at the board;
  2. `home-needs-you`: the agent peeking over the question block;
  3. `planning`: the planning card with the card-passing agents (the board steps aside);
  4. `home-starting`: "The team host is starting" with the team waking;
  5. `run-merged`: the merged task's celebration;
  6. `run-needs-you`: the nudge on a task's Overview;
  7. `card-idle`: the Work tab card's "Nothing running".
- **Frame strips** (`frames-<scene>-<dark|light>.png`): each scene's entrance at 0–100 % and, for the two that wait, three moments of the loop. The movement as stills.
- **`tests-without-fix.txt`:** run 1's output.
- **Goldens:** `test/goldens/team_scene_*`, `team_home_starting_*`, `team_run_merged_*`, `team_card_idle_*`.

## How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test test/team_motion_test.dart
$F test test/goldens/team_scenes_golden_test.dart test/goldens/team_golden_test.dart
$F test --concurrency=1 tool/capture/team_motion_frames_test.dart
$F test --concurrency=1 tool/capture/motion_team_test.dart
# before: with the modified lib/ files checked out at cf1d7464
$F test --concurrency=1 --dart-define=TEAM_MOTION_CAPTURE=before \
  tool/capture/motion_team_test.dart
```

## NOT proven

- **On a device:** no phone or emulator run, no video, no `dumpsys gfxinfo` of the loops (the planning card and the waking team are the two ambient loops). The coordinator's integrated run covers these.
- **The in-app and Termux sections' waking drawing** is covered by the widget code and the existing section tests only; no render of them was made (they need the in-app runtime or Termux faked while starting).
- **The agents list's empty drawing** has a golden of the scene and a behaviour test, but no 412 × 915 render.
- **Arabic and large text** only through the existing team layout tests.
