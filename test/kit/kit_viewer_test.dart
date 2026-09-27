// Behaviour tests for KitViewer (docs/ux-system/kit-api/KitViewer.md
// "Tests required"). Arabic and RTL cases are dropped by the owner's
// 2026-09-27 decision; the remaining numbered cases keep the spec's numbers.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/kit/kit_page_route.dart';
import 'package:opencode_mobile/ui/kit/kit_viewer.dart';

import 'kit_harness.dart';
import 'kit_motion_still.dart';

const _phone = Size(412, 915);
const _pc = Size(1280, 800);

/// A valid 1×1 PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Opens the viewer and settles; returns the future that completes on close.
Future<void> _open(
  WidgetTester tester, {
  Size size = _phone,
  String name = 'README.md',
  String? path = '/repo/README.md',
  KitViewerSource? source,
  KitAction? primary,
  List<KitMenuItem> more = const [],
  bool? asPage,
  bool interactive = true,
  VoidCallback? onOpenAll,
  bool? wrap,
  ValueChanged<bool>? onWrapChanged,
  bool? showSource,
  ValueChanged<bool>? onShowSourceChanged,
  bool settle = true,
  void Function(Future<void> closed)? closed,
}) async {
  // A fresh tree: nothing an earlier open left on the navigator stays.
  await tester.pumpWidget(const SizedBox.shrink());
  final context = await pumpKitHost(tester, size: size);
  final future = showKitViewer(
    context,
    name: name,
    path: path,
    source:
        source ??
        const KitViewerSource(KitViewerContent.code('void main() {}\n')),
    primary: primary,
    more: more,
    asPage: asPage,
    interactive: interactive,
    onOpenAll: onOpenAll,
    wrap: wrap,
    onWrapChanged: onWrapChanged,
    showSource: showSource,
    onShowSourceChanged: onShowSourceChanged,
  );
  closed?.call(future);
  if (settle) await tester.pumpAndSettle();
}

Future<void> _openMore(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('kit-viewer-more')));
  await tester.pumpAndSettle();
}

/// The menu labels, top to bottom, among [candidates].
List<String> _menuOrder(WidgetTester tester, List<String> candidates) {
  final present = [
    for (final label in candidates)
      if (find.text(label).evaluate().isNotEmpty) label,
  ];
  present.sort(
    (a, b) => tester
        .getTopLeft(find.text(a).last)
        .dy
        .compareTo(tester.getTopLeft(find.text(b).last).dy),
  );
  return present;
}

/// Records clipboard writes.
List<String> _recordClipboard(WidgetTester tester) {
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
  return writes;
}

TextSpan? _spanWith(WidgetTester tester, String text) {
  TextSpan? found;
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span;
        return false;
      }
      return true;
    });
    if (found != null) break;
  }
  return found;
}

bool _focusIsWithin(Key key) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  var within = focused.widget.key == key;
  focused.visitAncestorElements((element) {
    if (element.widget.key == key) within = true;
    return !within;
  });
  return within;
}

Future<void> _typeFind(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const ValueKey('kit-viewer-find')), query);
  await tester.pump(KitMotion.typingSettle);
  await tester.pumpAndSettle();
}

String _countText(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('kit-viewer-find-count')),
        matching: find.byType(Text),
      ),
    )
    .data!;

