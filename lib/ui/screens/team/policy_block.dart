/// The host's supervision policy on the phone (TEAM-207; 02-ux §7 and
/// §4.1): a read-only "Supervision · Balanced" line with the host's
/// boundaries as chips, appended under the run's state header, and the
/// same boundaries as the Start-a-run sheet's **Boundaries** row. Both
/// render from [OrchestrationController.policy] and are absent (not
/// hidden: no widget in the tree) while the controller has none — a bare
/// supervisor, the fixture, or a front without the route.
///
/// Nothing here is editable: the level and the boundaries are the host
/// owner's config (`<state-dir>/rigs/<rig>.json`), and the helper line
/// says so.
library;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_theme.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The localised name of a host-reported supervision level; the same words
/// as the Start-a-run choices.
String teamPolicySupervisionName(
  AppLocalizations l10n,
  OrchestrationSupervision level,
) => switch (level) {
  OrchestrationSupervision.high => l10n.teamUiStartRunSupervisionHigh,
  OrchestrationSupervision.balanced => l10n.teamUiStartRunSupervisionBalanced,
  OrchestrationSupervision.autonomous =>
    l10n.teamUiStartRunSupervisionAutonomous,
};

/// The run overview's policy block: supervision line, boundary chips, and
/// the "set on the host" helper.
class TeamPolicyBlock extends StatelessWidget {
  const TeamPolicyBlock({super.key, required this.policy});

  final OrchestrationPolicy policy;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final level = teamPolicySupervisionName(l10n, policy.supervision);
    final rig = policy.rig;
    return Semantics(
      container: true,
      label: l10n.teamUiPolicySemantics(
        level,
        policy.boundaries.isEmpty
            ? l10n.teamUiPolicyBoundariesNone
            : policy.boundaries.map((b) => b.text).join(', '),
      ),
      child: Column(
        key: const ValueKey('team-run-policy'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIconography.policy, size: 16, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.teamUiPolicySupervision(level),
                      key: const ValueKey('team-run-policy-supervision'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (rig != null && rig.isNotEmpty)
                      Text(
                        l10n.teamUiPolicyRig(rig),
                        key: const ValueKey('team-run-policy-rig'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TeamBoundaryChips(
            key: const ValueKey('team-run-policy-boundaries'),
            boundaries: policy.boundaries,
            keyPrefix: 'team-run-policy-boundary',
          ),
          const SizedBox(height: 4),
          Text(
            l10n.teamUiPolicyFromHost,
            key: const ValueKey('team-run-policy-from-host'),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

/// The boundaries as read-only chips, or the "none set" line.
class TeamBoundaryChips extends StatelessWidget {
  const TeamBoundaryChips({
    super.key,
    required this.boundaries,
    required this.keyPrefix,
  });

  final List<PolicyBoundary> boundaries;

  /// Each chip is keyed `<keyPrefix>-<boundary key>`.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    if (boundaries.isEmpty) {
      return Text(
        l10n.teamUiPolicyBoundariesNone,
        key: ValueKey('$keyPrefix-none'),
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final boundary in boundaries)
          Chip(
            key: ValueKey('$keyPrefix-${boundary.key}'),
            avatar: Icon(AppIconography.shield, size: 14, color: muted),
            label: Text(boundary.text),
            labelStyle: theme.textTheme.bodySmall,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
      ],
    );
  }
}

/// The Start-a-run sheet's **Boundaries** row (02-ux §7): the label, the
/// chips and the read-only helper.
class TeamBoundariesRow extends StatelessWidget {
  const TeamBoundariesRow({super.key, required this.policy});

  final OrchestrationPolicy policy;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    return Column(
      key: const ValueKey('team-start-run-boundaries'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.teamUiPolicyBoundariesLabel,
          style: theme.textTheme.labelLarge?.copyWith(color: muted),
        ),
        const SizedBox(height: 6),
        TeamBoundaryChips(
          boundaries: policy.boundaries,
          keyPrefix: 'team-start-run-boundary',
        ),
        const SizedBox(height: 4),
        Text(
          l10n.teamUiPolicyFromHost,
          key: const ValueKey('team-start-run-boundaries-from-host'),
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}
