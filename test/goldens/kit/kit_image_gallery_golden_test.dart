// Gallery (gate G4) for KitImageGallery, docs/ux-system/kit-api/
// KitImageGallery.md: one shot per declared state, dark and light, at phone
// and PC size, and a 2.0 text shot at both.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_image_gallery_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Future<Uint8List> _picture() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 800, 600),
    Paint()..color = const Color(0xFF2F5D8A),
  );
  canvas.drawCircle(
    const Offset(400, 300),
    140,
    Paint()..color = const Color(0xFFE8B84A),
  );
  final image = await recorder.endRecording().toImage(800, 600);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

List<KitGalleryPicture> _pictures(
  Future<Uint8List?> Function() load, {
  int count = 3,
}) => [
  for (var i = 0; i < count; i++)
    KitGalleryPicture(id: 'p$i', name: 'screen-$i.png', load: load),
];

Future<void> _show(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late Uint8List picture;
  setUpAll(() async {
    await loadKitGalleryFonts();
    picture = (await _picture());
  });

  // state -> (open, then). Loading never finishes reading; disabled is the
  // same page with Edit and Send waiting for it; error cannot read; working
  // is Send in flight on a loaded picture.
  Map<
    String,
    (
      FutureOr<void> Function(BuildContext),
      Future<void> Function(WidgetTester)?,
    )
  >
  states() {
    final never = Completer<Uint8List?>();
    Future<void> open(
      BuildContext context,
      List<KitGalleryPicture> pictures, {
      bool send = true,
      Completer<bool>? sending,
    }) => showKitImageGallery(
      context,
      pictures: pictures,
      initialIndex: 1,
      onSend: send
          ? (bytes, name, {required edited}) =>
                sending?.future ?? Future.value(true)
          : null,
    );
    return {
      'loading': (
        (c) => open(c, _pictures(() => never.future), send: false),
        null,
      ),
      'error': ((c) => open(c, _pictures(() async => null)), null),
      'disabled': ((c) => open(c, _pictures(() => never.future)), null),
      'working': (
        (c) =>
            open(c, _pictures(() async => picture), sending: Completer<bool>()),
        (tester) async {
          await _show(tester);
          await tester.tap(find.byKey(const ValueKey('kit-gallery-send')));
          await tester.pump();
        },
      ),
    };
  }

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_image_gallery loading · $at · $mode', (tester) async {
        final (open, then) = states()['loading']!;
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_image_gallery_loading', size, light: light),
          size: size,
          light: light,
          open: open,
          then: (t) async {
            if ('loading' != 'working') await _show(t);
            await then?.call(t);
          },
        );
      });
      testWidgets('kit_image_gallery error · $at · $mode', (tester) async {
        final (open, then) = states()['error']!;
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_image_gallery_error', size, light: light),
          size: size,
          light: light,
          open: open,
          then: (t) async {
            if ('error' != 'working') await _show(t);
            await then?.call(t);
          },
        );
      });
      testWidgets('kit_image_gallery disabled · $at · $mode', (tester) async {
        final (open, then) = states()['disabled']!;
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_image_gallery_disabled',
            size,
            light: light,
          ),
          size: size,
          light: light,
          open: open,
          then: (t) async {
            if ('disabled' != 'working') await _show(t);
            await then?.call(t);
          },
        );
      });
      testWidgets('kit_image_gallery working · $at · $mode', (tester) async {
        final (open, then) = states()['working']!;
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_image_gallery_working', size, light: light),
          size: size,
          light: light,
          open: open,
          then: (t) async {
            if ('working' != 'working') await _show(t);
            await then?.call(t);
          },
        );
      });
      testWidgets('kit_image_gallery working · text 2.0 · $at · $mode', (
        tester,
      ) async {
        final (open, then) = states()['working']!;
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_image_gallery_working',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          open: open,
          then: then,
        );
      });
    }
  }
}
