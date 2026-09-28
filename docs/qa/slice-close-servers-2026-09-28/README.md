# slice-close-servers: close the servers, phone and setup board items (2026-09-28)

Branch `revamp/slice-close-servers`, from `feat/phone-setup-v2` at `ee0fdb7a`.
Source: `docs/qa/review-board-closure-2026-09-28/README.md`, gaps 7, 12 and 22,
plus the servers and phone items in the low-impact list and loose ends.

**Finish line:** every servers, phone and setup item left open by the closure
audit either reads in plain words with its way forward, or is recorded here as
not done, with the reason.
**Non-goal:** no new backend contracts: termux-processes for the in-app host,
provider-quota's collector path and profile-monitor's route removal (P4.2b)
stay open. host-management belongs to another agent.

Owner notes applied: profile-editor "Inline with v installa?", termux-setup-connect-termux
and termux-setup-update-sheet "Align with v2", and termux-setup-failed "Unify all installation into v2".

## What changed, per page

| Page | Change |
|---|---|
| profile-editor | **Refused connection:** now reads "The computer refused the connection. Check that the server is running there and that the address and port are right." It no longer says `opencode serve` beside an `opencode2 pair` command. The no-answer text changed the same way (`e7SetupRefused`, `e7SetupNoServerAnswer`). **Raw errors:** a check that fails before the server answers ("Connection test failed: …") shows "The server could not be checked. Check the address and this phone's connection, then try again." The raw socket or TLS text goes in a Details fold under the notice. A failed save's technical text is folded under its notice the same way. **Placement:** the verdict is a notice under the address field it is about (OpenCode and Codex/Paseo alike). Once the check answers, the form scrolls so the field and verdict sit together above the pinned Save & connect. "Enter the address instead" opens if it was folded. The link drawing and the slow-check "Stop checking" stay at the head. **Codex:** the start command is one line (`SetupCommands.codexStart`), so it no longer shows four `$` lines cut at the edge. The `codexAddressHelp` and `paseoAddressHelp` helpers are deleted. The address is checked when the person leaves the field, e.g. "ws:// works only for a server on this phone. Use a wss:// address for another computer." |
| servers | A saved server's line carries state and kind only ("Needs you", "2 working", "OpenCode 2", "Codex", "Claude Code or Pi"). The row menu has **Details**, which opens "<name> details" with the full address and, for Codex/Paseo, the project folder (copyable, redacted). |
| termux-setup-connect-termux | No answer: "Termux didn't answer. Tap Copy & open Termux, paste the line in Termux and press Enter, then come back here." The settings action is **Allow the permission in Settings**. The denial text no longer repeats it. Copy & open Termux shows only when allowing Termux is the next step. |
| termux-setup-failed | A too-old Termux is a failed row with its own **Get the current Termux** action, opened through `openExternalLink` (new `SetupProgressView.failureActions`). Returning re-checks. For a script error the app does not know, the row says "Stopped during: {stage}. What went wrong is under Details." The raw text goes in the redacted Details log. Known script messages are translated (`setupPlainMessage`). The kit checklist moves a wide row button under the words, as its spec already said. |
| termux-setup-unsupported | Off Android: **Connect a server**, a plain body without backticks or "requires Termux", a copyable `opencode2 pair` block, and **Add server**. The Termux engine no longer starts there. |
| termux-setup-update-sheet | **Confirm:** "Update {runtime}?" / "Installs version X, restarts the server on this phone and connects again." / "Your conversations are kept. The server is away for a minute while it restarts." **Reply in progress:** "A reply is still being written. Stop it or let it finish, then update." **Up to date:** when the pinned version is installed, a non-tappable "Up to date · {version}" row shows where Update was. |
| termux-setup-installed | Needs you now tells the cases apart. **Failed start:** "{runtime} didn't start…" + **Start again**. **Failed install or update:** "Installing {runtime} didn't finish…" + **Install again**, with Update hidden so it isn't offered twice. **Failed stop:** its own sentence. **Termux didn't answer:** its own sentence + **Try again**; that case used to read "Not set up". The script's text is only in the page's redacted Details (`PhoneHost.problem`, additive in `phone_host.dart`). |
| termux-setup (switch stopped) | "{runtime} didn't start after the switch. Your conversations are kept." above Try again / Return. |
| embedded-termux-attention-line | A leftover helper is named as one: "A leftover node process has been busy for 10 min with nothing to do", with a project variant. OpenCode is blamed only when the busy process is OpenCode. The line's ⋯ menu has **See what's running**, which opens Running on this phone. |
| tailscale-setup | The installed line is "Tailscale is installed." with no "VPN connection is unverified". The primary is **Continue to sign-in** (was "Continue to authentication"). A bare "Continue", as the critic asked, fails gate G28 (actions name their target). Add server's Tailscale step says **Enter the address** (`addServerTailscaleNext`). |
| termux-storage | While scanning, the scan's 8 stages are a list that fills in (done / working / waiting) as the script logs each stage (`TermuxStorageScanStage`). Sizes arrive with the report, because the script reports none mid-scan. Stop is the list's action, and the log is under Details. The intro is two sentences. |
| development-services-logs-sheet | No code change. The finding was wrong: `KitLogPanel` already polls `onRefresh` every 2 s while open. A new test guards it: new lines arrive, old ones never blank, reads don't pile up, and reading stops on close. |
| connection-status-details-sheet | The raw error fold starts collapsed. |
| agent-account | "Sign in with your ChatGPT account. You finish in the browser; this app never sees your password." The Details note is rewritten plainly. |
| server-settings restart sheet (loose end) | The app can't know how a remote server was started, so the sheet says to restart it the way it was started. `bash ubuntu-opencode.sh restart` sits in a folded "Set up with the Linux service script?". |

