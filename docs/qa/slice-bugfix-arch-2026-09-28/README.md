# slice-bugfix-arch — 2026-09-28

Finish line: the three regressions from the recent merges pass on their
existing, unchanged tests. Non-goal: no test loosened, no chat library or kit
press/tap layer edit, no copy change.

Base: `51ede350` (feat/phone-setup-v2). Each failing test was run on the base
first and failed there; each passes after the product fix with the test file
untouched.

## 1. ARCH-1 / ARCH-2 (test/architecture_boundaries_test.dart)

Base failures:

- ARCH-1 `lib/ui/screens/tools_screen.dart` "lib/api/" x3 (baseline 2) —
  `api/provider_presentation.dart` for the provider name.
- ARCH-1 `lib/ui/widgets/last_known_sessions.dart` "lib/api/" x1 —
  `api/models.dart show Session`.
- ARCH-1 + ARCH-2 `lib/ui/widgets/session_handoff.dart` —
  `api/server_probe.dart show ServerFlavor` and
  `controller.serverFlavor == ServerFlavor.v2` to pick the CLI name.

Fix:

- New `lib/state/server_presentation.dart`: an extension on
  `ConnectionController` with `sessionResumeCli` (the OpenCode 1/2 CLI the
  resume command names; availability still gates on
  `capabilities.cliSessionResume`) and `providerName(providerID)` (the shared
  provider naming from the current catalog). The flavour comparison and the
  `lib/api` import now live in the state layer.
- `session_handoff.dart` uses `controller.sessionResumeCli`;
  `tools_screen.dart` uses `controller.providerName(...)`;
  `last_known_sessions.dart` takes `Session` from the domain
  (`domain/server_gateway.dart`, which already exports it for the UI).
- Baseline regenerated with `ARCH_BOUNDARIES_WRITE=1`: entries only drop
  (files other merges already cleaned); none raised or added.

## 2. Inbox "all caught up" (test/motion_states_test.dart)

Base failure: since `c96a7fb4` `unknownAttentionProfileCount` counted every
feed server that was not `current`. The active server is `current` only with
the monitor's failed-run coverage, and an unmonitored server is `disabled`,
so with monitoring never enabled the Inbox could never say all caught up.

Fix (`lib/state/connection.dart`, one getter): the current server answers from
its own state (connected, no permission/question/form read error); another
saved server counts only while it is monitored (feed state not `disabled`)
and its check is not current. The feed itself (`attentionFeed`, counts,
coverage states) is unchanged, so the codex-inbox contract for rows and the
per-server check states holds.

## 3. KitZoom under reduced motion (test/kit/kit_image_test.dart)

Base failure: "A Timer is still pending even after the widget tree was
disposed" — a 40 ms timer created by the framework's
`DoubleTapGestureRecognizer` (`_CountdownZoned`, `kDoubleTapMinTime`). Every
multi-tap recognizer starts one per tap and nothing can cancel it. The zoom
itself already jumped under reduced motion; the test used to pass only
because the old Material icon button kept animating its enabled/disabled
chrome long enough to run the timer out. KitIconButton (KitTappable) now
honours reduced motion, so nothing was left to run it out.

Fix (`lib/ui/kit/kit_image.dart`): KitZoom reads double-tap from its own
`Listener` pointer events: one primary-button pointer, second tap within
`kDoubleTapTimeout` and `kDoubleTapSlop`, a move past `kDoubleTapTouchSlop`,
a second finger or a cancel ends the series. The window is a `Timer` the
state owns and cancels on dispose and whenever the series ends. The
GestureDetector keeps tap-to-focus and pinch/pan. Side effect: tap-to-focus
no longer waits out the double-tap window.

## Tests

Pinned Flutter 3.47.1, `tool/qa/machine_lock.sh`, `--concurrency=1`,
affected files only:

- architecture_boundaries, motion_states, kit/kit_image, kit/kit_viewer,
  kit/kit_work_graph, team_work_graph, kit_ratchet, tools_screen,
  work_last_known, kit/kit_last_known, session_handoff_sheet_layout,
  session_handoff_domain, e7_library_layout, revamp/screen_library_3:
  236 passed, 1 failed.
- activity_screen, activity_requests, connection_attention_feed,
  attention_feed, profile_monitor_screen, teaching_empty_states,
  while_away_inbox, opening_shell, background_notification_navigation,
  home_navigation, v2_feature_gating, release_blockers,
  product_ui_regression, revamp/screen_shell_1: 177 passed, 1 failed.
- The two failures fail identically on base `51ede350` (checked in a
  temporary worktree), so they predate this slice and are not touched:
  `tools_screen_test.dart: Settings exposes one native tools destination`,
  `release_blockers_test.dart: full-screen prompt editor fits a 320dp phone
  at 2x text`.
- `flutter analyze` on the changed files: no issues. `dart format
  --language-version=3.10`: no changes.

No visual change: the Inbox now reaches its existing all-caught-up state
(tray drawing) for an unmonitored setup; no golden changed. Still needs a
device: double-tap zoom on a real touch screen and a mouse double-click on a
wide window (behaviour covered by the existing KitZoom widget tests).
