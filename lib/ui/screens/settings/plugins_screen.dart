/// Settings › Plugins (TEAM-106): the discovery card, the Plugins group with
/// its single "AI Team" row (subtitle per state, 02-ux §1.1; "Off" or
/// "On · This phone", docs/design/phone-server-screens-cleanup-2026-09-24.md
/// §3) and
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
///
/// Built from kit parts only (screen-library-3, kit-v2 §9).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../state/connection.dart';
import '../../../state/orchestration.dart';
import '../../../state/profiles.dart';
import '../../../termux/bridge.dart';
import '../../../termux/team_runtime.dart';
import '../../../builtin/builtin_server.dart' show looksLikeInAppServer;
import '../../../builtin/team/builtin_team.dart' show BuiltinTeam;
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/builtin_team_section.dart';
import '../../widgets/team_discover.dart' show teamStateLine;
import '../../widgets/team_discovery_card.dart';
import '../../widgets/team_host_form.dart';
import '../../widgets/team_phone_section.dart';
import '../../widgets/team_technical_details.dart';
import 'server_plugins_section.dart';

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

/// The one Plugins page. "In this app" holds the plugins this app ships
/// (AI Team · Gas City, with its discovery card); "On the server" holds the
/// connected server's plugin inventory and only exists when the server has
/// one.
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

  /// The "On the server" section's refresh, offered by this page's top
  /// bar.
  final ServerPluginsActions _serverActions = ServerPluginsActions();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _discovery.addListener(_changed);
    _serverActions.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _discovery.removeListener(_changed);
    _serverActions
      ..removeListener(_changed)
      ..dispose();
    _discovery.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  // revamp: merge-into:team-home (slice-P3.4). Until the one AI Team page
  // takes this sheet over, the row opens it here.
  Future<void> _openSheet() => showKitSheet<void>(
    context,
    title: _copy(context).teamUiRowTitle,
    icon: AppIconography.extensions,
    height: KitSheetHeight.full,
    body: (_) => TeamPluginSheet(
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
    final tokens = KitTokens.of(context);
    final controller = widget.controller;
    final profile = controller.profile;
    Widget rails(Widget child) => Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
      child: child,
    );
    // One AI Team per page, in one state (the owner, build 2054: "why
    // repeat gas city on the plugin page?"). On OpenCode inside the app the
    // phone's card IS the AI Team; connecting a computer's team instead is
    // a secondary choice under it, and once the phone's team is on, the
    // same sheet holds its technical details. The "In this app" row stays
    // for every other server, and for a computer's team connected here.
    final phoneHosts = BuiltinTeamSection.appliesTo(profile);
    final config = profile?.orchestration;
    final phoneTeamOn = BuiltinTeam.isBuiltinConfig(config);
    final phoneIsTheTeam = phoneHosts && (config == null || phoneTeamOn);
    final serverPlugins = controller.capabilities.pluginInventory;
    final refresh = serverPlugins ? _serverActions.refresh : null;
    return KitScreen(
      topBar: KitTopBar(
        title: l10n.teamUiPluginsTitle,
        actions: [
          if (serverPlugins)
            KitAction(
              key: const ValueKey('plugins-refresh'),
              label: l10n.pluginsRefresh,
              icon: AppIconography.retry,
              onPressed: refresh,
            ),
        ],
      ),
      width: KitScreenWidth.reading,
      body: KitScrollArea(
        builder: (scrollController) => ListView(
          controller: scrollController,
          padding: EdgeInsetsDirectional.only(
            top: tokens.space2,
            bottom: KitScreen.endPadding(context),
          ),
          children: [
            rails(
              TeamDiscoveryCard(
                controller: controller,
                discovery: _discovery,
                probe: widget.probe,
              ),
            ),
            if (phoneHosts)
              rails(
                BuiltinTeamSection(connection: controller, profile: profile!),
              ),
            if (phoneIsTheTeam)
              KitRowGroup(
                margin: EdgeInsetsDirectional.only(
                  start: tokens.gutter,
                  end: tokens.gutter,
                  bottom: tokens.sectionGap,
                ),
                children: [
                  KitRow(
                    key: const ValueKey('plugins-team-other'),
                    leading: KitRow.icon(
                      context,
                      phoneTeamOn
                          ? AppIconography.info
                          : AppIconography.computer,
                    ),
                    title: phoneTeamOn
                        ? l10n.teamUiTechnicalDetails
                        : l10n.teamDiscoverComputerChoiceTitle,
                    supporting: phoneTeamOn
                        ? null
                        : TextSpan(text: l10n.teamDiscoverComputerChoiceBody),
                    supportingMaxLines: 2,
                    trailing: const KitChevron(),
                    onTap: _openSheet,
                  ),
                ],
              ),
            if (profile == null)
              // Plugins belong to a server: say so, with nothing to tap
              // (map: whenMissing server.any explains).
              rails(
                KitNotice(
                  key: const ValueKey('plugins-no-server'),
                  icon: AppIconography.extensions,
                  message: l10n.teamUiNoServer,
                ),
              )
            else if (!phoneIsTheTeam)
              // One row: its name, and whether it is on and where. Gas
              // City, the host and "Add manually" are on its own page.
              KitRowGroup(
                key: const ValueKey('plugins-section-app'),
                label: l10n.pluginsSectionInApp,
                margin: EdgeInsetsDirectional.only(
                  start: tokens.gutter,
                  end: tokens.gutter,
                  bottom: tokens.sectionGap,
                ),
                children: [
                  KitRow(
                    key: const ValueKey('plugins-ai-team-row'),
                    leading: KitRow.icon(context, AppIconography.extensions),
                    title: l10n.pluginsTeamRowTitle,
                    supporting: TextSpan(
                      text: teamStateLine(
                        l10n,
                        controller,
                        discovery: _discovery,
                        now: widget.now?.call() ?? DateTime.now(),
                      ),
                    ),
                    supportingKey: const ValueKey('plugins-ai-team-subtitle'),
                    supportingMaxLines: 2,
                    trailing: const KitChevron(),
                    onTap: _openSheet,
                  ),
                ],
              ),
            if (controller.capabilities.pluginInventory)
              ServerPluginsSection(
                controller: controller,
                actions: _serverActions,
              ),
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
  // The server by the name a person knows it: "This phone" for the one on
  // this phone, not the name it was saved under.
  final server = teamPhoneProfile(profile) || looksLikeInAppServer(profile)
      ? l10n.phoneServerCardTitle
      : profile.name;
  if (config == null) {
    // "Off", or where a team was found. The engine's name, its version
    // and "Add manually" are on the AI Team page, not in the row.
    final found = discovery?.result;
    if (found != null) return l10n.pluginsTeamRowFound(server);
    return l10n.teamUiRowOff;
  }
  final c = orchestration;
  if (c == null || c.profileId != profile.id) {
    return l10n.teamUiRowOn(server);
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
      return l10n.teamUiRowOn(server);
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
              ? l10n.teamUiRowOnReadOnly(server)
              : l10n.teamUiRowOn(server);
      }
  }
}

/// The AI Team sheet of 02-ux §9: the body of the [showKitSheet] the
/// Plugins row opens. Listens to the connection so status and stream lines
/// follow the controller live.
// revamp: merge-into:team-home (slice-P3.4)
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

  /// The result of the last write, shown in place (K2 §4.8): saved, or
  /// turned off with cache left behind.
  (AppStatusTone, String)? _notice;

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
    setState(() {
      _busy = true;
      _notice = null;
    });
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
      setState(
        () => _notice = (AppStatusTone.ok, l10n.teamUiSavedOn(profile.name)),
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
    setState(() {
      _busy = true;
      _notice = null;
    });
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
        // The sheet stays open to say what was left behind.
        setState(
          () => _notice = (AppStatusTone.failure, l10n.teamUiTurnOffFailed),
        );
        return;
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
    final tokens = KitTokens.of(context);
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

    final (statusMark, statusLine) = _status(l10n, config, live);
    final onOffLine = on ? l10n.teamUiStatusOn : l10n.teamUiStatusOff;
    final version =
        host?.version ??
        found?.found.version ??
        (on ? l10n.teamUiVersionUnknown : null);
    final gap = SizedBox(height: tokens.space3);
    final statusDetail = [
      if (onOffLine != statusLine) onOffLine,
      if (on)
        readOnly ? l10n.teamUiWatchingOnly : l10n.teamUiWatchingAndAnswering,
    ].join(' · ');

    final notice = _notice;
    return Column(
      key: const ValueKey('team-plugin-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profile != null && version != null)
          KitText(
            '${profile.name} · $version',
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
          ),
        if (notice != null) ...[
          gap,
          KitNotice(tone: notice.$1, message: notice.$2),
        ],
        gap,
        // Status: a mark and a word, never colour-only. "Off" is said once.
        KitRow(
          padding: EdgeInsets.zero,
          leading: KitStatusMark(state: statusMark),
          title: statusLine,
          titleKey: const ValueKey('team-sheet-status'),
          titleMaxLines: 2,
          supporting: statusDetail.isEmpty
              ? null
              : TextSpan(text: statusDetail),
          supportingMaxLines: 3,
        ),
        if (live != null && live.phase == OrchestrationPhase.ready)
          KitText(
            _streamLine(l10n, live),
            key: const ValueKey('team-sheet-stream'),
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
          ),
        if (on || found != null) ...[
          SizedBox(height: tokens.space4),
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
            gap,
            KitNotice(
              key: const ValueKey('team-sheet-read-only'),
              message: l10n.teamUiReadOnlyBody,
              notes: [l10n.teamUiFrontLine],
              actions: [
                KitAction(
                  key: const ValueKey('team-sheet-how'),
                  label: l10n.teamUiHow,
                  onPressed: () => showTeamHostGuideSheet(context),
                ),
              ],
            ),
          ],
          if (hostKind != null) ...[
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KitIcon(
                  AppIconography.info,
                  size: KitIconSize.small,
                  tone: KitTextTone.secondary,
                ),
                SizedBox(width: tokens.space2),
                Expanded(
                  child: KitText(
                    teamHostDisclaimer(l10n, hostKind),
                    key: const ValueKey('team-sheet-disclaimer'),
                    role: KitTextRole.secondary,
                    tone: KitTextTone.secondary,
                  ),
                ),
              ],
            ),
          ],
        ],
        if (teamPhoneProfile(profile)) ...[
          SizedBox(height: tokens.space4),
          TeamPhoneSection(
            connection: controller,
            profile: profile!,
            runtime: widget.teamRuntime,
            onRemoved: () {
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
        SizedBox(height: tokens.space5),
        KitActionBlock(
          primary: !on && found != null
              ? KitAction(
                  key: const ValueKey('team-sheet-turn-on'),
                  label: l10n.teamUiDiscoveryTurnOn,
                  working: _busy,
                  onPressed: _busy ? null : _turnOn,
                )
              : null,
          secondary: KitAction(
            key: const ValueKey('team-sheet-add-manually'),
            label: on ? l10n.teamUiChange : l10n.teamUiAddManually,
            onPressed: _busy || profile == null ? null : _addManually,
          ),
          tertiary: [
            if (on) ...[
              KitAction(
                key: const ValueKey('team-sheet-refresh'),
                label: l10n.teamUiRefresh,
                icon: AppIconography.retry,
                onPressed: _busy || live == null ? null : _refresh,
              ),
              KitAction(
                key: const ValueKey('team-sheet-turn-off'),
                label: l10n.teamUiTurnOff,
                destructive: true,
                onPressed: _busy ? null : _turnOff,
              ),
            ],
          ],
        ),
        if (on || found != null) ...[
          SizedBox(height: tokens.space4),
          // The one technical fold, last and collapsed (K2 §4.3).
          KitDetailsFold(
            foldKey: const ValueKey('team-sheet-technical'),
            label: l10n.teamUiTechnicalDetails,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  padding: EdgeInsetsDirectional.only(
                    top: tokens.space2,
                    bottom: tokens.space1,
                  ),
                  child: KitText(
                    l10n.teamUiTermsHeading,
                    role: KitTextRole.label,
                    tone: KitTextTone.secondary,
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
      ],
    );
  }

  (KitMarkState, String) _status(
    AppLocalizations l10n,
    OrchestrationConfig? config,
    OrchestrationController? live,
  ) {
    if (config == null) return (KitMarkState.waiting, l10n.teamUiStatusOff);
    if (live == null) return (KitMarkState.waiting, l10n.teamUiStatusOn);
    switch (live.phase) {
      case OrchestrationPhase.idle:
      case OrchestrationPhase.probing:
      case OrchestrationPhase.connecting:
        return (KitMarkState.working, l10n.teamUiStatusProbing);
      case OrchestrationPhase.failed:
        final error = live.lastError;
        return (
          KitMarkState.failed,
          error == null
              ? l10n.teamUiStatusNotAvailable
              : l10n.teamUiRowNotAvailableReason(
                  teamErrorReason(l10n, error.kind),
                ),
        );
      case OrchestrationPhase.stopped:
        return (KitMarkState.waiting, l10n.teamUiStatusOn);
      case OrchestrationPhase.ready:
        switch (live.streamStatus) {
          case OrchestrationStreamStatus.connecting:
            return (KitMarkState.working, l10n.teamUiStatusReconnecting);
          case OrchestrationStreamStatus.reconnecting:
            return (KitMarkState.failed, l10n.teamUiStatusUnreachable);
          case OrchestrationStreamStatus.live:
          case OrchestrationStreamStatus.closed:
            return (KitMarkState.done, l10n.teamUiStatusConnected);
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
