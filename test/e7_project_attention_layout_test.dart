import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/ui/screens/attention_overview_screen.dart';
import 'package:opencode_mobile/ui/screens/profile_monitor_screen.dart';
import 'package:opencode_mobile/ui/screens/projects_screen.dart';

import '../tool/capture/fixtures.dart'
    show loadCaptureFonts, capturePng, writePng;
import 'support/profile_monitor_fixture.dart';

const _capture = bool.fromEnvironment('E7_PROJECT_CAPTURE');
final _boundary = GlobalKey();

Future<void> _captureScreen(WidgetTester tester, String name) async {
  if (!_capture) return;
  await writePng(
    'docs/qa/e7-project-attention/$name.png',
    await capturePng(tester, _boundary, pixelRatio: 1),
  );
}

class _Projects implements ServerOperationsGateway {
  String? renamed;
  WorkspaceProject project = const WorkspaceProject(
    id: 'mobile',
    name: 'مشروع الهاتف',
    directory: '/work/mobile-app',
    worktrees: ['/work/mobile-app-review'],
    updatedAt: 1,
  );

  @override
  Future<List<WorkspaceProject>> listProjects() async => [project];

  @override
  Future<WorkspaceProject> renameProject({
    required String projectID,
    required String projectDirectory,
    required String name,
  }) async {
    renamed = name;
    return project = WorkspaceProject(
      id: project.id,
      name: name,
      directory: project.directory,
      worktrees: project.worktrees,
      updatedAt: 2,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProjectController extends ConnectionController {
  _ProjectController(super.store, this.projects) {
    directory = '/work/mobile-app';
  }

  final _Projects projects;

  @override
  ServerCapabilities get capabilities =>
      const ServerCapabilities(projectManagement: true);

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async => projects;
}

Widget _app(Widget home, TextDirection direction) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(2.5)),
    child: RepaintBoundary(
      key: _boundary,
      child: Directionality(textDirection: direction, child: child!),
    ),
  ),
  home: home,
);

Future<void> _reveal(WidgetTester tester, Finder target) async {
  for (
    var attempt = 0;
    attempt < 60 && target.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pump();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_capture) setUpAll(loadCaptureFonts);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  for (final direction in TextDirection.values) {
    testWidgets('320dp 2.5x $direction project search and rename stay usable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await monitorStore(count: 0);
      final projects = _Projects();
      final controller = _ProjectController(store, projects);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          ProjectsScreen(controller: controller, selectedProjectID: 'mobile'),
          direction,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'mobile-app');
      await tester.pumpAndSettle();
      final rename = find.byKey(const ValueKey('rename-project-mobile'));
      await _reveal(tester, rename);
      expect(
        tester.widget<Text>(find.text('/work/mobile-app')).textDirection,
        TextDirection.ltr,
      );
      await _captureScreen(tester, 'projects-${direction.name}');
      await tester.tap(rename.hitTestable());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('project-name-input')),
        'مشروع جديد',
      );
      await _captureScreen(tester, 'rename-${direction.name}');
      final save = find.byKey(const ValueKey('confirm-rename-project'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(projects.renamed, 'مشروع جديد');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '320dp 2.5x $direction attention unknown and open action survive',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = await monitorStore(count: 1);
        final controller = ConnectionController(store);
        addTearDown(controller.dispose);
        String? opened;
        await tester.pumpWidget(
          _app(
            AttentionOverviewScreen(
              controller: controller,
              onOpenProfile: (id) => opened = id,
            ),
            direction,
          ),
        );
        await tester.pumpAndSettle();
        await _reveal(tester, find.byType(OutlinedButton));
        expect(find.text('Pending requests: unknown'), findsOneWidget);
        expect(find.text('Running sessions: unknown'), findsOneWidget);
        await _captureScreen(tester, 'attention-${direction.name}');
        await tester.tap(find.byType(OutlinedButton).hitTestable());
        expect(opened, 'profile-1');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '320dp 2.5x $direction monitor quiet time and reminder remain usable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = await monitorStore(count: 1);
        final controller = ConnectionController(
          store,
          monitorGatewayFactory: (_) => (
            gateway: MonitorTestGateway(),
            operations: MonitorTestOperations(),
          ),
        );
        await tester.pumpWidget(
          _app(ProfileMonitorScreen(controller: controller), direction),
        );
        await tester.pump();
        Finder toggle(String label) => find.descendant(
          of: find.widgetWithText(SwitchListTile, label),
          matching: find.byType(Switch),
        );
        final enabled = toggle('Monitor this server');
        await _reveal(tester, enabled);
        await tester.tap(enabled.hitTestable());
        await tester.pumpAndSettle();
        final quiet = toggle('Quiet hours');
        await _reveal(tester, quiet);
        await tester.tap(quiet.hitTestable());
        await tester.pumpAndSettle();
        // Localized labels are intentionally queried through the active catalog.
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ProfileMonitorScreen)),
        );
        final start = find.widgetWithText(ListTile, l10n.monitorQuietStart);
        await _reveal(tester, start);
        await _captureScreen(tester, 'monitor-quiet-${direction.name}');
        await tester.tap(start.hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.tap(
          find.text(
            MaterialLocalizations.of(
              tester.element(find.byType(TimePickerDialog)),
            ).cancelButtonLabel,
          ),
        );
        await tester.pumpAndSettle();
        final checkIn = find.descendant(
          of: find.byKey(const ValueKey('monitor-check-in-profile-1')),
          matching: find.byType(Switch),
        );
        await _reveal(tester, checkIn);
        await tester.tap(checkIn.hitTestable());
        await tester.pumpAndSettle();
        final duration = find.byKey(
          const ValueKey('monitor-check-in-after-profile-1'),
        );
        await _reveal(tester, duration);
        await tester.tap(duration.hitTestable());
        await tester.pumpAndSettle();
        await _captureScreen(tester, 'monitor-reminder-${direction.name}');
        await tester.tap(find.text('15 minutes').last);
        await tester.pumpAndSettle();
        expect(
          controller.profileMonitor.rulesFor('profile-1').checkInAfterMinutes,
          15,
        );
        expect(tester.takeException(), isNull);
        // Dispose inside the body: the monitor's refresh timer must be gone
        // before the binding checks for pending timers.
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }
}
