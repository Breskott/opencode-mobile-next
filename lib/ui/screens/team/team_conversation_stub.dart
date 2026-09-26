/// STUB — replaced at merge by the real `TeamConversation` from
/// `feat/team-agent-chat` (docs/design/team-conversation-2026-09-26.md: a
/// team task is a conversation on the chat page). Same signatures; until
/// then a new team task opens today's start sheet and a listed team task
/// opens its task page, so the Work tab's Solo · Team choice and its team
/// rows already lead somewhere real.
library;

import 'package:flutter/material.dart';

import '../../../state/orchestration.dart';
import 'run_screen.dart';
import 'start_run_sheet.dart';

abstract final class TeamConversation {
  /// Starts a new team conversation: the person says what the team should
  /// do.
  static Future<void> start(
    BuildContext context,
    OrchestrationController team,
  ) async {
    await showStartRunSheet(context, team);
  }

  /// Opens the team conversation of the task [runId].
  static Future<void> open(
    BuildContext context,
    OrchestrationController team, {
    required String runId,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RunScreen(controller: team, runId: runId),
    ),
  );
}
