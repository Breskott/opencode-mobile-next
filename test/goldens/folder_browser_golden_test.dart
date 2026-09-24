// Golden renders of "Open a project" for OpenCode inside the app, the
// folder browser (lib/ui/widgets/folder_browser.dart, design standard §6
// and §10): at the projects folder, inside a folder, loading, empty and a
// folder that cannot be shown, at 412x915, dark and light, with the app's
// real fonts; and its drawing, a folder opening, on its own.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/folder_browser_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_folders.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/kit/scenes/folders_open_scene.dart';
import 'package:opencode_mobile/ui/widgets/folder_browser.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

enum FolderBrowserScene { projects, inside, loading, empty, error }

List<FolderEntry> _entries(String path, List<(String, bool)> names) => [
  for (final (name, git) in names)
    FolderEntry(name: name, path: '$path/$name', isGit: git),
];

FolderLister _lister(FolderBrowserScene scene) => switch (scene) {
  FolderBrowserScene.projects => (path) async => _entries(path, [
    ('demo', true),
    ('landing-page', true),
    ('notes', false),
    ('opencode-mobile', true),
    ('scratch', false),
  ]),
  FolderBrowserScene.inside => (path) async => _entries(path, [
    ('android', false),
    ('assets', false),
    ('docs', false),
    ('lib', false),
    ('packages', false),
    ('test', false),
  ]),
  FolderBrowserScene.loading => (_) => Completer<List<FolderEntry>>().future,
  FolderBrowserScene.empty => (_) async => const [],
  FolderBrowserScene.error => (path) async => throw FolderListException(
    FolderListProblem.denied,
    "PathAccessException: Directory listing failed, path = '$path' "
    '(OS Error: Permission denied, errno = 13)',
  ),
};

/// Mounts the sheet over an empty screen, as the Work tab shows it.
Future<void> mountFolderBrowser(
  WidgetTester tester,
  FolderBrowserScene scene, {
  required bool light,
  required GlobalKey boundary,
  Size size = const Size(412, 915),
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final start = scene == FolderBrowserScene.inside
      ? '/root/projects/opencode-mobile'
      : '/root/projects';
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: captureTheme(light: light),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showModalBottomSheet<FolderBrowserChoice>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => FolderBrowserSheet(
                  list: _lister(scene),
                  knownProjects: () async => {'/root/projects/demo'},
                  start: start,
                ),
              );
            });
            return const Scaffold();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  if (scene == FolderBrowserScene.loading) {
    // The sheet slides up; the skeleton shows once listing is slow.
    await tester.pump(const Duration(seconds: 1));
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final scene in FolderBrowserScene.values) {
      final name = 'folder_browser_${scene.name}';
      testWidgets('$name · $mode', (tester) async {
        final boundary = GlobalKey();
        await mountFolderBrowser(
          tester,
          scene,
          light: light,
          boundary: boundary,
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(boundary),
          matchesGoldenFile('${name}_$mode.png'),
        );
      });
    }

    // The smallest phone the app supports, at twice the text size, in
    // Arabic: the folders scroll above the actions, paths stay left to right.
    testWidgets('folder_browser_compact_ar · $mode', (tester) async {
      final boundary = GlobalKey();
      await mountFolderBrowser(
        tester,
        FolderBrowserScene.projects,
        light: light,
        boundary: boundary,
        size: const Size(320, 640),
        locale: const Locale('ar'),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('folder_browser_compact_ar_$mode.png'),
      );
    });

    testWidgets('kit_folders_open · $mode', (tester) async {
      final theme = light ? AppTheme.light() : AppTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('scene'),
                child: ColoredBox(
                  color: theme.colorScheme.surface,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: KitIllustration(scene: KitFoldersOpenScene()),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('scene')),
        matchesGoldenFile('kit_folders_open_$mode.png'),
      );
    });
  }
}
