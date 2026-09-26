# revamp-kit-KitScanner: Build KitScanner (2026-09-26)

## 1. Scope

- Unit: `kit-KitScanner` (wave 1, tier 1b, `kit-part`). Finish line: `KitScanner` exists in `lib/ui/kit/kit_scanner.dart`, exported with one `kit.dart` row, with its full §4 API, every declared state (starting, slow, scanning, rejected, paused), its galleries and its contract/behaviour tests. Non-goal: no new scanner behaviour (torch, zoom, gallery import, other barcode formats), no permission/recovery/parsing logic, no edits to `pairing_scanner_screen.dart`.
- Files changed: none in the write set. Only this QA record and (after review) the build-record fields below.
- Pages (map ids): none listed for this unit (`pages: []` in `work-units.json`).
- Specs followed: `docs/ux-system/kit-api/KitScanner.md` (frozen, R16); `docs/ux-system/kit-v2.md` §5, §9.2; rules KIT-1, KIT-3, KIT-9, KIT-12, STATE-5, STATE-9, LOOK-4, LOOK-5, LOOK-6, LAY-3, LAY-9, A11Y-1, A11Y-3, SEC-2, SEC-5, MOT-11.
- **Contract problems (PROC-20): none.** The frozen spec itself is internally correct; the problem is procedural, not textual — see "Blockers" below. `work-units.json`'s `kit-KitScanner` entry has `"after": []`, which does not reflect the dependency the frozen spec states in its own prose ("Depends on: kit-KitSince … It moves this unit from tier 1a to 1b"). That is a scheduling-graph gap worth the coordinator's attention, but it does not make the frozen spec wrong, so it is filed as a blocker (PROC-32), not a contract problem (PROC-20).
- New kit parts (KIT-3): none. `KitScanner` is this unit's own planned part (R13 exempts it); no other new part was created.
- Map items (EVID-11): n/a — no `pages` entries on this unit.
- States per page (STATE-20): n/a — this is a kit-part unit with no owned pages.
- Deferred states (STATE-21): n/a.

## 2. Builds

- Branch `revamp/kit-KitScanner`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4` (`feat/phone-setup-v2` tip at start), code head: this record's commit (no separate code commit — see Blockers).
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work (R19, R20).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter pub get` | resolves | "Got dependencies!" | PASS |
| 2 | Confirm `kit-KitSince` is present and exported (`lib/ui/kit/kit_since.dart`, a `KitSince` row in `kit.dart`) | present | absent: no `lib/ui/kit/kit_since.dart` in this worktree; `grep -rn "KitSince" lib/ui/kit/kit.dart` finds nothing | FAIL (blocking) |
| 3 | KitScanner implementation | built to spec | not started (see Blockers) | BLOCKED |

## 5. Evidence

- `dependency-check.txt`: the exact commands and output that establish `kit-KitSince` is not yet integrated on `feat/phone-setup-v2`.
- Rule evidence (PROC-31): n/a — no implementation exists to test.
- Changed test expectations (TEST-19): none.
- Goldens changed: none.
- Before and after: n/a — no UI page owned by this unit.
- Accessibility: n/a — nothing built.
- Privacy and security: n/a — nothing built; note for the eventual build: SEC-2/SEC-5 (the decoded QR carries the pairing password) and the "never kept" test in the frozen spec's Tests §3 must be honoured once `kit-KitSince` lands.
- Migration: n/a — no stored format involved.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
ls lib/ui/kit/kit_since.dart            # No such file or directory
grep -n "KitSince" lib/ui/kit/kit.dart  # no output
git log --oneline -1 feat/phone-setup-v2
git branch -a --list 'revamp/kit-KitSince'   # exists as a sibling, unmerged branch
```

## 7. NOT proven

- Not run on a device or emulator.
- No implementation exists: none of the frozen spec's states, tokens, adaptive layout, RTL, motion, data-safety or the nine required behaviour tests in `test/kit/kit_scanner_test.dart` were built or run, because the dependency they need (`KitSince`'s 8 s escalation, STATE-5) is not available in this worktree.
- The 24 required gallery PNGs in `test/goldens/kit/kit_scanner_golden_test.dart` were not generated.

## Blockers (PROC-32)

`kit-KitScanner`'s frozen spec (`docs/ux-system/kit-api/KitScanner.md` §"Depends on") requires `kit-KitSince` for the `slow` state's 8 s escalation (STATE-5), and is explicit that building a local `Timer` instead is forbidden ("Without it the part would need its own `Timer`, which the kit forbids (KitStateView.md, C12)"). The task's own hard rules repeat this: "If you need another unit's part that has not merged, stop and report it; never build a local substitute."

`kit-KitSince` is not present on `feat/phone-setup-v2` (no `lib/ui/kit/kit_since.dart`, no `kit.dart` export) and is not in this repository's committed history under any name. It exists only as work in progress on the sibling branch `revamp/kit-KitSince` (checked out in a sibling worktree in this same wave batch), which has not been integrated. `kit-KitScanner` is therefore blocked by kind `dependency`:

- **Kind:** dependency.
- **Unit/file needed:** `kit-KitSince` — `lib/ui/kit/kit_since.dart`, exported from `kit.dart`, merged into `feat/phone-setup-v2` (or whatever branch this unit is rebuilt against).
- **What is needed:** the `KitSince` builder (`KitSince(since:, builder:, onEscalated:)` per `docs/ux-system/kit-api/KitSince.md`) available to import, so `KitScanner`'s `starting → slow` transition at `KitMotion.escalateAfter` (8 s) can be built per spec instead of with a forbidden local `Timer`.
- **Exact change requested:** merge `kit-KitSince` into the integration branch this unit builds from, then re-run this unit (fresh worktree, same branch name `revamp/kit-KitScanner`) so it can build `KitScanner` in full, including the `slow` state, its `KitSince`-driven tests (spec test 5) and its `slow` gallery frames.

No code was written under `lib/ui/kit/kit_scanner.dart` or the test/golden write set: every state in the frozen spec's state table interacts with the same widget/state machine that also owns `slow`, and four of the nine required behaviour tests (accept-once's stop-before-next-frame timing, the slow test itself, the lifecycle test's restart timing, and the overflow/motion sweep across all five declared states) cannot be written or meaningfully asserted without the real `KitSince` wired in. Writing a partial file that omits `slow` (or fakes it with a local timer) would violate both the frozen spec and the task's explicit "never build a local substitute" rule, and would not meet the unit's finish line ("every state"). So per PROC-32, the unit stops here rather than committing an incomplete or rule-breaking implementation.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | partial (blocked, PROC-32) | not applicable — no code committed |
| Enabled | No | |
| Verified | No | |
| Committed | Yes (this QA record only) | code head: this record's commit |
| Deployed | No | |
| Released | No | |
