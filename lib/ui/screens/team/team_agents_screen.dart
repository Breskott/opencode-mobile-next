/// The AI Team's agents list (docs/design/aiteam-redesign-2026-09-24.md):
/// what the home's one "3 agents · 1 working" row opens. The agents are
/// status, not a control centre (map team-agents, owner Fix).
///
/// One list ordered by urgency (owner rule 2026-09-27, no state sections):
/// the ones waiting for the person, then a crashed one, then the ones at
/// work, idle, and last the ones asleep or paused on the host, each group
/// newest activity first. Every row carries one kind of mark
/// ([KitTaskMark]) and its state in words ("Asleep · wakes when there is
/// work"), and is named "furiosa · Worker" when the host gives the agent a
/// name of its own, so two workers are told apart.
///
/// A paused agent (switched off on the host) offers "Wake furiosa" in its
/// row when the host lets the phone control agents; the row then carries
/// the answer's receipt. A row opens [AgentScreen].
///
/// The top bar says where the team runs and when the list was last
/// checked ("On pop-os · checked 4 min ago"), so old data never passes as
/// live (STATE-20 freshness).
///
/// Kit only (KIT-1): [KitScreen] with [KitTopBar], the shared states and
/// status line of `team_states.dart`, rows on one [KitRowGroup], pull to
/// refresh through [KitRefresh].
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_iconography.dart';
import '../../kit/kit_buttons.dart';
import '../../kit/kit_page_route.dart';
import '../../kit/kit_row.dart';
import '../../kit/kit_screen.dart';
import '../../kit/kit_since.dart';
import '../../kit/kit_state_view.dart';
import '../../kit/kit_task_mark.dart';
import '../../kit/kit_tokens.dart';
import '../../kit/kit_top_bar.dart';
import '../../kit/motion/kit_refresh.dart';
import '../../kit/scenes/team_scenes.dart';
import '../../widgets/relative_time.dart';
import '../../widgets/team_now.dart' show teamAgentPaused;
import '../../widgets/team_receipt.dart';
import '../../widgets/team_vocabulary.dart';
import 'agent_screen.dart';
import 'team_states.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Where an agent stands on this list, most urgent first.
enum TeamAgentStanding {
  /// Waiting for the person, or blocked.
  needsYou,
  crashed,
  working,
  idle,
  unknown,

  /// Stopped on the host; it wakes when there is work.
  asleep,

  /// Switched off on purpose (suspended): nothing wakes it until someone
  /// does.
  paused,
}

/// [agent]'s place on the list.
TeamAgentStanding teamAgentStanding(OrchestrationAgent agent) {
  if (!teamAgentIsLive(agent)) {
    return teamAgentPaused(agent)
        ? TeamAgentStanding.paused
        : TeamAgentStanding.asleep;
  }
  return switch (agent.state) {
    AgentState.waiting || AgentState.blocked => TeamAgentStanding.needsYou,
    AgentState.crashed => TeamAgentStanding.crashed,
    AgentState.working => TeamAgentStanding.working,
    AgentState.idle => TeamAgentStanding.idle,
    AgentState.stopped => TeamAgentStanding.asleep,
    AgentState.unknown => TeamAgentStanding.unknown,
  };
}

/// Urgency first (needs you, crashed, working, idle, asleep, paused), then
/// the newest activity, then the name so the order is stable.
int teamCompareAgentsByUrgency(OrchestrationAgent a, OrchestrationAgent b) {
  final rank = teamAgentStanding(a).index.compareTo(teamAgentStanding(b).index);
  if (rank != 0) return rank;
  final at = a.lastActivity, bt = b.lastActivity;
  if (at != null && bt != null && at != bt) return bt.compareTo(at);
  if (at != null && bt == null) return -1;
  if (at == null && bt != null) return 1;
  return a.name.compareTo(b.name);
}

/// The agent's own name when the host gives it one besides its role:
/// "furiosa" for `ocproof/gastown.furiosa` in the `gastown.polecat` pool.
/// Null when the name only repeats the role (`gastown.mayor`) or there is
/// no pool to tell them apart.
String? teamAgentNickname(OrchestrationAgent agent) {
  final pool = agent.pool;
  if (pool == null || pool.trim().isEmpty) return null;
  String tail(String value) => value.split('/').last.split('.').last.trim();
  final name = tail(agent.name);
  final role = tail(pool).replaceFirst(RegExp(r'-\d+$'), '').toLowerCase();
  if (name.isEmpty || name.toLowerCase().startsWith(role)) return null;
  return name;
}

