# Checker finding publication

Finish line: a checker response with any finding publishes an open finding on
both the durable job and the project task, with a visible review reason; an
empty passing check remains merge-ready.

Non-goal: changing checker verdict validation, dev merge or promotion rules,
creating finding waivers, retrying a task, or changing admission/scheduling.

`Store.update_job` normalizes every published finding's `status` to `open`.
It preserves all other authored finding fields and the unchanged criteria and
criterion results. Both top-level `findings` and nested `task.findings` take
this path, and both publish the same normalized findings to the durable job and
task. A checker cannot publish its own closed, fixed, ignored or met resolution.

A `needsFix` update lacking a nonempty explicit reason publishes the typed
`checkerFindings` reason on job and task. An explicit nonempty top-level reason
is preserved, as is a nested task reason when no top-level reason is supplied.
The durable timeline uses the canned wording “Work has checker findings that
need review.” Merge validation continues to block every nonempty finding list.

Regression coverage in `store::checker_publication_tests`:

- Incoming `met`, `fixed`, `ignored`, `closed`, and `open` findings persist as
  `open` on job/task after reopening storage, through both publication shapes.
  Their text, criterion, location, severity and extra evidence are retained;
  `criterionResults` can remain authored `met` while the task stays `needsFix`.
- An empty successful check remains `mergeReady` / task `checked` and still
  passes the existing checker validator.
- Missing or empty reasons receive the typed default; explicit reasons remain.

This worker ran `cargo fmt` and `git diff --check`. No tests or builds were
started. The coordinator must run the focused gate under the machine lock:

```sh
cargo test --lib store::checker_publication_tests
cargo test --test store_durability
cargo test --test store_merge_projection
```
