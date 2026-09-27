// Golden renders of screen-work-4's pages (wave 2b): Projects (loaded,
// error, one folder, rename), Development services (empty, running,
// unsupported, the editor, the log and the Stop question) and the isolated
// task sheet (form, the staged wait, a failed create), rebuilt from kit
// parts. Phone 412x915 and one wide window (1280x800), dark and light
// (owner decision 2026-09-27: no Arabic), with the app's real fonts at
// DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_work_4_golden_test.dart
// and look at every changed image before committing it.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/codex/gateway.dart'
    show codexServerCapabilities;
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit_undo.dart';
import 'package:opencode_mobile/ui/screens/development_services_screen.dart';
import 'package:opencode_mobile/ui/screens/projects_screen.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../development_services_screen_test.dart' show connectionFor, seed;
import '../support/development_service_fakes.dart';
import 'screen_work_4_test.dart'
    show ProjectsController, ProjectsRepository, SheetHost, projectsController;

/// A server that works in one folder (Codex, Paseo).
class _OneFolderController extends ProjectsController {
  _OneFolderController(super.store, super.projects);

  @override
  ServerCapabilities get capabilities => codexServerCapabilities;
}

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

/// Pumps [home], runs [act] (taps that open a sheet or start a run), lets
/// it settle and compares the whole window.
Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  required Widget home,
  Size size = _phone,
  Future<void> Function()? act,
  bool settle = true,
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
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (act != null) await act();
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    KitUndo.commitPending();
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  setUpAll(loadCaptureFonts);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';

    // --- Projects -----------------------------------------------------------

    for (final size in [_phone, _wide]) {
      testWidgets('projects loaded ($theme, $size)', (tester) async {
        final controller = await projectsController();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'work_projects_loaded',
          light: light,
          size: size,
          home: ProjectsScreen(
            controller: controller,
            selectedProjectID: 'project-1',
          ),
        );
      });
    }

    testWidgets('projects error ($theme)', (tester) async {
      final controller = await projectsController(
        ProjectsRepository()
          ..listError = const ProductException(
            'Could not load projects: the server took too long to answer',
          ),
      );
      addTearDown(controller.dispose);
      await _shot(
        tester,
        'work_projects_error',
        light: light,
        home: ProjectsScreen(controller: controller, selectedProjectID: null),
      );
    });

    testWidgets('projects in one folder ($theme)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = _OneFolderController(
        ProfileStore(prefs: await SharedPreferences.getInstance()),
        ProjectsRepository(),
      )..directory = '/work/codex-project';
      addTearDown(controller.dispose);
      await _shot(
        tester,
        'work_projects_one_folder',
        light: light,
        home: ProjectsScreen(controller: controller, selectedProjectID: null),
      );
    });

    testWidgets('projects rename dialog ($theme)', (tester) async {
      final controller = await projectsController();
      addTearDown(controller.dispose);
      await _shot(
        tester,
        'work_projects_rename_dialog',
        light: light,
        home: ProjectsScreen(
          controller: controller,
          selectedProjectID: 'project-1',
        ),
        act: () async {
          await tester.longPress(
            find.byKey(const ValueKey('project-project-2')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('rename-project-project-2')),
          );
        },
      );
    });

    // --- Development services ---------------------------------------------

    testWidgets('development services empty ($theme)', (tester) async {
      final connection = await connectionFor(ServiceRepository());
      addTearDown(connection.dispose);
      await _shot(
        tester,
        'work_development_services_empty',
        light: light,
        home: DevelopmentServicesScreen(controller: connection),
      );
    });

    for (final size in [_phone, _wide]) {
      testWidgets('development services running ($theme, $size)', (
        tester,
      ) async {
        final connection = await connectionFor(ServiceRepository());
        addTearDown(connection.dispose);
        await seed(connection);
        await _shot(
          tester,
          'work_development_services_running',
          light: light,
          size: size,
          home: DevelopmentServicesScreen(controller: connection),
          act: () async {
            await tester.tap(find.byTooltip('Start'));
            await tester.pumpAndSettle();
            KitUndo.commitPending();
          },
        );
      });
    }

    testWidgets('development services unsupported ($theme)', (tester) async {
      final connection = await connectionFor(ServiceRepository())
        ..supported = false;
      addTearDown(connection.dispose);
      await seed(connection);
      await _shot(
        tester,
        'work_development_services_unsupported',
        light: light,
        home: DevelopmentServicesScreen(controller: connection),
      );
    });

    testWidgets('development services editor ($theme)', (tester) async {
      final connection = await connectionFor(ServiceRepository());
      addTearDown(connection.dispose);
      await seed(connection);
      await _shot(
        tester,
        'work_development_services_editor_sheet',
        light: light,
        home: DevelopmentServicesScreen(controller: connection),
        act: () async {
          await tester.tap(find.byTooltip('Register service'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('development-services-name')),
            'Storybook',
          );
          await tester.tap(find.text('Save service'));
        },
      );
    });

    testWidgets('development services log ($theme)', (tester) async {
      final connection = await connectionFor(ServiceRepository());
      addTearDown(connection.dispose);
      await seed(connection);
      await _shot(
        tester,
        'work_development_services_logs_sheet',
        light: light,
        home: DevelopmentServicesScreen(controller: connection),
        act: () async {
          await tester.tap(find.byTooltip('Start'));
          await tester.pumpAndSettle();
          KitUndo.commitPending();
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('development-service-vite')),
          );
        },
      );
    });

    testWidgets('development services stop question ($theme)', (tester) async {
      final connection = await connectionFor(ServiceRepository());
      addTearDown(connection.dispose);
      await seed(connection);
      await _shot(
        tester,
        'work_development_services_confirm_sheet_stop',
        light: light,
        home: DevelopmentServicesScreen(controller: connection),
        act: () async {
          await tester.tap(find.byTooltip('Start'));
          await tester.pumpAndSettle();
          KitUndo.commitPending();
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Stop'));
        },
      );
    });

    // --- Isolated task sheet ------------------------------------------------

    for (final size in [_phone, _wide]) {
      testWidgets('isolated task form ($theme, $size)', (tester) async {
        final controller = await projectsController();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'work_isolated_task_sheet_form',
          light: light,
          size: size,
          home: Scaffold(body: SheetHost(controller: controller)),
          act: () => tester.tap(find.byKey(const Key('open-sheet'))),
        );
      });
    }

    testWidgets('isolated task creating ($theme)', (tester) async {
      final controller = await projectsController();
      addTearDown(controller.dispose);
      await _shot(
        tester,
        'work_isolated_task_sheet_creating',
        light: light,
        settle: false,
        home: Scaffold(body: SheetHost(controller: controller)),
        act: () async {
          await tester.tap(find.byKey(const Key('open-sheet')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('isolated-task-start')));
          await tester.pump();
        },
      );
    });

    testWidgets('isolated task failed ($theme)', (tester) async {
      final repository = ProjectsRepository();
      final controller = await projectsController(repository);
      addTearDown(controller.dispose);
      await _shot(
        tester,
        'work_isolated_task_sheet_failed',
        light: light,
        home: Scaffold(body: SheetHost(controller: controller)),
        act: () async {
          await tester.tap(find.byKey(const Key('open-sheet')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('isolated-task-start')));
          await tester.pump();
          repository.create.completeError(
            const ProductException('fatal: not a git repository'),
          );
        },
      );
    });
  }
}
