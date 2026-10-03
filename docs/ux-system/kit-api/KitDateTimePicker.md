# KitDateTimePicker — API freeze (wave 0, 2026-09-26)

Unit: `kit-KitDateTimePicker` (wave 1, tier 1e, kind `kit-part`). Spec: kit-v2.md §9.2 ("KitDateTimePicker replaces showDatePicker, showTimePicker; replaces the stock allowance in G1"), §4.6, §8.2, §8.3; STANDARDS KIT-2, KIT-11, KIT-44, MOT-2, COPY-8, COPY-30, Appendix A #17. Map records form-sheet-date-picker ("keep: familiar stock picker; only confirmText 'Use date'") and notifications-settings-quiet-time-dialog ("fix: say which end it sets and use a verb"; statesMissing: "start equals end is not explained"). STANDARDS wins where it differs from kit-v2.md.

## Purpose

The one way to pick a date, a time, or both. It is a kit sheet whose title says which value it sets, whose button is a verb, and which works by touch, keyboard and screen reader in every window class. It replaces the stock `showDatePicker` and `showTimePicker` dialogs, which carry Material's own look, buttons ("OK") and fade-scale.

## Replaces

- **Map elements.** kit-v2.json assigns `form-sheet-date-picker#form-sheet-date-picker` and `notifications-settings-quiet-time-dialog#quiet-time-picker` to `module:special surface` (§5). §9 (owner, kit only) moves them into the kit as this part.
- **Code sites** (`lib/`, 2026-09-26):

  | File | Call |
  |---|---|
  | `lib/ui/widgets/form_renderer.dart:700` | `showDatePicker` (form date and date-time fields) |
  | `lib/ui/widgets/form_renderer.dart:709` | `showTimePicker` (the time half of a date-time field) |
  | `lib/ui/screens/settings/notifications_settings_screen.dart:114` | `showTimePicker` (quiet hours start and end) |

- **The date field in `form_renderer.dart`** (a read-only `TextField` with a calendar suffix `Icon` that opens the picker; part of its G16 `TextField` 5) becomes `KitDateTimeRow`.
- **G1 baseline.** Neither call is counted today, because K2 G1 allowed stock pickers. KIT-2 adds `showDatePicker(` and `showTimePicker(` to G1 when this part merges (see Open questions for who commits the pattern).

## File

`lib/ui/kit/kit_date_time_picker.dart`. It holds `KitDateTimeMode`, `showKitDatePicker`, `showKitTimePicker`, `showKitDateTimePicker`, `KitDateTimeRow` and the named range constants. Tests go in `test/kit/kit_date_time_picker_test.dart` and galleries in `test/goldens/kit/kit_date_time_picker_golden_test.dart`.

## Public API

