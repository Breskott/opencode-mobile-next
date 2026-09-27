// KitDiffView (docs/ux-system/kit-api/KitDiffView.md, "Tests required"):
// parser, gaps, mode, file list, navigator, not colour alone, selection,
// copy (verbatim, SEC-13), states, too big, wrap, RTL, virtualisation,
// reduced motion (G8x) and the overflow matrix (G6). The wrapper's own
// compatibility (test 12) is test/diff_view_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';
import 'package:opencode_mobile/ui/kit/kit_diff_view.dart';
import 'package:opencode_mobile/ui/kit/kit_icon_button.dart';

import 'kit_motion_still.dart';

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool reduced = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.dark(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, widget) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduced,
    ),
    child: widget!,
  ),
  home: Scaffold(body: child),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(412, 915),
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool reduced = false,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(child, locale: locale, textScale: textScale, reduced: reduced),
  );
  await tester.pumpAndSettle();
}

const _twoHunks =
    '--- a/lib/a.dart\n'
    '+++ b/lib/a.dart\n'
    '@@ -10,3 +10,4 @@\n'
    ' context ten\n'
    '-old eleven\n'
    '+new eleven\n'
    '+new twelve\n'
    ' context twelve\n'
    '@@ -60,2 +61,2 @@\n'
    ' context sixty\n'
    '-old sixty-one\n'
    '+new sixty-two\n';

List<String> _numbered(int n, [String prefix = 'line']) => [
  for (var i = 1; i <= n; i++) '$prefix $i',
];

/// 60 lines with line 31 changed.
KitDiffFile _sixty([String path = 'notes.txt']) {
  final before = _numbered(60);
  final after = [...before]..[30] = 'changed line 31';
  return KitDiffFile.fromTexts(
    path,
    before: before.join('\n'),
    after: after.join('\n'),
  );
}

