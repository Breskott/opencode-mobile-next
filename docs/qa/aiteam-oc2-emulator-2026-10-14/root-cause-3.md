# OC2 planner failure on APK 2317

Base: `9b3065369`; branch: `codex/aiteam-oc2-planner`.
Input: [run3-2317.md](run3-2317.md) and its `r3-*` screenshots. The protected
start fix held: APK 2317 enabled AI Team against OpenCode 2.0.29. This follow-up
diagnosed the first planner failure using only `adb -s emulator-5554`.

Finish line: identify the model and terminal error of the failing planner,
preserve safe lane admission, and give a provider-auth refusal a useful typed
recovery code. Non-goals: UI changes, automatic model fallback, approving the
generated plan, executing worker tasks, or changing the OC1 path.

## Confirmed cause: the planner inherited a different model from chat

The two failed planner sessions used `opencode/cat-jam-free`, not
`zai-coding-plan/glm-5.3-flash`. The engine's planner role had an empty model
choice. For an empty role choice the OC2 driver resolves the server's
`GET /api/model/default`, scoped with
`location[directory]=/root/projects/my-app`. That endpoint still returned
Cat Jam Free with `enabled: true` during this diagnosis.

The app's selected chat model was GLM-5.3-Flash. A working chat with that model
did not establish that the server default used by new engine sessions had
changed. The prior run record's statement that the OC2 default was changed is
therefore corrected by this wire observation: the app selection and the
server default were different.

Both failed planners had accepted prompts followed by assistant messages with
`finish: error`, structured `error.type: provider.auth`, and status `403`.
The provider's explanation restricted this free tier to OpenCode. This was
not a `429` rate-limit response. A subsequent failed idle message and the
session's failed outcome confirmed that each turn had ended. The previous
driver collapsed that provider refusal into the generic `sessionFailed`,
which hid the actionable model/access problem behind “The planner stopped
before it answered.”

## Wire evidence and successful bounded retry

The installed app was APK 2317. Its engine daemon was PID `31758`; the OC2
server was PID `31882`, listening on port `4097`. Diagnosis used authenticated
engine and OC2 HTTP APIs plus logcat/process inspection. Credentials remained
inside scripts and were neither printed nor committed. No `run-as`, physical
phone access, installation, force-stop, or app-data reset was used.
The allowlisted before/after observations are recorded in
[planner-model-proof.json](planner-model-proof.json). Private API responses
and logcat remain under ignored `build/qa/aiteam-oc2-planner`; credentials were
not stored in those artifacts. Both temporary ADB forwards (`43597`, `44097`)
were removed and the emulator lock released after diagnosis.

| Check | Observed result |
|---|---|
| Two failed planner session models | `opencode/cat-jam-free` |
| Agent | `build` |
| Role instruction | `aiteam-role` entry present and confirmed; 79 characters |
| Planner permissions | Exact deny-all plus allow `read`, `glob`, `grep` |
| Prompt/turn | Prompt persisted; assistant error; terminal failed idle |
| Provider failure | `provider.auth`, HTTP status `403` |
| Server default at source repository | `opencode/cat-jam-free`, enabled |

Only the planner role was changed through the authenticated engine's
`saveRole` command to `zai-coding-plan/glm-5.3-flash`. An explicit `retryPlan`
then created job `job-07b95423-f1d2-4104-9e75-fffecb7a7d6c` and session
`ses_ec37244e9ffeuYqPoyNSgTr45y`.

That new session used the requested Z.ai model and `build` agent, with the
same read-only permissions. Its assistant finished with `stop`; the session
settled idle with outcome `succeeded`. It was absent from the active-session
set, with zero pending permissions and zero forms. The engine completed the
planner job and produced one phase with one task. `planApproved` remained
`false`.

This success used the **installed APK 2317 driver**, with a corrected explicit
role choice. It proves that its existing OC2 model, instruction, permission,
prompt and observation path can complete planning with this working provider.
It is not device qualification of the source changes in this branch.

The emulator was left with the plan awaiting the person's review. No plan
approval or worker dispatch was performed. Worker and checker model choices
remain empty, so they still inherit the unsuitable server default; configure
those choices or the actual server default before approving execution.

## What the driver sends, and what did not need changing

The OC2 driver creates the lane session with deny-all permissions, then
patches and verifies the role policy. It selects agent `build`, selects the
model with the existing session-state operation, writes and reads back the
instruction entry, and confirms agent/model/permissions before prompting:

```text
POST /api/session/{id}/agent
  {"agent":"build"}
POST /api/session/{id}/model
  {"model":{"providerID":"zai-coding-plan","id":"glm-5.3-flash"}}
PUT /api/experimental/session/{id}/instructions/entries/aiteam-role
  {"value":"AI Team role: planner.\n<role instructions>"}
POST /api/session/{id}/prompt
  {"text":"<planning request>"}
```

All session operations use the lane's `location[directory]`. Model and agent
are session state, not fields in the prompt body. The instruction entry keeps
the existing 8 KB bound. The planner's policy grants only `read`, `glob`, and
`grep` after deny-all. It grants neither `shell` nor `bash`; planning is
read-only. The successful retry did not require granting either tool,
altering the model-switch body, weakening the sandbox, or changing auth.

## Fix: classify settled provider-auth refusals without retrying uncertainty

The OC2 observer now recognizes the exact structured `provider.auth` type and
exports only the allowlisted recovery reason `modelNotConfigured`. It requires
terminal failed-session evidence, a later failed idle record matching the
session's idle timestamp, and no active run. A queued prompt or a different
latest user message prevents this recovery classification. Pending permission
or form work retains its blocked state.

