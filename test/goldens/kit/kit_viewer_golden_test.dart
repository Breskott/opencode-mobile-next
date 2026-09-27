// Gallery (gate G4) for KitViewer, docs/ux-system/kit-api/KitViewer.md:
// the declared states (code, markdown, image, pdf, svg, delimited, binary,
// loading, error, truncated, finding) at the two sizes the owner's
// 2026-09-27 decision keeps (412x915 phone: the sheet; 1280x800 wide: the
// page), light and dark. Arabic and text-2.0 galleries are dropped by that
// same decision.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_viewer_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/kit/kit_viewer.dart';

import 'kit_gallery.dart';

// No blank lines: a blank line's lone number fails G5 contrast inside
// KitCodeBlock (reported to its owner; see the QA record).
const _dart = r'''
import 'package:flutter/widgets.dart';
/// Greets someone by name.
class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final text = 'Hello, $name. Welcome back to the project.';
    return Text(text);
  }
}
String shout(String value) => value.toUpperCase();
int count(List<String> items) {
  var total = 0;
  for (final item in items) {
    total += item.length;
  }
  return total;
}
''';

const _readme = '''
# Greeting

A small widget that says **hello** to the person using the app.

## Use it

1. Add `Greeting` to a screen.
2. Pass the person's `name`.
3. Run the tests with `flutter test`.

```dart
const Greeting(name: 'Sam');
```

Read [the widget guide](https://docs.flutter.dev/ui) for more.
''';

const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 80" width="240" height="160">
  <rect x="4" y="4" width="112" height="72" rx="10" fill="#2f6f73"/>
  <circle cx="40" cy="40" r="20" fill="#f2c14e"/>
  <path d="M70 58 L88 26 L106 58 Z" fill="#e8eef0"/>
