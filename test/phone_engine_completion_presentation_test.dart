import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/team_project_gateway.dart';

import 'phone_project_engine_gateway_test.dart' as engine;

void main() {
  const repo = TeamRepo(
    id: 'repo-one',
    devCommit: 'current-main',
    mainCommit: 'current-main',
  );
  const task = TeamTask(id: 'task-one', repoId: 'repo-one', status: 'merged');
  const merge = TeamMergeItem(
    id: 'merge-one',
    taskId: 'task-one',
    repoId: 'repo-one',
    status: 'merged',
    checksPassed: true,
  );
  const receipt = TeamProjectReceipt(
    id: 'confirmed-promotion',
    kind: 'promote',
    repoId: 'repo-one',
    before: 'previous-main',
    after: 'current-main',
    actor: 'engine',
  );
  const promoted = TeamProject(
    id: 'project-one',
    status: 'running',
    revision: 18,
    planApproved: true,
    repos: [repo],
    tasks: [task],
    mergeQueue: [merge],
    receipts: [receipt],
  );

  Future<TeamProject> read(TeamProject project) async {
    final wire = engine.workspace(29)..['projects'] = [project.toJson()];
    final adapter = engine.FakeEngineAdapter(
      (request) async => engine.jsonBody(
        request.path == '/v1/health'
            ? engine.health('p1', execution: true)
            : wire,
      ),
    );
    final gateway = engine.gateway(adapter);
    try {
      final workspace = await gateway.teamWorkspace();
      expect(workspace.revision, 29);
      expect(
        adapter.requests.every((request) => request.method == 'GET'),
        isTrue,
      );
      return workspace.projects.single;
    } finally {
      await gateway.close();
    }
  }

  test(
    'fully checked and receipted promotion presents done while preserving native evidence',
    () async {
      final project = await read(promoted);
      expect(project.status, 'done');
      expect(project.revision, 18);
      expect(project.planApproved, isTrue);
      expect(project.tasks.single.toJson(), task.toJson());
      expect(project.repos.single.toJson(), repo.toJson());
      expect(project.mergeQueue.single.toJson(), merge.toJson());
      expect(project.receipts.single.toJson(), receipt.toJson());
      expect(promoted.status, 'running');
    },
  );

  test(
    'unknown unapproved or unfinished task evidence never presents done',
    () async {
      final cases = <String, TeamProject>{
        'unapproved': promoted.copyWith(planApproved: false),
        'no tasks': promoted.copyWith(tasks: []),
        'active task': promoted.copyWith(
          tasks: [task.copyWith(status: 'running')],
        ),
        'unknown task ID': promoted.copyWith(tasks: [task.copyWith(id: '')]),
        'duplicate task ID': promoted.copyWith(tasks: [task, task]),
        'open finding': promoted.copyWith(
          tasks: [
            task.copyWith(findings: [const TeamFinding(id: 'still-open')]),
          ],
        ),
        'missing repository': promoted.copyWith(repos: []),
        'unknown task repository': promoted.copyWith(
          tasks: [task.copyWith(repoId: '')],
        ),
      };
      for (final entry in cases.entries) {
        expect((await read(entry.value)).status, 'running', reason: entry.key);
      }
    },
  );

  test(
    'merge queue must cover every task with passed checks and matching repository',
    () async {
      final cases = <String, TeamProject>{
        'no queue': promoted.copyWith(mergeQueue: []),
        'unpassed checks': promoted.copyWith(
          mergeQueue: [merge.copyWith(checksPassed: false)],
        ),
        'not merged': promoted.copyWith(
          mergeQueue: [merge.copyWith(status: 'queued')],
        ),
        'missing merge ID': promoted.copyWith(
          mergeQueue: [merge.copyWith(id: '')],
        ),
        'foreign task': promoted.copyWith(
          mergeQueue: [merge.copyWith(taskId: 'other-task')],
        ),
        'foreign repository': promoted.copyWith(
          mergeQueue: [merge.copyWith(repoId: 'other-repo')],
        ),
        'uncovered task': promoted.copyWith(
          tasks: [
            task,
            task.copyWith(id: 'task-two'),
          ],
        ),
      };
      for (final entry in cases.entries) {
        expect((await read(entry.value)).status, 'running', reason: entry.key);
      }
    },
  );

  test(
    'current equal refs require a matching authoritative real promotion receipt',
    () async {
      final cases = <String, TeamProject>{
        'different refs': promoted.copyWith(
          repos: [repo.copyWith(devCommit: 'next-dev')],
        ),
        'unknown refs': promoted.copyWith(
          repos: [repo.copyWith(devCommit: '', mainCommit: '')],
        ),
        'no receipt': promoted.copyWith(receipts: []),
        'old receipt': promoted.copyWith(
          receipts: [receipt.copyWith(after: 'old-main')],
        ),
        'wrong repo receipt': promoted.copyWith(
          receipts: [receipt.copyWith(repoId: 'other-repo')],
        ),
        'merge only receipt': promoted.copyWith(
          receipts: [receipt.copyWith(kind: 'merge')],
        ),
        'unowned receipt': promoted.copyWith(
          receipts: [receipt.copyWith(actor: 'person')],
        ),
        'unknown receipt ID': promoted.copyWith(
          receipts: [receipt.copyWith(id: '')],
        ),
        'unknown previous ref': promoted.copyWith(
          receipts: [receipt.copyWith(before: '')],
        ),
        'no-op receipt': promoted.copyWith(
          receipts: [receipt.copyWith(before: 'current-main')],
        ),
      };
      for (final entry in cases.entries) {
        expect((await read(entry.value)).status, 'running', reason: entry.key);
      }
    },
  );

  test('each task repository needs its own current promotion proof', () async {
    const second = TeamRepo(
      id: 'repo-two',
      devCommit: 'main-two',
      mainCommit: 'main-two',
    );
    const secondTask = TeamTask(
      id: 'task-two',
      repoId: 'repo-two',
      status: 'merged',
    );
    const secondMerge = TeamMergeItem(
      id: 'merge-two',
      taskId: 'task-two',
      repoId: 'repo-two',
      status: 'merged',
      checksPassed: true,
    );
    const secondReceipt = TeamProjectReceipt(
      id: 'promotion-two',
      kind: 'promote',
      repoId: 'repo-two',
      before: 'old-two',
      after: 'main-two',
      actor: 'engine',
    );
    final project = promoted.copyWith(
      repos: [repo, second],
      tasks: [task, secondTask],
      mergeQueue: [merge, secondMerge],
    );
    expect((await read(project)).status, 'running');
    expect(
      (await read(project.copyWith(receipts: [receipt, secondReceipt]))).status,
      'done',
    );
  });

  test(
    'explicit pause stop or failure survives complete promotion evidence',
    () async {
      for (final status in ['paused', 'stopped', 'failed']) {
        expect((await read(promoted.copyWith(status: status))).status, status);
      }
    },
  );
}
