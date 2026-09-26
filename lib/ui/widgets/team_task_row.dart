/// A team task in the Work tab's own lists (docs/design/team-conversation-
/// 2026-09-26.md: a team task is a conversation): its task mark with a small
/// team badge, the title, and "Team · Working · 2 of 5 steps done" or
/// "Team · Waiting for a worker · the team checks every minute". It opens
/// the task's team conversation. It replaces the separate AI Team card on
/// the Work tab.
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/orchestration.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
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
    final theme = Theme.of(context);
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
    // A transparent ink surface of its own, like the TeamCard it replaces,
    // so the row splashes wherever the list is placed.
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        child: KitRow(
          key: ValueKey('team-work-task-${run.id}'),
          leading: SizedBox.square(
            dimension: 32,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                KitTaskMark(state: teamRunMark(run, needsYou: needsYou)),
                // The team mark: this row is the team's, not one agent's.
                PositionedDirectional(
                  end: -2,
                  bottom: -2,
                  child: Container(
                    key: ValueKey('team-work-task-mark-${run.id}'),
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIconography.agent,
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          title: run.title,
          titleMaxLines: 2,
          supporting: TextSpan(
            children: [
              TextSpan(
                text: l10n.teamTaskMark,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(text: '$teamUsageSeparator$line'),
            ],
          ),
          supportingMaxLines: 2,
          supportingKey: ValueKey('team-work-task-line-${run.id}'),
          onTap: onOpen,
        ),
      ),
    );
  }
}
