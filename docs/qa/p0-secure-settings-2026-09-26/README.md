# P0.1, P0.5, P0.6 — 2026-09-26

Worktree: `oc_app-p0-secure`, branch `fix/p0-secure-settings`.
Slices from `docs/ux-system/programmes.json` (programme P0).

Commits (one per slice):

1. `65f9a057` — fix(settings): AI Team row opens the team page, not Plugins (P0.5)
2. `f3471451` — fix(notifications): say when Android is blocking this app (P0.6)
3. `aa3c3729` — fix(mcp): mask HTTP header values, key visible, reveal on press (P0.1)

## P0.5 — Settings › AI Team opens the team page

**Changed:** `lib/ui/search/search_index.dart` (`settings-ai-team` entry's
`open` callback). When `controller.profile?.orchestration` is set (team on)
it now pushes `TeamHomeScreen(controller: team)` using the live
`controller.orchestration`, the same source the `ai-team` destination entry
and Work's own door already use. Off, it still opens `TeamIntroScreen`
(unchanged). The Settings hub row (`settings_screen.dart`'s
`settings-ai-team` row) calls `_openEntry(entries['settings-ai-team']!, ...)`,
so it automatically follows the same fix — no separate edit needed there.

**Tests:**
- `test/team_discover_test.dart`: added `'tapping it while on opens the team
  page, never Plugins (P0.5)'` next to the existing `'reads On · the server
  once it is on'` test. The pre-existing `'has an AI Team row that reads Off
  ... and opens the intro'` test covers the off state, so both states are
  now covered per the slice's acceptance.
- Result: `flutter test -j 2 test/team_discover_test.dart` — 21/21 pass.
- **Fail-before-fix evidence:** reverted `search_index.dart` only, reran the
  new test with `--plain-name`: fails with `TeamHomeScreen` not found
  (`findsOneWidget` got `findsNothing`). Restored and reran green.

## P0.6 — Notifications say when Android blocks them

**Changed:**
- `android/app/src/main/kotlin/.../MainActivity.kt`: added `"openAppSettings"`
  to the `oc/background` channel handler (native half), using
  `Settings.ACTION_APP_NOTIFICATION_SETTINGS` (API 26+, with
  `EXTRA_APP_PACKAGE`) and falling back to the same
  `ACTION_APPLICATION_DETAILS_SETTINGS` intent the `oc/termux`, `oc/voice`
  and `oc/camera` channels already use below API 26. No new intent pattern
  invented — mirrored the existing one.
- `lib/background/live_background.dart` (Dart half, same channel):
  - `openNotificationSettings()` — invokes `openAppSettings`, swallows a
    missing channel/platform error (test/desktop no-op).
  - `sendTestNotification()` — posts a real alert via the existing
    `showCodingAlert` bridge with `kind: question` (routes to the "Coding
    requests" / needs-you channel) and a fixed non-secret
    `testNotificationID`. Deliberately does **not** check `enabled` (the
    live-background toggle) the way `showCodingAlert` does — a test must
    work whether or not that unrelated preference is on. The native side
    still refuses when Android itself blocks notifications, so a `false`
    result is the honest answer.
- `lib/ui/screens/settings/notifications_settings_screen.dart`:
  - `_notificationsBlocked` getter reads
    `controller.backgroundLive.notificationGranted` (gated on
    `platformCapabilities.supportsBackgroundService`, matching how the rest
    of this screen already gates Android-only state).
  - A `KitNotice` (tone `attention`) at the very top of the page when
    blocked, title/message from new ARB copy, with one `KitAction` "Open
    Android settings" wired to `openNotificationSettings()`.
  - `notify-finished-runs`, `notify-requests` and `notify-quota-alerts`
    switches now pass `onChanged: null` while blocked (Flutter dims a
    disabled `SwitchListTile` on its own — "the switches read as blocked").
  - A `KitRow` "Send a test notification" under the notification toggles,
    calling `sendTestNotification()`.
  - Re-check on resume: this screen already had a `WidgetsBindingObserver`
    calling `backgroundLive.refreshStatus()` on
    `AppLifecycleState.resumed` (pre-existing, unchanged) — the honest state
    now shows through it automatically, no new observer needed.
- Copy added to `lib/l10n/app_en.arb` and `app_ar.arb` (real Arabic, not
  machine-placeholder): `notifyBlockedTitle`, `notifyBlockedMessage`,
  `notifyOpenAndroidSettings`, `notifySendTest`, `notifySendTestDetail`.

**Tests:**
- `test/background_live_test.dart`: two new unit tests — `sendTestNotification`
  ignores the live-mode gate but returns the platform's real answer (both
  `true` and `false` cases), and `openNotificationSettings` calls
  `openAppSettings` exactly once.
