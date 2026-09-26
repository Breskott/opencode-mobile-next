# KitImage, KitAvatar, KitZoom: API freeze (wave 0)

Unit: `kit-KitImage` (kind `kit-part`, tier 1a; cut review C13). Spec for `revamp.workflow.js`. kit-KitViewer and kit-KitComposerChips depend on it (C25).

## Purpose

This unit provides three parts:
- **KitImage** draws a raster image sharply. It is decoded at the device pixel ratio for its laid-out size and filtered at high quality (VL §7, LOOK-35), clipped to a token shape, and has honest loading and failure states and a required choice between a semantic label and "decorative".
- **KitAvatar** is the one identity mark: an image or icon, falling back to initials on `surface3`, always named, and never coloured by identity.
- **KitZoom** is the one pinch, pan and zoom viewer, with visible zoom controls and keyboard zoom.

## Replaces

- **G16 baseline:** 13 in 11 files.
  - `Image` 5:
    - `chat/composer.dart:1501` (attachment preview);
    - `file_preview.dart:401`;
    - `pdf_file_preview.dart:205`;
    - `tool_card.dart:2136`;
    - `provider_logo.dart:67` (a network favicon).
  - `CircleAvatar` 4:
    - `builtin_server_screen.dart:834` and `termux_setup_screen.dart:2980` are numbered steps; they go to `KitChecklist`, not here;
    - `server_switcher_sheet.dart:312` (a server icon) → `KitAvatar(icon:)`;
    - `guide_screen.dart:249`.
  - `InteractiveViewer` 4: `file_preview.dart:396`, `pdf_file_preview.dart:200`, `svg_file_preview.dart:101` and `team/work_graph.dart:433` (canvas mode).
- **Classes it makes redundant** (their files are outside this write set, so the owning units move the callers and the last one deletes the classes, KIT-43):
  - `ProviderLogo` and `ProviderMonogram` (`lib/ui/widgets/provider_logo.dart`) → `KitAvatar(image: KitImageSource.provider(...), name:)`. The favicon URL stays app-authored in `api/provider_presentation.dart` and reaches the kit as an `ImageProvider`.
  - `BrandTile` → `KitSurface.tile` / `KitAvatar`.
- **Not here:**
  - `QrImage` → `KitQr`.
  - SVG and PDF rendering → `KitViewer`, which puts its pages inside `KitZoom`.
  - The `TweenAnimationBuilder` fade-in in `provider_logo.dart:79` is KitImage's own loaded cross-fade.
- **kit-v2.json `assignment`:** no element is assigned.

## File

`lib/ui/kit/kit_image.dart` (new), holding `KitImage`, `KitAvatar` and `KitZoom`. The write set is that file, `test/kit/kit_image_test.dart` and `test/goldens/kit/kit_image_golden_test.dart`.

## Public API

