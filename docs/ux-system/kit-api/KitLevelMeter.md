# KitLevelMeter — API freeze (wave 0)

Unit: `kit-KitLevelMeter` (wave 1, tier 1a, kind `kit-part`, model sonnet). Spec: kit-v2.md §5 ("the voice level meter") and §9.2 (Surfaces), with cut review C16 (KitComposer's voice mode depends on it) and C30 (screen-voice-1 depends on it). Programmes: P9.9 (non-goal: no new behaviour), P10.3 (voice becomes a composer mode). Rules: KIT-1, KIT-9, KIT-12, LOOK-1, LOOK-5, LOOK-6, LOOK-14, LOOK-21, LAY-8, MOT-5, MOT-7, MOT-11, A11Y-3, PERF-4.

## Purpose

A small row of bars that moves with the microphone's input level, so the person can see the phone hears them. It is decorative: the words ("Listening 0:07") belong to its host.

## Replaces

- **Map element, 1 on 1 page:** `voice-composer-sheet#voice-composer-sheet-meter` (kit-v2.json `assignment` → `module:special surface`; note "Level bars + 'Listening 0:07 of 0:30'"). The time words stay with the host. P10.3 removes the 30 s cap and the sheet, so they are not part of the meter.
- **Code:** the private `_LevelMeter` in `lib/voice/voice_ui.dart:991-1017`:
  - 9 `Container` bars;
  - `colorScheme.error` lit and the same colour at 20 % alpha unlit (LOOK-5: red is only for an act that destroys or stops; LOOK-1: no alpha on a role);
  - `BorderRadius.circular(4)`, and widths, heights and margins as literals.
  - The file is not in G16 today (the scan skips `lib/voice`, C21 (a)); screen-voice-1 adopts the part.
- **Adopters:** screen-voice-1 (wave 2b restyles the voice sheet) and kit-KitComposer (the voice mode's field slot, C16).

## File

- `lib/ui/kit/kit_level_meter.dart` (new): `KitLevelMeter`.
- Tests: `test/kit/kit_level_meter_test.dart`.
- Gallery: `test/goldens/kit/kit_level_meter_golden_test.dart`.

## Public API

```dart
/// The microphone's input level as bars. Decorative: excluded from
/// semantics; its host says "Listening" in words.
///
/// States: listening (lit to the level), quiet (listening, nothing lit),
/// paused (not listening: every bar at rest).
class KitLevelMeter extends StatelessWidget {
  /// The host rebuilds it with each new level (today's voice sheet).
  const KitLevelMeter({
    super.key,
    required double this.level,  // 0..1, clamped; NaN reads as 0
    this.active = true,          // false: the mic is not listening (paused, transcribing)
    this.meterKey,
  }) : listenable = null;

  /// Repaints on each new level without rebuilding the host (the composer
  /// field at ~30 updates a second; PERF).
  const KitLevelMeter.listen({
    super.key,
    required ValueListenable<double> this.listenable,
    this.active = true,
    this.meterKey,
  }) : level = null;

  final double? level;
  final ValueListenable<double>? listenable;
  final bool active;
  final Key? meterKey;

  /// How many bars a level lights: bar i (0-based) is lit when
  /// level >= (i + 1) / 12, as today, so a normal voice lights about half
  /// and a shout lights all nine at 0.75.
  static int litFor(double level);
}
```

- **No styling parameters:** the bar count, sizes, gap and colours are tokens. The meter has an intrinsic size, and the host centres it.
- **No copy of its own.**

## States

| State | What paints | Notes |
|---|---|---|
| listening | `litFor(level)` bars in `accent`, the rest in `surface3` | lights from the start edge |
| quiet | listening with level below 1/12: every bar in `surface3` | the host's words still say "Listening" |
| paused | `active: false`: every bar in `surface3` whatever `level` says | so the meter never moves while the mic is off |

It has no loading, empty, error, working or answered state; the host owns those (downloading a voice pack, transcribing, mic denied). There is no disabled state: a meter is not interactive. KIT-12 doc comment: "States: listening, quiet, paused (decorative; not interactive)".

## Tokens

- **ThemeRoles:** `accent` for lit bars (LOOK-6: a working mark), `surface3` for unlit bars. The meter uses no `danger`, `attention` or alpha.
- **KitText:** none.
- **KitTokens:** `space1` (4, the gap between bars).
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitTokens.meterBars` = 9;
  - `KitTokens.meterBarWidth` = 6 (snapped to whole physical pixels);
  - `KitTokens.meterBarMin` = 12 and `meterBarMax` = 20: bar heights run from the centre bar (min) to the end bars (max) in whole steps, today's "V";
  - the corners are the pill shape (`KitShape.pill`, LOOK-19 "999").

  So the intrinsic size is 9 × 6 + 8 × 4 = 86 by 20 dp, which fits the composer's 24 dp field line.

## Adaptive

- **Identical at every window class** (compact, medium, expanded, large): it is an 86 × 20 dp mark that its host places (centred under the voice sheet's status, or in the composer's field slot on every window).
- **Short windows:** unchanged.
- **Pointer and keyboard:** not focusable, no hover. It is not a control (LAY-10 has nothing to reach).

## Accessibility

- **Excluded from semantics:** a level has nothing to say that the host's "Listening 0:07" does not (LOOK-38 by analogy; A11Y-3: the host's line announces the change once).
- **No touch target:** it is not a control, so the 48 dp rule does not apply.
- **200 % text:** fixed size. It is a graphic, not text, and it never overflows its host's line at 320 dp.
- **Colour alone is fine here:** the meter is decoration beside words that say the state (STATE-9 is met by the host's words).

## RTL

- **Bars light from the start edge:** left in English, right in Arabic. Progress direction mirrors (LAY-8).
- **The shape is symmetric,** so nothing else flips.

## Motion and haptics

- **A new level repaints at once:** no tween, no `AnimationController`, no `Ticker`. It is data, not motion, so reduced motion changes nothing and the part settles after one `pump()` (G8, MOT-7).
- **Paint only:** the bars are one `CustomPaint` in its own `RepaintBoundary`, so a 30 Hz level never lays out its host (MOT-5).
- **No haptics** (MOT-11).

## Data safety and honest state

- **The meter holds one number**, never audio, and keeps nothing between frames.
- **It is honest about the microphone:** with `active: false` it never lights, so it cannot suggest the phone is listening when it is not. The host passes `active: controller.state == listening`.
- **Levels outside 0..1 or NaN are clamped,** so bad input never paints a broken meter.

## Depends on

- **Existing:** `KitTokens`, `ThemeRoles`, `KitShape` (the pre-wave seam enum in `kit_tokens.dart`, see KitSurface.md).
- **Pre-wave seam:** `KitTokens.hairlineWidth` is not used. Bars snap to whole physical pixels with `(v * dpr).round() / dpr`.
- **No wave-1 dependency** (tier 1a).

Depended on by: kit-KitComposer (voice mode, C16), screen-voice-1 (C30).

## Tests required

In `test/kit/kit_level_meter_test.dart`:

1. **Lit count:** `litFor(0) == 0`, `litFor(.5) == 6`, `litFor(.75) == 9`, `litFor(1) == 9`, `litFor(-1) == 0`, `litFor(double.nan) == 0`.
2. **Paused:** with `active: false, level: 1` no `accent` pixel is painted (a painted-colour scan of `toImage`).
3. **Direction:** at `level: .5` the lit bars are the six at the left in LTR and the six at the right in RTL.
4. **Colours:** no `danger` or `attention` colour is painted in any state, and every painted colour is an opaque `ThemeRoles` role.
5. **Crisp:** at DPR 3 every bar's left edge, width and height are whole physical pixels.
6. **Listen:** `KitLevelMeter.listen` repaints on a `ValueNotifier` change without rebuilding its parent (a build counter on the parent stays at 1 across 10 changes).
7. **Semantics:** the meter adds no semantics node.
8. **Motion:** under reduced motion and normally, no ticker is active after one `pump()` (G8).
9. **Overflow:** inside a 24 dp line at 320 dp wide, at text 2.0, RTL: no overflow (G6).

## Galleries required

`test/goldens/kit/kit_level_meter_golden_test.dart`, DPR 3, Android. The scene is the meter centred on a `surface2` panel under a "Listening 0:07" label. That label is a gallery fixture, so the meter is seen in context.

- **Declared states × dark and light at 412×915:** `listening_low` (0.2), `listening_high` (0.9), `quiet` (0), `paused`. That is 8 PNGs.
- **Default (`listening_high`) × dark and light** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000: 10 PNGs.
- **Text 2.0 and Arabic** (`listening_high`) at 412×915 and 1280×800, dark: 4 PNGs.
- **Names:** `kit_level_meter_<state>[_ar][_text2][_WxH]_<dark|light>.png`. That is 22 PNGs.

## Non-goals

- **No time display, cap, stop button or microphone state:** those belong to the voice sheet, or to the composer's voice mode (P10.3).
- **No audio processing:** no smoothing, no peak hold, no new level mapping (P9.9). `level` arrives already computed from `audio.level`.
- **No adoption** in `voice_ui.dart` or the composer here.

## Open questions

None.
