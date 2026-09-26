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
  ("Depends on", including its "Edges added" line); `docs/ux-system/revamp/work-units.json`
  (`kit-KitDateTimePicker`, `kit-KitField`, `kit-KitSegmented`, `kit-KitIconButton-v2`,
  `kit-KitSheet-v2` records).
- Contract problems (PROC-20): **1 found, `blocks: true`.**
  - **What it says.** The unit's dispatch text states "Everything this unit builds on (nothing)
    is already integrated on feat/phone-setup-v2", matching `work-units.json`'s
    `"kit-KitDateTimePicker"` record, which has `"after": []` (no listed prerequisite unit).
  - **Why it is wrong.** The frozen spec for the same part,
    `docs/ux-system/kit-api/KitDateTimePicker.md` §"Depends on" (lines 212-222), lists four
    prerequisite units, and its own "Edges added" note (line 222) states the edge set in full:
    "DateTimePicker = [Field, Segmented, IconButton-v2, Sheet-v2] places it in tier 1e, after
    kit-KitSegmented (1d, itself after kit-KitChoiceList)". Two of them are hard dependencies
    and two are soft:
  - **Hard: `KitField` (kit-KitField) and `KitSegmented` (kit-KitSegmented).** No class of
    either name exists, and no nearer part carries their contract. The frozen API text requires
    both directly:
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
    — i.e. it is itself blocked on two more unbuilt parts.
  - **Soft: `KitSheet` v2 (kit-KitSheet-v2) and `KitIconButton` v2 (kit-KitIconButton-v2).**
    The spec names both as prerequisites: the sheet frame is "the existing `showKitSheet`; the
    v2 look from kit-KitSheet-v2, C17" (line 214), and "the month chevrons and the row's Clear"
    are v2 `KitIconButton`s (line 217). They are soft because the nearest existing parts already
    carry the callable contract the picker needs: `showKitSheet` (`lib/ui/kit/kit_sheet.dart:132`,
    title, body, primary, content height) and `KitIconButton` (`lib/ui/kit/kit_icon_button.dart:7`,
    a `label` that is its tooltip, 48 dp target). Building against them now would still produce
    galleries and a sheet look that must be redone when v2 lands, and the ledger's `after: []`
    would let the unit be dispatched before that. Both branches exist but carry no v2 work:
    `revamp/kit-KitSheet-v2` and `revamp/kit-KitIconButton-v2` have 0 commits beyond
    `feat/phone-setup-v2` (they sit at its earlier tip `b67e3276`, checked out in other agents'
    worktrees), so neither v2 is integrated. IconButton-v2 is reached indirectly through
    KitField's own `after`, but this part uses it directly (chevrons, Clear), so the edge belongs
    on this unit too.
  - This satisfies PROC-20's "contradicts the code's callable reality" test, and PROC-32's "A
    unit whose `after` dependency was not integrated does not start": the ledger's `after: []`
    is what is wrong, not the frozen spec.
  - **Evidence.** `docs/ux-system/kit-api/KitDateTimePicker.md:115-116,212-222` (line 222 is the
    "Edges added" line); `docs/ux-system/revamp/work-units.json:1024-1046` (this unit,
    `"after": []`), `:918-943` (`kit-KitSegmented`, unmerged), `:1296-1313` (`kit-KitField`, no
    branch, itself blocked), `:531` (`kit-KitIconButton-v2`), `:755` (`kit-KitSheet-v2`);
    `git branch -a` (no `KitField` branch; `revamp/kit-KitSegmented` at `fa62e3d3`, not an
    ancestor of `feat/phone-setup-v2`); `git log --oneline feat/phone-setup-v2..revamp/kit-KitSheet-v2`
    and `..revamp/kit-KitIconButton-v2` (0 commits each); `git grep "class KitField\b\|class
    KitSegmented\b" feat/phone-setup-v2 -- lib/` (no hits at `ae181bc9`).
  - **Proposed replacement text.** `work-units.json`'s `kit-KitDateTimePicker.after` should read
    `["kit-KitField", "kit-KitSegmented", "kit-KitIconButton-v2", "kit-KitSheet-v2"]`, matching the
    frozen spec's "Edges added" line, and the unit should not be dispatched until all four are
    integrated on `feat/phone-setup-v2` (or, if the owner wants the typed-entry design descoped
    for a first pass, the frozen spec's "What it draws" section needs a revised,
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
  The blocker was rechecked against the later `feat/phone-setup-v2` tip `ae181bc9`: still no
  `KitField`/`KitSegmented` class, and still no v2 commit from either v2 branch.
- QA-record commits: `76100c70` (first record) and the review-fix commit that adds the
  Sheet-v2 and IconButton-v2 edges.
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
| 5 | `git log --oneline feat/phone-setup-v2..revamp/kit-KitSheet-v2 \| wc -l` | v2 work integrated | 0 commits: the branch holds no v2 work yet | FAIL (confirms soft blocker) |
| 6 | `git log --oneline feat/phone-setup-v2..revamp/kit-KitIconButton-v2 \| wc -l` | v2 work integrated | 0 commits: the branch holds no v2 work yet | FAIL (confirms soft blocker) |
| 7 | `git grep "class KitField\b\|class KitSegmented\b" feat/phone-setup-v2 -- lib/` at `ae181bc9` | a hit | no hits | FAIL (blocker still holds at the later tip) |

Rows 1-3 and 5-7 are the feasibility check itself (AGENTS.md rule 2 / PROC-17), not a test of built
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
git log --oneline feat/phone-setup-v2..revamp/kit-KitSheet-v2        # empty: no v2 work
git log --oneline feat/phone-setup-v2..revamp/kit-KitIconButton-v2   # empty: no v2 work
sed -n 212,222p docs/ux-system/kit-api/KitDateTimePicker.md          # the four edges
```

## 7. NOT proven

- Not run on a device or emulator.
- No implementation, tests or galleries exist for `KitDateTimePicker`: the unit is blocked
  before any of §15's required behaviour, motion, keyboard, accessibility or overflow checks
  could be attempted.
- The KitSheet v2 look (kit-KitSheet-v2: grabber, icon tile, left-aligned title, stacked
  buttons on phones) and the KitIconButton v2 behaviour (kit-KitIconButton-v2: hover tooltip
  with the shortcut, selected/working states) are not integrated, so the picker's sheet frame,
  month chevrons and the row's Clear are unproven against them. The nearest existing parts,
  `showKitSheet` and `KitIconButton`, were read but not built on: using them now would give
  galleries that need redoing when v2 lands.
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
