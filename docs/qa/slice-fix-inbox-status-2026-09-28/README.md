# slice-fix-inbox-status (2026-09-28)

Fixes for the Inbox and status findings F3, F4, F5, F10, F15 and F16 from
`docs/qa/emulator-qa-claude-2026-09-28/README.md`. Branch
`revamp/slice-fix-inbox-status`.

## What changed

| Finding | Status | Change |
|---|---|---|
| F3 title | fixed | Inbox feed rows and saved automatic acts show the server's `New session - <ISO time>` placeholder as "New conversation", the same as Work (`presentedSessionTitleText` in `lib/ui/widgets/session_title.dart`). |
| F3 Stop shown as "Failed" with "1 need you" | partly fixed, **rest needs `lib/state/connection.dart`** | New `sessionErrorIsStop()` (`lib/domain/session_stop.dart`) recognises OpenCode's `MessageAbortedError` (v1 `name`, v2 `type`). Another project's stopped run is no longer a failed run (`elsewhere_attention.dart`). The connected server's SSE path (`connection.dart` `session.error` → `_failedAttentionSessions` + error alert) is owned by another lane: the exact patch is in the coordinator's lane notes. The monitor reader already skipped aborted runs. |
| F4 one "Reconnected by itself" row per reconnect | fixed | The Inbox folds routine reconnects into one current row per server or project, the newest one. Dismissing it acknowledges everything it folded, so no older row takes its place. Other kinds of act (restart, heat pause, …) keep a row each. The history store is unchanged. |
| F5 offline Work shows a second "Could not load your conversations / Report a problem" panel | fixed | `OlderSessionsPager` shows no list, page or pin error while the connection is down. The connection's status line is the one place that says so, and the listed rows stay. While connected, a failed list still shows its error with Try again. |
| F10 "Android closed … it's starting again" beside "Connected" | fixed | A force stop now reads "OpenCode Mobile was closed at …" (a force stop can come from Settings, a Recents swipe or a battery manager, not only from Android). Once the app is connected to the phone's OpenCode again, the notice says "…stopped with it and is running again". A notice with nothing left to offer (a crash has no Keep it running) resolves by itself at that point. |
| F15 mixed time formats | fixed | New `KitTime` (`lib/ui/kit/kit_time.dart`) is the one formatter. The clock follows the device's 12/24-hour setting and locale; a moment is the clock alone today, "Sep 25, 8:19 PM" this year and "Dec 31, 2025, 8:00 AM" before. Now used by Inbox and Work "as of" (`WorkRowStatus.line(moment:)`), team task rows, KitProgressRow "as of", KitReceipt and the app-exit notice. |
| F16 notification offer pushes the reply's actions up | **not done: needs `lib/ui/screens/chat_screen.dart`** | `FirstReplyNotifyCard` already shows after the reply finishes, as a one-line KitAskLine. The shift comes from where `chat_screen.dart` (~line 7630) hosts it, in the column above the composer. The chat lane owns that file; a placement proposal is in the lane notes. |

### Added on the coordinator's request: the chat's free-model note

After merging `feat/phone-setup-v2` (which brought slice-builtin-speed's
`connectionUsesFreeModel` and the `freeModelNotice` and `freeModelSignIn`
strings), a conversation whose replies come from OpenCode's free model,
with no provider signed in, shows one quiet neutral line in the chat page's
status slot: "Using OpenCode's free model — it's slower. Sign in to your
provider to use your own." with **Sign in to a provider** (it opens
Integrations › Providers) and a Dismiss.

- It is not a banner: it is the last entry in the chat's own status list, so
  every other chat line (a send error, queued drafts, a share) outranks it.
- It is dismissed once per conversation: `FreeModelNoteDismissals` in
  `lib/state/free_model_notice.dart`, key `oc.freeModelNoteDismissed.<profileId>`,
  holding the newest 200 conversations. Deleting the server sweeps the key.
- It does not move the reply. The status slot sits over the top of the
  bottom-anchored transcript, so the reply and its actions stay put; the test
  measures the reply's position before and after Dismiss.
