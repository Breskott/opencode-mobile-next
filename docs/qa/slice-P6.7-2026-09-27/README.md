# P6.7 Consent once, in flow (2026-09-27)

Branch `revamp/slice-P6.7`, from `feat/phone-setup-v2` (merged up to
`52ab78c4`). Builds on Codex's state half (`docs/qa/codex-p67-2026-09-27/`,
`lib/state/in_flow_consent.dart`, `lib/state/repeated_permission_consent.dart`).

**Finish line:** each consent is asked at the moment it matters, at most once
per server, remembered, and a declined one explains itself on its row on
What runs by itself (P6.1's `automation-settings`), where it can be answered
again. **Non-goal:** no NotificationRouter rewrite; no mobile-data download
gate (blocked, below).

## What changed

| Where | Change |
|---|---|
| `lib/state/consent_owners.dart` (new) | One owner per saved server of `InFlowConsent` and `RepeatedPermissionConsent`, shared by every asking place and the Settings page; `closeProfile` drains writes. |
| `lib/state/connection.dart` | `deleteProfileAndLocalData` awaits `ConsentOwners.closeProfile` before the `oc.*.<id>` sweep (same pattern as P6.1). Reverting it makes the deletion test fail (checked). |
| `in_flow_consent.dart`, `repeated_permission_consent.dart` | Added `close()`; `declinedCount()` / `forgetDeclined()` for the Settings row (declined or left-unanswered invitations). |
| Phone server first start (`phone_server_consents.dart`, new; wired in `PhoneServerCard._start`) | After a successful start: battery exemption first, then the maker's auto-start (only where the maker has one), as neutral `showKitConfirm` questions with "Not now". Claimed before showing, answered before the platform step runs; later starts ask nothing. `askConsent` is the one place the words live (also used from Settings). |
| First-reply notification question (`first_reply_notify_card.dart`) | Now the preset "Tell me when the agent needs me": copy "Notify you when the agent needs you?"; the question is claimed for the current server before it shows and the answer is kept there; a yes turns on request notifications + the background connection (no longer finished-run notifications). Still one time per device (first run). |
| "Always allow" on the third identical ask (`always_allow_invitation.dart`, new) | A `KitAskLine` under a permission card: "Asked 3 times. Always allow `git *`?" · Always allow / Keep asking. Accept states the scope in a confirm, replies `always` directly, and records it only after the server took it (a refusal is said, invitation stays). Only where `persistentPermissionGrants`. |
| What runs by itself | New group **Your answers** first: unanswered, then declined (each says what it means), then "Always allow offers" (N declined → Ask to always allow? → offered again after 3 more asks), then allowed (opens Keep running / Notifications, where the real setting lives). Only asked questions get a row. |

## Call sites for other owners

- **Chat lane (P4.1c, `chat_screen.dart` / `chat/**`)** — place the
  invitation directly under each permission request card (the conversation's
  pending-permission card, and optionally in `showPermissionSheet`):
  ```dart
  AlwaysAllowInvitation(
    key: ValueKey('always-allow-${permission.id}'),
    controller: _conn,
    sessionID: permission.sessionID,
    requestID: permission.id,
  )
  ```
  Until then the invitation is built and tested but not visible in a
  conversation.
- **Setup / This phone (P5.3, phone setup screens)** — the first start
  mostly happens there. After a successful start, call
  ```dart
  await askPhoneServerConsents(context,
      connection: connection,
      bridge: ref.read(appLifecycleBridgeProvider),
      profileId: profile.id);
  ```
  in `phone_setup_start_screen.dart` (after `builtinServerStarterProvider.start(profile)` returns no failure, before `connection.connect`) and `this_phone_screen.dart` `_start()` (after `_host.state == PhoneHostState.running`). Asking twice is harmless: the second call asks nothing.

## Blocked (feasible=false for this part)

- **Downloads over 50 MB on mobile data:** no metered/mobile transport signal
  exists (`monitorWifiAvailable` is Wi-Fi only; false also means offline or
  Ethernet) and no trustworthy download size contract. Kept unavailable, as
  Codex recorded. Needs a native mobile/metered/unknown contract first.
- NotificationRouter dedupe/cancel-on-answer: out of scope (Codex blocker stands).

## Tests

- New `test/consent_in_flow_test.dart` (8): battery then auto-start once,
  remembered after restart, declined row explains and sorts first; exempt
  stock phone asks nothing; allow from a declined row runs the platform step;
  needs-you preset claimed per server, decline explained, allow from Settings
  turns on requests + background; accept saves then turns on requests only;
  a server asked before is not asked again; third distinct ask offers once,
  replay not counted, rebuild keeps it, refused reply not recorded, accepted
  recorded, never again; Keep asking remembered, counted on Settings, offer
  again resets; deleting a server removes both records and closes the owner.
- New in `test/phone_server_card_test.dart`: first start asks once.
- Updated `test/first_reply_notify_card_test.dart` (new copy; finished runs no
  longer turned on). Golden `chat_notify_{light,dark}` regenerated (copy).
- New goldens `test/revamp/p67_consent_golden_test.dart` (6).
- Codex's two state tests pass; `flutter analyze` clean.
- Compared with the base (`52ab78c4`, second worktree): **no new failures**.
  Already failing on the base: `kit_ratchet` G17/G21, 18 settings goldens in
  `screen_settings_1_golden_test`, 12 other `chat_states` goldens,
  `ui_glossary` G11/G28 (no new entries), `architecture_boundaries` ARCH-1/2
  (no new entries), `nudge_moments` ×6, `first_run_landing` ×5.

## Images

Before: `before-automation-phone-light.png`, `before-automation-wide.png`
(P6.1's page), `before-chat-notify-light.png`.
After: `after-answers_light.png`, `after-answers_dark.png`,
`after-answers_1280x800_dark.png`, `after-first_start_battery_light.png`,
`after-first_start_battery_1280x800_dark.png`,
`after-always_allow_invite_light.png`, `after-chat-notify-light.png`.

## Migration

New keys `oc.inFlowConsent.<id>` / `oc.permissionConsent.<id>` (swept on
server deletion). No migration: existing installs have no answers, so no
rows; the first-run question keeps its device flag.

## Still needs a device

Emulator walk-through of each moment on a fresh install: start the phone
server from Servers (battery prompt → Android's own dialog; a Xiaomi-class
maker → auto-start screen), the first reply's question, a third identical
bash ask (after the chat call site lands), then What runs by itself.
Opening a system screen is not proof of a grant; the rows say so.
