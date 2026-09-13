import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/reader_preferences.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/files_screen.dart';
import 'package:opencode_mobile/ui/screens/review_workspace.dart';
import 'package:opencode_mobile/ui/widgets/diff_view.dart';
import 'package:opencode_mobile/ui/widgets/file_preview.dart';
import 'package:opencode_mobile/ui/widgets/markdown.dart';
import 'package:opencode_mobile/ui/widgets/reader_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RefusingPreferences implements SharedPreferences {
  @override
  String? getString(String key) => null;
  @override
  Future<bool> setString(String key, String value) async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedPreferences implements SharedPreferences {
  final started = Completer<void>();
  final release = Completer<void>();
  final data = <String, String>{};
  @override
  String? getString(String key) => data[key];
  @override
  Set<String> getKeys() => data.keys.toSet();
  @override
  Future<bool> remove(String key) async {
    data.remove(key);
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    started.complete();
    await release.future;
    data[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FilesApi extends OpenCodeApi {
  _FilesApi() : super(baseUrl: 'http://localhost');
  @override
  Future<List<FileNode>> listFiles([String path = '']) async => [
    FileNode(name: 'build', path: 'build', isDir: true),
    FileNode(name: 'main.dart', path: 'main.dart', isDir: false),
    FileNode(name: '.git', path: '.git', isDir: true),
    FileNode(name: 'README.md', path: 'README.md', isDir: false),
  ];
}

Future<SharedPreferences> _prefs([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

Future<void> _pump(
  WidgetTester tester,
  SharedPreferences prefs,
  Widget home, {
  String profile = 'a',
  bool rtl = false,
  double scale = 1,
  Size size = const Size(320, 740),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => ReaderPreferencesScope(
        profileId: profile,
        prefs: prefs,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: RepaintBoundary(
              key: const Key('reader-capture'),
              child: child!,
            ),
          ),
        ),
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['READER_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('reader-capture')),
  );
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  await File('$directory/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
}

Finder _horizontal() => find.byWidgetPredicate(
  (w) =>
      w is Scrollable &&
      axisDirectionToAxis(w.axisDirection) == Axis.horizontal,
);

Future<void> _chooseCodeAction(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Code options').first);
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) => widget is PopupMenuEntry,
          ),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saved choices restore per profile and deletion removes their key',
    () async {
      final prefs = await _prefs();
      final first = ReaderPreferencesStore(prefs: prefs, profileId: 'a');
      expect(first.value.wrapCode, isNull);
      expect(await first.update(sourceFirst: true, wrapCode: false), isTrue);
      final restarted = ReaderPreferencesStore(prefs: prefs, profileId: 'a');
      expect(restarted.value.sourceFirst, isTrue);
      expect(restarted.value.wrapCode, isFalse);
      final other = ReaderPreferencesStore(prefs: prefs, profileId: 'b');
      expect(other.value.sourceFirst, isFalse);
      final profiles = ProfileStore(prefs: prefs);
      expect(
        profiles.profileScopedPreferenceKeys('a'),
        contains(ReaderPreferencesStore.keyFor('a')),
      );
      expect(await profiles.removeScopedPreferences('a'), isEmpty);
      final removed = ReaderPreferencesStore(prefs: prefs, profileId: 'a');
      expect(removed.value.sourceFirst, isFalse);
      expect(removed.value.wrapCode, isNull);
      first.dispose();
      restarted.dispose();
      other.dispose();
      removed.dispose();
    },
  );

  test('storage refusal keeps prior display choices', () async {
    final store = ReaderPreferencesStore(
      prefs: _RefusingPreferences(),
      profileId: 'a',
    );
    expect(await store.update(sourceFirst: true, wrapCode: false), isFalse);
    expect(store.value.sourceFirst, isFalse);
    expect(store.value.wrapCode, isNull);
    store.dispose();
  });

  test(
    'profile deletion drains an accepted save before sweeping preferences',
    () async {
      final prefs = _DelayedPreferences();
      final store = ReaderPreferencesStore(prefs: prefs, profileId: 'a');
      final save = store.update(sourceFirst: true);
      await prefs.started.future;
      var deleted = false;
      final deletion = () async {
        await ReaderPreferencesStore.drain('a');
        await ProfileStore(prefs: prefs).removeScopedPreferences('a');
        deleted = true;
      }();
      await Future<void>.delayed(Duration.zero);
      expect(deleted, isFalse);
      prefs.release.complete();
      expect(await save, isTrue);
      await deletion;
      expect(prefs.getString(ReaderPreferencesStore.keyFor('a')), isNull);
      store.dispose();
    },
  );

  testWidgets('failed preference saves report failure without changing wrap', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      _RefusingPreferences(),
      const Scaffold(body: CodeBlock(code: 'code')),
    );
    await _chooseCodeAction(tester, 'Wrap lines');
    await tester.pumpAndSettle();
    expect(_horizontal(), findsOneWidget);
    expect(
      find.text('Could not save reader preferences. Try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'source first reorders without hiding and survives a reopened Files screen',
    (tester) async {
      final prefs = await _prefs();
      final controller = ConnectionController(ProfileStore(prefs: prefs))
        ..api = _FilesApi()
        ..status = StreamStatus.connected;
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget screen() => Scaffold(body: FilesScreen(controller: controller));
      await _pump(tester, prefs, screen());
      double top(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(top('build'), lessThan(top('main.dart')));
      await tester.tap(find.byTooltip('File order'));
      await tester.pumpAndSettle();
      await tester.tap(find.ancestor(of: find.text('Source first'), matching: find.byWidgetPredicate((widget) => widget is PopupMenuEntry)).first);
      await tester.pumpAndSettle();
      expect(top('main.dart'), lessThan(top('build')));
      for (final name in ['build', '.git', 'main.dart', 'README.md']) {
        expect(find.text(name), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, prefs, screen(), rtl: true, scale: 2.5);
      expect(top('main.dart'), lessThan(top('build')));
      expect(tester.takeException(), isNull);
      await _capture(tester, 'files-source-first-rtl-320-250');
      await tester.tap(find.byTooltip('File order'));
      await tester.pumpAndSettle();
      await tester.tap(find.ancestor(of: find.text('Default order'), matching: find.byWidgetPredicate((widget) => widget is PopupMenuEntry)).first);
      await tester.pumpAndSettle();
      expect(top('build'), lessThan(top('main.dart')));
    },
  );

  testWidgets(
    'wrap selection follows code into snapshot and a different reader',
    (tester) async {
      final prefs = await _prefs();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final code = 'final result = ${'long_value_' * 20};';
      await _pump(
        tester,
        prefs,
        Scaffold(
          body: SingleChildScrollView(child: CodeBlock(code: code)),
        ),
        rtl: true,
        scale: 2.5,
      );
      expect(_horizontal(), findsOneWidget);
      await _chooseCodeAction(tester, 'Wrap lines');
      await tester.pumpAndSettle();
      expect(_horizontal(), findsNothing);
      await _chooseCodeAction(tester, 'Full screen');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Scroll lines'), findsOneWidget);
      expect(_horizontal(), findsNothing);
      await _capture(tester, 'code-wrap-rtl-320-250');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _pump(
        tester,
        prefs,
        DiffView(
          diffs: [
            FileDiff(file: 'lib/main.dart', patch: '@@ -1 +1 @@\n-old\n+$code'),
          ],
        ),
        rtl: true,
        scale: 2.5,
      );
      expect(find.byKey(const Key('diff-view-horizontal')), findsNothing);
      await tester.tap(find.byTooltip('Scroll lines'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diff-view-horizontal')), findsOneWidget);
      final state = tester.state<ScrollableState>(_horizontal());
      expect(state.position.axisDirection, AxisDirection.right);
      expect(state.position.maxScrollExtent, greaterThan(0));
      expect(tester.takeException(), isNull);
      await _capture(tester, 'diff-scroll-rtl-320-250');
    },
  );

  testWidgets(
    'profile switch resets the displayed choice without restarting app',
    (tester) async {
      final prefs = await _prefs({
        ReaderPreferencesStore.keyFor('a'): jsonEncode({'wrapCode': true}),
      });
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const home = Scaffold(body: CodeBlock(code: 'code'));
      await _pump(tester, prefs, home);
      expect(_horizontal(), findsNothing);
      await _pump(tester, prefs, home, profile: 'b');
      expect(_horizontal(), findsOneWidget);
    },
  );

  testWidgets('review remains reachable in RTL large text and keeps code LTR', (
    tester,
  ) async {
    final prefs = await _prefs({
      ReaderPreferencesStore.keyFor('a'): jsonEncode({'wrapCode': true}),
    });
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      prefs,
      ReviewWorkspace(
        loadDiffs: () async => [
          FileDiff(
            file: 'lib/main.dart',
            patch: '@@ -1 +1 @@\n-before\n+after',
          ),
        ],
      ),
      rtl: true,
      scale: 2.5,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.text('+after')).textDirection,
      TextDirection.ltr,
    );
    await tester.tap(find.text('+after'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review-selection-bar')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'review-selection-rtl-320-250');
  });

  testWidgets('focused source honors wrap and scaled line gutters', (
    tester,
  ) async {
    final prefs = await _prefs({
      ReaderPreferencesStore.keyFor('a'): jsonEncode({'wrapCode': true}),
    });
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      prefs,
      Scaffold(
        body: FilePreviewBody(
          data: FilePreviewData(
            name: 'main.dart',
            text: List.generate(
              40,
              (i) => 'final value$i = "${'long_' * 8}";',
            ).join('\n'),
          ),
          initialLine: 12,
        ),
      ),
      rtl: true,
      scale: 2.5,
    );
    expect(_horizontal(), findsNothing);
    expect(find.byKey(const Key('file-preview-target-line')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'focused-source-rtl-320-250');
  });
}
