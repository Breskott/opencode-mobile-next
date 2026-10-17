// Setup polish from emulator run 4: feedback where the person acted, a new
// project that just works, defaults, a calm first look, one stable layout.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/team_project_controller.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_project_conversation.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_project_editors.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_projects_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit/kit_harness.dart';

final _en = lookupAppLocalizations(const Locale('en'));

class _Gateway implements OrchestrationProjectGateway {
  _Gateway(this.workspace);
  TeamWorkspace workspace;
  final commands = <TeamProjectCommand>[];
  final results = <TeamCommandResult>[];
  @override
  Future<TeamWorkspace> teamWorkspace() async => workspace;
  @override
  Stream<TeamWorkspace> watchTeamWorkspace() => const Stream.empty();
  @override
  Future<TeamCommandResult> executeProject(TeamProjectCommand command) async {
    commands.add(command);
    if (results.isNotEmpty) return results.removeAt(0);
    return const TeamCommandResult(accepted: true, revision: 9);
  }

  @override
  Future<void> close() async {}
  @override
  Future<void> deleteLocalData() async {}
}

const _phone = TeamServer(id: 'phone', name: 'This phone', phone: true);

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

Future<(_Gateway, TeamProjectController, BuildContext)> _boot(
  WidgetTester tester,
  TeamWorkspace workspace,
) async {
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Start planning', () {
    testWidgets('starts from one lane and a modest budget', (tester) async {
      final (gateway, controller, context) = await _boot(
        tester,
        const TeamWorkspace(servers: [_phone]),
      );
      teamFolderPickerOverride = (_) async => '/root/projects/app';
      addTearDown(() => teamFolderPickerOverride = null);
      unawaited(openTeamNewProject(context, controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('team-repo-folder')));
      await tester.pumpAndSettle();
      await _type(tester, 'goal', 'Add a README');
      await _tap(tester, 'Start planning');
      final settings = gateway.commands.single.settings!;
      expect(settings.mode, 'single');
      expect(settings.maxLanes, 1);
      expect(settings.budget.chosen, isTrue);
      expect(settings.budget.unlimited, isFalse);
      expect(settings.budget.daily, 5);
      expect(settings.budget.total, 20);
      await _close(tester);
    });

    testWidgets('Team settings name every missing choice at once', (
      tester,
    ) async {
      final (_, controller, context) = await _boot(
        tester,
        const TeamWorkspace(),
      );
      unawaited(openTeamDefaults(context, controller));
      await tester.pumpAndSettle();
      await _tap(tester, 'Save changes');
      expect(
        find.text(
          'Choose Single lane or Parallel agents, and set a budget or '
          'choose No limit.',
        ),
        findsOneWidget,
      );
      await _close(tester);
    });

    testWidgets('a refusal lands in view next to the button that was tapped', (
      tester,
    ) async {
      final (gateway, controller, context) = await _boot(
        tester,
        const TeamWorkspace(servers: [_phone]),
      );
      teamFolderPickerOverride = (_) async => '/root/projects/app';
      addTearDown(() => teamFolderPickerOverride = null);
      gateway.results.add(
        const TeamCommandResult(accepted: false, code: 'repository_empty'),
      );
      unawaited(openTeamNewProject(context, controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('team-repo-folder')));
      await tester.pumpAndSettle();
      await _type(tester, 'goal', 'Add a README');
      await _tap(tester, 'Start planning');
      final notice = find.byKey(const ValueKey('team-refusal'));
      expect(notice, findsOneWidget);
      final sheet = tester.getRect(find.byType(KitSheet));
      final rect = tester.getRect(notice);
      expect(rect.top, greaterThanOrEqualTo(sheet.top));
      expect(rect.bottom, lessThanOrEqualTo(sheet.bottom));
      await _close(tester);
    });

    testWidgets('an empty folder offers its first commit at the folder row', (
      tester,
    ) async {
      final (gateway, controller, context) = await _boot(
        tester,
        const TeamWorkspace(servers: [_phone]),
      );
      final committed = <String>[];
      teamFolderPickerOverride = (_) async => '/root/projects/new';
      teamRepoEmptyOverride = (_) async => true;
      teamFirstCommitOverride = (path) async => committed.add(path);
      addTearDown(() {
        teamFolderPickerOverride = null;
        teamRepoEmptyOverride = null;
        teamFirstCommitOverride = null;
      });
      unawaited(openTeamNewProject(context, controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('team-repo-folder')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('team-repo-empty')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('team-first-commit-inline')));
      await tester.pumpAndSettle();
      expect(committed, ['/root/projects/new']);
      expect(find.byKey(const ValueKey('team-repo-empty')), findsNothing);
      // Only the commit was made: nothing started.
      expect(gateway.commands, isEmpty);
      await _close(tester);
    });
  });

  group('AI Team home', () {
    TeamProject project({String goal = 'Add a README'}) => TeamProject(
      id: 'p',
      name: 'Readme',
      status: 'spec',
      repos: const [TeamRepo(id: 'r', name: 'app', serverId: 'phone')],
      specDraft: TeamSpec(goal: goal),
    );

    testWidgets('Leave demo is offered in the demo only', (tester) async {
      for (final simulated in [true, false]) {
        final (_, controller, context) = await _boot(
          tester,
          TeamWorkspace(
            servers: const [_phone],
            projects: [project()],
            simulated: simulated,
          ),
        );
        pushKitPage<void>(
          context,
          (_) => TeamProjectsScreen(controller: controller, onLeaveDemo: () {}),
        );
        await _settle(tester);
        await tester.tap(find.byTooltip(_en.kitMore).first);
        await _settle(tester);
        final leave = find.text(_en.teamProjectOff);
        simulated ? expect(leave, findsWidgets) : expect(leave, findsNothing);
        await _close(tester);
      }
    });

    testWidgets('the spec header counts the milestone drafted from the goal', (
      tester,
    ) async {
      final (_, controller, context) = await _boot(
        tester,
        TeamWorkspace(servers: const [_phone], projects: [project()]),
      );
      pushKitPage<void>(
        context,
        (_) => TeamProjectOverview(controller: controller, projectId: 'p'),
      );
      await _settle(tester);
      expect(
        find.textContaining('Draft spec · 1 milestone · 1 repo'),
        findsOne,
      );
      await _close(tester);
    });
  });

  group('roles', () {
    const roles = [
      TeamProjectRole(id: 'docs', name: 'Docs'),
      TeamProjectRole(id: 'checker', name: 'Checker', readOnly: true),
      TeamProjectRole(id: 'worker', name: 'Worker'),
      TeamProjectRole(id: 'planner', name: 'Planner', readOnly: true),
    ];

    testWidgets('keep one order: Planner, Worker, Checker, then the rest', (
      tester,
    ) async {
      final (_, controller, context) = await _boot(
        tester,
        const TeamWorkspace(roles: roles),
      );
      unawaited(openTeamRoles(context, controller));
      await tester.pumpAndSettle();
      double y(String name) => tester.getTopLeft(find.text(name).first).dy;
      expect(y('Planner'), lessThan(y('Worker')));
      expect(y('Worker'), lessThan(y('Checker')));
      expect(y('Checker'), lessThan(y('Docs')));
      await _close(tester);
    });

    testWidgets('Worker and Checker lay out Model and Fallback alike', (
      tester,
    ) async {
      final (_, controller, context) = await _boot(
        tester,
        const TeamWorkspace(roles: roles),
      );
      unawaited(openTeamRoles(context, controller));
      await tester.pumpAndSettle();
      Future<List<double>> layout(String role) async {
        await _tap(tester, role);
        final model = tester.getTopLeft(
          find.byKey(const ValueKey('roleModel')),
        );
        final fallback = tester.getTopLeft(
          find.byKey(const ValueKey('roleFallback')),
        );
        await _tap(tester, 'All roles');
        return [model.dy, fallback.dy];
      }

      final worker = await layout('Worker');
      final checker = await layout('Checker');
      expect(checker, worker);
      await _tap(tester, 'Worker');
      expect(find.text(_en.teamProjectEditorFallbackNote), findsOneWidget);
      await _close(tester);
    });
  });

  group('interrupted task', () {
    const interrupted = TeamProject(
      id: 'p',
      name: 'Notes',
      status: 'paused',
      revision: 12,
      planApproved: true,
      repos: [TeamRepo(id: 'r', name: 'app', serverId: 'phone')],
      phases: [TeamPhase(id: 'ph', title: 'Build')],
      tasks: [
        TeamTask(
          id: 'task-1',
          title: 'Create NOTES.md',
          phaseId: 'ph',
          repoId: 'r',
          serverId: 'phone',
          status: 'paused',
          reason: 'structuredOutputInvalid',
        ),
      ],
      requests: [
        TeamRequest(
          id: 'phone-interrupted-task-1',
          kind: 'interrupted',
          title: 'The check finished, but its answer could not be read',
          taskId: 'task-1',
        ),
      ],
    );

    testWidgets('the project asks to resume it, and says what that does', (
      tester,
    ) async {
      final (gateway, controller, context) = await _boot(
        tester,
        const TeamWorkspace(servers: [_phone], projects: [interrupted]),
      );
      pushKitPage<void>(
        context,
        (_) => TeamProjectOverview(controller: controller, projectId: 'p'),
      );
      await _settle(tester);
      expect(find.text(_en.teamProjectInterruptedResumeNote), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('team-interrupted-resume')));
      await _settle(tester);
      final command = gateway.commands.single;
      expect(command.action, TeamProjectAction.resumeTask);
      expect(command.targetId, 'task-1');
      expect(command.expectedRevision, 12);
      await _close(tester);
    });

    testWidgets('the task page shows it and offers one Resume', (tester) async {
      final (gateway, controller, context) = await _boot(
        tester,
        const TeamWorkspace(servers: [_phone], projects: [interrupted]),
      );
      pushKitPage<void>(
        context,
        (_) => TeamProjectConversation(
          controller: controller,
          projectId: 'p',
          taskId: 'task-1',
        ),
      );
      await _settle(tester);
      expect(find.text(_en.teamProjectInterruptedResumeNote), findsOneWidget);
      expect(find.text(_en.teamProjectInterruptedResume), findsOneWidget);
      await tester.tap(find.text(_en.teamProjectInterruptedResume));
      await _settle(tester);
      expect(gateway.commands.single.action, TeamProjectAction.resumeTask);
      expect(gateway.commands.single.targetId, 'task-1');
      await _close(tester);
    });
  });
}
