# KitScanner — API freeze (wave 0)

Unit: `kit-KitScanner` (wave 1, tier 1b, kind `kit-part`, model sonnet; the KitSince edge below is added, README.md). Spec: kit-v2.md §5 (one-off surfaces: "the QR scanner camera") and §9.2 (Surfaces), with cut review C36 (`pairing_scanner_screen.dart` → kit-KitScanner as the file→part edge for its wave-2 unit). Programme: P9.9 (non-goal: no new behaviour in the scanner). Rules: KIT-1, KIT-3, KIT-9, KIT-12, STATE-5, STATE-9, LOOK-4, LOOK-5, LOOK-6, LAY-3, LAY-9, A11Y-1, A11Y-3, SEC-2, SEC-5, MOT-11.

## Purpose

The camera frame that finds a pairing QR: a live preview with a viewfinder, one instruction line, and an in-place line when the code seen is not the one wanted. It hands each decoded value to the host exactly once and never keeps it. Permission, the recovery states and parsing stay with the host.

## Replaces

- **Map element, 1 on 1 page:** `pairing-scanner#pairing-scanner-camera` (kit-v2.json `assignment` → `module:special surface`, moved into the kit by K2 §9.2): the `MobileScanner` preview (`pairing_scanner_screen.dart:274-276`).
- **The preview column around it** (`pairing_scanner_screen.dart:266-321`):
  - the instruction `Text`;
  - the rejected message in an `errorContainer` `Container` with radius 10 (LOOK-5: red for a wrong QR is not an act that destroys);
  - the starting `CircularProgressIndicator` (`:176-179`, `:269-271`).
- **G16 counts this lets wave 2 bring to zero** in `pairing_scanner_screen.dart` (baseline: `AppBar` 1, `CircularProgressIndicator` 2, `Container` 1, `FilledButton` 1, `Icon` 2, `IconButton` 1, `Scaffold` 1, `Text` 7, `TextButton` 1): the `Container`, both progress indicators and 2 `Text`. The rest (`_Recovery`, the app bar) goes to `KitStateView` (`pairing-scanner-recovery`) and `KitScreen`/`KitTopBar` in the owning screen unit.
- **Not replaced here:** the camera permission flow (`cameraPlatform` in `lib/platform/camera.dart`) and `parsePairingPayload` (`lib/state/pairing.dart`) stay with the host (ARCH-5).

## File

- `lib/ui/kit/kit_scanner.dart` (new): `KitScanner`, `KitScannerCamera`, `KitScannerFailure`.
- Tests: `test/kit/kit_scanner_test.dart`.
- Gallery: `test/goldens/kit/kit_scanner_golden_test.dart`.
- `kit.dart`: one export row (the integrator adds it; R06, PROC-13).

## Public API

```dart
/// Where the frames come from. The default is the device camera through
/// mobile_scanner, QR only; tests and galleries pass a fake. The package's
/// types never leave this file.
abstract class KitScannerCamera {
  /// The back camera, QR codes only, each code reported once per sighting
  /// (mobile_scanner's DetectionSpeed.noDuplicates).
  factory KitScannerCamera.qr() = _MobileScannerCamera;

  /// Opens the camera. Throws KitScannerFailure when it cannot.
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();

  /// Decoded values, raw. Only KitScanner listens.
  Stream<String> get codes;

  /// The live preview, filling its box.
  Widget preview(BuildContext context);
}

/// The camera could not open. [deviceMessage] is about the device (it
/// never carries a decoded value), safe for the host's Details.
class KitScannerFailure implements Exception {
  const KitScannerFailure([this.deviceMessage]);
  final String? deviceMessage;
}

/// States: starting, scanning, rejected, slow (starting > 8 s), paused
/// (app in background). Failure goes to the host (onFailed).
class KitScanner extends StatefulWidget {
  const KitScanner({
    super.key,
    required this.onCode,        // bool Function(String raw): true = accepted; the part stops
                                 //   the camera and delivers nothing more
    required this.onFailed,      // ValueChanged<KitScannerFailure>: the host shows its KitStateView
    required this.instruction,   // "Point the camera at the code that opencode2 pair printed"
    this.rejected,               // String?: why the last code was refused, in words (the host's
                                 //   setupUiMessage); null hides the line
    this.onSlow = const [],      // ≤ 2 KitActions offered when the camera takes > 8 s to open
                                 //   ("Paste the code instead"); asserted ≤ 2
    this.camera,                 // KitScannerCamera? null = KitScannerCamera.qr()
    this.previewKey,             // default ValueKey('kit-scanner-preview'); the pairing screen
                                 //   passes its existing ValueKey('pairing-scanner-preview')
    this.rejectedKey,            // e.g. ValueKey('pairing-scanner-rejected') (kept by the host)
  });

  final bool Function(String raw) onCode;
  final ValueChanged<KitScannerFailure> onFailed;
  final String instruction;
  final String? rejected;
  final List<KitAction> onSlow;
  final KitScannerCamera? camera;
  final Key? previewKey;
  final Key? rejectedKey;
}
```

Notes:

