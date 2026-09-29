import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/team_project_controller.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_projects_screen.dart';
import 'kit/kit_harness.dart';

class _Gateway implements OrchestrationProjectGateway {
  TeamWorkspace value = const TeamWorkspace(
    servers: [TeamServer(id: 'pc', name: 'Home PC')],
    roles: [TeamProjectRole(id: 'frontend', name: 'Frontend')],
    projects: [
      TeamProject(
        id: 'site',
        name: 'Launch site',
        status: 'running',
        specDraft: TeamSpec(
          goal: 'Make our site accessible',
          milestones: [TeamMilestone(id: 'm', title: 'Accessible pages')],
        ),
        phases: [TeamPhase(id: 'ph', milestoneId: 'm', title: 'Build pages')],
        tasks: [
          TeamTask(
            id: 't',
            title: 'Pricing page',
            phaseId: 'ph',
            roleId: 'frontend',
            serverId: 'pc',
            status: 'running',
          ),
        ],
      ),
      TeamProject(
        id: 'urgent',
        name: 'Restore sync',
        requests: [TeamRequest(id: 'q', title: 'Keep offline drafts?')],
      ),
    ],
  );
  final commands = <TeamProjectCommand>[];
  @override
  Future<TeamWorkspace> teamWorkspace() async => value;
  @override
  Stream<TeamWorkspace> watchTeamWorkspace() => const Stream.empty();
  @override
  Future<TeamCommandResult> executeProject(TeamProjectCommand command) async {
    commands.add(command);
    return const TeamCommandResult(accepted: true);
  }

  @override
  Future<void> close() async {}
  @override
  Future<void> deleteLocalData() async {}
}

void main() {
  testWidgets('urgent projects lead and phone opens selected project', (
    tester,
  ) async {
    final gateway = _Gateway();
    final c = TeamProjectController(gateway);
    await c.load();
    final context = await pumpKitHost(tester);
    pushKitPage<void>(context, (_) => TeamProjectsScreen(controller: c));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Restore sync').last).dy,
      lessThan(tester.getTopLeft(find.text('Launch site')).dy),
    );
    await tester.tap(find.text('Launch site'));
    await tester.pumpAndSettle();
    expect(find.text('Make our site accessible'), findsOneWidget);
    expect(find.text('Accessible pages'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });

  testWidgets('large layout shows project overview and conversation together', (
    tester,
  ) async {
    final c = TeamProjectController(_Gateway());
    await c.load();
    final context = await pumpKitHost(tester, size: const Size(1280, 800));
    pushKitPage<void>(context, (_) => TeamProjectsScreen(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Launch site'));
    await tester.pumpAndSettle();
    expect(find.text('Make our site accessible'), findsOneWidget);
    expect(find.byType(KitComposer), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
