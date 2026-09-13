# Calm workspace, 2026-09-13

Finish line: open a workspace, recognize the current project, and start or resume a session while occasional controls remain available in project and session details.

Non-goals: new APIs, transport/state changes, theme redesign, other screens, or Gas City implementation.

The project name is now the single entry to folder/workspace details, switching, and project management. Session rows retain title, working/request state, time, and a differing folder when relevant. Cost, diff totals, and a shared URL are disclosed through Details in the row menu and desktop context menu. Rename, sharing, archival, deletion, pins, search, and isolated tasks retain their existing routes.

An empty, fresh brief with unsupported review state no longer creates a separate workspace banner when the project sheet discloses that unknown state. Actual requests and stale state still render. No read acknowledgement or persistence behavior changed. The folder chooser presents a recovery notice once, keeps open/create/browse actions available, and discloses unsupported creation details on request. Existing localized copy is reused.

Accessibility: the project entry keeps a full row target and a descriptive tooltip; title scaling and scrollable sheets preserve large text. Default content is reduced without lowering body text size. Session metadata uses selectable LTR paths/URLs. No credentials, storage formats, or migrations changed.

## Verification handoff

Source and test work is ready for the coordinator's serialized checks; this branch has not run Flutter/Dart/native processes. Run pinned Dart format on the changed Dart files, then pinned Flutter:

```sh
flutter test --concurrency=1 test/workspace_stable_layout_test.dart test/workspace_hierarchy_test.dart test/projects_screen_test.dart test/project_health_screen_test.dart test/return_brief_widget_test.dart test/v2_feature_gating_test.dart test/accessibility_guidelines_test.dart
flutter test --concurrency=1 tool/capture/calm_workspace_test.dart
```

The capture harness writes light/dark 390dp 1x and 320dp 2x/2.5x workspace views, long titles, scrolled list ends, and project sheets to `docs/qa/calm-workspace-2026-09-13/`. It loads real fonts and asserts complete project/primary labels. Screenshots and runtime outcomes remain pending until the coordinator runs and reviews them. Diff whitespace check passed before handoff. Analyzer and stable integration gates remain required before release.
