import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/team_project_controller.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_project_editors.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_refusal.dart';
import 'package:opencode_mobile/ui/screens/team/team_model_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit/kit_harness.dart';

const _roles = [
  TeamProjectRole(
    id: 'planner',
    name: 'Planner',
    instructions: 'Plan only.',
    fallbackModel: 'x/fallback',
    readOnly: true,
  ),
  TeamProjectRole(id: 'worker', name: 'Worker', instructions: 'Build.'),
  TeamProjectRole(
    id: 'checker',
    name: 'Checker',
    instructions: 'Check only.',
    readOnly: true,
  ),
];

class _Gateway implements OrchestrationProjectGateway {
  _Gateway(this.workspace);
  TeamWorkspace workspace;
  final commands = <TeamProjectCommand>[];

  /// Results handed out in order; accepted once the list runs out.
  final results = <TeamCommandResult>[];
  Completer<void>? hold;
  @override
  Future<TeamWorkspace> teamWorkspace() async => workspace;
  @override
  Stream<TeamWorkspace> watchTeamWorkspace() => const Stream.empty();
  @override
  Future<TeamCommandResult> executeProject(TeamProjectCommand command) async {
    commands.add(command);
    await hold?.future;
    if (results.isNotEmpty) return results.removeAt(0);
    if (command.action == TeamProjectAction.saveRole) {
      workspace = TeamWorkspace(
        servers: workspace.servers,
        projects: workspace.projects,
        roles: [
          for (final r in workspace.roles)
            r.id == command.role!.id ? command.role! : r,
        ],
      );
    }
    return const TeamCommandResult(accepted: true, revision: 9);
  }

