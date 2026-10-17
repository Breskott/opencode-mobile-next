import 'dart:async';
// KitImageMarkup (docs/ux-system/kit-api/KitImageMarkup.md): pen strokes in
// four colours, Undo, Clear, Crop with corner handles, and a result drawn at
// the picture's own resolution.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

const _w = 400;
const _h = 200;

Future<Uint8List> _picture() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(_w, _h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

class _Decoded {
  _Decoded(this.width, this.height, this.rgba);
  final int width;
  final int height;
  final ByteData rgba;
  Color at(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      rgba.getUint8(i + 3),
      rgba.getUint8(i),
      rgba.getUint8(i + 1),
      rgba.getUint8(i + 2),
    );
  }
}

Future<_Decoded> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _Decoded(image.width, image.height, data!);
}

class _Harness {
  KitMarkupResult? result;
  bool closed = false;
}

/// Opens the editor over a button and waits for the picture to decode.
Future<_Harness> _open(
  WidgetTester tester,
  Uint8List bytes, {
  bool canSend = true,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              harness.result = await showKitImageMarkup(
                context,
                bytes: bytes,
                name: 'shot.png',
                canSend: canSend,
              );
              harness.closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
  return harness;
}

Future<void> _draw(WidgetTester tester, Offset from, Offset by) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveBy(by);
  await gesture.up();
  await tester.pump();
}

