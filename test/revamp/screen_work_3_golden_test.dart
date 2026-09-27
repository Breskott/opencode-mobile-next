// Golden renders of screen-work-3's pages (wave 2b): Cloud environments
// (loaded, no provider, error, the create sheet and the remove question),
// Project health (loaded, no git, error, the Initialize Git question) and
// the two project folder dialogs, rebuilt from kit parts. Phone 412x915 and
// one wide window (1280x800), dark and light (owner decision 2026-09-27: no
// Arabic), with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_work_3_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/ui/screens/managed_workspaces_screen.dart';
import 'package:opencode_mobile/ui/screens/project_folder_actions.dart';
import 'package:opencode_mobile/ui/screens/project_health_screen.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import 'screen_work_3_fixtures.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

/// Pushes [screen] as the app does, runs [then] (open a sheet, type),
/// settles, and compares the whole window.
Future<void> _shot(
  WidgetTester tester,
  String shot,
  Widget screen, {
  required bool light,
  required Size size,
  Future<void> Function(WidgetTester tester)? then,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: sw3Host(
          screen,
          theme: captureTheme(light: light),
          disableAnimations: true,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('sw3-open')));
    await tester.pumpAndSettle();
    if (then != null) await then(tester);
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

/// A page whose only content starts [action] on a tap.
Widget _launcher(Future<Object?> Function(BuildContext context) action) =>
    Material(
      child: Builder(
        builder: (context) => Center(
          child: GestureDetector(
            key: const ValueKey('sw3-run'),
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(action(context)),
            child: const SizedBox.square(dimension: 48),
          ),
        ),
      ),
    );

Future<void> _run(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('sw3-run')));
  await tester.pumpAndSettle();
}

const _noGit = VersionControlHealth(
  setupState: VersionControlSetupState.absent,
  changes: [],
);

void main() {
  setUpAll(loadCaptureFonts);
  tearDown(() {
    ProjectFolderActions.canCreateOverride = null;
    ProjectFolderActions.createFolderOverride = null;
  });

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';
    for (final size in [_phone, _wide]) {
      final where = '$theme, ${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('cloud environments loaded ($where)', (tester) async {
        final controller = await sw3Controller()
          ..workspace = 'wrk_ci';
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'work_managed_workspaces_loaded',
          ManagedWorkspacesScreen(controller: controller, project: sw3Project),
          light: light,
          size: size,
        );
      });

      testWidgets('cloud environments, no provider ($where)', (tester) async {
        final controller = await sw3Controller(
          Sw3Repository()
            ..workspaces = []
            ..adapters = const [],
        );
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'work_managed_workspaces_no_provider',
          ManagedWorkspacesScreen(controller: controller, project: sw3Project),
          light: light,
          size: size,
        );
      });

      testWidgets('cloud environments error ($where)', (tester) async {
        final controller = await sw3Controller(
          Sw3Repository()
            ..workspacesError = const ProductException(
              'Could not list environments: adapter daytona is not '
              'configured',
            ),
        );
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'work_managed_workspaces_error',
          ManagedWorkspacesScreen(controller: controller, project: sw3Project),
          light: light,
          size: size,
        );
      });

      testWidgets('new cloud environment sheet ($where)', (tester) async {
        final controller = await sw3Controller();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'work_managed_workspaces_create_sheet_form',
          ManagedWorkspacesScreen(controller: controller, project: sw3Project),
          light: light,
          size: size,
          then: (tester) async {
            await tester.tap(
              find.byKey(const ValueKey('create-managed-workspace')),
            );
          },
        );
      });

      testWidgets('remove cloud environment ($where)', (tester) async {
        final controller = await sw3Controller()
          ..workspace = 'wrk_perf';
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'work_managed_workspaces_remove_sheet_typing',
          ManagedWorkspacesScreen(controller: controller, project: sw3Project),
          light: light,
          size: size,
          then: (tester) async {
            await tester.longPress(
              find.byKey(const ValueKey('managed-workspace-wrk_perf')),
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('environment-menu-remove')),
            );
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const ValueKey('kit-confirm-typed-name')),
              'perf',
            );
          },
        );
      });

      testWidgets('project health loaded ($where)', (tester) async {
        final controller = await sw3Controller();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'work_project_health_loaded',
          ProjectHealthScreen(repository: controller.fake),
          light: light,
          size: size,
        );
      });

      testWidgets('project health without git ($where)', (tester) async {
        final repository = Sw3Repository()..versionControl = _noGit;
        await _shot(
          tester,
          'work_project_health_no_git',
          ProjectHealthScreen(repository: repository),
          light: light,
          size: size,
        );
      });

      testWidgets('project health error ($where)', (tester) async {
        final repository = Sw3Repository()
          ..versionControlError = const ProductException(
            'Version control status is unavailable on this server',
          );
        await _shot(
          tester,
          'work_project_health_error',
          ProjectHealthScreen(repository: repository),
          light: light,
          size: size,
        );
      });

      testWidgets('initialize git question ($where)', (tester) async {
        final repository = Sw3Repository()..versionControl = _noGit;
        await _shot(
          tester,
          'work_project_health_git_init_sheet_confirming',
          ProjectHealthScreen(repository: repository),
          light: light,
          size: size,
          then: (tester) async {
            await tester.tap(
              find.byKey(const ValueKey('initialize-git-repository')),
            );
          },
        );
      });

      testWidgets('new folder dialog ($where)', (tester) async {
        final controller = await sw3Controller();
        addTearDown(controller.dispose);
        ProjectFolderActions.canCreateOverride = true;
        ProjectFolderActions.createFolderOverride = (name) async =>
            '/root/projects/$name';
        await _shot(
          tester,
          'work_project_folder_new_dialog_typing',
          _launcher(
            (context) => ProjectFolderActions.createFolder(context, controller),
          ),
          light: light,
          size: size,
          then: (tester) async {
            await _run(tester);
            await tester.enterText(
              find.byKey(const ValueKey('new-folder-name')),
              'loyalty-app',
            );
          },
        );
      });

      testWidgets('open folder dialog, no folder there ($where)', (
        tester,
      ) async {
        final controller = await sw3Controller()
          ..probeProblem = 'There is no folder at /home/dev/loyalty-app.';
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'work_project_folder_open_dialog_missing',
          _launcher(
            (context) => ProjectFolderActions.openFolder(context, controller),
          ),
          light: light,
          size: size,
          then: (tester) async {
            await _run(tester);
            await tester.enterText(
              find.byKey(const ValueKey('open-folder-path')),
              '/home/dev/loyalty-app',
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('open-folder-confirm')));
          },
        );
      });
    }
  }
}
