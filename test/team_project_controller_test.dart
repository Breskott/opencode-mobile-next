import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opencode_mobile/state/team_project_controller.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/project_fixture_gateway.dart';
import 'team_project_fixture_test.dart' show MemoryPersistence;

class ControlledProjectGateway implements OrchestrationProjectGateway {
  final updates = StreamController<TeamWorkspace>.broadcast(sync: true);
  Future<TeamWorkspace> Function() read = () async =>
      const TeamWorkspace(revision: 1);
  TeamCommandResult result = const TeamCommandResult(
    accepted: true,
    projectId: 'created-project',
    revision: 1,
  );
  int commands = 0;
  @override
  Future<TeamWorkspace> teamWorkspace() => read();
  @override
  Stream<TeamWorkspace> watchTeamWorkspace() => updates.stream;
  @override
  Future<TeamCommandResult> executeProject(TeamProjectCommand command) async {
    commands++;
    return result;
  }

  @override
  Future<void> close() => updates.close();
  @override
  Future<void> deleteLocalData() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const create = TeamProjectCommand(
    requestId: 'one-create',
    action: TeamProjectAction.createProject,
  );
  test('accepted command stays accepted when its refresh fails', () async {
    final gateway = ControlledProjectGateway();
    final controller = TeamProjectController(gateway);
    await controller.load();
    gateway.read = () async => throw StateError('read failed');
    final result = await controller.execute(create);
    expect(result.accepted, isTrue);
    expect(result.projectId, 'created-project');
    expect(gateway.commands, 1);
    expect(controller.errorCode, 'unavailable');
    expect(controller.snapshot!.revision, 1);
    expect(controller.busy, isFalse);
    controller.dispose();
  });
  test('refresh failure preserves the command refusal code', () async {
    final gateway = ControlledProjectGateway()
      ..result = const TeamCommandResult(accepted: false, code: 'chooseBudget')
      ..read = () async => throw StateError('read failed');
    final controller = TeamProjectController(gateway);
    final result = await controller.execute(create);
    expect(result.accepted, isFalse);
    expect(result.code, 'chooseBudget');
    expect(controller.errorCode, 'chooseBudget');
    controller.dispose();
  });
  test('late poll cannot replace a newer command refresh', () async {
    final gateway = ControlledProjectGateway();
    final controller = TeamProjectController(gateway);
    await controller.load();
    gateway.read = () async => const TeamWorkspace(revision: 8);
    await controller.execute(create);
    gateway.updates.add(const TeamWorkspace(revision: 3));
    expect(controller.snapshot!.revision, 8);
    gateway.updates.add(const TeamWorkspace(revision: 9));
    expect(controller.snapshot!.revision, 9);
    controller.dispose();
  });
  test('late explicit read cannot replace a newer stream snapshot', () async {
    final gateway = ControlledProjectGateway();
    final read = Completer<TeamWorkspace>();
    gateway.read = () => read.future;
    final controller = TeamProjectController(gateway);
    final load = controller.load();
    gateway.updates.add(const TeamWorkspace(revision: 7));
    read.complete(const TeamWorkspace(revision: 2));
    await load;
    expect(controller.snapshot!.revision, 7);
    controller.dispose();
  });
  test(
    'editor draft JSON stays parseable and secrets never reach disk or restore',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = TeamProjectController(
        ProjectFixtureGateway(
          persistence: MemoryPersistence(),
          seedDemo: false,
        ),
        profileId: 'alice',
        preferences: prefs,
      );
      await controller.saveEditorDraft(
        'spec',
        jsonEncode({
          'goal': 'Keep my work',
          'notes': 'Authorization: Bearer example-secret-value',
        }),
      );
      expect(
        prefs.getString('oc.teamEditorDrafts.alice'),
        isNot(contains('example-secret-value')),
      );
      final restored =
          jsonDecode((await controller.readEditorDraft('spec'))!) as Map;
      expect(restored['goal'], 'Keep my work');
      expect(restored['notes'], isNot(contains('example-secret-value')));
      await controller.clearEditorDraft('spec');
      expect(await controller.readEditorDraft('spec'), isNull);
      controller.dispose();
      await controller.drainEditorDrafts();
    },
  );
  test('dispose cancels queued draft saves before profile deletion', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = TeamProjectController(
      ProjectFixtureGateway(persistence: MemoryPersistence(), seedDemo: false),
      profileId: 'alice',
      preferences: prefs,
    );
    await controller.saveEditorDraft('spec', 'saved');
    final queued = controller.saveEditorDraft('spec', 'queued');
    final denial = expectLater(queued, throwsStateError);
    controller.dispose();
    await controller.drainEditorDrafts();
    await denial;
    await prefs.remove('oc.teamEditorDrafts.alice');
    await expectLater(
      controller.saveEditorDraft('spec', 'resurrection'),
      throwsStateError,
    );
    expect(prefs.containsKey('oc.teamEditorDrafts.alice'), isFalse);
  });
  test('draft targets and profiles are isolated', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = TeamProjectController(
      ProjectFixtureGateway(persistence: MemoryPersistence(), seedDemo: false),
      profileId: 'a',
      preferences: prefs,
    );
    final b = TeamProjectController(
      ProjectFixtureGateway(persistence: MemoryPersistence(), seedDemo: false),
      profileId: 'b',
      preferences: prefs,
    );
    await a.saveEditorDraft('new', 'first');
    await a.saveEditorDraft('spec', 'second');
    await b.saveEditorDraft('new', 'third');
    await a.deleteLocalData();
    expect(prefs.containsKey('oc.teamEditorDrafts.a'), isFalse);
    expect(await b.readEditorDraft('new'), 'third');
    a.dispose();
    b.dispose();
    await a.drainEditorDrafts();
    await b.drainEditorDrafts();
  });
}
