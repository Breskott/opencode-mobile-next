import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/screens/isolated_task_sheet.dart';
import 'package:opencode_mobile/ui/screens/worktrees_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _project = WorkspaceProject(
  id: 'project-1',
  name: 'OpenCode Mobile',
  directory: '/work/app',
  worktrees: [],
  updatedAt: 1,
);

const _otherProject = WorkspaceProject(
  id: 'project-2',
  name: 'Other',
  directory: '/work/other',
  worktrees: [],
  updatedAt: 1,
);

const _directory = '/data/worktree/project-1/wake-fix';

class _Repository implements ProductRepository {
  Completer<WorktreeInfo> create = Completer<WorktreeInfo>();
  WorkspaceProject? currentProject = _project;
  final removeCalls = <String>[];
  final resetCalls = <String>[];
  String? createName;
  String? createProjectDirectory;
  List<WorkspaceProject> projects = const [_project];
  Future<void> Function()? beforeProjects;

  @override
  Future<List<WorkspaceProject>> listProjects() async {
    await beforeProjects?.call();
    return projects;
  }

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<WorktreeInfo> createWorktree({
    required String projectDirectory,
    String? name,
  }) {
    createProjectDirectory = projectDirectory;
    createName = name;
    return create.future;
  }

  @override
  Future<WorkspaceProject?> loadCurrentProject() async => currentProject;

  @override
  Future<void> removeWorktree({
    required String projectDirectory,
    required String directory,
  }) async => removeCalls.add(directory);

  @override
  Future<void> resetWorktree({
    required String projectDirectory,
    required String directory,
  }) async => resetCalls.add(directory);

  @override
  Future<List<WorktreeInfo>> listWorktrees({
    required String projectDirectory,
    String? projectID,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends ConnectionController {
  _Controller(super.store);

  final locations = <String?>[];
  final createdSessions = <Session>[];
  Object? selectLocationError;
  ServerCapabilities capabilityOverride = ServerCapabilities.allV1;
  Future<void> Function()? beforeRepository;
  Future<void> Function()? beforeTransport;
  Future<void> Function()? duringSelection;

  @override
  ServerCapabilities get capabilities => capabilityOverride;

  /// The selected profile (the draft's owner), when a test sets one.
  ServerProfile? profileOverride;

  @override
  ServerProfile? get profile => profileOverride ?? super.profile;

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async {
    await beforeRepository?.call();
    return repository;
  }

  @override
  Future<ServerGateway?> prepareActionTransport() async {
    await beforeTransport?.call();
    return api;
  }

  @override
  Future<void> selectLocation({String? directory, String? workspace}) async {
    if (selectLocationError case final error?) throw error;
    locations.add(directory);
    if (this.directory != directory || this.workspace != workspace) {
      locationRevision++;
      connectionRevision++;
    }
    this.directory = directory;
    this.workspace = workspace;
    notifyListeners();
    await duringSelection?.call();
  }

  @override
  Future<void> selectLocationForExistingSession({
    String? directory,
    String? workspace,
  }) => selectLocation(directory: directory, workspace: workspace);
}

/// One prompt the sheet sent.
class _Prompt {
  const _Prompt(this.sessionID, this.text);
  final String sessionID;
  final String text;
}

class _Gateway implements ServerGateway {
  _Gateway(this.controller);
  final _Controller controller;
  final prompts = <_Prompt>[];
  Object? promptError;

  @override
  Future<void> promptAsync(
    String sessionID, {
    required String text,
    ModelRef? model,
    String? agent,
    String? variant,
    List<PromptAttachment> attachments = const [],
    List<PromptAgentMention> agentMentions = const [],
    PromptDelivery? delivery,
  }) async {
    if (promptError case final error?) throw error;
    prompts.add(_Prompt(sessionID, text));
  }

  @override
  Future<Session> createSession() async {
    final session = Session(
      id: 'ses_${controller.createdSessions.length + 1}',
      projectID: 'project-1',
      directory: controller.directory,
    );
    controller.createdSessions.add(session);
    return session;
  }

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Controller> _controller(_Repository repository) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = _Controller(ProfileStore(prefs: preferences))
    ..repository = repository
    ..directory = '/work/app'
    ..status = StreamStatus.connected;
  controller.adoptConnectedProfileForTesting(
    ServerProfile(id: 'remote', name: 'remote', baseUrl: 'http://127.0.0.1:1'),
  );
  controller.api = _Gateway(controller);
  return controller;
}

/// Hosts a button that opens the sheet and records what it resolved with.
class _Host extends StatefulWidget {
  const _Host({required this.controller, required this.timeout});

  final ConnectionController controller;
  final Duration timeout;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final results = <Session?>[];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const Key('open-sheet'),
        onPressed: () async {
          results.add(
            await showIsolatedTaskSheet(
              context,
              controller: widget.controller,
              project: _project,
              readinessTimeout: widget.timeout,
            ),
          );
        },
        child: const Text('open'),
      ),
    ),
  );
}

