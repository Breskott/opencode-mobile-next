# crit/look — 2026-09-29

Slice "look" (critique §3, §4). Not gated here: coordinator runs tests and device checks. Only `flutter analyze` was run (clean).

## Done
1. Appearance: Glass effects, Celebrations and Vibration rows removed; Animations and Celebrations merged into one "Motion: Full / Calm / Off" (Full = animations + celebrations, Calm = reduced, no celebrations, Off = none). The glass crash-strike note ("Turn it back on") stays; `glass_safety.dart` untouched. Stored keys: `oc.effectsMotion` is the one setting; an old `oc.effectsCelebrations=false` with Full reads as Calm; old glass/haptics keys are ignored (glass and vibration always on); unknown or wrong-typed values read as Full. Picking Full clears the old celebrations key. Search: vibration/glass/celebrations entries removed; Motion carries the celebration aliases. Unused strings deleted from app_en/app_ar (effectsGlass*, effectsCelebrations*, effectsVibration*); "Animations" now reads "Motion".
2. Colour: tertiary `KitButton` (cancel, dismiss, inline actions) is neutral `text1` (destructive stays danger, disabled text3) in the kit, so it holds everywhere. Focus ring stays accent. Status tones and selection marks were left alone.
3. Flat ground: the ambient green/blue fields are no longer painted by `KitScreen` (`_PageFrame` in kit_screen.dart), so root tabs match sub-pages in Dark and Light. `ThemeRoles.ambient` remains defined but unused by the page frame. `main.dart` `_Ground` needed no change (it has no glow of its own).

## Files
lib/state/profiles.dart, lib/ui/kit/kit_buttons.dart, lib/ui/kit/kit_screen.dart, lib/ui/screens/settings/personal_settings_screens.dart, lib/domain/settings_search_catalog.dart, lib/ui/search/search_index.dart, app_en.arb, app_ar.arb (+ generated l10n), tests: appearance_effects_test, settings_search_rows_test, settings_search_domain_test, kit/kit_action_test.

## Skipped
Nothing. `KitEffects` keeps its glass/celebrations/haptics fields (tests and the kit still read them); they are just no longer user choices.

## Device check
Appearance page: only Light/dark, Language, Motion. Cancel/dismiss buttons neutral, green only on the primary button. Work/Inbox/Project/Settings backgrounds flat in Light and Dark. Goldens with a glow or green tertiary buttons will need regenerating.
