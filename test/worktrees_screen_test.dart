import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/worktrees_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _project = WorkspaceProject(
  id: 'project-1',
  name: 'OpenCode Mobile',
  directory: '/work/app',
  worktrees: ['/data/worktree/project-1/mobile-review'],
  updatedAt: 1,
);

const _row = 'worktree-/data/worktree/project-1/mobile-review';

const _aliasedProject = WorkspaceProject(
  id: 'project-1',
  name: 'OpenCode Mobile',
  directory: '/work/app',
  worktrees: [
    '/legacy/data/project-1/mobile-review',
    '/data/worktree/project-1/mobile-review',
  ],
  updatedAt: 1,
);

class _WorktreeRepository implements ProductRepository {
  List<WorktreeInfo> worktrees = const [
    WorktreeInfo(
      name: 'mobile-review',
      directory: '/data/worktree/project-1/mobile-review',
      branch: 'opencode/mobile-review',
    ),
  ];
  List<VersionControlFile> statuses = const [
    VersionControlFile(
      path: 'lib/main.dart',
      status: 'modified',
      additions: 4,
      deletions: 1,
    ),
  ];
  final resetCalls = <String>[];
  final removeCalls = <String>[];
  String? createName;

  /// Thrown by [createWorktree] when set, to exercise the error path.
  Object? createError;

  /// Thrown by [removeWorktree] when set.
  Object? removeError;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<WorktreeInfo>> listWorktrees({
    required String projectDirectory,
    String? projectID,
  }) async {
    listCalls++;
    return List.of(worktrees);
  }

  /// How many times the list was read.
  int listCalls = 0;

  @override
  Future<WorktreeInfo> createWorktree({
    required String projectDirectory,
    String? name,
  }) async {
    if (createError case final error?) throw error;
    createName = name;
    final created = WorktreeInfo(
      name: name?.isNotEmpty == true ? name! : 'fresh-tree',
      directory: '/data/worktree/project-1/${name ?? 'fresh-tree'}',
      branch: 'opencode/${name ?? 'fresh-tree'}',
    );
    worktrees = [...worktrees, created];
    return created;
  }

  @override
  Future<List<VersionControlFile>> listWorktreeFileStatuses(
    String directory,
  ) async => statuses;

  @override
  Future<void> resetWorktree({
    required String projectDirectory,
    required String directory,
  }) async => resetCalls.add(directory);

