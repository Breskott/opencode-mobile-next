/// The AI Team plugin's identity and Technical details pieces (02-ux §8):
/// label-over-value identity rows, raw provider values with a copy button
/// and the side-by-side term rows, shared by the Settings sheet (TEAM-106)
/// and the host chip on the AI Team home (TEAM-108), which opens
/// [TeamHostDetailsSheet].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../state/orchestration.dart';
import '../../state/profiles.dart';
import '../app_theme.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Whether the phone can only watch: no front on the host and no control
/// capability from the adapter.
bool teamReadOnly(OrchestrationConfig config, OrchestrationController? c) =>
    !(config.front || (c?.capabilities.controlRespond ?? false));

/// Opens the host's Technical details as a bottom sheet.
Future<void> showTeamHostDetailsSheet(
  BuildContext context,
  OrchestrationController controller,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => TeamHostDetailsSheet(controller: controller),
);

/// The host chip's sheet: who the host is (provider, version, city,
/// address, where it runs, access), the raw values with copy buttons and
/// the product-to-provider terms. Read-only; the switches live in
/// Settings › Plugins.
class TeamHostDetailsSheet extends StatelessWidget {
  const TeamHostDetailsSheet({super.key, required this.controller});

  final OrchestrationController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final config = controller.config;
    final host = controller.host;
    final hostMode = host?.hostMode ?? config.hostMode;
    final city = config.city.isNotEmpty ? config.city : (host?.city ?? '');
    final readOnly = teamReadOnly(config, controller);
    final provider = host?.provider ?? config.provider.name;
    return SingleChildScrollView(
      key: const ValueKey('team-home-host-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.teamUiTechnicalDetails, style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            l10n.teamUiRowTitle,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 12),
          TeamIdentityRow(label: l10n.teamUiLabelProvider, value: provider),
          TeamIdentityRow(
            label: l10n.teamUiLabelVersion,
            value: host?.version ?? l10n.teamUiVersionUnknown,
          ),
          TeamIdentityRow(
            label: l10n.teamUiLabelCity,
            value: city.isEmpty ? '—' : city,
          ),
          TeamIdentityRow(
            label: l10n.teamUiLabelAddress,
            value: host?.url ?? config.url,
            mono: true,
          ),
          TeamIdentityRow(
            label: l10n.teamUiLabelHost,
            value: switch (hostMode) {
              OrchestrationHostMode.computer => l10n.teamUiHostModeComputer,
              OrchestrationHostMode.phone => l10n.teamUiHostModePhone,
            },
          ),
          TeamIdentityRow(
            label: l10n.teamUiLabelAccess,
            value: readOnly
                ? l10n.teamUiAccessReadOnly
                : l10n.teamUiAccessControls,
          ),
          if (readOnly) ...[
            const SizedBox(height: 8),
            Text(
              l10n.teamUiReadOnlyBody,
              key: const ValueKey('team-home-host-read-only'),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.teamUiHomeHostRawHeading,
            style: theme.textTheme.labelLarge?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          TeamTechnicalValue(label: l10n.teamUiLabelProvider, value: provider),
          TeamTechnicalValue(
            label: l10n.teamUiLabelAddress,
            value: host?.url ?? config.url,
          ),
          TeamTechnicalValue(label: l10n.teamUiLabelCity, value: city),
          if (controller.lastError case final error?)
            TeamTechnicalValue(
              label: l10n.teamUiTechnicalLastAnswer,
              value: error.message,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
            child: Text(
              l10n.teamUiTermsHeading,
              style: theme.textTheme.labelLarge?.copyWith(color: muted),
            ),
          ),
          for (final term in [
            l10n.teamUiTermTeam,
            l10n.teamUiTermProject,
            l10n.teamUiTermRun,
            l10n.teamUiTermWork,
            l10n.teamUiTermAgent,
          ])
            TeamTermRow(term),
        ],
      ),
    );
  }
}

/// Label above value so the pair still fits at 320dp × 2.5x; ids and URLs
/// stay LTR in RTL layouts.
class TeamIdentityRow extends StatelessWidget {
  const TeamIdentityRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedOf(theme),
            ),
          ),
          Text(
            value,
            textDirection: mono ? TextDirection.ltr : null,
            style: mono
                ? const TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: AppTheme.codeFontSize,
                  )
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// A raw provider value with a copy button (02-ux §8).
class TeamTechnicalValue extends StatelessWidget {
  const TeamTechnicalValue({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = _copy(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedOf(theme),
                ),
              ),
              SelectableText(
                value.isEmpty ? '—' : value,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: AppTheme.codeFontSize,
                ),
              ),
            ],
          ),
        ),
        if (value.isNotEmpty)
          IconButton(
            tooltip: l10n.teamUiCopy,
            iconSize: 18,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(l10n.teamUiCopied),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(AppIconography.copy),
          ),
      ],
    );
  }
}

/// "Product · provider" term pair; the product word leads, the Gas City
/// term follows in the muted colour.
class TeamTermRow extends StatelessWidget {
  const TeamTermRow(this.term, {super.key});

  final String term;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = term.split(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: parts.first, style: theme.textTheme.bodyMedium),
            if (parts.length > 1)
              TextSpan(
                text: ' · ${parts.sublist(1).join(' · ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedOf(theme),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
