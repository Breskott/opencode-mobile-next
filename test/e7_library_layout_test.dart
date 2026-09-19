import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:opencode_mobile/ui/screens/manage_project_screen.dart';
import 'package:opencode_mobile/ui/screens/managed_workspaces_screen.dart';
import 'package:opencode_mobile/ui/screens/mcp_setup_screen.dart';
import 'package:opencode_mobile/ui/screens/project_health_screen.dart';
import 'package:opencode_mobile/ui/screens/saved_permissions_screen.dart';
import 'package:opencode_mobile/ui/screens/tools_screen.dart';
import 'package:opencode_mobile/ui/screens/worktrees_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart'
    show capturePng, captureTheme, loadCaptureFonts;

const _project = WorkspaceProject(
  id: 'layout-project',
  name: 'Mobile project',
  directory: '/work/mobile',
  worktrees: [],
  updatedAt: 1,
);

class _Repository implements ProductRepository {
  int mutations = 0;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<WorktreeInfo>> listWorktrees({
    required String projectDirectory,
    String? projectID,
  }) async => const [];

  @override
  Future<List<WorkspaceInfo>> listManagedWorkspaces({
    required String projectDirectory,
  }) async => const [];

  @override
  Future<List<WorkspaceAdapterInfo>> listWorkspaceAdapters({
    required String projectDirectory,
  }) async => const [
    WorkspaceAdapterInfo(
      type: 'cloud',
      name: 'Cloud runner',
      description: 'Remote project environment',
    ),
  ];

  @override
  Future<VersionControlHealth> loadVersionControlHealth() async =>
      const VersionControlHealth(
        branch: 'feature/mobile',
        defaultBranch: 'main',
        changes: [],
      );

  @override
  Future<List<LanguageServiceHealth>> listLanguageServices() async => const [];

  @override
  Future<List<FormatterHealth>> listFormatters() async => const [];

  @override
  Future<List<SavedPermission>> listSavedPermissions() async => const [
    SavedPermission(
      id: 'layout-permission',
      projectID: 'layout-project',
      action: 'bash',
      resource: 'git status',
    ),
  ];

  @override
  Future<void> removeSavedPermission(String id) async => mutations++;

  @override
  Future<List<CodingToolInfo>> listCodingTools({
    required String providerID,
    required String modelID,
  }) async => const [
    CodingToolInfo(
      id: 'read',
      description: 'Read project files.',
      parameters: {'type': 'object'},
    ),
  ];

  @override
  Future<List<String>> listCodingToolIDs() async => const ['read', 'task'];

  @override
  Future<ExperimentalServerCapabilities> loadExperimentalCapabilities() async =>
      const ExperimentalServerCapabilities(backgroundSubagents: true);

  @override
  Future<List<McpServerInfo>> listMcpServers() async => const [];

  @override
  Future<List<McpResourceInfo>> listMcpResources() async => const [];

  @override
  Future<List<IntegrationInfo>> listIntegrations() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends ConnectionController {
  _Controller(super.store, this.gateway) {
    repository = gateway;
    directory = _project.directory;
    selectedModel = ModelRef(providerID: 'openai', modelID: 'layout-model');
  }

  final _Repository gateway;

  @override
  Future<ProductRepository?> prepareActionRepository() async => gateway;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorage = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (_) async => null);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, null),
  );

  for (final variant in [
    (name: 'light', rtl: false, large: false),
    (name: 'dark', rtl: false, large: false),
    (name: 'rtl-large', rtl: true, large: true),
  ]) {
    testWidgets('library project tools remain reachable ${variant.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _Repository();
      final controller = _Controller(
        ProfileStore(prefs: await SharedPreferences.getInstance()),
        repository,
      );
      addTearDown(controller.dispose);
      final output = Platform.environment['OC_E7_LIBRARY_CAPTURE_DIR'];
      if (output != null) {
        expect(Directory(output).existsSync(), isTrue);
        await loadCaptureFonts();
      }
      final screens = <String, Widget>{
        'manage-project': ManageProjectScreen(
          controller: controller,
          project: _project,
        ),
        'worktrees': WorktreesScreen(controller: controller, project: _project),
        'cloud-environments': ManagedWorkspacesScreen(
          controller: controller,
          project: _project,
        ),
        'project-health': ProjectHealthScreen(repository: repository),
        'permissions': SavedPermissionsScreen(controller: controller),
        'tools': ToolsScreen(controller: controller),
        'providers': IntegrationsScreen(
          controller: controller,
          mode: IntegrationsMode.providers,
        ),
        'mcp-setup': McpSetupScreen(controller: controller),
      };
      for (final entry in screens.entries) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: captureTheme(light: variant.name == 'light'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(variant.large ? 2.5 : 1),
                ),
                child: Directionality(
                  textDirection: variant.rtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: child!,
                ),
              ),
              home: entry.value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final layoutException = tester.takeException();
        expect(layoutException, isNull, reason: '${entry.key}/${variant.name}');
        if (output != null) {
          File(
            '$output/${entry.key}-${variant.name}.png',
          ).writeAsBytesSync(await capturePng(tester, boundary, pixelRatio: 1));
        }
        if (entry.key == 'cloud-environments' || entry.key == 'worktrees') {
          final action = find.byKey(
            ValueKey(
              entry.key == 'worktrees'
                  ? 'create-worktree'
                  : 'create-managed-workspace',
            ),
          );
          final bounds = tester.getRect(action);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(320));
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Cancel'), findsOneWidget);
          if (output != null) {
            File(
              '$output/${entry.key}-create-${variant.name}.png',
            ).writeAsBytesSync(
              await capturePng(tester, boundary, pixelRatio: 1),
            );
          }
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(repository.mutations, 0);
        }
        if (entry.key == 'permissions') {
          await tester.tap(find.byTooltip('Revoke bash access'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Revoke access'), findsOneWidget);
          expect(repository.mutations, 0);
          if (output != null) {
            File(
              '$output/revoke-confirmation-${variant.name}.png',
            ).writeAsBytesSync(
              await capturePng(tester, boundary, pixelRatio: 1),
            );
          }
          await tester.tap(find.text('Keep access'));
          await tester.pumpAndSettle();
          expect(repository.mutations, 0);
        }
        if (entry.key == 'mcp-setup') {
          // Technical input direction is independent of translated labels.
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('mcp-name')),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          final name = tester.widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('mcp-name')),
              matching: find.byType(EditableText),
            ),
          );
          expect(name.textDirection, TextDirection.ltr);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
