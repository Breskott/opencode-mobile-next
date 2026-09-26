/// Finding the AI Team while it is off (docs/qa/team-discover-2026-09-25):
/// the owner, "AI team is impossible to discover bro". Before this, the
/// team was reachable only from Settings › Plugins, or from the Work tab's
/// card once it was already on.
///
/// - [TeamDiscoverEntry] sits where the Work tab's AI Team section goes,
///   after the person's own conversations, so it never pushes their work
///   down. The first time it is a small drawing, one line of value and a
///   way in; once the person has opened it or hidden it, it folds to one
///   quiet row ("AI Team · Off · …") that stays as a door. When the team is
///   on, [TeamCard] takes its place.
/// - The door leads to the intro ([TeamIntroScreen]), which says what the
///   team does and what it needs on this kind of server, and hands over to
///   that kind's own set-up.
///
/// Built from kit parts only (revamp unit shared-work-1): each state is a
/// flat [KitRow] (the first time under a [SectionLabel]); "Not now" is a
/// [KitIconButton].
///
/// The folded state is one global preference ([TeamDiscoverMemory]): it is
/// about the person knowing the team exists, not about a server, so it is
/// not an `oc.<what>.<profileId>` key and outlives a deleted server.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../builtin/setup/components.dart' show SetupComponentIds;
import '../../builtin/setup/setup_contract.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart';
import '../../termux/team_runtime.dart';
import '../app_theme.dart';
import '../kit/kit_icon_button.dart';
import '../kit/kit_illustration.dart';
import '../kit/kit_row.dart';
import '../kit/kit_row_parts.dart';
import '../kit/motion/kit_animated_rows.dart';
import '../kit/scenes/team_discover_scenes.dart';
import '../screens/settings/plugins_screen.dart'
    show teamPhoneProfile, teamRowSubtitle;
import '../screens/team/team_intro_screen.dart';
import 'builtin_team_section.dart' show BuiltinTeamSection;
import 'product_states.dart' show SectionLabel;
import 'team_discovery_card.dart' show TeamDiscovery;
import 'team_host_form.dart' show TeamHostProbe;
import 'team_phone_onboarding.dart' show teamPhoneRuntime;

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Where the AI Team of a server would run, which decides what setting it
/// up means.
enum TeamServerKind {
  /// OpenCode inside this app (its own Ubuntu): the team is a component of
  /// the app's setup, installed here and turned on per project.
  inApp,

  /// OpenCode in Termux, managed by this app: the team installs into Termux
  /// from the Termux setup screen, when this phone can run it.
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

/// Whether this phone can run a team inside Termux: false when it cannot
/// be told (a Termux that does not answer).
Future<bool> teamTermuxSupported(TermuxTeamRuntime? runtime) async {
  try {
    return await (runtime ?? teamPhoneRuntime).supportsAiTeam;
  } catch (_) {
    return false;
  }
}

/// Whether [profile]'s kind of server can run a team at all: always, but
/// on a Termux phone only when its runtime can.
Future<bool> teamPossibleOn(
  ServerProfile profile, {
  TermuxTeamRuntime? runtime,
}) async => teamServerKindOf(profile) == TeamServerKind.termux
    ? teamTermuxSupported(runtime)
    : true;

/// New conversation's Solo · Team choice, remembered per server
/// (`oc.newConversationMode.<profileId>`, swept with the profile).
abstract final class TeamNewMode {
  static String key(String profileId) => 'oc.newConversationMode.$profileId';

  static bool isTeam(SharedPreferences prefs, String profileId) =>
      prefs.getString(key(profileId)) == 'team';

  static Future<void> set(
    SharedPreferences prefs,
    String profileId, {
    required bool team,
  }) => prefs.setString(key(profileId), team ? 'team' : 'solo');
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

/// Whether the Work tab's entry has been seen (opened or hidden). Global:
/// see the library comment.
abstract final class TeamDiscoverMemory {
  static const foldedKey = 'oc.teamDiscover.folded';

  static bool folded(SharedPreferences prefs) =>
      prefs.getBool(foldedKey) ?? false;