```dart
/// Where the pixels come from. There is never a raw URL string: a network
/// image arrives as an ImageProvider built by a service that authored its URL
/// (the favicon service) or that fetches through the gateway (attachments).
sealed class KitImageSource {
  const factory KitImageSource.memory(Uint8List bytes) = _MemorySource;
  const factory KitImageSource.asset(String name) = _AssetSource;           // bundled raster only
  const factory KitImageSource.provider(ImageProvider provider) = _ProviderSource;
}

enum KitImageFit { contain, cover }

class KitImage extends StatelessWidget {
  /// [semanticsLabel] is required and may be null, so every call site decides
  /// between a named image and a decorative one.
  const KitImage({
    Key? key,
    required KitImageSource source,
    required String? semanticsLabel,
    KitImageFit fit = KitImageFit.contain,
    KitShape shape = KitShape.square,   // pre-wave seam enum; clips the image and its states
    double? width,                      // layout size; null: the incoming constraints
    double? height,
    Widget? fallback,                   // shown instead of the failure state (e.g. KitAvatar's initials)
    Key? imageKey,
  });
}

enum KitAvatarSize { tile, mark } // KitTokens.iconTileSize (30) · KitTokens.markSize (44)

class KitAvatar extends StatelessWidget {
  /// An image or icon when given, otherwise the initials of [name] (the first
  /// grapheme of its first two words, upper-cased where the script has case)
  /// in text1 on surface3. [name] is always the semantic label. The colour
  /// never encodes identity.
  const KitAvatar({
    Key? key,
    required String name,
    KitImageSource? image,       // falls back to the initials while loading and on failure
    IconData? icon,              // an AppIconography glyph instead of initials (a server, the phone)
    KitAvatarSize size = KitAvatarSize.tile,
    bool decorative = false,     // true when the row beside it already says [name]
  });
}

enum KitZoomMode {
  fit,    // the child fits the view at 1×; zoom in to maxScale; pan only while zoomed (images, pages)
  canvas, // the child is larger than the view; pan freely within it, zoom out to fit (the work graph)
}

/// Drives a KitZoom from its host (the work graph's Fit on open and its
/// keyboard zoom). [value] is the current transform, for tests.
class KitZoomController extends ChangeNotifier {
  KitZoomController({TransformationController? transformation}); // wraps a host's controller when it has one
  Matrix4 get value;
  void reset();   // the start view: 1× in fit mode; the whole child fitted in canvas mode
  void zoomIn();
  void zoomOut();
}

class KitZoom extends StatefulWidget {
  const KitZoom({
    Key? key,
    required Widget child,
    required String label,       // what is being viewed: "Screenshot.png", "Work graph"
    KitZoomMode mode = KitZoomMode.fit,
    bool controls = true,        // the visible twin of pinch: zoom out, reset ("Fit to screen" in canvas mode), zoom in (A11Y-5)
    Object? resetKey,            // a change resets to the start view (a new page, a new file)
    KitZoomController? controller,
    Key? zoomKey,
    Key? resetControlKey,        // the reset / Fit control (the work graph keeps team-work-graph-fit)
  });

  static const double maxScale = 5;   // behaviour constants, not look tokens
  static const double minScale = 0.2; // canvas mode: the smallest fit
}
```

**Behaviour, frozen.**
- **Decode size.** `cacheWidth = (laidOutWidth × devicePixelRatio).round()`, or `cacheHeight` when height bounds it, applied through `ResizeImage.resizeIfNeeded`. With unbounded constraints and no `width` or `height`, the image decodes at its intrinsic size, capped at 4,096 device px on the longer side. The filter is `FilterQuality.high` and never lower, whatever the source.
- **Source change.** The old frame stays up only while the new one loads (gapless). If the new one fails, the failure state shows, never the old image.
- **KitZoom input:**
  - pinch and trackpad scale; Ctrl+wheel zooms at the pointer;
  - double-tap toggles between 1× and 2× at the tap point;
  - keys, once focused: Ctrl+= zooms in, Ctrl+− zooms out, Ctrl+0 resets, and the arrows pan while zoomed;
  - `controls` shows three `KitIconButton`s (zoom out, reset, zoom in; the existing v1 API) on a `surface2` pill at the bottom end, each 48 dp and 8 dp apart.
  - **Canvas mode fits on open:** in the first post-frame callback the child is fitted to the view (scale ≤ 1 and ≥ `minScale`, centred), which is the start view `reset` returns to; the reset control is labelled "Fit to screen" (`kitZoomFit`). This is the job KitWorkGraph's own pill did (KitWorkGraph.md, README.md decision D17), so the kit has one zoom part.
- **Kit copy** (ARB, `kit` prefix, en and ar): `kitImageUnavailable` "Can't show this image", `kitZoomIn` "Zoom in", `kitZoomOut` "Zoom out", `kitZoomReset` "Reset zoom", `kitZoomFit` "Fit to screen", `kitZoomAtStart` "Already at full view", `kitZoomAtMax` "Largest zoom", `kitZoomLevel` "{percent} %". KitWorkGraph and KitViewer reuse these (COPY-18).

## States

