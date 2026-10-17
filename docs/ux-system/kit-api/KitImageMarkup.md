# KitImageMarkup — API freeze

Spec: the owner request "make images scrollable and editable with send option" (2026-10-11). Rules: A11Y-1, A11Y-8, LAY-9, KIT-12.

## Purpose

A small markup editor for one picture: draw with a finger, undo, clear, and crop. Not a photo editor: no text, shapes, arrows or filters.

## File

- `lib/ui/kit/kit_image_markup.dart`: `KitImageMarkup`, `showKitImageMarkup`, `KitMarkupResult`, `kitMarkupMaxBytes`.
- Tests: `test/kit/kit_image_markup_test.dart`.

## Public API

```dart
Future<KitMarkupResult?> showKitImageMarkup(BuildContext context,
    {required Uint8List bytes, required String name, bool canSend = true});

class KitMarkupResult {
  final Uint8List bytes; // PNG when changed, else the original bytes
  final bool send;       // Send pressed, not Done
  final bool changed;    // something was drawn or cropped
}
```

## Behaviour

- **Pen:** one finger draws, four colours as a `KitSwatchGrid` (red by default, yellow, white, black; named for a screen reader). Undo removes the last stroke; Clear removes every stroke and the crop.
- **Crop:** a rectangle with four 48 dp corner handles; dragging inside moves it; Apply keeps it, Cancel leaves it. A later Crop starts from the applied rectangle. The picture then shows only the kept area.
- **Resolution:** strokes are stored in the picture's own pixels and the result is drawn at the picture's own size (the crop's size), not the screen's. A PNG over 9 MiB (`kitMarkupMaxBytes`, under the composer's 10 MB limit) is scaled down by a quarter at a time until it fits.
- **No edit, no re-encode:** Done or Send with nothing drawn or cropped returns the original bytes with `changed: false`.
- Pen colours are the editor's own (a red mark stays red in every theme); everything else reads `KitTokens`.

## States

loading (the picture is being read), error (cannot read the picture; a failed render says what happened and to go back and send the original), working (the result being drawn). Drawing and cropping are modes, not states.

## Accessibility

The surface is labelled "Picture being edited. Draw on it with your finger."; each corner handle and the crop area have labels; swatches are named; Undo, Clear and Crop have tooltips. Handles are physical (not mirrored) because they sit on the picture's own pixels.
