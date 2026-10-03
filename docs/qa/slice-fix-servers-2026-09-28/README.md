# slice-fix-servers — 2026-09-28

Area: servers, connect flows, profiles, launch routing. Base: `bb9261ad`
(feat/phone-setup-v2). Input: the 38 non-golden failures listed for this
group in the 2026-09-28 full-suite re-run at `7954e980`.

Result: **38 failing tests → 38 passing**. Verdicts: 0 PRODUCT BUG,
38 STALE TEST (35 assert behaviour an intentional Sept 26–28 change replaced,
3 test harness gaps the new behaviour exposed), 0 GATE/INVENTORY. No `lib/`
file changed.

## Shared helper

`test/support/kit_field_finders.dart` — `editableOf(tester, finder)` returns
the framework `TextField` under a kit field. `KitField.fieldKey` now sits on
a `TextFormField` (a1410445, KitField), so `tester.widget<TextField>(byKey)`
threw "TextFormField is not a subtype of TextField". Every such read in this
group's tests goes through the helper.

## Verdicts

| Test | Verdict | Cause (commit) → fix |
|---|---|---|
| agent_account_widget: explicit sign-in opens reviewed official host… | STALE | The link sheet names the host inside a sentence, "Opens {host} outside this app." (06102116) → `textContaining`. |
| agent_account_widget: Servers account entry reaches the panel… | STALE | Row menus open on long-press of the row; the per-row menu button is gone (71417a2f) → long-press `server-row-<id>`. |
| agent_account_widget: production capture usage light / dark / large (3) | STALE | A window row reads "Codex · 5-hour window" (82eb38cc) → exact new titles. |
| connection_v2: health false and active-profile persistence failure fail closed | STALE | Each attempt keeps an 8 s connection-status clock until it runs out or dispose (3d64653c); the test ended with it pending → pump 8 s in the test. |
| consent_in_flow: deleting a server removes its answers for good (10-min hang) | STALE (harness) | Under Android capabilities, profile deletion awaits the home-widget snapshot write and the launcher/tile write; their channels `oc/background` and `oc/shortcut` were unmocked and never answer inside `testWidgets` (found by tracing the deletion awaits: it stopped at `await _pendingWidgetSnapshotWrite`, then at `await _pendingLauncherWrite`). → mock both channels, as `profile_deletion_test.dart` already does. |
| server_profile_reentry: failed active delete keeps the current connection | STALE (harness) | Same wait on the unmocked `oc/background`/`oc/shortcut` channels (pumpAndSettle timed out) → answers them in the test. |
| e7_setup_layout: setup servers at 320dp 2.5x LTR / RTL (2) | STALE | TextFormField cast (a1410445) → `editableOf`. |
| goldens/settings_golden: servers_add_failed · dark / light (2) | STALE | Add server first asks what runs there (P3.9, 3d251f37); the scene typed into a URL field that was not built → `openServerManualAddress` in `test/support/settings_scenes.dart`. Now only a pixel diff remains (refresh follows); the scene shows the failure verdict (checked the test image). |
| ios_remote_platform_gating: iOS remote chat reads and sends… | STALE | The composer's commands row reads "Commands and agents" (chat-3, e28442b0). |
| ios_remote_platform_gating: dark / light iOS About… (2) | STALE | About's identity row is the build version; the platform is said by its line, the remote-only summary (c2889432) → reveal the version row, still assert the iOS summary and the Android/desktop copy absent. |
| launch_session_shortcut_routing: a tap after a final connection error routes to servers | STALE | One status slot, connection first (P4.4, 3d64653c: connection, app stopped, heat, local work, update). After a failed connection the connection line outranks the launch's one-shot notice → assert the connection line is shown. |
| launch_shortcut_routing: new task during password re-entry drops with a notice | STALE | Same priority (3d64653c). See follow-up 1. |
| launch_shortcut_routing: new task after a final connection error routes to servers | STALE | Same priority (3d64653c). |
| session_link_routing: a saved server whose connection fails routes to Servers | STALE | Same priority (3d64653c). |
| oc2_server_discovery: editing endpoint clears / retains cached generation evidence (2) | STALE | Row menu on long-press (71417a2f); the row says what the server is, never where; the address moved to Details (17047913) → exact "OpenCode" / "OpenCode 2". |
| oc2_server_discovery: known OC1 user reaches phone setup with no runtime forced | STALE | Installing through Termux is the v2 job with Termux as host (P1.2, 935945d6) → expect `PhoneSetupTermuxJobScreen`; Termux has its own engine, so `PhoneSetup.termux` gets the fake too (a channel engine left timers pending). |
| server_codex_connect_flow: Codex save failure keeps token and project inputs editable | STALE | TextFormField cast (a1410445). |
| server_codex_connect_flow: Codex submit freezes fields and backend until connect completes | STALE | TextFormField cast; the backend is Add server's first step, not on the connect step (P3.9, 3d251f37) → assert it is absent and Back does nothing mid-save; Add server ends on its ready step → `openReadyServer`. |
| server_pairing_paste: pasting a pairing code fills url, username and password | STALE | A paired password is held for the save, not typed into the field; the field shows "Saved" with Replace (71417a2f). → `expectHeldPassword` plus the probe received the pairing password. |
| server_pairing_paste: the confirmation names the host it chose | STALE | TextFormField cast. |
| server_pairing_paste: the pairing password never appears in the confirmation | STALE | Held password (71417a2f). The no-plain-text check is kept; now no editable holds the value. |
| server_pairing_paste: a pairing code pasted into the URL field is never left there | STALE | TextFormField cast + held password. |
| server_pairing_paste: a pairing code in the clipboard is honoured by the password paste button too | STALE | Held password. |
| server_pairing_paste: an ordinary password paste still works | STALE | TextFormField cast. |
| server_pairing_paste: a server that answers with a stale password says so | STALE | TextFormField cast. |
| server_v2_connect_flow: a v2 401 without a password focuses…, a rejected password shows…, the paste affordance fills…, the reveal toggle keeps working… (4) | STALE | TextFormField cast (a1410445). |
| server_v2_connect_flow: a mid-session 401 raises the update-password banner action | STALE | The connection status belongs to a saved server; with no active profile it stays hidden (3d64653c) → the store now has an active profile. |
| settings_server_updates: shell failure remains scoped and can be retried | STALE | The resume in the test arms the phone server's 5 s recovery check (6ed0ec26), owned by the connection scope → unmount and dispose inside the test. |
| settings_server_updates: an Android service timeout turns the switch off and says why | STALE | The switch's limit line is now "Android stops this after 6 hours a day…" (d0047ca3). |

