// Execution-gated project actions (New project, Approve and start, lanes,
// merge, verify, move, Promote) follow what the engine can do right now
// (OrchestrationCapabilities), never the server's flavor. While it cannot
// run work the actions are not drawn as dead buttons: one plain line says
// why and carries the one action that fixes it, the setup flow.
//
// The gate is bound to a project controller by the page that owns the
// team ([TeamExecutionGate.bind]); screens pushed on the navigator find it
// from the controller they already hold. A controller nobody bound (the
// demo, which simulates every action) is never gated.
import 'package:flutter/widgets.dart';

import '../../../../domain/orchestration_gateway.dart'
    show OrchestrationCapabilities;
import '../../../../l10n/app_localizations.dart';
import '../../../../state/connection.dart';
import '../../../../state/orchestration.dart';
import '../../../../state/team_project_controller.dart';
import '../../../kit/kit.dart';
import '../team_phone_setup_screen.dart';

/// What an action needs the engine to be able to do.
enum TeamExecutionNeed { lanes, promotion, mergeQueue, verification, placement }

class TeamExecutionGate {
  TeamExecutionGate._(this.team, this.connection);

  final OrchestrationController team;
  final ConnectionController connection;

  static final Expando<TeamExecutionGate> _bound = Expando();

  /// Binds [team]'s project controller to the gate. Safe to repeat.
  static void bind(OrchestrationController team, ConnectionController c) {
    final projects = team.projectController;
    if (projects == null) return;
    final existing = _bound[projects];
    if (existing != null && identical(existing.connection, c)) return;
    _bound[projects] = TeamExecutionGate._(team, c);
  }

  static TeamExecutionGate? of(TeamProjectController controller) =>
      _bound[controller];

  OrchestrationCapabilities get capabilities => team.capabilities;

  bool permits(TeamExecutionNeed need) => switch (need) {
    TeamExecutionNeed.lanes => capabilities.projectLanes,
    TeamExecutionNeed.promotion => capabilities.projectPromotion,
    TeamExecutionNeed.mergeQueue => capabilities.projectMergeQueue,
    TeamExecutionNeed.verification => capabilities.projectVerification,
    TeamExecutionNeed.placement => capabilities.projectPlacement,
  };

  /// Opens "Turn on AI Team on this phone".
  Future<void> setUp(BuildContext context) =>
      openPhoneTeamSetup(context, connection);

  /// Whether [need] can run now; true for an unbound controller.
  static bool allows(TeamProjectController c, TeamExecutionNeed need) =>
      of(c)?.permits(need) ?? true;
}

/// The one plain line, with the fix, shown once per page while the engine
/// cannot run work. Draws nothing otherwise.
class TeamExecutionBlocked extends StatelessWidget {
  const TeamExecutionBlocked({super.key, required this.controller});

  final TeamProjectController controller;

  @override
  Widget build(BuildContext context) {
    final gate = TeamExecutionGate.of(controller);
    if (gate == null || gate.permits(TeamExecutionNeed.lanes)) {
      return const SizedBox.shrink();
    }
    final l = lookupAppLocalizations(Localizations.localeOf(context));
    return KitNotice(
      key: const ValueKey('team-execution-blocked'),
      message: l.phoneTeamBlocked,
      actions: [
        KitAction(
          key: const ValueKey('team-execution-set-up'),
          label: l.teamIntroTurnOnPhone,
          onPressed: () => gate.setUp(context),
        ),
      ],
    );
  }
}
