/// The fleet row of 02-ux §5.1, shared by the AI Team home's Agents
/// segment and a run's Agents tab (§4.3):
///
/// ```
/// [glyph] fox · gastown.polecat · opencode / gpt-x       ● Working
///         Sync engine · ctx 63% · 12m ago
/// ```
///
/// Names, roles, providers and models are identifiers and stay LTR; the
/// state word carries its glyph so status is never colour-only (§11).
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'relative_time.dart';
import 'team_vocabulary.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// "ctx 63%" with the tone of [teamContextTone], for rows and headers.
class TeamContextNumber extends StatelessWidget {
  const TeamContextNumber({
    super.key,
    required this.percent,
    this.style,
    this.label,
  });

  final int percent;
  final TextStyle? style;

  /// Longer wording ("Context use 63%") for the detail header; the row
  /// uses the short form.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final tone = teamContextTone(percent);
    final color = tone == AppStatusTone.neutral
        ? AppTheme.mutedOf(theme)
        : AppTheme.statusColor(theme, tone);
    return Semantics(
      label: l10n.teamUiAgentContextSemantics(percent),
      excludeSemantics: true,
      child: Text(
        label ?? l10n.teamUiAgentContextShort(percent),
        style: (style ?? theme.textTheme.bodySmall)?.copyWith(
          color: color,
          fontWeight: tone == AppStatusTone.neutral ? null : FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// One agent of the fleet. [keyPrefix] names the row and its state text
/// (`<prefix>-<id>`, `<prefix>-state-<id>`) so each list keeps its keys.
class TeamAgentRow extends StatelessWidget {
  const TeamAgentRow({
    super.key,
    required this.agent,
    required this.work,
    required this.now,
    required this.onTap,
    this.keyPrefix = 'team-agent',
  });

  final OrchestrationAgent agent;
  final WorkItem? work;
  final DateTime now;
  final VoidCallback? onTap;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (icon, tone) = teamAgentGlyph(agent.state);
    final color = AppTheme.statusColor(theme, tone);
    final role = agent.pool ?? agent.pack;
    final runtime = [
      if (agent.provider case final provider? when provider.isNotEmpty)
        provider,
      if (agent.model case final model? when model.isNotEmpty) model,
    ].join(' / ');
    final identity = [
      if (role != null && role.isNotEmpty) role,
      if (runtime.isNotEmpty) runtime,
    ].join(' · ');
    final activity = agent.lastActivity == null
        ? null
        : relativeTimeLabel(
            agent.lastActivity!.millisecondsSinceEpoch,
            now: now,
            l10n: l10n,
          );
    final percent = agent.contextPercent;
    final stacked = AppTheme.stackedActions(context);
    final smallMuted = theme.textTheme.bodySmall?.copyWith(color: muted);
    final state = Text(
      teamAgentStateWord(l10n, agent.state),
      key: ValueKey('$keyPrefix-state-${agent.id}'),
      style: theme.textTheme.bodySmall?.copyWith(color: color),
    );
    return InkWell(
      key: ValueKey('$keyPrefix-${agent.id}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Agent names are identifiers: LTR in every locale.
                    Text(
                      agent.name,
                      style: theme.textTheme.bodyMedium,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (identity.isNotEmpty)
                      Text(
                        identity,
                        style: smallMuted,
                        textDirection: TextDirection.ltr,
                      ),
                    // Work · ctx · age: the current work first, the two
                    // numbers after it, on one line that wraps.
                    Wrap(
                      spacing: 0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          work?.title ?? l10n.teamUiHomeAgentNoWork,
                          style: smallMuted,
                        ),
                        if (percent != null) ...[
                          Text(' · ', style: smallMuted),
                          TeamContextNumber(
                            key: ValueKey('$keyPrefix-context-${agent.id}'),
                            percent: percent,
                          ),
                        ],
                        if (activity != null) ...[
                          Text(' · ', style: smallMuted),
                          Text(activity, style: smallMuted),
                        ],
                      ],
                    ),
                    if (stacked) ...[const SizedBox(height: 2), state],
                  ],
                ),
              ),
              if (!stacked) ...[const SizedBox(width: 12), state],
            ],
          ),
        ),
      ),
    );
  }
}
