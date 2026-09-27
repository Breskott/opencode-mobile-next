import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/managed_workspaces_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _project = WorkspaceProject(
  id: 'project-1',
  name: 'OpenCode Mobile',
  directory: '/work/app',
  worktrees: [],
  updatedAt: 1,
);

class _ManagedWorkspaceRepository implements ProductRepository {
  List<WorkspaceInfo> workspaces = [
    const WorkspaceInfo(
      id: 'wrk_remote',
      projectID: 'project-1',
      name: 'Phone runner',
      type: 'cloud',
      branch: 'feature/mobile',
      directory: '/remote/app',
      status: 'connected',
    ),
  ];
  List<WorkspaceAdapterInfo> adapters = const [
    WorkspaceAdapterInfo(
      type: 'cloud',
      name: 'Cloud runner',
      description: 'Create an isolated remote runner',
    ),
  ];
  int syncCalls = 0;
  String? createdType;
  String? createdBranch;
  String? removedID;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => workspaces;

  @override
  Future<List<WorkspaceInfo>> listManagedWorkspaces({
    required String projectDirectory,
  }) async {
    listCalls += 1;
    return List.of(workspaces);
  }

  /// How many times the environments were read.
  int listCalls = 0;

  @override
  Future<List<WorkspaceAdapterInfo>> listWorkspaceAdapters({
    required String projectDirectory,
  }) async => adapters;

  @override
  Future<void> syncWorkspaceList({required String projectDirectory}) async {
    syncCalls += 1;
  }

  @override
  Future<WorkspaceInfo> createManagedWorkspace({
    required String projectDirectory,
    required String type,
    String? branch,
  }) async {
    createdType = type;
    createdBranch = branch;
    final workspace = WorkspaceInfo(
      id: 'wrk_created',
      projectID: 'project-1',
      name: 'Created runner',
      type: type,
      branch: branch,
      directory: '/remote/created',
      status: 'connected',
    );
    workspaces = [...workspaces, workspace];
    return workspace;
  }