  static Future<void> fold(SharedPreferences prefs) async {
    if (folded(prefs)) return;
    await prefs.setBool(foldedKey, true);
  }
}

/// The Work tab's door to the AI Team while it is off. Absent when there is
/// no server, when the team is on (the [TeamCard] is there instead), and on
/// a Termux phone that cannot run a team (nothing to offer there; Settings
/// › AI Team still says so plainly).
class TeamDiscoverEntry extends StatefulWidget {
  const TeamDiscoverEntry({
    super.key,
    required this.controller,
    this.runtime,
    this.probe,
  });

  final ConnectionController controller;

  /// The Termux team runtime; tests pass a fake.
  final TermuxTeamRuntime? runtime;

  /// The Gas City probe the intro uses; tests pass a fake.
  final TeamHostProbe? probe;

  @override
  State<TeamDiscoverEntry> createState() => _TeamDiscoverEntryState();
}

class _TeamDiscoverEntryState extends State<TeamDiscoverEntry> {
  /// The Termux profile [_termuxSupported] was asked for.
  String? _termuxProfile;
  bool _termuxSupported = false;

  SharedPreferences get _prefs => widget.controller.store.prefs;

  bool _available(ServerProfile profile) {
    if (teamServerKindOf(profile) != TeamServerKind.termux) return true;
    if (_termuxProfile != profile.id) {
      _termuxProfile = profile.id;
      _termuxSupported = false;
      unawaited(_checkTermux(profile.id));
    }
    return _termuxSupported;
  }

  Future<void> _checkTermux(String profileId) async {
    final supported = await teamTermuxSupported(widget.runtime);
    if (!mounted || _termuxProfile != profileId) return;
    if (supported != _termuxSupported) {
      setState(() => _termuxSupported = supported);
    }
  }

  Future<void> _hide() async {
    await TeamDiscoverMemory.fold(_prefs);
    if (mounted) setState(() {});
  }

  Future<void> _open() async {
    // Seen: when the person comes back, the entry is one quiet row.
    await TeamDiscoverMemory.fold(_prefs);
    if (!mounted) return;
    await openTeamIntro(
      context,
      widget.controller,
      probe: widget.probe,
      runtime: widget.runtime,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final profile = controller.profile;
    if (profile == null ||
        profile.orchestration != null ||
        controller.orchestration != null ||
        !_available(profile)) {
      return const SizedBox.shrink();
    }
    final l10n = _copy(context);
    final folded = TeamDiscoverMemory.folded(_prefs);
    // The full entry folds away where it was and the quiet row unfolds in
    // its place (design standard §10). Both are flat rows like the
    // person's conversations above them and the team's own door when it is
    // on; the Work list's surface is the ink their rows splash on.
    return KitAnimatedRows(
      children: [
        if (folded)
          KitRow(
            key: const ValueKey('team-discover-row'),
            leading: KitRow.icon(context, AppIconography.agent),
            title: l10n.teamUiHomeTitle,
            supporting: TextSpan(text: l10n.teamDiscoverRowLine),
            supportingKey: const ValueKey('team-discover-row-line'),
            trailing: const KitChevron(),
            onTap: _open,
          )
        else
          Column(
            key: const ValueKey('team-discover-card'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(l10n.teamUiHomeTitle),
              Semantics(
                button: true,
                child: KitRow(
                  key: const ValueKey('team-discover-open'),
                  // Three agents, one holding up a task: a small drawing
                  // that plays once, never loops (a resting screen).
                  leading: const KitIllustration(
                    key: ValueKey('team-discover-drawing'),
                    scene: TeamDiscoverTeaserScene(),
                    width: 60,
                  ),
                  title: l10n.teamDiscoverEntryTitle,
                  titleMaxLines: 2,
                  supporting: TextSpan(text: l10n.teamDiscoverEntryBody),
                  supportingMaxLines: 3,
                  trailing: KitIconButton(
                    key: const ValueKey('team-discover-hide'),
                    icon: AppIconography.close,
                    size: 20,
                    tooltip: l10n.teamUiDiscoveryNotNow,
                    onPressed: _hide,
                  ),
                  onTap: _open,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
