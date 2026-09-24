/// The AI Team's agents list (docs/design/aiteam-redesign-2026-09-24.md):
/// what the home's one "3 agents · 1 working" row opens. The agents that
/// are on, named by role, what needs the person first (02-ux §5.1); then
/// the ones switched off on the host under one collapsed group: they
/// exist, they are not the team at work. A row opens [AgentScreen].
///
/// Design standard: one scroll view on [KitScreen], the shared states and
/// status line of `team_states.dart`, rows on [KitRow], pull to refresh.
library;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../kit/scenes/team_scenes.dart';
import '../../widgets/team_agent_row.dart';
import '../../widgets/team_vocabulary.dart';
import 'agent_screen.dart';
import 'team_states.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

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
  /// The "Suspended on the host" group: collapsed on every open.
  bool _suspendedExpanded = false;
  bool _refreshing = false;

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

  void _openAgent(OrchestrationAgent agent) {
    final open = widget.onOpenAgent;
    if (open != null) return open(agent);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgentScreen(
          controller: widget.controller,
          agentId: agent.id,
          now: widget.now,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = _copy(context);
      final theme = Theme.of(context);
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
      return Scaffold(
        key: const ValueKey('team-agents'),
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.teamUiRunTabAgents, maxLines: 1),
              Text(
                teamHostPhrase(l10n, controller),
                key: const ValueKey('team-agents-host'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedOf(theme),
                ),
              ),
            ],
          ),
        ),
        body: KitScreen(
          header: [?line],
          loading: teamScreenLoading(controller) || _refreshing,
          loadingLabel: l10n.teamUiCardLoading,
          body: _body(context),
        ),
      );
    },
  );

  Widget _body(BuildContext context) {
    final l10n = _copy(context);
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
    final live = teamLiveAgents(snapshot.agents)..sort(teamCompareAgents);
    final off = teamOffAgents(snapshot.agents)..sort(teamCompareAgents);
    Widget row(OrchestrationAgent agent) => TeamAgentRow(
      keyPrefix: 'team-home-agent',
      agent: agent,
      work: workById[agent.currentWorkId],
      now: _now,
      onTap: () => _openAgent(agent),
    );
    final rows = <Widget>[
      if (live.isEmpty)
        KitStateView(
          key: const ValueKey('team-home-agents-empty'),
          size: KitStateSize.inline,
          liveRegion: false,
          icon: AppIconography.agent,
          // Nobody at work: one agent dozing.
          illustration: const TeamRestScene(),
          title: l10n.teamUiHomeAgentsEmpty,
          body: l10n.teamUiHomeAgentsEmptyHint,
        ),
      for (final agent in live) row(agent),
      if (off.isNotEmpty) ...[
        _GroupRow(
          key: const ValueKey('team-home-suspended-group'),
          icon: AppIconography.stopCircle,
          title: l10n.teamUiHomeSuspendedGroup(off.length),
          expanded: _suspendedExpanded,
          onTap: () => setState(() => _suspendedExpanded = !_suspendedExpanded),
        ),
        if (_suspendedExpanded)
          for (final agent in off) row(agent),
      ],
    ];
    return RefreshIndicator(
      key: const ValueKey('team-agents-pull'),
      onRefresh: _refresh,
      child: ListView(
        key: const ValueKey('team-home-agents'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 8, bottom: KitScreen.endPadding(context)),
        children: [
          // Stale rows dim; they stay readable (never colour-only).
          if (controller.isStale)
            Opacity(
              opacity: .6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}

/// A collapsible group heading row ("Suspended on the host (4)"): the
/// state lives in the row, the chevron says it opens.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    super.key,
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOf(Theme.of(context));
    return Semantics(
      button: true,
      expanded: expanded,
      child: KitRow(
        leading: KitRow.icon(context, icon),
        title: title,
        trailing: Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: Icon(
            expanded ? AppIconography.chevronUp : AppIconography.chevronDown,
            size: 20,
            color: muted,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