Strings: English only, in `app_en.arb`, followed by gen-l10n. Deleted: `codexAddressHelp`, `paseoAddressHelp`, `setupRuntimeUpdateDetail`, `setupConnectExisting` and `setupProgressViewFailedStageReason` (en and ar). `e7SetupConfirmUpdate` and `e7SetupUpdateInterruption` stay, because `setup_ui_messages.dart` still translates script messages with them.

## Tests

New behaviour tests. Each was seen failing on the base `ee0fdb7a` first, in a temporary second worktree or before the fix:
- `test/slice_close_servers_profile_editor_test.dart` (5): refused wording, placement and in view; raw error under Details; Codex one-line command; Codex blur validation with no standing helper; row line and Details sheet.
- `test/termux_setup_v2_words_test.dart` (8): no-answer and permission wording, Get the current Termux link, plain script failure with Details, unsupported page.
- `test/this_phone_plain_failures_test.dart` (7 cases): start vs install vs stop vs no-answer, Details, update confirm, up to date, switch stopped.
- `test/work_tab_status_line_test.dart` (4 new or rewritten): helper vs OpenCode wording, See what's running.
- `test/termux_storage_test.dart`, `test/tailscale_setup_test.dart`, `test/r16_says_things_once_test.dart`, `test/revamp/slice_p4_4_test.dart`, `test/revamp/screen_servers_2_test.dart`: storage stages, Tailscale words, agent account copy, collapsed fold, restart sheet.
- `test/development_services_screen_test.dart`: log follows output. This one already passed on the base; it is a regression guard.

New golden cases, phone and 1280x800: `servers_addserver_refused`, `servers_addserver_codex`, `servers_row_details` (in `test/revamp/screen_servers_1_test.dart`; the list, remove-sheet and row-menu goldens in `screen_servers_1`, `slice_r15`, `queued_prompt_move` and `queued_prompt_removal` were regenerated for the shorter row line), plus `test/revamp/slice_close_servers_termux_golden_test.dart` and `test/revamp/slice_close_servers_phone_golden_test.dart`. Regenerated and looked at: `add_server_*`, `first_run_connect_*`, `servers_welcome_*`, `servers_addserver_tailscale_*`, `servers_tailscale_setup_*`, `phone_termux_storage_*`, `agent_account_*`, `r16_account_signed_out_*`, `servers_server_settings_restart_dialog_notice_*`, `work_runaway_*`.

