// Golden renders of the "Clear storage" guard (slice clear-storage-guard):
// the manage-space page Android opens from App info › Storage, its delete
// question, an export in progress and finished, and This phone's Export
// projects page. Phone 412x915 (and a tall 412x1500 to show the whole
// list) and one wide window (1280x800), dark and light, real fonts.
//
// Regenerate deliberately, and look at every changed image before committing it:
//   flutter test --update-goldens test/goldens/manage_space_golden_test.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/project_export.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/manage_space_screen.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../manage_space/manage_space_screen_test.dart'
    show FakeExportPlatform, controllerFor;

const _phone = Size(412, 915);
const _tall = Size(412, 1500);
const _wide = Size(1280, 800);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required bool light,
  Size size = _phone,
  bool exportPage = false,
  FakeExportPlatform? platform,
  Future<void> Function()? act,
}) async {
  final boundary = GlobalKey();
  debugDefaultTargetPlatformOverride = TargetPlatform.android; // ARCH-11
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = controllerFor(platform ?? FakeExportPlatform());
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
        home: exportPage
            ? ProjectExportScreen(controller: controller)
            : ManageSpaceScreen(controller: controller, onClose: () {}),
      ),
    ),
  );
  await _settle(tester);
  if (act != null) {
    await act();
    await _settle(tester);
  }
  expect(tester.takeException(), isNull);
  final suffix = [
    if (size == _tall) 'full',
    if (size == _wide) '1280x800',
    light ? 'light' : 'dark',
  ].join('_');
  await expectLater(
    find.byKey(boundary),
    matchesGoldenFile('manage_space_${name}_$suffix.png'),
  );
  await tester.pumpWidget(const SizedBox.shrink());
  debugDefaultTargetPlatformOverride = null;
}

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';
    testWidgets('page ($theme)', (tester) async {
      await _shot(tester, 'page', light: light);
    });
    testWidgets('page, whole list ($theme)', (tester) async {
      await _shot(tester, 'page', light: light, size: _tall);
    });
    testWidgets('page, wide ($theme)', (tester) async {
      await _shot(tester, 'page', light: light, size: _wide);
    });
    testWidgets('delete question ($theme)', (tester) async {
      await _shot(
        tester,
        'delete',
        light: light,
        act: () =>
            tester.tap(find.byKey(const ValueKey('manage-space-delete'))),
      );
    });
  }

  testWidgets('export running (dark)', (tester) async {
    final platform = FakeExportPlatform()
      ..hold = Completer<ProjectExportResult>();
    await _shot(
      tester,
      'exporting',
      light: false,
      platform: platform,
      act: () => tester.tap(find.byKey(const ValueKey('project-export'))),
    );
  });

  testWidgets('export done (dark)', (tester) async {
    await _shot(
      tester,
      'exported',
      light: false,
      act: () => tester.tap(find.byKey(const ValueKey('project-export'))),
    );
  });

  testWidgets('export failed (light)', (tester) async {
    final platform = FakeExportPlatform()
      ..exportResult = const ProjectExportResult.failed(
        ProjectExportFailure.space,
      );
    await _shot(
      tester,
      'export_failed',
      light: true,
      platform: platform,
      act: () => tester.tap(find.byKey(const ValueKey('project-export'))),
    );
  });

  testWidgets('This phone export page (dark)', (tester) async {
    await _shot(tester, 'this_phone_export', light: false, exportPage: true);
  });
}
