/// Finding the AI Team while it is off (docs/qa/team-discover-2026-09-25):
/// the owner, "AI team is impossible to discover bro". The door is Settings
/// › AI Team, which leads to the intro ([TeamIntroScreen]) while the team
/// is off: it says what the team does and what it needs on this kind of
/// server, and hands over to that kind's own set-up.
///
/// These are the helpers those pages share: where a server's team would
/// run, whether it can, the new-conversation Solo · Team choice and the
/// team's one state line.
library;

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../builtin/setup/components.dart' show SetupComponentIds;
import '../../builtin/setup/setup_contract.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart';
import '../screens/settings/plugins_screen.dart'
    show teamPhoneProfile, teamRowSubtitle;
import '../screens/new_conversation_sheet.dart'
    show NewConversationChoice, NewConversationKind, NewConversationMemory;
import '../screens/team/team_intro_screen.dart';
import 'builtin_team_section.dart' show BuiltinTeamSection;
import 'team_discovery_card.dart' show TeamDiscovery;

/// Where the AI Team of a server would run, which decides what setting it
/// up means.
enum TeamServerKind {
  /// OpenCode inside this app (its own Ubuntu): the team is a component of
  /// the app's setup, installed here and turned on per project.
  inApp,

  /// OpenCode in Termux, managed by this app: the team is the same setup
  /// component, installed into Termux's Ubuntu by the Termux host's job.
  termux,

  /// Any other server (a computer, a laptop, WSL): Gas City runs there and
  /// the app finds it, or is given its address.
  computer,
}

/// The kind of [profile] for the AI Team.
TeamServerKind teamServerKindOf(ServerProfile profile) {
  if (BuiltinTeamSection.appliesTo(profile)) return TeamServerKind.inApp;
  if (teamPhoneProfile(profile)) return TeamServerKind.termux;
  return TeamServerKind.computer;
}

/// Whether New conversation offers Team on [profile]'s server: on every
/// kind of server. A phone that cannot run a team is never hidden: Team
/// opens the intro, whose pre-flight says why and offers a computer
/// (programme P1.7).
Future<bool> teamPossibleOn(ServerProfile profile) async => true;

/// New conversation's Solo · Team choice, remembered per server.
///
/// Retired by slice-P4.5: New conversation's chooser remembers every way to
/// start (Solo, Team, a separate copy, a cloud machine) under the same key;
/// use [NewConversationMemory].
@Deprecated('Retired by slice-P4.5: use NewConversationMemory')
abstract final class TeamNewMode {
  static String key(String profileId) => NewConversationMemory.key(profileId);

  static bool isTeam(SharedPreferences prefs, String profileId) =>
      NewConversationMemory.read(prefs, profileId)?.kind ==
      NewConversationKind.team;

  static Future<void> set(
    SharedPreferences prefs,
    String profileId, {
    required bool team,
  }) => NewConversationMemory.remember(
    prefs,
    profileId,
    team
        ? const NewConversationChoice.team()
        : const NewConversationChoice.solo(),
  );
}

/// Whether [progress] is a setup job that installs the AI Team (Add tools
/// with AI Team, on OpenCode inside the app).
bool teamSetupRunning(SetupProgress progress) =>
    progress.state == SetupState.running &&
    progress.components.any(
      (component) => component.id == SetupComponentIds.aiTeam,
    );

/// The AI Team's one state line, read the same by Settings' AI Team row
/// and Settings › Plugins: "Turning on…" while this phone installs it,
/// else the Plugins row's words ("Off", "On · This phone", "Not
/// answering…"). Never "Off" while an install job runs.
String teamStateLine(
  AppLocalizations l10n,
  ConnectionController controller, {
  TeamDiscovery? discovery,
  SetupProgress? setup,
  DateTime? now,
}) {
  final profile = controller.profile;
  if (profile == null) return '';
  if (profile.orchestration == null &&
      setup != null &&
      teamSetupRunning(setup)) {
    return l10n.teamDiscoverTurningOn;
  }
  return teamRowSubtitle(
    l10n,
    profile: profile,
    orchestration: controller.orchestration,
    discovery: discovery,
    now: now ?? DateTime.now(),
  );
}
