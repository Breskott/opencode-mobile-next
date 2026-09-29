/// Team settings: everything about how the AI Team is set up, kept off the
/// work page (crit team-page 2026-09-29). Opened from the team page's top
/// bar and from Settings › AI Team while the team is on.
///
/// One list: the **agents** row (opening [TeamAgentsScreen]), what the team
/// **spent today** when the host reports it, the host's upkeep in words, the
/// phone's own team controls and Change address where they apply, the
/// **Details** row (how fast it runs; the address, version and engine, where
/// Gas City is named, behind it) and **Turn off the AI Team** last.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;

import '../../../builtin/team/builtin_team.dart' show BuiltinTeam;
import '../../../builtin/thermal_guard.dart';
import '../../../builtin/thermal_guard_teams.dart'
    show thermalGuardSlotProvider;
import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/connection.dart';
import '../../../state/orchestration.dart';
import '../../../state/team_conversation.dart' show teamSessionState;
import '../../../state/team_overview.dart';
import '../../../termux/team_runtime.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/team_discovery_card.dart'
    show teamHostDisclaimer, teamHostKindFor;
import '../../widgets/team_host_form.dart'
    show TeamHostProbe, showTeamTurnOffSheet;
import '../../widgets/team_now.dart';
import '../../widgets/team_phone_section.dart' show TeamPhoneSection;
import '../../widgets/team_switch.dart';
import '../../widgets/team_technical_details.dart';
import '../../widgets/team_vocabulary.dart';
import '../settings/plugins_screen.dart' show teamPhoneProfile;
import 'team_agents_screen.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Opens Team settings over the current page.
Future<void> openTeamSettings(
  BuildContext context, {
  required OrchestrationController controller,
  ConnectionController? connection,
  ValueListenable<ThermalGuard?>? thermalGuard,
  TeamHostProbe? probe,
  TermuxTeamRuntime? teamRuntime,
  DateTime Function()? now,
  ValueChanged<OrchestrationAgent>? onOpenAgent,
  VoidCallback? onTeamChanged,
}) => Navigator.of(context).push(
  KitPageRoute<void>(
    builder: (_) => TeamSettingsScreen(
      controller: controller,
      connection: connection,
      thermalGuard: thermalGuard,
      probe: probe,
      teamRuntime: teamRuntime,
      now: now,
      onOpenAgent: onOpenAgent,
      onTeamChanged: onTeamChanged,
    ),
  ),
);

class TeamSettingsScreen extends StatefulWidget {
  const TeamSettingsScreen({
    super.key,
    required this.controller,
    this.connection,
    this.thermalGuard,
    this.probe,
    this.teamRuntime,
    this.now,
    this.onOpenAgent,
    this.onTeamChanged,
  });

  final OrchestrationController controller;

  /// The connection whose server this team belongs to: Change address and
  /// Turn off write its profile. Neither is offered without one.
  final ConnectionController? connection;

  /// The heat guard's slot ([thermalGuardSlotProvider] when null).
  final ValueListenable<ThermalGuard?>? thermalGuard;

  /// The Gas City probe of the address form; tests pass a fake.
  final TeamHostProbe? probe;

  /// The Termux team runtime; tests pass a fake.
  final TermuxTeamRuntime? teamRuntime;
  final DateTime Function()? now;
  final ValueChanged<OrchestrationAgent>? onOpenAgent;

  /// After Change address or Turn off replaced this team; this page has
  /// closed itself first.
  final VoidCallback? onTeamChanged;

  @override
  State<TeamSettingsScreen> createState() => _TeamSettingsScreenState();
}

class _TeamSettingsScreenState extends State<TeamSettingsScreen> {
  bool _offFailed = false;
  bool _switching = false;
  ValueListenable<ThermalGuard?>? _scopeHeat;

