# E7 Projects and saved-server attention

Finish line: all app-authored copy in Projects, Attention overview and Profile Monitor is localizable; project search/rename and monitor settings stay usable at 320dp with 2.5x text in both layout directions, preserving server paths and unknown-status truth.

Non-goals: protocol changes, session inventory/Workspace changes, automatic profile switching, monitoring policy changes, or the global language picker/corpus. Parent integrates the full Arabic catalog and verifies real Arabic rendering.

Scope: `projects_screen.dart`, `attention_overview_screen.dart`, `profile_monitor_screen.dart`, owned layout tests, English ARB/generated output and the new-key Arabic fragment. Related findings: E7 and the Workspace/Activity clarity and accessibility fix batch.

Implemented:

- Localized project loading failures, actions, search, counts, empty states, rename confirmation/errors, rename dialog and worktree plurals.
- Localized all attention overview prose, including unknown positive-observation boundaries and guarded explicit server-open actions.
- Localized the monitor's unsupported-connection explanation instead of displaying a state-layer English constant.
- Project paths render left-to-right independently of translated worktree descriptions; project names retain the interface direction.
- Quiet-hour times use a second line so labels and times do not compete horizontally at large text. Reminder choices may grow with text scale.
- Arabic additions are supplied only in `messages_ar.json`; no partial Arabic catalog is created here.

Checks: owned-source visible-literal scan and all 39 new Arabic placeholder contracts passed. Heavy gates are pending the coordinator's serialized slot. Focused command plan: pinned Flutter `pub get`, `gen-l10n`, serial tests `test/e7_project_attention_layout_test.dart test/projects_screen_test.dart test/profile_monitor_screen_test.dart test/profile_monitor_navigation_test.dart`, then scoped analyzer. The new six layout scenarios run both LTR and RTL at 320dp/2.5x and exercise real search/rename, explicit attention navigation, quiet-time picker and reminder persistence.

Limitations: direction-only fixtures use the English catalog until the parent integrates the complete Arabic corpus. Dynamic server project names, server errors, paths and request titles are intentionally not translated. Device screenshots and Arabic-catalog verification belong to the integrated candidate; no physical-phone proof is claimed here.

Source checkpoint: checks and generated localization pending the serialized slot. The old Attention empty-state Home reference was replaced with server list: connected navigation is Workspace/Files/Activity/More (`home_screen.dart`), and `/servers` routes to the server list (`main.dart`).