The daemon preserves this fixed recovery code in the failed job. Unknown
provider types and other failures retain `sessionFailed`; raw provider
messages, response bodies, headers and arbitrary error strings are not copied
into durable job reasons or UI Details. The OC1 driver does not supply this
new hint and keeps its existing behavior.

An explicit `retryPlan` may create a fresh proposal after this settled model
failure only when the prior planner session exists and prompt dispatch is
confirmed. Uncertain or partial dispatch still requires reconciliation.
There is no automatic retry, automatic provider/model fallback, or replay of
the old prompt. Changing the model also never changes an already dispatched
job's durable model binding.

## Why the planner is absent from the ordinary chat list

The engine creates lane sessions under
`/root/aiteam/work/<profile>/<repository>/<job-or-task>`. The app deliberately
excludes directories under `/root/aiteam` from ordinary conversations:
`lib/state/connection/chat_feed.dart` calls `isAiTeamDirectory`, defined in
`lib/domain/team_directories.dart`. Team conversations belong to the AI Team
surface. Their absence from the chat list is not evidence that creation or
prompt acceptance failed.

There is a separate diagnostic gap: the workspace's planner `planningState`
currently exposes job ID, stage, reason and update time, but not the lane
session ID. The underlying engine job retains `sessionIds.planner`; exposing
an appropriate team-only conversation/details link is future UI work.

## P1 handoff: where Team model selection belongs

The current “Pick a model” action in
`lib/ui/screens/team/projects/screen/overview_helpers.dart` calls
`openTeamDefaults`. Its native-engine settings editor in
`lib/ui/screens/team/projects/team_project_editors.dart` contains execution,
review, budget and limits, but no model control. The text “Team settings ›
Model” therefore describes a control that is missing from this surface.

The **current engine-backed Team settings/defaults screen** should own this
setting, with the failed-planner action opening or focusing the Planner model.
The existing Team home Roles editor already has catalog-backed per-role model
fields and can supply the implementation pattern. Reuse `showTeamModelSheet`
and the connection's enabled model catalog; keep UI access through the domain
gateway and capability gates.

The engine contract for that UI builder is:

- Authority is `TeamWorkspace.roles[].model`, scoped to this phone profile.
  Planner role ID is `planner`; worker and checker choices are separate.
- Save through `TeamProjectController.execute` with `TeamProjectAction.saveRole`
  and the complete edited role. Preserve its ID, name, instructions,
  `readOnly`, and fallback field. Planner and checker must remain read-only.
- An explicit selection is `provider/model`, for example
  `zai-coding-plan/glm-5.3-flash`. Empty string means **the server default**,
  not the currently selected chat model. Show this distinction accurately.
- There is no team-wide default-model field in the engine's default settings.
  Expose the existing per-role choices clearly; a single shared team default
  would require a separately defined engine contract.
- Do not reuse legacy `TeamModelStore`/`BuiltinTeam.applyModel` as persistence
  for this engine. That older Team settings implementation does not feed the
  native engine's workspace roles.
- Each new job snapshots its role model, then durably resolves it before
  dispatch. A saved choice affects new jobs. After saving the planner choice,
  offer the existing explicit “Ask again” action, which creates a fresh
  proposal from current roles; do not resubmit silently.
- `fallbackModel` is stored but has no execution consumer in this engine.
  Do not promise automatic failover.

No Dart or UI code changes are part of this fix. The first-run repository
picker, empty spec, and other run-3 UX findings remain outside this slice.

## Verification and delivery state

- Focused OC2 driver tests: **11 passed**.
- Full Rust suite: **247 passed, 0 failed, 1 existing ignored** in one successful
  invocation, including all default integration targets and doc tests:
  `cargo test --manifest-path engine/phone/Cargo.toml --locked -j 2 -- --test-threads=1`,
  under `tool/qa/machine_lock.sh test`. `OC_ENGINE_TEST_ROOT` and
  `OC_PHONE_PROOF_ROOT` pointed to isolated directories under ignored
  `build/qa/aiteam-oc2-planner`. The ignored raw-syscall boundary proof requires
  Landlock ABI 6; no new skip was added.
- Regression coverage includes the explicit Z.ai model-switch body independent
  of the server default, settled versus still-running/queued/stale auth errors,
  allowlisted/redacted failure projection, explicit fresh retry with the saved
  role model, and refusal to retry uncertain dispatch.
- Both ABI bundles were rebuilt and staged using
  `CARGO_BUILD_JOBS=2 tool/qa/machine_lock.sh build -- engine/phone/tool/build-android.sh --stage-android`.
  All six ELF hashes and the current source digest match the staged manifest.
  Source SHA-256: `40e0264368f2974066f62504d6a89cb3ab413989cc1cab5e1403c40ac6ffb765`.
- Rust formatting and `git diff --check` passed. No Dart files changed, and
  Flutter/analyzer/instrumentation were not run.

The device evidence above covers installed APK 2317 with an explicit planner
model override, not the new error mapping. The new native build still needs
an emulator rerun to verify that mapping and its recovery action end to end.

Rust source changes require restaging the Android engine binaries and a new
native Shorebird release/APK, not a Dart patch. No push, signing or release is
authorized by this work. No Dart tests are required by changed Dart files,
because this branch makes no Dart changes; UI-builder changes need their own
focused widget/controller tests and device qualification.
