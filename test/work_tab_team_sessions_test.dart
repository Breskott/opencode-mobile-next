import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/widgets/other_projects_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// What the Work tab showed on the Android 15 emulator on 2026-09-24 after the
// in-app AI Team ran one task in the project my-app: the team's agents'
// sessions listed under "In other projects" as if they were the person's.
const _myApp = '/root/projects/my-app';
const _notes = '/root/projects/notes';
const _polecat =
    '/root/aiteam/city/.gc/worktrees/my-app/polecats/gastown.furiosa';
const _refinery = '/root/aiteam/city/.gc/worktrees/my-app/refinery';
const _refineryStartup =
    "I'll run the startup sequence to check for existing work and prime the "
    'merge queue.<tool_call><fu…';
const _refineryStartupShown =
    "I'll run the startup sequence to check for existing work and prime the "
    'merge queue.';
const _patrol = 'Refinery merge queue patrol';
const _polecatStartup = 'Polecat startup: claim work and execute';
const _mine = 'Add a dark mode toggle';

class _Api extends OpenCodeApi {
  _Api(this.statuses) : super(baseUrl: 'http://localhost');
  final Map<String, String> statuses;

  @override
  Future<Map<String, String>> sessionStatuses() async => statuses;
}

/// The server's all-projects list, newest first, in pages of [pageSize].
class _Repository implements ServerOperationsGateway {
  _Repository(this.results, {this.pageSize = 1000});
  final List<GlobalSessionResult> results;
  final int pageSize;
  final cursors = <String?>[];

