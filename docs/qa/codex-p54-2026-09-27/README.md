# P5.4 Quota as answers — backend/state hand-off (2026-09-27)

Finish line: expose Spent's actual measured period and a listenable Remaining
answer sourced from the Codex account, retaining observation age offline,
with a default-on 80%-used alert preference and actionable collector status.
Non-goals: collector packaging, UI implementation, enrollment dialogs, native
notifications/background service activation, signing, release or deployment.

## Scope and feasibility

Base: `dcf05c5e`, existing `codex/p54` worktree. Read AGENTS.md and only
STANDARDS sections 2, 3, 13 and 15. No HANDOFF.md exists in this checkout.

Read set: existing account gateway/session/controller, quota parser/client,
usage query/statistics/overview, profile deletion and KitRedact; current Usage
and account screens were inspected without edits. Write set is exclusively:

- `lib/domain/quota_answers.dart` and `test/quota_answers_test.dart`.
- `lib/state/quota_answer_preferences.dart` and its behavior test.
- `lib/state/quota_answers_controller.dart` and its behavior test.
- This QA folder and, if git cannot commit, root `COMMIT_MSG.txt`.

These are three bounded ownership slices (domain, preferences, controller),
reviewed together. No existing production file, UI, protected single-owner
file, Kotlin, generated localization or package file is changed.

Feasibility passed against the existing callable adapters:

- `lib/codex/account.dart` implements `account/read` with `refreshToken:false`
  and `account/rateLimits/read` through the connected runtime's authenticated
  transport. Its supported runtime check remains authoritative. No new
  authentication adapter, provider endpoint, token read or refresh was added.
- `lib/domain/agent_account.dart` supplies the protocol-neutral session. Codex
  answers use only signed-in `chatgpt` subscription accounts. API-key accounts
  and unsupported runtimes cannot be represented as subscription remaining.
- `lib/quota/provider_quota_client.dart` already supplies the separately
  deployed, same-origin authenticated collector route and maps HTTP 404/405 to
  `QuotaFailureKind.unsupported`. No new collector or permission bypass exists.
- `tool/quota/README.md` describes the existing operator deployment. No live
  account, collector or server was contacted. Feasibility is based on current
  adapters and their contracts, not a claim of live provider validation.

## UI hook-up

### Remaining

Create one `QuotaAnswersController` per open Usage profile/location. It is a
`ChangeNotifier`; listen to it using the UI's existing builder pattern, call
`refresh()` on entry/resume, and dispose when leaving the scope. It does not
fetch in its constructor, poll, enroll, start device login or post notifications.

Prefer `QuotaAnswersController.codex(session: ..., preferences: ...,
isCurrent: ...)` when `connection.capabilities.agentAccount` and the domain
`AgentAccountGateway` are available. Open a **dedicated** session through
`AgentAccountGateway.openAccountSession()`; the controller owns/closes it.
Never reuse the login panel's session. Never fall back to a collector after a
Codex account failure: it might be configured for a different account.

For other servers use `QuotaAnswersController.collector(gatewayFactory: ...,
serverName: ..., preferences: ..., isCurrent: ...)`. The factory returns a
fresh dedicated `ProviderQuotaGateway` for the already trusted selected server,
using the existing `HttpProviderQuotaGateway` from a state/composition layer.
The UI should depend on the domain gateway and new state API, not protocols.
The controller closes each collector handle after the read. Changing provider
also creates a new scope; do not change the factory's target behind a controller.
The existing collector trust/authentication prerequisite still applies.

The owner's `isCurrent` closure must validate profile existence/readability,
profile ID, origin/auth configuration, location and selected provider. Capture
those at construction; check `connection.isProfileReadable(profileId)` as well
as the captured scope. On deletion/location/profile edits, call
`invalidate(forget: true)` and dispose **before awaiting cleanup**. On background
or transport interruption, call `invalidate()` to retain the last observation
as stale. Account events already refetch limits, invalidate old identity, and
mark disconnects stale. After reconnect, `replaceAccountSession(newSession)`
drops the previous identity, then call `refresh()`; never replay deltas.

Read these fields together:

| API | Rendering contract |
| --- | --- |
| `snapshot.source` | Attribute to Codex account or collector, separate from project spend. |
| `snapshot.windows` | Independent reported windows; never sum percentages across windows. Empty means unknown, not 100% left. |
| `remainingPercent`, `isWeekly`, `durationMinutes`, `resetsAt` | Localize a sentence such as **About 40 % left this week · resets Tue** for a weekly window with 60% used. Unknown duration/reset stays unknown. Format resets in the displayed timezone. |
| `snapshot.observedAt`, `age`, `stale` | Always show age for retained/offline values. Reading age or failing refresh never changes observedAt; a passed reset never replenishes quota locally. |
| `status`, `loading` | Keep stale value/age visible alongside transient errors; sign-out/account changes clear previous identity. Use a fixed localized status, never exception text. |
| `alert80Enabled` | Bind **Alert me at 80 %**; default true. Await `setAlert80Enabled(value)` and show a fixed save error on false/`preferences.failed`. Threshold means **used**, not remaining. |
| `attentionRequired` | Foreground attention for a fresh reading at/above 80%; deduped per reported reset within this controller. Stale/error/background values cannot alert. |

