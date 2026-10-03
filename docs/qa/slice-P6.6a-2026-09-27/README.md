# P6.6a Defaults instead of questions (2026-09-27)

Branch `revamp/slice-P6.6a`, from `feat/phone-setup-v2` at `f19a5b9c`. Builds on
Codex's backend half (`docs/qa/codex-p66a-2026-09-27/`, merged in `f9b4f6c4`):
`InteractionDefaults` (pure policy) and `InteractionDefaultsStore`
(`oc.defaultNotices.<profileId>`, swept with the profile).

**Finish line:** the app picks what is knowable instead of asking (the only or
most recent project, "my-app" on first run, the server's default model by name,
the review view that has changes), says so once where it matters, and the
thing's own place keeps the way to change it.
**Non-goal:** no new settings; no guessing where the answer is not knowable.

## What changed, per page

| Page | Change |
|---|---|
| review-workspace | `initialScope` is now optional. Without one (the conversation's Review) the page opens the first view **with changes**, in the order This conversation → Uncommitted → Whole branch (`InteractionDefaults.review`). The other views are read once, into the same cache the prefetch fills. When that is not the first view, one dismissible `KitNotice` says "Showing Uncommitted: it is the view with changes." once per server (per app run without a profile). A view the caller names (Files → Uncommitted) is kept even when empty; a person's pick in the picker ends the default. Nothing changed anywhere → the existing empty state. |
| workspace (Work tab) | The fresh-connection project pick now goes through `InteractionDefaults.project` (same result as before: the project still picked, else the only one, else the one the server lists as used most recently). After it really opens, a once-per-server notice: "Opened shop, the only project on this server." (plain, dismiss only: there is no other) or "Opened new, the project worked on most recently." with **Choose another project** (opens Projects). A restored saved project is the person's own: nothing is said. |
| project-folder-new-dialog (Work chooser, Projects) | With no project of the person's own on the server (root and AI Team folders do not count) the name field starts filled with **my-app**, ready to create or type over (`ProjectFolderActions.suggestedName`). |
| settings (hub, Model row) | The row keeps the model's name at its end and, when the person did not pick it, says why under the title: "Server default". Tap still opens the one model sheet to change it. |

New shared helper `lib/ui/widgets/default_notices.dart`:
`claimDefaultNotice(kind:, choice:, profileId:, prefs:)` (once per server via
`InteractionDefaultsStore`, once per run without a profile; failures stay
silent) and `modelDefaultOf(ConnectionController)` (the connection's model as
a `DefaultChoice`: explicit pick, server default by name, only model, or
unresolved).

Copy (English only, `app_en.arb`): `defaultProjectOnlyNotice`,
`defaultProjectLastUsedNotice`, `defaultProjectChange`,
`defaultReviewScopeNotice`, `defaultModelNotice`, `defaultModelChange` (the last
two are for the chat call site below).

### Already in place before this slice (verified, not changed)

- New conversation chooser (P4.5): skipped when Solo is the only way; the last
  choice is marked "Last used".
- Review's view picker is hidden when only one view exists.
- The connection resolves the server's configured chat model, then the
  provider default, after sign-in, and keeps an explicit pick
  (`connection.dart` catalog refresh).
- Phone setup's ready screen already proposes "my-app" (P1.4, not touched).

### Call sites left for the chat lane (P4.1c owns `chat_screen.dart` / `chat/**`)

1. **Model announced once where it is used** (composer). After the catalog is
   loaded and the composer is shown (not in `build`):

   ```dart
   final choice = modelDefaultOf(_conn);
   final said = await claimDefaultNotice(
     kind: DefaultKind.model,
     choice: choice,
     profileId: _conn.profile?.id,
     prefs: _conn.store.prefs,
   );
   if (said != null && mounted) {
     // KitNotice.offer(message: l10n.defaultModelNotice(KitBidi.auto(said)),
     //   action: KitAction(label: l10n.defaultModelChange,
     //     onPressed: () => showModelPicker(...)), onDismiss: ...)
     // Offer the action only when choice.canChange.
   }
   ```

2. **Review notice once per server**: in `chat_screen.dart`'s
   `ReviewWorkspace(...)` add `profileId: _conn.profile?.id`. Without it the
   notice is said once per app run (and comment drafts stay in memory only, as
   today).

### Not done (named)

- Voice pack by RAM, voice by locale and Queue over Steer belong to P6.6's
  other half; Codex's API covers them, no UI is wired here.
- The in-app folder browser's "New project" field still shows "my-app" only as
  its example (its known-project list is best-effort, so "none" is not
  knowable there).

## Tests

- New: `test/revamp/slice_p6_6a_defaults_test.dart` (12): review default to
  Uncommitted and to Whole branch, said once across reopen; a conversation with
  changes stays first; a named view is kept; nothing changed → empty state;
  Work opens the only project and says so once across a fresh connection; of
  several, the most recent with the change action; a restored project says
  nothing; "my-app" proposal rules; model server default by name, once per
  server; explicit model says nothing; Settings row shows name and "Server
  default".
- New goldens: `test/revamp/slice_p6_6a_defaults_golden_test.dart` (12 images,
  `p66a_*`, phone + 1280x800, dark + light).
- Updated goldens (intended): `p310_settings_hub_full_{dark,light}`,
  `p310_settings_hub_paseo_dark` (Model row gains "Server default").
- `screen_review_1_golden_test` empty shot now has an empty Uncommitted view
  too, so it still shows the empty state.
- Existing tests for the changed files (71 files that build Work, Review,
  Settings, Projects or the folder actions, plus `interaction_defaults_test`
  and `kit_ratchet_test`), run once at `-j 3`: every failure also fails on the
  base commit `f19a5b9c` (compared in a separate worktree, same files, same
  flags) except the three p310 goldens above, now updated. Pre-existing at base
  include kit_ratchet G17/G21 (other files), screen_review_1 pixel diffs,
  screen_servers_2/screen_work_3/screen_work_4 goldens, provider_quota,
  projects_screen, work_tab_cleanup (`KitText` cast), reader_preferences.
- `flutter analyze lib test`: no issues.

## Images

Before (base goldens): `before-review-phone-dark.png` (conversation empty →
"no changes" although Uncommitted had changes), `before-work-phone-light.png`,
`before-settings-phone-light.png`, `before-settings-wide-dark.png`.
After: `after-review-phone-dark.png`, `after-review-wide-light.png`,
`after-work-phone-light.png`, `after-work-wide-dark.png`,
`after-settings-phone-light.png`, `after-settings-wide-dark.png`.

## Still needs a device

The unit's proof (emulator first-run recording from install to first reply)
was not run: widget tests and goldens only. On a device, check the Work notice
after the first connect to a server with one project, "my-app" in the create
dialog on an empty in-app server, and the Settings Model row after sign-in.
