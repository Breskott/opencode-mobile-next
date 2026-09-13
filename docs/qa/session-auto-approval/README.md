# Per-session auto-approval with subagent inheritance

Branch `feature/session-auto-approval` off `dev` 6c20ed7. Slice fragment:
`messages_ar.json` in this folder (picked up by `tool/assemble_arabic_arb.py`).

## Finish line

A person can open a session's menu, choose **Approvals → Approve
automatically while connected**, optionally switch on **Subagents inherit
this**, and from then on every permission request that arrives for that
session (and, when inheriting, for its child and grandchild sessions) is
answered with **Allow once** by this phone without a prompt — visibly, with a
record, reversibly, and only while the app is connected. New sessions ask.
The choice is stored per server profile and deleted with the profile.

## Non-goals

- No "always allow" is ever sent. The server's saved permission rules
  (`/api/permission/saved`) stay exactly as they were.
- Questions and forms are never answered automatically; only permissions.
- Requests that were waiting while the app was away (found by the reconnect
  hydration) are not auto-answered; a person sees them.
- No server-side setting, no cross-device sync, no global default.

## Design rationale: why "once", not "always"

- OpenCode 2's saved permissions apply to the whole project and outlive the
  session and this device. A per-session setting that quietly wrote
  project-wide rules would be a permanent side effect of a temporary choice.
- Subagent sessions get their own server-side rules, so an "always" from the
  parent would not even cover them. Replying "once" per request, on the
  app side, is the only mechanism that gives the user "this session and its
  subagents, while I watch" semantics honestly.
- "Once" leaves the server's deny rules untouched: a denied action is still
  denied, the app never sees a request for it.
- The setting stops when the app disconnects because the app is the thing
  answering. The indicator says "Auto-approval paused · Not connected" so
  this is never a surprise.

Inheritance rule: a session with its own setting uses it. Otherwise the
walk goes up `parentID` links; the first ancestor with an explicit setting
decides — it passes its mode down when "Subagents inherit this" is on, and
stops the walk when it is off (an opted-out child shields its own subtree).
Cycles and unknown parents end the walk at "ask".

## What changed

Product:

- `lib/state/session_auto_approval.dart` (new): `SessionAutoApproval`
  (`mode: ask | autoOnce`, `inheritToChildren`), `EffectiveAutoApproval`,
  `AutoApprovedPermission`, and `SessionAutoApprovalStore` keyed
  `oc.autoApprove.<profileId>` with serialized writes, `drain`, `forget`,
  and a `prefs.reload()` on refused writes so a reopened store cannot read
  a value the platform rejected.
- `lib/state/connection.dart`: `sessionAutoApproval` store,
  `autoApprovalFor(sessionID)`, `setSessionAutoApproval`, `_maybeAutoApprove`
  hooked into all three permission event handlers (`permission.asked`,
  `permission.v2.asked`, legacy `permission.updated`). The automatic reply
  goes through the existing `_sendPermissionReply` with the request
  identity, on the live transport (no wake reconciliation), and only when
  `isConnected`. In-flight requests stay in `permissions` for the reply
  plumbing but are excluded from `awaitingPermissions` /
  `permissionsForSession` / `permissionForSession` / `awaitingPermissionCount`,
  from coding-alert notifications, from `unifiedAttentionCount` and from
  `liveStatus().pendingCount`. A failed reply records
  `autoApprovalFailure(requestID)` and the request stays pending and
  visible. Successes are recorded per session (`autoApprovedFor`, bounded
  to 20, cleared with the connection). Profile deletion drains the store
  before the key sweep and forgets its cache afterwards; session deletion
  and connection reset clear the in-memory records.
- `lib/state/attention_overview.dart`, `lib/ui/screens/activity_screen.dart`:
  count and list `awaitingPermissions` so an in-flight automatic reply never
  shows as needing attention.
