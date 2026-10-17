// How a reply's pictures are laid out (docs/ux-system/kit-api/KitMarkdown.md
// "Pictures"): each at its own proportions, no caption that is only a content
// hash, the same file once.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_markdown.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';
import 'package:opencode_mobile/ui/kit/kit_image.dart';

final _hash = 'a' * 64;

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF336699),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    String text,
    Map<String, Uint8List> files,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: KitMarkdown(
              text,
              fileLinks: KitMarkdownFileLinks(
                validate: (path) async => files.containsKey(path),
                open: (_) {},
                readImage: (path) async => files[path],
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets('a wide screenshot keeps its proportions, no hash caption', (
    tester,
  ) async {
    final path = '/tmp/paseo-attachments-x/$_hash.png';
    final bytes = (await tester.runAsync(() => _png(800, 400)))!;
    await pump(tester, '![Image](file://$path)', {path: bytes});
    final size = tester.getSize(find.byType(KitImage));
    expect(size.width, 320);
    expect(size.height, closeTo(160, 0.5));
    expect(find.textContaining('aaaa'), findsNothing);
  });

  testWidgets('a tall screenshot is capped in height, not cropped', (
    tester,
  ) async {
    final path = '/tmp/shots/tall.png';
    final bytes = (await tester.runAsync(() => _png(200, 800)))!;
    await pump(tester, '![Image](/tmp/shots/tall.png)', {path: bytes});
    final size = tester.getSize(find.byType(KitImage));
    expect(size.height, 360);
    expect(size.width, closeTo(90, 0.5));
    // A real file name is still a caption.
    expect(find.text(KitBidi.ltr('tall.png')), findsOneWidget);
  });

  testWidgets('the same file twice in a row is shown once', (tester) async {
    final path = '/tmp/paseo-attachments-x/$_hash.png';
    final bytes = (await tester.runAsync(() => _png(400, 200)))!;
    await pump(tester, '![Image](file://$path)\n![Image](file://$path)', {
      path: bytes,
    });
    expect(find.byType(KitImage), findsOneWidget);
  });

  testWidgets('several pictures are one row of equal height', (tester) async {
    final a = '/tmp/shots/a.png';
    final b = '/tmp/shots/b.png';
    final files = {
      a: (await tester.runAsync(() => _png(400, 200)))!,
      b: (await tester.runAsync(() => _png(200, 400)))!,
    };
    await pump(tester, '![Image]($a)\n![Image]($b)', files);
    final images = find.byType(KitImage);
    expect(images, findsNWidgets(2));
    expect(tester.getSize(images.at(0)).height, 148);
    expect(tester.getSize(images.at(1)).height, 148);
    expect(tester.getSize(images.at(0)).width, closeTo(296, 0.5));
    expect(tester.getSize(images.at(1)).width, closeTo(74, 0.5));
  });
}