  ValueListenable<ThermalGuard?>? get _heat =>
      widget.thermalGuard ?? _scopeHeat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.thermalGuard != null) return;
    try {
      _scopeHeat = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(thermalGuardSlotProvider);
    } on StateError {
      _scopeHeat = null;
    }
  }

  /// The connection's profile when it is this team's, else null.
  ConnectionController? get _owner {
    final connection = widget.connection;
    final profile = connection?.profile;
    if (connection == null ||
        profile == null ||
        profile.id != widget.controller.profileId ||
        profile.orchestration == null) {
      return null;
    }
    return connection;
  }

  bool get _cooling {
    final hold = _heat?.value?.holds[widget.controller.profileId];
    if (hold == null) return false;
    final controller = widget.controller;
    return teamOverview(
          profileId: controller.profileId,
          host: controller.host,
          agents: null,
          isStale: true,
          heatHold: hold,
        ).heatHold !=
        null;
  }

  void _changed() {
    if (mounted) Navigator.of(context).pop();
    widget.onTeamChanged?.call();
  }

  Future<void> _changeAddress() async {
    final connection = _owner;
    if (connection == null || _switching) return;
    setState(() => _switching = true);
    try {
      final saved = await editTeamAddress(
        context,
        connection,
        probe: widget.probe,
      );
      if (saved) _changed();
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _turnOff() async {
    final connection = _owner;
    final profile = connection?.profile;
    if (connection == null || profile == null || _switching) return;
    final confirmed = await showTeamTurnOffSheet(context, profile.name);
    if (!confirmed || !mounted) return;
    setState(() {
      _switching = true;
      _offFailed = false;
    });
    try {
      final outcome = await turnOffTeam(connection, profile);
      if (outcome == TeamOffOutcome.failed) {
        if (mounted) setState(() => _offFailed = true);
        return;
      }
      _changed();
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _openPhoneControls() {
    final connection = _owner!;
    final l10n = _copy(context);
    return showKitSheet<void>(
      context,
      title: l10n.teamUiPhoneSectionTitle,
      icon: AppIconography.phone,
      sheetKey: const ValueKey('team-home-phone-sheet'),
      body: (sheetContext) => TeamPhoneSection(
        connection: connection,
        profile: connection.profile!,
        runtime: widget.teamRuntime,
        onRemoved: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  void _openAgents() {
    Navigator.of(context).push(
      KitPageRoute<void>(
        builder: (_) => TeamAgentsScreen(
          controller: widget.controller,
          onOpenAgent: widget.onOpenAgent,
          now: widget.now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, widget.connection, _heat]),
      builder: (context, _) {
        final owner = _owner;
        final builtin = BuiltinTeam.isBuiltinConfig(controller.config);
        final snapshot = controller.snapshot;
        final live = teamLiveAgents(snapshot.agents);
        final working = live
            .where((a) => teamSessionState(a) == AgentState.working)
            .length;
        final crashed = live
            .where((a) => teamSessionState(a) == AgentState.crashed)
            .length;
        final keptOff = snapshot.agents
            .where((a) => teamAgentKeptOff(controller.config, a))
            .length;
        final pausedAgents = snapshot.agents
            .where(
              (a) =>
                  !teamAgentIsLive(a) &&
                  teamAgentPaused(a) &&
                  !teamAgentKeptOff(controller.config, a),
            )
            .length;
        final rest = teamRest(snapshot.agents, config: controller.config);
        final upkeep = teamUpkeepRuns(snapshot.runs);
        final spent = _spentRow(context, l10n, controller);
        return KitScreen(
          key: const ValueKey('team-settings'),
          topBar: KitTopBar(
            title: l10n.teamSettingsTitle,
            subtitle: teamHostPhrase(l10n, controller),
          ),
          width: KitScreenWidth.list,
          body: ListView(
            key: const ValueKey('team-settings-list'),
            padding: EdgeInsetsDirectional.only(
              bottom: KitScreen.endPadding(context),
            ),
            children: [
              if (_offFailed)
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: tokens.gutter,
                    vertical: tokens.space2,
                  ),
                  child: KitNotice(
                    key: const ValueKey('team-home-turn-off-failed'),
                    tone: AppStatusTone.failure,
                    icon: AppIconography.error,
                    message: l10n.teamHomeTurnOffFailed,
                    onDismiss: () => setState(() => _offFailed = false),
                  ),
                )
              else
                SizedBox(height: tokens.space3),
              KitRowGroup(
                key: const ValueKey('team-home-team'),
                children: [
                  _AgentsRow(
                    key: const ValueKey('team-home-agents-row'),
                    total: snapshot.agents.length,
                    rest: rest,
                    cooling: _cooling,
                    working: working,
                    crashed: crashed,
                    paused: pausedAgents,
                    keptOff: keptOff,
                    onTap: _openAgents,
                  ),
                  ?spent,
                  if (upkeep.isNotEmpty)
                    KitRow(
                      key: const ValueKey('team-home-upkeep-row'),
                      leading: KitRow.icon(context, AppIconography.retry),
                      title: l10n.teamHomeUpkeepTitle,
                      supporting: TextSpan(text: teamUpkeepLine(l10n, upkeep)),
                      supportingKey: const ValueKey('team-home-upkeep-line'),
                      supportingMaxLines: 3,
                    ),
                ],
              ),
              SizedBox(height: tokens.sectionGap),
              KitRowGroup(
                key: const ValueKey('team-settings-how'),
                children: [
                  if (owner != null && teamPhoneProfile(owner.profile))
                    KitRow(
                      key: const ValueKey('team-home-phone-controls'),
                      leading: KitRow.icon(context, AppIconography.phone),
                      title: l10n.teamHomePhoneControls,
                      trailing: const KitChevron(),
                      onTap: () => unawaited(_openPhoneControls()),
                    ),
                  if (owner != null && !builtin)
                    KitRow(
                      key: const ValueKey('team-home-change-address'),
                      leading: KitRow.icon(context, AppIconography.edit),
                      title: l10n.teamHomeChangeAddress,
                      enabled: !_switching,
                      trailing: const KitChevron(),
                      onTap: () => unawaited(_changeAddress()),
                    ),
                  // How fast it runs where it runs; the address, version and
                  // engine (where Gas City is named) are behind it.
                  KitRow(
                    key: const ValueKey('team-home-host-row'),
                    leading: KitRow.icon(context, AppIconography.speed),
                    title: l10n.teamUiTechnicalDetails,
                    supporting: TextSpan(
                      text: teamHostDisclaimer(
                        l10n,
                        teamHostKindFor(
                          controller.config,
                          controller.host?.hostMode ??
                              controller.config.hostMode,
                        ),
                      ),
                    ),
                    supportingKey: const ValueKey('team-home-host-speed'),
                    supportingMaxLines: 2,
                    trailing: const KitChevron(),
                    onTap: () => showTeamHostDetailsSheet(context, controller),
                  ),
                  if (owner != null)
                    KitRow(
                      key: const ValueKey('team-home-turn-off'),
                      leading: KitRow.icon(context, AppIconography.unlink),
                      title: l10n.teamSettingsTurnOff,
                      destructive: true,
                      enabled: !_switching,
                      onTap: () => unawaited(_turnOff()),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// What the whole team spent today, as the host estimates it; null when
  /// the host reports nothing (unknown is never "\$0").
  Widget? _spentRow(
    BuildContext context,
    AppLocalizations l10n,
    OrchestrationController controller,
  ) {
    if (!controller.capabilities.usage) return null;
    final evidence = controller.snapshot.usage?.evidence;
    final today = evidence != null && evidence.available
        ? evidence.today
        : null;
    if (today == null) return null;
    final cost = today.costUsdEstimate;
    final input = today.inputTokens, output = today.outputTokens;
    final tokens = input == null && output == null
        ? null
        : (input ?? 0) + (output ?? 0);
    if ((cost ?? 0) == 0 && (tokens ?? 0) == 0) return null;
    final figures = [
      if (cost != null) l10n.teamUiUsageCostEstimated(teamCurrencyLabel(cost)),
      if (tokens != null) l10n.teamUiUsageTokens(teamCompactCount(tokens)),
    ];
    final lines = [
      l10n.teamHomeSpentHint,
      if ((today.unpriced ?? 0) > 0)
        l10n.teamHomeSpentPartial
      else if (evidence!.partial)
        l10n.teamHomeSpentHistoryMissing,
      if (!evidence!.recording) l10n.teamHomeSpentNotRecording,
    ];
    return KitRow(
      key: const ValueKey('team-home-spent'),
      leading: KitRow.icon(context, AppIconography.usage),
      title: l10n.teamHomeSpentToday(figures.join(teamUsageSeparator)),
      titleKey: const ValueKey('team-home-spent-figure'),
      supporting: TextSpan(text: lines.join(' ')),
      supportingKey: const ValueKey('team-home-spent-scope'),
      supportingMaxLines: 5,
    );
  }
}

/// "6 agents · 1 working · 4 kept off on this phone", opening the agents
/// list: it counts every agent the list shows, so the two agree.
class _AgentsRow extends StatelessWidget {
  const _AgentsRow({
    super.key,
    required this.total,
    required this.rest,
    required this.working,
    required this.onTap,
    this.crashed = 0,
    this.paused = 0,
    this.keptOff = 0,
    this.cooling = false,
  });

  final int total;
  final TeamRest rest;
  final int working;
  final int crashed;
  final int paused;
  final int keptOff;
  final bool cooling;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final count = l10n.teamUiHomeAgentsRowCount(total);
    final kept = keptOff > 0 ? l10n.teamHomeAgentsRowKeptOff(keptOff) : null;
    final title = switch (cooling ? null : rest) {
      null => [count, l10n.teamHomeAgentsCooling],
      TeamRest.asleep => [count, l10n.teamNowAgentsAsleep, ?kept],
      TeamRest.paused => [count, l10n.teamNowAgentsPaused, ?kept],
      TeamRest.awake => [
        count,
        if (working > 0) l10n.teamUiHomeAgentsRowWorking(working),
        if (crashed > 0) l10n.teamHomeAgentsRowCrashed(crashed),
        if (paused > 0) l10n.teamHomeAgentsRowPaused(paused),
        ?kept,
      ],
    }.join(teamUsageSeparator);
    return Semantics(
      button: true,
      hint: l10n.teamUiHomeAgentsRowHint,
      child: KitRow(
        leading: KitRow.icon(context, AppIconography.agent),
        title: title,
        titleMaxLines: 2,
        trailing: const KitChevron(),
        onTap: onTap,
      ),
    );
  }
}