```dart
enum KitDateTimeMode { date, time, dateAndTime }

abstract final class KitDateTimePicker {
  /// The default range when a caller gives none (the form renderer's today).
  static final DateTime earliest = DateTime(1900);
  static final DateTime latest = DateTime(2100, 12, 31);
}

/// A date. Returns the chosen day (local, time 00:00), or null when dismissed.
Future<DateTime?> showKitDatePicker(
  BuildContext context, {
  required String title,                    // which value this sets: "Due date"
  DateTime? initial,                        // default: today
  DateTime? first,                          // default: KitDateTimePicker.earliest
  DateTime? last,                           // default: KitDateTimePicker.latest
  bool Function(DateTime day)? selectable,  // days that cannot be chosen are shown inert
  String? confirmLabel,                     // a verb; default kit "Set date"
  String? helper,                           // one line under the title: why or what it affects
  Key? sheetKey,
  Key? confirmKey,
});

/// A time of day. Returns the chosen time, or null when dismissed.
Future<TimeOfDay?> showKitTimePicker(
  BuildContext context, {
  required String title,                    // "Quiet from"
  required TimeOfDay initial,
  String? confirmLabel,                     // default kit "Set time"
  String? helper,                           // e.g. "Same as the end: quiet hours are off"
  String? Function(TimeOfDay value)? validate, // a reason, shown under the fields; Set does not close while invalid
  Key? sheetKey,
  Key? confirmKey,
});

/// A day and a time in one sheet (the calendar, then the time entry).
Future<DateTime?> showKitDateTimePicker(
  BuildContext context, {
  required String title,
  DateTime? initial,
  DateTime? first,
  DateTime? last,
  bool Function(DateTime day)? selectable,
  String? confirmLabel,                     // default kit "Set"
  String? helper,
  Key? sheetKey,
  Key? confirmKey,
});

/// The row a form or a settings list shows for a date or time value:
/// "Due date · 3 Oct 2026 ›". A tap opens the matching picker; the chosen
/// value is passed to onChanged. [clearable] adds a labelled Clear button.
class KitDateTimeRow extends StatelessWidget {
  const KitDateTimeRow.date({
    super.key,
    required this.title,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,   // null: disabled (disabledReason required)
    this.pickerTitle, this.first, this.last, this.selectable,
    this.placeholder,                              // shown when value is null: "Not set"
    this.clearable = false,
    this.supporting, this.error,
    this.disabledReason, this.rowKey, this.clearKey,
  });
  const KitDateTimeRow.time({
    super.key,
    required this.title,
    required TimeOfDay? value,
    required ValueChanged<TimeOfDay?> onChanged,
    this.pickerTitle, this.placeholder, this.clearable = false,
    this.supporting, this.error, this.disabledReason, this.rowKey, this.clearKey,
  });
  const KitDateTimeRow.dateAndTime({
    super.key,
    required this.title,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    this.pickerTitle, this.first, this.last, this.selectable,
    this.placeholder, this.clearable = false,
    this.supporting, this.error, this.disabledReason, this.rowKey, this.clearKey,
  });
  // The mode and the typed value are held in private fields.
}
```

- **What it draws.** Everything is inside the kit.
  - **Date:** the framework's `CalendarDatePicker` (a framework widget, allowed inside `lib/ui/kit/`), in the kit sheet frame, with a tertiary action "Type a date" that swaps in place (`KitReveal`, no second route) to a `KitField` that parses the locale's short date (`intl` `DateFormat.yMd`).
  - **Time:** typed entry. Two `KitField(kind: number)` fields, "Hour" and "Minute", plus a `KitSegmented` AM/PM control when the locale uses a 12-hour clock (`MediaQuery.alwaysUse24HourFormatOf` and `MaterialLocalizations`). Arrow Up and Down step the focused field by 1, and Page Up and Page Down by 10 minutes.
  - **Actions.** The primary is the verb (`confirmLabel`) and the sheet's close button cancels. There is never an "OK".
- **Presentation.** `showKitSheet` (content height). Choosing a date is a choice, and a choice is a sheet (K2 §4.6), so the part is not a dialog. It adapts through `showKitSheet` (§8.2).
- **Kit copy** (ARB, `kit` prefix): `kitDateSet` "Set date", `kitTimeSet` "Set time", `kitDateTimeSet` "Set", `kitDateType` "Type a date", `kitDateCalendar` "Show calendar", `kitDateFormatHint` "e.g. {example}" (Field example), `kitDateInvalid` "Not a date", `kitDateOutOfRange` "Pick a date between {first} and {last}", `kitTimeHour` "Hour", `kitTimeMinute` "Minute", `kitTimeInvalid` "Not a time", `kitDateTimeNotSet` "Not set", `kitDateTimeClear` "Clear {title}". AM and PM come from `MaterialLocalizations`.

## States

The doc comment declares: `date` (the calendar), `date-typed` ("Type a date" field), `date-invalid` (a typed date out of range or unparseable), `time` (24-hour), `time-12h` (with AM/PM), `time-invalid` (a `validate` reason or an impossible time), `date-and-time`, `row-empty` ("Not set"), `row-set`, `row-error`, `row-disabled`.

