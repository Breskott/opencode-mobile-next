# P3.9 Add a computer in one path (2026-09-27)

Branch `revamp/slice-P3.9`, from `feat/phone-setup-v2` at `e1ccfc42`.

**Finish line:** agent-choice and connection-help fold into Add server's
steps: what runs there, then Tailscale when that is the way, then the address
or pairing code, the check, and a ready moment.
**Non-goal:** no new server kinds.

## What changed, per page

| Page | Change |
|---|---|
| agent-choice | **Removed** (`agent_choice_screen.dart`, `widgets/first_run_choice.dart`). It is now Add server's first step. The welcome's "On my computer", the list's Add server, the server switcher's Add, phone setup's Add and the guide's Add server all open the same flow. |
| connection-help | **Removed** (`connection_help_screen.dart`). Errors explain themselves where they happen. An `http://` address on the network gets a notice under the field ("…needs an https:// address. Tailscale gives it a private one…") with **Use Tailscale**, which opens the Tailscale step. The guide's "Connection help" row is gone. Its search entry is now "Add server" (under Saved servers), which opens the flow and keeps the connection-help search words. Nothing suggests a public relay or the open internet. |
| profile-editor | A new server with nothing preset is **stepped**, with a kit staged bar ("Step 2 of 4 · Pair or enter the address"): **1 What runs there** (the three kinds act on tap; the other ways in are listed under them: this phone, Tailscale, external agents) → **2 Tailscale on this phone** (only on that path; the Tailscale page's own checklist, now `TailscalePhoneSteps`) → **Pair or enter the address** → **Checking** (its own step while it runs) → **Ready** ("<name> is connected", "Connected to <host>", a linked drawing, and **Open <name>**). Back steps back through the flow. A secret typed before stepping back is held as "Saved · Replace", never refilled (SEC-3). The auto check after a pause now runs on every Add server, not only first run. A check or pairing that runs **8 s** shows "<host> has not answered yet…" with **Stop checking**, and its late answer is ignored. That applies to editing a saved server too. Editing a saved server, re-entering a password and the phone's own server still use one form. |
| tailscale-setup | Only refactored. The checklist and the help fold were pulled out as `TailscalePhoneSteps` and `TailscaleHelpFold` so the step can reuse them. The page's goldens are unchanged. |
| session-link-server-missing-banner | Now a kit sheet: **"Add this server?"**, with **Add server** (it opens the flow) and Dismiss. The old `MaterialBanner` is gone (G1 count 2 → 1). |
| guide | "Add server" opens Add server itself, not the Servers list. The Connection help row is removed. |

Acceptance:
- "Add server" and "Connect OpenCode 2" start the same flow. The separate "Connect OpenCode 2" entry no longer exists, and its unused strings were deleted. Add server and "On my computer" both land on step 1. Tested in `test/add_server_steps_test.dart`.
- A check that runs longer than 8 s offers Cancel. Tested.
- The flow ends in a ready moment. Tested. When the first connect turns the root into the shell, the ready step still shows on top, and Open leaves it (`server_v2_connect_flow_test`).

## Blocker (feasibility, AGENTS.md rule 2)

**The "Add this server?" sheet cannot be prefilled.** A session link
(`SessionLink`, `lib/domain/session_handoff.dart`) carries only the sending
phone's profile id and the session id. It never carries the server's
address, and adding that "would need a privacy review first" (source comment).
So the sheet asks and opens an empty Add server. Prefilling needs a
link-contract change plus a privacy review. That work is not done here.

Not in this slice: the programme's "profile-monitor folds into server rows".
It is in `programmes.json` but not in this work unit's finish line.

## Tests

- New: `test/add_server_steps_test.dart`, 9 behaviour tests, all pass. They cover one entry, kind → connect with Back, slow-check Cancel with the late answer ignored, no Cancel on a quick check, the ready moment and Open, Close on ready, Tailscale as a step (Back walks it, the save remembers `oc.tailscale.<id>`), the `http://` advice → Tailscale step, and a held password that is still sent.
- Updated for the flow: `add_server_flow`, `server_profile_editor`, `first_run_computer_path`, `first_run_auto_test`, `server_v2_connect_flow`, `session_link_routing`, `ios_remote_platform_gating`, `e7_setup_layout`, `first_run_welcome`, `phone_setup_welcome_entry`, the helpers in `test/support/`, and `revamp/screen_servers_1` (new goldens `servers_addserver_{kind,tailscale,slowcheck,ready}` at phone size, plus kind and ready at 1280x800).
- Goldens regenerated and reviewed: `test/goldens/add_server_*` and `first_run_connect_*` (they now go through step 1), `servers_profile-editor_add-opencode_*` and `servers_guide_loaded_*` (the Connection help row is gone).
- Ledger: `parts/g-servers.json` and `parts/j1-settings-more.json` updated, then rebuilt. `check_ui_ledger.py` reports the same 217 errors as the base, and warnings went from 44 to 41.
- `kit_ratchet_baseline.json`: only tightened, for the deleted files and `main.dart`'s `MaterialBanner`.
- `flutter analyze` is clean.
- Compared with the base in a second worktree across 46 affected test files: **no new failures**. 37 tests that failed on the base now pass, for example the Tailscale editor test, the "choosing X" tests, not-same-network and Show the commands. Failures that already exist on the base and are left alone: search "Settings search" ×5, desktop, iOS and termux gating, `first_run_auto_test` ×3, `server_v2_connect_flow` ×4, `tailscale_setup_test` ×2, `kit_ratchet` G17 and G21, `golden_harness`, `design_standard`, `ui_ledger_coverage` and `architecture_boundaries`.
- Also already on the base: `first_run_computer_path` "fits 320dp at 2.5x" for opencode and paseo ×4. Expanding "Show the commands" trips KitCodeBlock's SEC-4 assert, because `SetupCommands.legacyServe` and `paseoStartPrivateNetwork` contain `PASSWORD=your-secret` placeholders that `KitRedact` treats as credentials. The fix belongs in `setup_commands.dart` and is left to its owner.

## Images

Before (base `e1ccfc42`): `before-agent-choice-{phone,wide}.png`, `before-add-server-{phone,wide}.png`, `before-guide-phone.png`.
After: `after-1-kind-{phone,wide}.png`, `after-2-tailscale-phone.png`, `after-2-connect-phone.png`, `after-3-slow-check-phone.png`, `after-4-ready-{phone,wide}.png`, `after-guide-phone.png`.

## Still needs a device

The work unit's proof is an emulator run against a live OpenCode 2 (password never recorded): pair by QR and by typed address, and watch the check, Cancel and Ready. It was not run here: this slice has widget tests and goldens only. Also check the session-link sheet from a real `opencode-mobile://session` QR.
