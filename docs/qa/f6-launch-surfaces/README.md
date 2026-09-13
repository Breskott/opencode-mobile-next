# F6 — Launch surfaces (Android)

Branch `feature/f6-launch-surfaces`, base `dev` 6c20ed7. Backlog source:
`docs/backlog/innovation-2026-09-06.md` §F6; F6-S1a (static Connect / New
task shortcuts) already shipped, see `docs/backlog/rolling-swarm-2026-09-07.md`.

## Finish line

A user who pins a session sees it in the app icon's long-press menu; tapping
it opens exactly that chat, cold or warm, once, without sending anything. A
Quick Settings tile reads "OpenCode · 2 need you" from a cached count while
the app is not running and opens Activity on tap. Both surfaces are withdrawn
on an explicit disconnect and on profile deletion, and neither exists on
desktop or iOS builds.

**Non-goals:** launcher voice query (F6-S3, investigation note only, below);
cross-server counts on the tile (needs F3-S1's profile monitor); any launcher
entry that sends a prompt, answers a permission, or switches servers by itself.

## What shipped

### F6-S1 — pinned-session shortcuts

Product:

- `lib/background/pinned_session_shortcuts.dart` — `PinnedSessionShortcuts`
  writer: at most 4 pinned sessions, `{id, title}` only (title trimmed,
  cut at 80 chars, localized "Untitled session" fallback), published over
  `oc/shortcut` → `setPinnedSessions` only when the payload changed, with
  the owning profile remembered in `oc.pinnedShortcuts`. `clear()` on
  disconnect; `clearForProfile()` with the same three outcomes the widget
  snapshot reports (`nothingToClear` / `cleared` / `failed`).
- `lib/state/connection.dart` — `_publishLaunchSurfaces` runs from
  `notifyListeners` next to the widget snapshot, only while
  `status == connected`; `disconnect()` withdraws both surfaces;
  `deleteProfileAndLocalData` step 3 clears them with ownership checks and
  reports refusals (`DeleteProfileResult.clearedPinnedShortcuts`,
  `clearedAttentionTile`, new `failures` sentences). Lifecycle suspension
  does **not** withdraw them (the entries would vanish every time the app
  was backgrounded, which is exactly when a launcher shortcut is used).
- `lib/platform/launch_shortcut.dart` — `SessionLaunch` (profile id +
  session id), `pendingSession` notifier, `consumeSessionLaunch` cold drain
  and `launchedSession` live push on the existing `oc/shortcut` channel;
  same generation guard as the static actions so a live tap beats a stale
  cold-start value. `LaunchAction.activity` added for the tile.
- `lib/main.dart` — `_openSessionForLaunch`: waits like New task while the
  saved server connects, then `pushNamed('/chat/<id>')`; drops a launch for
  another profile with a notice (no silent server switch, mirroring widget
  rows); no-server / re-entry / final-error each consume with a notice; a
  warm tap on the chat already on top does not stack it. One-shot: the
  pending value is taken at consumption and never re-fires.
- Native: `PinnedSessionShortcuts.kt` (`ShortcutManagerCompat`, ids
  `oc.session:<profile>:<session>`, intent = MAIN → MainActivity with
  exactly `oc.shortcut.profile` + `oc.shortcut.session`), stale entries —
  including user-pinned home-screen copies — are **disabled** with a reason
  before the new set is published; `MainActivity.captureSessionLaunch`
  removes both extras before parking, and pushes live only after Dart's
  readiness ack. `androidx.core:core:1.13.1` declared explicitly.
  `ic_shortcut_session.xml` icon; `shortcut_session_untitled` /
  `shortcut_session_unavailable` strings (en + ar).

### F6-S2 — Quick Settings tile

Product:

- `lib/background/attention_tile_snapshot.dart` — writes
  `oc.attentionTile` = `{pendingCount, profileID, updatedAt}` when the count
  or owner changes; count is `permissions + questions + forms` of the
  connected server (the same sum `liveStatus().pendingCount` gives the
  ongoing notification and Activity shows). `clear()` on disconnect,
  `clearForProfile()` on deletion.
- Native `AttentionTileService.kt` — passive `TileService` (binds only when
  the panel is open, so it works with the app dead and costs nothing
  otherwise). Reads `flutter.oc.attentionTile` from `FlutterSharedPreferences`
  in `onStartListening`; label "OpenCode", subtitle "N need you" / "Nothing
  needs you" (Android 10+; folded into the label as "OpenCode · …" below
  that); `STATE_ACTIVE` when N > 0. A snapshot older than 24 h or absent →
  plain "OpenCode", no count, inactive. Tap → `MainActivity` with
  `oc.shortcut = "activity"` (added to the native whitelist), collapsing the
  shade via `PendingIntent` on Android 14+ and the deprecated Intent form
  below; `unlockAndRun` on a locked device. Manifest: `exported="true"`,
  `BIND_QUICK_SETTINGS_TILE`, `QS_TILE` action, `@string/tile_label`, icon
  `@drawable/ic_launcher_monochrome`. Strings + plurals in en and ar.