- `test/notifications_settings_screen_test.dart`: new group `P0.6: Android
  blocking this app's notifications` — notice shown + switches disabled +
  "Open Android settings" invokes the platform; notice absent and switches
  enabled once granted; re-checks on resume (mutates what the fake platform
  reports, fires `tester.binding.handleAppLifecycleStateChanged(.resumed)`,
  confirms the notice disappears without reopening the screen); "Send a test
  notification" calls `showCodingAlert`; and the blocked case where the send
  call itself reports `false`.
- Result: `flutter test -j 2 test/background_live_test.dart
  test/notifications_settings_screen_test.dart` — 52/52 pass. Also reran
  `test/background_coding_alert_test.dart` (unaffected, still green) since it
  shares the same controller.
- **Fail-before-fix evidence:** reverted every non-test file above, reran
  both test files — compilation fails (`sendTestNotification`,
  `openNotificationSettings`, `notifyBlockedTitle`, `notifySendTest` all
  undefined). Restored and reran green.

## P0.1 — MCP header values are secrets

**Feasibility check (AGENTS.md rule 2):** grepped every caller of
`McpSetupScreen` — exactly one, `integrations_screen.dart`'s "Add" action,
always a blank draft. There is no edit-existing-MCP-server screen anywhere
in this app today. So the acceptance line "editing an existing MCP server
shows 'saved · replace'" has no code path to attach to yet; documenting
this here rather than inventing an unreachable prefill branch (rule: don't
build a workaround for a feature that doesn't exist, and "never prefills a
saved value" is trivially true — there is nothing to prefill from). Whoever
builds an edit flow (or P2.4's "MCP Add chooser") must carry this rule
forward: never populate the value field, always show a replace affordance
for a previously-saved header.

**Changed:**
- `lib/ui/screens/mcp_setup_screen.dart`: replaced the single multi-line
  "one `KEY=VALUE` per line" header field with one row per pair
  (`_HeaderRow`: two `TextEditingController`s + a `revealed` flag). Header
  name stays a plain `TextFormField`; the value field uses native
  `obscureText` (so the mask is real, not a cosmetic overlay) with a
  per-row reveal `IconButton` (`AppIconography.visible`/`hidden`, the same
  icons and `Show/Hide` pattern `servers_screen.dart`'s connection-token
  field already uses). An "Add another header" `KitButton.tertiary` adds
  rows; a remove `IconButton` appears once there is more than one row.
  `_headersDraftText()` reassembles the rows into the exact `KEY=VALUE\n...`
  text the existing `_pairs`/`_pairError` validation already expects, so
  that validation logic (duplicate names, invalid characters, the "Use
  KEY=VALUE" message) is unchanged and still exercised by the pre-existing
  tests (updated to type into the two new fields instead of one).
  No new kit part: `KitSecretField` isn't built yet (`docs/ux-system/kit-v2.md`
  lists it as a gap). Marked `// kit-gap: KitSecretField` at the field
  declaration and the row builder, per the owner's kit-only-UI rule; this is
  the smallest raw addition that can mask a value (two `TextFormField`s + one
  reveal `IconButton`, only one remove `IconButton` when there is more than
  one row). The rest of the screen was left as it already was (still a
  pre-existing, unmigrated raw-widget screen outside this slice's scope).
- `lib/diagnostics/app_diagnostics.dart`: `sanitize()`'s
  `authorization|proxy-authorization` pattern only matched the `KEY: VALUE`
  form; extended it to also match `KEY=VALUE` (MCP headers use `=`). Without
  this, a short `Authorization=Bearer <token>` string under 32 characters
  slipped past every other pattern in `sanitize()` — confirmed by writing
  the redaction test first and watching it fail (see below) before making
  the change.
- Copy added to `app_en.arb`/`app_ar.arb`: `mcpHeaderName`, `mcpHeaderValue`,
  `mcpShowHeaderValue`, `mcpHideHeaderValue`, `mcpAddHeader`, `mcpRemoveHeader`.

**The redaction test** (`test/mcp_setup_screen_test.dart`, group `P0.1:
header values are secrets`):
- Confirms the Add form's header row starts empty (nothing to prefill).
- Types a fake bearer into the value field, confirms `obscureText: true` by
  default (checked via the underlying `TextField`, since `TextFormField`
  doesn't expose `obscureText` itself), confirms the reveal toggle flips it
  to `false` and back to `true` (tooltip text checked both ways).
- Pushes it through **save (error path)**: the repository is made to throw a
  realistic "already exists" error; every rendered `Text` widget in the tree
  is enumerated (the same technique `test/server_pairing_paste_test.dart`
  already uses for the server password field) and asserted not to contain
  the fake token. This deliberately does **not** use `find.textContaining`
  on the whole tree, because that finder also matches a live `EditableText`
  by its controller's logical text — which would flag the person's own
  still-open input field as a "leak" even though nothing has actually
  rendered it anywhere; enumerating `Text` widgets only checks what is
  actually displayed as text.
- Pushes it through **save (success path)**: same check (the screen pops on
  success, so this is largely a confirmation that popping doesn't leave
  anything behind), plus confirms the real value did reach
  `repository.addedDraft.headers` unmodified — masking must not corrupt the
  data that is actually sent.
- Pushes a fake header through the **diagnostics path** directly:
  `AppDiagnosticsController.record` with a message containing
  `Authorization=Bearer <fake>`, asserts `reportText()` doesn't contain it —
  this is the test that caught the `sanitize()` gap above.
- A second small test adds and removes header rows (no remove button on a
  lone row).

**Results:** `flutter test -j 2 test/mcp_setup_screen_test.dart
test/app_diagnostics_test.dart test/library_integrations_test.dart
test/e7_library_layout_test.dart` — 44/44 pass (the last two files' existing
McpSetupScreen references were unaffected).

**Fail-before-fix evidence:**
- Reverted `lib/diagnostics/app_diagnostics.dart` only: the diagnostics
  redaction test fails, token visible in `reportText()`. Restored, green.
- Reverted `mcp_setup_screen.dart` + the ARB/generated-l10n files: the two
  P0.1 widget tests fail (`No element` — the old single `mcp-headers` field
  no longer exists once the fix is gone, since the test now looks for the
  new per-row keys). Restored, green.

## flutter analyze

`flutter analyze` (whole project, no path filter) — **No issues found!**
(19s), run after all three commits.

## gen-l10n

`flutter gen-l10n` run after each ARB edit and once more at the end; no
errors. `lib/l10n/app_localizations*.dart` are checked in as usual (this
repo commits generated l10n output).

## Not done / left for the coordinator

- **Emulator proof: pending coordinator.** No emulator or device was used in
  this worktree (out of scope per the task's rules — no APK builds, no
  adb/emulator). Screens to capture on an Android 15 emulator once merged:
  1. **P0.5** — Settings → AI Team with the team on → lands on team-home
     (not Plugins). Also from search ("ai team").
  2. **P0.6** — System Settings → revoke POST_NOTIFICATIONS for the app →
     open Notifications settings page → the blocked KitNotice appears,
     the three notification switches are dimmed. Tap "Open Android
     settings" → confirms it opens the app's notification settings (not
     just app info) on API 26+. Grant the permission, return to the app
     (resume) → notice disappears without reopening the screen. Tap "Send a
     test notification" → a real notification arrives in the "Coding
     requests" channel.
  3. **P0.1** — MCP → Add server (remote) → type a fake
     `Authorization` / `Bearer faketoken123` pair → screenshot showing the
     value masked (dots) and the key in clear → tap the reveal icon →
     screenshot showing the value in clear → hide it again. Add a second
     header row, remove it.
- **"saved · replace" (P0.1 acceptance line):** not applicable today — see
  the feasibility note above. No edit-existing-MCP-server screen exists to
  attach this to.
