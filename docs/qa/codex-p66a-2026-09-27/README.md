# P6.6 backend/state defaults — 2026-09-27

Finish line: expose deterministic project, model, voice, delivery and review defaults, with named selections and profile-scoped once-only announcements for the later UI unit.

Non-goals: UI/kit edits, new settings, connection or native bridge changes, project creation, downloads, playback, prompt dispatch, signing or publication.

## Scope and feasibility

Base: `024e97b0`, existing worktree branch `codex/p66a`. No HANDOFF.md exists here. Read AGENTS.md and STANDARDS.md sections 2, 3, 13 and 15. This is the requested backend half; it does not make the end-to-end product acceptance live.

Write set: `lib/state/interaction_defaults.dart`, `test/interaction_defaults_test.dart`, this QA directory, and root `COMMIT_MSG.txt` only if committing is blocked. All existing files, including UI, remain unchanged.

Read/dependencies: domain `WorkspaceProject`, `CatalogModel`, `PromptDelivery`; `ProfileStore` preference deletion; voice manifest, device info, model manager and read-aloud controller; read-only `KitRedact`. No new adapter or authentication flow is needed. Existing authenticated catalog loading is the prerequisite for model selection. The current connection resolves configured chat defaults ahead of provider defaults; the caller supplies that resolved server preference, not an arbitrary catalog item.

Feasibility passed at the source-contract level: project/catalog/default-model data, physical RAM, voice inventory and review-change data are already represented. No live server or native capability was verified. Unknown/missing data stays unresolved. No credentials are accepted by this API.

## UI hook-up

Import `package:opencode_mobile/state/interaction_defaults.dart`. Use `InteractionDefaults` for synchronous decisions and one `InteractionDefaultsStore(preferences, profileID: activeProfileID)` per active profile for persistence. Recompute when inputs change; the service does not fetch data, notify widgets or mutate existing settings.

`DefaultChoice<T>` exposes `value`, redacted `label`, `reason`, `optionCount`, `skipPicker`, `canChange` and `isAutomatic`.

- Skip the entry-flow picker when `skipPicker` is true. A null value with zero options means unavailable, not a selected value. A singleton review scope can still be unresolved until its change data arrives.
- In the existing Settings row show the resolved label and a localized explanation keyed by `reason`. For delivery/review, localize the enum value rather than displaying its raw English identifier. Show Change when alternatives exist (`canChange`); open the existing selector explicitly even though the entry flow skipped it. Persist changes through the current setting owner and supply them as explicit inputs next time. This adds no new settings.
- `value` retains the original typed object/ID for actions. Only `label` is safe presentation data; do not log or persist raw catalog/project/voice objects.

| API | Inputs and application |
| --- | --- |
| `picker<T>(options, label:, explicitChoice:)` | Reuse for other pickers. A single option is selected automatically; a valid explicit choice wins. Generic options use their existing equality. Empty lists never open a picker. |
| `project(projects, lastUsedID:, explicitID:)` | Supply a successfully loaded project list. Use `store.lastProjectID`; call `rememberProject(id)` only after successfully opening/creating a project, including explicit changes. Explicit current project wins, then the only project, then a still-available last-used ID. With multiple projects and no valid history, leave the picker available. With no projects, return a `DefaultProject(name: 'my-app', project: null)` creation proposal. `needsCreation` must be handled through the existing creation flow; do not navigate to a fabricated directory. Loading/error is not an empty catalog. The creation name remains editable. |
| `model(models, signedIn:, serverProviderID:, serverModelID:, explicitChoice:)` | Call after successful authentication and catalog loading; filter the catalog by current provider availability/capabilities. Supply the configured chat default IDs, or provider defaults when no configured model exists. Match provider+model IDs and show `CatalogModel.name`, avoiding ambiguous display-name matching. Preserve the existing explicit model setting; do not treat an arbitrary connection fallback as the server's default. Disabled/stale choices are ignored. Missing server defaults with multiple options remain unresolved. |
| `voicePack(totalMemoryMb:, supportedPacks:, explicitID:)` | Await the existing voice manager/device probe. Pass physical `VoiceDeviceInfo.totalMemoryMb`, never `memoryClassMb`. Filter manifest packs with `manager.supportFor(pack).supported`. Highest eligible minimum RAM wins: tiny at 1024 MB, base at 1536 MB, small at 3400 MB. Unknown RAM picks the smallest supported pack; below every threshold stays unavailable. Preserve an explicitly saved pack, not the manager's initial in-memory fallback. Apply via the existing `selectPack`; selecting does not authorize downloading. |
| `voice(voices, locale:, explicitID:)` | Use the current offline inventory from `ReadAloudController.voices()`, app/device locale and existing explicit voice. Prefer exact locale, then matching language, with case/underscore normalization. Equal matches use inventory order. If multiple voices have no locale match, leave unresolved. A singleton follows the universal single-option rule. Playback consent remains required by the read-aloud controller. |
| `delivery(explicitChoice:)` | Returns domain `PromptDelivery.queue`; respect a current explicit Steer choice. UI/connection owner maps the result through its existing send path. |
| `review(changeCounts, explicitChoice:)` | Map supported session/workingTree/branch scopes to current counts. Null means loading/unknown, zero means confirmed no changes. Select a positive count; ties prefer session, workingTree, branch. Preserve an explicit supported scope, even if empty. No positive count leaves the default unresolved; render existing loading/empty state. Map `DefaultReviewScope` to the review screen's existing scope enum in its UI unit. |