void main() {
  const motionSource = KitViewerSource(KitViewerContent.text('Project notes'));
  kitMotionStillTests(
    'KitViewer',
    builds: {
      'loaded': () => const KitViewer(name: 'notes.txt', source: motionSource),
    },
    changes: {
      'content replaced': KitMotionChange(
        build: () => const KitViewer(name: 'notes.txt', source: motionSource),
        act: (tester, stage) => stage.rebuild(
          const KitViewer(
            name: 'notes.txt',
            source: KitViewerSource(KitViewerContent.text('Updated notes')),
          ),
        ),
        shows: 'Updated notes',
      ),
    },
  );
  Future<void> openMotionViewer(BuildContext context) =>
      showKitViewer(context, name: 'notes.txt', source: motionSource);
  kitMotionStillTests(
    'showKitViewer',
    opens: {'text': KitMotionOpen(openMotionViewer, shows: 'notes.txt')},
    changes: {
      'dismissed': kitModalDismiss(openMotionViewer, shows: 'notes.txt'),
    },
  );
  testWidgets('1. frame: name, path, one primary, More and Close', (
    tester,
  ) async {
    Future<void>? closed;
    var added = 0;
    await _open(
      tester,
      primary: KitAction(label: 'Add to prompt', onPressed: () => added++),
      more: [KitMenuItem.copy(label: 'Copy path', text: () => '/repo')],
      closed: (f) => closed = f,
    );
    expect(find.text('README.md'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('/repo/README.md')), findsWidgets);
    expect(find.byKey(const ValueKey('kit-viewer-primary')), findsOneWidget);
    expect(find.text('Add to prompt'), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-viewer-more')), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-viewer-close')), findsOneWidget);
    // No second Copy in the body: copying lives in More.
    expect(find.byTooltip('Copy'), findsNothing);
    expect(find.byKey(const ValueKey('kit-code-copy')), findsNothing);

    await tester.tap(find.text('Add to prompt'));
    expect(added, 1);

    var done = false;
    unawaited(closed!.then((_) => done = true));
    await tester.tap(find.byKey(const ValueKey('kit-viewer-close')));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(find.byKey(const ValueKey('kit-viewer')), findsNothing);

    // Back completes it too.
    await _open(tester, closed: (f) => closed = f);
    done = false;
    unawaited(closed!.then((_) => done = true));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('2. More: kit items first, caller items after, destructive '
      'last', (tester) async {
    await _open(
      tester,
      source: const KitViewerSource(
        KitViewerContent.markdown('# Title\n\nSome words.'),
      ),
      showSource: true,
      more: [
        KitMenuItem(label: 'Delete file', onSelected: () {}, destructive: true),
        KitMenuItem.copy(label: 'Copy path', text: () => '/repo'),
      ],
    );
    await _openMore(tester);
    expect(
      _menuOrder(tester, [
        'Find in file',
        'Copy contents',
        'Wrap lines',
        'Show source',
        'Copy path',
        'Delete file',
      ]),
      [
        'Find in file',
        'Copy contents',
        'Wrap lines',
        'Show source',
        'Copy path',
        'Delete file',
      ],
    );
  });

  testWidgets('3. loading, error with Try again, then the content', (
    tester,
  ) async {
    var calls = 0;
    var gate = Completer<KitViewerContent>();
    await _open(
      tester,
      source: KitViewerSource.load(() {
        calls++;
        return gate.future;
      }),
      settle: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('kit-skeleton-rows')), findsOneWidget);
    expect(find.text('README.md'), findsOneWidget);

    gate.completeError(StateError('disk unplugged'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open README.md"), findsOneWidget);
    expect(calls, 1);

    gate = Completer<KitViewerContent>();
    await tester.tap(find.byKey(const ValueKey('kit-viewer-retry')));
    await tester.pump();
    expect(calls, 2);
    gate.complete(const KitViewerContent.text('hello from the file'));
    await tester.pumpAndSettle();
    expect(find.textContaining('hello from the file'), findsOneWidget);
  });

  testWidgets('4. empty text says so and Copy contents is disabled', (
    tester,
  ) async {
    final writes = _recordClipboard(tester);
    await _open(
      tester,
      source: const KitViewerSource(KitViewerContent.text('')),
    );
    expect(find.text('This file is empty'), findsOneWidget);
    await _openMore(tester);
    await tester.tap(find.text('Copy contents'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
  });

  testWidgets('5. truncated: counts, and Open all only with a handler', (
    tester,
  ) async {
    const content = KitViewerContent.code('line\n', truncated: true);
    final lines = List.filled(2000, 'x').join('\n');
    await _open(
      tester,
      source: KitViewerSource(
        KitViewerContent.code(lines, truncated: true, totalLines: 5210),
      ),
    );
    expect(find.text('Showing the first 2,000 of 5,210 lines'), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-viewer-open-all')), findsNothing);

    var opened = 0;
    await _open(
      tester,
      source: KitViewerSource(
        KitViewerContent.code(lines, truncated: true, totalLines: 5210),
      ),
      onOpenAll: () => opened++,
    );
    await tester.tap(find.byKey(const ValueKey('kit-viewer-open-all')));
    await tester.pumpAndSettle();
    expect(opened, 1);

    // Unknown total: "part of this file".
    await _open(tester, source: const KitViewerSource(content));
    expect(find.text('Showing part of this file'), findsOneWidget);
  });

  testWidgets('6. links go through openExternalLink; inert when not '
      'interactive', (tester) async {
    await _open(
      tester,
      source: const KitViewerSource(
        KitViewerContent.markdown(
          'Read [the docs](https://docs.example.com/a).',
        ),
      ),
    );
    final link = _spanWith(tester, 'the docs')!;
    (link.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
    // openExternalLink's confirmation names the host before anything opens.
    expect(find.textContaining('docs.example.com'), findsWidgets);

    await _open(
      tester,
      interactive: false,
      source: const KitViewerSource(
        KitViewerContent.markdown(
          'Read [the docs](https://docs.example.com/a).',
        ),
      ),
    );
    expect(_spanWith(tester, 'the docs')!.recognizer, isNull);
  });

  testWidgets('7. Find counts, moves, wraps; Esc closes Find, then the '
      'viewer', (tester) async {
    Future<void>? closed;
    await _open(
      tester,
      source: const KitViewerSource(
        KitViewerContent.text('foo one\nfoo two\nthree foo'),
      ),
      closed: (f) => closed = f,
    );
    await _openMore(tester);
    await tester.tap(find.text('Find in file'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kit-viewer-find')), findsOneWidget);

    await _typeFind(tester, 'foo');
    expect(_countText(tester), '1 of 3');
    expect(
      tester.widget<KitCodeBlock>(find.byType(KitCodeBlock)).marks,
      hasLength(3),
    );
    await tester.tap(find.byKey(const ValueKey('kit-viewer-find-next')));
    await tester.pump();
    expect(_countText(tester), '2 of 3');
    await tester.tap(find.byKey(const ValueKey('kit-viewer-find-next')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('kit-viewer-find-next')));
    await tester.pump();
    expect(_countText(tester), '1 of 3');
    await tester.tap(find.byKey(const ValueKey('kit-viewer-find-previous')));
    await tester.pump();
    expect(_countText(tester), '3 of 3');

    var done = false;
    unawaited(closed!.then((_) => done = true));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kit-viewer-find')), findsNothing);
    expect(done, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('8. Show source swaps prose for source and reports it', (
    tester,
  ) async {
    final changes = <bool>[];
    await _open(
      tester,
      source: const KitViewerSource(
        KitViewerContent.markdown('# Title\n\nSome words.'),
      ),
      showSource: false,
      onShowSourceChanged: changes.add,
    );
    expect(find.byKey(const ValueKey('kit-code-line-1')), findsNothing);
    expect(find.textContaining('Title'), findsWidgets);
    await _openMore(tester);
    await tester.tap(find.text('Show source'));
    await tester.pumpAndSettle();
    expect(changes, [true]);
    expect(find.byKey(const ValueKey('kit-code-line-1')), findsOneWidget);
  });

  testWidgets('9. Wrap: the menu reports it; the window picks the default', (
    tester,
  ) async {
    final changes = <bool>[];
    await _open(tester, size: const Size(360, 800), onWrapChanged: changes.add);
    expect(tester.widget<KitCodeBlock>(find.byType(KitCodeBlock)).wrap, true);
    await _openMore(tester);
    await tester.tap(find.text('Wrap lines'));
    await tester.pumpAndSettle();
    expect(changes, [false]);
    expect(tester.widget<KitCodeBlock>(find.byType(KitCodeBlock)).wrap, false);

    await _open(tester, size: _pc);
    expect(tester.widget<KitCodeBlock>(find.byType(KitCodeBlock)).wrap, false);
  });

  testWidgets('10. PDF: only visible pages render; cancel on scroll-away; '
      'a failed page has its own Try again', (tester) async {
    final requested = <int>[];
    final cancelled = <int>[];
    final pending = <int, Completer<KitPdfPage>>{};
    await _open(
      tester,
      name: 'Report.pdf',
      path: null,
      source: KitViewerSource(
        KitViewerContent.pdf(
          pageCount: 12,
          renderPage: (index, widthPx) {
            requested.add(index);
            if (index == 0) return Future.error(StateError('bad page'));
            return (pending[index] = Completer<KitPdfPage>()).future;
          },
          cancelPage: cancelled.add,
        ),
      ),
    );
    expect(requested, isNotEmpty);
    expect(requested.length, lessThan(4));
    expect(requested, containsAll(<int>[0, 1]));
    // Page 1 failed on its own; page 2 is still waiting.
    expect(find.text("Couldn't show page 1"), findsOneWidget);
    expect(
      find.byKey(const ValueKey('kit-viewer-page-0-retry')),
      findsOneWidget,
    );
    pending[1]!.complete(KitPdfPage(bytes: _png, width: 100, height: 141));
    await tester.pump();
    expect(find.bySemanticsLabel('Page 2 of 12'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('kit-viewer-page-0-retry')));
    // Inside KitZoom a tap waits out the double-tap window.
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(requested.where((i) => i == 0), hasLength(2));

    // Scroll far down: the pages left behind that never rendered cancel.
    final waiting = pending.entries
        .where((e) => !e.value.isCompleted)
        .map((e) => e.key)
        .toList();
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    for (final index in waiting) {
      expect(cancelled, contains(index));
    }
    expect(requested, isNot(contains(11)), reason: 'not yet in view');
  });

  testWidgets('11. delimited: virtualised rows, sticky header, isolated '
      'cells', (tester) async {
    final rows = [
      ['name', 'city', 'note'],
      for (var i = 0; i < 500; i++) ['row $i', 'مدينة', 'n$i'],
    ];
    await _open(
      tester,
      name: 'people.csv',
      source: KitViewerSource(KitViewerContent.delimited(rows)),
    );
    expect(find.byKey(const ValueKey('kit-viewer-table')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('kit-viewer-table-row-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('kit-viewer-table-row-499')),
      findsNothing,
    );
    final arabic = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((t) => (t.data ?? '').contains('مدينة'));
    expect(arabic.data, startsWith('\u2068'));

    await tester.drag(
      find.byKey(const ValueKey('kit-viewer-table-row-2')),
      const Offset(0, -1500),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kit-viewer-table-row-0')), findsNothing);
    expect(
      find.byKey(const ValueKey('kit-viewer-table-header')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('kit-viewer-table-header')))
          .dy,
      lessThan(tester.getTopLeft(find.byType(ListView)).dy + 1),
    );
  });

  testWidgets('12. binary: type and size in words, with the caller action', (
    tester,
  ) async {
    var saved = 0;
    await _open(
      tester,
      name: 'archive.zip',
      source: const KitViewerSource(
        KitViewerContent.binary(
          mimeType: 'application/zip',
          byteLength: 2516582,
        ),
      ),
      primary: KitAction(label: 'Save', onPressed: () => saved++),
    );
    expect(find.text("Can't show this file"), findsOneWidget);
    expect(find.text('application/zip · 2.4 MB'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.text('Save'));
    expect(saved, 1);
  });

  testWidgets('13. adaptive: sheet on a phone, page on a PC, asPage forces', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byKey(const ValueKey('kit-viewer')))),
      isNot(isA<KitPageRoute<void>>()),
    );

    await _open(tester, size: _pc);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      ModalRoute.of(tester.element(find.byKey(const ValueKey('kit-viewer')))),
      isA<KitPageRoute<void>>(),
    );

    await _open(tester, asPage: true);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      ModalRoute.of(tester.element(find.byKey(const ValueKey('kit-viewer')))),
      isA<KitPageRoute<void>>(),
    );
  });

  group('14. keyboard on a PC', () {
    setUp(
      () =>
          debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop(),
    );
    tearDown(() => debugPlatformCapabilities = null);

    testWidgets('Esc closes, Ctrl+F finds, Tab reaches primary, More, '
        'Close', (tester) async {
      Future<void>? closed;
      await _open(
        tester,
        size: _pc,
        primary: KitAction(label: 'Add to prompt', onPressed: () {}),
        closed: (f) => closed = f,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kit-viewer-find')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kit-viewer-find')), findsNothing);

      final order = <String>[];
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        for (final key in [
          'kit-viewer-primary',
          'kit-viewer-more',
          'kit-viewer-close',
        ]) {
          if (_focusIsWithin(ValueKey(key))) order.add(key);
        }
      }
      expect(order, [
        'kit-viewer-primary',
        'kit-viewer-more',
        'kit-viewer-close',
      ]);

      var done = false;
      unawaited(closed!.then((_) => done = true));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });
  });

  testWidgets('15. redaction: shown masked, copied verbatim (SEC-13)', (
    tester,
  ) async {
    final writes = _recordClipboard(tester);
    const secret = 'sk-ant-FAKE0123456789abcdefghijklmnopqrstuvwxyz';
    const code = 'const key = "$secret";';
    await _open(
      tester,
      source: const KitViewerSource(
        KitViewerContent.code(code, language: 'dart'),
      ),
    );
    expect(find.textContaining('sk-ant-FAKE'), findsNothing);
    await _openMore(tester);
    await tester.tap(find.text('Copy contents'));
    await tester.pumpAndSettle();
    // SEC-13 (coordinator 2026-09-27): the person's own file is copied as
    // it is; only the screen is masked.
    expect(writes, [code]);
  });

  testWidgets('17. reduced motion: open and Find settle in one pump', (
    tester,
  ) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    unawaited(
      showKitViewer(
        context,
        name: 'a.txt',
        source: const KitViewerSource(KitViewerContent.text('abc abc')),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('a.txt'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kit-viewer-more')));
    await tester.pump();
    await tester.tap(find.text('Find in file'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('kit-viewer-find')), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('18. overflow', () {
    final name = List.filled(12, 'long-name-').join();
    final path = '/${List.filled(30, 'directory').join('/')}';
    for (final width in [320.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('${width.toInt()} dp at text $scale', (tester) async {
          tester.view.physicalSize = Size(width, 915);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          late BuildContext context;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (inner) {
                  context = inner;
                  return const SizedBox.expand();
                },
              ),
            ),
          );
          unawaited(
            showKitViewer(
              context,
              name: name,
              path: path,
              primary: KitAction(label: 'Add to prompt', onPressed: () {}),
              source: const KitViewerSource(
                KitViewerContent.code(
                  'final aVeryLongIdentifierName = computeSomethingLong();',
                  language: 'dart',
                  truncated: true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(name), findsOneWidget);
        });
      }
    }
  });
}