Future<void> _press(WidgetTester tester, String key) async {
  await tester.runAsync(() async {
    await tester.tap(find.byKey(ValueKey(key)));
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Offset _canvasCentre(WidgetTester tester) =>
    tester.getCenter(find.byKey(const ValueKey('kit-markup-canvas')));

/// kitModalDismiss for a full-screen page: the home is hidden under the page,
/// so the context is taken before it opens.
KitMotionChange _pageDismiss(
  Future<void> Function(BuildContext context) open,
  String shows,
) => KitMotionChange(
  build: () => const SizedBox.expand(),
  act: (tester, stage) async {
    final context = stage.context;
    unawaited(open(context));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(shows), findsWidgets, reason: 'the page never opened');
    Navigator.of(context).pop();
  },
  hides: shows,
);

void main() {
  final bytes = Uint8List.fromList(const [1, 2, 3]);
  kitMotionStillTests(
    'KitImageMarkup',
    builds: {'unreadable': () => KitImageMarkup(bytes: bytes, name: 'a.png')},
  );
  Future<void> openStill(BuildContext context) =>
      showKitImageMarkup(context, bytes: bytes, name: 'a.png');
  kitMotionStillTests(
    'showKitImageMarkup',
    opens: {'unreadable': KitMotionOpen(openStill, shows: 'Edit picture')},
    changes: {'dismissed': _pageDismiss(openStill, 'Edit picture')},
  );

  testWidgets('drawing marks the picture in red at its own resolution', (
    tester,
  ) async {
    final original = (await tester.runAsync(_picture))!;
    final harness = await _open(tester, original);
    final centre = _canvasCentre(tester);
    await _draw(tester, centre, const Offset(40, 0));
    await _press(tester, 'kit-markup-done');
    final result = harness.result!;
    expect(result.changed, isTrue);
    expect(result.send, isFalse);
    final out = (await tester.runAsync(() => _decode(result.bytes)))!;
    expect(out.width, _w);
    expect(out.height, _h);
    final red = out.at(_w ~/ 2 + 5, _h ~/ 2);
    expect(red.r, greaterThan(0.8));
    expect(red.g, lessThan(0.3));
    // Away from the stroke the picture is untouched.
    expect(out.at(10, 10).b, greaterThan(0.7));
  });

  testWidgets('a chosen colour draws in that colour', (tester) async {
    final original = (await tester.runAsync(_picture))!;
    final harness = await _open(tester, original);
    expect(find.bySemanticsLabel('Yellow'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('kit-markup-yellow')));
    await tester.pump();
    await _draw(tester, _canvasCentre(tester), const Offset(40, 0));
    await _press(tester, 'kit-markup-done');
    final out = (await tester.runAsync(() => _decode(harness.result!.bytes)))!;
    final yellow = out.at(_w ~/ 2 + 5, _h ~/ 2);
    expect(yellow.r, greaterThan(0.8));
    expect(yellow.g, greaterThan(0.7));
    expect(yellow.b, lessThan(0.3));
  });

  testWidgets('undo removes the last stroke; with none left nothing changed', (
    tester,
  ) async {
    final original = (await tester.runAsync(_picture))!;
    final harness = await _open(tester, original);
    await _draw(tester, _canvasCentre(tester), const Offset(40, 0));
    await tester.tap(find.byKey(const ValueKey('kit-markup-undo')));
    await tester.pump();
    await _press(tester, 'kit-markup-done');
    expect(harness.result!.changed, isFalse);
    expect(harness.result!.bytes, original);
  });

  testWidgets('clear removes every stroke', (tester) async {
    final original = (await tester.runAsync(_picture))!;
    final harness = await _open(tester, original);
    final centre = _canvasCentre(tester);
    await _draw(tester, centre, const Offset(30, 0));
    await _draw(tester, centre + const Offset(0, 30), const Offset(30, 0));
    await tester.tap(find.byKey(const ValueKey('kit-markup-clear')));
    await tester.pump();
    await _press(tester, 'kit-markup-done');
    expect(harness.result!.changed, isFalse);
  });

  testWidgets('crop keeps the chosen rectangle at the picture resolution', (
    tester,
  ) async {
    final original = (await tester.runAsync(_picture))!;
    final harness = await _open(tester, original);
    await tester.tap(find.byKey(const ValueKey('kit-markup-crop')));
    await tester.pump();
    // Bottom-right corner in by about a quarter of the picture each way.
    final canvas = tester.getRect(
      find.byKey(const ValueKey('kit-markup-canvas')),
    );
    final handle = tester.getCenter(
      find.byKey(const ValueKey('kit-markup-handle-3')),
    );
    expect(handle.dx, lessThanOrEqualTo(canvas.right));
    final gesture = await tester.startGesture(handle);
    await gesture.moveBy(const Offset(-60, -30));
    await gesture.moveBy(const Offset(-40, -20));
    await gesture.up();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('kit-markup-apply')));
    await tester.pump();
    await _press(tester, 'kit-markup-done');
    final result = harness.result!;
    expect(result.changed, isTrue);
    final out = (await tester.runAsync(() => _decode(result.bytes)))!;
    expect(out.width, lessThan(_w));
    expect(out.height, lessThan(_h));
    // The corner moved in by about 100 screen px; the result is in picture
    // pixels, so it is cut by more than that (the picture is drawn smaller
    // than it is) but keeps most of the picture.
    expect(out.width, greaterThan(_w * 0.3));
    expect(out.height, greaterThan(_h * 0.3));
  });

  testWidgets('cancelling a crop leaves the picture whole', (tester) async {
    final original = (await tester.runAsync(_picture))!;
    final harness = await _open(tester, original);
    await tester.tap(find.byKey(const ValueKey('kit-markup-crop')));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('kit-markup-handle-3'))),
    );
    await gesture.moveBy(const Offset(-60, -30));
    await gesture.up();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('kit-markup-cancel')));
    await tester.pump();
    await _press(tester, 'kit-markup-done');
    expect(harness.result!.changed, isFalse);
  });

  testWidgets('Send returns the result with send set; Done only without it', (
    tester,
  ) async {
    final original = (await tester.runAsync(_picture))!;
    final harness = await _open(tester, original);
    await _draw(tester, _canvasCentre(tester), const Offset(20, 0));
    await _press(tester, 'kit-markup-send');
    expect(harness.result!.send, isTrue);
    expect(harness.result!.changed, isTrue);

    await _open(tester, original, canSend: false);
    expect(find.byKey(const ValueKey('kit-markup-send')), findsNothing);
    expect(find.byKey(const ValueKey('kit-markup-done')), findsOneWidget);
  });
}
