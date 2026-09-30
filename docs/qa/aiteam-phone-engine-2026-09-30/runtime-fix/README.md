# Native startup review fixes

Finish line: a native launch survives its short-lived MethodChannel thread, dies
when the app closes its stdin pipe, resolves Android's trusted app-data alias,
and authenticates its child-selected loopback port before sending any token.
Non-goal: changing the worker confinement policy or claiming device acceptance.

- **C1:** removed `PR_SET_PDEATHSIG`. The native `Process` retains its stdin
  writer for the full daemon generation; Rust's blocking reader sends SIGTERM
  on EOF or pipe error. Existing daemon SIGTERM handling performs recovery.
  Tests use an actual OS pipe and a child Rust test process: launch-thread exit
  keeps it alive; closing the parent stdin endpoint kills it with SIGTERM.
- **C2 / S3:** native config paths originate at canonical `filesDir`. Rust config
  load resolves that trusted app-data ancestor once, rejects symlinks below it
  (including existing ancestors of a not-yet-created worker path), then uses
  canonical paths for private / worker containment checks. An Android-style
  `/data/user0 -> /data/data` fixture permits the trusted alias and rejects
  private and worker descendant links. The source path check excludes both
  private and worker roots.
- **S1:** config requests kernel port 0. The child reports one bounded JSON line
  on its private stdout pipe, after binding and before serving HTTP. Its HMAC
  binds profile, actual port, and UUID nonce. Native verifies that receipt and
  live child before any authenticated health request or credential handoff;
  a listener on the former fixed 4098 port receives no bearer token.
- **A2:** unconfined app deletion restores directory mode 0700 before listing;
  entries already removed are safe to skip.
- **A6:** native stop removes its private OC1 credential copy. The original
  Ubuntu server credential remains under the existing Ubuntu lifecycle owner.

Readiness JSON: `{schemaVersion:1,profileId,port,nonce,mac}`; at most 1024 UTF-8
bytes plus newline. HMAC-SHA256 uses token UTF-8 bytes as key and the exact
message `oc-phone-engine-ready-v1\n{profile}\n{port}\n{nonce}`. `mac` is lowercase
64-character hex. Token material is never included in readiness output.

Verification is performed by the integration owner under `machine_lock`; this
slice adds focused tests and does not run builds in parallel with that owner.
Device proof remains required on the packaged binary; no policy is relaxed for
an emulator or older kernel.
