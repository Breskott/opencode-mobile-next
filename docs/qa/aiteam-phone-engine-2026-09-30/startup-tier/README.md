# Native startup and tier contract

Finish line: real OC1 authentication is a startup prerequisite, private startup failures retain only bounded static codes, and native status distinguishes the authenticated daemon's live boundary tier.

Non-goal: changing proof eligibility, inventing credentials, implementing a new daemon gateway, signing, installation, or claiming device proof from host checks.

## Behavior

- Missing OC1 `server.password` now refuses native start with `server_auth_unavailable` before calling the proof/signer or launching the daemon. Stale copied credentials are unlinked. The daemon requires genuine server credentials in its current architecture; the old store-only comment contradicted that contract. Rust configuration validation reports the same typed missing-credential code.
- Before creating Tokio threads, the actual binary enforces `PR_SET_DUMPABLE=0`, closes every inherited descriptor above stderr, and replaces the inherited environment with only `PATH=/system/bin`. The native launcher already clears its environment and keeps credentials out of arguments.
- Rust startup failures write only a bounded private-stdout frame `{schemaVersion:1,startupError:<static code>}`. Native accepts only exact known two-field failure frames; raw/unknown errors and extra fields fail as `engine_ready_invalid`. Failure frames grant no authority, open no HTTP connection, and contain no credentials, paths, stderr, or environment values.
- Authenticated health must report matching top-level and capability `boundaryTier` values (`landlock` or `proot`) with `boundary=true`. Native status reports that tier only for a running verified generation; otherwise it reports `none`. No tier is inferred from mutable configuration or the proof's requested tier.
- `processId()` exposes only the running exact tracked daemon PID for root's post-start controls and proot view masks.

## Actual binary proof subject

Root's device controls can launch the exact packaged ELF:

```text
libaiteam_engine.so --proot-proof-subject <canonical-fixture-directory>
```

The directory must be an app-owned canonical absolute `.phone-engine-view-<UUID>` directory, mode 0700. Its `sentinel` must be an owned regular mode-0600 file, one link, 1–4096 bytes. The subject changes cwd using its verified directory descriptor, opens and retains the real sentinel descriptor, and emits only `READY_SUBJECT:<pid>:<sentinel_fd>` over the private pipe. It holds the descriptor/cwd until stdin EOF. No project/store/config/receipt/provider authority is accessed or simulated. Malformed names, aliases, links, ownership and mode violations refuse with `prootProofSubjectUnavailable`.

This subject is a real positive control for live process/fd/cwd inspection, not proof by itself. Root must run the corresponding negative proot controls and repeat them against the real daemon before exposing credentials.

## Focused regressions

`engine/phone/tests/startup_reporting.rs` contains four real-executable tests:

1. Missing OC1 credentials reports the typed error before readiness.
2. Malformed credential-looking configuration emits only a bounded static frame.
3. Actual subject opens a live private FD, closes deliberately inherited non-CLOEXEC descriptors, and exits on EOF without changing the sentinel.
4. Subject refuses symlink sentinels and invalid fixture names while preserving an outside control.

`PhoneEngineNativeRegressions` adds known failure-frame propagation, unknown/extra-field rejection, missing/empty/oversized password refusal, valid existing password acceptance, and strict health-tier consistency controls. Its existing actual-daemon HMAC, squatter, launcher lifetime and stdin EOF controls remain.

Rust formatting and `git diff --check` passed. Root owns serialized cargo/Kotlin/device runs; none were run in this worker. Rust syscall ancestor fix `9281857b` is separate and must be integrated by root before Android startup is claimed.
