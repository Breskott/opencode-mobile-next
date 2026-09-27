/// The AI Team as a conversation (docs/design/team-conversation-2026-09-26.md):
/// the doors into it. The page itself is part of the chat library
/// ([TeamConversationScreen]) so it draws with the chat's own parts.
///
/// Frozen for callers (New conversation's "Solo · Team", the Work tab):
/// - [TeamConversation.open]: an existing task's conversation;
/// - [TeamConversation.start]: give the team a new task (the existing
///   Start-a-task sheet), then open its conversation, which binds to the
///   task's run as soon as the team lists it.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../../state/team_planning.dart' show TeamPlanningRequest;
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../chat_screen.dart';
import '../team/start_run_sheet.dart' show showStartRunSheet;

export '../chat_screen.dart'
    show
        TeamAgentConversationLookup,
        TeamAgentConversationMiss,
        TeamAgentTranscript,
        TeamConversationScreen,
        TeamControllerScope,
        TeamOpenConversationRow,
        TeamPendingTask,
        lookupTeamAgentConversation,
        openTeamAgentConversation,
        teamAgentConversationMissNote,
        teamAgentWatch;

abstract final class TeamConversation {
  /// Opens the conversation of the task [runId].
  static Future<void> open(
    BuildContext context,
    OrchestrationController team, {
    required String runId,
  }) => Navigator.of(context).push(route(team, runId: runId));

  /// The route [open] pushes, for a door that holds a [NavigatorState]
  /// rather than a context (the team notification).
  static Route<void> route(
    OrchestrationController team, {
    required String runId,
  }) => KitPageRoute<void>(
    builder: (_) => TeamControllerScope(
      team: team,
      child: TeamConversationScreen(team: team, runId: runId),
    ),
  );

  /// Asks for a new task (the team's Start-a-task sheet: the planner, or a
  /// direct task when the planner is off), then opens its conversation.
  /// Nothing opens when the person backs out or the host refused the task;
  /// the sheet's record comes back so a caller can say a refusal the sheet
  /// did not (a work item made but refused by its worker pool).
  static Future<MutationRecord?> start(
    BuildContext context,
    OrchestrationController team,
  ) async {
    final record = await showStartRunSheet(context, team);
    if (record == null ||
        record.status == MutationStatus.rejected ||
        !context.mounted) {
      return record;
    }
    final TeamPendingTask pending;
    switch (record.kind) {
      case MutationKind.createWork:
        pending = TeamPendingTask(
          title: record.request.targetId,
          details: record.request.text,
          sentAt: record.createdAt,
          workId: record.receipt?.createdId,
        );
      case MutationKind.message:
        final parsed = TeamPlanningRequest.parse(record);
        pending = TeamPendingTask(
          title: parsed?.objective ?? record.request.text ?? '',
          sentAt: record.createdAt,
          record: record,
        );
      default:
        return record;
    }
    await Navigator.of(context).push(
      KitPageRoute<void>(
        builder: (_) => TeamControllerScope(
          team: team,
          child: TeamConversationScreen(team: team, pending: pending),
        ),
      ),
    );
    return record;
  }
}

/// "Open conversation" on a task's Overview: the task as a conversation
/// (its workers are one tap further, each in watching mode).
class TeamTaskConversationRow extends StatelessWidget {
  const TeamTaskConversationRow({
    super.key,
    required this.team,
    required this.runId,
  });

  final OrchestrationController team;
  final String runId;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return KitRow(
      key: const ValueKey('team-run-open-conversation'),
      leading: KitRow.icon(context, AppIconography.chat),
      title: l10n.teamOpenConversation,
      supporting: TextSpan(text: l10n.teamOpenTaskConversationHint),
      trailing: const KitChevron(),
      onTap: () => TeamConversation.open(context, team, runId: runId),
    );
  }
}
