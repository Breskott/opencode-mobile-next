# revamp-kit-KitDateTimePicker: Build KitDateTimePicker (2026-09-27)

Supersedes the blocked record `docs/qa/revamp-kit-KitDateTimePicker-2026-09-26/`:
KitField and KitSegmented are now integrated on `feat/phone-setup-v2`, so the
part is built in full.

## 1. Scope

- Unit: `kit-KitDateTimePicker` (wave 1, tier 1, kit-part). Finish line: the
  frozen API (`KitDateTimeMode`, `KitDateTimePicker.earliest/latest`,
  `showKitDatePicker`, `showKitTimePicker`, `showKitDateTimePicker`,
  `KitDateTimeRow.date/.time/.dateAndTime`) exists in
  `lib/ui/kit/kit_date_time_picker.dart` with every declared state, behaviour
  tests and galleries. Non-goal: no call site migrates (form_renderer and
  notifications settings are wave 2), `kit.dart` is not edited (integrator
  adds the export, R06).
- Files changed: `lib/ui/kit/kit_date_time_picker.dart` (new),
  `test/kit/kit_date_time_picker_test.dart` (new),
  `test/goldens/kit/kit_date_time_picker_golden_test.dart` + 24 PNGs (new),
  `lib/l10n/app_en.arb` (+16 keys) and the regenerated
  `lib/l10n/app_localizations*.dart`, this record.
- Pages (map ids): none on this unit (the part serves
  `form-sheet-date-picker` and `notifications-settings-quiet-time-dialog`
  when wave 2 migrates them).
- Specs followed: `docs/ux-system/kit-api/KitDateTimePicker.md`; STANDARDS
  KIT-2, KIT-10, KIT-11, KIT-12, MOT-2, MOT-11, COPY-8, COPY-30, STATE-8,
  DATA-1, TEST-9, TEST-11, TEST-20; kit-v2 §8.2 (through `showKitSheet`),
  §8.3 (keyboard).
- Owner decisions applied (2026-09-27): Arabic dropped (no `app_ar.arb`
  entries, no RTL/Arabic galleries; spec test item 8 reduced to a
  mirrored-arrow check under an RTL `Directionality`); galleries at 412x915
  and 1280x800 only, light and dark; tests written and run once.
