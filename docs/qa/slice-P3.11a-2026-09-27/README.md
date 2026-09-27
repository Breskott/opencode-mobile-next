# slice-P3.11a: small merges outside the chat library (2026-09-27)

Branch `revamp/slice-P3.11a`, base `53fd6d18` (feat/phone-setup-v2).

Finish line: each non-chat pair in P3.11 becomes one landing. Non-goal: no
visual redesign beyond the merge. The Codex sv3 skill-conversation hooks were
read and are **not** wired here (see "Not done").

## What changed, per merged pair

| Removed page | Now lands on | Change |
|---|---|---|
| `session-handoff-dialog` | `continue-on-computer-sheet` | `showSessionHandoff` (Related / All conversations menus) re-reads the session and opens the same sheet the conversation menu opens, with the same `cd … && opencode --session …` command. The OpenCode 1 `attach` command and the metadata "reference" JSON are gone (journeys: "one sheet, one command, copy"). The server without `cliSessionResume` gets a stated reason; a session that moved project says so. Menu labels now read "Continue {title} on computer" / "Continue on computer". The sheet's command is now a `KitCodeKind.command` block with R3's hanging wrap (leftover). |
| `integrations-forget-uncertain-auth-sheet` | `integrations-forget-pending-auth-sheet` | One `_confirmForgetSignIn(name)` question ("Forget the {provider} sign-in?") for saved and unconfirmed sign-ins (code now lives in `integrations_screen.dart`; `pending_auth_recovery.dart` holds only the source token). |
| `command-auth-sheet-confirm-sheet` | `command-auth-sheet` | Start acts directly; the sheet intro says what it runs and whom it trusts. Leftover: 8 s after a start the sheet offers "Check {provider} sign-in now" (at once for an attempt already running). |
| `skills-preview-sheet` | `skill-activation-sheet` | Already one sheet in code (screen-library-4); removed from the ledger. |
| `provider-quota-enroll-dialog` | `provider-quota` | "Alert me about {provider} on {server}" row turns monitoring on in place at 90 %; the threshold row and named Stop replace it. |
| `workspace-directory-details-dialog` | `workspace-context-sheet` | Folder rows open the project sheet with Details open on that folder; on a server that cannot manage projects the sheet has no project rows. |
| `workspace-session-details-sheet` | `session-context` | Row menu "Conversation context" pushes Conversation context; its Details now hold the folder and shared link (also before any reply). |
| `question-sheet-dismiss-dialog` | `confirm-sheet` | Already `showKitConfirm`; ledger target fixed. Leftover: Send is pinned through `primaryListenable` and enables as the person answers. |
| `manage-project` (file deleted) | `project-hub` | Development services and Cloud environments are Project tab tools (`ProjectTool.services`, `.workspaces`, with search entries); the project sheet's Manage project row is gone. Leftover: Terminal stays listed, dimmed with the registry reason, on a server without one. |

Other leftovers done: credential sheet caption "Keys stay on your server.",
the "Active account unknown…" paragraph deleted, remove confirm "Remove the
{provider} account “{name}”?" / "Remove “{name}”"; folder chooser body
"Conversations run inside a folder on {server}." and tertiary "Open a project
you used before".

Ledger: merged pages removed from `docs/design/ui-ledger/parts/*`, targets
repointed, ledger rebuilt (checker 220 → 208 errors, all pre-existing).
Census shots for the removed pages dropped or retargeted. Strings made unused
were deleted from `app_en.arb` / `app_ar.arb`; `gen-l10n` run.

## Tests

- New: `test/revamp/slice_p3_11a_test.dart` (folder row → project sheet,
  row menu → Conversation context, pinned Send enables and sends), a
  session-context facts test, and rewritten tests in
  `session_command_handoff_test`, `screen_library_3_test` (Start acts, 8 s
  check, one forget question, account copy), `screen_usage_2_test` /
  `provider_quota_screen_test` (monitoring row), `project_hub_test`,
  `v2_feature_gating_test`, `projects_screen_test`, `project_health_screen_test`,
  `development_services_screen_test`, `accessibility_guidelines_test`,
  `codex_project_navigation_test`, `search_index_test`.
- Ran the 88 test files that import a changed file plus `kit_ratchet_test`.
  441 failing tests on the branch vs 436 on the base in a second worktree for
  the same files; the only new ones were five goldens whose pages changed on
  purpose (project hub, question sheet, folder chooser; regenerated and
  inspected) and one new test fixed. All other failures are pre-existing on
  the base (chat_live_events, many goldens, kit_ratchet G17/G21, …).
- Goldens regenerated: project hub, question sheet (light), folder chooser,
  and the library-3 accounts / sign-in and usage-2 quota goldens (these were
  already stale on the base). `quota_enroll_sheet_*` deleted.
- `flutter analyze`: clean.

## Images (412x915 phone; 1280x800 wide where noted)

- Continue on computer / quota: `before_quota_enroll_sheet_412x915_dark.png`
  (the sheet that is gone; the monitoring row is asserted in tests).
- Server sign-in: `before_/after_library_command_auth_sheet_light.png`.
- Accounts: `before_/after_library_credential_management_sheet_light.png`,
  `before_/after_library_credential_management_remove_sheet_light.png`.
- Project tab: `before_/after_project_hub_loaded_light.png`,
  `before_/after_project_hub_loaded_1280x800_light.png`.
- Question sheet: `before_/after_shell_question_sheet_unanswered_light.png`.
- Folder chooser: `before_/after_work_workspace_folder_chooser_light.png`,
  `before_/after_work_workspace_folder_chooser_error_light.png`.

## Not done / needs a device

- Emulator screenshots, one per merged pair (the plan's proof): not taken;
  goldens above stand in.
- `KitSliverRowGroup` for the Work head + recent rows: needs slice-R4 (not
  merged). The "Work" subtitle under the server pill is not in this write set
  (shell header).
- Skills preview mode could offer "Use in a new conversation" through the
  sv3 `SkillConversationController`; not wired (new feature, not a merge).
- `SessionCommandHandoffGateway` (OC1 attach command) is now unused by the UI;
  left in `lib/domain` / `lib/api` for the owner to retire.
