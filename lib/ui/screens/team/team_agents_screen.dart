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
/// Two agents never share a title: a repeated role is told apart by its
/// project, then by what it looks after ("Supervisor · whole team"), then
/// by number ([teamAgentTitles]). The agents the app keeps off on its own
/// phone team say so ("Off on this phone") and are never offered a Wake.
///
/// Paused agents (switched off on the host) are woken together by one
/// "Wake the paused agents" row above the list when the host lets the
/// phone control agents, one at a time, stopping at the first the host
/// does not confirm; the row carries the receipt, and when the team does
/// not answer it says so in words with Check again. A row opens the
/// agent's conversation in watching mode (slice-P3.6); its own page
/// (the agent screen: state, controls, technical details) is that
/// conversation's top-bar action.
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
import '../../../state/profiles.dart' show OrchestrationConfig;
import '../../../state/team_conversation.dart' show teamSessionState;
import '../../app_iconography.dart';
import '../../kit/kit_buttons.dart';
import '../../kit/kit_receipt.dart';
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
import '../../widgets/team_now.dart'
    show teamAgentKeptOff, teamAgentKind, teamAgentPaused;
import '../../widgets/team_vocabulary.dart';
import '../team_conversation/team_conversation.dart'
    show openTeamAgentConversation;
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

  /// Kept off by the app on its own phone team, to save the phone
  /// ([teamAgentKeptOff]): not the person's pause, never woken from here.
  keptOff,
}

