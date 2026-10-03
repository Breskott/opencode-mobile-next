# Run 3: typed command refusal preservation

Finish line: a refused create/planning command retains the daemon's safe typed cause through the Dart gateway and controller, while an accepted command remains accepted after a failed refresh and sends no second POST.

Non-goal: fixing Git imports or repository setup, editing UI copy, adding retries, or claiming a live device journey. Root owns the daemon/repository fix and serialized verification gate.

## Contract

Authenticated non-redirect error responses with `{"code":"<symbolicCode>"}` retain that exact code. Both camelCase and snake_case codes are supported, including `repository_git`, `unsafe_repository_metadata`, and `repoPathInvalid`. Codes must match `[A-Za-z][A-Za-z0-9_]{0,63}` and must not contain registered secrets. No raw response message, nested cause, repository path, or credential is retained. Missing/malformed codes use the existing safe transport/authentication fallback. Redirects remain `redirectRefused` and are never followed.

The command gateway returns `TeamCommandResult(accepted: false, code: ...)` for typed health, lifecycle, HTTP, parsing, and transport failures. A complete refused command receipt preserves its project ID, revision, and replay flag even when sent with a non-success HTTP status. A partial HTTP refusal with a valid code preserves the cause without inventing receipt metadata. Existing successful command receipt validation remains strict. An empty result code is accepted only with `accepted: true`.

The controller also preserves safe `PhoneEngineException.code` values from other gateway implementations; untyped, malformed, and known-secret failures remain `saveFailed`. An accepted POST followed by failed workspace refresh still returns its original accepted result and records `unavailable` separately. No refusal or refresh failure triggers an automatic resend or a new request ID.

## Focused regression files

- `test/phone_project_engine_gateway_test.dart`: HTTP 400/401/403/409/422/500/503 typed refusals; camelCase and snake_case repository codes; complete and partial refused receipts; health refusal before POST; malformed and known-secret codes; redirects; accepted create plus failed refresh with exactly one POST and unchanged request ID. Existing ambiguous transport/redaction tests remain.
- `test/team_project_controller_test.dart`: typed thrown failures remain typed; untyped/malformed/known-secret failures stay generic. Existing accepted-plus-failed-refresh and refused-plus-failed-refresh regressions remain.

The worker ran pinned Dart formatting and `git diff --check`; both completed. The thin worktree has no package map, so formatting warned about an unresolved `flutter_lints` include. No Flutter tests or analyzer were launched here. Root must append focused gate results before reporting this slice as verified.
