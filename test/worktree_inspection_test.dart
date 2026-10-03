import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/worktree_inspection.dart';

class _Host extends Fake implements HostGateway {
  String? requestedDirectory;
  String? requestedCursor;
  bool? requestedArchived;
  int? requestedLimit;
  Object? failure;
  List<VersionControlFile> files = [];
  ServerPage<GlobalSessionResult> page = const ServerPage(items: []);

  @override
  Future<List<VersionControlFile>> listWorktreeFileStatuses(
    String directory,
  ) async {
    requestedDirectory = directory;
    if (failure != null) {
      throw failure!;
    }
    return files;
  }

  @override
  Future<ServerPage<GlobalSessionResult>> listGlobalSessions({
    String? search,
    bool includeArchived = false,
    String? cursor,
    int limit = 50,
  }) async {
    requestedCursor = cursor;
    requestedArchived = includeArchived;
    requestedLimit = limit;
    if (failure != null) {
      throw failure!;
    }
    return page;
  }
}

GlobalSessionResult _session(
  String id, {
  String? directory = '/copy',
  String projectID = 'project',
  String? workspaceID,
  String? parentID,
}) => GlobalSessionResult(
  session: Session(
    id: id,
    directory: directory,
    projectID: projectID,
    workspaceID: workspaceID,
    parentID: parentID,
  ),
  // The project root is not the session's copy and must never be used instead.
  projectDirectory: '/copy',
);

void main() {
  test(
    'reads exact copy changes; an error remains unknown, not clean',
    () async {
      final host = _Host()
        ..files = [
          const VersionControlFile(
            path: 'lib/app.dart',
            status: 'modified',
            additions: 3,
            deletions: 1,
          ),
        ];
      final inspection = WorktreeInspection(
        gateway: host,
        capabilities: ServerCapabilities.allV1,
      );
      final files = await inspection.loadChanges('/copy');
      expect(host.requestedDirectory, '/copy');
      expect(files.single.path, 'lib/app.dart');
      expect(files.single.additions, 3);
      expect(() => files.clear(), throwsUnsupportedError);
      host.files = [];
      expect(await inspection.loadChanges('/copy'), isEmpty);
      host.failure = StateError('Unavailable');
      await expectLater(inspection.loadChanges('/copy'), throwsStateError);
    },
  );

  test(
    'conversation membership uses exact project, path and workspace',
    () async {
      final host = _Host()
        ..page = ServerPage(
          items: [
            _session('match'),
            _session('nested', directory: '/copy/nested'),
            _session('prefix', directory: '/copy-old'),
            _session('wrong-project', projectID: 'another'),
            _session('remote', workspaceID: 'remote'),
            _session('unknown', directory: null),
            _session('child', parentID: 'match'),
          ],
          nextCursor: 'opaque-next',
        );
      final inspection = WorktreeInspection(
        gateway: host,
        capabilities: ServerCapabilities.allV1,
      );
      final page = await inspection.conversationPage(
        directory: '/copy',
        projectID: 'project',
        cursor: 'opaque-current',
        limit: 7,
      );
      expect(page.items.map((session) => session.id), ['match']);
      expect(page.nextCursor, 'opaque-next');
      expect(host.requestedCursor, 'opaque-current');
      expect(host.requestedLimit, 7);
      expect(host.requestedArchived, isTrue);
      final remote = await inspection.conversationPage(
        directory: '/copy',
        projectID: 'project',
        workspaceID: 'remote',
        includeArchived: false,
      );
      expect(remote.items.single.id, 'remote');
      expect(host.requestedArchived, isFalse);
    },
  );

  test(
    'empty matching page retains continuation and failures propagate',
    () async {
      final host = _Host()
        ..page = ServerPage(
          items: [_session('elsewhere', directory: '/other')],
          nextCursor: 'next',
        );
      final inspection = WorktreeInspection(
        gateway: host,
        capabilities: ServerCapabilities.allV1,
      );
      final page = await inspection.conversationPage(
        directory: '/copy',
        projectID: 'project',
      );
      expect(page.items, isEmpty);
      expect(page.hasMore, isTrue);
      host.failure = StateError('Unavailable');
      await expectLater(
        inspection.conversationPage(directory: '/copy', projectID: 'project'),
        throwsStateError,
      );
    },
  );

  test('unsupported and invalid scopes cannot dispatch requests', () async {
    final host = _Host();
    final disabled = WorktreeInspection(
      gateway: host,
      capabilities: const ServerCapabilities(projectManagement: false),
    );
    expect(disabled.capabilities.worktreeMerge, isFalse);
    expect(disabled.capabilities.worktreeConversations, isFalse);
    await expectLater(disabled.loadChanges('/copy'), throwsUnsupportedError);
    await expectLater(
      disabled.conversationPage(directory: '/copy', projectID: 'project'),
      throwsUnsupportedError,
    );
    expect(host.requestedDirectory, isNull);
    expect(host.requestedLimit, isNull);
    expect(
      const ServerCapabilities(
        globalSessionSearch: false,
      ).worktreeConversations,
      isFalse,
    );
    final enabled = WorktreeInspection(
      gateway: host,
      capabilities: ServerCapabilities.allV1,
    );
    await expectLater(enabled.loadChanges(' '), throwsArgumentError);
    await expectLater(
      enabled.conversationPage(directory: '/copy', projectID: ''),
      throwsArgumentError,
    );
    await expectLater(
      enabled.conversationPage(
        directory: '/copy',
        projectID: 'project',
        limit: 0,
      ),
      throwsArgumentError,
    );
    expect(host.requestedDirectory, isNull);
    expect(host.requestedLimit, isNull);
  });
}