</svg>
''';

/// Deterministic bitmaps, drawn once: an illustration and two PDF pages.
late Uint8List _photo;
late Uint8List _page1;
late Uint8List _page2;

Future<Uint8List> _draw(int width, int height, void Function(Canvas) paint) {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  return recorder
      .endRecording()
      .toImage(width, height)
      .then((image) => image.toByteData(format: ui.ImageByteFormat.png))
      .then((data) => data!.buffer.asUint8List());
}

Color _hsv(double hue, double saturation, double value) =>
    HSVColor.fromAHSV(1, hue, saturation, value).toColor();

Future<void> _drawBitmaps() async {
  _photo = await _draw(480, 320, (canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 480, 320),
      Paint()..color = _hsv(200, .35, .9),
    );
    canvas.drawCircle(
      const Offset(360, 90),
      44,
      Paint()..color = _hsv(45, .7, 1),
    );
    final hills = Path()
      ..moveTo(0, 320)
      ..lineTo(0, 220)
      ..quadraticBezierTo(120, 150, 240, 220)
      ..quadraticBezierTo(360, 290, 480, 200)
      ..lineTo(480, 320)
      ..close();
    canvas.drawPath(hills, Paint()..color = _hsv(140, .5, .55));
  });
  Future<Uint8List> page(int lines) => _draw(420, 594, (canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 420, 594),
      Paint()..color = _hsv(0, 0, 1),
    );
    final ink = Paint()..color = _hsv(0, 0, .72);
    canvas.drawRect(const Rect.fromLTWH(40, 48, 220, 18), ink);
    for (var i = 0; i < lines; i++) {
      final width = 340.0 - (i % 4) * 36;
      canvas.drawRect(Rect.fromLTWH(40, 100 + i * 22.0, width, 8), ink);
    }
  });
  _page1 = await page(20);
  _page2 = await page(12);
}

/// Decodes every image on screen for real (widget tests fake time).
Future<void> _decodeImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pumpAndSettle();
}

List<List<String>> _table() => [
  ['Name', 'Role', 'City', 'Joined'],
  for (var i = 0; i < 30; i++)
    [
      'Person ${i + 1}',
      ['Engineer', 'Designer', 'Writer', 'Researcher'][i % 4],
      ['Cairo', 'Lisbon', 'Osaka', 'Toronto', 'Nairobi'][i % 5],
      '2026-0${i % 9 + 1}-1${i % 9}',
    ],
];

KitViewerSource _code() =>
    const KitViewerSource(KitViewerContent.code(_dart, language: 'dart'));

/// Opens the viewer as a person would from a file row.
Future<void> Function(BuildContext) _open({
  required String name,
  required KitViewerSource source,
  String? path,
  bool primary = true,
}) =>
    (context) => showKitViewer(
      context,
      name: name,
      path: path,
      source: source,
      primary: primary
          ? KitAction(label: 'Add to prompt', onPressed: () {})
          : null,
      more: [KitMenuItem.copy(label: 'Copy path', text: () => path ?? name)],
      onOpenAll: () {},
    );

final _states =
    <
      String,
      (
        Future<void> Function(BuildContext),
        Future<void> Function(WidgetTester)?,
      )
    >{
      'code': (
        _open(
          name: 'greeting.dart',
          path: '/home/sam/app/lib/ui/greeting.dart',
          source: _code(),
        ),
        null,
      ),
      'markdown': (
        _open(
          name: 'README.md',
          path: '/home/sam/app/README.md',
          source: const KitViewerSource(KitViewerContent.markdown(_readme)),
        ),
        null,
      ),
      'image': (
        (context) => _open(
          name: 'hills.png',
          path: '/home/sam/app/assets/hills.png',
          source: KitViewerSource(KitViewerContent.image(_photo)),
        )(context),
        _decodeImages,
      ),
      'pdf': (
        (context) => _open(
          name: 'Report.pdf',
          path: '/home/sam/app/docs/Report.pdf',
          source: KitViewerSource(
            KitViewerContent.pdf(
              pageCount: 2,
              renderPage: (index, widthPx) async => KitPdfPage(
                bytes: index == 0 ? _page1 : _page2,
                width: 420,
                height: 594,
              ),
            ),
          ),
        )(context),
        _decodeImages,
      ),
      'svg': (
        _open(
          name: 'logo.svg',
          path: '/home/sam/app/assets/logo.svg',
          source: const KitViewerSource(
            KitViewerContent.svg(_svg, original: _svg),
          ),
        ),
        null,
      ),
      'delimited': (
        _open(
          name: 'people.csv',
          path: '/home/sam/app/data/people.csv',
          source: KitViewerSource(KitViewerContent.delimited(_table())),
        ),
        null,
      ),
      'binary': (
        _open(
          name: 'release.zip',
          path: '/home/sam/app/build/release.zip',
          primary: false,
          source: const KitViewerSource(
            KitViewerContent.binary(
              mimeType: 'application/zip',
              byteLength: 2516582,
            ),
          ),
        ),
        null,
      ),
      'loading': (
        _open(
          name: 'server.log',
          path: '/home/sam/app/logs/server.log',
          source: KitViewerSource.load(
            () => Completer<KitViewerContent>().future,
          ),
        ),
        null,
      ),
      'error': (
        _open(
          name: 'server.log',
          path: '/home/sam/app/logs/server.log',
          source: KitViewerSource.load(
            () => Future<KitViewerContent>.error(
              StateError('The server stopped answering.'),
            ),
          ),
        ),
        null,
      ),
      'truncated': (
        _open(
          name: 'strings.dart',
          path: '/home/sam/app/lib/generated/strings.dart',
          source: KitViewerSource(
            KitViewerContent.code(
              [
                for (var i = 1; i <= 80; i++) "const s$i = 'string $i';",
              ].join('\n'),
              language: 'dart',
              truncated: true,
              totalLines: 5210,
            ),
          ),
        ),
        null,
      ),
      'finding': (
        _open(
          name: 'greeting.dart',
          path: '/home/sam/app/lib/ui/greeting.dart',
          source: _code(),
        ),
        (tester) async {
          await tester.tap(find.byKey(const ValueKey('kit-viewer-more')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Find in file'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('kit-viewer-find')),
            'name',
          );
          await tester.pump(KitMotion.typingSettle);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('kit-viewer-find-next')));
        },
      ),
    };

void main() {
  setUpAll(() async {
    await loadKitGalleryFonts();
    await _drawBitmaps();
  });

  const sizes = [Size(412, 915), Size(1280, 800)];

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in sizes) {
      final at = kitGallerySize(size);
      for (final MapEntry(key: state, value: (open, then)) in _states.entries) {
        testWidgets('kit_viewer $state · $at · $mode', (tester) async {
          await kitGalleryShot(
            tester,
            name: kitGalleryName('kit_viewer_$state', size, light: light),
            size: size,
            light: light,
            open: open,
            then: then,
          );
        });
      }
    }
  }
}
