# Light glass crash and stray rectangle (F1, screenshots 61/62), 2026-09-29

Branch `revamp/slice-fix-glass-light`, merged with `feat/phone-setup-v2`.

## Cause
1. The liquid glass painted a wide gradient stroke (rim highlight) inside its backdrop-filter layer,
   and the shader ran with unclamped inputs (clamp with low > high, divide by zero size, `pow(0,y)`,
   uv outside the texture). Light theme is the variant that takes that path with the stroke on the
   brightest backdrop; the emulator's SwiftShader renderer segfaults (QEMU exit 139) on it. Real
   GPUs (Adreno/Vulkan) tolerate it.
2. The joined pill+search pair pushed its backdrop filter inside a rectangle round both shapes and the
   shader wrote a copy of the backdrop outside the shapes, which showed as a dark rectangle.

## Fix
- `shaders/kit_glass.frag`: every input clamped (bounds, size, radius, band/bend/rim/glow/tint), no
  `pow`, output clamped; outside the shapes it writes transparent, and the edge is premultiplied.
- `kit_glass.dart`: the rim highlight is a filled two-pixel sliver, not a gradient stroke.
- `kit_glass_pair.dart`: the pair's clip is the outline of the two shapes one physical pixel wider
  (a path clip), not a rectangle; nothing paints outside the glass.
- `lib/ui/kit/glass/glass_safety.dart` (new `KitGlassSafety`): liquid glass is not loaded on an
  emulated or software renderer (`getprop`: qemu, ranchu/goldfish, EGL emulation/swiftshader) and
  is turned off for 7 days after two launches in a row that died with it on screen. Real phones keep
  the look; any read failure allows liquid.

## Proof
- Emulator-5554 (Pixel_6, swiftshader_indirect, ro.hardware=ranchu), release probe
  `tool/qa/glass_probe_main.dart` (`safety=0` skips the renderer check so the glass itself is tested):
  - BEFORE (base glass files, light + liquid): the emulator died within 45 s (device gone).
  - AFTER, light + liquid: alive after 25 s and after 90 s; dark + liquid alive 40 s (clean data).
  - AFTER, safety on (default): light falls back to frosted, alive. Shots in `emulator/`.
  - Note: a second and third launch after force-stop count strikes by design, so the first dark run
    showed frosted; the clean-data run above shows liquid.
- Tests (serial): kit_glass_safety, kit_glass (both), glass_surface, app_theme, kit_ratchet,
  kit_manifest, kit_motion, golden_harness: 330 passed, 2 skipped. `flutter analyze`: no issues.
- Impeller renders `renders/before` vs `renders/after` (light/dark, Catppuccin, rest/scrolled) and
  contact sheets in this folder; look on the real-device path is unchanged apart from no rectangle.

## Not proven
Physical phone not touched. Whether the emulator crash is the stroke, the shader inputs or the
rectangle was not separated (all three fixed together).