At the visible point where an automatic default is actually used, await `store.takeAnnouncement(DefaultKind.model, choice)` (or the appropriate kind). A non-null result is the safe label for the kit's localized inline notice. A null result means already announced, explicit choice or unresolved. Do not invoke from build methods, background probes or before the selection has been applied. Claims are serialized on the shared store instance and persisted before returning, once per kind/profile, not once per changed value. This is at-most-once delivery: process death between claim and rendering can lose a notice; exact UI delivery is not claimed.

Before profile deletion/switch, stop initiating writes, await `store.drain()`, then discard it. The existing `ProfileStore.removeScopedPreferences` sweep already removes `oc.defaultProject.<profileID>` and `oc.defaultNotices.<profileID>`; no shared blob or connection edit is needed. The later owner must wire lifecycle draining along with the UI hooks.

## Persistence and security

Only a project ID and enum notice IDs are stored. Values pass through KitRedact; sensitive project/profile identifiers are rejected without including them in errors, since substituting redacted IDs could select the wrong resource. Labels are redacted and never persisted. No provider configuration or credential payload is stored. Existing settings storage is reused by its current owners, not duplicated here. New keys are optional; no migration is required. Removing a profile resets its history and announcement eligibility. Failed preference writes throw, reload the optimistic SharedPreferences cache and allow retry.

## Focused verification

Eight `flutter_test` behaviour tests cover: zero/single/multiple pickers and project creation/history; authentication/model IDs/names/overrides; RAM thresholds and unsupported packs; locale matching; Queue and review truth; restart/isolation/concurrent announcement claims/profile deletion; failed-write retry; and redaction/invalid-write recovery. Tests use fake values only. ProfileStore is constructed only for its preference sweep; no load/upsert or secure-storage call occurs.

Commands attempted:

```sh
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/dart format --language-version=3.10 lib/state/interaction_defaults.dart test/interaction_defaults_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/interaction_defaults_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter analyze lib test
```

The Flutter/Dart wrapper cannot write SDK `engine.stamp.tmp` / `engine.realm` under this sandbox. Test and analyzer exit before running; **no test or analyzer pass is claimed**. See [test-output.txt](test-output.txt) and [analyze-output.txt](analyze-output.txt). A verifier must run the focused test and analyzer in a writable SDK environment.

Formatting succeeded with the very same pinned SDK's underlying Dart executable and `--suppress-analytics` (avoids writing home telemetry); [format-output.txt](format-output.txt) records the final idempotence check. Package-resolution warnings are due to absent worktree package configuration. No SDK or home files were modified. `git diff --no-index --check /dev/null <new file>` checks were used for new files as well as `git diff --check`.

## State

Implemented: backend API and focused tests. Enabled in app: no, pending the UI hook-up above. Verified: formatting/diff only; runtime tests and analyzer blocked by environment. UI/Settings acceptance, screen readers, screenshots and native behaviour: not verified and outside this write set. Deployed/released: no.

Committed: no. Git could not create the parent repository worktree `index.lock` on the read-only filesystem; see [commit-output.txt](commit-output.txt). The exact intended message is at root [COMMIT_MSG.txt](../../../COMMIT_MSG.txt), and all changes remain in the working tree. No push requested or attempted.
