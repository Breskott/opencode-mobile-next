# Effects card: live sample of the chosen look (2026-10-15)

Settings > Appearance > Effects used to open with a large static drawing (the
old motion-preview illustration) that filled the top of the card and pushed the
Look row down. It is now a short live tile (108 dp, full row width) of the
chosen look behind two mock chat lines.

Behaviour (`lib/ui/kit/kit_live_look_preview.dart`, `KitLiveLookPreview`):

- Shows the person's look and Intensity; Live background off gives the flat
  ground and a quiet "Off".
- Tapping it opens the look picker, like the Look row.
- A change of look, Intensity or the switch cross-fades (250 ms, none under
  reduced motion).
- Reduced motion, Calm, Off: a still frame (KitLiveBackground). It also rests
  while scrolled out of view (TickerMode off).
- Copy: `effectsLookPreviewLabel`, `effectsLookPreviewOffLabel`,
  `effectsLookPreviewOff` (en, ar).

Tests: `test/kit/kit_live_look_preview_test.dart` (kit part, reduced-motion
registration, cross-fade, scroll rest), `test/appearance_effects_test.dart`
("a live sample of the chosen look heads the card", fails without the change),
goldens `test/goldens/kit/kit_live_look_preview_*` and
`test/revamp/goldens/settings_appearance_loaded_*`.

Evidence (phone size, one screen each; "after" paints a frozen frame of the
look, regenerate with `tool/capture/effects_preview_test.dart`):

| | Before | After |
|---|---|---|
| Dark | before-dark-top.png | after-dark-top.png |
| Light | before-light-top.png | after-light-top.png |
| Emulator, before | before-emulator.png | |

The look is intentionally subtle at Normal intensity (the page behind it runs
the same look), so the tile reads as a calm field with the mock lines.
