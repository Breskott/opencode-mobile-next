# slice-speed-ui — make the app feel instant (2026-09-28)

Branch `revamp/slice-speed-ui` from `feat/phone-setup-v2` @ `90db3565`. Builds
on the Codex speed backend ([codex-speed-2026-09-28](../codex-speed-2026-09-28/README.md)),
contract items 1, 3 (non-chat) and 4.

Finish line: after a restart, the app opens on the titles this server listed
last time while it reconnects, Work never flashes skeletons over titles it
already knows, and hidden shell tabs do no startup work.
Non-goal: chat (item 2, tail preview and tap prefetch) and the team page;
hand-offs are in the coordinator's lane notes.

## What changed, per page

| Page | Before | After |
| --- | --- | --- |
| App root while connecting to a saved server | A full-page "Connecting to Laptop" with the portal drawing until the first health answer | Same honest connection state (inline size, same actions) with **the last-known conversation titles under it**, "Updated 12m ago · Refreshing". Read-only: no tap, menu, swipe, running or pinned marks. `hasConnectedServer` stays false, `sessionsById` stays empty, no live action is enabled |
| App root after a failed connect | Failure page only | Failure (same diagnosis, actions, Details) with the titles kept, label drops "Refreshing" |
| Work, first page loading | Skeleton rows | The same last-known titles (read-only) under the one loading bar; replaced the moment the live list arrives, including a live list that is empty |
| Work, first read failed | Pager failure, empty list | Pager failure plus the last-known titles, not "Refreshing" |
| Work on resume | Already kept live rows while refreshing | Unchanged; now pinned by a test (no skeleton, no spinner, no blank) |
| Shell tabs (Work, Inbox, Project, Settings) | All four built at startup; hidden Settings did its own health read | Built on first visit (`KitTabSwitcher(lazy: true, preload: {Work})`) and kept after; one health read at startup instead of two |

Titles only ever come from `ConnectionController.cachedSessionInventory`, whose
scope is the exact profile, endpoint, protocol, directory and workspace:
another server or project never shows old rows (tested).

## Kit

- New part **KitLastKnown** + `KitLastKnownRow` (`lib/ui/kit/kit_last_known.dart`,
  spec `docs/ux-system/kit-api/KitLastKnown.md`): a labelled row group of
  remembered, non-interactive rows with one semantics hint, no ticker. States:
  loading. Gallery, unit test with MOT-7 samples, G6 overflow scene, kit.dart
  export and doc row.
- **KitTabSwitcher** gains `lazy` and `preload` (default off; spec updated).
- `SavedServerConnectionCard` takes `size` (page or inline). No new
  non-kit widgets on screens; `LastKnownSessions` (`lib/ui/widgets/`) only
  maps the cache to kit rows.
- Copy (English only): `kitLastKnownRefreshing`, `kitLastKnownHint`,
  `lastKnownUpdatedJustNow`, `lastKnownUpdatedAgo`.

## Measured (widget-test harness, not device timing)

`test/opening_shell_test.dart` pumps the real `AppBootstrapGate`, app root,
profile store and `ConnectionController` with fake transports and a held
health future:

```
OPENING_SHELL before: titles_visible=0 health_calls=1 session_reads=0
OPENING_SHELL after:  titles_visible=3 health_calls=1 session_reads=0 connected=false live_rows=0
```

"Before" here is the same build with no saved titles; the before images below
come from the base commit with titles saved (it ignores them).
`test/perf_startup_connection_test.dart`: health reads before the event stream
connects went **2 → 1** (hidden Settings no longer mounts).

## Images (phone 412×915 and wide 1280×800)

Root while connecting: `before_root_connecting_412x915.png` →
`after_root_connecting_412x915.png` (and `_1280x800`).
Root after a failed connect: `before_root_failed_*` → `after_root_failed_*`.
Work first load: `before_work_first_load_*` (skeletons) →
`after_work_first_load_*` (last-known titles). Kit gallery:
`test/goldens/kit/kit_last_known_{loading,settled}_*.png`.

## Tests

New/changed, all passing: `test/kit/kit_last_known_test.dart` (9),
`test/goldens/kit/kit_last_known_golden_test.dart` (8),
`test/kit/kit_tab_switcher_test.dart` (48, +3 lazy),
`test/opening_shell_test.dart` (5), `test/work_last_known_test.dart` (6),
`test/perf_startup_connection_test.dart` (1, expectation 2 → 1).

Gates passing: kit_ratchet, kit/kit_manifest, kit/kit_draft_manifest,
redaction, ui_glossary, no_raw_error_text, kit_motion; `flutter analyze` clean.
Also passing: saved_server_connection_card, project_hub, work_tab_cleanup,
app_lifecycle, codex_navigation, builtin_server_autostart, revamp/screen_shell_2,
revamp/coord_main_golden, session_inventory_cache.

Pre-existing failures, identical failing-test sets on the base commit (temporary
base worktree): home_navigation (16), desktop_shortcuts (2), first_run_landing
(5), first_run_auto_test (3), release_blockers (5), accessibility_guidelines
(2), server_switcher (4), desktop_scrollbar (2), motion_states (3),
goldens/work_tab_golden (20), revamp/screen_work_1_golden (9),
goldens/work_parts_golden (8), text_scale_overflow (KitSegmented only; the
KitSegmented lane). Several look for a `current-tab-title` key that no longer
exists in lib/.

## Not done / needs a device

- **Emulator cold-start recording: not captured.** A release preview APK
  (x86_64, debug-keystore-signed, `ocPreview=true`) built fine, but
  emulator-5554 was gone by then and the PC had < 1 GB RAM free under load 20,
  so no emulator was started. Recipe for later: install that preview APK on
  emulator-5554, connect to a loopback OpenCode server (adb reverse), force
  stop, remove the reverse, cold start and screen-record; the titles show
  before any server answer.
- Tap feedback: `KitTappable`'s pressed fill still waits for the tap
  recognizer (100 ms press timeout, needed to tell taps from scrolls); a quick
  tap shows the next page on the next frame instead. Holding the pressed fill
  for one frame after a quick tap touches every golden that taps and pumps
  once, so it is left for its own kit unit (lane notes).
- Chat (item 2) and the tap-time `prefetchSessionTail` are the chat lane's;
  adding the prefetch before chat hydration uses `loadSessionTail` would double
  the first history read.
