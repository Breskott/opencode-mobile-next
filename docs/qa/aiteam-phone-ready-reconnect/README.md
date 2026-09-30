# Execution-ready attach restores the phone chat transport

Finish line: completing protected phone setup with execution-ready health automatically retries the selected failed foreground phone connection, including a retained API whose old SSE connection was refused, without a manual Try Again action or fabricated idle evidence.

Non-goal: changing setup UI, native/server lifetime, generic server healing, domain health readiness, chat observation rules, or automatic planner resend.

## Additive controller contract

`PhoneProjectEngineController` adds optional `void Function(String profileId)? onReady`. `_attach` invokes it only after the native credentials have been saved, prior heartbeat ownership has drained, closed/deletion ownership has been rechecked, the new heartbeat producer has started and existing `onAttached` has run. Health must report `canExecute == true`. `start` shares `_attach`; ordinary `probe` and orchestration health polling do not emit readiness callbacks. Store-only startup cannot reconnect while setup deliberately keeps OpenCode stopped.

`ConnectionController` binds that signal to existing `retryConnection()`. It requires the same selected managed OC1 phone engine profile, an undisposed non-isolated foreground connection, and a connection that is not already connected. Suspended, remote, switched, deleting and retired owners are excluded by lifecycle/profile eligibility. Existing manual/lifecycle reconnect deduplication and generation fencing remain authoritative. The unawaited retry observes errors; readiness itself never assigns connected/idle truth.

Retry replaces and closes the failed retained API through the normal connection recovery path, clears the obsolete connection-refused error, and waits for server health/SSE/status evidence. Chat heartbeats remain UNKNOWN while that evidence is missing. This recovers the setup-specific gap where generic `connectIfNeeded` skips a failed connection because `api` is already nonnull.

## Regressions and gate

Six tests in `test/phone_engine_ready_reconnect_test.dart` use the actual controllers with an old retained failed API, an immediate engine transport and a held new OpenCode health response. They verify API replacement, saved native credentials, pending reconnect and UNKNOWN-only heartbeats, repeated-attach deduplication, store-only/probe-only behavior, already-connected/isolated/suspended/remote guards, a profile switch during attach, and disposal while attach is pending.

Pinned Dart formatting and `git diff --check` passed. No Flutter tests, analyzer, native build or device process was launched by this worker. Coordinator owns the serialized focused gate: new test plus existing phone engine controller/connection/chat regression files. Actual phone setup must then prove recovery without a manual reconnect.

Implemented and locally committed with `[skip ci]`; integration/testing/device deployment remain separate gates. No UI edits or push.
