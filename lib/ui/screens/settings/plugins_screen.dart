/// Settings › Plugins (TEAM-106): the discovery card, the Plugins group with
/// its single "AI Team · Gas City" row (subtitle per state, 02-ux §1.1) and
/// the AI Team sheet of 02-ux §9: status, host identity, live updates,
/// Technical details with the side-by-side terms (§8), the host
/// performance disclaimer (03-onboarding §4) and the actions Add manually /
/// Refresh / Turn off (§1.3).
///
/// For the Termux (managed) profile the sheet also carries the "On this
/// phone" section (TEAM-302, §9) and the page the one-time re-offer of the
/// skipped on-device step; both read [TermuxTeamRuntime] only.
///
/// Reads only [ConnectionController.orchestration] and the profile's
/// [OrchestrationConfig]; never touches the server gateway.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../state/connection.dart';
import '../../../state/orchestration.dart';
import '../../../state/profiles.dart';
import '../../../termux/bridge.dart';
import '../../../termux/team_runtime.dart';
import '../../app_theme.dart';
import '../../desktop/desktop_interaction.dart';
import '../../widgets/team_discovery_card.dart';
import '../../widgets/team_host_form.dart';
import '../../widgets/team_phone_section.dart';
import '../../widgets/team_technical_details.dart';

export '../../widgets/team_discovery_card.dart' show TeamDiscoveryCard;
export '../../widgets/team_technical_details.dart' show teamReadOnly;

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// True when [profile] is the app-managed Termux server on this phone: the
/// only profile that gets the "On this phone" section and the re-offer.
bool teamPhoneProfile(ServerProfile? profile) =>
    profile != null &&
    TermuxBridge.supported &&
    TermuxBridge.managesServerUrl(profile.baseUrl);

/// The Plugins page: discovery card, then the Plugins group.
class PluginsSettingsScreen extends StatefulWidget {
  const PluginsSettingsScreen({
    super.key,
    required this.controller,
    this.probe,
    this.now,
    this.teamRuntime,
  });

  final ConnectionController controller;

  /// Probe used by discovery and the manual-add form; tests pass a fake.
  final TeamHostProbe? probe;

  /// Clock for the "unreachable since N min" subtitle.
  final DateTime Function()? now;

  /// The on-device team runtime (TEAM-302); tests pass a fake.
  final TermuxTeamRuntime? teamRuntime;

  @override
  State<PluginsSettingsScreen> createState() => _PluginsSettingsScreenState();
}