For `needsCollector`, localize **Needs the quota collector on {serverName}**.
The name is redacted. Provide a **How to get it** details action using the
operator instructions referenced by `QuotaAnswersController.collectorSetupGuide`
(`tool/quota/README.md`): obtain the repository's existing Node >=20 collector,
ask the server operator to configure its protected credential/token files and
same-origin authenticated HTTPS proxy, then retry. This is an operator setup
request, not an install/download command generated by the app. Bundle or link
that help using the UI's approved help/external-link path. `collectorAuth` means
fix server/proxy authentication, not install again; `unsupported` means the
provider/runtime is unsupported. Claude collection remains disabled.

The P3.11 **monitor enrollment dialog removal is a UI follow-up**: bind the
switch directly to the new preference, without calling `quotaMonitor.enroll`.
This service emits attention; it does not secretly grant Android permissions or
enable a background service. Route presentation/notifications through the
approved UI/router when wired. Dedupe here lasts only for this controller; any
background notification policy and durable dedupe remain the router's concern.

### Spent

Use the existing `UsageOverview.snapshot` and construct:

```dart
final period = SpentPeriod.fromUsage(
  query: snapshot.query,
  statistics: snapshot.statistics,
  requestedRange: snapshot.range,
);
```

`period.from` / `period.to` are the **returned** UTC half-open interval. Convert
in the query's display timezone. For a nonempty date-only interval, format the
last included instant (`to - 1 ms`) as its end date. When
`matchesRequestedRange == false`, label the answer with those actual dates:
a thirty-day request returning September 2–6 must read **Spent … · Sep 2–6**,
not **Spent … in 30 days**. The selector may still say 30 days as the requested
filter, but must not claim that it is the period covered by the returned total.
Do not derive dates from nonempty chart/activity buckets; zero-use days count.
The helper does not silently refetch, requery or modify measured spend.

All sentence, status, age and setup copy must be localized by the later UI unit
(en/ar); these APIs carry facts and enums, not hardcoded English UI sentences.
The UI's default-on switch, sentence rendering, removed dialog and date label
acceptance remain unverified until that unit wires and tests them.

## Persistence, privacy and deletion

Only `{version: 1, alert80Enabled: bool}` is persisted, through KitRedact,
under `oc.quotaAnswers.<profileId>`. No migration is needed: absence defaults
on. The existing `ProfileStore.profileScopedPreferenceKeys` deletion sweep
already covers the key, so connection/main need no changes.

Writes are serialized per preference object/profile and guarded before/after
awaits. A late write after deletion is removed; navigating away preserves a
still-present profile's saved setting. Storage errors are fixed flags only.
Quota observations and account identity remain in memory, so an offline value
survives disconnect within the controller, **not app restart**. After restart
Remaining is unknown until a successful read; the switch's saved choice remains.
No raw transport error, account label/email or provider credential is logged,
stored in quota preferences, or included in notification data.

## Verification

Added behavior tests cover domain percentages, immutable windows, age/reset,
actual-vs-requested Spent bounds; preference default/restart/isolation/deletion,
storage failures and concurrency; and controller source selection, offline age,
threshold/dedupe, sign-out, account changes, late completions, missing collector,
collector expiry and transient failures. Tests use synthetic fixtures only.

The pinned Flutter wrapper cannot start in this sandbox: it tries to write
`bin/cache/engine.stamp.tmp.*` and `engine.realm` on a read-only filesystem.
Each command exited 1 **before executing tests/analyzer**. Saved outputs:

- [Controller tests](controller-test.txt)
- [Domain tests](domain-test.txt)
- [Preference tests](preferences-test.txt)
- [Whole lib/test analyzer attempt](analyze.txt)
- [Requested Dart wrapper attempt](format-wrapper.txt)

Formatting uses the Dart executable inside the exact same pinned SDK:
`bin/cache/dart-sdk/bin/dart --suppress-analytics format --language-version=3.10`
on all six changed Dart files. It succeeds; package-resolution warnings reflect
this checkout's missing resolved `flutter_lints` configuration. This is formatting
evidence, not a successful analyzer run. See [format check](format.txt).

Verifier, after restoring a writable pinned Flutter cache and resolving packages:

```sh
FLUTTER=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
"$FLUTTER" pub get
"$FLUTTER" test --concurrency=1 test/quota_answers_test.dart
"$FLUTTER" test --concurrency=1 test/quota_answer_preferences_test.dart
"$FLUTTER" test --concurrency=1 test/quota_answers_controller_test.dart
"$FLUTTER" analyze lib test
```

No full suite, screenshots, emulator, native build, live query or release was
attempted. Existing UI source remains unchanged. Source review found and fixed
same-account collector-outage retention, prompt listener invalidation on account
change, and speculative preference-cache handling; execution is still pending.

## Delivery state

- Implemented: backend/domain/state API and behavior tests; UI integration pending.
- Enabled: only when a caller constructs the service; existing screens unchanged.
- Verified: formatting and source/diff review; tests/analyzer blocked by sandbox.
- Committed: see commit attempt record/fallback below.
- Deployed/released: no.

Git staging was blocked by the worktree Git metadata being read-only. No commit
was created. All changes remain in the working tree; the exact requested subject
and attribution trailers are in [COMMIT_MSG.txt](../../../COMMIT_MSG.txt).
See [commit attempt](commit-attempt.txt). No push was attempted.