## Checks (pinned Flutter 3.47.1, through tool/qa/machine_lock.sh)

- The 14 owned files (not the golden): 173 tests, all passed.
- goldens/settings_golden: remaining failures are pixel diffs only (skipped
  per brief; a reviewed refresh follows).
- Gates: kit_ratchet, redaction, ui_glossary, no_raw_error_text,
  architecture_boundaries, kit/kit_manifest, kit/kit_draft_manifest —
  121 tests, all passed.
- `flutter analyze --no-pub`: no issues.

## Follow-ups (not fixed here)

1. A profile whose saved password can no longer be read
   (`requiresPasswordReentry`) gets the connection line "‹name› isn't
   answering · Reconnect to ‹name›", though nothing was tried and Reconnect
   cannot help. The P4.4 contract says credentials take priority over
   transport failure, but `ConnectionController.connectionStatus` maps only
   `passwordRejected` to `credentialsRequired`. Fixing it needs a copy
   decision (the credentials line says "Server password changed", which is
   not what happened), so it is left for the connection owner.
2. With a failed connection, a launch, shortcut or link that was dropped
   says so only through the connection line; its own notice is outranked
   (by design, 3d64653c). If the owner wants the dropped act named, the
   notice could become the connection line's supporting text.
3. `iosAppTitle` in `app_en.arb` has had no user since c2889432.
