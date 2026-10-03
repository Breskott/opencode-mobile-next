// Golden renders of shared-files-1's pages (wave 2a): the file preview
// sheet and the embedded file preview body, now adapters over KitViewer.
// Phone 412x915 and one wide window (1280x800), dark and light (owner
// decision 2026-09-27: no Arabic), with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/shared_files_1_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/widgets/file_preview.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

const _readme = '''# Release checklist

Run the **serial** suite before tagging, then:

1. Build the release APK.
2. Compare the signer with `apksigner`.
3. Publish the draft.

```bash
flutter test --concurrency=1
```
''';

const _csv =
    'service,region,latency ms\n'
    'gateway,eu-west,42\n'
    'sessions,eu-west,57\n'
    'search,us-east,118\n'
    'files,ap-south,203\n';

const _json = '{"name":"opencode","port":4096,"tls":false,"plugins":["a","b"]}';

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  Size size = _phone,
  Widget body = const SizedBox.expand(),
  FutureOr<void> Function(BuildContext context)? open,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  try {
    late BuildContext context;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: SafeArea(
              child: Builder(
                builder: (inner) {
                  context = inner;
                  return body;
                },
              ),
            ),
          ),
        ),
      ),
    );
    if (open != null) unawaited(Future.sync(() => open(context)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';

    for (final size in [_phone, _wide]) {
      testWidgets('sheet, markdown ($theme, $size)', (tester) async {
        await _shot(
          tester,
          'file_preview_sheet_markdown',
          light: light,
          size: size,
          open: (context) => showFilePreviewSheet(
            context,
            FilePreviewData(name: 'RELEASING.md', text: _readme),
            path: 'docs/RELEASING.md',
            onAttach: () async {},
          ),
        );
      });
    }

    testWidgets('sheet, unavailable ($theme)', (tester) async {
      await _shot(
        tester,
        'file_preview_sheet_unavailable',
        light: light,
        open: (context) => showFilePreviewSheet(
          context,
          FilePreviewData.fromDataUrl(
            name: 'screenshot.png',
            mimeType: 'image/png',
            url: 'https://example.com/screenshot.png',
          ),
        ),
      );
    });

    testWidgets('sheet, binary ($theme)', (tester) async {
      await _shot(
        tester,
        'file_preview_sheet_binary',
        light: light,
        open: (context) => showFilePreviewSheet(
          context,
          FilePreviewData(
            name: 'model.onnx',
            mimeType: 'application/octet-stream',
            bytes: Uint8List(3 * 1024 * 1024),
          ),
          onAttach: () async {},
        ),
      );
    });

    for (final size in [_phone, _wide]) {
      testWidgets('embedded body, table ($theme, $size)', (tester) async {
        await _shot(
          tester,
          'embedded_file_preview_body_table',
          light: light,
          size: size,
          body: FilePreviewBody(
            data: FilePreviewData(name: 'latency.csv', text: _csv),
          ),
        );
      });
    }

    testWidgets('embedded body, json ($theme)', (tester) async {
      await _shot(
        tester,
        'embedded_file_preview_body_json',
        light: light,
        body: FilePreviewBody(
          data: FilePreviewData(name: 'opencode.json', text: _json),
        ),
      );
    });

    testWidgets('embedded body, malformed table ($theme)', (tester) async {
      await _shot(
        tester,
        'embedded_file_preview_body_malformed',
        light: light,
        body: FilePreviewBody(
          data: FilePreviewData(name: 'broken.tsv', text: 'a\t"open\nb\tc'),
        ),
      );
    });
  }
}
