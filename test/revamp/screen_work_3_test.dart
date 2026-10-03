// screen-work-3 (wave 2b): Cloud environments, Project health and the
// project folder dialogs rebuilt from kit parts, with the map's missing
// states and actions. Tests assert what the person sees and what is sent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/ui/screens/managed_workspaces_screen.dart';
import 'package:opencode_mobile/ui/screens/project_folder_actions.dart';
import 'package:opencode_mobile/ui/screens/project_health_screen.dart';

import 'screen_work_3_fixtures.dart';

Future<void> _open(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(sw3Host(screen));
  await tester.tap(find.byKey(const ValueKey('sw3-open')));
  await tester.pumpAndSettle();
}

void main() {
  group('Cloud environments', () {
    testWidgets('no provider: says where to set one up, offers no New', (
      tester,
    ) async {
      final repository = Sw3Repository()
        ..workspaces = []
        ..adapters = const [];
      final controller = await sw3Controller(repository);
      addTearDown(controller.dispose);
      await _open(
        tester,
        ManagedWorkspacesScreen(controller: controller, project: sw3Project),
      );

      expect(find.text('No provider set up'), findsOneWidget);
      expect(find.textContaining('OpenCode’s config'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('create-managed-workspace')),
        findsNothing,
      );
    });

    testWidgets('rows say their state in words and which one is in use', (
      tester,
    ) async {
      final controller = await sw3Controller()
        ..workspace = 'wrk_ci';
      addTearDown(controller.dispose);
      await _open(
        tester,
        ManagedWorkspacesScreen(controller: controller, project: sw3Project),
      );

      expect(find.textContaining('In use · Connected'), findsOneWidget);
      expect(find.textContaining('Error · Daytona'), findsOneWidget);
      // The provider is chosen in the New environment sheet only (R13).
      expect(find.text('Providers'), findsNothing);
    });

    testWidgets('a list that cannot be read says why and tries again', (
      tester,
    ) async {
      final repository = Sw3Repository()
        ..workspacesError = const ProductException(
          'adapter daytona is not configured',
        );
      final controller = await sw3Controller(repository);
      addTearDown(controller.dispose);
      await _open(
        tester,
        ManagedWorkspacesScreen(controller: controller, project: sw3Project),
      );

      expect(find.text('Couldn’t load cloud environments'), findsOneWidget);
      expect(find.textContaining('not configured'), findsOneWidget);
      repository.workspacesError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('ci-sandbox'), findsOneWidget);
      expect(repository.listCalls, 2);
    });

    testWidgets('a failed create says so on the page with Try again', (
      tester,
    ) async {
      final repository = Sw3Repository()
        ..createError = const ProductException('quota reached');
      final controller = await sw3Controller(repository);
      addTearDown(controller.dispose);
      await _open(
        tester,
        ManagedWorkspacesScreen(controller: controller, project: sw3Project),
      );

      await tester.tap(find.byKey(const ValueKey('create-managed-workspace')));
      await tester.pumpAndSettle();
      // The only provider is already chosen, and the wait is said first.
      expect(find.textContaining('usually takes a few minutes'), findsOne);
      await tester.tap(
        find.byKey(const ValueKey('confirm-create-managed-workspace')),
      );
      await tester.pumpAndSettle();

      expect(repository.createdType, 'daytona');
      expect(find.text('Couldn’t create the environment'), findsOneWidget);
      expect(find.text('quota reached'), findsOneWidget);
      expect(controller.locations, isEmpty);
      repository.createError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(controller.locations.single.workspace, 'wrk_new');
    });

    testWidgets('a failed remove stays in the question; nothing is lost', (
      tester,
    ) async {
      final repository = Sw3Repository()
        ..removeError = const ProductException('provider timed out');
      final controller = await sw3Controller(repository);
      addTearDown(controller.dispose);
      await _open(
        tester,
        ManagedWorkspacesScreen(controller: controller, project: sw3Project),
      );

      await tester.longPress(
        find.byKey(const ValueKey('managed-workspace-wrk_perf')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('environment-menu-remove')));
      await tester.pumpAndSettle();
      expect(find.text('Remove perf-lab?'), findsOneWidget);
      expect(find.textContaining('Conversations stay in history'), findsOne);
      await tester.enterText(
        find.byKey(const ValueKey('kit-confirm-typed-name')),
        'perf-lab',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('confirm-remove-managed-workspace')),
      );
      await tester.pumpAndSettle();

      expect(repository.removedID, isNull);
      expect(find.text('Remove perf-lab?'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('managed-workspace-wrk_perf')),
        findsOneWidget,
      );
    });

    for (final size in const [
      Size(360, 800),
      Size(915, 412),
      Size(800, 1280),
      Size(1280, 800),
      Size(1600, 1000),
    ]) {
      testWidgets('loaded fits $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = await sw3Controller();
        addTearDown(controller.dispose);
        await _open(
          tester,
          ManagedWorkspacesScreen(controller: controller, project: sw3Project),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('ci-sandbox'), findsOneWidget);
      });
    }
  });

  group('Project health', () {
    testWidgets('rows say their state; a stopped server says so', (
      tester,
    ) async {
      final controller = await sw3Controller();
      addTearDown(controller.dispose);
      await _open(tester, ProjectHealthScreen(repository: controller.fake));

      // No counts beside the section labels (R13): the rows say it.
      expect(find.text('2 changed'), findsNothing);
      expect(find.text('1 of 2 running'), findsNothing);
      expect(find.text('1 of 2 on'), findsNothing);
      expect(find.textContaining('Not running · error'), findsOneWidget);
      // Added lines carry their sign, not only a colour (STATE-9).
      expect(find.text('+24'), findsWidgets);
      expect(find.text('-3'), findsWidgets);
    });

    testWidgets('no git: no "changed" count, and Set up confirms first', (
      tester,
    ) async {
      final repository = Sw3Repository()
        ..versionControl = const VersionControlHealth(
          setupState: VersionControlSetupState.absent,
          changes: [],
        );
      final controller = await sw3Controller(repository);
      addTearDown(controller.dispose);
      await _open(tester, ProjectHealthScreen(repository: repository));

      expect(find.text('Git is not initialized'), findsOneWidget);
      expect(find.textContaining('changed'), findsNothing);
      expect(find.text('Set up'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('initialize-git-repository')));
      await tester.pumpAndSettle();
      expect(find.text('Initialize Git repository?'), findsOneWidget);
    });

    testWidgets('a server without git init explains where to run it', (
      tester,
    ) async {
      final repository = Sw3Repository()
        ..versionControl = const VersionControlHealth(
          setupState: VersionControlSetupState.absent,
          changes: [],
        );
      final controller = await sw3Controller(repository);
      addTearDown(controller.dispose);
      await _open(
        tester,
        ProjectHealthScreen(
          repository: repository,
          capabilities: const ServerCapabilities(
            clientPromptMessageID: true,
            gitInit: false,
          ),
        ),
      );

      expect(find.text('Run `git init` from a terminal'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('initialize-git-repository')),
        findsNothing,
      );
    });

    for (final size in const [
      Size(360, 800),
      Size(915, 412),
      Size(800, 1280),
      Size(1280, 800),
      Size(1600, 1000),
    ]) {
      testWidgets('loaded fits $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = await sw3Controller();
        addTearDown(controller.dispose);
        await _open(tester, ProjectHealthScreen(repository: controller.fake));
        expect(tester.takeException(), isNull);
        expect(find.text('feature/loyalty'), findsOneWidget);
      });
    }
  });

  group('Project folder dialogs', () {
    tearDown(() {
      ProjectFolderActions.canCreateOverride = null;
      ProjectFolderActions.createFolderOverride = null;
    });

    Future<void> run(
      WidgetTester tester,
      Future<String?> Function(BuildContext context) action,
    ) async {
      await tester.pumpWidget(
        sw3Host(
          Builder(
            builder: (context) => Center(
              child: GestureDetector(
                key: const ValueKey('sw3-run'),
                behavior: HitTestBehavior.opaque,
                onTap: () => action(context),
                child: const SizedBox.square(dimension: 48),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('sw3-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sw3-run')));
      await tester.pumpAndSettle();
    }

    testWidgets('a folder that cannot be made says why and keeps the name', (
      tester,
    ) async {
      final controller = await sw3Controller();
      addTearDown(controller.dispose);
      ProjectFolderActions.canCreateOverride = true;
      ProjectFolderActions.createFolderOverride = (name) async =>
          throw const ProductException('Termux is not running');
      await run(
        tester,
        (context) => ProjectFolderActions.createFolder(context, controller),
      );

      expect(find.textContaining('on this phone'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('new-folder-name')),
        'loyalty-app',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new-folder-create')));
      await tester.pumpAndSettle();

      expect(find.text('Termux is not running'), findsOneWidget);
      expect(find.text('loyalty-app'), findsOneWidget);
      expect(controller.locations, isEmpty);
    });
  });
}
