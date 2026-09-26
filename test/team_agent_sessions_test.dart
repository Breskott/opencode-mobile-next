import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/team_agent_sessions.dart';

const polecat =
    '/root/aiteam/city/.gc/worktrees/my-app/polecats/gastown.furiosa';
const refinery = '/root/aiteam/city/.gc/worktrees/my-app/refinery';

final started = DateTime.utc(2026, 9, 25, 19, 51, 5);
int ms(DateTime at) => at.millisecondsSinceEpoch;

GlobalSessionResult result(
  String id,
  String? directory, {
  DateTime? created,
  DateTime? updated,
  String? parentID,
  String? projectDirectory,
}) => GlobalSessionResult(
  session: Session(
    id: id,
    directory: directory,
    parentID: parentID,
    time: SessionTime(
      created: created == null ? null : ms(created),
      updated: updated == null ? null : ms(updated),
    ),
  ),
  projectDirectory: projectDirectory,
);

class _FakeOps implements ServerOperationsGateway {
  _FakeOps(this.pages, {this.fail = false});

  final List<ServerPage<GlobalSessionResult>> pages;
  final bool fail;
  final cursors = <String?>[];

  @override
  Future<ServerPage<GlobalSessionResult>> listGlobalSessions({
    String? search,
    bool includeArchived = false,
    String? cursor,
    int limit = 50,
  }) async {
    cursors.add(cursor);
    if (fail) throw StateError('server went away');
    final index = cursor == null ? 0 : int.parse(cursor);
    return pages[index];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final later = started.add(const Duration(minutes: 4));

  group('pickTeamAgentSession', () {
    test('matches the session in the agent work folder', () {
      expect(
        pickTeamAgentSession(
          workDir: polecat,
          startedAt: started,
          sessions: [
            result('ses_person', '/root/projects/my-app', updated: later),
            result('ses_furiosa', polecat, created: started, updated: later),
            result('ses_refinery', refinery, updated: later),
          ],
        ),
        'ses_furiosa',
      );
    });

    test('matches a session in a folder inside the work folder', () {
      expect(
        pickTeamAgentSession(
          workDir: polecat,
          sessions: [result('ses_repo', '$polecat/repo', updated: later)],
        ),
        'ses_repo',
      );
    });

    test('trailing slash, dot and dot-dot forms are the same folder', () {
      expect(
        pickTeamAgentSession(
          workDir: '$polecat/',
          sessions: [
            result(
              'ses_a',
              '/root/aiteam/city/.gc/worktrees/my-app/./polecats/x/../gastown.furiosa',
              updated: later,
            ),
          ],
        ),
        'ses_a',
      );
      expect(
        pickTeamAgentSession(
          workDir: r'\root\aiteam\city\.gc\worktrees\my-app\refinery',
          sessions: [result('ses_r', '$refinery/', updated: later)],
        ),
        'ses_r',
      );
    });

    test('the project folder the team works on is not the agent folder', () {
      expect(
        pickTeamAgentSession(
          workDir: polecat,
          sessions: [
            result('ses_person', '/root/projects/my-app', updated: later),
            result('ses_sibling', '${polecat}2', updated: later),
          ],
        ),
        isNull,
      );
    });

    test('falls back to the project folder when the session names none', () {
      expect(
        pickTeamAgentSession(
          workDir: refinery,
          sessions: [
            result('ses_r', null, updated: later, projectDirectory: refinery),
          ],
        ),
        'ses_r',
      );
    });

    test('child sessions (sub-agents) are ignored', () {
      expect(
        pickTeamAgentSession(
          workDir: polecat,
          sessions: [
            result('ses_root', polecat, updated: started),
            result('ses_child', polecat, updated: later, parentID: 'ses_root'),
          ],
        ),
        'ses_root',
      );
    });

    test('the newest wins; ties by creation then id', () {
      expect(
        pickTeamAgentSession(
          workDir: polecat,
          sessions: [
            result('ses_old', polecat, updated: started),
            result('ses_new', polecat, updated: later),
          ],
        ),
        'ses_new',
      );
      expect(
        pickTeamAgentSession(
          workDir: polecat,
          sessions: [
            result('ses_b', polecat, created: started, updated: later),
            result(
              'ses_a',
              polecat,
              created: started.add(const Duration(seconds: 1)),
              updated: later,
            ),
          ],
        ),
        'ses_a',
      );
      expect(
        pickTeamAgentSession(
          workDir: polecat,
          sessions: [
            result('ses_a', polecat, updated: later),
            result('ses_b', polecat, updated: later),
          ],
        ),
        'ses_b',
      );
    });

    test('a session older than the Gas City session is a previous task', () {
      final yesterday = started.subtract(const Duration(days: 1));
      expect(
        pickTeamAgentSession(
          workDir: polecat,
          startedAt: started,
          sessions: [result('ses_previous', polecat, updated: yesterday)],
        ),
        isNull,
      );
      // Within the two-minute slack it still counts.
      expect(
        pickTeamAgentSession(
          workDir: polecat,
          startedAt: started,
          sessions: [
            result(
              'ses_now',
              polecat,
              created: started.subtract(const Duration(seconds: 30)),
            ),
          ],
        ),
        'ses_now',
      );
    });

    test('no work folder or no match is null', () {
      final sessions = [result('ses_a', polecat, updated: later)];
      expect(pickTeamAgentSession(workDir: null, sessions: sessions), isNull);
      expect(pickTeamAgentSession(workDir: '  ', sessions: sessions), isNull);
      expect(
        pickTeamAgentSession(workDir: refinery, sessions: sessions),
        isNull,
      );
      expect(pickTeamAgentSession(workDir: polecat, sessions: []), isNull);
    });
  });

  group('findTeamAgentSession', () {
    test('pages until the agent session is found', () async {
      final repository = _FakeOps([
        ServerPage(
          items: [
            for (var i = 0; i < 3; i++)
              result('ses_person$i', '/root/projects/my-app', updated: later),
          ],
          nextCursor: '1',
        ),
        ServerPage(
          items: [result('ses_furiosa', polecat, updated: later)],
          nextCursor: '2',
        ),
        ServerPage(items: [result('ses_x', '/tmp', updated: started)]),
      ]);
      expect(
        await findTeamAgentSession(
          repository,
          workDir: polecat,
          startedAt: started,
          pageSize: 3,
        ),
        'ses_furiosa',
      );
      expect(repository.cursors, [null, '1', '2']);
    });

    test('stops once a page reaches back before the session start', () async {
      final repository = _FakeOps([
        ServerPage(
          items: [
            result('ses_furiosa', polecat, updated: later),
            result(
              'ses_old',
              '/root/projects/my-app',
              updated: started.subtract(const Duration(hours: 1)),
            ),
          ],
          nextCursor: '1',
        ),
        ServerPage(items: const []),
      ]);
      expect(
        await findTeamAgentSession(
          repository,
          workDir: polecat,
          startedAt: started,
        ),
        'ses_furiosa',
      );
      expect(repository.cursors, [null]);
    });

    test('at most the given number of pages', () async {
      final repository = _FakeOps([
        for (var i = 0; i < 5; i++)
          ServerPage(
            items: [result('ses_p$i', '/root/projects/my-app', updated: later)],
            nextCursor: '${i + 1}',
          ),
      ]);
      expect(
        await findTeamAgentSession(repository, workDir: polecat, pages: 2),
        isNull,
      );
      expect(repository.cursors, [null, '1']);
    });

    test('a server that fails is null, not an error', () async {
      final repository = _FakeOps(const [], fail: true);
      expect(await findTeamAgentSession(repository, workDir: polecat), isNull);
    });

    test('no work folder asks nothing', () async {
      final repository = _FakeOps(const []);
      expect(await findTeamAgentSession(repository, workDir: null), isNull);
      expect(repository.cursors, isEmpty);
    });
  });
}
