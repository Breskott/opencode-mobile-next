import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/environment_projects.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';

class _ProjectsGateway implements ServerOperationsGateway {
  _ProjectsGateway(this.projects, {this.failure});

  final List<WorkspaceProject> projects;
  final Object? failure;
  int requests = 0;

  @override
  Future<List<WorkspaceProject>> listProjects() async {
    requests++;
    final error = failure;
    if (error != null) throw error;
    return projects;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WorkspaceProject _project(String id, int updatedAt) => WorkspaceProject(
  id: id,
  name: id,
  directory: '/projects/$id',
  worktrees: const [],
  updatedAt: updatedAt,
);

void main() {
  test(
    'orders by update time, keeps ties stable and unknown dates last',
    () async {
      final source = [
        _project('unknown-zero', 0),
        _project('old', 10),
        _project('new-first', 30),
        _project('unknown-negative', -1),
        _project('new-second', 30),
      ];
      final original = List<WorkspaceProject>.of(source);
      final gateway = _ProjectsGateway(source);

      final result = await gateway.loadProjectsByLatestUpdate(
        capabilities: const ServerCapabilities(),
      );

      expect(result.map((project) => project.id), [
        'new-first',
        'new-second',
        'old',
        'unknown-zero',
        'unknown-negative',
      ]);
      expect(source, orderedEquals(original));
      expect(result.first, same(source[2]));
      expect(() => result.clear(), throwsUnsupportedError);
      expect(gateway.requests, 1);
    },
  );

  test('unavailable project ordering does not contact the server', () async {
    final gateway = _ProjectsGateway([]);
    const capabilities = ServerCapabilities(projectManagement: false);

    expect(capabilities.projectsByLatestUpdate, isFalse);
    await expectLater(
      gateway.loadProjectsByLatestUpdate(capabilities: capabilities),
      throwsUnsupportedError,
    );
    expect(gateway.requests, 0);
  });

  test(
    'empty response stays empty and request failures remain failures',
    () async {
      final empty = _ProjectsGateway([]);
      expect(
        await empty.loadProjectsByLatestUpdate(
          capabilities: const ServerCapabilities(),
        ),
        isEmpty,
      );
      final failure = StateError('request failed');
      final failing = _ProjectsGateway([], failure: failure);
      await expectLater(
        failing.loadProjectsByLatestUpdate(
          capabilities: const ServerCapabilities(),
        ),
        throwsA(same(failure)),
      );
    },
  );

  test('missing environment and project operations remain unavailable', () {
    const capabilities = ServerCapabilities();
    expect(capabilities.projectsByLatestUpdate, isTrue);
    expect(capabilities.projectsByRecentUse, isFalse);
    expect(capabilities.environmentErrorReason, isFalse);
    expect(capabilities.environmentStop, isFalse);
    expect(capabilities.repositoryClone, isFalse);
  });
}
