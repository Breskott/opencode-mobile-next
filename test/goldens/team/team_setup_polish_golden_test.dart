// Regenerate deliberately, and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/team_project_controller.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_project_conversation.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_project_editors.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_projects_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../kit/kit_gallery.dart';

class _Gateway implements OrchestrationProjectGateway {
  _Gateway(this.workspace);
  final TeamWorkspace workspace;
  @override
  Future<TeamWorkspace> teamWorkspace() async => workspace;
  @override
  Stream<TeamWorkspace> watchTeamWorkspace() => const Stream.empty();
  @override
  Future<TeamCommandResult> executeProject(TeamProjectCommand command) async =>
      const TeamCommandResult(accepted: false, code: 'repository_empty');
  @override
  Future<void> close() async {}
  @override
  Future<void> deleteLocalData() async {}
}

const _phone = TeamServer(id: 'phone', name: 'This phone', phone: true);
const _interrupted = TeamProject(
  id: 'p',
  name: 'Create NOTES.md',
  status: 'paused',
  revision: 12,
  simulated: false,
  planApproved: true,
  specDraft: TeamSpec(goal: 'Create NOTES.md with one line'),
  repos: [TeamRepo(id: 'r', name: 'hello-team', serverId: 'phone')],
  phases: [TeamPhase(id: 'ph', title: 'Build')],
  tasks: [
    TeamTask(
      id: 'task-1',
      title: 'Create NOTES.md',
      phaseId: 'ph',
      roleId: 'worker',
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
  timeline: [
    TeamTimelineEvent(
      id: 'e',
      kind: 'taskCheckpoint',
      actor: 'engine',
      taskId: 'task-1',
      text:
          'Work was interrupted. Resume to check its existing session '
          '(checkerAnswerUnreadable).',
    ),
  ],
);
const _roles = [
  TeamProjectRole(id: 'planner', name: 'Planner', readOnly: true),
  TeamProjectRole(id: 'worker', name: 'Worker'),
  TeamProjectRole(id: 'checker', name: 'Checker', readOnly: true),
];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    await loadKitGalleryFonts();
  });
  const size = Size(412, 915);
  for (final light in [false, true]) {
    for (final scene in [
      'interrupted-task',
      'interrupted-project',
      'role-worker',
      'role-checker',
      'empty-folder',
      'refusal-in-view',
    ]) {
      testWidgets('setup polish $scene $light', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final c = TeamProjectController(
          _Gateway(
            const TeamWorkspace(
              servers: [_phone],
              roles: _roles,
              projects: [_interrupted],
              simulated: false,
            ),
          ),
        );
        await c.load();
        teamFolderPickerOverride = (_) async => '/root/projects/notes';
        teamRepoEmptyOverride = (_) async => scene == 'empty-folder';
        teamFirstCommitOverride = (_) async {};
        addTearDown(() {
          teamFolderPickerOverride = null;
          teamRepoEmptyOverride = null;
          teamFirstCommitOverride = null;
          c.dispose();
        });
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_teamsetuppolish_${scene.replaceAll('-', '')}',
            size,
            light: light,
          ),
          size: size,
          light: light,
          open: (context) {
            switch (scene) {
              case 'interrupted-task':
                pushKitPage<void>(
                  context,
                  (_) => TeamProjectConversation(
                    controller: c,
                    projectId: 'p',
                    taskId: 'task-1',
                  ),
                );
              case 'interrupted-project':
                pushKitPage<void>(
                  context,
                  (_) => TeamProjectOverview(controller: c, projectId: 'p'),
                );
              case 'role-worker' || 'role-checker':
                unawaited(openTeamRoles(context, c));
              default:
                unawaited(openTeamNewProject(context, c));
            }
          },
          then: (tester) async {
            Future<void> tap(Finder f) async {
              await tester.ensureVisible(f);
              await tester.pumpAndSettle();
              await tester.tap(f.last);
              await tester.pumpAndSettle();
            }

            switch (scene) {
              case 'role-worker':
                await tap(find.text('Worker'));
              case 'role-checker':
                await tap(find.text('Checker'));
              case 'empty-folder' || 'refusal-in-view':
                await tap(find.byKey(const ValueKey('team-repo-folder')));
                if (scene == 'refusal-in-view') {
                  await tester.enterText(
                    find.descendant(
                      of: find.byKey(const ValueKey('goal')),
                      matching: find.byType(EditableText),
                    ),
                    'Create NOTES.md with one line',
                  );
                  tester.testTextInput.hide();
                  await tester.pumpAndSettle();
                  await tap(find.text('Start planning'));
                }
            }
          },
        );
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }
  }
}
