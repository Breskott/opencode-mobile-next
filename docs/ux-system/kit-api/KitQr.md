# KitQr — API freeze (wave 0)

> **Copy (SEC-13, coordinator 2026-09-27):** copies of technical values, logs and details use `KitCopy.copy(context, text)` (redacted). A part that also copies the person's own content passes `redact: false` for that content.

Unit: `kit-KitQr` (wave 1, tier 1a, kind `kit-part`, model sonnet). Spec: kit-v2.md §5 (handoff: "the handoff QR") and §9.2 (Surfaces), with cut review C36 (`session_handoff_sheets.dart`, `_QrPainter` at `:292` → kit-KitQr as the file→part edge for its wave-2 unit). Rules: LOOK-1, LOOK-21, LOOK-35, KIT-9, KIT-12, KIT-32, STATE-2, STATE-8, A11Y-1, A11Y-8, SEC-2, SEC-5, TEST-11.

## Purpose

A QR code another device can scan: dark modules on a light card with a four-module quiet zone, whatever the theme (scanners read contrast, not palette). Every module is snapped to whole physical pixels, so the code is as sharp as the screen allows. When the data cannot fit in a code, it says so instead of drawing nothing.

## Replaces

- **Map element, 1 on 1 page:** `continue-on-phone-sheet#continue-on-phone-qr` (kit-v2.json `assignment` → `module:handoff`; `kitGap` `KitQrCode`; note "SessionLinkQr custom painter (l.246)"). The page's proposal is `keep`.
- **Code** (`lib/ui/widgets/session_handoff_sheets.dart`, not in this unit's write set; its wave-2 unit adopts the part):
  - `SessionLinkQr` (`:246-290`): a `Container` with `Colors.white` and radius 8, and a `CustomPaint`;
  - `_QrPainter` (`:292-331`): `Colors.black`, and cells overlapped by a `.25` hair "so scaling never leaves seams". Snapping to physical pixels makes the overlap unnecessary (LOOK-21, VL §7).
  - It returns `SizedBox.shrink()` on `InputTooLongException`: a silent blank (STATE-2, STATE-8).
  - Of the file's G16 baseline, `SessionLinkQr` accounts for `Container` 1 and `CustomPaint` 1.
- **Keys kept:** `session-link-qr`, which `test/session_handoff_sheet_layout_test.dart` finds (twice). The adopting unit passes it as `qrKey` (TEST-5).

## File

- `lib/ui/kit/kit_qr.dart` (new): `KitQr`.
- Tests: `test/kit/kit_qr_test.dart`.
- Gallery: `test/goldens/kit/kit_qr_golden_test.dart`.

## Public API

```dart
/// A scannable QR code of [data]. States: default, too long (error).
class KitQr extends StatelessWidget {
  const KitQr({
    super.key,
    required this.data,            // the text to encode; non-empty (asserted)
    required this.semanticsLabel,   // what the code is for: "QR code to open this conversation on your phone"
    this.qrKey,                    // e.g. ValueKey('session-link-qr') (kept by the host)
  });

  final String data;
  final String semanticsLabel;
  final Key? qrKey;

  /// Whether [data] fits a code at the kit's error correction (M). The host
  /// can decide before showing the part (for example to hide "Scan" words).
  static bool fits(String data);
}
```

- **No size parameter.** The code takes the width it is given, up to `KitTokens.qrMaxSize`, and is square. The old `size:` argument (the host computed `min(240, maxWidth)`) becomes the kit's rule.
- **Error correction is M** (as today), and not a parameter.
- **Kit copy** (ARB, `kit` prefix, en and ar):
  - `kitQrTooLong` "This is too long for a QR code. Copy the link instead." (the too-long state);
  - no other words. The semantic label is the host's.

## States

| State | What shows |
|---|---|
| default | the paper card (square, `KitTokens.qrPaper`) with the code in `KitTokens.qrInk`, a 4-module quiet zone, `codeRadius` corners |
| too long | no card. An inline line in `text2` with the error glyph in `text1`: `kitQrTooLong`, which points the person to the copy action the host shows beside it. It is a live region, announced once. |

Loading is not possible (encoding is synchronous and fast for any size a code can hold). Empty is asserted away: `data` must be non-empty. There is no disabled, working or answered state. KIT-12 doc comment: "States: default, error (too long)".

## Tokens

- **New tokens (pre-wave, `_new-tokens.md`; they are not role colours on purpose):**
  - `KitTokens.qrInk` = `graphiteLight.text1` (#111214) and `KitTokens.qrPaper` = `graphiteLight.surface1` (#FFFFFF). Both are read from the `graphiteLight` constant in `theme_roles.dart`, never a literal in the part (LOOK-1, KIT-9). They are the same in every theme and brightness, because an inverted (light-on-dark) code fails many scanners. The paper also gives the ≥ 15:1 contrast scanners need. The coordinator adds them to `KitTokens.fromRoles` (they ignore the pack) and to the LOOK-1 allowlist reason: "scanner contrast, not palette".
  - `KitTokens.qrMaxSize` = 240: the largest side, as today.
  - `KitTokens.qrQuietModules` = 4: the quiet zone the QR standard requires.
- **ThemeRoles:** `text2` (the too-long words), `text1` (its glyph), `hairline` (a 1-physical-px edge around the paper, so a white card on a light sheet still has an edge; LOOK-21).
- **KitText:** `secondary` for the too-long line.
- **KitTokens:** `codeRadius` (14, the paper's corners; the quiet zone is wider than the radius at every size ≥ 120 dp), `space2` (gap between glyph and words), `smallIconSize` (20, the glyph).

## Adaptive

- **Size:** side = `min(maxWidth, qrMaxSize)`, then snapped down so that `side × dpr` is a whole multiple of `(moduleCount + 2 × qrQuietModules)` physical pixels. Every module is the same whole number of physical pixels, and there are no seams or blurred edges (LOOK-21, VL §7). The card is centred by its host.
- **compact:** within the sheet's rails, so the side is 240 dp on any phone ≥ 272 dp of content.
- **medium, expanded, large:** 240 dp, unchanged. The sheet becomes a dialog panel from expanded up (KitSheet); the code stays 240.
- **Short windows:** the host's sheet scrolls, and the code never shrinks below `min(maxWidth, 160)`. If it would, the part still draws at the width it has, and each module stays at least 2 physical px. The host keeps the copy-link path.
- **Pointer and keyboard:** not focusable, no hover. It is an image, and the actions around it (Copy link) are the host's.

## Accessibility

- **One image node** labelled `semanticsLabel` (A11Y-1). The module pattern is excluded. A screen reader user is told what it is, and the host's "Copy link" beside it is the non-visual path.
- **The too-long line** is a live region, announced once when shown.
- **200 % text:** the code does not scale with text (it is an image). The too-long line wraps and is never cut (A11Y-8).
- **Contrast:** qrInk on qrPaper is about 18:1 in every theme. The paper's hairline edge keeps it visible on a light sheet.

## RTL

- **The code itself is never mirrored.** A mirrored QR does not scan; the painter always draws in LTR module order, whatever `Directionality` says.
- **The too-long line** is directional: the glyph at the start, words start-aligned.
- **`data`** is never rendered as text, so it needs no isolation.

## Motion and haptics

- **None:** the code appears with its host, with no build-up animation (a scan-ready code should be ready at once).
- **No haptics.**
- **Reduced motion:** nothing to reduce (G8).

## Data safety and honest state

- **`data` is never shown as text, logged or put into semantics** by the part. A session link can carry identifiers (SEC-2), so only `semanticsLabel` is spoken.
- **Honest failure:** too long is said in words, with a pointer to the copy path. A code that cannot exist is never replaced by a blank (STATE-2, STATE-8).
- **Deterministic:** the same `data` gives the same pixels, so goldens are stable (TEST-11). Fixtures use a fake link, never a real server address or token (SEC-5).
- **No network, no clipboard:** copying the link is the host's `KitIconButton.copy`.

## Depends on

- **Package:** `qr` (already a dependency; the encoder only).
- **Existing:** `KitTokens` (plus the pre-wave tokens above), `KitText`, `ThemeRoles` and `graphiteLight`.
- **Pre-wave seam:** `KitTokens.hairlineWidth(context)`.
- **No wave-1 dependency** (tier 1a).

Depended on by: the wave-2 unit owning `session_handoff_sheets.dart` (C36), and any later pairing or sharing sheet that shows a code, for example "Continue on phone" and a future "pair a phone" flow.

## Tests required

In `test/kit/kit_qr_test.dart`:

1. **Module snapping:** at DPR 3 with 272 dp available, the painted side is ≤ 240 dp and `side × 3` is a whole multiple of the module count plus 8. Every painted module rect has integer physical coordinates (a recording canvas via `PaintingContext`/`TestRecordingCanvas`).
2. **Pattern:** for `data = 'https://example.invalid/s/abc'` the painted dark modules equal `QrImage(QrCode.fromData(data, M)).isDark` cell by cell (the recording canvas).
3. **Theme-proof:** in dark and light apps, and with a high-contrast pack, the paper paints `graphiteLight.surface1` and the ink `graphiteLight.text1`.
4. **Too long:** data of 4,000 characters shows `kitQrTooLong` (found by text) and no paper. `KitQr.fits` returns false for it and true for a short link.
5. **Semantics:** one image node with the `semanticsLabel`. `data` appears nowhere in the semantics tree or the rendered text.
6. **Direction:** under RTL the painted module pattern is identical to LTR.
7. **Empty:** `KitQr(data: '')` asserts.
8. **Overflow and motion:** no overflow at 320 and 412 dp, text 1.0, 1.3 and 2.0, LTR and RTL, for both states (G6); settles after one `pump()` (G8).

## Galleries required

`test/goldens/kit/kit_qr_golden_test.dart`, DPR 3, Android. The scene is the code on a `surface2` sheet body with a caption row that stands in for the host's link and Copy, so the paper's edge is seen against a sheet in both themes.

- **Declared states × dark and light at 412×915:** `default`, `too_long`. That is 4 PNGs.
- **Default × dark and light** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000: 10 PNGs.
- **Text 2.0 and Arabic** (`default`, `too_long`) at 412×915 and 1280×800, dark: 8 PNGs.
- **Names:** `kit_qr_<state>[_ar][_text2][_WxH]_<dark|light>.png`. That is 22 PNGs.

## Non-goals

- **No scanning:** that is KitScanner.
- **No logo in the middle, no colour codes, no size or error-correction options.**
- **No link row, copy button or share:** the host's sheet has those.
- **No edits to `session_handoff_sheets.dart`.**

## Open questions

None. The one exception to theme colours (a fixed dark-on-light code) is required by how scanners work. It is kept inside the kit as two named tokens read from `graphiteLight`, never as literals.
