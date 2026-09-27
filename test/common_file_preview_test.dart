// Behaviour of the file preview adapters over KitViewer (shared-files-1):
// the embedded body, the one viewer sheet and the inline text preview.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_markdown.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/widgets/file_preview.dart';

Widget _app(Widget body) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: body),
);

Future<void> _pump(WidgetTester tester, Widget body) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(body));
  await tester.pumpAndSettle();
}

Future<void> _body(WidgetTester tester, FilePreviewData data, {int? line}) =>
    _pump(tester, FilePreviewBody(data: data, initialLine: line));

/// Pumps a host and returns a context under its navigator.
Future<BuildContext> _host(WidgetTester tester) async {
  late BuildContext context;
  await _pump(
    tester,
    Builder(
      builder: (inner) {
        context = inner;
        return const SizedBox.expand();
      },
    ),
  );
  return context;
}

List<String> _recordCopies(WidgetTester tester) {
  final copies = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copies.add((call.arguments as Map)['text'] as String);
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
  return copies;
}

Future<void> _more(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('kit-viewer-more')));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'eligible byte-only text decodes strictly and export keeps original bytes',
    () {
      final bytes = Uint8List.fromList(utf8.encode('a,b\r\n1,2\r\n'));
      final data = FilePreviewData(name: 'data.csv', bytes: bytes);
      expect(data.text, 'a,b\r\n1,2\r\n');
      expect(data.exportBytes, same(bytes));
      expect(
        FilePreviewData(
          name: 'data.csv',
          bytes: Uint8List.fromList([0xff]),
        ).text,
        isNull,
      );
      expect(
        FilePreviewData(name: 'data.csv', bytes: Uint8List.fromList([0])).text,
        isNull,
      );
      expect(
        FilePreviewData(
          name: 'data.csv',
          mimeType: 'application/pdf',
          bytes: bytes,
        ).text,
        isNull,
      );
    },
  );

  test('invalid UTF-8 data URL keeps Save bytes without replacement text', () {
    final data = FilePreviewData.fromDataUrl(
      name: 'data.csv',
      mimeType: 'text/csv',
      url: 'data:text/csv;base64,/w==',
    );
    expect(data.text, isNull);
    expect(data.exportBytes, [255]);
    expect(data.error, isNull);
  });

  testWidgets('CSV is an inert table with a Source view beside it', (
    tester,
  ) async {
    const source = 'name,value\r\n"a,b","=SUM(A1)"\r\n# Heading,<script>\r\n';
    await _body(tester, FilePreviewData(name: 'report.csv', text: source));
    expect(find.byKey(const ValueKey('kit-viewer-table')), findsOneWidget);
    expect(find.textContaining('a,b'), findsOneWidget);
    expect(find.textContaining('=SUM(A1)'), findsOneWidget);
    expect(find.textContaining('# Heading'), findsOneWidget);
    expect(find.byType(KitMarkdown), findsNothing);
    // Wrap applies to source only.
    expect(find.byKey(const ValueKey('file-preview-wrap')), findsNothing);
    await tester.tap(find.text('Source'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kit-viewer-table')), findsNothing);
    expect(find.byKey(const ValueKey('file-preview-wrap')), findsOneWidget);
    await tester.tap(find.text('Table'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kit-viewer-table')), findsOneWidget);
  });

  testWidgets('a partial CSV never becomes a table and says so', (
    tester,
  ) async {
    final data = FilePreviewData(
      name: 'report.csv',
      text: 'a,b\n"partial',
      originalText: 'a,b\n"partial but complete",2\n',
      truncated: true,
    );
    await _body(tester, data);
    expect(find.byKey(const ValueKey('kit-viewer-table')), findsNothing);
    expect(find.text('Showing part of this file'), findsOneWidget);
    expect(utf8.decode(data.exportBytes!), data.originalText);
  });

  testWidgets('malformed and empty tables explain themselves', (tester) async {
    await _body(tester, FilePreviewData(name: 'report.tsv', text: '"open'));
    expect(
      find.textContaining('incomplete or inconsistent quoting'),
      findsOneWidget,
    );
    expect(find.byType(KitCodeBlock), findsOneWidget);
    await _body(tester, FilePreviewData(name: 'report.tsv', text: ''));
    expect(find.text('This file is empty'), findsOneWidget);
  });

  testWidgets('a line outside the preview is named, one inside is not', (
    tester,
  ) async {
    final data = FilePreviewData(
      name: 'large.dart',
      text: 'first\nsecond\npartial',
      originalText: 'first\nsecond\npartial complete\nfourth\nfifth',
      truncated: true,
    );
    await _body(tester, data, line: 2);
    expect(find.textContaining('outside this preview'), findsNothing);
    expect(
      tester.widget<KitCodeBlock>(find.byType(KitCodeBlock)).initialLine,
      2,
    );
    await _body(tester, data, line: 5);
    expect(
      find.textContaining('Line 5 is outside this preview'),
      findsOneWidget,
    );
    expect(
      tester.widget<KitCodeBlock>(find.byType(KitCodeBlock)).initialLine,
      isNull,
    );
  });

  testWidgets('static SVG draws locally; active SVG shows its source', (
    tester,
  ) async {
    const drawing =
        '<svg viewBox="0 0 100 50"><rect width="100" height="50" fill="#123456"/></svg>\r\n';
    await _body(tester, FilePreviewData(name: 'drawing.svg', text: drawing));
    expect(find.byType(SvgPicture), findsOneWidget);
    await tester.tap(find.text('Source'));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byType(KitCodeBlock), findsOneWidget);

    const active = '<svg><script>run()</script></svg>';
    await _body(tester, FilePreviewData(name: 'drawing.svg', text: active));
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.textContaining('cannot be shown as a local'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Markdown reads as prose with a Rendered and Source switch', (
    tester,
  ) async {
    await _body(
      tester,
      FilePreviewData(name: 'SKILL.md', text: '# Title\n\nSome **words**.'),
    );
    expect(find.byType(KitMarkdown), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('file-preview-raw-mode')));
    await tester.pumpAndSettle();
    expect(find.byType(KitMarkdown), findsNothing);
    expect(find.byType(KitCodeBlock), findsOneWidget);
  });

  testWidgets('missing and unknown files say what happened in words', (
    tester,
  ) async {
    await _body(
      tester,
      FilePreviewData.fromDataUrl(name: 'a.png', mimeType: null, url: null),
    );
    expect(find.text('Preview unavailable'), findsOneWidget);
    expect(
      find.text('The attachment content is not included in this message.'),
      findsOneWidget,
    );
    await _body(
      tester,
      FilePreviewData(
        name: 'blob.bin',
        mimeType: 'application/octet-stream',
        bytes: Uint8List(2048),
      ),
    );
    expect(find.text("Can't show this file"), findsOneWidget);
    expect(find.textContaining('application/octet-stream'), findsOneWidget);
  });

  testWidgets(
    'the sheet has Close, one labelled action and More; attach closes it',
    (tester) async {
      final context = await _host(tester);
      var attached = 0;
      var filesOpened = 0;
      showFilePreviewSheet(
        context,
        FilePreviewData(name: 'notes.txt', text: 'hello\n'),
        path: '/repo/notes.txt',
        onAttach: () async => attached++,
        onOpenInFiles: () => filesOpened++,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('file-preview-sheet')), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('Attach to prompt'), findsOneWidget);
      expect(find.byKey(const ValueKey('kit-viewer-close')), findsOneWidget);
      expect(find.byTooltip('Copy file contents'), findsNothing);
      await _more(tester);
      expect(find.text('Save to device'), findsOneWidget);
      expect(find.text('Copy path'), findsOneWidget);
      expect(find.text('Open in Files'), findsOneWidget);
      await tester.tap(find.text('Open in Files'));
      await tester.pumpAndSettle();
      expect(filesOpened, 1);
      expect(find.byKey(const ValueKey('file-preview-sheet')), findsNothing);

      showFilePreviewSheet(
        context,
        FilePreviewData(name: 'notes.txt', text: 'hello\n'),
        onAttach: () async => attached++,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('file-preview-attach')));
      await tester.pumpAndSettle();
      expect(attached, 1);
      expect(find.byKey(const ValueKey('file-preview-sheet')), findsNothing);
    },
  );

  testWidgets('a failed attach keeps the sheet and says so', (tester) async {
    final context = await _host(tester);
    showFilePreviewSheet(
      context,
      FilePreviewData(name: 'notes.txt', text: 'hello\n'),
      onAttach: () async => throw StateError('offline'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('file-preview-attach')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't attach file"), findsOneWidget);
  });

  testWidgets('laid-out JSON offers a verbatim copy of the original', (
    tester,
  ) async {
    final copies = _recordCopies(tester);
    const source = ' {"n":1} \r\n';
    final context = await _host(tester);
    showFilePreviewSheet(
      context,
      FilePreviewData(name: 'report.json', text: source),
    );
    await tester.pumpAndSettle();
    await _more(tester);
    await tester.tap(find.text('Copy original file'));
    await tester.pumpAndSettle();
    expect(copies, [source]);
  });

  testWidgets('a fetch that fails says so and Try again fetches again', (
    tester,
  ) async {
    final context = await _host(tester);
    var calls = 0;
    showFilePreviewSheetLoading(
      context,
      name: 'main.dart',
      load: () async {
        calls++;
        if (calls == 1) throw StateError('network down');
        return FilePreviewData(name: 'main.dart', text: 'void main() {}\n');
      },
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open main.dart"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text("Couldn't open main.dart"), findsNothing);
    expect(find.byType(KitCodeBlock), findsOneWidget);
  });

  testWidgets('inline Markdown switches to its source; JSON is laid out', (
    tester,
  ) async {
    await _pump(
      tester,
      SingleChildScrollView(
        child: SmartTextPreview(
          data: FilePreviewData(name: 'result.md', text: '# Done\n\nAll good.'),
        ),
      ),
    );
    expect(find.byType(KitMarkdown), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('file-preview-raw-mode')));
    await tester.pumpAndSettle();
    expect(find.byType(KitCodeBlock), findsOneWidget);

    await _pump(
      tester,
      SingleChildScrollView(
        child: SmartTextPreview(
          data: FilePreviewData(name: 'out.json', text: '{"n":1}'),
        ),
      ),
    );
    final block = tester.widget<KitCodeBlock>(find.byType(KitCodeBlock));
    expect(block.text, '{\n  "n": 1\n}');
    expect(block.copyText, '{"n":1}');
  });
}