  @override
  Future<void> removeWorktree({
    required String projectDirectory,
    required String directory,
  }) async {
    if (removeError case final error?) throw error;
    removeCalls.add(directory);
    worktrees = worktrees
        .where((worktree) => worktree.directory != directory)
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WorktreeController extends ConnectionController {
  _WorktreeController(super.store);

  final locations = <String?>[];
  var created = 0;
  ServerCapabilities? capabilitiesOverride;

  @override
  ServerCapabilities get capabilities =>
      capabilitiesOverride ?? super.capabilities;

  @override
  Future<Session> createSession() async {
    created += 1;
    return Session(id: 'ses_new', directory: directory);
  }

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async =>
      repository;

  @override
  Future<void> selectLocation({String? directory, String? workspace}) async {
    if (this.directory == directory && this.workspace == workspace) return;
    locations.add(directory);
    this.directory = directory;
    this.workspace = workspace;
    dataRefreshRevision += 1;
    notifyListeners();
  }

  @override
  Future<void> selectLocationForExistingSession({
    String? directory,
    String? workspace,
  }) => selectLocation(directory: directory, workspace: workspace);
}

Future<_WorktreeController> _controller(
  ProductRepository repository, {
  String directory = '/work/app',
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return _WorktreeController(ProfileStore(prefs: preferences))
    ..repository = repository
    ..directory = directory
    ..status = StreamStatus.connected;
}

Widget _app(
  ConnectionController controller, {
  double textScale = 1,
  WorkspaceProject project = _project,
}) => MaterialApp(
  routes: {'/chat/ses_new': (_) => const Scaffold(body: Text('New chat'))},
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: WorktreesScreen(controller: controller, project: project),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('slice-R13', () {
    testWidgets('the title names the list: no group label, no count and no '
        'refresh in the top bar; pulling down reloads', (tester) async {
      final repository = _WorktreeRepository();
      final controller = await _controller(repository);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      // "Worktrees" is said once, by the title.
      expect(find.text('Worktrees'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('worktrees-section-label')),
        findsNothing,
      );
      expect(find.text('1'), findsNothing);
      expect(find.byTooltip('Refresh worktrees'), findsNothing);

      final before = repository.listCalls;
      await tester.fling(
        find.byKey(const ValueKey('worktrees-list')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(repository.listCalls, greaterThan(before));
    });

    testWidgets('the main copy and the worktrees are one list', (tester) async {
      final controller = await _controller(_WorktreeRepository());
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      final group = find.byKey(const ValueKey('worktrees-group'));
      expect(
        find.descendant(
          of: group,
          matching: find.byKey(const ValueKey('primary-worktree')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: group, matching: find.byKey(const ValueKey(_row))),
        findsOneWidget,
      );
    });

    testWidgets('with none yet, the empty state says what a worktree is', (
      tester,
    ) async {
      final repository = _WorktreeRepository()..worktrees = const [];
      final controller = await _controller(repository);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('no-worktrees')), findsOneWidget);
      expect(
        find.textContaining('A worktree is a separate copy'),
        findsOneWidget,
      );
    });
  });

  testWidgets('compact worktree creation grows into global ready state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _WorktreeRepository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, textScale: 2));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('primary-worktree')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('worktree-/data/worktree/project-1/mobile-review'),
      ),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('mobile-review'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-worktree')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('worktree-name-field')),
      'wake-fix',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-create-worktree')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.createName, 'wake-fix');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('worktree-/data/worktree/project-1/wake-fix')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('wake-fix'), findsOneWidget);
    // The row says it is being prepared, in words (STATE-9).
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('worktree-/data/worktree/project-1/wake-fix'),
        ),
        matching: find.textContaining('Preparing files and project tasks'),
      ),
      findsOneWidget,
    );

    controller.handleEventForTesting(
      EventEnvelope(
        type: 'worktree.ready',
        directory: '/data/worktree/project-1/wake-fix',
        project: 'project-1',
        properties: const {'name': 'wake-fix', 'branch': 'opencode/wake-fix'},
      ),
    );
    await tester.pump();

    expect(find.text('opencode/wake-fix'), findsOneWidget);
    // Ready: the next step, a conversation in it, is offered in place.
    expect(find.text('wake-fix is ready'), findsOneWidget);
    expect(find.byKey(const ValueKey('worktrees-ready-start')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failing worktree action reports product copy, not the raw '
      'exception', (tester) async {
    // The five _showError call sites passed error.toString(), which put
    // "Bad state: ..." back in front of users at exactly the wrong moment.
    final repository = _WorktreeRepository()..createError = StateError('boom');
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-worktree')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('worktree-name-field')),
      'wake-fix',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-create-worktree')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Bad state'), findsNothing);
    expect(
      find.text(
        "That didn't work. Details show what happened. Try again, or report the problem.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('reset explains and confirms every destructive file class', (
    tester,
  ) async {
    final repository = _WorktreeRepository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    // Rarer acts open on long-press (KIT-28), not a per-row button.
    await tester.longPress(find.byKey(const ValueKey(_row)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Reset mobile-review?'), findsOneWidget);
    expect(find.textContaining('1 changed file was detected'), findsOneWidget);
    expect(find.textContaining('untracked and ignored files'), findsOneWidget);
    expect(find.textContaining('Submodules are also reset'), findsOneWidget);
    // With changes, reset asks for the typed name, like delete.
    await tester.enterText(
      find.byKey(const ValueKey('kit-confirm-typed-name')),
      'mobile-review',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-reset-worktree')));
    await tester.pumpAndSettle();

    expect(repository.resetCalls, ['/data/worktree/project-1/mobile-review']);
  });

  testWidgets('removing the current worktree switches to primary first', (
    tester,
  ) async {
    final repository = _WorktreeRepository();
    final controller = await _controller(
      repository,
      directory: '/legacy/data/project-1/mobile-review',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, project: _aliasedProject));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey(_row)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('kit-confirm-typed-name')),
      'mobile-review',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-remove-worktree')));
    await tester.pumpAndSettle();

    expect(controller.locations, ['/work/app']);
    expect(repository.removeCalls, ['/data/worktree/project-1/mobile-review']);
    expect(find.text('No isolated worktrees yet'), findsOneWidget);
  });

  testWidgets('a failed delete keeps the question open with Try again', (
    tester,
  ) async {
    final repository = _WorktreeRepository()
      ..removeError = const ProductException('Server refused');
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey(_row)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('kit-confirm-typed-name')),
      'mobile-review',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-remove-worktree')));
    await tester.pumpAndSettle();

    // Still asking: nothing claims it was deleted.
    expect(find.text('Delete mobile-review?'), findsOneWidget);
    expect(find.textContaining('were deleted'), findsNothing);
    expect(find.byKey(const ValueKey(_row)), findsOneWidget);
  });

  testWidgets('a clean worktree resets without typing its name', (
    tester,
  ) async {
    final repository = _WorktreeRepository()..statuses = const [];
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey(_row)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kit-confirm-typed-name')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('confirm-reset-worktree')));
    await tester.pumpAndSettle();

    expect(repository.resetCalls, ['/data/worktree/project-1/mobile-review']);
    expect(
      find.text('mobile-review reset to the default branch'),
      findsOneWidget,
    );
  });

  testWidgets('New conversation here switches to the worktree and opens it', (
    tester,
  ) async {
    final repository = _WorktreeRepository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey(_row)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New conversation here'));
    await tester.pumpAndSettle();

    expect(controller.locations, ['/data/worktree/project-1/mobile-review']);
    expect(controller.created, 1);
    expect(find.text('New chat'), findsOneWidget);
  });

  testWidgets('without the create call there is no New worktree at all', (
    tester,
  ) async {
    final repository = _WorktreeRepository()..worktrees = const [];
    final controller = await _controller(repository);
    controller.capabilitiesOverride = const ServerCapabilities(
      worktreeCreate: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('create-worktree')), findsNothing);
    expect(find.text('No isolated worktrees yet'), findsOneWidget);
    expect(
      find.textContaining('Main copy', findRichText: true),
      findsOneWidget,
    );
  });
}
