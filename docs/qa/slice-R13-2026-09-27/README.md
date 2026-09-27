# slice-R13: Work tool pages with no counts, no refresh icons and one inset (2026-09-27)

Definition: `docs/ux-system/revamp/leftover-units.json` id `slice-R13`
(after slice-R4). It adopts R4's `KitSectionLabel` and the section-gap rule of
`KitRowGroup` on the Work tool pages. No Codex record exists for this slice.

## What changed, per page

- **All conversations** (`global_sessions_screen.dart`)
  - Removed the summary line ("4 conversations in 2 projects" and its loaded
    and filtered variants) and the count beside each project label.
  - Inside each project, rows are ordered by urgency: first the ones that need
    the person (a permission, question or form), then working ones, then the
    rest, newest first. A needs-you row now shows Work's `KitNeedsYou` mark and
    starts with the words "Needs you ·".
  - Rows move when a conversation starts, finishes or asks something. A cheap
    urgency key is checked on each controller change, so this happens without
    a reload.
  - Project groups no longer wrap themselves in extra bottom padding, which
    made the section gap twice as large after R4. The label's own gap (22)
    separates them.
  - The search field was already on the 16 dp gutter through `KitScreen`, and
    a test now guards it (field, segmented control and panels share the rails).
- **Worktrees**: removed the "Worktrees" label and its count, because the
  title already says it. The main copy and the worktrees are now **one list**
  (`worktrees-group`). The top-bar refresh is gone: pull to refresh stays, and
  Try again appears only in the error state. The glossary term on the label
  went with the label. The empty state and the create dialog still explain
  what a worktree is.
- **Cloud environments** (`managed_workspaces_screen.dart`)
  - Removed the top-bar refresh.
  - Removed `_providers()`, so providers are no longer listed on the page. The
    provider is chosen only in the New environment sheet.
  - With one provider, the sheet drops the radio list and its subtitle says
    "In Daytona" (new ARB key `managedWorkspacesCreateIn`). With several, it
    shows a `KitSectionLabel` "Provider" and the choice list, where the
    `SectionLabel.inline` used to be.
  - New environment is missing when providers fail to load, or when the server
    has none while environments exist. In those cases one `KitNotice` says why.
- **Project health**: removed the top-bar refresh (pull to refresh stays).
  `SectionLabel` is now `KitSectionLabel`. Removed the label counts ("2
  changed", "1 of 2 running", "1 of 2 on"); each row already says its own
  state. When a read fails, the notice sits right under its label with no
  extra space2. "Language services" and "Formatters" get the section gap from
  the rule.
- **Projects**: removed the top-bar refresh. "Open projects" drops its
  hand-made `margin: top sectionGap`, and the label rule now gives it the gap.
- **Always allowed actions** (`saved_permissions_screen.dart`)
  - Removed the top-bar refresh and the "3 actions" count.
  - Before, the intro and notice paddings added their own `sectionGap` below
    them, and R4 then added a second gap above the label (44 dp in total).
    They now leave the gap to the label rule (22 dp).

### Deliberate deviations (for the coordinator)

- The acceptance says "'Environments' ... get a section gap". With Providers
  gone, "Environments" became the only section, and it repeated the page title
  "Cloud environments". The owner rule is to never repeat a name the title
  gives, and Worktrees follows the same precedent. So the label was removed,
  not spaced. To bring it back, add `label: l10n.e7LibraryEnvironments` on
  `managed-workspaces-group`.
- The slice title says "no counts", so the counts on Project health and Always
  allowed actions were removed too, though their acceptance lines only name
  the refresh icon.

### Copy

- Added `managedWorkspacesCreateIn` ("In {provider}").
- Deleted keys this change made unused: `savedPermissionsCount`,
  `e7LibraryRefreshAlwaysAllowedActions`, `e7LibraryRefreshProjectHealth`,
  `e7LibraryChanged`, `projectHealthRunningOf`, `projectHealthOnOf`,
  `e7WorkspaceFilteredLoaded`, `e7WorkspaceLoadedSummary`,
  `globalSessionsSummaryCount` and `managedWorkspacesProviders`. They were
  deleted from both ARBs, and gen-l10n was run.
- `e7GlossaryWorktreeExplanation` stays because `test/kit/kit_term_test.dart`
  uses it.

## Tests

New or changed behaviour tests:

- `test/global_sessions_screen_test.dart`, group `slice-R13`:
  - urgency order (needs you, then working, then newest) with the needs-you mark
  - a conversation that starts working moves up without a reload
  - no counts
  - search field, segmented control and panels on one gutter, and a single
    22 dp gap between projects
  - count assertions in the older tests were replaced
- `test/worktrees_screen_test.dart`, group `slice-R13`:
  - no label, count or refresh icon, and pulling down reloads
  - the main copy and the worktrees are one list
  - the empty state explains a worktree (replaces the P3.1 label-term test)
- `test/managed_workspaces_screen_test.dart`:
  - no refresh icon or provider list, and pulling down reloads
  - several providers: the sheet asks which, and creates with the one chosen
  - one provider: the subtitle says "In Cloud runner" and there is no picker
  - environments but no provider: a notice says why, with no New environment
- `test/project_health_screen_test.dart`, group `slice-R13`:
  - no refresh icon or counts, and pulling down reloads
  - labels start where the panel starts, 22 dp under the section above
  - a failed read keeps its `KitSectionLabel`
- `test/projects_screen_test.dart`: no refresh icon, and "Open projects" is
  22 dp under the folder actions.
- `test/saved_permissions_screen_test.dart`:
  - no refresh icon, and the label is 22 dp under the intro (it was 44 before
    this change)
  - the count assertions were replaced
- `test/revamp/screen_work_3_test.dart`: the Providers and count expectations
  were inverted.

Run once on this candidate, `--concurrency=3`:

- the six screen test files above
- `revamp/screen_work_3_test`, `revamp/screen_work_4_test`
- `kit_ratchet_test`
- `e7_library_layout_test`, `teaching_empty_states_test`,
  `v2_feature_gating_test`, `codex_project_navigation_test`, `project_hub_test`,
  `e7_project_attention_layout_test`

The result was 39 failures. Every one of them also fails on the base commit
`0a579ea6`, checked in a temporary worktree. The list:

- project_health: 2
- projects: 10
- kit_ratchet G17 and G21
- e7_library_layout: 3
- teaching_empty_states: 2
- v2_feature_gating: 6
- project_hub: 12
- e7_project_attention: 2

The change adds no new failures. `flutter analyze` is clean.

One test was left out on purpose: pull to refresh on Projects. Its fake
controller hangs a fling-triggered reload in the test zone, so there is no
fling test for it.

## Goldens

`--update-goldens` was run on `screen_work_2`, `screen_work_3`,
`screen_work_4` and `screen_settings_1`. Only the goldens of this slice's
pages were kept. The work_development_services, work_session_import,
work_isolated_task_sheet, settings_appearance, settings_hub and
settings_privacy goldens were stale from earlier merges and were reverted.

Before and after images are in `before/`, `after/` and `compare/` (side by
side). The shots are the phone (412x915) loaded state of each page, the
1280x800 wide window, and the one-provider create sheet.

## Still needs a device

- On a live server, how often a conversation's needs-you or working state
  re-orders All conversations while you watch (the urgency key only rebuilds
  when it changes).
- Pull to refresh on each page on a real phone.
- The one-provider sheet subtitle with a real Daytona adapter.