- Dart routing: `LaunchAction.activity` pushes `ActivityScreen` over the
  shell (route name `/activity/launch`, not stacked twice); without a saved
  server it opens the servers screen with `launchUiActivityNoServer`.

### Gating

`PlatformCapabilities.supportsLaunchShortcuts` and
`supportsQuickSettingsTile` (Android only). `LaunchShortcut.supported` now
reads the capability object (honours `debugPlatformCapabilities`). Both
writers write nothing off Android; `clearForProfile` still runs everywhere
because the stored record is the privacy artifact.

### Localization

New `launchUi*` keys in `lib/l10n/app_en.arb` with Arabic in
`docs/qa/f6-launch-surfaces/messages_ar.json`. `tool/assemble_arabic_arb.py`
now also globs `docs/qa/f[0-9]*-*/messages_ar*.json` so later slices keep the
same fragment shape (`missing 0; placeholder mismatches 0`). Regenerating
also picked up three Arabic strings that were already in fragments but had
fallen back to English in the committed `app_localizations_ar.dart`
(`e7SharedDeviceReportedError`, `e7SharedOpenCodeUnreachableTryAgain`,
`chatUiQueueOnlySteeringNeedsOpenCode2`). Native strings live in
`res/values/strings.xml` and `res/values-ar/strings.xml`.

`PRIVACY.md` gained a paragraph on what the widget, long-press menu and tile
can show and when they are cleared.

## Evidence

Toolchain: pinned Flutter 3.47.x at the Shorebird cache path; JDK 17.