Gates pass: kit_ratchet, redaction, ui_glossary, no_raw_error_text, kit/kit_manifest, kit/kit_draft_manifest and architecture_boundaries. The ratchet and glossary counts only went down; the baselines were left as committed. `flutter analyze` over all 39 changed Dart files: no issues. `dart format --language-version=3.10`: clean.

Integration pass on the finished tree: 29 test files, run one at a time through `tool/qa/machine_lock.sh`, covering every new or changed test file and the main files for each screen touched. Also run: 11 servers-flow files (`first_run_*`, `accessibility_guidelines`, `app_diagnostics`, `capability_flows`, `desktop_platform_gating`, `text_scale_overflow`, `product_ui_regression`, …) and the servers goldens. The only failures left are the ones listed below, which fail on the base too.

Failures that are the same on the base, left alone (checked in a second worktree at `ee0fdb7a`):
- `server_codex_connect_flow` ×2, `server_pairing_paste` ×7, `oc2_server_discovery` ×3, `server_v2_connect_flow` ×5, `server_profile_reentry` "failed active delete…", `session_link_routing` "a saved server whose connection fails…".
- `ios_remote_platform_gating` ×3, `e7_setup_layout` "setup servers at 320dp 2.5x" ×2.
- Stale goldens: `screen_servers_1` (welcome, editor add, kind, ready, slow check), `queued_prompt_removal` "kept prompts" ×2, `screen_servers_2` pairing scanner ×10, `screen_phone_1`, `termux_v2_host`, `team_phone_v2`, `work_tab_golden`, `motion_setup`, `goldens/phone_setup_golden`, `agent_account_widget` ×5, `screen_usage_1_golden` ×4, `screen_work_4_golden`.
- `this_phone_screen` "the first Start asks once… (P6.7)", which fails on a pending timer.

## Images

Each pair is `before-<name>.png` (the base rendering of the same state) and `after-<name>.png`, dark unless the page's goldens are light:
- profile-editor: `profile-editor-refused-{phone,wide}`, `profile-editor-codex-{phone,wide}`
- servers: `servers-{phone,wide}`, plus `after-servers-row-details-{phone,wide}`
- termux-setup-connect-termux: `termux-setup-connect-termux-{phone,wide}`
- termux-setup-failed: `termux-setup-failed-{phone,wide}`, `termux-setup-failed-script-phone`
- termux-setup-unsupported: `termux-setup-unsupported-{phone,wide}`
- termux-setup-update-sheet: `termux-setup-update-sheet-phone`, `termux-setup-update-sheet-up-to-date-{phone,wide}`
- termux-setup-installed: `termux-setup-installed-start-failed-{phone,wide}`, `-install-failed-phone`, `-details-phone`
- termux-setup: `termux-setup-switch-stopped-phone`
- embedded-termux-attention-line: `embedded-termux-attention-line-phone`
- tailscale-setup: `tailscale-setup-{phone,wide}`
- termux-storage: `termux-storage-intro-phone`, `termux-storage-scanning-phone`
- agent-account: `agent-account-{phone,wide}`
- restart sheet: `server-restart-sheet-phone`

## Still open, and why

- **Device proof:** none of this has run on a device or emulator. Still to check:
  - a real refused and TLS-failing address in Add server
  - a too-old Termux going to the download page and back
  - the permission round trip in Settings
  - a failed Termux start and a failed install on This phone
  - a leftover node process opening Running on this phone
- **Install again only on the Termux path:** the in-app host can't produce "install didn't finish" on This phone, because its install failures stay on phone setup's progress screen.
- **Not in this slice:**
  - termux-processes: needs an in-app process inventory from the backend (codex-p53).
  - provider-quota: collector path, a P5.4 follow-up.
  - profile-monitor: P4.2b route removal, which is a Servers IA decision.
  - host-management: another agent owns it.

## Brief note

The generic wave-3 brief says not to edit phone setup screens. This slice's own prompt asked for the setup v2 Termux pages to be fixed, and its don't-touch list does not name them, so `phone_setup_termux_job_screen.dart`, `phone_setup_termux_screen.dart` and `setup_progress_view.dart` were edited. No `lib/builtin/setup/**` script was touched.
