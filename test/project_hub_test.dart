import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/api2/gateway_mappers.dart';
import 'package:opencode_mobile/codex/gateway.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/paseo/gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/files_screen.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/project_health_screen.dart';
import 'package:opencode_mobile/ui/screens/project_hub_screen.dart';
import 'package:opencode_mobile/ui/screens/review_workspace.dart';
import 'package:opencode_mobile/ui/screens/terminal_screen.dart';
import 'package:opencode_mobile/ui/screens/worktrees_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart' show loadCaptureFonts;

// UX plan 5.1: the Project tab gathers the tools that act on the current
// project. A row exists only when the connected server can serve it, and the
// tab exists only when a row does.

class _Api extends OpenCodeApi {
  _Api(this._capabilities) : super(baseUrl: 'http://localhost');

  final ServerCapabilities _capabilities;

  @override
  ServerCapabilities get capabilities => _capabilities;

  @override
  Future<List<Session>> sessions() async => [];

  @override
  Future<List<FileNode>> listFiles([String path = '']) async => [];
}

class _Repository implements ProductRepository {
  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<WorkspaceProject>> listProjects() async => [
    const WorkspaceProject(
      id: 'project-1',
      name: 'app',
      directory: '/srv/app',
      worktrees: [],
      updatedAt: 1,
    ),
  ];

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => [];

  @override
  Future<List<TerminalProcess>> listTerminals() async => [];

  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends ProfileStore {
  _Store({required super.prefs});

  @override
  List<ServerProfile> get profiles => const [];

  @override
  String? get activeId => null;
}

Future<ConnectionController> _controller(
  ServerCapabilities capabilities,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ConnectionController(_Store(prefs: prefs))
    ..api = _Api(capabilities)
    ..repository = _Repository()
    ..directory = '/srv/app'
    ..status = StreamStatus.connected;
}

Widget _shell(
  ConnectionController controller, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => ProviderScope(
  overrides: [connProvider.overrideWithValue(controller)],
  child: MaterialApp(
    theme: AppTheme.dark(),
    locale: locale,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const HomeScreen(),
  ),
);

Finder _tool(ProjectTool tool) =>
    find.byKey(ValueKey('project-hub-${tool.name}'));

void _phone(WidgetTester tester, [Size size = const Size(390, 844)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openProjectTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(AppIconography.files),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  const everyTool = ProjectTool.values;

  group('rows follow the connected server', () {
    final expected = <String, (ServerCapabilities, List<ProjectTool>)>{
      'OpenCode 1': (ServerCapabilities.allV1, everyTool),
      'OpenCode 2': (api2ServerCapabilities, everyTool),
      'Codex': (codexServerCapabilities, const []),
      'Paseo': (paseoServerCapabilities, const []),
      'files only': (
        const ServerCapabilities(terminal: false, projectManagement: false),
        const [ProjectTool.files, ProjectTool.changes, ProjectTool.search],
      ),
      'terminal only': (
        const ServerCapabilities(fileBrowsing: false, projectManagement: false),
        const [ProjectTool.terminal],
      ),
      'project management only': (
        const ServerCapabilities(fileBrowsing: false, terminal: false),
        const [ProjectTool.health, ProjectTool.worktrees],
      ),
    };

    test('the listed tools and their order', () {
      expect(everyTool, const [
        ProjectTool.files,
        ProjectTool.changes,
        ProjectTool.terminal,
        ProjectTool.health,
        ProjectTool.worktrees,
        ProjectTool.search,
      ]);
      for (final entry in expected.entries) {
        final (capabilities, tools) = entry.value;
        expect(ProjectHub.toolsFor(capabilities), tools, reason: entry.key);
        expect(
          ProjectHub.isAvailable(capabilities),
          tools.isNotEmpty,
          reason: entry.key,
        );
      }
    });

    for (final entry in expected.entries) {
      testWidgets('${entry.key}: the tab and exactly its rows', (tester) async {
        _phone(tester);
        final (capabilities, tools) = entry.value;
        final controller = await _controller(capabilities);
        addTearDown(controller.dispose);
        await tester.pumpWidget(_shell(controller));
        await tester.pumpAndSettle();

        final labels = tester
            .widgetList<NavigationDestination>(
              find.descendant(
                of: find.byType(NavigationBar),
                matching: find.byType(NavigationDestination),
              ),
            )
            .map((destination) => destination.label)
            .toList();
        if (tools.isEmpty) {
          expect(labels, ['Work', 'Inbox', 'Settings']);
          expect(find.byType(ProjectHub), findsNothing);
          return;
        }
        expect(labels, ['Work', 'Inbox', 'Project', 'Settings']);
        await _openProjectTab(tester);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('current-tab-title')))
              .data,
          'Project',
        );
        for (final tool in everyTool) {
          expect(
            _tool(tool),
            tools.contains(tool) ? findsOneWidget : findsNothing,
            reason: '${entry.key}: ${tool.name}',
          );
        }
        // Top to bottom in the declared order.
        final tops = [
          for (final tool in tools) tester.getTopLeft(_tool(tool)).dy,
        ];
        expect(tops, [...tops]..sort());
        expect(find.text('app'), findsOneWidget);
        expect(find.text('/srv/app'), findsOneWidget);
      });
    }
  });

