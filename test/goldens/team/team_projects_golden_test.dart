// Regenerate deliberately, and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opencode_mobile/state/team_project_controller.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_projects_screen.dart';
import '../kit/kit_gallery.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_project_editors.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_project_conversation.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import '../../../tool/capture/census/support/i1_team_core_world.dart';

class _GalleryGateway implements OrchestrationProjectGateway {
  @override
  Future<TeamWorkspace> teamWorkspace() async => const TeamWorkspace(
    servers: [
      TeamServer(id: 'pc', name: 'Home PC'),
      TeamServer(id: 'phone', name: 'This phone', phone: true),
    ],
    roles: [TeamProjectRole(id: 'frontend', name: 'Frontend')],
    projects: [
      TeamProject(
        id: 'site',
        name: 'Lumen launch site',
        status: 'running',
        settings: TeamProjectSettings(
          mode: 'parallel',
          maxLanes: 3,
          budget: TeamBudget(chosen: true, daily: 10, total: 50),
        ),
        specDraft: TeamSpec(
          goal: 'Launch the marketing site and its docs',
          constraints: 'Accessible on phones and computers',
          milestones: [
            TeamMilestone(id: 'm1', title: 'Design tokens', accepted: true),
            TeamMilestone(
              id: 'm2',
              title: 'Landing and pricing',
              criteria: ['Readable at twice the text size'],
            ),
          ],
        ),
        phases: [
          TeamPhase(
            id: 'ph',
            milestoneId: 'm2',
            title: 'Build and check pages',
          ),
        ],
        tasks: [
          TeamTask(
            id: 't',
            title: 'Pricing table',
            phaseId: 'ph',
            roleId: 'frontend',
            serverId: 'pc',
            status: 'running',
            criteria: ['Keyboard can reach each plan'],
            messages: [
              TeamMessage(
                actor: 'frontend',
                text: 'I am checking the pricing layout at larger text sizes.',
              ),
            ],
          ),
        ],
      ),
    ],
  );
  @override
  Stream<TeamWorkspace> watchTeamWorkspace() => const Stream.empty();
  @override
  Future<TeamCommandResult> executeProject(TeamProjectCommand command) async =>
      const TeamCommandResult(accepted: true);
  @override
  Future<void> close() async {}
  @override
  Future<void> deleteLocalData() async {}
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    await loadKitGalleryFonts();
  });
  for (final size in [const Size(412, 915), const Size(1280, 800)]) {
    for (final light in [false, true]) {
      for (final scene in [
        'overview',
        'new',
        'plan',
        'findings',
        'promote',
        'before',
      ]) {
        testWidgets('project $scene ${kitGallerySize(size)} $light', (
          tester,
        ) async {
          final c = TeamProjectController(_GalleryGateway());
          await c.load();
          final original = c.snapshot!.projects.first;
          final task = original.tasks.first.copyWith(
            repoId: 'site',
            status: scene == 'findings'
                ? 'findings'
                : scene == 'promote'
                ? 'merged'
                : 'queued',
            messages: const [],
            findings: scene == 'findings'
                ? const [
                    TeamFinding(
                      id: 'f1',
                      severity: 'critical',
                      text: 'Checkout can lose a draft',
                      criterion: 'Keep entered values after a failed save',
                    ),
                    TeamFinding(
                      id: 'f2',
                      severity: 'major',
                      text: 'Focus skips a plan',
                      criterion: 'Keyboard can reach every plan',
                    ),
                    TeamFinding(
                      id: 'f3',
                      severity: 'minor',
                      text: 'Button text needs clarification',
                      criterion: 'Actions name their target',
                    ),
                  ]
                : const [],
          );
          c.snapshot = c.snapshot!.copyWith(
            projects: [
              original.copyWith(
                status: scene == 'plan' ? 'plan' : 'running',
                planApproved: scene != 'plan',
                phases: [
                  for (final phase in original.phases)
                    phase.copyWith(accepted: scene == 'promote'),
                ],
                mergeQueue: scene == 'promote'
                    ? const [
                        TeamMergeItem(
                          id: 'merge',
                          taskId: 't',
                          repoId: 'site',
                          status: 'merged',
                          checksPassed: true,
                        ),
                      ]
                    : const [],
                repos: const [
                  TeamRepo(
                    id: 'site',
                    name: 'Website',
                    serverId: 'pc',
                    devCommit: 'demo-dev',
                    mainCommit: 'demo-main',
                  ),
                ],
                tasks: scene == 'overview' ? original.tasks : [task],
              ),
            ],
          );
          final legacy = scene == 'before' ? (await teamController()).$1 : null;
          await kitGalleryShot(
            tester,
            name: kitGalleryName('kit_teamprojects_$scene', size, light: light),
            size: size,
            light: light,
            open: (context) {
              if (scene == 'new') {
                openTeamNewProject(context, c);
              } else {
                pushKitPage<void>(
                  context,
                  (_) => switch (scene) {
                    'before' => TeamHomeScreen(
                      controller: legacy!,
                      now: teamNow,
                    ),
                    'overview' =>
                      size == const Size(412, 915)
                          ? TeamProjectOverview(
                              controller: c,
                              projectId: 'site',
                            )
                          : TeamProjectsScreen(controller: c),
                    _ => TeamProjectConversation(
                      controller: c,
                      projectId: 'site',
                      taskId: 't',
                    ),
                  },
                );
              }
            },
            then: scene == 'findings'
                ? (tester) async {
                    await tester.ensureVisible(
                      find.text('Verification findings'),
                    );
                    await tester.pumpAndSettle();
                  }
                : null,
          );
          legacy?.dispose();
          c.dispose();
        }, variant: TargetPlatformVariant.only(TargetPlatform.android));
      }
    }
  }
  for (final size in [
    const Size(360, 800),
    const Size(412, 915),
    const Size(1280, 800),
  ]) {
    testWidgets('project large text ${kitGallerySize(size)}', (tester) async {
      final c = TeamProjectController(_GalleryGateway());
      await c.load();
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_teamprojects_scaled',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        open: (context) => pushKitPage<void>(
          context,
          (_) => TeamProjectsScreen(controller: c),
        ),
      );
      c.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
