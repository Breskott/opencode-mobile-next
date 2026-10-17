# Team models and first-run setup (2026-10-15)

Branch feat/team-models-setup. Contract: "P1 handoff" in `docs/qa/aiteam-oc2-emulator-2026-10-14/root-cause-3.md`.
Implemented and unit/widget/golden tested here; not yet run on a device or emulator.

| Item | Change | Test (`test/team_models_setup_test.dart` unless noted) | Image |
|---|---|---|---|
| 1 Per-role models | Team settings has Planner / Worker / Checker rows (catalog picker, `saveRole` with the complete role; planner and checker stay read-only). Empty reads "Server default" (the catalog exposes no default name, so none is shown). "Choose the Planner model" opens settings and the Planner picker; after saving, "Ask again" is offered for the failed project (never automatic). | pick saves whole role; failed plan opens picker then offers Ask again | before-new-project-no-model-control, after-settings-models, after-settings-ask-again |
| 1 Error words | `modelNotConfigured` / `sessionFailed` say the model did not accept the request and point to the Planner model choice; `repoPathInvalid` has plain words. | plain words test; `team_digest_failure_test.dart` | |
| 2a Folder | Repo folder uses the New chat folder browser (`ProjectFolderActions.pickFolder`, in-app server only); "Type a path" is second. Picking a phone folder also picks This phone and the repo name. | folder chosen / Type a path | after-new-folder |
| 2b Empty repo | "Make the first commit for me" runs an empty commit in the phone's Ubuntu (no engine action exists), then repeats Start planning. Folders on other servers get the exact git command. | first commit test | after-empty-repo |
| 2c Draft + progress | A restored draft is announced with "Start fresh" (restores in place, never silently appended). "Checking the folder and starting the planner..." shows at once after Start planning. | draft + progress tests; goldens `kit_teamprojects_new_*` regenerated | before-new-project-form, after-new-project-form-draft-notice |
| 2d Spec | An empty spec is seeded with one editable milestone from the task text (title and one criterion). | starter milestone test | before-spec-form, after-spec-starter |
| 2e Rate limit | A retry whose time is unknown or past reads "Rate limited. Retrying 1..." with no 0:00 clock (the chat already ticks while the time is in the future). | `chat_server_state_ui_test.dart` headline | |

Motion: new notices use `KitReveal` (KitMotion.standard, instant under reduced motion).
