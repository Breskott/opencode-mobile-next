/// A team task in the Work tab's own lists (docs/design/team-conversation-
/// 2026-09-26.md: a team task is a conversation): its task mark, the
/// title, and "Team · Working · 2 of 5 steps done" or "Team · Waiting for
/// a worker · the team checks every minute". It opens
/// the task's team conversation. It replaces the separate AI Team card on
/// the Work tab.
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/orchestration.dart';
import '../kit/kit_row.dart';
import '../kit/kit_task_mark.dart';
import '../kit/kit_text.dart';
import 'team_now.dart';
import 'team_vocabulary.dart';

/// The team's open tasks (not finished, not cancelled), what needs the
/// person first; the host's upkeep left out.
List<OrchestrationRun> teamOpenTasks(OrchestrationController team) {
  final snapshot = team.snapshot;
  if (!snapshot.hasData) return const [];
  final gated = teamGatedRuns(snapshot);
  return [
    for (final run in teamVisibleRuns(snapshot.runs))
      if (run.state != RunState.completed && run.state != RunState.cancelled)
        run,
  ]..sort((a, b) => teamCompareRuns(a, b, gated));
}

class TeamTaskRow extends StatelessWidget {
  const TeamTaskRow({
    super.key,
    required this.team,
    required this.run,
    required this.onOpen,
  });

  final OrchestrationController team;
  final OrchestrationRun run;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final snapshot = team.snapshot;
    final needsYou = teamGatedRuns(snapshot).contains(run.id);
    final line = teamTaskLine(
      l10n,
      run,
      snapshot.work,
      needsYou: needsYou,
      now: DateTime.now(),
      cycleOf: team.cycleFor,
      explainWait: true,
      checkEvery: teamCheckInterval(team),
      paused: teamRest(snapshot.agents) == TeamRest.paused,
      // The list has no clock of the team's to draw an age from; the
      // task's own page says how long.
      showWaitAge: false,
    );
    // The Work list's own row: the task's mark leads, and the "Team" word
    // in `text1` opens the line, so the row reads as the team's, not one
    // agent's. The list's scaffold is the ink surface.
    return Semantics(
      button: true,
      child: KitRow(
        key: ValueKey('team-work-task-${run.id}'),
        leading: KeyedSubtree(
          key: ValueKey('team-work-task-mark-${run.id}'),
          child: KitTaskMark(state: teamRunMark(run, needsYou: needsYou)),
        ),
        title: run.title,
        titleMaxLines: 2,
        supporting: TextSpan(
          children: [
            TextSpan(
              text: l10n.teamTaskMark,
              style: KitText.styleOf(
                context,
                KitTextRole.secondary,
                tone: KitTextTone.primary,
              ),
            ),
            TextSpan(text: '$teamUsageSeparator$line'),
          ],
        ),
        supportingMaxLines: 2,
        supportingKey: ValueKey('team-work-task-line-${run.id}'),
        onTap: onOpen,
      ),
    );
  }
}
