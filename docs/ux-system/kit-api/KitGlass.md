# KitGlass: fluid glass on the floating navigation layer

Unit: `kit-fluid-glass` (2026-09-28, branch `revamp/kit-fluid-glass`). Spec: the owner's approved "Fluid glass" motion sample (artifact `UH4zkQzgLQMHSiB4AExMyV`, visual language §6 proposal), design standard §10 (glass), STANDARDS LOOK-21, LOOK-22, LOOK-27, LOOK-29, MOT-1, MOT-2, MOT-5, MOT-7, MOT-8. Before this unit KitGlass had no spec of its own; the looks are recorded in `docs/qa/liquid-glass-2026-09-25/README.md`.

## Purpose

`KitGlass` is the one glass part: a bounded surface floating over scrolling content. Owner rules: glass **only** on the floating navigation layer (the dock, the rail, the top controls, the composer), "very very sharp and crisp" (no blur mush; a one-physical-pixel rim; the edge is a clip or an analytic one-pixel edge, never a soft glow), adaptive phone / tablet / PC, and it must read on the Graphite default and on every theme pack the person picks.

This unit makes the glass move like liquid, as the sample shows, without changing any layout:

| Sample step | Here |
|---|---|
| The tab lens stretches: tap a tab and the lens leads with its front edge, stretches, and settles; drag along the bar and it lifts out of the bar and follows the finger | `KitNav` dock and rail (`_KitNavItems`): the lens's two edges ride separate springs (`KitMotion.lensLead` / `lensTrail`; while dragged `lensDragLead` / `lensDragTrail`), the lens thins a little while stretched, lifts (grows `space2` and its hairline turns `glassRimLight`, `KitMotion.lensLift`) under a finger, and opens the destination it is let go on |
| Glass gives when pressed: swells slightly, brightens, springs back | `KitGlass(respond: true)` (dock, rail, server pill, search): the drawn glass swells up to `GlassGeometry.swellMax` (4 dp) a side (3.5 % of its size, half that vertically), the liquid shader's `u_glow` lifts the tint and the rim, `KitMotion.glassPress` springs it back. The content is never scaled (labels stay on the pixel grid) |
| Search joins the server pill as the list scrolls, like drops; scroll back to the top and they pull apart | `KitGlass.pair` in `KitShellControls` (bar layout): while the page under `KitNav` is scrolled past one `minTarget` (`KitGlass.trackScroll` / `scrolledOf`) search slides next to the pill, becomes the smaller drop and the two melt together (`KitMotion.glassJoin`); a new tab starts apart |
| The composer grows as you type, line by line, instead of jumping | `KitGlass(flow: true)`: the glass follows its box's new size from the old one, growing from its bottom edge (`KitMotion.glassFlow`). The composer lives in the chat library; see "Call-site change" |

## File

