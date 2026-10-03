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

    void expectBlocked(String reason) {
      final primary = tester.widget<KitSheet>(find.byType(KitSheet)).primary!;
      expect(primary.onPressed, isNull);
      expect(primary.disabledReason, reason);
      expect(find.text(reason), findsOneWidget);
      expect(gateway.commands, isEmpty);
    }

    expectBlocked('Choose Single lane or Parallel agents.');
    await _tap(tester, 'Single lane');
    expectBlocked('Set a budget or choose No limit.');
    await _tap(tester, 'No limit');
    expectBlocked('Add a goal and at least one repo.');
    for (final entry in {
      'name': 'Reader',
      'goal': 'Read saved articles offline',
      'repoName': 'App',
      'repoPath': '/projects/reader',
    }.entries) {
      final field = find.descendant(
        of: find.byKey(ValueKey(entry.key)),
        matching: find.byType(EditableText),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
    }
    await _tap(tester, 'Home PC');
    await _tap(tester, 'Add repo');
    expect(
      tester.widget<KitSheet>(find.byType(KitSheet)).primary!.onPressed,
      isNotNull,
    );
    await _tap(tester, 'Start planning');
    expect(gateway.commands, hasLength(1));
    expect(gateway.commands.single.spec!.goal, 'Read saved articles offline');
    expect(gateway.commands.single.settings!.mode, 'single');
    expect(gateway.commands.single.settings!.budget.unlimited, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('plan approval sends edited criteria and risky phase choice', (
    tester,
  ) async {
    final gateway = _Gateway(
      const TeamWorkspace(
        servers: [
          TeamServer(id: 'pc', name: 'Home PC'),
          TeamServer(id: 'remote', name: 'Build server'),
        ],
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
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await _tap(tester, 'Review gate · risky');
    await _tap(tester, 'Build server');
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
    expect(command.tasks!.single.serverId, 'remote');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('dismissed form restores its redacted controller draft', (
    tester,
  ) async {
    final gateway = _Gateway(const TeamWorkspace());
    final controller = TeamProjectController(gateway);
    await controller.load();
    addTearDown(controller.dispose);
    KitRedact.registerKnownSecret('test-only-draft-secret');
    addTearDown(KitRedact.clearKnownSecrets);
    final context = await pumpKitHost(
      tester,
      effects: const KitEffects(motion: KitMotionLevel.off),
    );
    unawaited(openTeamNewProject(context, controller));
    await tester.pumpAndSettle();
    Finder goal() => find.descendant(
      of: find.byKey(const ValueKey('goal')),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(goal());
    await tester.enterText(goal(), 'Build a reader test-only-draft-secret');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    unawaited(openTeamNewProject(context, controller));
    await tester.pumpAndSettle();
    final restored = tester.widget<EditableText>(goal()).controller.text;
    expect(restored, contains('Build a reader'));
    expect(restored, isNot(contains('test-only-draft-secret')));
    expect(gateway.commands, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'checker model and fallback remain editable without write access',
    (tester) async {
      final gateway = _Gateway(
        const TeamWorkspace(
          roles: [
            TeamProjectRole(id: 'checker', name: 'Checker', readOnly: true),
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
      unawaited(openTeamRoles(context, controller));
      await tester.pumpAndSettle();
      await _tap(tester, 'Checker');
      for (final entry in {
        'roleModel': 'vendor/checker',
        'roleFallback': 'vendor/backup',
      }.entries) {
        final field = find.descendant(
          of: find.byKey(ValueKey(entry.key)),
          matching: find.byType(EditableText),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
      }
      await _tap(tester, 'Save changes');
      expect(gateway.commands.single.role!.model, 'vendor/checker');
      expect(gateway.commands.single.role!.fallbackModel, 'vendor/backup');
      expect(gateway.commands.single.role!.readOnly, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  for (final recovery in {
    'Use as one task': TeamProjectAction.usePlanAsTask,
    'Ask again': TeamProjectAction.retryPlan,
  }.entries) {
    testWidgets('malformed plan offers ${recovery.key} without starting work', (
      tester,
    ) async {
      final gateway = _Gateway(
        const TeamWorkspace(
          projects: [
            TeamProject(
              id: 'project',
              name: 'Reader',
              status: 'planFailed',
              revision: 7,
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
      expect(find.text('Approve and start'), findsNothing);
      await _tap(tester, recovery.key);
      expect(gateway.commands.single.action, recovery.value);
      expect(gateway.commands.single.expectedRevision, 7);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
