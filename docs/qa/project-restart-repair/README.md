# UXPROJECT-01 — selected project changes after restart

Priority: P1. Status: implemented and focused-tested, including remote workspace preservation and delayed-write deletion; native app proof and integration analyzer remain coordinator gates.

Finish line: choosing project B survives a fresh controller/app restart for the same profile, while profile switching and deletion remain isolated. Unverified location truth must be explicit.

Non-goal: new project model or backend protocol redesign. Write fence: connection.dart, relevant location persistence/deletion contracts, focused tests and the minimum Workspace naming correction. Chat, Termux, localization output and other agents' worktrees were not edited.

Baseline: `724a8bd430e570d27dac8c0b5eb2968a2087e0a8`, dedicated `fix/project-restart-state` worktree. This slice does not build or install an APK, invoke signing/CI, or push.

## Reproduction and cause

The new regression explicitly selects `/work/b`, verifies that it was saved, disposes the controller, then starts a fresh controller and ProfileStore over the same preferences. The server answers with the catch-all project for B and lists only its `/work/a` project. On the baseline, the regression fails with Expected `/work/b`, Actual `/work/a`; see [red evidence](red-regression.txt).

`_validatedSavedLocation` treated absence from `listProjects` as proof the saved directory had disappeared. It replaced the selection with the newest catalog project, or cleared the saved choice when the catalog was empty. Plain folders and worktrees can be absent from that catalog. `revalidateRestoredLocation` repeated the same replacement later. Existing tests explicitly asserted that old behavior; those expectations now assert selection preservation and an honest unverified notice.

Two related paths made the symptom possible: `_selectLocation` saved only after network refresh and only if locationError stayed null, and automatic Workspace initialization could run while saved-state restoration was pending. Workspace also labelled an unlisted B with the first catalog project's A name, even while its displayed path remained B.

## Resulting contract

| Path | Result |
| --- | --- |
| Explicit project/folder/worktree selection | Same public methods; per-profile selection is saved before awaiting catalog/session refresh. Slow or failed refresh leaves the choice remembered. |
| Cold connect / app restart | Saved directory and remote workspace ID are preserved even when lookup or catalog is inconclusive. Neither is replaced by another project or a local-workspace fallback. |
| Catalog refresh / reconnect revalidation | A matching result may clear the unverified notice. Missing or unavailable entries cannot change scope. |
| Automatic initial selection | Fills an empty connection only after restore, with no saved or currently selected scope. An old screen callback cannot override an explicit choice. |
| Profile switch | Each profile retains its own existing `oc.location.<profileId>` entry. No preference schema or migration changed. |
| Profile deletion | Selection admission is closed while deleting; queued location writes drain before the scoped preference sweep. |
| Protected home/root paths | Existing refusal and old saved-home cleanup remain. Reading an existing home-folder conversation still does not replace the remembered project. |
| Workspace context | A catalog match names the project; an unlisted selected directory uses its basename in the page and context sheet, including empty catalogs. Its full path stays available. Nested folders still match their known project. |

Current unverified copy: “Couldn’t verify this project. Your selection was kept.” The workspace-specific equivalent names “this workspace”. Existing project selection remains the recovery route. A failed preferences write retains the existing honest “could not be remembered for the next launch” notice. Remote workspace omission or lookup failure also preserves the selected workspace ID; late verification must confirm both pieces of scope before clearing the notice.

Explicit selection callers reviewed: ProjectsScreen, Workspace workspace switcher, project-folder open/create actions, managed workspace open/delete fallback, worktree open/remove fallback, session import, existing-session navigation in chat/search/activity, controller worktree task/open/move/warp flows. These continue through `selectLocation`, `selectLocationForExistingSession` or the guarded `selectInitialLocation`; signatures are unchanged. Codex continues to treat the configured profile folder as authoritative on connect.

## Verification

Pinned Shorebird Flutter 3.47.2, serial `--no-pub --concurrency=1`:

- [Controller final run](controller-green.txt): 43 passed across `connection_location_restore_test.dart` and `connection_sse_test.dart`. Includes explicit B → fresh controller, initial-discovery race, slow failed refresh persistence, profile isolation, unavailable/empty catalogs, later revalidation, protected paths, reconnect and atomic SSE replacement.
- [Workspace final run](workspace-green.txt): 35 passed across `workspace_hierarchy_test.dart` and `projects_screen_test.dart`. Includes unlisted-folder naming, full path access, narrow/large text and project opening controls.
- [Supporting run](supporting-checks.txt): profile store, profile deletion and transport factory guard files passed (24 cases). This earlier combined run also records an SSE ordering failure, corrected and rerun in the controller final log. Do not read the whole earlier command as a pass.
- Changed Dart files formatted; `git diff --check` passed. No analyzer or full-suite claim. Native force-stop/relaunch evidence remains with the coordinator.

The repair cannot infer an earlier selection already overwritten by the old build. Choosing the intended project again establishes the selection that the fixed build preserves.

Coordinator review follow-up is now verified:

- [Scope and deletion run](workspace-scope-and-deletion.txt): all 60 cases across location restoration (19), SSE (27), and profile deletion (14) passed. This includes omitted/unavailable remote workspace catalogs, later confirmation without scope change, and a delayed selection save followed by profile deletion and fresh-store load. The same log then records two obsolete UI expectations for “No projects opened”; those assertions were corrected to the retained active-folder contract.
- [Final projects run](projects-final.txt): all 20 project UI cases passed after that assertion correction. Empty or newly refreshed empty catalogs show the active folder and retain session/search access.
- This follow-up supersedes the initial controller behavior log. The Workspace hierarchy file's 15 earlier cases, profile-store 8 cases and transport factory 2 cases remain the supporting coverage described above. No full-suite or analyzer claim is made.

The save queue is drained before deletion's scoped preference sweep. A selection paused on storage also checks deletion admission before starting refresh, so it cannot repopulate profile-scoped data during the deletion transaction.
