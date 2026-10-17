# KitFactRow — API (2026-10-11)

Unit: FactsBook fact and search hit (spec 60 sections 4-5, G7, G31; D25: every recalled fact shows its source and date). Rules: KIT-1, KIT-12, LOOK-1, LOOK-5, G17, G20 (bidi-safe values).

## Purpose

Shows one remembered fact, or one search hit, with where it came from and when. The border (solid, plain, dashed) and an icon repeat the provenance, but the word is always there: colour and line style never carry it alone. "From a source" means read from it, not true.

## File

`lib/ui/kit/kit_fact_row.dart`: `KitFactRow`, `KitProvenance`. Tests: `test/kit/kit_fact_row_test.dart`. Gallery: `test/goldens/kit/kit_fact_row_golden_test.dart`.

## API

```dart
const KitFactRow({
  required String text,
  required KitProvenance provenance,   // told | seen | guessed | calculated
  required DateTime observedAt,
  String? source,                      // plain words: "a shared message"; null for told
  String? title,                       // a hit's thing ("Dentist"), above the text
  bool waitingForOk = false,           // a guess the person has not approved
  List<KitAction> answers = const [],  // up to two, under the line ("Yes, keep it", "Not right")
  VoidCallback? open,                  // a hit opens its thing; null is a row you read
  String? semanticsLabel,
  Key? tappableKey,
});
static String lineOf(...);             // "You told it · Oct 3"
static String isolateValues(String text, {required bool rtl});
```

## Look

- A panel-radius card on `surface1`, gutter on both sides. Text in `body`; the line under it in `caption`, `text2`, led by a 16 dp icon (check, bookmark, spark, function).
- told: solid 1.5 dp `accent` border, "You told it · date". seen: solid 1 dp `hairline`, "From <source> · date". guessed: dashed 1.5 dp `text2`, "It guessed · date" (+ "from <source>"), and "· waiting for your OK" while it waits. Never amber (G17: amber is Needs you only).
- Dates: "Oct 3" in the current year, "Oct 3, 2025" before, in the person's language.
- Right-to-left: amounts, `••42` card endings, `[AMOUNT] CUR`, times and addresses inside the text are isolated left to right with LRI/PDI marks (`isolateValues`); the source name is isolated as a whole. In left-to-right layouts the text is shown as written.
- At large text everything wraps; nothing is clipped. A hit with `open` is one `KitTappable` target; its sentence reads "title. text. word. line".

## Copy

`kitFact*` in `lib/l10n/app_en.arb` / `app_ar.arb`: the four words, the lines and the waiting suffix. The Arabic words come from the canvas Home-AR ("قلت ذلك", "خمّنه النظام"); the owner confirms the glossary.

## States

None of its own (KIT-12): told, seen, guessed and calculated, waiting and answered are the data it is given.
