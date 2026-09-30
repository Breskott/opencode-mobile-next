# Dart phone-engine review closure

Finish line: deletion fences an engine's first activation before credentials exist, chat admission failures reach the queued-prompt path as plain API errors, and the monitor reads authenticated phone-project attention without changing engine state.

Non-goal: editing UI screens, running device proof, changing native authority, or claiming a complete integration suite.

## Changes

- D3: connection deletion now includes managed builtin URLs and controller lifecycle ownership, including a pending first attach on a saved alias. Deletion still closes controller admission before draining the admitted native operation. Optional native bridge / gateway constructor seams follow the connection's existing injected transport pattern; production defaults are unchanged.
- D4: the complete phone before-dispatch callback maps `PhoneEngineException` to plain `ApiException` wording. This includes an old transport and failure to stop a different saved phone alias. No request is dispatched after a failed fence. The queue's existing API-error handler persists `message` rather than raw exception text.
- D5: the monitor creates one phone gateway with the selected profile ID, orchestration URL, and Keystore token, probes its identity, then reads its project snapshot only when `projects` is supported. It projects unanswered requests and failed/interrupted/needs-you tasks; running tasks and answered requests do not ask for attention. The inventory remains capped at 256 records; truncation, wrong identity, missing credentials, and failed reads remain unknown coverage. The client closes on every exit. Reading never sends heartbeats or commands.

## Existing major / minor regressions retained

- D1: `test/team_project_controller_test.dart` — accepted command stays accepted when its refresh fails; refusal codes survive failed refresh.
- D2: `test/phone_project_engine_controller_test.dart` — ordinary phone profile edits retain the secure engine token, a fresh store reload retains it, and explicit deletion clears it without serializing the secret.
- D6: older stream or explicit-read revisions cannot replace a newer controller snapshot.
- D7: closed probes and caller-owned clients leave controller ownership and close once.
- D8: the review's suggested rollback of `_deleted` is intentionally rejected. A failed deletion leaves a durable tombstone because native data may be partially erased. It reports `deleteFailed`, prevents restart/attach across controller reconstruction, and permits an explicit deletion retry. Removing the fence would revive uncertain authority.

## Focused verification

No Flutter/native tests or analyzer were launched by this worker; the root agent owns the serialized gate.

Required focused files:

```text
test/phone_engine_connection_review_test.dart
test/monitor_attention_reader_test.dart
test/team_project_controller_test.dart
test/phone_project_engine_controller_test.dart
```

Pinned Dart formatting and `git diff --check` passed locally. Formatting in this thin worktree warned that its local package map was absent; this is not an analyzer result. Full analyzer and focused test results belong to the integration evidence recorded by the root agent.
