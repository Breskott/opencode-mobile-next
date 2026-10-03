# Admission recovery slice

Finish line: worker-session birth events never consume the person-directory ledger, and malformed or lost observation pauses recover only after a fresh complete snapshot with no intervening observation or reconnect.

Non-goal: global discovery of every directory used by clients on other devices, or admitting more than 256 concurrently busy person directories.

Owned files: `engine/phone/src/chat.rs` and `engine/phone/src/admission.rs`; no UI, protocol, daemon, or native edits.

Focused checks: root coordinator runs `cargo test --locked chat::tests -- --test-threads=1` and the admission tests through the machine lock. This worker does not launch tests or native builds.

Implementation:

- Filter the exact guest worker namespace and descendants before teaching directories from either SSE or heartbeats, independently of the team-session ID ledger. Similar prefix paths remain person scopes. Reload atomically removes historical worker scopes from the private JSON ledger.
- Maintain 256 person-directory LRU entries. Never evict a scope with observed busy sessions, a directory in the current heartbeat, or any directory while a complete snapshot reports unidentified busy work. An incoming heartbeat can replace obsolete idle scopes transactionally.
- Preserve busy evidence when bounded capacity cannot admit its directory; include that scope in reconciliation instead of treating a partial poll as complete. More than 256 simultaneously busy person directories pauses until authoritative idle evidence frees capacity. The persisted LRU remains bounded.
- A malformed/disconnected stream increments an observation revision and marks admission unknown. Reconnect never grants idle. Reconciliation runs for unknown as well as busy states and accepts only a successful complete directory-status poll while the global observer remains connected and the revision is unchanged. A complete busy snapshot stays busy; failed polls stay unknown. Adding a heartbeat directory also fences an in-flight poll.

Verification authored (not executed by this worker): five new chat tests cover 600 worker birth races, safe LRU eviction, busy overflow, malformed/disconnected observation recovery, heartbeat directory changes during a poll, plus one private-store restart cleanup test. Existing race coverage was adapted to the explicit snapshot reconciliation API. `rustfmt` and `git diff --check` passed. Root coordinator owns machine-locked execution.