- `lib/ui/kit/glass/kit_glass.dart` — `KitGlass`, `KitGlassLook`, `KitGlassShader`, the scroll scope; part `kit_glass_pair.dart` (the joined pair).
- `lib/ui/kit/glass/glass_geometry.dart` — `GlassGeometry`: the drawn shape (press, flow) that the clip, the decoration, the rim and the shader all read.
- `lib/ui/kit/glass/liquid_glass_filter.dart` — `LiquidGlassFilter` / `RenderLiquidGlass`, `GlassLens` (the shader's uniforms), `GlassShaders` (two shaders from the one program, used in turn), `GlassBackdropTracking` (where the glass is on the backdrop, and the after-frame watch).
- `shaders/kit_glass.frag` — one program: one clipped surface, or two joined surfaces with an analytic edge.
- `lib/ui/kit/kit_motion.dart` — the spring tokens.

## Public API

```dart
class KitGlass extends StatefulWidget {
  const KitGlass({
    Key? key,
    required Widget child,
    BorderRadius? borderRadius,   // null: KitTokens.navRadius (22)
    bool shadow = true,           // the one glassShadow (y 6, blur 16)
    bool dim = true,              // glass that holds words: surface2 at 88 %
    bool respond = false,         // gives under a finger
    bool flow = false,            // follows a size change from the old size
  });

  /// Two pieces in one row drawn as one surface; joined, the trailing piece
  /// slides next to the leading one and they melt together like drops.
  const KitGlass.pair({
    Key? key,
    required Widget leading,
    required Widget trailing,
    bool joined = false,
    BorderRadius? borderRadius,
    bool shadow = true,
    bool dim = true,
    bool respond = true,
  });

  static Color foregroundColor(ThemeData theme);
  static bool reduceEffects(BuildContext context);
  static KitGlassLook lookOf(BuildContext context);

  /// Watches vertical scrolling under [child]; [resetOn] (the selected
  /// destination) starts again at the top. KitNav puts it around the page.
  static Widget trackScroll({required Widget child, Object? resetOn});

  /// Whether the page under the nearest trackScroll is scrolled past one
  /// minTarget; false without one.
  static bool scrolledOf(BuildContext context);
}

enum KitGlassLook { liquid, frosted, solid }

abstract final class KitGlassShader {
  static final ValueNotifier<ui.FragmentProgram?> program;
  static bool? debugSupportedOverride;
  static bool get supported;
  static const asset = 'shaders/kit_glass.frag';
  static void ensureLoaded();
  static void debugReset();
}

// KitMotion (lib/ui/kit/kit_motion.dart), per unit mass, dp and seconds:
static const SpringDescription lensLead;      // stiffness 560, damping 32
static const SpringDescription lensTrail;     // 210, 23
static const SpringDescription lensDragLead;  // 700, 36
static const SpringDescription lensDragTrail; // 260, 26
static const SpringDescription lensLift;      // 260, 20
static const SpringDescription glassPress;    // 380, 15
static const SpringDescription glassJoin;     // 170, 17
static const SpringDescription glassFlow;     // 300, 26
```

The spring values are the sample's own (its `Spring(x, k, c)` integrates the same equation in px and seconds).

## States

None — a surface around its child; it holds no data. Looks (`KitGlassLook`), unchanged by this unit:

| Look | When | Draws |
|---|---|---|
| liquid | Impeller, shader loaded, Glass on, no accessibility override | `kit_glass.frag` over a light frost (σ 5, was 8: crisper), clipped by the drawn shape; one-physical-pixel shader rim plus the painted rim |
| frosted | Skia, or before the shader has loaded | blur σ 12, `surface2` at 82 / 88 %, painted rim |
| solid | Glass off; or high contrast, accessible navigation, remove animations | `surface2` at 94 % (opaque under the accessibility settings) with the hairline rim, no shadow |

## Motion rules

- Only the drawn shape moves: `GlassGeometry` (press, flow) and the pair's own layout of where each piece is painted. The clip, the fill and shadow (`_GlassDecoration`, a `BoxDecoration` painted along the drawn shape), the rim and the shader read it and **repaint**; nothing rebuilds, the content is never scaled (MOT-2: no scale transition; G21 bans `Transform.scale`), and no list relays out (MOT-5). The lens is laid out alone (`CustomSingleChildLayout`, a relayout boundary).
- Springs come only from `KitMotion` (MOT-1). The lens's springs are stepped on one ticker so a dragging finger moves their targets every frame without restarting them.
- Reduced motion (`KitMotion.reduced`: the system's remove animations or Animations: Off): every state is instant — no swell, no flow, the pair joins and parts at once, the lens jumps and follows a drag directly without lifting; no ticker runs (MOT-7).
- Glass off and the accessibility settings: solid glass never moves (no press, no flow); the pair still joins, as one solid outline with its hairline.
- Edges land on physical pixels at rest (the press and flow controllers end exactly at their targets; the lens rounds its edges to device pixels), so the rim is a crisp single pixel.

## Performance

- The shader program is compiled once, when it loads (`KitGlassShader`); a moving glass only sets uniforms on one of two shader instances (`GlassShaders`), so there are no per-frame shader compiles.
- One surface: two texture reads per pixel. The joined pair: eight (a centre-and-six-tap frost plus dispersion) over the small top controls only, and the backdrop is read once for all glass under `KitNav`'s `BackdropGroup`.
- `test/kit/kit_glass_test.dart` "60 fps budget": during a lens spring and a held press no glass or navigation widget rebuilds, and the whole shell's frames stay well under 16 ms on the test host (recorded in the QA record).

## Adaptive

- compact: the dock (lens on a horizontal track, horizontal drag) and the top controls in one row (the pair).
- medium: the rail (vertical track, vertical drag) and the same top controls.
- expanded / large: the sidebar is solid (no lens, no glass rows); its header's pill and search are `KitGlass(respond: true)` stacked; they do not join (nothing scrolls under a sidebar header).

## Accessibility

- A drag is an extra for touch; every destination keeps its own tap, focus and semantics (the drag detector is excluded from semantics). The joined search keeps its label and its place in reading order; a screen reader is told where it moved.
- Screen reader, high contrast and remove animations make glass solid and still (LOOK-29).

## Call-site change (chat lane, not made here)

The composer is `lib/ui/kit/chat/kit_composer.dart` (chat lane P3.6). To have it flow as the sample shows, its one `KitGlass` gains `flow: true`:

```dart
child: KitGlass(
  borderRadius: BorderRadius.circular(radius),
  dim: true,
  shadow: true,
  flow: true, // fluid glass: grows line by line from its bottom edge
  child: Padding(...),
),
```

Nothing else changes: the composer's layout and `KitBottomInset` height still update at once; only the glass follows. `KitComposer.layer` needs no change.

## Tests

- `test/kit/kit_glass_test.dart` (behaviour): press swell and spring back, reduced motion and glass off still; flow from the old size on the bottom edge; the pair joining, tappable where it now is, instant when reduced, solid outline when off; the shell joining on scroll and parting at the top and on a new tab; the lens stretching and settling, the drag lift and select on the dock and the rail, reduced-motion drag; a finger lifted after the glass (or the pair) left the screen is ignored; the frame budget.
- `test/kit_glass_test.dart` (looks, unchanged), `test/glass_surface_test.dart` (contrast on every theme pack, unchanged), `test/kit/kit_nav_test.dart`, `test/kit/kit_top_bar_test.dart` (the shell's controls are one dim pair).

## Galleries

`test/goldens/kit/kit_glass_golden_test.dart`: the shell at the five §8.4 sizes, light and dark, and with 2.0 text at 412×915 and 1280×800; motion samples at 412×915 (`kit_glass_lens_stretch`, `kit_glass_lens_lift`, `kit_glass_pressed`, `kit_glass_joining`, `kit_glass_joined`, `kit_glass_flow`) `kit_glass_solid`, and `kit_glass_joined_catppuccin` (a theme pack the person picks; contrast on every pack stays in `test/glass_surface_test.dart`). The liquid look needs Impeller: `flutter test --enable-impeller tool/capture/fluid_glass_test.dart` writes renders into the unit's QA record.

## Non-goals

- Glass anywhere but the floating navigation layer (sheets, cards, rows, the PC toolbar stay solid).
- A second glass layer for the lens (glass never sits on glass, VL §6): the lens stays a clear pill with a hairline, now moving like the sample's.
- Magnifying content inside the lens (the sample's lens refraction): it would put glass on glass and scale content under a label.