- **Loading and empty.** Not applicable: the values are local. The row's empty state is "Not set" (or `placeholder`) in `text3`.
- **Error.**
  - A typed date or time that does not parse, or is out of range, shows its reason under the field (KitField error).
  - `validate` reasons show under the time fields.
  - The primary stays enabled, so its reachability never depends on a live reason. Pressing it while invalid focuses the error, announces it, and does not close.
  - `KitDateTimeRow.error` shows under the row, for a form validation.
- **Disabled.** The row is dimmed with its reason on the supporting line (STATE-8). Days outside `first`/`last` or rejected by `selectable` are inert in the calendar and announced as unavailable.
- **Working and answered.** Not applicable. The value goes to the host, and a host that saves to a server shows its own receipt or notice (the notifications screen's save).

## Tokens

All of the following exist on `feat/visual-language-v1` unless flagged.

- **ThemeRoles:**
  - `surface2`: the sheet;
  - `accent`: the selected day fill, today's outline, the focus ring and the cursor (LOOK-6 current selection);
  - `onAccent`: the selected day's number;
  - `text1`: days and fields;
  - `text2`: weekday headers and helper;
  - `text3`: inert days and the empty row value;
  - `hairline`: the 1 px today outline and the separators;
  - `surface1`: the fields.
- **KitText roles:**
  - `title`: the sheet title;
  - `secondary`: the helper and the weekday headers;
  - `rowTitle`: day numbers, with tabular figures;
  - `label`: the month and year header;
  - `body`: the time fields, through `KitField`;
  - `rowTitle` and `secondary`: the row's title and value.
- **KitTokens:**
  - `minTarget` (48): each day cell is at least 48 dp;
  - `space2`–`space4`;
  - `smallIconSize` (20): the month chevrons and the calendar/keyboard toggle;
  - `sheetRadius` and `handle*` (through `showKitSheet`);
  - `panelCornerRadius` (18): the row panel;
  - `maxIconScale`.
- **KitMotion:** `quick` for the month change (a slide, MOT-2), and `standard` through `KitReveal` for the calendar ↔ typed swap.
- **Flagged: calendar theming.** `CalendarDatePicker` reads `DatePickerThemeData`. VL's `app_theme.dart` sets no `datePickerTheme`, and `app_theme.dart` is not in this unit's write set. This unit wraps the calendar in a kit-local `Theme` whose `datePickerTheme` is derived from `ThemeRoles` and `KitText` inside `kit_date_time_picker.dart`. R23 ("Theme overrides only in app_theme.dart") is read as a rule for screens, and the kit is where such plumbing belongs. See Open questions.
- **New tokens:** none.

## Adaptive

- **Compact.** A bottom sheet at content height. The calendar is the full sheet width on the 16 dp rails, and the day cells are 48 dp or more (the grid grows with width, never shrinks below 48). The primary is pinned at the bottom. The date-and-time mode puts the time entry under the calendar, and the body scrolls if needed.
- **Medium.** A bottom sheet capped at 640 dp and centred (through `showKitSheet`).
- **Expanded and large.** A centred panel of up to 560 dp (through `showKitSheet`). The date-and-time mode may place the time entry beside the calendar when the panel is wide enough for both at 48 dp cells. It measures, it does not compare to a width literal.
- **Short windows (< 480 dp tall, a landscape phone).** A bottom sheet whose body scrolls. The primary stays pinned above the keyboard.
- **Keyboard (§8.3, G14):**
  - Focus starts on the selected day, or on the Hour field for time.
  - Arrow keys move the day, following direction in RTL; Page Up and Page Down change the month; Home and End go to the week's start and end.
  - Enter or Space picks the focused day.
  - Tab order: the month header → the grid → "Type a date" → the time fields → the primary.
  - Esc closes the sheet (returning null) and obeys no draft (nothing typed is kept, see Data safety).
  - Enter on the primary sets the value.
- **Fine pointer.** A hover highlight on days (`surface3`). The month chevrons are `KitIconButton`s with tooltips. Targets stay 48 dp.

## Accessibility

- The sheet's route is named by `title` ("Quiet from"), so a screen reader hears which value it sets. The quiet-hours map fix is structural: the title is required.
- Each day is announced with its full date, its state (selected, today, unavailable) and its place ("Friday, 3 October 2026, selected").
- The month change is announced once ("October 2026").
- The time fields are labelled "Hour" and "Minute", and AM/PM is a labelled `KitSegmented` group.
- The typed-date field's hint is an example in the locale's format, marked as a Field example (COPY-11).
- Targets are 48 dp (day cells, chevrons, toggles). Selection is marked by a filled accent circle plus semantics, never colour alone.
- At 200 % text the calendar keeps 7 columns, the cells grow and the sheet scrolls, and the month header wraps. The time fields stack vertically when they do not fit side by side.
- `KitDateTimeRow` is a `KitRow`. Its semantics read title, value and "Double tap to change". Clear is a labelled `KitIconButton` ("Clear due date").

## RTL

- The calendar grid and weekday order follow the locale (the framework's `CalendarDatePicker` with the locale's first day of week). The month chevrons mirror, and arrow keys follow visual direction.
- The hour–minute pair is laid out left to right in both directions, as clocks are written. AM/PM follows the locale.
- Every date and time shown (row value, header, announcements) is formatted by `intl` or `MaterialLocalizations` for the current locale. There is no hand-built formatting and no digit conversion (COPY-30, B17).
- A typed date accepts the locale's digits and is parsed by `intl`.

## Motion and haptics

- The month change slides the grid horizontally on `KitMotion.quick` (the direction mirrors in RTL). The calendar ↔ typed swap uses `KitReveal` on `KitMotion.standard`.
- The sheet's own motion comes from `showKitSheet`.
- There is no fade-scale anywhere (MOT-2). This is the reason the stock dialogs go.
- Under `KitMotion.reduced` everything is instant, and one `pump()` settles.
- Haptics: none (MOT-11).

## Data safety and honest state

- **Nothing is written by the part.** The value is returned to the host, which saves it. Cancel, Esc, back or a swipe returns null and leaves the host's value unchanged. Typed partial entries are not kept: they are a moment's input, not work, and DATA-1 allows this for non-multiline input.
- **No silent coercion.** An impossible typed date (31 February) or out-of-range day is refused with its reason, never rounded. Local time only: the part returns local `DateTime`s, and a host that needs UTC or ISO converts explicitly, as `form_renderer` does today.
- **Honest wording.** The title always says which value it sets, the primary is a verb ("Set time"), and `helper` lets the host state a consequence, such as the quiet-hours case "Start equals end: quiet hours are off" (the map's statesMissing).

## Depends on

- **KitSheet** (the existing `showKitSheet`; the v2 look from kit-KitSheet-v2, C17).
- **KitField** (kit-KitField): the typed date, and hour and minute.
- **KitSegmented** (kit-KitSegmented): AM/PM.
- **KitIconButton v2** (kit-KitIconButton-v2): the month chevrons and the row's Clear.
- **Existing parts:**
  - `KitRow`/`KitChevron`: `KitDateTimeRow`;
  - `KitAction`, `KitReveal`, `KitMotion`;
  - `KitText`/`ThemeRoles`/`KitTokens` (VL).
- **Edges added** (README.md): C25 gave kit-KitDateTimePicker none. DateTimePicker = [Field, Segmented, IconButton-v2, Sheet-v2] places it in tier 1e, after kit-KitSegmented (1d, itself after kit-KitChoiceList). Nothing depends on it in wave 1.

## Tests required

In `test/kit/kit_date_time_picker_test.dart` (G9, G14, TEST-15):

1. `showKitDatePicker`:
   - its route is named by `title`;
   - tapping a day, then "Set date", returns that day (local, 00:00);
   - Esc, back, close and a swipe return null.
2. Days before `first`, after `last`, or rejected by `selectable` are inert and announced as unavailable, and tapping them changes nothing.
3. "Type a date":
   - it swaps in place with no new route;
   - a valid locale date returns it;
   - "31/02/2026" shows "Not a date";
   - an out-of-range date shows the range reason;
   - Set does not close while the entry is invalid.
4. `showKitTimePicker`:
   - 24-hour locale: two number fields, and Set returns the `TimeOfDay`;
   - a 12-hour locale shows the AM/PM `KitSegmented`, and 12 AM gives 00:00;
   - Arrow Up and Down step the fields;
   - hour 25 is refused with "Not a time";
   - a `validate` reason blocks closing and is announced once.
5. `showKitDateTimePicker` returns the combined local `DateTime`.
6. `KitDateTimeRow`:
   - it shows the formatted value (intl, locale) or "Not set";
   - a tap opens the matching picker, and the result reaches `onChanged`;
   - `clearable` shows a labelled Clear that calls `onChanged(null)`;
   - disabled without a reason asserts, and disabled shows its reason.
7. Keyboard (desktop capabilities):
   - focus starts on the selected day;
   - the arrows move days, mirrored in RTL;
   - Page Down moves to the next month;
   - Enter picks;
   - Tab reaches every action;
   - Esc returns null.
8. RTL (Arabic):
   - the grid starts at the locale's first weekday and the chevrons mirror;
   - the hour–minute pair is laid out LTR;
   - the row value is formatted by `intl` for `ar`.
9. No stock `DatePickerDialog`, `TimePickerDialog` or `showDialog` route is pushed (it is a kit sheet).
10. Under reduced motion the month change and the swap settle after one `pump()`.
11. Overflow (G6): at 320–1600 dp and 915×412, text 1.0, 1.3 and 2.0, LTR and RTL, there is no exception, and day cells are at least 48 dp at 320 dp.

## Galleries required

`test/goldens/kit/kit_date_time_picker_golden_test.dart`, at DPR 3 (TEST-9). There are 2 × 10 + 18 = 38 PNGs, under the TEST-20 cap.

- **Every declared state, dark and light, at 412×915:**
  - date;
  - date-typed;
  - date-invalid;
  - time (24-hour);
  - time-12h;
  - time-invalid;
  - date-and-time;
  - row-empty and row-set (one settings panel scene holding both);
  - row-error;
  - row-disabled.
- **The date state, dark and light, at the other sizes:** 360×800, 915×412, 800×1280, 1280×800 (a centred panel) and 1600×1000.
- **The date state at text 2.0 and in Arabic RTL, dark and light, at 412×915 and 1280×800.** The fixture date is fixed (for example 2026-10-03), never `DateTime.now()` (TEST-11).

## Non-goals

- No clock dial: time is typed entry, the accessible and keyboard-first form. See Open questions.
- No date ranges, no recurrence, and no time zones: the part returns local values.
- No week numbers or a year grid beyond what `CalendarDatePicker` offers.
- No free-text "tomorrow at 5".
- No migration of the two call sites (wave 2: shared-chat for `form_renderer.dart`, the settings unit for `notifications_settings_screen.dart`).

## Open questions

1. **Clock dial (owner; non-blocking).** The map's critics called the stock picker "familiar" and "fine", and the owner's §9 rule replaces it with a kit part. The freeze uses typed hour and minute fields with AM/PM, which is accessible, crisp and keyboard-first, and drops the Material dial. Only the owner can say whether a dial is wanted. Until he answers, the unit builds typed entry.
2. **Who commits the G1 patterns (coordinator)** `showDatePicker(` and `showTimePicker(` (KIT-2)? KIT-44 says "the unit the rule names" may add the pattern with `ratchet-tighten:`, while R05 says only kit-gates-ratchet and the integrator stage `test/kit_ratchet_baseline.json`. Proposed: the integrator adds the two patterns in the merge commit of this unit, with the three existing calls baselined.
3. **Calendar theme location (coordinator).** The calendar's theme is kit-local (see Tokens). The coordinator should confirm this is not a breach of R23, or move `datePickerTheme` into `app_theme.dart` in the kit-token seam.