- **One camera per part.** `KitScanner` owns the camera it creates: it starts it in `initState` and disposes it in `dispose`. A camera passed in is started and stopped by the part but disposed by its owner.
- **Handled once.** After `onCode` returns true, the part sets its latch, stops the camera and ignores every later value, even ones already queued in the stream. This moves `_handled` (`pairing_scanner_screen.dart:66`) into the kit, where every future scanner gets it.
- **Parsing stays out.** The part never decides what a valid code is. `onCode` returns false for "not a pairing code", and the host sets `rejected` to the words.
- **No styling parameters.** The frame size, the corners and the dim outside the frame come from tokens.
- **Kit copy** (ARB, `kit` prefix, en and ar together; COPY-1, COPY-3):
  - `kitScannerStarting` "Opening the camera…";
  - `kitScannerSlow` "Still opening the camera" (shown in the slow phase KitSince reports);
  - `kitScannerPaused` "Camera paused";
  - `kitScannerPreview` "Camera view".

  The instruction and rejected words are the host's.

## States

| State | What shows | Announced |
|---|---|---|
| starting | `ground` where the preview will be; `KitProgress.waiting` with the kit's "Opening the camera…" centred in the frame | once, by the progress's own label |
| slow | after `KitMotion.escalateAfter` (8 s) of starting: "Still opening the camera" (the words come from `KitSince`) with the `onSlow` actions under it | once (STATE-5) |
| scanning | the live preview filling the area. Outside the square window it is dimmed with `scrim`; four corner brackets mark the window; the instruction sits under the preview | the preview's label, once when scanning starts |
| rejected | scanning, plus an inline `KitNotice` (neutral tone, `AppIconography.error` glyph in `text1`) with `rejected`, under the instruction. Scanning continues. | once per distinct message (A11Y-3) |
| paused | the app went to the background: the camera is stopped and the area shows `ground` with "Camera paused". It restarts on resume, with no action needed. | none (nothing happened that the person did) |
| failed | not drawn by the part: `onFailed` is called once and the host replaces the part with its `KitStateView` (denied, blocked, no camera and failed stay the host's) | the host's state |

Empty and disabled do not apply: a scanner with no camera is the host's no-camera state. Working and answered do not apply. KIT-12 doc comment: "States: loading (starting, slow), error (rejected; failure reported), paused".

## Tokens

- **ThemeRoles:**
  - `ground` behind the preview while it starts;
  - `scrim` over the preview outside the window;
  - `accent` for the corner brackets while scanning (LOOK-6: a working mark), `text3` while starting or paused;
  - `text2` for the instruction;
  - `text1` for the rejected words and glyph (never `danger`: LOOK-5, B2 interim; never `attention`: LOOK-4).
- **KitText:** `secondary` for the instruction and the rejected line; `label` for "Opening the camera…" and "Camera paused".
- **KitTokens:** `gutter` (16, side rails of the text block), `space3` (12, instruction to notice), `space4` (16), `space6` (24, under the text block), `panelCornerRadius` (18, the window's corners), `space1` (4, the bracket thickness: a filled shape, not a stroke; LOOK-21 governs lines and borders).
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitTokens.scannerWindow` = 240: the side of the square window. It is capped by `width − 2 × gutter` and by the preview's height `− 2 × space6`.
  - `KitTokens.scannerBracket` = 28: the length of each corner bracket's arms.

## Adaptive

| Window | Layout |
|---|---|
| compact | the preview fills the available width and height minus the text block; the window is centred in it; instruction and notice sit under the preview on the 16 dp rails |
| short (< 480 dp tall, a phone in landscape) | the preview takes the start half and the text block the end half, so the window keeps its size (LAY-3) |
| medium | as compact, with the text block capped at `KitLayout.readingWidth` and centred |
| expanded / large | the same (tablets with a camera). A PC without a camera never shows the part: the host's no-camera state applies, and on a desktop build `KitScannerCamera.qr().start()` throws `KitScannerFailure`. |

- **Pointer:** no hover targets inside the frame.
- **Keyboard:** the frame is not a Tab stop, and the `onSlow` actions are (LAY-10). Esc belongs to the host's route: it pops, and the part's `dispose` stops the camera.

## Accessibility

- **The preview** is one image node labelled "Camera view" (`kitScannerPreview`) with the instruction as its hint. A screen reader user hears what to do without a picture.
- **The rejected line** is a live region, announced once per new message.
- **Starting and slow** are announced once each by `KitProgress` and `KitSince`.
- **Actions:** the `onSlow` actions are 48 dp `KitButton`s with their labels.
- **200 % text:** the instruction and notice wrap, never truncate. The text block scrolls when it would push the window below 160 dp; the window shrinks before the text is cut. No overflow at 320 dp (G6).

## RTL

- The layout is directional: text is start-aligned, and in the short layout the preview sits at the start (the right in Arabic).
- The camera image is never mirrored. The window and brackets are symmetric, so nothing flips.
- Words the host passes (the instruction, the rejected line) may quote a command. Such a value is wrapped by the host with `KitBidi.ltr` (COPY-30).

## Motion and haptics

- **Nothing moves:** no scanning line and no pulsing corners. The corners change colour at once when the camera starts.
- **The rejected notice** appears with the existing `KitNotice` entrance (`KitMotion.standard`), and instantly under reduced motion.
- **No haptics** on detection or rejection (MOT-11). The host may call `KitHaptics.done` when pairing completes.
- **Reduced motion:** settles after one `pump()` with a fake camera (G8).

## Data safety and honest state

- **The decoded value is never kept.** It is passed straight from the camera stream to `onCode` and is never stored in state, rendered, put into semantics, logged or sent to diagnostics. The QR carries the server password (SEC-2). A test asserts that a fake value appears nowhere in the rendered tree, the semantics tree or the captured debug log.
- **The camera stops when nobody needs it:**
  - after an accepted code, before the host pops, so no frame is decoded behind a closing route;
  - on `AppLifecycleState.paused` and `inactive` (privacy and battery), restarting on `resumed`;
  - on `dispose`.
- **No silent wait:** a camera that does not open within 8 s says so with a way out (STATE-5).
- **An honest failure:** `onFailed` is called exactly once per `start` attempt. A retry is the host's (it rebuilds the part with a new key). `deviceMessage` comes from the camera error only.
- **Fixtures:** tests and galleries use a fake camera and fake values. Nothing holds a real pairing password (SEC-5).

## Depends on

- **kit-KitSince** (tier 1a; edge added, README.md): the 8 s escalation of `starting` (STATE-5). It moves this unit from tier 1a to 1b. Without it the part would need its own `Timer`, which the kit forbids (KitStateView.md, C12).
- **Existing kit parts:** `KitProgress`/`KitProgressView` (waiting), `KitNotice` (the rejected line; v1 is enough), `KitButton`/`KitAction` (the `onSlow` actions), `KitTokens`, `KitText`, `KitLayout`, `ThemeRoles`.
- **Package:** `mobile_scanner` (already a dependency; only this file imports it once the screen unit migrates).

Depended on by: the wave-2 unit owning `pairing_scanner_screen.dart` (C36 file→part edge).

## Tests required

In `test/kit/kit_scanner_test.dart`, with a `FakeScannerCamera` (a `StreamController<String>` and a flat `surface3` preview):

1. **Accept once:** two values arrive in the same frame and `onCode` returns true for the first. `onCode` is called exactly once, and `camera.stop()` is called before the next frame.
2. **Reject and keep scanning:** `onCode` returns false, and the host sets `rejected`. The notice appears (found by `rejectedKey`) and is announced once. The same message set again does not announce twice. A later valid value is still delivered.
3. **Never kept:** after a value `'oc2://pair?password=fake-secret'`, the string `fake-secret` is absent from `find.textContaining`, from the semantics tree (`tester.getSemantics` over the whole tree) and from `debugPrint` output captured during the test.
4. **Failure:** `start()` throws `KitScannerFailure('busy')`, so `onFailed` is called once with `deviceMessage == 'busy'` and nothing else is drawn by the part.
5. **Slow:** with a camera whose `start()` never completes and KitSince's fake clock, there is no change at 7 s. At 8 s "Still opening the camera" shows with the `onSlow` action, announced once. Three `onSlow` actions throw an `AssertionError`.
6. **Lifecycle:** `AppLifecycleState.paused` calls `stop()` and shows "Camera paused"; `resumed` calls `start()` again. `dispose` stops the camera it created and disposes it, but does not dispose one passed in.
7. **Short window:** at 915×412 the preview and the text block sit side by side, with the preview at the start (LTR left, Arabic right).
8. **Colours:** the corners paint `accent` while scanning, and no `danger` or `attention` colour is painted in any state (a painted-colour scan of the gallery scenes).
9. **Overflow and motion:** no overflow at 320, 412 and 915×412 at text 1.0, 1.3 and 2.0, LTR and RTL (G6); settles after one `pump()` under reduced motion (G8).

## Galleries required

`test/goldens/kit/kit_scanner_golden_test.dart`, DPR 3, Android, with the fake camera (a flat `surface3` preview, no network and no clock; TEST-11).

- **Declared states × dark and light at 412×915:** `starting`, `slow`, `scanning`, `rejected`, `paused`. That is 10 PNGs.
- **Default (`scanning`) × dark and light** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000: 10 PNGs.
- **Text 2.0 and Arabic** (`rejected`) at 412×915 and 1280×800, dark: 4 PNGs.
- **Names:** `kit_scanner_<state>[_ar][_text2][_WxH]_<dark|light>.png`. That is 24 PNGs.

## Non-goals

- **No new scanner behaviour (P9.9):** no torch, no zoom, no gallery-image import and no other barcode formats.
- **No permission handling, recovery states or payload parsing:** those stay with the host.
- **No edits to `pairing_scanner_screen.dart`:** that is its wave-2 unit.

## Open questions

None. The one reading chosen is that "KitScanner (pairing camera frame)" means the frame and its honest states only, while permission and recovery stay with the host as `KitStateView`s, because kit-v2.json assigns `pairing-scanner-recovery` to `KitStateView`.
