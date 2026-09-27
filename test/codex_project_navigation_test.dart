import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/codex/gateway.dart'
    show codexServerCapabilities;
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/project_hub_screen.dart';
import 'package:opencode_mobile/ui/screens/projects_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CodexCapabilitiesApi extends OpenCodeApi {
  _CodexCapabilitiesApi() : super(baseUrl: 'http://localhost');

  @override
  ServerCapabilities get capabilities => codexServerCapabilities;
}

class _NoProjectCallsRepository implements ProductRepository {
  int listCalls = 0;
  int renameCalls = 0;

  @override
  Future<List<WorkspaceProject>> listProjects() async {
    listCalls++;
    return const [];
  }

  @override
  Future<WorkspaceProject> renameProject({
    required String projectID,
    required String projectDirectory,
    required String name,
  }) async {
    renameCalls++;
    throw StateError('project management should be gated');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ConnectionController> _controller(
  _NoProjectCallsRepository repository,
) async {
  SharedPreferences.setMockInitialValues({});
  final controller =
      ConnectionController(
          ProfileStore(prefs: await SharedPreferences.getInstance()),
        )
        ..repository = repository
        ..directory = '/work/codex-project'
        ..api = _CodexCapabilitiesApi();
  return controller;
}

void main() {
  // Manage project merged into the Project tab (slice-P3.11a). Codex
  // serves none of its tools, so the tab is absent and the configured
  // folder is shown by the Work tab's folder row and its sheet.
  test('Codex offers no Project tab tools', () {
    expect(ProjectHub.toolsFor(codexServerCapabilities), isEmpty);
    expect(ProjectHub.isAvailable(codexServerCapabilities), isFalse);
  });

  testWidgets(
    'Codex ProjectsScreen does not list projects or expose project actions',
    (tester) async {
      final repository = _NoProjectCallsRepository();
      final controller = await _controller(repository);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProjectsScreen(controller: controller, selectedProjectID: null),
        ),
      );
      await tester.pumpAndSettle();

      // The same title, and it says the server works in one folder.
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Server uses one folder'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('projects-configured-folder')),
        findsOneWidget,
      );
      expect(find.text('/work/codex-project'), findsOneWidget);
      expect(find.byKey(const ValueKey('project-search')), findsNothing);
      expect(repository.listCalls, 0);
      expect(repository.renameCalls, 0);
    },
  );
}