/// [changes] single-line changes, 20 lines apart.
KitDiffFile _spaced(String path, int changes) {
  final before = _numbered(changes * 20 + 10, path);
  final after = [...before];
  for (var c = 0; c < changes; c++) {
    after[10 + c * 20] = 'changed $path ${c + 1}';
  }
  return KitDiffFile.fromTexts(
    path,
    before: before.join('\n'),
    after: after.join('\n'),
  );
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  group('1. parser', () {
    test('fromPatch: counts, numbers and hunk lines', () {
      final file = KitDiffFile.fromPatch('lib/a.dart', _twoHunks);
      expect(file.added, 3);
      expect(file.removed, 2);
      expect(file.changeCount, 2);
      final lines = file.segments.whereType<KitDiffLine>().toList();
      final hunks = lines.where((l) => l.kind == KitDiffLineKind.hunk);
      expect(hunks, hasLength(2));
      expect(hunks.first.newNo, 10);
      final removed = lines.firstWhere((l) => l.text == 'old eleven');
      expect((removed.kind, removed.oldNo), (KitDiffLineKind.removed, 11));
      final added = lines.firstWhere((l) => l.text == 'new twelve');
      expect((added.kind, added.newNo), (KitDiffLineKind.added, 12));
      final kept = lines.firstWhere((l) => l.text == 'context twelve');
      expect((kept.oldNo, kept.newNo), (12, 13));
      // The skipped lines before and between hunks are count-only gaps.
      final gaps = file.segments.whereType<KitDiffGap>().toList();
      expect(gaps.map((g) => (g.count, g.lines)), [(9, null), (47, null)]);
    });

    test('fromTexts folds unchanged runs with 3 context lines', () {
      final file = _sixty();
      expect((file.added, file.removed, file.changeCount), (1, 1, 1));
      final first = file.segments.first as KitDiffGap;
      expect(first.count, 27);
      expect(first.lines, hasLength(27));
      final visible = file.segments
          .whereType<KitDiffLine>()
          .map((l) => l.text)
          .toList();
      expect(visible, [
        'line 28',
        'line 29',
        'line 30',
        'line 31',
        'changed line 31',
        'line 32',
        'line 33',
        'line 34',
      ]);
      expect((file.segments.last as KitDiffGap).count, 26);
    });

    test('fromTexts(after:) alone is an added file', () {
      final file = KitDiffFile.fromTexts('new.txt', after: 'a\nb');
      expect(file.status, KitDiffFileStatus.added);
      expect((file.added, file.removed), (2, 0));
      final deleted = KitDiffFile.fromTexts('old.txt', before: 'a');
      expect(deleted.status, KitDiffFileStatus.deleted);
    });

    test('fromTexts finds separate changes, not one block', () {
      expect(_spaced('a', 3).changeCount, 3);
    });
  });

  testWidgets('2. gaps reveal 20 lines per tap, collapse, and a patch gap '
      'only states its count', (tester) async {
    await _pump(tester, KitDiffView(files: [_sixty()]));
    expect(find.text('line 27'), findsNothing);
    expect(find.text('Show 20 unchanged lines'), findsWidgets);
    expect(
      tester.getSize(_key('kit-diff-gap-0')).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(_key('kit-diff-gap-0'));
    await tester.pumpAndSettle();
    expect(find.text('line 8'), findsOneWidget);
    expect(find.text('line 7'), findsNothing);
    expect(find.text('Show 7 unchanged lines'), findsOneWidget);

    await tester.tap(_key('kit-diff-collapse-0'));
    await tester.pumpAndSettle();
    expect(find.text('line 8'), findsNothing);
    expect(find.text('changed line 31'), findsOneWidget);

    await _pump(
      tester,
      KitDiffView(files: [KitDiffFile.fromPatch('lib/a.dart', _twoHunks)]),
    );
    expect(find.text('9 unchanged lines'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('kit-diff-gap-0'),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    // Hunk headers read as line ranges.
    expect(find.text('Lines 10–13'), findsOneWidget);
  });

  group('3. mode follows the diff box', () {
    final file = KitDiffFile.fromTexts(
      'a.dart',
      before: 'keep\nold value',
      after: 'keep\nnew value',
    );
    bool sideBySide(WidgetTester tester) =>
        tester.getTopLeft(find.text('old value')).dy ==
        tester.getTopLeft(find.text('new value')).dy;

    testWidgets('auto: unified at 412, split at 1280', (tester) async {
      await _pump(tester, KitDiffView(files: [file]));
      expect(sideBySide(tester), isFalse);
      await _pump(
        tester,
        KitDiffView(files: [file]),
        size: const Size(1280, 800),
      );
      expect(sideBySide(tester), isTrue);
    });

    testWidgets('split in a 412 box renders unified', (tester) async {
      await _pump(tester, KitDiffView(files: [file], mode: KitDiffMode.split));
      expect(sideBySide(tester), isFalse);
    });

    testWidgets('a 340 dp box on a 1600 dp window renders unified', (
      tester,
    ) async {
      await _pump(
        tester,
        Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: 340, child: KitDiffView(files: [file])),
        ),
        size: const Size(1600, 1000),
      );
      expect(sideBySide(tester), isFalse);
    });
  });

  group('4. files', () {
    final files = [
      _spaced('lib/one.dart', 1),
      _spaced('lib/two.dart', 1),
      _spaced('lib/three.dart', 1),
    ];

    testWidgets('a 1600 dp box shows the file list', (tester) async {
      await _pump(
        tester,
        KitDiffView(files: files),
        size: const Size(1600, 1000),
      );
      expect(_key('kit-diff-file-list'), findsOneWidget);
      expect(_key('kit-diff-file-picker'), findsNothing);
      await tester.tap(_key('kit-diff-file-row-2'));
      await tester.pumpAndSettle();
      expect(_key('kit-diff-file-header-lib/three.dart'), findsOneWidget);
    });

    testWidgets('412: the picker sheet lists the files and opens one', (
      tester,
    ) async {
      await _pump(tester, KitDiffView(files: files));
      expect(_key('kit-diff-file-list'), findsNothing);
      expect(find.text('3 files'), findsOneWidget);
      await tester.tap(_key('kit-diff-file-picker'));
      await tester.pumpAndSettle();
      for (final path in ['lib/one.dart', 'lib/two.dart', 'lib/three.dart']) {
        expect(find.text(KitBidi.ltr(path)), findsOneWidget);
      }
      expect(find.text('+1 −1'), findsWidgets);
      await tester.tap(find.text(KitBidi.ltr('lib/three.dart')));
      await tester.pumpAndSettle();
      expect(_key('kit-diff-file-header-lib/three.dart'), findsOneWidget);
      expect(find.text('changed lib/three.dart 1'), findsOneWidget);
    });
  });

  testWidgets('5. the navigator moves across files and announces politely', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      KitDiffView(files: [_spaced('a.txt', 3), _spaced('b.txt', 3)]),
    );
    expect(find.text('Change 1 of 6'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(_key('kit-diff-nav-next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Change 6 of 6'), findsOneWidget);
    expect(_key('kit-diff-file-header-b.txt'), findsOneWidget);
    expect(find.text('changed b.txt 3'), findsOneWidget);

    // The keyboard: the diff holds focus after a move.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pumpAndSettle();
    expect(find.text('Change 5 of 6'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();
    }
    expect(find.text('Change 2 of 6'), findsOneWidget);
    expect(_key('kit-diff-file-header-a.txt'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(find.text('Change 3 of 6'), findsOneWidget);

    // One polite live region carries the label.
    final label = tester.getSemantics(_key('kit-diff-nav-label'));
    expect(label.label, 'Change 3 of 6');
    expect(
      find.ancestor(
        of: _key('kit-diff-nav-label'),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('6. change identity is spoken and shown, not colour alone', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      KitDiffView(
        files: [
          KitDiffFile.fromTexts(
            'a.dart',
            before: 'old value',
            after: 'new value',
          ),
        ],
      ),
    );
    expect(find.text('+'), findsOneWidget);
    expect(find.text('−'), findsOneWidget);
    expect(find.bySemanticsLabel('Line 1 added: new value'), findsOneWidget);
    expect(find.bySemanticsLabel('Line 1 removed: old value'), findsOneWidget);
    semantics.dispose();
  });

  group('7-8. selection', () {
    List<MethodCall> clipboard = [];
    List<Object?> announcements = [];
    setUp(() {
      clipboard = [];
      announcements = [];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard.add(call);
        return null;
      });
      messenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        (message) async {
          announcements.add(message);
          return null;
        },
      );
    });
    tearDown(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        null,
      );
    });

    const secret = 'sk-ant-FAKE0123456789abcdefghijklmnopqrstuvwxyz';
    KitDiffFile file() {
      final before = _numbered(20);
      final after = [...before]
        ..[11] = 'new twelve'
        ..[12] = 'key = "$secret"'
        ..[13] = 'new fourteen';
      return KitDiffFile.fromTexts(
        'lib/a.dart',
        before: before.join('\n'),
        after: after.join('\n'),
      );
    }

    testWidgets('7. drag line numbers 12-14, Comment, Esc', (tester) async {
      final comments = <KitDiffSelection>[];
      await _pump(
        tester,
        KitDiffView(files: [file()], readOnly: false, onComment: comments.add),
      );
      final from = tester.getCenter(_key('kit-diff-line-0-current-12'));
      final to = tester.getCenter(_key('kit-diff-line-0-current-14'));
      await tester.timedDragFrom(
        from,
        to - from,
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 lines selected'), findsOneWidget);
      expect(_key('kit-diff-selection-bar'), findsOneWidget);
      expect(
        tester.getSize(_key('kit-diff-line-0-current-12')).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.text('Comment'));
      await tester.pumpAndSettle();
      expect(comments, hasLength(1));
      final selection = comments.single;
      expect(selection.side, KitDiffSide.current);
      expect((selection.startLine, selection.endLine), (12, 14));
      // The handler gets the lines redacted (G12).
      expect(selection.text, startsWith('new twelve\nkey = '));
      expect(selection.text, isNot(contains(secret)));
      expect(selection.text, endsWith('new fourteen'));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_key('kit-diff-selection-bar'), findsNothing);
    });

    testWidgets('7. a drag that starts on an unchanged line keeps going', (
      tester,
    ) async {
      await _pump(
        tester,
        KitDiffView(files: [file()], readOnly: false, onComment: (_) {}),
      );
      // Selecting line 10 tints its row; the drag must survive that.
      final from = tester.getCenter(_key('kit-diff-line-0-current-10'));
      final to = tester.getCenter(_key('kit-diff-line-0-current-12'));
      await tester.timedDragFrom(
        from,
        to - from,
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 lines selected'), findsOneWidget);
    });

    testWidgets('7. read-only offers no selection', (tester) async {
      await _pump(tester, KitDiffView(files: [file()]));
      expect(_key('kit-diff-line-0-current-12'), findsNothing);
      expect(find.text('new twelve'), findsOneWidget);
    });

    testWidgets('8. Copy lines copies verbatim, announces once, no SnackBar', (
      tester,
    ) async {
      await _pump(
        tester,
        KitDiffView(files: [file()], readOnly: false, onAddToPrompt: (_) {}),
      );
      await tester.tap(_key('kit-diff-line-0-current-13'));
      await tester.pumpAndSettle();
      expect(find.text('1 line selected'), findsOneWidget);
      await tester.tap(find.text('Copy lines'));
      await tester.pumpAndSettle();
      expect(clipboard, hasLength(1));
      // SEC-13: a diff is the person's own content; it copies verbatim.
      expect((clipboard.single.arguments as Map)['text'], 'key = "$secret"');
      expect(
        announcements.where((m) => m is Map && m['type'] == 'announce'),
        hasLength(1),
      );
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('9. states', () {
    testWidgets('loading shows skeleton lines', (tester) async {
      await _pump(tester, const KitDiffView(files: [], loading: true));
      await tester.pump();
      expect(_key('kit-skeleton-rows'), findsOneWidget);
    });

    testWidgets('empty says No changes', (tester) async {
      await _pump(tester, const KitDiffView(files: []));
      expect(find.text('No changes'), findsOneWidget);
    });

    testWidgets('error shows the words and Try again', (tester) async {
      var retried = 0;
      await _pump(
        tester,
        KitDiffView(
          files: const [],
          error: 'The server stopped answering.',
          onRetry: () => retried++,
        ),
      );
      expect(find.text("Couldn't load the changes"), findsOneWidget);
      expect(find.text('The server stopped answering.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(retried, 1);
    });

    testWidgets('binary and renamed files', (tester) async {
      await _pump(
        tester,
        const KitDiffView(
          files: [
            KitDiffFile(
              path: 'assets/logo.png',
              segments: [],
              added: 0,
              removed: 0,
              binary: true,
            ),
          ],
        ),
      );
      expect(find.text('Binary file · not shown'), findsOneWidget);
      await _pump(
        tester,
        KitDiffView(
          files: [
            KitDiffFile(
              path: 'lib/new.dart',
              segments: const [KitDiffLine('x', KitDiffLineKind.context)],
              added: 0,
              removed: 0,
              status: KitDiffFileStatus.renamed,
              oldPath: 'lib/old.dart',
            ),
          ],
        ),
      );
      expect(find.textContaining('Renamed from'), findsOneWidget);
      expect(find.textContaining('lib/old.dart'), findsOneWidget);
    });
  });

  testWidgets('10. too big: "Showing 400 of 3,200 lines" and Open all', (
    tester,
  ) async {
    var opened = 0;
    await _pump(
      tester,
      KitDiffView(
        files: [
          KitDiffFile.fromTexts('big.txt', after: _numbered(3200).join('\n')),
        ],
        maxLines: 400,
        onOpenAll: () => opened++,
      ),
    );
    expect(find.text('Showing 400 of 3,200 lines'), findsOneWidget);
    await tester.tap(_key('kit-diff-open-all'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('11. wrap: hanging indent at 412, sideways at 1280', (
    tester,
  ) async {
    final long = 'value ${'longer ' * 60}';
    final file = KitDiffFile.fromTexts('a.dart', before: 'x', after: long);
    await _pump(tester, KitDiffView(files: [file]));
    expect(_key('kit-diff-horizontal'), findsNothing);
    final wrapped = tester.getRect(find.text(long));
    expect(wrapped.height, greaterThan(40));
    // The continuation lines start at the text column, after the gutter.
    expect(wrapped.left, greaterThan(tester.getRect(find.text('+')).right - 1));

    final changes = <bool>[];
    await _pump(
      tester,
      KitDiffView(files: [file], onWrapChanged: changes.add),
      size: const Size(1280, 800),
    );
    expect(_key('kit-diff-horizontal'), findsOneWidget);
    await tester.tap(find.byTooltip('Wrap lines'));
    await tester.pumpAndSettle();
    expect(changes, [true]);
    expect(_key('kit-diff-horizontal'), findsNothing);
  });

  testWidgets('13. under Arabic the diff stays LTR, old side on the left', (
    tester,
  ) async {
    await _pump(
      tester,
      KitDiffView(
        files: [
          KitDiffFile.fromTexts(
            'a.dart',
            before: 'old value',
            after: 'new value',
          ),
        ],
      ),
      size: const Size(1280, 800),
      locale: const Locale('ar'),
    );
    expect(
      tester.getCenter(find.text('old value')).dx,
      lessThan(tester.getCenter(find.text('new value')).dx),
    );
    expect(
      Directionality.of(tester.element(find.text('new value'))),
      TextDirection.ltr,
    );
  });

  testWidgets('14. a 10,000-line file builds only visible rows', (
    tester,
  ) async {
    await _pump(
      tester,
      KitDiffView(
        files: [
          KitDiffFile.fromTexts('big.txt', after: _numbered(10000).join('\n')),
        ],
      ),
    );
    expect(find.text('line 1'), findsOneWidget);
    expect(find.text('line 9999'), findsNothing);
    expect(find.textContaining(RegExp(r'^line \d+$')), findsWidgets);
    expect(
      tester.widgetList(find.textContaining(RegExp(r'^line \d+$'))).length,
      lessThan(200),
    );
  });

  testWidgets('15. reduced motion: navigation settles after one pump', (
    tester,
  ) async {
    await _pump(
      tester,
      KitDiffView(files: [_spaced('a.txt', 4)], initialChange: 1),
      reduced: true,
    );
    expect(find.text('Change 2 of 4'), findsOneWidget);
    // Pressed through its callback, as kit_motion_still does: a synthetic
    // tap would start Material's ink splash, which ignores reduced motion.
    tester.widget<KitIconButton>(_key('kit-diff-nav-next')).onPressed!();
    await tester.pump();
    expect(find.text('Change 3 of 4'), findsOneWidget);
    expect(find.text('changed a.txt 3'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  kitMotionStillTests(
    'KitDiffView',
    builds: {
      'default': () => KitDiffView(files: [_sixty()]),
    },
    changes: {
      'expand gap': KitMotionChange(
        build: () => KitDiffView(files: [_sixty()]),
        act: (tester, stage) => stage.press(
          find.descendant(
            of: _key('kit-diff-gap-0'),
            matching: find.byType(InkWell),
          ),
        ),
        shows: 'line 27',
      ),
    },
  );

  group('16. overflow (G6)', () {
    final path = 'lib/${'deep_folder_name/' * 8}${'x' * 6}.dart';
    final file = KitDiffFile.fromTexts(
      path.substring(0, 150),
      before: 'short',
      after: 'y' * 400,
    );
    for (final width in [320.0, 412.0, 600.0, 840.0, 1280.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('${width.toInt()} dp at text $scale', (tester) async {
          await _pump(
            tester,
            KitDiffView(
              files: [file, _sixty()],
              readOnly: false,
              onComment: (_) {},
            ),
            size: Size(width, 800),
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