- **KitImage:**
  - **loading:** a static fill of `surface2` in `shape`. There is no spinner and no shimmer (a calm instrument), and no 8 s escalation, because an image is not a wait the person started. A slow file is the host `KitViewer`'s `KitStateView` with `since`.
  - **loaded:** the first frame cross-fades in, unless it loaded synchronously.
  - **failed:** a `surface2` fill with the `imageBroken` glyph (20, `text2`). From 120 dp wide it also shows the words "Can't show this image" (`kitImageUnavailable`). Or it shows `fallback`.
  - Empty and disabled do not apply.
- **KitAvatar:** image, icon, or initials. A failed or loading image shows the initials, so the slot is never empty.
- **KitZoom:**
  - **at rest (1×):** reset is disabled with the reason "Already at full view" (`kitZoomAtStart`); zoom out is disabled in `fit`.
  - **zoomed.**
  - **at max:** zoom in is disabled with the reason "Largest zoom" (`kitZoomAtMax`).

## Tokens

- **ThemeRoles:** `surface2` (placeholder, failure, controls pill), `surface3` and `text1` (initials), `text2` (failure glyph and words).
- **KitTokens:** `shapeOf(shape)` (pre-wave seam), `iconTileSize` (30), `markSize` (44), `smallIconSize` (20), `space2`, `minTarget` (48).
- **KitText roles:** `label` (initials at tile size), `headline` (initials at mark size), `secondary` (the failure words).
- **KitMotion:** `quick` (the loaded cross-fade), `standard` with `enter` (animated reset and double-tap zoom).
- **New token (pre-wave `kit_tokens.dart`, `_new-tokens.md`):** `KitTokens.monogramMaxTextScale` (1.3). The initials in a fixed-size avatar clamp to it, a named clamp with a reason, as A11Y-8 requires ("badges and counts"). Without it the initials overflow the circle at 2.0 text.

## Adaptive

- **KitImage and KitAvatar:** the same on every window. Their size comes from the layout and is decoded per window.
- **KitZoom:**
  - **compact and medium:** pinch, double-tap, and the controls pill at the bottom end.
  - **expanded and large:** the same, plus Ctrl+wheel zoom at the pointer, a grab cursor while zoomed and panning with a fine pointer, keyboard zoom, and a `KitIconButton` tooltip with each control's shortcut ("Zoom in · Ctrl+=").
  - The controls never shrink below 48 dp (§8.3).

## Accessibility

- **KitImage:** with `semanticsLabel` it is an image node; with null it is excluded. The failure state's words are read.
- **KitAvatar:** an image node labelled `name` unless `decorative`. The initials themselves are excluded, so a screen reader reads "Anthropic", not "A N".
- **KitZoom:**
  - one node labelled `label` with the value "200 %" (`kitZoomLevel`, formatted with `intl`);
  - custom actions "Zoom in", "Zoom out" and "Reset zoom";
  - the controls are labelled KitIconButtons;
  - it is focusable to take the keys (a Tab stop).
- **200 % text:** image sizes do not change; the initials clamp at `monogramMaxTextScale`; the failure words wrap to two lines, then the glyph alone shows.
- **Contrast:** initials `text1` on `surface3` meet 7:1 (LOOK-8).

## RTL

- The controls pill sits at the bottom end (the left under Arabic). The order is zoom out, reset, zoom in in reading order.
- Images are never mirrored.
- Arabic initials use the first grapheme of each word, without case.
- No left or right literals (G7).

## Motion and haptics

- **KitImage:** the first frame cross-fades on `KitMotion.quick`. Under reduced motion, or when loaded synchronously, it shows at once. There is no fade-scale (MOT-2).
- **KitZoom:** reset and double-tap animate on `KitMotion.standard` with `enter`. Under reduced motion they jump. Pinch follows the fingers.
- **Haptics:** none (MOT-11).

## Data safety and honest state

