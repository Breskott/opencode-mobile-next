import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/team_project_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/project_fixture_gateway.dart';

class MemoryPersistence implements TeamProjectPersistence {
  String? value;
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    if (pending != null) await pending!.future;
    if (fail) throw StateError('private backend error');
    value = next;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  late MemoryPersistence store;
  late ProjectFixtureGateway gateway;
  var request = 0;
  Future<TeamProject> project() async =>
      (await gateway.teamWorkspace()).projects.first;
  Future<TeamCommandResult> command(
    TeamProjectAction action, {
    String targetId = '',
    String text = '',
    bool confirmed = false,
    String expectedDevCommit = '',
    String expectedMainCommit = '',
    List<TeamTask>? tasks,
  }) async {
    final p = await project();
    return gateway.executeProject(
      TeamProjectCommand(
        requestId: 'request-${request++}',
        action: action,
        projectId: p.id,
        expectedRevision: p.revision,
        targetId: targetId,
        text: text,
        confirmed: confirmed,
        expectedDevCommit: expectedDevCommit,
        expectedMainCommit: expectedMainCommit,
        tasks: tasks,
      ),
    );
  }

  Future<void> create() async {
    final r = await gateway.executeProject(
      const TeamProjectCommand(
        requestId: 'create',
        action: TeamProjectAction.createProject,
        name: 'Build a useful project',
        spec: TeamSpec(goal: 'A complete accessible journey'),
        repos: [TeamRepo(id: 'app', name: 'App', serverId: 'computer')],
        settings: TeamProjectSettings(
          mode: 'parallel',
          maxLanes: 2,
          budget: TeamBudget(chosen: true, unlimited: true),
        ),
      ),
    );
    expect(r.accepted, isTrue);
  }

  Future<void> start() async {
    await create();
    expect(
      (await command(
        TeamProjectAction.answerRequest,
        targetId: 'project-1-question',
        text: 'Saved work survives a restart',
      )).accepted,
      isTrue,
    );
    expect((await command(TeamProjectAction.approveSpec)).accepted, isTrue);
    expect((await command(TeamProjectAction.approvePlan)).accepted, isTrue);
  }