Future<_HostState> _openSheet(
  WidgetTester tester,
  _Controller controller, {
  Duration timeout = const Duration(seconds: 45),
  String? name,
  String? task,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: _Host(controller: controller, timeout: timeout),
    ),
  );
  await tester.tap(find.byKey(const Key('open-sheet')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('isolated-task-sheet')), findsOneWidget);
  if (task != null) {
    await tester.enterText(find.byKey(const Key('isolated-task-prompt')), task);
  }
  if (name != null) {
    await tester.tap(find.byKey(const Key('isolated-task-options')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('isolated-task-name')), name);
  }
  await tester.ensureVisible(find.byKey(const Key('isolated-task-start')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('isolated-task-start')));
  await tester.pump();
  return tester.state<_HostState>(find.byType(_Host));
}

void _ready(_Controller controller) => controller.handleEventForTesting(
  EventEnvelope(
    type: 'worktree.ready',
    directory: _directory,
    project: 'project-1',
    properties: const {'name': 'wake-fix', 'branch': 'opencode/wake-fix'},
  ),
);

const _created = WorktreeInfo(
  name: 'wake-fix',
  directory: _directory,
  branch: 'opencode/wake-fix',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile switch before Start permanently retires the sheet', (
    tester,
  ) async {
    final original = _Repository();
    final other = _Repository();
    final controller = await _controller(original);
    addTearDown(controller.dispose);
    final originalScope = controller.isolatedTaskScope;
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          controller: controller,
          timeout: const Duration(seconds: 45),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pumpAndSettle();
    // Retain the original callback to exercise a stale queued tap as well.
    final start = tester
        .widget<KitButton>(find.byKey(const Key('isolated-task-start')))
        .onPressed!;
    controller.repository = other;
    controller.adoptConnectedProfileForTesting(
      ServerProfile(id: 'other', name: 'Other', baseUrl: 'http://127.0.0.1:2'),
    );
    controller.notifyListeners();
    await tester.pumpAndSettle();
    start();
    expect(
      () => controller.startIsolatedTask(
        project: _project,
        expectedScope: originalScope,
      ),
      throwsA(isA<ProductException>()),
    );
    controller.repository = original;
    controller.adoptConnectedProfileForTesting(
      ServerProfile(
        id: 'remote',
        name: 'remote',
        baseUrl: 'http://127.0.0.1:1',
      ),
    );
    controller.notifyListeners();
    await tester.pumpAndSettle();
    start();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('start again from the project you want'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('isolated-task-start')), findsNothing);
    expect(original.createProjectDirectory, isNull);
    expect(other.createProjectDirectory, isNull);
    expect(controller.createdSessions, isEmpty);
    expect(original.removeCalls, isEmpty);
    expect(other.removeCalls, isEmpty);
  });

  testWidgets('cached project absent from current catalog never creates', (
    tester,
  ) async {
    final repository = _Repository()..projects = const [_otherProject];
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await _openSheet(tester, controller);
    await tester.pumpAndSettle();
    expect(repository.createProjectDirectory, isNull);
    expect(controller.createdSessions, isEmpty);
    expect(
      find.textContaining('project could not be confirmed'),
      findsOneWidget,
    );
  });

  testWidgets('scope change while revalidating catalog refuses creation', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    repository.beforeProjects = () async {
      controller.locationRevision++;
    };
    await _openSheet(tester, controller);
    await tester.pumpAndSettle();
    expect(repository.createProjectDirectory, isNull);
    expect(controller.createdSessions, isEmpty);
  });

  for (final stage in ['selection', 'repository', 'transport']) {
    testWidgets(
      'same-directory workspace change during $stage refuses opening',
      (tester) async {
        final repository = _Repository();
        final controller = await _controller(repository);
        addTearDown(controller.dispose);
        final host = await _openSheet(tester, controller);
        repository.create.complete(_created);
        await tester.pump();
        final entered = Completer<void>();
        final release = Completer<void>();
        Future<void> hold() async {
          if (!entered.isCompleted) entered.complete();
          await release.future;
        }

        switch (stage) {
          case 'selection':
            controller.duringSelection = hold;
          case 'repository':
            controller.beforeRepository = hold;
          case 'transport':
            controller.beforeTransport = hold;
        }
        _ready(controller);
        await tester.pump();
        expect(entered.isCompleted, isTrue);
        expect(controller.directory, _directory);
        controller.duringSelection = null;
        await controller.selectLocation(
          directory: _directory,
          workspace: 'other-workspace',
        );
        release.complete();
        await tester.pumpAndSettle();
        expect(controller.workspace, 'other-workspace');
        expect(controller.createdSessions, isEmpty);
        expect(host.results, isEmpty);
        expect(repository.removeCalls, isEmpty);
        expect(repository.resetCalls, isEmpty);
        expect(
          find.byKey(const Key('isolated-task-open-error')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('connection change during repository preparation blocks create', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    controller.beforeRepository = () async {
      controller.adoptConnectedProfileForTesting(
        ServerProfile(
          id: 'other',
          name: 'Other',
          baseUrl: 'http://127.0.0.1:2',
        ),
      );
    };
    await _openSheet(tester, controller);
    await tester.pumpAndSettle();
    expect(repository.createProjectDirectory, isNull);
    expect(controller.createdSessions, isEmpty);
    expect(find.byKey(const Key('isolated-task-dismiss')), findsOneWidget);
  });

  testWidgets(
    'scope change while waiting for readiness blocks automatic open',
    (tester) async {
      final repository = _Repository();
      final controller = await _controller(repository);
      addTearDown(controller.dispose);
      await _openSheet(tester, controller);
      repository.create.complete(_created);
      await tester.pump();
      controller.directory = '/work/other';
      _ready(controller);
      await tester.pumpAndSettle();
      expect(controller.locations, isEmpty);
      expect(controller.createdSessions, isEmpty);
      expect(find.byKey(const Key('isolated-task-open-error')), findsOneWidget);
    },
  );

  testWidgets('transport preparation cannot retarget session creation', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    controller.beforeTransport = () async {
      controller.directory = '/work/other';
    };
    await _openSheet(tester, controller);
    repository.create.complete(_created);
    await tester.pump();
    _ready(controller);
    await tester.pumpAndSettle();
    expect(controller.createdSessions, isEmpty);
    expect(find.byKey(const Key('isolated-task-open-error')), findsOneWidget);
  });

  testWidgets('unresolved current project refuses session creation', (
    tester,
  ) async {
    final repository = _Repository()..currentProject = null;
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await _openSheet(tester, controller);
    repository.create.complete(_created);
    await tester.pump();
    _ready(controller);
    await tester.pumpAndSettle();
    expect(controller.createdSessions, isEmpty);
    expect(find.textContaining('could not be confirmed'), findsOneWidget);
  });

  testWidgets('ready worktree opens a blank session in its scope', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    final host = await _openSheet(tester, controller, name: 'wake-fix');

    expect(find.text('Making the copy…'), findsOneWidget);
    expect(repository.createName, 'wake-fix');
    expect(repository.createProjectDirectory, '/work/app');
    expect(find.byKey(const Key('isolated-task-stop')), findsOneWidget);

    repository.create.complete(_created);
    await tester.pump();
    expect(find.text('Setting up wake-fix…'), findsOneWidget);
    // The branch and folder are technical: under Details only.
    expect(find.text('opencode/wake-fix'), findsNothing);
    expect(controller.locations, isEmpty, reason: 'no switch before ready');

    _ready(controller);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(controller.locations, [_directory]);
    expect(controller.createdSessions, hasLength(1));
    expect(host.results, hasLength(1));
    expect(host.results.single?.id, 'ses_1');
    expect(host.results.single?.directory, _directory);
    expect(find.byKey(const Key('isolated-task-sheet')), findsNothing);
    expect(repository.removeCalls, isEmpty);
    expect(repository.resetCalls, isEmpty);
  });

  testWidgets('a ready event that beats the create response still counts', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    final host = await _openSheet(tester, controller);

    _ready(controller);
    await tester.pump();
    expect(find.text('Making the copy…'), findsOneWidget);

    repository.create.complete(_created);
    await tester.pumpAndSettle();
    expect(controller.createdSessions, hasLength(1));
    expect(host.results.single?.id, 'ses_1');
  });

  testWidgets('no readiness within the wait needs an explicit open', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    final host = await _openSheet(
      tester,
      controller,
      timeout: const Duration(seconds: 2),
    );
    repository.create.complete(_created);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.text("wake-fix is made, but its setup hasn't reported back."),
      findsOneWidget,
    );
    expect(controller.createdSessions, isEmpty);
    expect(find.byKey(const Key('isolated-task-keep-waiting')), findsOneWidget);

    await tester.tap(find.byKey(const Key('isolated-task-keep-waiting')));
    await tester.pump();
    expect(find.text('Setting up wake-fix…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('isolated-task-open-anyway')), findsOneWidget);

    await tester.tap(find.byKey(const Key('isolated-task-open-anyway')));
    await tester.pumpAndSettle();
    expect(controller.locations, [_directory]);
    expect(controller.createdSessions, hasLength(1));
    expect(host.results.single?.id, 'ses_1');
  });

  testWidgets('stop waiting keeps the worktree and creates no session', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    final host = await _openSheet(tester, controller);
    repository.create.complete(_created);
    await tester.pump();

    await tester.tap(find.byKey(const Key('isolated-task-stop')));
    await tester.pumpAndSettle();

    expect(host.results, [null]);
    expect(find.byKey(const Key('isolated-task-sheet')), findsNothing);
    expect(controller.locations, isEmpty);
    expect(controller.createdSessions, isEmpty);
    expect(repository.removeCalls, isEmpty, reason: 'never an implicit delete');

    // A late ready must not open anything after the user left.
    _ready(controller);
    await tester.pumpAndSettle();
    expect(controller.createdSessions, isEmpty);
  });

  testWidgets('stopping before the response warns that create may run', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await _openSheet(tester, controller);
    expect(
      find.text(
        'If you stop waiting, the copy may still be made. '
        "You'll find it under Project › Worktrees.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('isolated-task-stop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('isolated-task-sheet')), findsNothing);

    repository.create.complete(_created);
    await tester.pumpAndSettle();
    expect(controller.createdSessions, isEmpty);
    expect(repository.removeCalls, isEmpty);
  });

  void failSetup(_Controller controller) => controller.handleEventForTesting(
    EventEnvelope(
      type: 'worktree.failed',
      directory: _directory,
      project: 'project-1',
      properties: const {'message': 'setup script exited 1'},
    ),
  );

  testWidgets('a failed setup names the copy, keeps the setup output under '
      'Details, and offers Start anyway, Remove the copy and Close', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    final host = await _openSheet(tester, controller);
    repository.create.complete(_created);
    await tester.pump();
    failSetup(controller);
    await tester.pump();

    expect(find.text('Setup failed in wake-fix'), findsOneWidget);
    expect(
      find.text(
        "The copy is made, but its setup didn't finish. Start in it anyway, "
        'or remove it.',
      ),
      findsOneWidget,
    );
    // The script's own words are technical: never the body, only Details.
    expect(find.textContaining('setup script exited 1'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('isolated-task-details')));
    await tester.tap(find.byKey(const Key('isolated-task-details')));
    await tester.pumpAndSettle();
    expect(find.textContaining('setup script exited 1'), findsOneWidget);
    expect(find.text('What the setup reported'), findsOneWidget);

    expect(find.byKey(const Key('isolated-task-start-anyway')), findsOneWidget);
    expect(find.byKey(const Key('isolated-task-remove')), findsOneWidget);
    expect(find.byKey(const Key('isolated-task-dismiss')), findsOneWidget);
    await tester.tap(find.byKey(const Key('isolated-task-dismiss')));
    await tester.pumpAndSettle();
    expect(host.results, [null]);
    expect(controller.createdSessions, isEmpty);
    expect(repository.removeCalls, isEmpty, reason: 'never an implicit delete');
  });

  testWidgets('Start anyway opens the conversation in a copy whose setup '
      'failed and sends the task', (tester) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    final gateway = controller.api! as _Gateway;
    final host = await _openSheet(tester, controller, task: 'Fix the login');
    repository.create.complete(_created);
    await tester.pump();
    failSetup(controller);
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const Key('isolated-task-start-anyway')),
    );
    await tester.tap(find.byKey(const Key('isolated-task-start-anyway')));
    await tester.pumpAndSettle();
    expect(controller.locations, [_directory]);
    expect(host.results.single?.id, 'ses_1');
    expect(gateway.prompts.single.sessionID, 'ses_1');
    expect(gateway.prompts.single.text, 'Fix the login');
  });

  testWidgets('Remove the copy asks once, removes it and returns to the form '
      'with the words kept', (tester) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await _openSheet(tester, controller, task: 'Fix the login');
    repository.create.complete(_created);
    await tester.pump();
    failSetup(controller);
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('isolated-task-remove')));
    await tester.tap(find.byKey(const Key('isolated-task-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Remove wake-fix?'), findsOneWidget);
    expect(repository.removeCalls, isEmpty);
    await tester.tap(find.byKey(const Key('isolated-task-remove-confirm')));
    await tester.pumpAndSettle();

    expect(repository.removeCalls, [_directory]);
    expect(find.byKey(const Key('isolated-task-removed')), findsOneWidget);
    expect(find.text('Removed wake-fix. You can start again.'), findsOneWidget);
    expect(find.text('Fix the login'), findsOneWidget);
    expect(find.byKey(const Key('isolated-task-start')), findsOneWidget);
    expect(controller.createdSessions, isEmpty);
  });

  testWidgets('a typed task is sent to the new conversation once it opens', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    final gateway = controller.api! as _Gateway;
    final host = await _openSheet(tester, controller, task: 'Fix the login');
    repository.create.complete(_created);
    await tester.pump();
    expect(gateway.prompts, isEmpty, reason: 'nothing before the copy');
    _ready(controller);
    await tester.pumpAndSettle();

    expect(host.results.single?.id, 'ses_1');
    expect(gateway.prompts, hasLength(1));
    expect(gateway.prompts.single.sessionID, 'ses_1');
    expect(gateway.prompts.single.text, 'Fix the login');
  });

  testWidgets('with no task typed the conversation opens blank', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    final gateway = controller.api! as _Gateway;
    final host = await _openSheet(tester, controller);
    repository.create.complete(_created);
    await tester.pump();
    _ready(controller);
    await tester.pumpAndSettle();
    expect(host.results.single?.id, 'ses_1');
    expect(gateway.prompts, isEmpty);
  });

  testWidgets('a task that could not be sent waits as the conversation\'s '
      'draft, and the sheet says so before opening it', (tester) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    final gateway = controller.api! as _Gateway
      ..promptError = const ProductException('upstream 502');
    final host = await _openSheet(tester, controller, task: 'Fix the login');
    repository.create.complete(_created);
    await tester.pump();
    _ready(controller);
    await tester.pumpAndSettle();

    expect(host.results, isEmpty);
    expect(find.text("Couldn't send your task"), findsOneWidget);
    expect(
      find.text(
        "It's waiting in the conversation's message box, ready to send.",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('upstream 502'), findsNothing);
    expect(gateway.prompts, isEmpty);
    expect(controller.sessionDraft('ses_1'), 'Fix the login');

    await tester.tap(find.byKey(const Key('isolated-task-open-conversation')));
    await tester.pumpAndSettle();
    expect(host.results.single?.id, 'ses_1');
  });

  testWidgets('a failed create says so in words and Try again sends the same '
      'request again', (tester) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await _openSheet(tester, controller, task: 'Fix the login');
    repository.create.completeError(
      ApiException('fatal: not a git repository', statusCode: 500),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't make the copy"), findsOneWidget);
    expect(find.textContaining('fatal: not a git repository'), findsNothing);

    repository.create = Completer<WorktreeInfo>();
    await tester.ensureVisible(
      find.byKey(const Key('isolated-task-try-again')),
    );
    await tester.tap(find.byKey(const Key('isolated-task-try-again')));
    await tester.pump();
    expect(find.text('Making the copy…'), findsOneWidget);
    repository.create.complete(_created);
    await tester.pump();
    _ready(controller);
    await tester.pumpAndSettle();
    expect(controller.createdSessions, hasLength(1));
    expect((controller.api! as _Gateway).prompts.single.text, 'Fix the login');
  });

  testWidgets('a task typed and closed is back on the next open, and gone '
      'once it reached its conversation', (tester) async {
    final repository = _Repository();
    final controller = await _controller(repository)
      ..profileOverride = ServerProfile(
        id: 'remote',
        name: 'remote',
        baseUrl: 'http://127.0.0.1:1',
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          controller: controller,
          timeout: const Duration(seconds: 45),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('isolated-task-prompt')),
      'Fix the login',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('isolated-task-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('isolated-task-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pumpAndSettle();
    expect(find.text('Fix the login'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('isolated-task-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('isolated-task-start')));
    await tester.pump();
    repository.create.complete(_created);
    await tester.pump();
    _ready(controller);
    await tester.pumpAndSettle();
    expect((controller.api! as _Gateway).prompts.single.text, 'Fix the login');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('oc.draft.isolated.task.remote'), isNull);
  });

  testWidgets('the form asks what to work on first and keeps the name under '
      'Options', (tester) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          controller: controller,
          timeout: const Duration(seconds: 45),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pumpAndSettle();
    expect(find.text('Start in a separate copy'), findsOneWidget);
    expect(
      find.text(
        "Works on its own branch, so it can't clash with your other "
        'conversations.',
      ),
      findsOneWidget,
    );
    expect(find.text('What should it work on?'), findsOneWidget);
    expect(find.byKey(const Key('isolated-task-name')), findsNothing);
    expect(find.textContaining('worktree'), findsNothing);
    await tester.tap(find.byKey(const Key('isolated-task-options')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('isolated-task-name')), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('a scope that resolves to another project refuses the session', (
    tester,
  ) async {
    final repository = _Repository()..currentProject = _otherProject;
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    final host = await _openSheet(tester, controller);
    repository.create.complete(_created);
    await tester.pump();
    _ready(controller);
    await tester.pumpAndSettle();

    expect(controller.locations, [_directory]);
    expect(controller.createdSessions, isEmpty);
    expect(host.results, isEmpty);
    expect(find.byKey(const Key('isolated-task-open-error')), findsOneWidget);
    expect(find.textContaining('could not be confirmed'), findsOneWidget);
    expect(find.byKey(const Key('isolated-task-retry-open')), findsOneWidget);

    repository.currentProject = _project;
    await tester.tap(find.byKey(const Key('isolated-task-retry-open')));
    await tester.pumpAndSettle();
    expect(controller.createdSessions, hasLength(1));
    expect(host.results.single?.id, 'ses_1');
  });

  testWidgets('a failed location switch keeps the launch openable', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository)
      ..selectLocationError = const ProductException('switch failed');
    addTearDown(controller.dispose);
    await _openSheet(tester, controller);
    repository.create.complete(_created);
    await tester.pump();
    _ready(controller);
    await tester.pumpAndSettle();

    expect(controller.createdSessions, isEmpty);
    expect(find.textContaining('switch failed'), findsOneWidget);
    expect(find.byKey(const Key('isolated-task-retry-open')), findsOneWidget);
    expect(find.byKey(const Key('isolated-task-dismiss')), findsOneWidget);
  });

  testWidgets('without the create capability the sheet refuses to start', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository)
      ..capabilityOverride = const ServerCapabilities(worktreeCreate: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          controller: controller,
          timeout: const Duration(seconds: 1),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('isolated-task-start')));
    await tester.pumpAndSettle();

    expect(repository.createName, isNull);
    expect(find.byKey(const Key('isolated-task-sheet')), findsOneWidget);
    expect(
      find.textContaining('Creating worktrees is not available'),
      findsOneWidget,
    );
  });

  testWidgets('Worktrees screen hides Create without the capability', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository)
      ..capabilityOverride = const ServerCapabilities(worktreeCreate: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: WorktreesScreen(controller: controller, project: _project),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-worktree')), findsNothing);
    expect(find.byKey(const ValueKey('primary-worktree')), findsOneWidget);

    controller.capabilityOverride = ServerCapabilities.allV1;
    await tester.pumpWidget(
      MaterialApp(
        home: WorktreesScreen(controller: controller, project: _project),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-worktree')), findsOneWidget);
  });
}
