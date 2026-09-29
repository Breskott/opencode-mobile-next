/// The one AI Team page (programme P3.4, "the team page is one page"):
/// every door to the AI Team opens it — Settings › AI Team, Plugins' AI
/// Team row, search, New conversation's Team while the team is off — and
/// it shows the team in whatever state it is in:
///
/// - **On** ([OrchestrationController] for the connected server): the
///   work itself ([TeamHomeScreen]): one status line and one list of
///   tasks, most urgent first. Setup (agents, how it runs, spend, Turn
///   off) is Team settings, from the top bar or Settings › AI Team.
/// - **Off**: the same page says what the team does and sets it up for
///   this kind of server ([TeamIntroScreen]); the moment it is on, the
///   page turns into the team, with no hop back and no second page.
///
/// The retired AI Team sheet (team-plugin-sheet) and the separate intro
/// route both land here.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../state/connection.dart';
import '../../../domain/orchestration_gateway.dart' show OrchestrationRun;
import '../../../termux/team_runtime.dart';
import '../../../voice/device.dart';
import '../../kit/kit.dart';
import '../../widgets/team_host_form.dart' show TeamHostProbe;
import 'team_home_screen.dart';
import 'team_intro_screen.dart';
import 'team_settings_screen.dart';

/// Opens the AI Team page for the connected server. [onOpenRun] replaces
/// what a task row opens (a task's conversation that opened this page
/// takes its own task back instead of stacking a second copy).
Future<void> openTeamPage(
  BuildContext context,
  ConnectionController connection, {
  TeamHostProbe? probe,
  TermuxTeamRuntime? runtime,
  Future<VoiceDeviceInfo> Function()? deviceProbe,
  DateTime Function()? now,
  ValueChanged<OrchestrationRun>? onOpenRun,
}) => pushKitPage<void>(
  context,
  (_) => TeamPage(
    connection: connection,
    probe: probe,
    runtime: runtime,
    deviceProbe: deviceProbe,
    now: now,
    onOpenRun: onOpenRun,
  ),
);

/// Settings › AI Team's door (setup only): Team settings while the team is
/// on, the intro and turn-on flow while it is off. The work page stays
/// behind the Work strip and search.
Future<void> openTeamSetup(
  BuildContext context,
  ConnectionController connection, {
  TeamHostProbe? probe,
  TermuxTeamRuntime? runtime,
  Future<VoiceDeviceInfo> Function()? deviceProbe,
}) {
  final profile = connection.profile;
  final team = connection.orchestration;
  if (profile != null &&
      profile.orchestration != null &&
      team != null &&
      team.profileId == profile.id) {
    return openTeamSettings(
      context,
      controller: team,
      connection: connection,
      probe: probe,
      teamRuntime: runtime,
    );
  }
  return openTeamPage(
    context,
    connection,
    probe: probe,
    runtime: runtime,
    deviceProbe: deviceProbe,
  );
}

class TeamPage extends StatelessWidget {
  const TeamPage({
    super.key,
    required this.connection,
    this.probe,
    this.runtime,
    this.deviceProbe,
    this.now,
    this.onOpenRun,
  });

  final ConnectionController connection;

  /// The Gas City probe (discovery and the address form); tests pass a
  /// fake.
  final TeamHostProbe? probe;

  /// The Termux team runtime; tests pass a fake.
  final TermuxTeamRuntime? runtime;

  /// The device facts the phone's pre-flight reads; tests stand in.
  final Future<VoiceDeviceInfo> Function()? deviceProbe;

  /// Clock for the team's ages; tests pin it.
  final DateTime Function()? now;

  /// What a task row opens; its conversation when null.
  final ValueChanged<OrchestrationRun>? onOpenRun;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: connection,
    builder: (context, _) {
      final profile = connection.profile;
      final team = connection.orchestration;
      if (profile != null &&
          profile.orchestration != null &&
          team != null &&
          team.profileId == profile.id) {
        // A new controller (a changed address) is a new team: fresh state.
        return TeamHomeScreen(
          key: ObjectKey(team),
          controller: team,
          connection: connection,
          probe: probe,
          teamRuntime: runtime,
          now: now,
          onOpenRun: onOpenRun,
          // This page follows the connection by itself.
          onTeamChanged: () {},
        );
      }
      if (profile != null && profile.orchestration != null) {
        // Turned on a moment ago: the team starts in the next frame.
        final l10n = lookupAppLocalizations(Localizations.localeOf(context));
        return KitScreen(
          key: const ValueKey('team-page-starting'),
          topBar: KitTopBar(title: l10n.teamUiHomeTitle),
          loading: true,
          loadingLabel: l10n.teamUiCardLoading,
          body: const SizedBox.shrink(),
        );
      }
      // Off, or no server: the same page says what the team does and
      // sets it up. Keyed by the server so a switch looks afresh.
      return TeamIntroScreen(
        key: ValueKey('team-page-off-${profile?.id}'),
        controller: connection,
        probe: probe,
        runtime: runtime,
        deviceProbe: deviceProbe,
      );
    },
  );
}