  @override
  Future<void> removeManagedWorkspace({
    required String projectDirectory,
    required String id,
  }) async {
    removedID = id;
    workspaces = workspaces.where((workspace) => workspace.id != id).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ManagedWorkspaceController extends ConnectionController {
  _ManagedWorkspaceController(super.store, this.managedRepository) {
    repository = managedRepository;
  }

  final _ManagedWorkspaceRepository managedRepository;
  final locations = <({String? directory, String? workspace})>[];

  @override
  Future<ProductRepository?> prepareActionRepository() async =>
      managedRepository;

  @override
  Future<void> selectLocation({String? directory, String? workspace}) async {
    locations.add((directory: directory, workspace: workspace));
    this.directory = directory;
    this.workspace = workspace;
    locationError = null;
    notifyListeners();
  }

  @override
  Future<void> selectLocationForExistingSession({
    String? directory,
    String? workspace,
  }) => selectLocation(directory: directory, workspace: workspace);
}

Future<_ManagedWorkspaceController> _controller(
  _ManagedWorkspaceRepository repository,
) async {
  SharedPreferences.setMockInitialValues({});
  return _ManagedWorkspaceController(
    ProfileStore(prefs: await SharedPreferences.getInstance()),
    repository,
  );
}

Widget _host(ManagedWorkspacesScreen screen, {double textScale = 1}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('open-managed-workspaces'),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => screen)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester, ManagedWorkspacesScreen screen) async {
  await tester.pumpWidget(_host(screen));
  await tester.tap(find.byKey(const ValueKey('open-managed-workspaces')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('managed workspace screen fits a compact large-text phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ManagedWorkspaceRepository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        ManagedWorkspacesScreen(controller: controller, project: _project),
        textScale: 2,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-managed-workspaces')));
    await tester.pumpAndSettle();

    expect(find.text('Cloud environments'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('managed-workspace-wrk_remote')),
      findsOneWidget,
    );
    // Providers are chosen in the New environment sheet only (R13).
    expect(find.text('Cloud runner'), findsNothing);
    expect(tester.takeException(), isNull);

    // Discover existing lives in the top bar's overflow (map rationale).
    await tester.tap(find.byKey(const ValueKey('managed-workspaces-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sync-managed-workspaces')));
    await tester.pumpAndSettle();
    expect(repository.syncCalls, 1);
    // The outcome is said at the top of the list, not in a snackbar.
    await tester.scrollUntilVisible(
      find.text('Discovery finished'),
      -240,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('managed-workspaces-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Discovery finished'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('create-managed-workspace')));
    await tester.pumpAndSettle();
    expect(find.text('New cloud environment'), findsOneWidget);
    // One provider: nothing to choose, the subtitle names it.
    expect(find.text('In Cloud runner'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-adapter-picker')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    // The sheet closes with its Close button (KIT-19).
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('creating a workspace uses an adapter then opens exact result', (
    tester,
  ) async {
    final repository = _ManagedWorkspaceRepository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await _open(
      tester,
      ManagedWorkspacesScreen(controller: controller, project: _project),
    );

    await tester.tap(find.byKey(const ValueKey('create-managed-workspace')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('workspace-branch-input')),
      'feature/phone',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-create-managed-workspace')),
    );
    await tester.pumpAndSettle();

    expect(repository.createdType, 'cloud');
    expect(repository.createdBranch, 'feature/phone');
    expect(controller.directory, '/remote/created');
    expect(controller.workspace, 'wrk_created');
  });

  testWidgets('removing the active workspace returns local before deletion', (
    tester,
  ) async {
    final repository = _ManagedWorkspaceRepository();
    final controller = await _controller(repository);
    controller
      ..directory = '/remote/app'
      ..workspace = 'wrk_remote';
    addTearDown(controller.dispose);
    await _open(
      tester,
      ManagedWorkspacesScreen(controller: controller, project: _project),
    );

    // The row's rarer acts are on long-press (KIT-28), one verb: Remove.
    final tile = find.byKey(const ValueKey('managed-workspace-wrk_remote'));
    await tester.longPress(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('environment-menu-remove')));
    await tester.pumpAndSettle();
    // Nothing is removed until the name is typed.
    await tester.tap(
      find.byKey(const ValueKey('confirm-remove-managed-workspace')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(repository.removedID, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('kit-confirm-typed-name')),
      'Phone runner',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('confirm-remove-managed-workspace')),
    );
    await tester.pumpAndSettle();

    expect(controller.locations.first.directory, '/work/app');
    expect(controller.locations.first.workspace, isNull);
    expect(repository.removedID, 'wrk_remote');
    expect(
      find.byKey(const ValueKey('managed-workspace-wrk_remote')),
      findsNothing,
    );
  });
  group('slice-R13', () {
    testWidgets('no refresh in the top bar and no provider list on the page; '
        'pulling down reloads', (tester) async {
      final repository = _ManagedWorkspaceRepository();
      final controller = await _controller(repository);
      addTearDown(controller.dispose);
      await _open(
        tester,
        ManagedWorkspacesScreen(controller: controller, project: _project),
      );

      expect(
        find.byKey(const ValueKey('refresh-managed-workspaces')),
        findsNothing,
      );
      expect(find.text('Providers'), findsNothing);
      // The page title names the list: no "Environments" label or count.
      expect(find.text('Environments'), findsNothing);
      expect(find.text('1'), findsNothing);

      final before = repository.listCalls;
      await tester.fling(
        find.byKey(const ValueKey('managed-workspaces-list')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(repository.listCalls, greaterThan(before));
    });

    testWidgets('several providers: the sheet asks which, and creates with '
        'the one chosen', (tester) async {
      final repository = _ManagedWorkspaceRepository()
        ..adapters = const [
          WorkspaceAdapterInfo(
            type: 'cloud',
            name: 'Cloud runner',
            description: 'Create an isolated remote runner',
          ),
          WorkspaceAdapterInfo(
            type: 'daytona',
            name: 'Daytona',
            description: 'A sandbox in Daytona',
          ),
        ];
      final controller = await _controller(repository);
      addTearDown(controller.dispose);
      await _open(
        tester,
        ManagedWorkspacesScreen(controller: controller, project: _project),
      );

      await tester.tap(find.byKey(const ValueKey('create-managed-workspace')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('workspace-adapter-picker')),
        findsOneWidget,
      );
      expect(find.text('Provider'), findsOneWidget);
      expect(find.textContaining('In '), findsNothing);
      await tester.tap(find.text('Daytona'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirm-create-managed-workspace')),
      );
      await tester.pumpAndSettle();
      expect(repository.createdType, 'daytona');
    });

    testWidgets('environments but no provider: the page says why there is no '
        'New environment', (tester) async {
      final repository = _ManagedWorkspaceRepository()
        ..adapters = <WorkspaceAdapterInfo>[];
      final controller = await _controller(repository);
      addTearDown(controller.dispose);
      await _open(
        tester,
        ManagedWorkspacesScreen(controller: controller, project: _project),
      );

      expect(
        find.byKey(const ValueKey('managed-workspace-wrk_remote')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workspace-adapters-empty')),
        findsOneWidget,
      );
      expect(
        find.textContaining('No provider set up', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('create-managed-workspace')),
        findsNothing,
      );
    });
  });
}
