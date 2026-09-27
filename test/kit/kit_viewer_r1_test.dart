// Unit slice-R1 (docs/ux-system/revamp/leftover-units.json): KitViewer's
// header shows the parent folder only, the primary action has its own
// full-width row under the name, and the body sits on the gutter. Behaviour
// first, then the unit's own gallery shots (owner 2026-09-27: phone 412x915
// and 1280x800, light and dark).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_viewer.dart';

import '../goldens/kit/kit_gallery.dart';
import 'kit_harness.dart';

const _phone = Size(412, 915);
const _pc = Size(1280, 800);

const _code = KitViewerSource(
  KitViewerContent.code('void main() {\n  print("hi");\n}\n', language: 'dart'),
);

Future<void> _open(
  WidgetTester tester, {
  Size size = _phone,
  String name = 'README.md',
  String? path = 'docs/README.md',
  KitAction? primary,
  List<KitMenuItem> more = const [],
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final context = await pumpKitHost(tester, size: size);
  unawaited(
    showKitViewer(
      context,
      name: name,
      path: path,
      source: _code,
      primary: primary,
      more: more,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('KitViewer.folderOf', () {
    test('the parent folder only, with its slash', () {
      expect(KitViewer.folderOf('docs/README.md', 'README.md'), 'docs/');
      expect(KitViewer.folderOf('/repo/docs/a.md', 'a.md'), '/repo/docs/');
      expect(KitViewer.folderOf(r'C:\repo\a.md', 'a.md'), r'C:\repo\');
    });
    test('a root file has none, so the name never shows twice', () {
      expect(KitViewer.folderOf('README.md', 'README.md'), isNull);
      expect(KitViewer.folderOf('', 'README.md'), isNull);
    });
    test('what follows the name stays ("· Line 12")', () {
      expect(
        KitViewer.folderOf('src/a.dart · Line 12', 'a.dart'),
        'src/ · Line 12',
      );
      expect(KitViewer.folderOf('a.dart · Line 12', 'a.dart'), 'Line 12');
    });
    test('a caption that is not the file path shows as it is', () {
      expect(KitViewer.folderOf('MIT License', 'Vosk'), 'MIT License');
    });
  });

  group('header', () {
    testWidgets('a root file shows its name once', (tester) async {
      await _open(tester, path: 'README.md');
      expect(find.textContaining('README.md'), findsOneWidget);
    });

    testWidgets('the subtitle is the folder; the label and Copy path keep '
        'the full path', (tester) async {
      final semantics = tester.ensureSemantics();
      final writes = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            writes.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _open(
        tester,
        more: [
          KitMenuItem.copy(label: 'Copy path', text: () => 'docs/README.md'),
        ],
      );
      expect(find.text('docs/'), findsOneWidget);
      expect(find.textContaining('docs/README.md'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('docs/README.md')), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('kit-viewer-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy path'));
      await tester.pumpAndSettle();
      expect(writes, ['docs/README.md']);
      semantics.dispose();
    });

    for (final (label, size) in [('phone', _phone), ('PC', _pc)]) {
      testWidgets('$label: the primary has its own row under the name, '
          'starting where the name starts, on one line', (tester) async {
        await _open(
          tester,
          size: size,
          primary: KitAction(label: 'Add to prompt', onPressed: () {}),
        );
        final name = find.text('README.md');
        final more = find.byKey(const ValueKey('kit-viewer-more'));
        final words = find.text('Add to prompt');
        expect(
          tester.getTopLeft(words).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(more).dy),
        );
        expect(
          tester.getTopLeft(words).dy,
          greaterThan(tester.getBottomLeft(find.text('docs/')).dy),
        );
        final nameX = tester.getTopLeft(name).dx;
        if (size == _phone) {
          // The tertiary button's words line up with the name.
          expect(tester.getTopLeft(words).dx, closeTo(nameX, 1));
        } else {
          final button = find.byKey(const ValueKey('kit-viewer-primary'));
          expect(tester.getTopLeft(button).dx, closeTo(nameX, 1));
        }
        // One line: the words are no taller than a line of their style.
        final lineHeight = tester.getSize(words).height;
        expect(lineHeight, lessThan(tester.getSize(name).height * 1.5));
      });
    }
  });

  testWidgets('the body is on the gutter, like the name', (tester) async {
    await _open(tester);
    final nameX = tester.getTopLeft(find.text('README.md')).dx;
    final block = find.byType(KitCodeBlock);
    expect(tester.getTopLeft(block).dx, nameX);
  });

  testWidgets("\"Can't show this file\" is on the gutter too", (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final context = await pumpKitHost(tester, size: _pc);
    unawaited(
      showKitViewer(
        context,
        name: 'release.zip',
        path: 'build/release.zip',
        source: KitViewerSource(
          KitViewerContent.binary(mimeType: 'application/zip', byteLength: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text("Can't show this file")).dx,
      tester.getTopLeft(find.text('release.zip')).dx,
    );
  });

  setUpAll(loadKitGalleryFonts);
  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';
    for (final size in [_phone, _pc]) {
      testWidgets('kit_viewer_r1_header ${kitGallerySize(size)} $theme', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name:
              'goldens/${kitGalleryName('kit_viewer_r1_header', size, light: light)}',
          size: size,
          light: light,
          child: SizedBox(
            height: 360,
            child: KitViewer(
              name: 'kit_viewer.dart',
              path: 'lib/ui/kit/kit_viewer.dart',
              source: _code,
              primary: KitAction(label: 'Add to prompt', onPressed: () {}),
              onClose: () {},
            ),
          ),
        );
      });
    }
  }
}