- The only edit to the chat library is the status entry and its two handlers
  in `chat_screen.dart`. This was a coordinator-directed exception to the brief.
- Images: `after_chat_free_model_note_dark.png` (phone; the long copy wraps
  to three lines there) and `after_chat_free_model_note_1280x800_light.png`.

The same status-slot placement is the proven no-shift home for F16's
notification offer, too. F16 itself was not moved: `FirstReplyNotifyCard`'s
claim, answer and failure flow would need turning into a status source, and
that is recorded for the chat lane.

Not reproduced here: in QA screenshot 64 the offline Work row's "as of" time
kept moving to the current time. That timestamp comes from the row-status
observation in the connection lane, and it is recorded in the lane notes.

## Images (evidence goldens, phone 412×915 dark and wide 1280×800 light)

Produced by `test/revamp/slice_fix_inbox_status_golden_test.dart`, which is
evidence only (`--dart-define=CAPTURE_EVIDENCE=true`) because ages and times
come from the wall clock. The "before" images come from the same test run on
the base commit `690c3833`.

| | Before | After |
|---|---|---|
| Inbox, phone | `before_inbox_dark.png`: placeholder title, "as of 9/28/2026 23:59", four reconnect rows | `after_inbox_dark.png`: "New conversation", "as of 11:58 PM", one reconnect row |
| Inbox, wide | `before_inbox_1280x800_light.png` | `after_inbox_1280x800_light.png` |
| Work offline, phone | `before_work_offline_dark.png`: second "Could not load your conversations" panel, 24-hour date | `after_work_offline_dark.png`: rows only; the app-wide status line (not in this harness) says the server is not answering |
| Work offline, wide | `before_work_offline_1280x800_light.png` | `after_work_offline_1280x800_light.png` |

The failed row in these fixtures is a real provider error, not a Stop. The
Stop case waits on the `connection.dart` patch.

## Tests

- New: `test/slice_fix_inbox_status_test.dart`, 7 tests: Stop recognition,
  a stop in another project, the placeholder title, the 12/24-hour "as of",
  reconnect folding and its Dismiss, and the offline and connected pager.
  All 5 behaviour tests failed on the base commit and pass now.
- New: `test/kit/kit_time_test.dart` (the clock, the moment, and the
  fallback with no widget tree).
- Changed to the new behaviour: `test/app_exit_recovery_test.dart` (wording,
  plus two new F10 tests) and `test/kit/kit_progress_row_test.dart` ("as of
  10:42 AM" in the device's 12-hour clock).
- Run once, before the merge: every test file that imports a changed file
  (93 files, including `kit_ratchet_test` and `kit_map_gate_test`). All pass
  except the two `kit_progress_row_golden_test` "stale" shots, whose "as of
  10:42" became "as of 10:42 AM". That was reviewed as the intended F15
  change and refreshed. Three capture files skip unless their capture flag
  is set. `text_scale_overflow_test` passes: 505 tests in 6 min 18 s.
- New: `test/chat_free_model_note_test.dart`, 4 tests plus 2 evidence-only
  shots: the line and its action, the reply not moving on Dismiss, dismissed
  once per conversation (reopened, and another conversation), Sign in opens
  the provider sign-ins, no line when a provider is signed in, and the
  dismissal store's bound and sweep.
- After the merge: `slice_p4_4_test`, `chat_speed_test`, `free_model_test`,
  `this_phone_speed_test`, `ios_remote_platform_gating_test`,
  `release_blockers_test` and `kit_ratchet_test` pass.
- `flutter analyze` on the whole project after the merge: no issues.

## Still needs a device

- A Stop on the emulator, once the `connection.dart` patch lands: Inbox and
  Work show no "Failed", and there is no badge.
- The app-exit notice after a force stop and relaunch on the phone server:
  "was closed … is running again" once the pill says Connected.
- The 24-hour setting on a device: Inbox, Work and the banner show the same
  format.
