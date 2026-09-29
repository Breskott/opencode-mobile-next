import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/team_project_controller.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_project_editors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit/kit_harness.dart';

class _Gateway implements OrchestrationProjectGateway {
  _Gateway(this.workspace);
  TeamWorkspace workspace;
  final commands = <TeamProjectCommand>[];
  @override
  Future<TeamWorkspace> teamWorkspace() async => workspace;
  @override
  Stream<TeamWorkspace> watchTeamWorkspace() => const Stream.empty();
  @override
  Future<TeamCommandResult> executeProject(TeamProjectCommand command) async {
    commands.add(command);
    return const TeamCommandResult(accepted: true, revision: 8);
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('project creation requires an explicit mode and budget', (
    tester,
  ) async {
    final gateway = _Gateway(
      const TeamWorkspace(
        servers: [TeamServer(id: 'pc', name: 'Home PC')],
      ),
    );
    final controller = TeamProjectController(gateway);
    await controller.load();
    addTearDown(controller.dispose);
    final context = await pumpKitHost(
      tester,
      effects: const KitEffects(motion: KitMotionLevel.off),
    );
    unawaited(openTeamNewProject(context, controller));
    await tester.pumpAndSettle();

    await _tap(tester, 'Start planning');
    expect(find.text('Choose Single lane or Parallel agents.'), findsOneWidget);
    expect(gateway.commands, isEmpty);

    await _tap(tester, 'Single lane');
    await _tap(tester, 'Start planning');
    expect(find.text('Set a budget or choose No limit.'), findsOneWidget);
    expect(gateway.commands, isEmpty);

    await _tap(tester, 'No limit');
    await _tap(tester, 'Start planning');
    expect(
      find.text('Add a project name, goal and at least one repo.'),
      findsOneWidget,
    );
    expect(gateway.commands, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('plan approval sends edited criteria and risky phase choice', (
    tester,
  ) async {
    final gateway = _Gateway(
      const TeamWorkspace(
        servers: [TeamServer(id: 'pc', name: 'Home PC')],
        roles: [TeamProjectRole(id: 'builder', name: 'Builder')],
        projects: [
          TeamProject(
            id: 'project',
            name: 'Reader',
            status: 'plan',
            revision: 7,
            repos: [TeamRepo(id: 'repo', name: 'App', serverId: 'pc')],
            phases: [TeamPhase(id: 'phase', title: 'Reader screen')],
            tasks: [
              TeamTask(
                id: 'task',
                title: 'Show saved articles',
                phaseId: 'phase',
                roleId: 'builder',
                repoId: 'repo',
                serverId: 'pc',
                criteria: ['Articles are visible'],
              ),
            ],
          ),
        ],
      ),
    );
    final controller = TeamProjectController(gateway);
    await controller.load();
    addTearDown(controller.dispose);
    final context = await pumpKitHost(
      tester,
      effects: const KitEffects(motion: KitMotionLevel.off),
    );
    unawaited(openTeamPlanEditor(context, controller, 'project'));
    await tester.pumpAndSettle();

    final field = find.descendant(
      of: find.byKey(const ValueKey('criteria-task')),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(field);
    await tester.enterText(
      field,
      'Articles survive restart\nAn empty library explains how to add one',
    );
    await tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await _tap(tester, 'Pause for review after this phase');
    await _tap(tester, 'Approve and start');

    expect(gateway.commands, hasLength(1));
    final command = gateway.commands.single;
    expect(command.action, TeamProjectAction.approvePlan);
    expect(command.expectedRevision, 7);
    expect(command.tasks!.single.criteria, [
      'Articles survive restart',
      'An empty library explains how to add one',
    ]);
    expect(command.phases!.single.risky, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