  @override
  Future<ServerPage<GlobalSessionResult>> listGlobalSessions({
    String? search,
    bool includeArchived = false,
    String? cursor,
    int limit = 50,
  }) async {
    cursors.add(cursor);
    final start = int.tryParse(cursor ?? '') ?? 0;
    final end = (start + pageSize).clamp(0, results.length);
    return ServerPage(
      items: results.sublist(start, end),
      nextCursor: end < results.length ? '$end' : null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GlobalSessionResult _result(
  String id,
  String title,
  String directory, {
  int updated = 0,
  String projectDirectory = _myApp,
}) => GlobalSessionResult(
  session: Session(
    id: id,
    title: title,
    directory: directory,
    time: SessionTime(created: 0, updated: updated),
  ),
  projectName: 'my-app',
  projectDirectory: projectDirectory,
);

/// The real list as the emulator's server returned it: the team's three
/// sessions are newer than the person's own conversation.
List<GlobalSessionResult> _emulatorList() => [
  _result('ses_refinery_startup', _refineryStartup, _refinery, updated: 90),
  _result('ses_refinery_patrol', _patrol, _refinery, updated: 80),
  _result('ses_polecat', _polecatStartup, _polecat, updated: 70),
  _result('ses_mine', _mine, _myApp, updated: 10),
];

class _Controller extends ConnectionController {
  _Controller(super.store);
  List<ProfileLocation> recents = const [];

  @override
  List<ProfileLocation> get recentLocations => recents;
}

Future<_Controller> _controller(
  _Repository repository, {
  Map<String, String> statuses = const {},
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return _Controller(ProfileStore(prefs: prefs))
    ..api = _Api(statuses)
    ..repository = repository
    ..status = StreamStatus.connected
    ..directory = _notes;
}

EventEnvelope _event(String type, String directory, Map<String, dynamic> p) =>
    EventEnvelope(type: type, properties: p, directory: directory);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('In other projects: the team\'s sessions are left out, the person\'s '
      'conversation in the team\'s rig stays', () async {
    final controller = await _controller(
      _Repository(_emulatorList()),
      statuses: {'ses_polecat': 'busy', 'ses_refinery_patrol': 'busy'},
    );
    addTearDown(controller.dispose);

    final found = await controller.conversationsElsewhere();
    expect(found.map((c) => c.session.id), ['ses_mine']);
    expect(found.single.directory, _myApp);
  });

  test('a team busy enough to fill the first pages does not push the '
      'person\'s conversations out', () async {
    final repository = _Repository([
      for (var i = 0; i < 60; i++)
        _result('ses_patrol_$i', _patrol, _refinery, updated: 1000 - i),
      _result('ses_mine', _mine, _myApp, updated: 10),
    ], pageSize: 40);
    final controller = await _controller(repository);
    addTearDown(controller.dispose);

    final found = await controller.conversationsElsewhere();
    expect(found.map((c) => c.session.id), ['ses_mine']);
    expect(repository.cursors, [null, '40']);
  });

  test('the team\'s runs and requests are not counted as the person\'s other '
      'projects or the Inbox badge', () async {
    final controller = await _controller(_Repository(const []));
    addTearDown(controller.dispose);
    final attention = controller.elsewhereAttention;
    attention.handle(
      _event('session.status', _polecat, {
        'sessionID': 'ses_polecat',
        'status': {'type': 'busy'},
      }),
    );
    attention.handle(
      _event('permission.v2.asked', _refinery, {
        'id': 'per_1',
        'sessionID': 'ses_refinery_patrol',
      }),
    );
    attention.handle(
      _event('question.asked', _myApp, {
        'id': 'que_1',
        'sessionID': 'ses_mine',
      }),
    );
    expect(attention.activity(except: _notes).map((p) => p.directory), [
      _myApp,
    ]);
    expect(controller.waitingElsewhereCount, 1);
  });

  test('a team folder is never the project opened for the person', () {
    final picked = ConnectionController.newestProject(const [
      WorkspaceProject(
        id: 'team',
        name: 'refinery',
        directory: _refinery,
        worktrees: [],
        updatedAt: 99,
      ),
      WorkspaceProject(
        id: 'mine',
        name: 'my-app',
        directory: _myApp,
        worktrees: [_polecat],
        updatedAt: 1,
      ),
    ]);
    expect(picked?.id, 'mine');
  });

  testWidgets('the Work tab panel shows the person\'s conversation and '
      'project, and none of the team\'s', (tester) async {
    final controller = await _controller(
      _Repository(_emulatorList()),
      statuses: {'ses_polecat': 'busy'},
    );
    addTearDown(controller.dispose);
    controller.recents = const [
      ProfileLocation(directory: _notes),
      ProfileLocation(directory: _myApp),
      // Opened once from the old list; still not the person's project.
      ProfileLocation(directory: _polecat),
    ];
    controller.elsewhereAttention.handle(
      _event('session.status', _refinery, {
        'sessionID': 'ses_refinery_patrol',
        'status': {'type': 'busy'},
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: OtherProjectsPanel(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('In other projects'), findsOneWidget);
    expect(find.text(_mine), findsOneWidget);
    expect(find.byKey(const ValueKey('elsewhere-ses_mine')), findsOneWidget);
    for (final title in [
      _refineryStartup,
      _refineryStartupShown,
      _patrol,
      _polecatStartup,
    ]) {
      expect(find.text(title), findsNothing, reason: title);
    }
    expect(find.textContaining('<tool_call>'), findsNothing);

    expect(
      find.byKey(const ValueKey('recent-project-$_myApp')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('recent-project-$_polecat')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('recent-project-$_refinery')),
      findsNothing,
    );
    expect(find.text('gastown.furiosa'), findsNothing);
    expect(find.text('refinery'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a leaked tool call never reaches the Work tab list', (
    tester,
  ) async {
    // The same title on a conversation of the person's own: the markup is
    // cut for display only.
    final session = _result('ses_own', _refineryStartup, _myApp, updated: 5);
    final controller = await _controller(_Repository([session]));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: OtherProjectsPanel(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(_refineryStartupShown), findsOneWidget);
    expect(find.textContaining('<tool_call>'), findsNothing);
    expect(session.session.title, _refineryStartup);

    await tester.pumpWidget(const SizedBox());
  });
}
