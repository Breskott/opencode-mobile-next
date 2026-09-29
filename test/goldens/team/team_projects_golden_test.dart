// Regenerate deliberately, and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/team_project_controller.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_projects_screen.dart';
import '../kit/kit_gallery.dart';

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
  setUpAll(loadKitGalleryFonts);
  for (final size in [const Size(412, 915), const Size(1280, 800)]) {
    for (final light in [false, true]) {
      testWidgets('project journey ${kitGallerySize(size)} $light', (
        tester,
      ) async {
        final c = TeamProjectController(_GalleryGateway());
        await c.load();
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_teamprojects_overview', size, light: light),
          size: size,
          light: light,
          open: (context) {
            pushKitPage<void>(
              context,
              (_) => size == const Size(412, 915)
                  ? TeamProjectOverview(controller: c, projectId: 'site')
                  : TeamProjectsScreen(controller: c),
            );
          },
        );
        c.dispose();
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }
  }
}