/// "furiosa · Worker", or the role alone.
String teamAgentTitle(AppLocalizations l10n, OrchestrationAgent agent) {
  final role = teamAgentRoleWord(l10n, teamAgentRole(agent));
  final nickname = teamAgentNickname(agent);
  return nickname == null ? role : '$nickname$teamUsageSeparator$role';
}

class TeamAgentsScreen extends StatefulWidget {
  const TeamAgentsScreen({
    super.key,
    required this.controller,
    this.onOpenAgent,
    this.now,
  });

  final OrchestrationController controller;

  /// Opens an agent's detail; pushes [AgentScreen] when null.
  final ValueChanged<OrchestrationAgent>? onOpenAgent;

  /// Clock for relative ages; tests pin it.
  final DateTime Function()? now;

  @override
  State<TeamAgentsScreen> createState() => _TeamAgentsScreenState();
}

class _TeamAgentsScreenState extends State<TeamAgentsScreen> {
  bool _refreshing = false;

  /// The agent a Wake is being sent for.
  String? _waking;

  DateTime get _now => (widget.now ?? DateTime.now)();

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final controller = widget.controller;
      if (controller.phase == OrchestrationPhase.failed) {
        await controller.retry();
      } else {
        await controller.refresh();
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _wake(OrchestrationAgent agent) async {
    if (_waking != null) return;
    setState(() => _waking = agent.id);
    try {
      await widget.controller.controlAgent(agent.id, AgentControlAction.resume);
    } finally {
      if (mounted) setState(() => _waking = null);
    }
  }

  void _openAgent(OrchestrationAgent agent) {
    final open = widget.onOpenAgent;
    if (open != null) return open(agent);
    unawaited(
      Navigator.of(context).push(
        KitPageRoute<void>(
          builder: (_) => AgentScreen(
            controller: widget.controller,
            agentId: agent.id,
            now: widget.now,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      // Rebuilds once the check is 8 s old and then every minute, so the
      // "checked …" words keep up without a timer of our own.
      return KitSince(
        since: controller.lastRefreshedAt,
        ticks: KitSinceTicks.minutes,
        builder: (context, _) => _screen(context),
      );
    },
  );

  Widget _screen(BuildContext context) {
    final l10n = _copy(context);
    final controller = widget.controller;
    final ready =
        controller.phase == OrchestrationPhase.ready &&
        controller.snapshot.hasData;
    final line = ready
        ? teamStatusLine(
            context,
            controller: controller,
            keyPrefix: 'team-agents',
            onRetry: _refreshing ? null : _refresh,
          )
        : null;
    // The age on the screen's own clock, like every other age here; the
    // KitSince above only decides when to rebuild.
    final checkedAt = controller.lastRefreshedAt;
    final age = checkedAt == null ? null : _now.difference(checkedAt);
    final subtitle = [
      teamHostPhrase(l10n, controller),
      if (ready && age != null)
        l10n.teamAgentsChecked(
          KitSince.ageLabel(context, age.isNegative ? Duration.zero : age),
        ),
    ].join(teamUsageSeparator);
    return KitScreen(
      key: const ValueKey('team-agents'),
      topBar: KitTopBar(title: l10n.teamUiRunTabAgents, subtitle: subtitle),
      width: KitScreenWidth.list,
      header: [?line],
      loading: teamScreenLoading(controller) || _refreshing,
      loadingLabel: l10n.teamUiCardLoading,
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final controller = widget.controller;
    if (teamScreenState(
          context,
          controller: controller,
          keyPrefix: 'team-agents',
          onRetry: _refreshing ? null : _refresh,
        )
        case final state?) {
      return state;
    }
    final snapshot = controller.snapshot;
    final workById = {for (final item in snapshot.work) item.id: item};
    final agents = [...snapshot.agents]..sort(teamCompareAgentsByUrgency);
    final canWake = controller.capabilities.controlAgent;
    return KitRefresh(
      key: const ValueKey('team-agents-pull'),
      onRefresh: _refresh,
      child: ListView(
        key: const ValueKey('team-home-agents'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.only(
          top: tokens.space3,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          if (agents.isEmpty)
            KitStateView(
              key: const ValueKey('team-home-agents-empty'),
              size: KitStateSize.inline,
              liveRegion: false,
              icon: AppIconography.agent,
              // Nobody at work: one agent dozing.
              illustration: const TeamRestScene(),
              title: l10n.teamUiHomeAgentsEmpty,
              body: l10n.teamUiHomeAgentsEmptyHint,
            )
          else
            KitRowGroup(
              children: [
                for (final agent in agents)
                  _AgentRow(
                    agent: agent,
                    work: workById[agent.currentWorkId],
                    now: _now,
                    receipt: controller.latestMutation(
                      kind: MutationKind.controlAgent,
                      targetId: agent.id,
                    ),
                    waking: _waking == agent.id,
                    onWake:
                        canWake &&
                            teamAgentStanding(agent) ==
                                TeamAgentStanding.paused &&
                            (_waking == null || _waking == agent.id)
                        ? () => _wake(agent)
                        : null,
                    onTap: () => _openAgent(agent),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One agent: its mark, "furiosa · Worker", and "Working · Sync engine ·
/// 1m ago" (or "Asleep · wakes when there is work"); a paused agent's Wake
/// and the receipt of what the host did with it under the line.
class _AgentRow extends StatelessWidget {
  const _AgentRow({
    required this.agent,
    required this.work,
    required this.now,
    required this.receipt,
    required this.waking,
    required this.onWake,
    required this.onTap,
  });

  final OrchestrationAgent agent;
  final WorkItem? work;
  final DateTime now;
  final MutationRecord? receipt;
  final bool waking;

  /// Null when the agent cannot be woken from here.
  final VoidCallback? onWake;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final standing = teamAgentStanding(agent);
    final word = switch (standing) {
      TeamAgentStanding.asleep => l10n.teamAgentsAsleep,
      TeamAgentStanding.paused => l10n.teamAgentsPaused,
      _ => teamAgentStateWord(l10n, agent.state),
    };
    final mark = switch (standing) {
      TeamAgentStanding.needsYou => const KitTaskMark(
        state: KitTaskState.needsYou,
      ),
      TeamAgentStanding.crashed => KitTaskMark(
        state: KitTaskState.failed,
        label: word,
      ),
      TeamAgentStanding.working => KitTaskMark(
        state: KitTaskState.working,
        label: word,
      ),
      TeamAgentStanding.idle || TeamAgentStanding.unknown => KitTaskMark(
        state: KitTaskState.waiting,
        label: word,
      ),
      TeamAgentStanding.asleep => KitTaskMark(
        state: KitTaskState.stopped,
        label: word,
      ),
      TeamAgentStanding.paused => KitTaskMark(
        state: KitTaskState.waiting,
        paused: true,
        label: word,
      ),
    };
    final activity = agent.lastActivity == null
        ? null
        : relativeTimeLabel(
            agent.lastActivity!.millisecondsSinceEpoch,
            now: now,
            l10n: l10n,
          );
    final line = switch (standing) {
      TeamAgentStanding.asleep => [word, l10n.teamAgentsAsleepHint],
      TeamAgentStanding.paused => [word, l10n.teamAgentsPausedHint],
      _ => [word, ?work?.title, ?activity],
    }.join(teamUsageSeparator);
    final record = receipt;
    final showReceipt =
        record != null && record.status != MutationStatus.confirmed;
    final wake = onWake;
    final name = teamAgentNickname(agent) ?? teamAgentTitle(l10n, agent);
    return KitRow(
      key: ValueKey('team-home-agent-${agent.id}'),
      leading: mark,
      title: teamAgentTitle(l10n, agent),
      titleKey: ValueKey('team-home-agent-title-${agent.id}'),
      supporting: TextSpan(text: line),
      supportingKey: ValueKey('team-home-agent-state-${agent.id}'),
      // The step's title is the person's own words: two lines before it
      // ends, so the age is not cut off.
      supportingMaxLines: 2,
      below: wake == null && !showReceipt
          ? null
          : Padding(
              padding: EdgeInsetsDirectional.only(top: tokens.space2),
              child: Wrap(
                spacing: tokens.space2,
                runSpacing: tokens.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (wake != null)
                    KitButton.secondary(
                      key: ValueKey('team-agents-wake-${agent.id}'),
                      label: l10n.teamAgentsWake(name),
                      icon: AppIconography.play,
                      expand: false,
                      working: waking,
                      onPressed: waking ? null : wake,
                    ),
                  if (showReceipt)
                    ?teamGateRowReceipt(
                      context,
                      record,
                      key: ValueKey('team-agents-receipt-${agent.id}'),
                      onOpen: onTap,
                    ),
                ],
              ),
            ),
      onTap: onTap,
    );
  }
}
