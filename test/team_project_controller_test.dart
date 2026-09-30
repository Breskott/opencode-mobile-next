import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opencode_mobile/state/team_project_controller.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/project_fixture_gateway.dart';
import 'team_project_fixture_test.dart' show MemoryPersistence;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