class _PluginsSettingsScreenState extends State<PluginsSettingsScreen> {
  late final TeamDiscovery _discovery = TeamDiscovery(
    widget.controller,
    probe: widget.probe,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _discovery.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _discovery.removeListener(_changed);
    _discovery.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _openSheet() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TeamPluginSheet(
      controller: widget.controller,
      discovery: _discovery,
      probe: widget.probe,
      now: widget.now,
      teamRuntime: widget.teamRuntime,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final controller = widget.controller;
    final profile = controller.profile;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.teamUiPluginsTitle)),
      body: DesktopScrollbarArea(
        builder: (scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            TeamDiscoveryCard(
              controller: controller,
              discovery: _discovery,
              probe: widget.probe,
            ),
            if (teamPhoneProfile(profile))
              TeamPhoneReofferCard(
                connection: controller,
                profile: profile!,
                runtime: widget.teamRuntime,
              ),
            if (profile == null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
                child: Text(
                  l10n.teamUiNoServer,
                  key: const ValueKey('plugins-no-server'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedOf(theme),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: Text(
                  l10n.teamUiPluginsTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.mutedOf(theme),
                  ),
                ),
              ),
              ListTile(
                key: const ValueKey('plugins-ai-team-row'),
                minTileHeight: 72,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                minLeadingWidth: 32,
                horizontalTitleGap: 12,
                leading: SizedBox.square(
                  dimension: 32,
                  child: Icon(
                    AppIconography.extensions,
                    size: 24,
                    color: AppTheme.mutedOf(theme),
                  ),
                ),
                title: Text(l10n.teamUiRowTitle),
                subtitle: Text(
                  teamRowSubtitle(
                    l10n,
                    profile: profile,
                    orchestration: controller.orchestration,
                    discovery: _discovery,
                    now: widget.now?.call() ?? DateTime.now(),
                  ),
                  key: const ValueKey('plugins-ai-team-subtitle'),
                ),
                trailing: const Icon(AppIconography.chevronRight, size: 20),
                onTap: _openSheet,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The reason an [OrchestrationErrorKind] gives the row, lower-case so it
/// reads after "Not available on this server ·".
String teamErrorReason(AppLocalizations l10n, OrchestrationErrorKind kind) =>
    switch (kind) {
      OrchestrationErrorKind.notGasCity => l10n.teamUiReasonNotGasCity,
      OrchestrationErrorKind.cityNotRunning => l10n.teamUiReasonCityNotRunning,
      OrchestrationErrorKind.plainHttpRefused => l10n.teamUiReasonPlainHttp,
      OrchestrationErrorKind.unreachable => l10n.teamUiReasonUnreachable,
      OrchestrationErrorKind.readFailed => l10n.teamUiReasonReadFailed,
    };

/// The row subtitle for every state of 02-ux §1.1.
String teamRowSubtitle(
  AppLocalizations l10n, {
  required ServerProfile profile,
  required OrchestrationController? orchestration,
  required TeamDiscovery? discovery,
  required DateTime now,
}) {
  final config = profile.orchestration;
  if (config == null) {
    final found = discovery?.result;
    if (found != null) {
      return l10n.teamUiRowFound(
        profile.name,
        found.found.version ?? l10n.teamUiVersionUnknown,
      );
    }
    return discovery?.probed == true
        ? l10n.teamUiRowOffAddManually
        : l10n.teamUiRowOff;
  }
  final c = orchestration;
  if (c == null || c.profileId != profile.id) {
    return l10n.teamUiRowOn(profile.name);
  }
  switch (c.phase) {
    case OrchestrationPhase.idle:
    case OrchestrationPhase.probing:
    case OrchestrationPhase.connecting:
      return l10n.teamUiRowConnecting;
    case OrchestrationPhase.failed:
      final error = c.lastError;
      return error == null
          ? l10n.teamUiRowNotAvailable
          : l10n.teamUiRowNotAvailableReason(teamErrorReason(l10n, error.kind));
    case OrchestrationPhase.stopped:
      return l10n.teamUiRowOn(profile.name);
    case OrchestrationPhase.ready:
      switch (c.streamStatus) {
        case OrchestrationStreamStatus.connecting:
        case OrchestrationStreamStatus.reconnecting:
          final since = c.lastEventAt ?? c.lastRefreshedAt;
          if (since != null &&
              now.difference(since) >= const Duration(minutes: 1)) {
            return l10n.teamUiRowUnreachable(
              now.difference(since).inMinutes.toString(),
            );
          }
          return l10n.teamUiRowReconnecting;
        case OrchestrationStreamStatus.closed:
        case OrchestrationStreamStatus.live:
          return teamReadOnly(config, c)
              ? l10n.teamUiRowOnReadOnly(profile.name)
              : l10n.teamUiRowOn(profile.name);
      }
  }
}

/// The AI Team sheet of 02-ux §9. Listens to the connection so status and
/// stream lines follow the controller live.
class TeamPluginSheet extends StatefulWidget {
  const TeamPluginSheet({
    super.key,
    required this.controller,
    this.discovery,
    this.probe,
    this.now,
    this.teamRuntime,
  });

  final ConnectionController controller;
  final TeamDiscovery? discovery;
  final TeamHostProbe? probe;
  final DateTime Function()? now;

  /// The on-device team runtime (TEAM-302); tests pass a fake.
  final TermuxTeamRuntime? teamRuntime;

  @override
  State<TeamPluginSheet> createState() => _TeamPluginSheetState();
}

class _TeamPluginSheetState extends State<TeamPluginSheet> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.discovery?.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.discovery?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _addManually() async {
    final profile = widget.controller.profile;
    if (profile == null) return;
    final existing = profile.orchestration;
    final config = await showTeamHostSheet(
      context,
      initialUrl:
          existing?.url ??
          widget.discovery?.result?.url ??
          teamDiscoveryUrlFor(profile.baseUrl) ??
          '',
      initialCity: existing?.city ?? '',
      initialHostKind: existing?.hostKind,
      probe: widget.probe,
    );
    if (config == null || !mounted) return;
    await _save(profile, config);
  }

  Future<void> _save(ServerProfile profile, OrchestrationConfig config) async {
    final l10n = _copy(context);
    setState(() => _busy = true);
    try {
      final current = widget.controller.orchestration;
      if (current != null && current.profileId == profile.id) {
        // A changed host: drop the old host's cache before the new one
        // writes its own.
        await current.remove();
      }
      profile.orchestration = config;
      await widget.controller.store.upsert(profile);
      widget.controller.syncOrchestration();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10n.teamUiSavedOn(profile.name))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOff() async {
    final profile = widget.controller.profile;
    if (profile == null) return;
    final confirmed = await showTeamTurnOffSheet(context, profile.name);
    if (!confirmed || !mounted) return;
    final l10n = _copy(context);
    setState(() => _busy = true);
    try {
      final controller = widget.controller;
      final current = controller.orchestration;
      var failed = const <String>{};
      if (current != null && current.profileId == profile.id) {
        failed = await current.remove();
      } else {
        failed = await controller.orchestrationStore.sweep(profile.id);
      }
      profile.orchestration = null;
      await controller.store.upsert(profile);
      // §1.3: the probe offer is not re-shown for 30 days; written before
      // the sync so the re-check after it sees the dismissal.
      await controller.orchestrationStore.dismissDiscovery(profile.id);
      controller.syncOrchestration();
      if (!mounted) return;
      if (failed.isNotEmpty) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(l10n.teamUiTurnOffFailed)));
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final c = widget.controller.orchestration;
    if (c == null) return;
    setState(() => _busy = true);
    try {
      await c.refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOn() async {
    final discovery = widget.discovery;
    if (discovery == null) return;
    setState(() => _busy = true);
    try {
      await discovery.turnOn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final controller = widget.controller;
    final profile = controller.profile;
    final config = profile?.orchestration;
    final c = controller.orchestration;
    final live = c != null && profile != null && c.profileId == profile.id
        ? c
        : null;
    final host = live?.host;
    final found = widget.discovery?.result;
    final on = config != null;
    final readOnly = config != null && teamReadOnly(config, live);
    final hostMode = config?.hostMode ?? found?.found.host.hostMode;
    final hostKind = hostMode == null
        ? null
        : teamHostKindFor(config, host?.hostMode ?? hostMode);

    final (statusTone, statusLine) = _status(l10n, config, live);
    final version =
        host?.version ??
        found?.found.version ??
        (on ? l10n.teamUiVersionUnknown : null);

    return SingleChildScrollView(
      key: const ValueKey('team-plugin-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.teamUiRowTitle, style: theme.textTheme.titleLarge),
          if (profile != null && version != null) ...[
            const SizedBox(height: 2),
            Text(
              '${profile.name} · $version',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedOf(theme),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Status: a dot and a word, never colour-only.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  AppIconography.statusDot,
                  size: 14,
                  color: AppTheme.statusColor(theme, statusTone),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLine,
                      key: const ValueKey('team-sheet-status'),
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      on ? l10n.teamUiStatusOn : l10n.teamUiStatusOff,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedOf(theme),
                      ),
                    ),
                    if (on)
                      Text(
                        readOnly
                            ? l10n.teamUiWatchingOnly
                            : l10n.teamUiWatchingAndAnswering,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (live != null && live.phase == OrchestrationPhase.ready) ...[
            const SizedBox(height: 8),
            Text(
              _streamLine(l10n, live),
              key: const ValueKey('team-sheet-stream'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedOf(theme),
              ),
            ),
          ],
          if (on || found != null) ...[
            const SizedBox(height: 16),
            TeamIdentityRow(
              label: l10n.teamUiLabelProvider,
              value: host?.provider ?? found?.found.host.provider ?? 'gascity',
            ),
            TeamIdentityRow(
              label: l10n.teamUiLabelVersion,
              value: version ?? l10n.teamUiVersionUnknown,
            ),
            TeamIdentityRow(
              label: l10n.teamUiLabelCity,
              value: (config?.city.isNotEmpty ?? false)
                  ? config!.city
                  : (host?.city ?? found?.found.city ?? '—'),
            ),
            TeamIdentityRow(
              label: l10n.teamUiLabelAddress,
              value: config?.url ?? found?.url ?? '',
              mono: true,
            ),
            TeamIdentityRow(
              label: l10n.teamUiLabelHost,
              value: switch (hostKind ?? OrchestrationHostKind.pc) {
                OrchestrationHostKind.pc => l10n.teamUiHostModeComputer,
                OrchestrationHostKind.laptop => l10n.teamUiHostKindLaptop,
                OrchestrationHostKind.wsl => l10n.teamUiHostKindWsl,
                OrchestrationHostKind.phone => l10n.teamUiHostModePhone,
              },
            ),
            TeamIdentityRow(
              label: l10n.teamUiLabelAccess,
              value: (on ? readOnly : found?.found.readOnly ?? true)
                  ? l10n.teamUiAccessReadOnly
                  : l10n.teamUiAccessControls,
            ),
            if (on && readOnly) ...[
              const SizedBox(height: 8),
              Text(
                l10n.teamUiReadOnlyBody,
                key: const ValueKey('team-sheet-read-only'),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              Text(
                l10n.teamUiFrontLine,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedOf(theme),
                  height: 1.35,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('team-sheet-how'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => showTeamHostGuideSheet(context),
                  child: Text(l10n.teamUiHow),
                ),
              ),
            ],
            if (hostKind != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AppIconography.info,
                    size: 16,
                    color: AppTheme.mutedOf(theme),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      teamHostDisclaimer(l10n, hostKind),
                      key: const ValueKey('team-sheet-disclaimer'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedOf(theme),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('team-sheet-technical'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(
                  l10n.teamUiTechnicalDetails,
                  style: theme.textTheme.titleSmall,
                ),
                children: [
                  TeamTechnicalValue(
                    label: l10n.teamUiLabelProvider,
                    value: host?.provider ?? found?.found.host.provider ?? '',
                  ),
                  TeamTechnicalValue(
                    label: l10n.teamUiLabelAddress,
                    value: config?.url ?? found?.url ?? '',
                  ),
                  TeamTechnicalValue(
                    label: l10n.teamUiLabelCity,
                    value: config?.city ?? found?.found.city ?? '',
                  ),
                  if (live?.lastError case final error?)
                    TeamTechnicalValue(
                      label: l10n.teamUiTechnicalLastAnswer,
                      value: error.message,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                    child: Text(
                      l10n.teamUiTermsHeading,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.mutedOf(theme),
                      ),
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
            ),
          ],
          if (teamPhoneProfile(profile)) ...[
            const SizedBox(height: 16),
            TeamPhoneSection(
              connection: controller,
              profile: profile!,
              runtime: widget.teamRuntime,
              onRemoved: () {
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
          const SizedBox(height: 12),
          if (!on && found != null)
            FilledButton(
              key: const ValueKey('team-sheet-turn-on'),
              onPressed: _busy ? null : _turnOn,
              child: Text(l10n.teamUiDiscoveryTurnOn),
            ),
          if (on) ...[
            FilledButton.tonalIcon(
              key: const ValueKey('team-sheet-refresh'),
              onPressed: _busy || live == null ? null : _refresh,
              icon: const Icon(AppIconography.retry),
              label: Text(l10n.teamUiRefresh),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton(
            key: const ValueKey('team-sheet-add-manually'),
            onPressed: _busy || profile == null ? null : _addManually,
            child: Text(on ? l10n.teamUiChange : l10n.teamUiAddManually),
          ),
          if (on) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('team-sheet-turn-off'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: _busy ? null : _turnOff,
              child: Text(l10n.teamUiTurnOff),
            ),
          ],
        ],
      ),
    );
  }

  (AppStatusTone, String) _status(
    AppLocalizations l10n,
    OrchestrationConfig? config,
    OrchestrationController? live,
  ) {
    if (config == null) return (AppStatusTone.neutral, l10n.teamUiStatusOff);
    if (live == null) return (AppStatusTone.neutral, l10n.teamUiStatusOn);
    switch (live.phase) {
      case OrchestrationPhase.idle:
      case OrchestrationPhase.probing:
      case OrchestrationPhase.connecting:
        return (AppStatusTone.progress, l10n.teamUiStatusProbing);
      case OrchestrationPhase.failed:
        final error = live.lastError;
        return (
          AppStatusTone.attention,
          error == null
              ? l10n.teamUiStatusNotAvailable
              : l10n.teamUiRowNotAvailableReason(
                  teamErrorReason(l10n, error.kind),
                ),
        );
      case OrchestrationPhase.stopped:
        return (AppStatusTone.neutral, l10n.teamUiStatusOn);
      case OrchestrationPhase.ready:
        switch (live.streamStatus) {
          case OrchestrationStreamStatus.connecting:
            return (AppStatusTone.progress, l10n.teamUiStatusReconnecting);
          case OrchestrationStreamStatus.reconnecting:
            return (AppStatusTone.attention, l10n.teamUiStatusUnreachable);
          case OrchestrationStreamStatus.live:
          case OrchestrationStreamStatus.closed:
            return (AppStatusTone.ok, l10n.teamUiStatusConnected);
        }
    }
  }

  String _streamLine(AppLocalizations l10n, OrchestrationController live) {
    switch (live.streamStatus) {
      case OrchestrationStreamStatus.connecting:
        return l10n.teamUiEventStreamConnecting;
      case OrchestrationStreamStatus.reconnecting:
        return l10n.teamUiEventStreamReconnecting;
      case OrchestrationStreamStatus.closed:
        return l10n.teamUiEventStreamClosed;
      case OrchestrationStreamStatus.live:
        final seq = live.cursor.seq;
        return seq == null
            ? l10n.teamUiEventStreamLiveNoSeq
            : l10n.teamUiEventStreamLive(seq.toString());
    }
  }
}
