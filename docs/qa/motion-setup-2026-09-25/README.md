# Motion and illustration, slice A: setup and connecting (2026-09-25)

## Scope

The owner, on build 2052/2053: "be more creative — add animations, cool graphics that you
create with svgs or whatever (they could even move etc), etc, be creative!". Slice A of
[`docs/design/motion-and-illustration-2026-09-25.md`](../../design/motion-and-illustration-2026-09-25.md),
on the frozen foundation of design standard §10 (`KitMotion`, `KitScene`,
`KitIllustration`, `KitPortalScene`). Also ledger rows 1, 2 and 16 of
[`design-regressions-2026-09-24.md`](../design-regressions-2026-09-24.md), and the
coordinator's addition from the owner's phone after setup (the ready screen with the
folder sheet's second name field on top: "Why not browse folders here").

Presentation only: the setup engine, its steps, Cancel, Continue, resume and errors are
unchanged.

### The drawings (new files, `lib/ui/kit/scenes/setup_*.dart`)

One family with the portal: line art in the brand's stroke, one accent, muted and
hairline for the rest, accent washes; drawn in code, so dark and light and any size.

| Scene | What it shows | How it moves |
|---|---|---|
| `SetupPhoneScene` (`fresh`) | A phone on a soft wash; its screen lights, a `>_` prompt types, the portal draws itself on the screen, sparkles pop. | Entrance once (900 ms), then still. |
| `SetupPhoneScene` (`starting`) | The same phone with the portal. | While waiting: the portal breathes, its spark circles, the cursor blinks, a dot orbits the phone. |
| `SetupPhoneScene` (`termux`) | The phone's screen as a terminal, the last line lit. | Entrance once. |
| `SetupPhoneScene` (`ready`) | A larger portal on a lit screen. | Entrance once. |
| `SetupPhoneScene` (`stopped`) | A dark screen, a closed grey portal, a small moon. | Entrance once. |
| `SetupStepsScene` | Setup as a journey: cloud → parcel → phone. The cloud's arrow while downloading, the parcel's flaps open while unpacking, one line per finished component on the phone's screen while installing, the portal forming when OpenCode starts. Paused drains to grey; failed turns the failing part red. Every part comes from the job's real state (`SetupProgressView.sceneFor`). | While running: dots travel the active leg, the arrow bobs, the current line breathes. |
| `SetupReadyScene` | The celebration: the phone lights, the portal springs open (overshoot) around a check, eight rays burst and fade, sparkles and confetti settle. Replaces the lone check, keeping its meaning. | Once; rests after. |
| `SetupUnpluggedScene` | Not answering: the app's plug just short of a quiet grey portal, small marks in the gap. | While waiting: the plug nudges towards the portal and back, a faint spark flickers inside it. |

Shared cast in `setup_cast.dart` (portal brackets, sparkle, phone, prompt, check, all
paths built once).

### Where they are

| Moment | Before | After |
|---|---|---|
| **Setup start** (`phone_setup_start_screen.dart`) | A phone icon in a tonal circle, the whole block centred vertically under a large empty top (ledger row 1). | `PhoneSetupHero` (new, `phone_setup/phone_setup_hero.dart`): the drawing at the top (248 dp), then the title, promise, Set up, Customize, Other ways. Each hero state has its drawing: first time `fresh`, running/stopped part way `SetupStepsScene` (ambient only while running), ready `ready`, Termux `termux`, Open starting OpenCode `starting` (ambient), Open failing `SetupUnpluggedScene` with the reason in the failure colour. The switch and entrance use `KitMotion.standard`, and the switcher no longer centres the state (it floated because `AnimatedSwitcher` centres by default). |
| **Setup progress** (`widgets/setup_progress_view.dart`) | Download icon, title, bar and checklist centred, dead space above (row 2); Details opened a box in a box (`TerminalView`'s frame inside `KitStateView`'s panel) with every apt line wrapped in two, a lone Cancel above Hide details, and the title and bar scrolling away (row 16). | The head (the journey drawing, title, one line, bar and time left) is pinned at the top when there is room (≥ 560 dp high, text ≤ 1.3×); the steps, Cancel and Details scroll under it. Cancel sits right under the checklist in the action hierarchy (tertiary, error colour, confirmed as before); a hairline, then the folded Details. The log is **one box** (`TerminalView(framed: false, wrap: false)`), mono `bodySmall`, one line per line with long lines scrolling sideways, newest at the bottom (a reversed scroll that follows the output), at most 42 % of the screen high; opening it scrolls it into view under the head. Short screens and large text scroll as one, as before. |
| **Setup ready** (`phone_setup_ready_screen.dart`) | A check in a tonal circle, content floating low under a big empty top; "Create" plus "Open an existing folder", whose sheet (with its own "New project" name field) sat on top of this screen's name field on the owner's phone. | One step: `SetupReadyScene` at the top, "OpenCode is ready", "Name your first project", the one name field, **Create and open** (primary), **Open a folder instead** (tertiary). The folder sheet (`ProjectFolderActions.openFolder`, unchanged; slice F is adding browsing inside it) opens only on that tap. Nothing in the code opens it by itself: its only callers are this tap, the Work tab and Projects, each on a tap; the test checks no sheet and one name field after the screen settles. `ReadyCheck` removed. |
| **Starting OpenCode on this phone…** (`saved_server_connection_card.dart`) | Play icon. | `SetupPhoneScene(starting)`, ambient. |
| **Connecting to …** | Terminal icon. | The reference `KitPortalScene`, ambient (breathing brackets, circling spark). |
| **… isn't answering** (after 8 s) | Cloud-off icon. | `SetupUnpluggedScene`, ambient (the app keeps trying). |
| **The server on this phone is stopped** | Stop icon. | `SetupPhoneScene(stopped)`, still. Other failures (a remote server, a password) keep their icon: a drawing would not say which. |
| **On this phone** (Termux, `termux_setup_screen.dart`) | Phone icon, running and stopped. | Inline (88 dp) `SetupPhoneScene(termux)` while running and `(stopped)` when stopped; a problem keeps its warning icon. |

One ambient loop per screen at most, only while the person waits; resting screens are
still. Reduced motion shows the finished drawing and nothing loops (the foundation's
`KitIllustration`). Drawings are decorative (excluded from semantics).

### Strings

`phoneSetupReadyCreateOpen` "Create and open" / "إنشاء وفتح",
`phoneSetupReadyOpenFolderInstead` "Open a folder instead" / "فتح مجلد بدلًا من ذلك"
(`app_en.arb`, `app_ar.arb`, regenerated with `gen-l10n`). The old keys are left in place
for the coordinator's key-by-key merge.

## Builds

- Branch `ds/motion-setup` from `cf1d7464` (feat/phone-setup-v2). No APK built.

## Devices

None. Widget tests and rendered images only (pinned Shorebird Flutter
`91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC).

## Runs

1. **Behaviour tests fail on the old code.** `test/motion_setup_test.dart` (12 tests) run
   with the product files reverted (`git checkout -- lib`, keeping the new scene files so it
   compiles): 10 fail — no drawing at the top of setup start or ready, the log's newest line
   at y = 2292 on a 915 dp screen, 78.6 lines of height for a 40-line tail (wrapped apt
   lines), Cancel/Details order, no drawings on the connection states. Output:
   `tests-without-change.txt`. With the change: 12 pass (`tests-with-change.txt`). PASS.
2. **Scene tests** `test/setup_scenes_test.dart`: 13 scenes × dark/light goldens of the
   finished frame (`test/goldens/kit_setup_*.png`), a scene with data repaints when its step
   changes, the starting phone loops only while shown, reduced motion settles every scene at
   once. PASS.
3. **Existing tests kept**, two changed on purpose: the progress test finds Details by its
   new key (`setup-progress-details`); the ready test's "check draws in once" became "the
   celebration plays once, and is still with reduced motion" (loops allowed), and its copy
   check reads "Open a folder instead". The rest of phone setup, connection card, Termux
   screen, terminal view, design standard and golden files pass unchanged: 27 affected
   files, 465 tests (`-j 2`), after one fix in `termux_setup_screen_test.dart`, whose helper
   tapped a row right after scrolling it into view without a frame in between (the drawn
   stopped state is taller than the icon was, so the row now sits below the fold of the
   800 × 600 test screen; it is reachable by scrolling, as before). `flutter analyze lib
   test` clean.
4. **Goldens regenerated and looked at** (dark and light): `setup_*` (start, progress,
   ready, customize behind its sheet, the new `setup_progress_log` with Details open),
   `connection_{connecting,not_answering,stopped,starting}` (their golden test now waits the
   900 ms entrance), `phone_running`, `phone_stopped`. `test/design_standard_test.dart`
   lists `phone_setup_hero.dart` and the new `setup_progress_log` golden.
5. **Renders** at 412 × 915, before (`before-*`, the code at `cf1d7464`) and after
   (`after-*`), dark and `-light`:
   `01` setup start, `02` start with setup running, `03` progress, `04` progress with
   Details open, `05` ready, `06` starting OpenCode on this phone, `07` connecting,
   `08` not answering, `09` phone server stopped, `10` On this phone stopped.
   The renders run under `tool/capture/`, outside `test/flutter_test_config.dart`, so ambient
   loops run there: the waiting states (`03`, `04`, `06`–`08`) show a moment of their loop;
   the goldens show the still finished frame.

## How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 2 test/motion_setup_test.dart test/setup_scenes_test.dart
$F test -j 2 test/phone_setup_progress_screen_test.dart test/phone_setup_ready_screen_test.dart \
  test/phone_setup_start_screen_test.dart test/saved_server_connection_card_test.dart \
  test/termux_setup_screen_test.dart test/terminal_view_test.dart test/design_standard_test.dart
$F test -j 2 test/goldens/phone_setup_golden_test.dart test/goldens/work_tab_golden_test.dart \
  test/goldens/phone_server_screens_golden_test.dart
# renders (before: on cf1d7464 with this capture file and test/support/phone_setup_scenes.dart)
$F test tool/capture/motion_setup_test.dart
$F test --dart-define=MOTION_LIGHT=true tool/capture/motion_setup_test.dart
$F test --dart-define=MOTION_CAPTURE=before tool/capture/motion_setup_test.dart
```

## NOT proven

- **On a device.** Nothing here has run on a phone or emulator: not the smoothness of the
  loops (the §10 `gfxinfo` check), not how the drawings read at the phone's real density
  and font scale, not the notification → progress → ready path.
- The celebration is staged within the foundation's 900 ms entrance (`KitIllustration` has
  no longer entrance); `KitMotion.celebration` (1.4 s) is not used.
- `builtin_server_screen.dart` (the older "OpenCode in this app" page reached from
  Termux setup and `main.dart`) was not changed: it is not on the kit and its states are
  step tiles, not a state view.
- The folder sheet itself (its own "New project" field) belongs to slice F.
- The start screen with "Starting OpenCode on this phone…" after Open has no render (it
  needs the in-app server start to hang); its drawing is the same `starting` phone as
  render `06`.
