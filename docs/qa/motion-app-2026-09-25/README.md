# Motion across the app (2026-09-25)

## Scope

The owner, on build 2052/2053: "be more creative — add animations … (they could even
move etc) … This in general see where we need". Issue #87 started from a "choppy,
ugly UI". Spec: slice **E** of
[`docs/design/motion-and-illustration-2026-09-25.md`](../../design/motion-and-illustration-2026-09-25.md),
on design standard §10 and the frozen `KitMotion` timings (`quick` 150 ms,
`standard` 250 ms, `breath` 4 s; curves `enter`, `exit`, `emphasized`).

The rule for every change: calm and quick, never showy; paint and transforms only
where it can be; nothing left running on a resting screen; instant (or a plain fade)
under the system's "remove animations".

### What now moves

| Where | Before | After | Timing | Cost |
|---|---|---|---|---|
| **Every page push and back** (`KitPageTransitionsBuilder`, the theme's transition on Android, Linux, Windows, macOS, Fuchsia; iOS keeps its back-swipe) | Flutter's `FadeForwards`: 450 ms, the new page slides a quarter of the screen (103 dp at 412) while the old one slides a quarter back, the two overlapping. | M3 **shared axis x**: the page underneath fades out in the first 30 % while drifting 30 dp back, then the new page fades in while sliding 30 dp into place. Back is the mirror. Follows RTL. Reduced motion: the new page shows at once; a closing page only fades. | `standard` 250 ms, `emphasized` travel, `exit`/`enter` fades | Opacity + translation over each route's repaint boundary. No snapshot, no relayout. The widget structure is the same with and without reduced motion, so toggling the setting never rebuilds an open page. |
| **Shell tabs** (`KitTabSwitcher` in `home_screen.dart`) | `RetainedTabView`: a 180 ms crossfade, both lists half-visible in the middle ("two lists blending"). | **Fade-through**: the tab being left clears in the first 35 %, then the chosen one fades in and settles from 97 % to full size. Keeps every tab's state, focus/semantics/touches only on the chosen tab from the first frame, tickers of the old tab stop at once, quick changes of mind start from what is painted. | `standard` 250 ms | Opacity + scale over each tab's repaint boundary. |
| **Dock indicator** | 180 ms | Moves with the tabs. | `standard` | Stock `NavigationBar`. |
| **Connection banner** over Inbox/Project/Settings | Popped in, pushing the tab down in one frame. | Unfolds and folds (`KitReveal`). | `standard` | One small part's height; the tab lists keep their width, so their rows are not laid out again. |
| **Destination name** under the server name | Swapped. | Settles in (fade + 3 dp rise), one `Text`, never two copies. | `standard` | Paint only. |
| **Server status dot** while connecting | A spinning 12 dp progress wheel in the app bar, forever while reconnecting. | A still dot that sends out a soft ring twice per breath; still once connected; never under reduced motion or in tests. | `breath` (2 rings per 4 s) | One 10 dp `CustomPaint` in its own repaint boundary; the ring paints outside the dot, layout never moves. |
| **`KitStateView`** (every page and inline state) | Cut from one state to the next. | Arrives with a fade and a 6 dp rise when first shown and again when it **becomes a different state** (icon, tone or drawing changes). New words or progress inside the same state do not replay it. Details unfold and fold. Working → finished (tone `progress` → `ok`) while the person watches gives a soft haptic. | `standard` | Paint only for the arrival; details: one part's height. |
| **`KitNotice`, `KitStatusLine`** | Appeared/vanished. | Fade and rise into place when they appear and when their tone/icon changes. A host that shows them through `KitReveal` also gets the fold-away when they go. | `standard` | Paint only. |
| **`KitExpandRow`** (Plugins' built-ins, other OpenCode versions) | Rows popped in, chevron icon swapped. | Rows unfold under the header; the chevron turns. | `standard`, chevron on `emphasized` | One part's height; rotation. |
| **Working `KitButton`** (primary/secondary) | Icon swapped for a spinner; an icon-less button became a different widget (`FilledButton` → `FilledButton.icon`) and its label jumped sideways. | Icon and spinner crossfade in one 19 dp slot; an icon-less button makes room for the spinner smoothly and stays the same widget. | `quick` 150 ms | A 19 dp slot; `AnimatedSize` of the spinner's slot only. |

### Kit parts for the other slices to adopt (not yet used in their screens)

| Part | File | Use |
|---|---|---|
| `KitReveal` | `lib/ui/kit/motion/kit_reveal.dart` | `KitReveal(child: cond ? KitNotice(…) : null)`: a part unfolds in and folds away (form verdicts, a failed save, a status line that comes and goes). First build is instant. |
| `KitEntrance` | same | A paint-only fade and rise, replayed when `trigger` changes. |
| `KitAnimatedRows` | `lib/ui/kit/motion/kit_animated_rows.dart` | A short keyed list (Column / `ListView(children:)`): a new conversation, a task added, a server forgotten unfold in / fold away where they were; rows that stay keep their state. |
| `KitRefresh` | `lib/ui/kit/motion/kit_refresh.dart` | Drop-in for `RefreshIndicator` (28 uses in `lib/ui/screens`): the brand portal draws itself in with the pull, the spark lands when armed, breathes while refreshing, shrinks away when done. Flutter's own `RefreshIndicator.noSpinner` runs the gesture. |
| `KitHaptics.send()` / `.done(context)` | `lib/ui/kit/motion/kit_haptics.dart` | A light tick on send; Android's CONFIRM (API 30+) on a finished moment, skipped under reduced motion. The chat already ticks on send and on a finished reply with raw `HapticFeedback` (`chat_screen.dart`, slice C's library): switching those calls to `KitHaptics` is a one-line change each for slice C. |

Exported from `kit.dart` (one line per new file, appended at the end).

## Builds

- Branch `ds/motion-app` from `cf1d7464` (feat/phone-setup-v2, the motion foundation).
- No APK, no emulator, no Gradle (other agents share the PC).

## Devices

None. Widget tests and rendered frames only (pinned Shorebird Flutter
`91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC).

## Runs

| # | Run | Expected | Actual |
|---|---|---|---|
| 1 | `test/kit_motion_app_test.dart` (20 tests): transition family on every platform but iOS; page fade-through and its rest state; reduced-motion page; tab fade-through keeps state; reduced-motion tab; notice unfolds, settles, folds away (not touchable while leaving); first build and reduced motion instant; notice and status line fade in and settle; state view fades on a new state, not on new words, finish haptic once; details unfold/fold; reduced motion: no fade, no haptic; rows unfold/fold where they were, keep state, reduced instant; working button crossfade, smooth room, reduced motion without error; expand row; pull to refresh draws the portal (no stock spinner) and settles; haptics send/done. | pass | PASS |
| 2 | `test/home_navigation_test.dart` (+1 test: the real shell fades through; dock indicator on `KitMotion.standard`; nothing running at rest) | pass | PASS (26) |
| 3 | Same two files on the pre-change kit/theme/shell | the new behaviours fail | FAIL, 11 tests (`failing-first-without-change.txt`) |
| 4 | Discovery run of the whole suite (406 files, 8 chunks, `-j 2`) | pass | 2 files failed, both fixed: **`work_tab_golden_test.dart`**, 4 goldens: the "not answering" state appears during a 9 s pump and was captured on the first frame of its arrival (blank); the golden now pumps `KitMotion.standard` after its `before` step, and the 4 images were re-recorded after looking at them: identical except the indeterminate bar's phase and the status dot (still dot, 10 dp, instead of a spinning 12 dp wheel). **`phone_setup_ready_screen_test.dart`**, 3 tests: a product bug — under reduced motion the working button's zero-duration `AnimatedSize` re-dirtied itself during layout; fixed (no `AnimatedSize` under reduced motion) and guarded by a new test that fails without the fix. |
| 5 | Final gate on the committed candidate | pass | PASS: `flutter analyze lib test` clean; all 406 test files (8 chunks, `-j 2`, every chunk exit 0, 775 s) on `1377c6e7` (code as of `4fee2153`) |

## Evidence

- `failing-first-without-change.txt`: the new tests run against the pre-change kit,
  theme and shell (the product files checked out from `cf1d7464`, the new motion files
  kept so it compiles): 11 tests fail, one per behaviour — the page transition family
  and its fade-through and reduced motion, the tab fade-through in the real shell, the
  notice and status line arriving, the state view's new-state fade and finish haptic,
  details unfolding, the working button crossfade and its smooth room, the expand row.
- Frame strips (412 × 915 dp at half size, time above each frame), before and after:
  `before-tab-switch.png` / `after-tab-switch.png`, `before-page-push.png` /
  `after-page-push.png`, `before-notice.png` / `after-notice.png` (the single frames
  are regenerated under `frames/` by the capture tool and not committed). Before the
  change, the tab switch at 32 ms shows both lists on top of each other ("Work row 1"
  over "Inbox row 40"); after, the Work tab clears by ~90 ms and Inbox fades in alone.
  The old page push slides the whole page ~100 dp over 450 ms; the new one settles in
  250 ms with 30 dp of travel.

## Measure on a device (coordinator)

Profile or release build of this branch merged, on the emulator used for issue #87
(and the owner's phone if possible). For each scenario, reset, act, dump:

```sh
PKG=<applicationId>
adb shell dumpsys gfxinfo $PKG reset
# … do the scenario …
adb shell dumpsys gfxinfo $PKG > gfx-<scenario>-<before|after>.txt
# Record: Total frames rendered, Janky frames (%), 50th/90th/95th/99th percentile,
# Number Slow UI thread, Slow bitmap uploads, Slow issue draw commands.
```

| # | Scenario | What to do | Pass |
|---|---|---|---|
| 1 | Tab switching | On a connected server with ≥ 20 conversations: tap Work → Inbox → Project → Settings → Work, 5 rounds, 1 s apart. | Janky % and p90 no worse than `dev` before the merge; no frame > 32 ms during a switch. |
| 2 | Page push/back | From Work open a conversation, wait 1 s, back; 10 times. Then Settings → a sub-page → back, 10 times. | Same; p99 no worse than before. (The old `FadeForwards` ran 450 ms and slid ~100 dp: expect fewer frames per push, not more jank.) |
| 3 | Chat scroll | In a long conversation (≥ 100 turns), fling up and down 10 times. | Unchanged from before (this pass does not touch the transcript); it is the control. |
| 4 | Work tab scroll | Fling the Work list 10 times. | Unchanged from before. |
| 5 | Connecting | Stop the server, watch the app bar dot for 10 s while it reconnects, restart it. | The dot's ring is smooth; `gfxinfo` during the 10 s shows ~0 janky frames (one 10 dp layer repainting). |
| 6 | Reduced motion | Settings → Accessibility → Remove animations on. Repeat 1 and 2. | Tabs and pages switch without motion; the dot is still; nothing animates. |
| 7 | Haptics | Send a chat message; finish phone setup (working → ready). | A light tick on send (already in the chat); a soft confirmation when a working `KitStateView` turns finished (Android 11+). None with Remove animations on for the finish. |

Compare against `dev` (or `feat/phone-setup-v2` at `cf1d7464`) with the same device,
same data, same build type. Also record: a short screen recording of 1, 2 and the
connection banner unfolding for the audit.

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test test/kit_motion_app_test.dart test/home_navigation_test.dart
# Failing first: check out the old product files and run the same two files
git checkout cf1d7464 -- lib/ui/kit/kit_state_view.dart lib/ui/kit/kit_notice.dart \
  lib/ui/kit/kit_status_line.dart lib/ui/kit/kit_buttons.dart lib/ui/kit/kit_row_parts.dart \
  lib/ui/app_theme.dart lib/ui/screens/home_screen.dart
$F test test/kit_motion_app_test.dart test/home_navigation_test.dart   # 11 fail
git checkout HEAD -- lib/ui/kit lib/ui/app_theme.dart lib/ui/screens/home_screen.dart
# Frames and strips
$F test --concurrency=1 tool/capture/motion_app_test.dart
python3 tool/capture/motion_strip.py docs/qa/motion-app-2026-09-25
```

## NOT proven

- **Nothing on a device.** No frame timing, no `gfxinfo`, no haptic felt. The table
  above is what the coordinator must measure; until then "no dropped frames" is a
  design claim (paint and transforms only, repaint boundaries), not a measurement.
- Predictive back (Android 14+ back gesture preview): the kit transition, like the
  `FadeForwards` it replaces, animates after the gesture commits; it does not follow
  the finger.
- `KitRefresh`, `KitAnimatedRows` and `KitReveal` around notices are **not adopted** in
  any screen yet (those screens belong to slices A–D); they are tested as parts only.
  The chat's send/finish haptics were already there and are unchanged.
- The finish haptic fires only for a `KitStateView` whose tone goes `progress` → `ok`
  while mounted; a finished moment shown on a new screen (setup ready) must call
  `KitHaptics.done` itself.
- iOS keeps the Cupertino transition (not a target).
- `lib/ui/widgets/retained_tab_view.dart` is no longer used by the app (its own test
  still runs); removing it is the coordinator's call.