- Contract problems (PROC-20), none blocking:
  1. **"What it draws: the framework's `CalendarDatePicker`" vs the spec's own
     Tokens/Adaptive/Accessibility lines.** The stock calendar draws its month
     chevrons as stock `IconButton`s with stock tooltips (R14: tooltips only
     through KitIconButton), has no Home/End week keys, cannot hover in
     `surface3`, reads `DatePickerThemeData` (the spec's own open question 3,
     a `Theme` override outside `app_theme.dart`, R23) and has a year-picker
     header the spec does not ask for. Built instead: a kit-drawn month grid
     inside the part, using `MaterialLocalizations` for the week order
     (`firstDayOfWeekIndex`, `narrowWeekdays`), month/year and full-date
     labels, and `DateUtils` for arithmetic. Public API unchanged; open
     question 3 disappears (no `Theme` override at all). Proposed text: "Date:
     a kit-drawn month grid (MaterialLocalizations week order and labels)".
  2. **48 dp day cells at 320 dp.** Seven 48 dp columns need 336 dp; the
     sheet's body rails leave 320 dp at a 360 dp window (and 280 dp at 320).
     Cells are 48 dp tall everywhere and 48 dp wide from about 376 dp of
     window (412 dp phone: 53 dp); below that each column is window/7
     (45.7 dp at 360). The columns touch, so the tap area is contiguous. The
     spec's test item 11 ("day cells at least 48 dp at 320 dp") cannot hold
     with 7 columns; the test asserts 48x48 at 412 dp. Proposed text: "at
     least 48 dp tall, and 48 dp wide wherever the window gives 7 × 48 dp".
  3. **`KitDateTimeRow` `onChanged` type.** The API block types it
     `required ValueChanged<DateTime?> onChanged` but says "null: disabled".
     Built as `required ValueChanged<DateTime?>? onChanged` (and
     `ValueChanged<TimeOfDay?>?` for `.time`) so null can disable it.
  4. **Copy keys added beyond the spec's list:** `kitDateField` ("Date", the
     typed field's visible label: KitField requires one), `kitTimePeriod`
     ("Morning or afternoon", KitSegmented's required `semanticsLabel`) and
     `kitDateUnavailable` ("That day can’t be chosen", a typed day in range
     but refused by `selectable`; "Not a date" and the range reason would
     both be false there).
  5. **Kit copy lives in `app_en.arb` only** (owner decision 2026-09-27), so
     gen-l10n reports 16 untranslated `ar` messages; the unit's dispatch text
     still says "app_en.arb AND app_ar.arb"; the later owner decision wins.
  6. **Clear label** is `Clear {title}` with the row title as given ("Clear
     Due date"); the spec's example lowercases it ("Clear due date"), which
     is not locale-safe to do in code.
- New kit parts (KIT-3): none beyond this unit's own part.
- Moved or removed (owner rethink rule): the row's Clear button sits beside
  the row's tap target instead of inside its trailing slot, so the row reads
  as one button ("Due date, Oct 3, 2026") and Clear as another (inside, it
  broke the row's merged label: G5 labeledTapTarget). A disabled row shows
  no chevron (it opens nothing). The month grid shows only the weeks the
  month needs (no blank sixth week between the days and the actions).
- Map items (EVID-11): n/a — no pages on this unit.
- States (STATE-20), each → golden (both themes, 412x915):
  date → `kit_date_time_picker_date_*` (also 1280x800 and text 2.0);
  date-typed → `_date_typed_*`; date-invalid → `_date_invalid_*`;
  time (24-hour, en_GB) → `_time_*`; time-12h → `_time_12h_*`;
  time-invalid (validate reason) → `_time_invalid_*`;
  date-and-time → `_date_and_time_*`; row-empty + row-set →
  `_row_empty_set_*`; row-error → `_row_error_*`; row-disabled →
  `_row_disabled_*`.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitDateTimePicker`, base `646990ad`
  (`feat/phone-setup-v2`; the branch's earlier docs-only commits were
  already merged there, so it was reset onto that tip), code head
  `65539be5`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1
checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_date_time_picker_test.dart` | passes | 39 passed | PASS |
| 2 | `test/goldens/kit/kit_date_time_picker_golden_test.dart` (G4 + G5 in both themes) | passes | 24 passed | PASS |
| 3 | `flutter analyze` on the part, both test files and `lib/l10n` | no issues | no issues | PASS |
| 4 | Ratchet, design-standard, l10n coverage, manifest tests | — | not run (owner decision 2026-09-27: own files only); banned patterns self-checked by grep (no `Curves.`, duration literals, numeric insets/sizes/radii, `fontSize:`, left/right layout, `Tooltip(`, stock pickers) | not run |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule / spec item | Test (`--plain-name`) or golden |
  |---|---|
  | KIT-11, route named by title, day returned | "its route is named by the title and a day is returned" |
  | DATA-1, dismissal returns null | "Esc, back, close and a swipe return null" |
  | Inert days announced as unavailable | "days outside the range or refused are inert and unavailable" |
  | Full-date + today announcement | "each day announces its full date and today" |
  | Typed date in place, invalid/out of range block Set | "\"Type a date\" swaps in place and checks the entry" |
  | Test item 9 (no stock picker / dialog route) | "no stock picker or dialog route is pushed" |
  | 24-hour / 12-hour / 12 AM = 00:00 | "24-hour: two number fields…", "12-hour: AM/PM control, and 12 AM is 00:00" |
  | Arrow/Page keys in time fields | "Arrow Up/Down step the field, Page Down moves 10 minutes" |
  | "Not a time", validate announced once | "hour 25 is refused…", "a validate reason blocks closing and is announced once" |
  | Combined local DateTime | "showKitDateTimePicker returns the combined local DateTime" |
  | Row value, tap, Clear, disabled reason, error | group "KitDateTimeRow" |
  | §8.3 keyboard | group "keyboard" (start on selected day, arrows + Enter, Home/End, Page Down announced once, RTL mirrored arrows, Tab reaches grid, "Type a date" and "Set date", Esc) |
  | MOT-2 reduced motion | "under reduced motion the month change and swap take one pump" |
  | G6 overflow | group "overflow (G6)" (320x640, 412x915, 915x412, 1280x800, 1600x1000 × text 1.0/1.3/2.0) |

- Changed test expectations (TEST-19): none (all tests new).
- Goldens (new, each opened and looked at): the 24 `test/goldens/kit/kit_date_time_picker_*.png`. The typed-date shots were re-rendered after moving the caret before focus, which removed a touch selection handle that covered the "Not a date" reason.
- Accessibility: every day is a 48 dp-tall button labelled with its full date (", Today" for today), selected/enabled flags, never colour alone (selected = filled accent circle + selected flag); chevrons are `KitIconButton`s with the localized "Previous month"/"Next month" tooltips; month change announced once; hour/minute labelled, AM/PM is a labelled `KitSegmented`; the time fields stack when they do not fit at large text; G5 (tap targets, labels, contrast, reading order) passes in all 24 shots in both themes.
- Privacy and security: n/a — no credentials, stored data, links or notifications.
- Migration: n/a — no stored format; nothing is persisted.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_date_time_picker_test.dart test/goldens/kit/kit_date_time_picker_golden_test.dart
$F analyze lib/ui/kit/kit_date_time_picker.dart test/kit/kit_date_time_picker_test.dart test/goldens/kit/kit_date_time_picker_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (soft keyboard over the pinned action, TalkBack wording of inert days).
- Shared gates (kit_ratchet, design_standard, l10n_coverage, kit_manifest, golden_harness) not run; the integrator runs them after adding the `kit.dart` export (the manifest-discovered G4/G5/G6/G14 gates will pick the part up then).
- KIT-2: the G1 patterns `showDatePicker(` / `showTimePicker(` are not added here (spec open question 2: integrator).
- Arabic/RTL galleries and `ar` copy: dropped by the owner.
- Open question 1 (clock dial): built as typed entry per the freeze.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitDateTimePicker` |
| Enabled | No: no call site uses it yet (wave 2 migrations), not exported from `kit.dart` until the integrator adds it | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `65539be5` |
| Deployed | No | |
| Released | No | |