/// [agent]'s place on the list, from its session first
/// ([teamSessionState], ledger row 21): an agent the list calls working
/// whose session the host reports stopped is asleep, never "Working"; one
/// the list calls stopped whose session runs is at work.
TeamAgentStanding teamAgentStanding(
  OrchestrationAgent agent, {
  OrchestrationConfig? config,
}) {
  if (config != null && teamAgentKeptOff(config, agent)) {
    return TeamAgentStanding.keptOff;
  }
  if (!teamAgentIsLive(agent)) {
    return teamAgentPaused(agent)
        ? TeamAgentStanding.paused
        : TeamAgentStanding.asleep;
  }
  return switch (teamSessionState(agent)) {
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
int teamCompareAgentsByUrgency(
  OrchestrationAgent a,
  OrchestrationAgent b, {
  OrchestrationConfig? config,
}) {
  final rank = teamAgentStanding(
    a,
    config: config,
  ).index.compareTo(teamAgentStanding(b, config: config).index);
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

/// The title of each of [agents] by id, none twice (owner, build 2055:
/// three rows all called "Supervisor"). [teamAgentTitle] first; a title
/// shared by several agents takes, where it tells them apart, the agent's
/// project ("Supervisor · demo-app"), then what it looks after
/// ("Supervisor · whole team", "Supervisor · watchdog"), and any title
/// still shared ends with the agent's number in the list ("Worker 2").
Map<String, String> teamAgentTitles(
  AppLocalizations l10n,
  List<OrchestrationAgent> agents,
) {
  final titles = {
    for (final agent in agents) agent.id: teamAgentTitle(l10n, agent),
  };
  List<List<OrchestrationAgent>> shared() {
    final groups = <String, List<OrchestrationAgent>>{};
    for (final agent in agents) {
      groups.putIfAbsent(titles[agent.id]!, () => []).add(agent);
    }
    return [
      for (final group in groups.values)
        if (group.length > 1) group,
    ];
  }

  void qualify(String? Function(OrchestrationAgent) by) {
    for (final group in shared()) {
      for (final agent in group) {
        final word = by(agent);
        if (word == null || word.isEmpty) continue;
        titles[agent.id] = '${titles[agent.id]}$teamUsageSeparator$word';
      }
    }
  }

  qualify((agent) {
    final name = agent.name;
    final slash = name.lastIndexOf('/');
    return slash <= 0 ? null : name.substring(0, slash);
  });
  qualify(
    (agent) => switch (teamAgentKind(agent)) {
      'deacon' => l10n.teamAgentLooksAfterTeam,
      'boot' => l10n.teamAgentLooksAfterWatchdog,
      'witness' => l10n.teamAgentLooksAfterWorkers,
      _ => null,
    },
  );
  for (final group in shared()) {
    for (final (index, agent) in group.indexed) {
      titles[agent.id] = '${titles[agent.id]} ${index + 1}';
    }
  }
  return titles;
}

class TeamAgentsScreen extends StatefulWidget {
  const TeamAgentsScreen({
    super.key,
    required this.controller,
    this.onOpenAgent,
    this.now,
  });

  final OrchestrationController controller;

  /// Opens an agent; its conversation ([openTeamAgentConversation]) when
  /// null.
  final ValueChanged<OrchestrationAgent>? onOpenAgent;

  /// Clock for relative ages; tests pin it.
  final DateTime Function()? now;

  @override
  State<TeamAgentsScreen> createState() => _TeamAgentsScreenState();
}

class _TeamAgentsScreenState extends State<TeamAgentsScreen> {
  bool _refreshing = false;

  /// "Wake the paused agents" is sending.
  bool _waking = false;

  /// The agents the last Wake was sent for, in order; their receipts are
  /// the controller's latest records for them (a sent wake the host never
  /// confirms turns "Not confirmed yet" there). Cleared by Check again.
  List<String> _woken = const [];

  List<MutationRecord> get _wokenRecords => [
    for (final id in _woken)
      ?widget.controller.latestMutation(
        kind: MutationKind.controlAgent,
        targetId: id,
      ),
  ];

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

  /// Wakes [agents] one at a time and stops at the first the host does
  /// not accept: a team that did not answer one wake is not sent more
  /// (starting agents is what can keep a phone's team busy).
  Future<void> _wake(List<OrchestrationAgent> agents) async {
    if (_waking || agents.isEmpty) return;
    setState(() {
      _waking = true;
      _woken = const [];
    });
    final sent = <String>[];
    try {
      for (final agent in agents) {
        sent.add(agent.id);
        if (mounted) setState(() => _woken = List.unmodifiable(sent));
        final record = await widget.controller.controlAgent(
          agent.id,
          AgentControlAction.resume,
        );
        if (!mounted) return;
        final accepted =
            record.status == MutationStatus.confirmed ||
            (record.status == MutationStatus.sent &&
                (record.receipt?.isAccepted ?? false));
        if (!accepted) break;
      }
    } finally {
      if (mounted) setState(() => _waking = false);
    }
  }

  /// After a wake the team did not confirm: read the team again.
  Future<void> _checkAgain() async {
    await _refresh();
    if (mounted) setState(() => _woken = const []);
  }

  /// The wake's receipt: sending while it runs, then the worst answer
  /// (refused, then not confirmed); null once every answer was accepted.
  KitReceiptState? get _wakeState {
    if (_waking) return KitReceiptState.sending;
    final records = _wokenRecords;
    if (records.any((r) => r.status == MutationStatus.rejected)) {
      return KitReceiptState.refused;
    }
    if (records.any((r) => r.status == MutationStatus.unconfirmed)) {
      return KitReceiptState.notConfirmed;
    }
    // Sent and accepted, waiting for the host's echo.
    if (records.any((r) => r.status == MutationStatus.sent)) {
      return KitReceiptState.sent;
    }
    return null;
  }

  void _openAgent(OrchestrationAgent agent) {
    final open = widget.onOpenAgent;
    if (open != null) return open(agent);
    unawaited(
      openTeamAgentConversation(context, agent, team: widget.controller),
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
    final config = controller.config;
    final agents = [...snapshot.agents]
      ..sort((a, b) => teamCompareAgentsByUrgency(a, b, config: config));
    final titles = teamAgentTitles(l10n, agents);
    final paused = [
      for (final agent in agents)
        if (teamAgentStanding(agent, config: config) ==
            TeamAgentStanding.paused)
          agent,
    ];
    final wakeState = _wakeState;
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
          else ...[
            // One action for every paused agent, above the list (owner,
            // build 2055: a Wake button in each row was noise).
            if (canWake && (paused.isNotEmpty || wakeState != null)) ...[
              KitRowGroup(
                children: [
                  KitRow(
                    key: const ValueKey('team-agents-wake-paused'),
                    leading: KitRow.icon(context, AppIconography.play),
                    title: l10n.teamAgentsWakePaused(paused.length),
                    titleMaxLines: 2,
                    supporting: TextSpan(
                      text: switch (wakeState) {
                        KitReceiptState.notConfirmed =>
                          l10n.teamAgentsWakeUnconfirmed,
                        KitReceiptState.refused => l10n.teamAgentsWakeRefused,
                        _ => l10n.teamAgentsWakePausedHint,
                      },
                    ),
                    supportingKey: const ValueKey('team-agents-wake-line'),
                    supportingMaxLines: 4,
                    enabled: !_waking,
                    onTap: _waking || paused.isEmpty
                        ? null
                        : () => _wake(paused),
                    below: wakeState == null
                        ? null
                        : Padding(
                            padding: EdgeInsetsDirectional.only(
                              top: tokens.space2,
                            ),
                            child: Wrap(
                              spacing: tokens.space2,
                              runSpacing: tokens.space2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                KitReceipt(
                                  key: const ValueKey(
                                    'team-agents-wake-receipt',
                                  ),
                                  state: wakeState,
                                  sendingLabel: l10n.teamAgentsWaking,
                                ),
                                if (wakeState == KitReceiptState.notConfirmed ||
                                    wakeState == KitReceiptState.refused)
                                  KitButton.secondary(
                                    key: const ValueKey(
                                      'team-agents-wake-check',
                                    ),
                                    label: l10n.teamAgentsWakeCheckAgain,
                                    icon: AppIconography.retry,
                                    expand: false,
                                    working: _refreshing,
                                    onPressed: _refreshing ? null : _checkAgain,
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
              SizedBox(height: tokens.sectionGap),
            ],
            KitRowGroup(
              children: [
                for (final agent in agents)
                  _AgentRow(
                    agent: agent,
                    title: titles[agent.id]!,
                    standing: teamAgentStanding(agent, config: config),
                    work: workById[agent.currentWorkId],
                    now: _now,
                    onTap: () => _openAgent(agent),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One agent: its mark, its title (never another agent's), and "Working ·
/// Sync engine · 1m ago" (or "Asleep · wakes when there is work").
class _AgentRow extends StatelessWidget {
  const _AgentRow({
    required this.agent,
    required this.title,
    required this.standing,
    required this.work,
    required this.now,
    required this.onTap,
  });

  final OrchestrationAgent agent;
  final String title;
  final TeamAgentStanding standing;
  final WorkItem? work;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final word = switch (standing) {
      TeamAgentStanding.asleep => l10n.teamAgentsAsleep,
      TeamAgentStanding.paused => l10n.teamAgentsPaused,
      TeamAgentStanding.keptOff => l10n.teamAgentsKeptOff,
      _ => teamAgentStateWord(l10n, teamSessionState(agent)),
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
      TeamAgentStanding.asleep || TeamAgentStanding.keptOff => KitTaskMark(
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
      TeamAgentStanding.keptOff => [word, l10n.teamAgentsKeptOffHint],
      _ => [word, ?work?.title, ?activity],
    }.join(teamUsageSeparator);
    return KitRow(
      key: ValueKey('team-home-agent-${agent.id}'),
      leading: mark,
      title: title,
      titleKey: ValueKey('team-home-agent-title-${agent.id}'),
      supporting: TextSpan(text: line),
      supportingKey: ValueKey('team-home-agent-state-${agent.id}'),
      // The step's title is the person's own words: two lines before it
      // ends, so the age is not cut off.
      supportingMaxLines: 2,
      onTap: onTap,
    );
  }
}
