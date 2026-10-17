# Micro animations, kit-wide pass (2026-10-15)

Branch `feat/micro-animations`. Rules kept: 150 ms (`KitMotion.quick`), `KitMotion.enter`,
no scale or bounce, instant under `KitMotion.reduced` (system setting or Animations: Off),
cross-fades through the existing `KitSwap`, cheap implicit animation, composer glow untouched.

## Inventory

Most of the kit already moved before this pass. Checked and left alone because they animate today:
KitChip / KitFilterChip(s) (selected fill, leading swap, chevron), KitStatusMark (glyph cross-fade),
KitStatusSlot, KitNotice host (`KitReveal`), KitSegmented (thumb and label), KitChoiceRow marks,
KitSwitchRow (platform switch), KitButton (busy swap, spinner slot), KitField error line,
KitStateView, KitNav / tab lens, KitJumpPill, KitProgress(Row), KitTopBar (title, actions, server
name, chevron), KitExpandRow / KitDetailsFold (`KitReveal`), KitChecklist and board lanes
(`KitAnimatedRows`), KitTappable (press / hover fill).

| Part | Before | After | ms |
|---|---|---|---|
| KitStatusTag | tone or word changed in one frame (Running to Done) | cross-fades | 150 |
| KitRowValue (value) | new value text popped | cross-fades | 150 |
| KitRowValue.count | badge appeared, changed number, vanished in one frame | cross-fades | 150 |
| KitRow trailing | chevron, spinner, check, word swapped in one frame when the kind changes | cross-fades (keyed by key or type) | 150 |

Skipped, with reasons:
- KitRow selected fill: KitTappable already animates its own fill; a second animated box on every
  row would add a paint layer to each list row (60 fps cost) for a rare change.
- KitRow supporting line: often a live clock ("5 min ago"); a cross-fade every tick would be noise.
- KitSectionLabel, KitLastKnown label, KitChip label text, KitLevelMeter (painted live by level),
  KitFloatingAction (its host decides when it exists): no pop that a kit part owns.
- Sheet content swaps: size animation is banned in the kit except through `KitReveal` (MOT-5);
  no sheet swaps content without a part today.

## Tests

`test/kit/kit_micro_animations_test.dart`: per change, the two states are both in the tree 50 ms
in (fade layers above the settled count), the old one is gone when settled, and under reduced
motion one pump shows only the new state with no leftover fade layer.
`kit_motion_test` and `kit_ratchet_test` pass.

## Frame strips

`frames/<change>_{0,50,100,200}ms.png`, rendered by that test with `MICRO_STRIP_DIR=<dir>`
(status tag, row value, row count badge, row trailing mark).

## Extra scope from the coordinator (APK 2316 emulator findings)

| Item | Verdict | Change |
|---|---|---|
| Hard edge above the composer | REAL | `kit_composer_layer.dart`: the composer band and the band over it paint nothing; the transcript is clipped at the band's top edge so nothing shows behind the chips. Pill and glow unchanged. Tests in `test/kit/kit_composer_test.dart`. |
| Appearance "Look" row is a huge icon | FALSE as described | The big green drawing is `_EffectsPreview` (the motion preview illustration, first child of the Effects group), not the Look row. The Look row is a normal `KitRow` with title and "Aurora drift" value further down. Left as is; if the preview is too big or unwanted, that is a separate owner call. |
| Chat project line 16 dp right of title, title too high | REAL | `kit_top_bar.dart`: the scope line has no start padding (glyph on the title edge); title gets `space2` top room when a scope line is shown. Test in `test/kit_top_bar_declutter_test.dart`. |
