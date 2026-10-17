// KitProjectFileList and showKitProjectFileSheet: the "File from the
// project" tool. A search field and the files it finds; folders list their
// own files; a tap on a file returns its project-relative path.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Future<List<String>> _top(String folder) async => switch (folder) {
  '' => ['lib/', 'README.md', 'pubspec.yaml'],
  'lib' => ['lib/main.dart', 'lib/ui/'],
  'lib/ui' => ['lib/ui/app.dart'],
  _ => const [],
};

Future<List<String>> _find(String query) async => [
  for (final path in ['lib/main.dart', 'lib/ui/app.dart', 'README.md'])
    if (path.contains(query)) path,
];

Widget _list({
  Future<List<String>> Function(String query)? search,
  Future<List<String>> Function(String folder)? initial = _top,
  ValueChanged<String>? onPick,
}) => KitProjectFileList(
  search: search ?? _find,
  initial: initial,
  onPick: onPick ?? (_) {},
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _file(String path) => find.byKey(ValueKey('project-file-$path'));

Future<void> _openSheet(BuildContext context) =>
    showKitProjectFileSheet(context, search: _find, initial: _top);

void main() {
  // G8x (MOT-7): the list changes what it shows after a search and a folder
  // tap; under stillness it settles in one frame either way.
  kitMotionStillTests(
    'KitProjectFileList',
    builds: {'top level': _list},
    changes: {
      'a folder opens': KitMotionChange(
        build: _list,
        act: (tester, stage) async {
          await tester.pump();
          await stage.press(find.byKey(const ValueKey('project-folder-lib/')));
          await tester.pump();
        },
        shows: 'Back',
      ),
    },
  );
  kitMotionStillTests(
    'showKitProjectFileSheet',
    opens: {'default': const KitMotionOpen(_openSheet, shows: 'Project files')},
    changes: {'dismissed': kitModalDismiss(_openSheet, shows: 'Project files')},
  );

  testWidgets('it lists the top level first, folders and files', (
    tester,
  ) async {
    await _pump(tester, _list());
    expect(find.byKey(const ValueKey('project-folder-lib/')), findsOneWidget);
    expect(_file('README.md'), findsOneWidget);
    expect(_file('pubspec.yaml'), findsOneWidget);
  });

  testWidgets('a tap on a file returns its project-relative path', (
    tester,
  ) async {
    final picked = <String>[];
    await _pump(tester, _list(onPick: picked.add));
    await tester.tap(_file('README.md'));
    expect(picked, ['README.md']);
  });

  testWidgets('a folder lists its files, and Back returns to the parent', (
    tester,
  ) async {
    await _pump(tester, _list());
    await tester.tap(find.byKey(const ValueKey('project-folder-lib/')));
    await tester.pumpAndSettle();
    expect(_file('lib/main.dart'), findsOneWidget);
    expect(find.byKey(const Key('project-file-back')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('project-folder-lib/ui/')));
    await tester.pumpAndSettle();
    expect(_file('lib/ui/app.dart'), findsOneWidget);
    await tester.tap(find.byKey(const Key('project-file-back')));
    await tester.pumpAndSettle();
    expect(_file('lib/main.dart'), findsOneWidget);
    await tester.tap(find.byKey(const Key('project-file-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-file-back')), findsNothing);
    expect(_file('pubspec.yaml'), findsOneWidget);
  });

  testWidgets('typing searches files only', (tester) async {
    await _pump(tester, _list());
    await tester.enterText(find.byKey(const Key('project-file-search')), 'app');
    await tester.pumpAndSettle();
    expect(_file('lib/ui/app.dart'), findsOneWidget);
    expect(_file('README.md'), findsNothing);
    expect(find.byKey(const ValueKey('project-folder-lib/')), findsNothing);
  });

  testWidgets('an empty top level says what to do', (tester) async {
    await _pump(tester, _list(initial: (_) async => const []));
    expect(find.byKey(const Key('project-file-hint')), findsOneWidget);
  });

  testWidgets('a search with no match names the query and clears', (
    tester,
  ) async {
    await _pump(tester, _list());
    await tester.enterText(
      find.byKey(const Key('project-file-search')),
      'zzzz',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('zzzz'), findsWidgets);
    expect(_file('README.md'), findsNothing);
  });

  testWidgets('a failed search says so in plain words and retries', (
    tester,
  ) async {
    var fail = true;
    await _pump(
      tester,
      _list(
        initial: (_) async {
          if (fail) throw StateError('connection refused: 10.0.0.9');
          return ['README.md'];
        },
      ),
    );
    expect(find.byKey(const Key('project-file-error')), findsOneWidget);
    expect(find.textContaining('connection refused'), findsNothing);
    expect(find.byKey(const Key('project-file-search')), findsOneWidget);
    fail = false;
    await tester.tap(find.byKey(const Key('project-file-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-file-error')), findsNothing);
    expect(_file('README.md'), findsOneWidget);
  });

  testWidgets('the sheet loading bar runs while a search is out', (
    tester,
  ) async {
    final loading = ValueNotifier<bool>(false);
    addTearDown(loading.dispose);
    final gate = Completer<List<String>>();
    await _pump(
      tester,
      KitProjectFileList(
        search: (_) => gate.future,
        initial: _top,
        loading: loading,
        onPick: (_) {},
      ),
    );
    expect(loading.value, isFalse);
    await tester.enterText(find.byKey(const Key('project-file-search')), 'a');
    await tester.pump(const Duration(milliseconds: 600));
    expect(loading.value, isTrue);
    gate.complete(['a.txt']);
    await tester.pumpAndSettle();
    expect(loading.value, isFalse);
  });

  testWidgets('it fits at text 2.0 in English and Arabic', (tester) async {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      await _pump(tester, _list(), textScale: 2, locale: locale);
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });

  testWidgets('the sheet returns the chosen path and takes its own key', (
    tester,
  ) async {
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold();
          },
        ),
      ),
    );
    final result = showKitProjectFileSheet(
      host,
      search: _find,
      initial: _top,
      sheetKey: const Key('my-files'),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-files')), findsOneWidget);
    expect(find.byKey(const Key('project-file-sheet')), findsNothing);
    await tester.tap(_file('README.md'));
    await tester.pumpAndSettle();
    expect(await result, 'README.md');
  });
}