  setUp(() {
    store = MemoryPersistence();
    gateway = ProjectFixtureGateway(
      persistence: store,
      seedDemo: false,
      now: () => DateTime.utc(2026, 9, 29, 12),
    );
    request = 0;
  });
  tearDown(() async {
    await gateway.close();
  });
  test('explicit mode and budget are required before creating work', () async {
    final r = await gateway.executeProject(
      const TeamProjectCommand(
        requestId: 'bad',
        action: TeamProjectAction.createProject,
        name: 'Missing choices',
        spec: TeamSpec(goal: 'Goal'),
      ),
    );
    expect(r.accepted, isFalse);
    expect((await gateway.teamWorkspace()).projects, isEmpty);
  });
  test(
    'full lifecycle checks fixes rechecks merges and confirms exact commits',
    () async {
      await start();
      for (var i = 0; i < 4; i++) {
        await gateway.advance();
      }
      final task = (await project()).tasks.first;
      expect(task.status, 'review');
      expect(
        (await command(
          TeamProjectAction.verifyTask,
          targetId: task.id,
        )).accepted,
        isTrue,
      );
      expect((await project()).tasks.first.status, 'findings');
      await command(TeamProjectAction.fixFindings, targetId: task.id);
      await command(TeamProjectAction.recheckTask, targetId: task.id);
      await command(TeamProjectAction.processMergeQueue);
      var p = await project();
      expect(p.tasks.first.status, 'merged');
      expect(p.repos.first.mainCommit, 'fixture-base');
      expect(
        (await command(
          TeamProjectAction.promote,
          targetId: 'app',
          confirmed: true,
          expectedDevCommit: 'stale',
          expectedMainCommit: 'fixture-base',
        )).code,
        'staleCommits',
      );
      expect(
        (await command(
          TeamProjectAction.promote,
          targetId: 'app',
          expectedDevCommit: p.repos.first.devCommit,
          expectedMainCommit: p.repos.first.mainCommit,
        )).code,
        'confirmationRequired',
      );
      expect(
        (await command(
          TeamProjectAction.promote,
          targetId: 'app',
          confirmed: true,
          expectedDevCommit: p.repos.first.devCommit,
          expectedMainCommit: p.repos.first.mainCommit,
        )).accepted,
        isTrue,
      );
      p = await project();
      expect(p.repos.first.mainCommit, p.repos.first.devCommit);
      expect(p.receipts.map((r) => r.kind), ['merge', 'promotion']);
    },
  );
  test(
    'restart preserves approved spec and receipts and interrupts live work',
    () async {
      await start();
      await gateway.advance();
      expect((await project()).tasks.first.status, 'running');
      await gateway.close();
      gateway = ProjectFixtureGateway(persistence: store, seedDemo: false);
      final p = await project();
      expect(p.tasks.first.status, 'interrupted');
      expect(p.specVersions, hasLength(1));
      expect(
        (await command(
          TeamProjectAction.resumeTask,
          targetId: p.tasks.first.id,
        )).accepted,
        isTrue,
      );
      await gateway.advance();
      expect((await project()).tasks.first.status, 'running');
    },
  );
  test(
    'persist before publishing and reject stale or reused commands',
    () async {
      await create();
      final p = await project();
      final c = TeamProjectCommand(
        requestId: 'pause',
        action: TeamProjectAction.pauseProject,
        projectId: p.id,
        expectedRevision: p.revision,
      );
      store.fail = true;
      expect((await gateway.executeProject(c)).code, 'saveFailed');
      expect((await project()).status, 'spec');
      store.fail = false;
      expect((await gateway.executeProject(c)).accepted, isTrue);
      expect((await gateway.executeProject(c)).replayed, isTrue);
      expect(
        (await gateway.executeProject(
          TeamProjectCommand(
            requestId: 'stale',
            action: TeamProjectAction.stopProject,
            projectId: p.id,
            expectedRevision: p.revision,
          ),
        )).code,
        'staleRevision',
      );
      expect(
        (await gateway.executeProject(
          TeamProjectCommand(
            requestId: 'pause',
            action: TeamProjectAction.stopProject,
            projectId: p.id,
            expectedRevision: p.revision,
          ),
        )).code,
        'requestIdReused',
      );
    },
  );
  test('lane and dependency caps hold and a cycle is rejected', () async {
    await start();
    final p = await project();
    final t = p.tasks.first;
    final tasks = [
      t,
      t.copyWith(id: 'second', dependsOn: [t.id]),
      t.copyWith(id: 'third'),
      t.copyWith(id: 'fourth'),
    ];
    expect(
      (await command(TeamProjectAction.approvePlan, tasks: tasks)).accepted,
      isTrue,
    );
    await gateway.advance();
    final running = (await project()).tasks
        .where((t) => t.status == 'running')
        .map((t) => t.id);
    expect(running, hasLength(2));
    expect(running, isNot(contains('second')));
    final cyclic = [
      t.copyWith(dependsOn: ['second']),
      t.copyWith(id: 'second', dependsOn: [t.id]),
    ];
    expect(
      (await command(TeamProjectAction.approvePlan, tasks: cyclic)).code,
      'planAlreadyRunning',
    );
  });
  test('delete drains an in-flight write and prevents resurrection', () async {
    await create();
    final p = await project();
    store.pending = Completer<void>();
    final mutation = gateway.executeProject(
      TeamProjectCommand(
        requestId: 'pending',
        action: TeamProjectAction.pauseProject,
        projectId: p.id,
        expectedRevision: p.revision,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final deleting = gateway.deleteLocalData();
    store.pending!.complete();
    await mutation;
    await deleting;
    expect(store.value, isNull);
    expect(
      (await gateway.executeProject(
        const TeamProjectCommand(
          requestId: 'closed',
          action: TeamProjectAction.createProject,
        ),
      )).code,
      'closed',
    );
    await gateway.close();
  });
  test(
    'read-only projection never seeds or reconciles persisted work',
    () async {
      final empty = ProjectFixtureGateway(persistence: store, readOnly: true);
      expect((await empty.teamWorkspace()).projects, isEmpty);
      expect(store.value, isNull);
      await empty.close();
      await start();
      await gateway.advance();
      final original = store.value;
      final reader = ProjectFixtureGateway(persistence: store, readOnly: true);
      expect(
        (await reader.teamWorkspace()).projects.first.tasks.first.status,
        'running',
      );
      expect(
        (await reader.executeProject(
          const TeamProjectCommand(
            requestId: 'readonly',
            action: TeamProjectAction.updateDefaults,
          ),
        )).code,
        'readOnly',
      );
      await reader.deleteLocalData();
      expect(store.value, original);
    },
  );
  test('budget gate survives a cap with no running tasks', () async {
    await start();
    final p = await project();
    await gateway.close();
    final capped = p.copyWith(
      spent: 1,
      settings: p.settings.copyWith(
        budget: const TeamBudget(chosen: true, total: 1),
      ),
    );
    final w = TeamWorkspace.fromJson(
      Map<String, dynamic>.from(
        (jsonDecode(store.value!) as Map)['workspace'] as Map,
      ),
    );
    store.value = jsonEncode({
      'schemaVersion': 1,
      'workspace': w.copyWith(projects: [capped]).toJson(),
      'requests': {},
    });
    gateway = ProjectFixtureGateway(persistence: store, seedDemo: false);
    await gateway.advance();
    expect((await project()).status, 'paused');
    expect(
      (await project()).requests.any((r) => r.kind == 'budget' && !r.answered),
      isTrue,
    );
  });
  test(
    'replan cannot inject completed runtime state and resume cannot skip a plan',
    () async {
      await create();
      await command(
        TeamProjectAction.answerRequest,
        targetId: 'project-1-question',
        text: 'Ready',
      );
      await command(TeamProjectAction.approveSpec);
      expect(
        (await command(TeamProjectAction.resumeProject)).code,
        'approvePlanFirst',
      );
      final p = await project();
      await gateway.executeProject(
        TeamProjectCommand(
          requestId: 'draft',
          action: TeamProjectAction.saveSpecDraft,
          projectId: p.id,
          expectedRevision: p.revision,
          spec: p.specDraft.copyWith(constraints: 'Changed'),
        ),
      );
      expect(
        (await command(
          TeamProjectAction.replan,
          tasks: [p.tasks.first.copyWith(status: 'merged')],
        )).code,
        'invalidPlan',
      );
    },
  );
  test('quick task honors plan-first and selected role/server', () async {
    final result = await gateway.executeProject(
      const TeamProjectCommand(
        requestId: 'quick',
        action: TeamProjectAction.createQuickTask,
        name: 'One task',
        roleId: 'backend',
        serverId: 'phone',
        spec: TeamSpec(goal: 'Change one thing'),
        repos: [TeamRepo(id: 'app', name: 'App', serverId: 'computer')],
        settings: TeamProjectSettings(
          mode: 'single',
          budget: TeamBudget(chosen: true, unlimited: true),
        ),
      ),
    );
    expect(result.accepted, isTrue);
    final p = await project();
    expect(p.status, 'plan');
    expect(p.tasks, hasLength(1));
    expect(p.tasks.first.roleId, 'backend');
    expect(p.tasks.first.serverId, 'phone');
  });
  test('persisted and published user content is redacted', () async {
    await create();
    await command(
      TeamProjectAction.answerRequest,
      targetId: 'project-1-question',
      text: 'Authorization: Bearer private-provider-value',
    );
    expect(store.value, isNot(contains('private-provider-value')));
    expect(
      jsonEncode((await project()).toJson()),
      isNot(contains('private-provider-value')),
    );
  });
}
