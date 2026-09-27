# P6.2 Every automatic act reported: While you were away (2026-09-27)

Branch `revamp/slice-P6.2`, from `feat/phone-setup-v2` at `596ca82a`. Builds on
Codex's backend half (`docs/qa/codex-p62-2026-09-27/`, merged in `c435ec36`):
`AutomaticActivityController` (`oc.automaticActivity.<profileId>`) and
`WhileAwaySnapshot`.

**Finish line:** every automatic act the app already does is filed once, and
the Inbox lists it with what finished, newest first, below everything that
waits on the person: what it was done to, what was done and when, Undo where
the act has a real inverse, a tap to that thing's page.
**Non-goal:** no new triggers; no Undo invented for acts without an inverse.

## What changed, per page

| Page | Change |
|---|---|
| activity (Inbox) | While you were away rows join the one list (owner rule R1: no section, no header). Order: Needs you, other servers' requests, running, check-ins, then finished work and automatic acts **interleaved newest first**. An act row: done mark, the thing as title (server name, or the conversation's current title), line "Reconnected by itself · 12m ago" (the KitAutoLine words through `KitReceipt.span`), tap opens the conversation it was done to, Dismiss by swipe or row menu with KitUndo (deferred acknowledge), Undo button only while `canUndo`. Undone / "Undo didn't go through" / "Undo not confirmed" are said on the line; an uncertain Undo never reads as done and is never retried. A corrupt or unsaved history shows a plain KitNotice. Acts never count toward Needs you, badges or notifications. |
| activity: finished digest | Dismiss now saves (on Undo-window close) through `dismissReturnBrief(ReturnBrief.single(run))`, the same "reviewed" mark as Work's *Mark as reviewed*, so it survives a restart; before it was view state only. A refused save brings the row back. Finished rows also honour that mark. |
| embedded-return-brief-panel + status dialog | Code was already gone (census: removed 2026-09-24). This slice removes its 12 dead strings (`returnBriefTitle`, `…Description`, `…Untitled`, `…Stale`, `…Unknown`, `…Partial`, `…Answer`, `…Unreviewed`, `…More`, `…SaveFailed`, `…Saving`, `…Dismiss`) from `app_en.arb` (and the stale `app_ar.arb` copies). Its job now lives in the Inbox. |

Row design choice: a first cut placed `KitReceipt(automatic: true)` under the
title; it put the check mark out of line with every other row and its
"at 10:42" clock time is ambiguous a day later. The shipped row uses the
list's done mark and relative time like the finished rows, and the receipt's
row form (`KitReceipt.span`, K2 §1.16). KitReceipt/KitAutoLine was not
changed (kit read-only for this slice).

## Producers wired (existing acts only, recorded after confirmation)

| Act | Where | Filed under |
|---|---|---|
| Reconnect: the live stream went `reconnecting → connected` by itself (a first connect or a person's Reconnect starts a new stream and is not filed) | `connection.dart` `_startEvents.handleStatus` | server address |
| Request allowed by itself (session auto-approval), after the reply is confirmed and recorded | `connection.dart` `_autoApprove` | project (`returnBriefScope` identity), conversation id; patterns never stored |
| Queued message sent once the server was back (delivered and its removal recorded) | `connection.dart` `flushOfflineQueue` | project, conversation id |
| AI Team paused / stopped / resumed by the heat guard (per team, confirmed; an unreachable resume is not filed) | `ThermalGuard.onAct` → `main.dart` → `ConnectionController.recordServerAct` | that server's address |

State ownership: `AutomaticActivityController.forProfile(prefs, id)` is the
one shared history per profile (the app's connection, isolated task
connections and the Inbox use the same instance; isolated connections file
nothing). `ConnectionController.automaticActivity`, `automaticActsHere`,
`recordAutomaticAct`, `recordServerAct`. The saved summary is only the
thing's name; the Inbox words the act from its kind (English copy in ARB).
`AutomaticActKind.heatStop` was added (backward compatible by name).
`deleteProfileAndLocalData` now awaits `AutomaticActivityController.closeProfile`
(close, drain writes and Undo in flight, remove the key) before the sweep.

No producer has a real inverse today (a reconnect, a confirmed permission
reply, a sent message and heat protection cannot be taken back), so Undo is
wired end to end but shows only for an act recorded with one.

### Call sites still open (owners)

- **Restart** (`AutomaticActKind.restart`): `lib/builtin/app_exit_recovery.dart`
  and `lib/termux/managed_server_recovery.dart` (P6.5 / P1.7 area) should call
  `controller.recordServerAct(profileId:, kind: AutomaticActKind.restart,
  eventId: '<episode id>', at:)` after a confirmed recovery.
- **Update** (`AutomaticActKind.update`): `lib/update/shorebird_update_notice.dart`
  after a confirmed automatic download (app-wide; needs a decision on which
  profile or a profile-less home).
- **In-place KitAutoLine** in the chat (auto-approved request, queued message
  sent) belongs to the chat lane (P3.3); the history is already there to read.
- **Settings hub / What runs by itself**: no entry point added; the Inbox is
  the one place.
- UI ledger: `parts/a-shell.json` gained `activity-auto-row`,
  `activity-auto-dismiss`, `activity-auto-undo` and the digest dismiss's new
  effect. `build_ledger.py` was **not** re-run here: on this base it rewrites
  the outputs from 338 to 322 pages (other merged parts), so the coordinator
  should rebuild once after merging.

## Tests

- New `test/while_away_inbox_test.dart` (7): order in the one list and never
  Needs you; other server / other project acts stay out; an act opens its
  conversation; Dismiss + Undo, then Dismiss saves (acknowledged); Undo only
  with a real inverse and "· Undone" after it; unreadable history is said;
  a dismissed finished run stays reviewed after a rebuild; deleting a server
  removes its history and nothing can file for it after.
- New in `test/connection_sse_test.dart` (1): a stream reconnect is filed, the
  first connect is not.
- New in `test/thermal_guard_test.dart` (2): pause, stop, resume reported once
  each per team; an unreachable resume is not reported.
- New goldens in `test/revamp/screen_shell_1_golden_test.dart`:
  `shell_activity_away` phone and 1280x800, dark and light.
- Ran once: the new tests, `activity_screen_test`, `revamp/screen_shell_1_test`,
  `automatic_activity_test`, `while_away_test`, `return_brief_test`,
  `return_brief_state_test`, `connection_sse_test`, `thermal_guard_test`,
  `l10n_coverage_test` — all pass.
- Failing on this branch **and on the base** (second worktree at `596ca82a`),
  left alone: `kit_ratchet` G17 and G21; `ui_glossary` G11 COPY-9, G11 COPY-11,
  G28 (none of their messages name a file or key of this slice);
  `return_brief_widget_test` ×5; `screen_shell_1_golden_test` inbox waiting,
  inbox all clear, question sheet (both themes). No new failures.
- `flutter analyze lib test`: clean.

## Images

Before (base goldens): `before-inbox-phone-light.png`, `before-inbox-wide-dark.png`.
After: `after-inbox-phone-light.png`, `after-inbox-phone-dark.png`,
`after-inbox-wide-light.png`, `after-inbox-wide-dark.png`.

## Still needs a device

The unit's proof: on the emulator, background the app, let the server drop
and come back (a reconnect) and a run finish, reopen: the Inbox shows
"Reconnected by itself · …" under the server and the finished run, newest
first, below any request. Not run here (widget tests and goldens only).