- **No raw URLs.** KitImage never takes a URL string, so a server-sent value can never make the app fetch an arbitrary host. Network images come only as an `ImageProvider` from a service that authored the URL or fetches through the gateway (SEC and AGENTS.md link rules).
- The failure state is shown instead of a stale or blank image, and loading is never shown as loaded.
- Memory is bounded by decoding at the displayed size, with the 4,096 px cap for unbounded images.
- KitAvatar's colour does not identify anyone. Identity is the name (STATE-9: never colour alone).
- KitZoom never changes the underlying file.

## Depends on

- The VL merge (`ThemeRoles`, `KitTokens`, `KitText`).
- The pre-wave `KitShape` / `shapeOf` and the new `monogramMaxTextScale`.
- `KitIconButton`, the existing v1 API only, for the zoom controls. It does not wait for kit-KitIconButton-v2.
- The failure glyph and avatar icon are drawn with the kit-internal `Icon` at 20 until kit-KitIcon merges. `kit-hygiene` swaps them.

## Tests required

`test/kit/kit_image_test.dart`:

1. A `KitImage` laid out 100 dp wide at DPR 3 requests a decode width of 300: assert the `ResizeImage` `width` via a recording `ImageProvider`. At DPR 2.625 it requests 263.
2. `filterQuality` is `FilterQuality.high` for memory, asset and provider sources.
3. Loading shows the `surface2` fill with no spinner. A provider that errors shows the failure glyph, and at 120 dp or more the words `kitImageUnavailable`. With `fallback`, the fallback shows instead.
4. When the source changes from A to a failing B, the result shows the failure state, not A.
5. `semanticsLabel: null` gives no semantics node; a label gives one image node.
6. `KitAvatar(name: 'Open AI')` shows "OA" and has the semantic label "Open AI". An Arabic name shows its first graphemes. `decorative: true` gives no node. An image that fails keeps showing the initials.
7. At 2.0 text the avatar's initials stay inside the circle (clamped at `monogramMaxTextScale`).
8. `KitZoom`:
   - double-tap goes to 2× and back to 1×;
   - Ctrl+= then Ctrl+0 returns to 1× (desktop capabilities);
   - the custom actions zoom in, zoom out and reset;
   - at 1× reset is disabled with its reason, and at `maxScale` zoom in is disabled with its reason;
   - a new `resetKey` resets.
9. `KitZoomMode.canvas` pans a 2000×2000 child within its bounds, fits it on open (scale ≤ 1, ≥ `minScale`), and a `KitZoomController.reset()` after zooming returns to that fitted transform; `resetControlKey` finds the Fit control.
10. Under reduced motion the reset settles after one `pump()` (G8), and the first-frame cross-fade does not run.
11. No `HapticFeedback` call.

## Galleries required

`test/goldens/kit/kit_image_golden_test.dart`, at DPR 3, Android, with deterministic in-memory PNG fixtures and no network (TEST-11):

- **States** in dark and light at 412×915:
  - `loaded` (contain and cover, in square, panel and circle shapes);
  - `loading`;
  - `failed` (narrow and wide);
  - `avatar` (initials at tile and mark, icon, image);
  - `zoom_rest` and `zoom_zoomed` (controls pill with states).
- **Default state (`loaded` + `avatar`):** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000.
- **`_text2` and `_ar`:** `failed`, `avatar` and `zoom_rest` at 412×915 and 1280×800. The Arabic shot shows Arabic initials and the pill at the bottom left.
- **G5:** control targets and labels.
- **G6 overflow matrix** without images.

## Non-goals

- No SVG, PDF or vector illustrations: those are `KitViewer` and `KitScene`.
- No network fetching by URL, and no cache policy beyond Flutter's image cache.
- No image editing or cropping.
- No camera: that is `KitScanner`.
- No QR codes: that is `KitQr`.
- No hashed avatar colours.
- No numbered step circles: that is `KitChecklist`.
- No call-site migration.

## Open questions

None. `KitTokens.monogramMaxTextScale` is pre-wave (`_new-tokens.md`). `KitZoomController`, canvas fit-on-open and `resetControlKey` were added in the cross-check so KitWorkGraph needs no zoom of its own (README.md, decision D17); they are additive to this unit's scope.