- `lib/ui/screens/chat/approvals_sheet.dart` (new part of the chat
  library): `showSessionApprovalsSheet` / `SessionApprovalsSheet` — radio
  choice **Ask each time** / **Approve automatically while connected**,
  **Subagents inherit this** switch (disabled with "Available once automatic
  approval is on." while asking), inherited-from-parent note with
  **Override for this session**, **Follow parent again** on an explicit
  child, the record of what was approved on this connection, and the
  footnote about server deny rules, disconnects and new sessions.
  `_AutoApprovalIndicator`: a two-line strip (state + last approval /
  inherited / "Not connected") that opens the sheet.
- `lib/ui/screens/chat_screen.dart`: **Approvals** row in the session menu's
  Session actions group; the indicator lives in the attention slot (same
  `AnimatedSwitcher` as the permission card, so the two never stack and
  never overflow while one animates out); the permission card shows
  "Automatic approval failed. Review this request." when its automatic
  reply failed; the short-layout scroll guard includes the indicator.
- `lib/ui/screens/chat/attention_card.dart`: `approvalsAvailable` on
  `SessionMenuSheet`; `autoApprovalFailed` on `_PermissionAttentionCard`.
- Localization: 22 `approvalsUi*` keys in `lib/l10n/app_en.arb`, Arabic in
  `messages_ar.json` here; `tool/assemble_arabic_arb.py` now also unions
  `docs/qa/*/messages_ar.json` (E7 fragments still win on duplicates).
  Generated `lib/l10n/app_localizations*.dart` and `app_ar.arb` updated via
  the tool + `flutter gen-l10n`.

Tests (new):

- `test/session_auto_approval_store_test.dart` — 11 tests: round trip under
  the profile key and discoverability by `profileScopedPreferenceKeys`,
  clearing, refused write throws and leaves the last value (also on a
  reopened store), malformed storage, empty profile, inheritance parent →
  child → grandchild, no-inherit, explicit override and shielding, cycle,
  and profile deletion draining an in-flight write (verified to fail with
  the drain removed).
- `test/session_auto_approval_controller_test.dart` — 12 tests: default
  asks; v1 reply "once" with in-flight exclusion from every attention count;
  v2 reply on `respondPermissionV2`; legacy shape; non-inheriting parent;
  inheritance through grandchild with an unrelated session still asking;
  explicit child override and follow-parent again; not connected → stays
  pending, no reply; refused reply → pending, visible, `autoApprovalFailure`
  set, hand reply still works; questions never auto-answered; switching
  off mid-flight; record bounded and cleared on disconnect while the
  stored setting survives.
- `test/e7_session_approvals_layout_test.dart` — 6 tests at 320dp / 2.5x
  text, LTR and RTL: menu → Approvals → sheet; switch disabled while
  asking; choose automatic, inherit, footnote copy present; Close; indicator
  visible; a request answered without a card and named in the indicator and
  in the sheet's record; Ask switches it off and the next request shows a
  card. Child session: inherited indicator and note, override, ask on the
  override leaves the parent alone, follow parent again, request
  auto-approved. Disconnect pauses the indicator without hiding it. Failed
  reply shows the card with the reason, and the strip returns after a hand
  reply. Screenshots in this folder come from
  `flutter test --dart-define=E7_APPROVALS_CAPTURE=true test/e7_session_approvals_layout_test.dart`.

## Evidence

- `flutter analyze --no-pub` → No issues found.
- `python3 tool/assemble_arabic_arb.py` → missing 0; placeholder mismatches 0.
- Focused: `session_auto_approval_store_test` 11/11,
  `session_auto_approval_controller_test` 12/12,
  `e7_session_approvals_layout_test` 6/6 (with and without capture fonts).
- Existing suites for touched files, all green (`--concurrency=4`):
  chat_permission, chat_live_events, pending_sends_strip, profile_deletion,
  session_pins, activity_requests, activity_screen, chat_menu_hierarchy,
  live_status, connection_v2, background_action, connection_interaction,
  accessibility_guidelines, background_notification_navigation,
  home_navigation, product_ui_regression, release_blockers,
  profile_monitor_screen, v2_feature_gating, reader_preferences,
  e7_project_attention_layout (376 tests), plus library_screen,
  managed_runtime_switch_preflight, return_brief_*, workspace_hierarchy
  (76 tests).

Screenshots: `sheet-ask-*`, `sheet-auto-*`, `sheet-record-*`,
`indicator-*`, `child-indicator-*`, `child-sheet-*` (ltr/rtl, 320×740 at
2.5x).

## Limitations

- Auto-approval acts on live events only. Requests discovered by the
  reconnect hydration are shown for review (deliberate: they waited while
  the app was away).
- A child session whose `parentID` the app has not learned yet (no
  `session.created` seen) resolves to "ask" until the session list knows it.
- The indicator shares the attention slot with permission/question/retry
  cards: while a request needs a person, the card takes the slot (with the
  failure reason when the automatic reply failed) and the strip returns
  once it is answered. At 2.5x on 320dp the strip's label ellipsizes after
  two lines; the accessibility label carries the full text.
- Pre-existing, not from this slice: a permission card next to the
  reconnecting banner at 320dp / 2.5x overflows the chat body with the test
  font (reproduced on the unmodified chat screen), so the disconnected
  widget test asserts the paused strip only and leaves the pending state to
  the controller test.
- `permissions` (the raw map) still holds an in-flight automatic request for
  the reply plumbing; new consumers should read `awaitingPermissions`.
- Copy in the sheet is long at 2.5x: the automatic-choice tile is taller
  than the 320×740 viewport, which is why the layout test taps tile titles.
  Everything stays reachable by scrolling.
