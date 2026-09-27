/// Settings › Plugins (TEAM-106): the discovery card, the Plugins group with
/// its single "AI Team" row (subtitle per state, 02-ux §1.1; "Off" or
/// "On · This phone", docs/design/phone-server-screens-cleanup-2026-09-24.md
/// §3), and the connected server's own plugins.
///
/// The row opens the one AI Team page ([openTeamPage], programme P3.4):
/// the team's state, where it runs, Change address and Turn off live there
/// now; the AI Team sheet that held them here (team-plugin-sheet) is gone.
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
import '../../widgets/team_switch.dart' show editTeamAddress;
import '../../widgets/team_technical_details.dart';
import '../team/team_page.dart';
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

  /// The one AI Team page, in whatever state the team is (P3.4).
  Future<void> _openTeam() => openTeamPage(
    context,
    widget.controller,
    probe: widget.probe,
    runtime: widget.teamRuntime,
    now: widget.now,
  );

  /// A computer's team instead of the phone's: its address, straight away.
  Future<void> _addComputerTeam() => editTeamAddress(
    context,
    widget.controller,
    probe: widget.probe,
    suggestedUrl: _discovery.result?.url,
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
                          ? AppIconography.agent
                          : AppIconography.computer,
                    ),
                    title: phoneTeamOn
                        ? l10n.pluginsTeamOpenPage
                        : l10n.teamDiscoverComputerChoiceTitle,
                    supporting: phoneTeamOn
                        ? null
                        : TextSpan(text: l10n.teamDiscoverComputerChoiceBody),
                    supportingMaxLines: 2,
                    trailing: const KitChevron(),
                    onTap: phoneTeamOn ? _openTeam : _addComputerTeam,
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
                    onTap: _openTeam,
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
