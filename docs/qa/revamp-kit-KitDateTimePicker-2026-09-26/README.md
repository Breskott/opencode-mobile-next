# revamp-kit-KitDateTimePicker: Build KitDateTimePicker (2026-09-26)

## 1. Scope

- Unit: `kit-KitDateTimePicker` (wave 1, kit-part). Finish line: `KitDateTimePicker` exists in
  `lib/ui/kit/kit_date_time_picker.dart`, exported with one `kit.dart` row, with its full §4
  API, every declared state, its galleries (TEST-9) and its contract tests (TEST-15).
  Non-goal: no call site outside the kit changes (the two `showDatePicker`/`showTimePicker`
  migrations are wave 2, per the spec's own Non-goals).
- Files changed: `docs/qa/revamp-kit-KitDateTimePicker-2026-09-26/README.md` only. No kit,
  library or test file was created — see "Contract problems" and PROC-32 below.
- Pages (map ids): none (this unit has no `pages` in work-units.json).
- Specs followed: STANDARDS.md PROC-17, PROC-20, PROC-32; `docs/ux-system/kit-api/KitDateTimePicker.md`
  ("Depends on"); `docs/ux-system/revamp/work-units.json` (`kit-KitDateTimePicker`, `kit-KitField`,
  `kit-KitSegmented` records).
- Contract problems (PROC-20): **1 found, `blocks: true`.**
  - **What it says.** The unit's dispatch text states "Everything this unit builds on (nothing)
    is already integrated on feat/phone-setup-v2", matching `work-units.json`'s
    `"kit-KitDateTimePicker"` record, which has `"after": []` (no listed prerequisite unit).
  - **Why it is wrong.** The frozen spec for the same part,
    `docs/ux-system/kit-api/KitDateTimePicker.md` §"Depends on" (lines 212-222), lists
    `KitField` (kit-KitField) and `KitSegmented` (kit-KitSegmented) as hard dependencies, and
    its own "Edges added" note says this unit is "tier 1e, after kit-KitSegmented (1d, itself
    after kit-KitChoiceList)". The frozen API text requires both directly:
    - `showKitTimePicker`'s hour/minute entry is "Two `KitField(kind: number)` fields" (line 116).
    - The 12-hour AM/PM control is "a `KitSegmented` AM/PM control" (line 116).
    - `showKitDatePicker`'s required "Type a date" affordance and its `date-typed`/`date-invalid`
      states (lines 115, 121-123, tests item 3, galleries) swap in "a `KitField` that parses the
      locale's short date" (line 115).
    Neither part exists in this repository at `feat/phone-setup-v2` (`git log --oneline --all`
    has no `KitField`/`KitSegmented` merge; `grep -rn "class KitField\|class KitSegmented" lib/`
    returns nothing). `kit-KitSegmented` has an unmerged branch (`revamp/kit-KitSegmented`,
    forbidden to merge here by R02); `kit-KitField` has no branch at all, and its own
    `work-units.json` record (lines 1296-1313) lists `"after": ["kit-KitSince", "kit-KitIconButton-v2"]`
    — i.e. it is itself blocked on two more unbuilt parts. This satisfies PROC-20's "contradicts
    the code's callable reality" test, and PROC-32's "A unit whose `after` dependency was not
    integrated does not start" — the ledger's `after: []` is what is wrong, not the frozen spec.
  - **Evidence.** `docs/ux-system/kit-api/KitDateTimePicker.md:115-116,212-222`;
    `docs/ux-system/revamp/work-units.json:1024-1046` (this unit, `"after": []`),
    `:918-943` (`kit-KitSegmented`, unmerged), `:1296-1313` (`kit-KitField`, no branch, itself
    blocked); `git branch -a` (no `KitField` branch; `revamp/kit-KitSegmented`,
    `revamp/kit-KitIconButton-v2`, `revamp/kit-KitSheet-v2` exist but unmerged); `git log
    --oneline --all --grep=KitField --grep=KitSegmented` (no hits).
  - **Proposed replacement text.** `work-units.json`'s `kit-KitDateTimePicker.after` should read
    `["kit-KitField", "kit-KitSegmented"]`, and the unit should not be dispatched until both are
    integrated on `feat/phone-setup-v2` (or, if the owner wants the clock-dial-free typed-entry
    design descoped for a first pass, the frozen spec's "What it draws" section needs a revised,
    explicitly-approved fallback that names the exact framework widgets a `kit-part` may use
    directly, the way it already does for `CalendarDatePicker`).
  - `blocks: true` — the finish line cannot be met.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a — no `pages` on this unit's record.
- States per page (STATE-20): n/a — no pages.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitDateTimePicker`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (`feat/phone-setup-v2` tip at start), code head `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (no code commit — nothing in the write set could be built to the frozen spec; see above).
- No APK (unit agents do not build; also n/a, no code).

## 3. Devices

None: no implementation exists to run. Device proof is a wave checkpoint concern once the
part is buildable.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `grep -rn "class KitField" lib/` | a hit (dependency present) | no hits | FAIL (confirms blocker) |
| 2 | `grep -rn "class KitSegmented" lib/` | a hit (dependency present) | no hits | FAIL (confirms blocker) |
| 3 | `git branch -a \| grep -iE "kit-kitfield"` | a branch to point to (still not mergeable per R02) | no branch at all | FAIL (confirms blocker) |
| 4 | `flutter pub get` | resolves | "Got dependencies!" | PASS |

Rows 1-3 are the feasibility check itself (AGENTS.md rule 2 / PROC-17), not a test of built
behaviour: there is no behaviour to test yet.

## 5. Evidence

- No `failing-first.txt`: no fix was made.
- Rule evidence (PROC-31): n/a, no test file exists to cite.
- Changed test expectations (TEST-19): none.
- Goldens changed: none.
- Before and after: n/a, no page/state changed.
- Accessibility: n/a, not built.
- Privacy and security: n/a: no credentials, stored data, links or notifications touched.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
grep -rn "class KitField" lib/            # no hits
grep -rn "class KitSegmented" lib/        # no hits
git branch -a | grep -iE "kit-kitfield|kit-kitsegmented"   # KitSegmented has an unmerged
                                                            # branch; KitField has none
```

## 7. NOT proven

- Not run on a device or emulator.
- No implementation, tests or galleries exist for `KitDateTimePicker`: the unit is blocked
  before any of §15's required behaviour, motion, keyboard, accessibility or overflow checks
  could be attempted.
- Whether the owner wants a descoped, KitField/KitSegmented-free first pass (e.g. framework
  `TextField`/`SegmentedButton` named explicitly in a revised spec, the way `CalendarDatePicker`
  already is) is unresolved; see Open question 1 in the frozen spec, which is about the clock
  dial, not this ordering gap, and does not cover it.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | partial (PROC-32: blocked before any code) | `revamp/kit-KitDateTimePicker` |
| Enabled | No | |
| Verified | No: nothing built to verify | |
| Committed | Yes (QA record only) | code head `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4` |
| Deployed | No | |
| Released | No | |