- `flutter analyze --no-pub` → No issues found.
- `dart format` on all changed Dart files.
- Focused tests (all green, `--concurrency=4`):
  - `test/pinned_session_shortcuts_test.dart` (11): cap 4, titles+ids only,
    title cut, unchanged-payload skip, empty set forgets the record, clear on
    disconnect, clearForProfile owner / other / none / unreadable /
    off-Android, non-Android publishes nothing.
  - `test/attention_tile_snapshot_test.dart` (9): payload shape, rewrite only
    on change, negative → 0, clear, clearForProfile variants, off-Android.
  - `test/launch_session_shortcut_test.dart` (8): cold drain once, static and
    session drained independently, live push, invalid payloads ignored
    (both directions), stale cold-start loses to a live tap, inert off
    Android, dispose.
  - `test/launch_session_shortcut_routing_test.dart` (9): warm tap opens the
    exact chat once with `created == 0`, `prompted == 0`; cold-start drain
    routes once; no stacking; other-server drop without switching; no
    server; final error; waits while connecting; tile opens Activity (not
    stacked twice); tile without a server.
  - `test/launch_surfaces_controller_test.dart` (7): pins → channel payload
    capped at 4 in list order, unpin republishes, unchanged pins do not
    republish, tile cache carries only the count/owner/timestamp, nothing
    while connecting, explicit disconnect withdraws both, lifecycle
    suspension keeps them, desktop writes nothing.
  - `test/launch_surfaces_native_contract_test.dart` (11) — source-pinned
    Kotlin/manifest/resource contract (see "Unverified" for what this does
    not prove).
  - Updated: `test/launch_shortcut_native_contract_test.dart` (whitelist =
    static ids ∪ `activity`), `test/profile_deletion_test.dart` (records
    seeded for `doomed`, cleared on its deletion with a native withdraw,
    kept on `keeper`'s deletion, refusals reported),
    `test/desktop_platform_gating_test.dart` and
    `test/ios_remote_platform_gating_test.dart` (new "launch surfaces"
    groups; `oc/shortcut` added to the iOS never-called channel list).
- Existing tests for touched files, green: `launch_shortcut_test`,
  `launch_shortcut_routing_test`, `widget_snapshot_test`,
  `l10n_coverage_test`, `background_notification_navigation_test`,
  `share_intent_test`, `share_routing_test`, `connection_v2_test`,
  `demo_isolation_test`, `external_agent_state_test`,
  `profile_monitor_check_in_test`, `reader_preferences_test`,
  `provider_quota_overview_test`, `provider_quota_screen_test`,
  `read_aloud_test`, `saved_server_connection_card_test`,
  `settings_server_updates_test`.
- Android compile: `gradle -p android :app:compileReleaseKotlin --no-daemon
  --max-workers=2 -Dorg.gradle.jvmargs=-Xmx2g --offline` with JAVA_HOME =
  JDK 17 → BUILD SUCCESSFUL (2m 25s). The repo has no `gradlew`; the cached
  Gradle 9.5.0 wrapper distribution was invoked directly. This task also
  merges the manifest and compiles resources, so the new service entry,
  strings, plurals and drawable are known to be well-formed.

## Native-only and unverified on a device

Nothing below ran on an emulator or phone in this slice:

- That launchers actually render the dynamic entries next to the two static
  ones. Most launchers show 4–5 entries total and list static shortcuts
  first, so with 4 pins a user may see only 2–3 of them; the cap stays at 4
  per the backlog, and the ordering is the launcher's.
- `disableShortcuts` on user-pinned copies (greyed with
  `shortcut_session_unavailable`) and `enableShortcuts` on re-pin. On
  Android < 8 (`ShortcutManagerCompat` compat path) dynamic shortcuts are a
  no-op.
- Launcher rate limiting (`isRateLimited`): a refused publish is swallowed
  and the entries keep their last state; the next changed payload retries.
- The tile: passive binding, subtitle rendering on Android 10+ vs label
  folding below, `startActivityAndCollapse(PendingIntent)` on 14+,
  `unlockAndRun` on a locked device, and the `singleTop` delivery of the
  `activity` extra into `onNewIntent` when the app is already up.
- The 24 h staleness cut-off is a judgement call, not a measured one.
- Tile count truth while backgrounded: the cache is written only while the
  Dart side is connected. Without background mode the count is whatever was
  last confirmed before the app was backgrounded; with background mode it
  tracks live events. The tap always lands on Activity, which shows the
  real state.

## F6-S3 — launcher voice query: investigation note (deferred)

What "ask the assistant to talk to OpenCode" would actually require on
Android, and why none of it is built here:

1. **There is no third-party hook into the hotword path.** "Hey Google" /
   the default assistant is owned by the app holding the assistant role
   (`RoleManager.ROLE_ASSISTANT`); only that app receives the hotword and
   `ACTION_ASSIST`. An app cannot register a phrase or intercept the
   assistant without *becoming* the assistant (`VoiceInteractionService`,
   which requires the user to select it in Settings and replaces Google
   Assistant / Gemini entirely). That is a different product.
2. **The supported route is App Actions (`shortcuts.xml` capabilities /
   built-in intents) or Android's `actions.intent.*` deep links.** These
   deliver a *parsed* intent to an Activity — text the user spoke, already
   transcribed by the assistant — and require a Play Console App Actions
   review and a published listing; sideloaded builds and the current
   `docs/verification` release model cannot exercise them, and the Assistant
   → Gemini migration has narrowed BII coverage to a moving target.
3. **Any inbound text is an untrusted draft.** Whatever arrives would have
   to be shown in the composer with the destination visible (server,
   session, agent) for the user to send deliberately — exactly the rule the
   share target already follows — never auto-sent and never a tool
   approval. That part is cheap; the routing that gets text there is not.
4. **The static and dynamic shortcuts shipped here are already voice-
   reachable in the narrow sense** — Assistant can open an app shortcut by
   its label ("open New task in OpenCode") without any App Actions work,
   which covers the launch half of the hypothesis.

Decision: deferred. Reopen only if (a) a Play listing exists so App Actions
can be reviewed, or (b) the product is willing to ship a
`VoiceInteractionService` and own the assistant role. Neither is planned.

## Limitations

- Pins are scoped per profile *and* location (`SessionPinStore.scope`), so
  switching project folder republishes that folder's pins. A shortcut for a
  session in another folder still opens the chat by ID (same rule as
  notification taps); OpenCode 2 servers that scope sessions to a workspace
  may show that chat as unavailable until the location matches.
- The tile is single-server (active connection only) until F3-S1 provides a
  cross-server count.
- Widget snapshot, pinned shortcuts and tile share `_widgetSnapshotSuspended`
  during profile deletion; the field name was kept to limit churn in the
  single-owner `connection.dart`.