  @override
  Future<void> close() async {}
  @override
  Future<void> deleteLocalData() async {}
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

const _failedPlan = TeamProject(
  id: 'p1',
  name: 'Readme',
  status: 'planFailed',
  revision: 4,
);

Future<(_Gateway, TeamProjectController, BuildContext)> _boot(
  WidgetTester tester,
  TeamWorkspace workspace,
) async {
  SharedPreferences.setMockInitialValues({});
  final gateway = _Gateway(workspace);
  final controller = TeamProjectController(gateway);
  await controller.load();
  addTearDown(controller.dispose);
  final context = await pumpKitHost(
    tester,
    effects: const KitEffects(motion: KitMotionLevel.off),
  );
  return (gateway, controller, context);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('team settings pick each role model and save the whole role', (
    tester,
  ) async {
    final (gateway, controller, context) = await _boot(
      tester,
      const TeamWorkspace(roles: _roles),
    );
    final asked = <String?>[];
    unawaited(
      openTeamDefaults(
        context,
        controller,
        modelPicker: (context, {required current, required fallback}) async {
          asked.add(current);
          return const TeamModelChoice('zai-coding-plan/glm-5.3-flash');
        },
      ),
    );
    await tester.pumpAndSettle();
    // Empty reads as the server's default, never as the chat's model.
    expect(find.text('Server default'), findsNWidgets(3));
    await tester.ensureVisible(
      find.byKey(const ValueKey('team-model-role-planner')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-model-role-planner')));
    await tester.pumpAndSettle();
    final command = gateway.commands.single;
    expect(command.action, TeamProjectAction.saveRole);
    expect(command.role!.id, 'planner');
    expect(command.role!.model, 'zai-coding-plan/glm-5.3-flash');
    expect(command.role!.name, 'Planner');
    expect(command.role!.instructions, 'Plan only.');
    expect(command.role!.fallbackModel, 'x/fallback');
    expect(command.role!.readOnly, isTrue);
    expect(asked, [null]);
    expect(find.text('Server default'), findsNWidgets(2));
    await _close(tester);
  });

  testWidgets('a failed plan opens the planner choice, then offers Ask again', (
    tester,
  ) async {
    final (gateway, controller, context) = await _boot(
      tester,
      const TeamWorkspace(roles: _roles, projects: [_failedPlan]),
    );
    unawaited(
      openTeamDefaults(
        context,
        controller,
        focusPlannerModel: true,
        retryProjectId: 'p1',
        modelPicker: (context, {required current, required fallback}) async =>
            const TeamModelChoice('zai/glm'),
      ),
    );
    await tester.pumpAndSettle();
    // The planner choice opened by itself and was saved; nothing resent.
    expect(gateway.commands.single.action, TeamProjectAction.saveRole);
    expect(
      find.text('Planner model saved. Ask again to plan with it.'),
      findsOneWidget,
    );
    await _tap(tester, 'Ask again');
    expect(gateway.commands.last.action, TeamProjectAction.retryPlan);
    expect(gateway.commands.last.projectId, 'p1');
    expect(gateway.commands.last.expectedRevision, 4);
    await _close(tester);
  });

  testWidgets('the repo folder is chosen, with typing a path second', (
    tester,
  ) async {
    final (gateway, controller, context) = await _boot(
      tester,
      const TeamWorkspace(
        roles: _roles,
        servers: [TeamServer(id: 'phone', name: 'This phone', phone: true)],
      ),
    );
    teamFolderPickerOverride = (_) async => '/root/projects/my-app';
    addTearDown(() => teamFolderPickerOverride = null);
    unawaited(openTeamNewProject(context, controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-repo-folder')), findsOneWidget);
    expect(find.byKey(const ValueKey('repoPath')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('team-repo-folder')));
    await tester.tap(find.byKey(const ValueKey('team-repo-folder')));
    await tester.pumpAndSettle();
    expect(find.text('/root/projects/my-app'), findsOneWidget);
    await _tap(tester, 'Single lane');
    await _tap(tester, 'No limit');
    await _type(tester, 'goal', 'Add a README');
    await _tap(tester, 'Start planning');
    final repo = gateway.commands.single.repos.single;
    expect(repo.path, '/root/projects/my-app');
    expect(repo.name, 'my-app');
    expect(repo.serverId, 'phone');
    await _close(tester);
  });

  testWidgets('Type a path is still there when the person wants it', (
    tester,
  ) async {
    final (_, controller, context) = await _boot(
      tester,
      const TeamWorkspace(
        servers: [TeamServer(id: 'phone', name: 'This phone', phone: true)],
      ),
    );
    teamFolderPickerOverride = (_) async => null;
    addTearDown(() => teamFolderPickerOverride = null);
    unawaited(openTeamNewProject(context, controller));
    await tester.pumpAndSettle();
    await _tap(tester, 'Type a path');
    expect(find.byKey(const ValueKey('repoPath')), findsOneWidget);
    await _close(tester);
  });

  testWidgets('an empty repository can be given its first commit here', (
    tester,
  ) async {
    final (gateway, controller, context) = await _boot(
      tester,
      const TeamWorkspace(
        servers: [TeamServer(id: 'phone', name: 'This phone', phone: true)],
      ),
    );
    final committed = <String>[];
    teamFolderPickerOverride = (_) async => '/root/projects/my-app';
    teamFirstCommitOverride = (path) async => committed.add(path);
    addTearDown(() {
      teamFolderPickerOverride = null;
      teamFirstCommitOverride = null;
    });
    gateway.results.add(
      const TeamCommandResult(accepted: false, code: 'repository_empty'),
    );
    unawaited(openTeamNewProject(context, controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-repo-folder')));
    await tester.pumpAndSettle();
    await _tap(tester, 'Single lane');
    await _tap(tester, 'No limit');
    await _type(tester, 'goal', 'Add a README');
    await _tap(tester, 'Start planning');
    expect(find.text('This repository has no commits yet.'), findsOneWidget);
    await _tap(tester, 'Make the first commit for me');
    expect(committed, ['/root/projects/my-app']);
    // Then the same request goes through again.
    expect(gateway.commands, hasLength(2));
    await _close(tester);
  });

  testWidgets('progress shows at once after Start planning', (tester) async {
    final (gateway, controller, context) = await _boot(
      tester,
      const TeamWorkspace(
        servers: [TeamServer(id: 'phone', name: 'This phone', phone: true)],
      ),
    );
    teamFolderPickerOverride = (_) async => '/root/projects/my-app';
    addTearDown(() => teamFolderPickerOverride = null);
    gateway.hold = Completer<void>();
    unawaited(openTeamNewProject(context, controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('team-repo-folder')));
    await tester.pumpAndSettle();
    await _tap(tester, 'Single lane');
    await _tap(tester, 'No limit');
    await _type(tester, 'goal', 'Add a README');
    final start = find.text('Start planning').last;
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('team-starting')), findsOneWidget);
    gateway.hold!.complete();
    await tester.pumpAndSettle();
    await _close(tester);
  });

  testWidgets('a saved draft is said, and Start fresh empties the form', (
    tester,
  ) async {
    final (_, controller, context) = await _boot(tester, const TeamWorkspace());
    unawaited(openTeamNewProject(context, controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-draft-restored')), findsNothing);
    await _type(tester, 'goal', 'Old goal');
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    unawaited(openTeamNewProject(context, controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-draft-restored')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('team-draft-start-fresh')));
    await tester.pumpAndSettle();
    final goal = find.descendant(
      of: find.byKey(const ValueKey('goal')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(goal).controller.text, isEmpty);
    expect(find.byKey(const ValueKey('team-draft-restored')), findsNothing);
    await _close(tester);
  });

  testWidgets('the first spec starts with a milestone drafted from the task', (
    tester,
  ) async {
    final (gateway, controller, context) = await _boot(
      tester,
      const TeamWorkspace(
        projects: [
          TeamProject(
            id: 'p1',
            name: 'Readme',
            revision: 2,
            specDraft: TeamSpec(goal: 'Add a README.md saying hello'),
          ),
        ],
      ),
    );
    unawaited(openTeamSpecEditor(context, controller, 'p1'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('team-starter-milestone')),
      findsOneWidget,
    );
    await _tap(tester, 'Approve spec');
    final saved = gateway.commands.first;
    expect(saved.action, TeamProjectAction.saveSpecDraft);
    expect(saved.spec!.milestones.single.title, 'Add a README.md saying hello');
    expect(saved.spec!.milestones.single.criteria, [
      'Add a README.md saying hello',
    ]);
    await _close(tester);
  });

  test('a wrong folder and a rejected sign-in read in plain words', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final path = teamReasonFor(l, 'repoPathInvalid')!;
    expect(path.message, "The team can't find that folder on this phone.");
    expect(path.next, contains('Choose the folder'));
    final model = teamReasonFor(l, 'modelNotConfigured')!;
    expect(model.next, contains('Planner model choice'));
    expect(model.message, isNot(contains('modelNotConfigured')));
  });
}