  group('each row opens the existing screen', () {
    testWidgets(
      'Files opens inside the tab and the header returns to the hub',
      (tester) async {
        _phone(tester);
        final controller = await _controller(ServerCapabilities.allV1);
        addTearDown(controller.dispose);
        await tester.pumpWidget(_shell(controller));
        await tester.pumpAndSettle();
        await _openProjectTab(tester);
        expect(find.byType(FilesScreen), findsNothing);

        await tester.tap(_tool(ProjectTool.files));
        await tester.pumpAndSettle();
        expect(find.byType(FilesScreen), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(_tool(ProjectTool.files).hitTestable(), findsNothing);

        await tester.tap(find.byKey(const ValueKey('project-hub-files-back')));
        await tester.pumpAndSettle();
        expect(_tool(ProjectTool.files).hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('files-search-field')).hitTestable(),
          findsNothing,
        );
      },
    );

    testWidgets('Search files opens Files with the find field focused', (
      tester,
    ) async {
      _phone(tester);
      final controller = await _controller(ServerCapabilities.allV1);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_shell(controller));
      await tester.pumpAndSettle();
      await _openProjectTab(tester);

      await tester.tap(_tool(ProjectTool.search));
      await tester.pumpAndSettle();
      expect(find.byType(FilesScreen), findsOneWidget);
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        'files-search',
      );
    });

    testWidgets('Terminal, Changes, Project health and Worktrees push theirs', (
      tester,
    ) async {
      _phone(tester);
      final controller = await _controller(ServerCapabilities.allV1);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_shell(controller));
      await tester.pumpAndSettle();
      await _openProjectTab(tester);

      Future<void> opens(ProjectTool tool, Type screen) async {
        await tester.tap(_tool(tool));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(screen), findsOneWidget, reason: tool.name);
        Navigator.of(tester.element(find.byType(screen))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(screen), findsNothing, reason: tool.name);
      }

      await opens(ProjectTool.terminal, TerminalPage);
      await opens(ProjectTool.changes, ReviewWorkspace);
      await opens(ProjectTool.health, ProjectHealthScreen);
      await opens(ProjectTool.worktrees, WorktreesScreen);
    });
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('the hub fits 320 dp at 2.5x text in ${locale.languageCode}', (
      tester,
    ) async {
      _phone(tester, const Size(320, 640));
      final controller = await _controller(ServerCapabilities.allV1);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _shell(controller, locale: locale, textScale: 2.5),
      );
      await tester.pumpAndSettle();
      await _openProjectTab(tester);
      expect(find.byType(ProjectHub), findsOneWidget);
      // The last row scrolls clear of the dock rather than ending under it.
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('project-hub')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // The list is lazy: its extent is only final once the end is built.
      for (var i = 0; i < 4; i++) {
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(_tool(ProjectTool.search).hitTestable(), findsOneWidget);
      expect(
        tester.getRect(_tool(ProjectTool.search)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(NavigationBar)).top),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
