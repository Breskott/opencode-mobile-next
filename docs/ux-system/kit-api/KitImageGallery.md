# KitImageGallery — API freeze

Spec: the owner request "make images scrollable and editable with send option" (2026-10-11). Rules: A11Y-1, LAY-9, KIT-12, STATE-8.

## Purpose

The pictures of a conversation, one swipe apart. A picture the person opens in a chat (a reply's thumbnail, a sent photo, a path link to a picture) opens this instead of a single-file viewer. They swipe left or right through every picture of the conversation in transcript order, starting at the one tapped, with a "2 of 5" position under the title. Edit opens `KitImageMarkup`; Send puts the (edited) picture in the message field.

## File

- `lib/ui/kit/kit_image_gallery.dart`: `KitImageGallery`, `showKitImageGallery`, `KitGalleryPicture`, `KitGallerySend`.
- Tests: `test/kit/kit_image_gallery_test.dart`.

## Public API

```dart
class KitGalleryPicture {
  const KitGalleryPicture({required String id, required String name,
      required Future<Uint8List?> Function() load});
}
typedef KitGallerySend = Future<bool> Function(Uint8List bytes, String name,
    {required bool edited});

Future<void> showKitImageGallery(BuildContext context,
    {required List<KitGalleryPicture> pictures, int initialIndex = 0,
     KitGallerySend? onSend});
```

## Behaviour

- **Lazy:** `load` runs only for the shown picture and the one on each side, and again after Try again. The host's loaders and caches are reused; the gallery holds bytes only for pictures it has been asked to show.
- **Pinch and swipe:** each page is a `KitZoom`. A horizontal swipe changes picture only while the shown picture is not zoomed in and only one finger is down; zoomed in, the drag pans the picture. Page order follows reading direction, so a swipe is mirrored in RTL.
- **Edit:** opens `showKitImageMarkup`. An edited picture replaces its page in the gallery (the original on the server is never changed). Send in the editor sends and closes.
- **Send:** shown only when `onSend` is given (the host passes null when the agent cannot take pictures). `onSend` returns true when the picture was added, which closes the gallery; false keeps it open (the host has said why). The gallery never sends the prompt. An edited picture is named `<name>-edited.png`.

## States

loading (a working mark), error per picture (title, the way forward, Try again), disabled (Edit and Send until the picture has loaded), working (Send in flight).

## Accessibility

The pager has a semantics label "Picture 2 of 5: name"; the position text is in the title bar; Edit and Send are 48 dp actions; pinch has the visible zoom controls and custom semantic actions of `KitZoom`.
