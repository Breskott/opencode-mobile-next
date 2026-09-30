// Plain words for a refused project command, in one place.
//
// The engine answers a refused command with a short technical code
// ([TeamCommandResult.code]) and the phone engine adapter can throw a
// `PhoneEngineException` with one. The person reads a sentence, a way
// forward and, under Details, the code. To add a code: one line in
// [_known] and its two strings in app_en.arb (teamRefusal<Name> and
// teamRefusal<Name>Next). An unknown code never reads as a raw code: it
// reads "The team couldn't <what you asked>" and keeps the code in Details.
import '../../../../domain/team_project_gateway.dart' show TeamProjectAction;
import '../../../../l10n/app_localizations.dart';

class TeamRefusal {
  const TeamRefusal({
    required this.message,
    required this.next,
    required this.code,
  });
  final String message, next, code;
}

typedef _Say = String Function(AppLocalizations l);

final Map<String, (_Say, _Say)> _known = {
  'repository_empty': (
    (l) => l.teamRefusalRepositoryEmpty,
    (l) => l.teamRefusalRepositoryEmptyNext,
  ),
  'invalid_proot_object_link': (
    (l) => l.teamRefusalRepositoryLink,
    (l) => l.teamRefusalRepositoryLinkNext,
  ),
  'repository_object_hash_mismatch': (
    (l) => l.teamRefusalRepositoryDamaged,
    (l) => l.teamRefusalRepositoryDamagedNext,
  ),
  'planTaskTitleRequired': (
    (l) => l.teamRefusalPlanTaskTitle,
    (l) => l.teamRefusalPlanTaskTitleNext,
  ),
  'planPhaseInvalid': (
    (l) => l.teamRefusalPlanPhase,
    (l) => l.teamRefusalPlanPhaseNext,
  ),
  'unsupportedCommand': (
    (l) => l.teamRefusalUnsupportedCommand,
    (l) => l.teamRefusalUnsupportedCommandNext,
  ),
  'boundaryUnverified': (
    (l) => l.teamRefusalBoundaryUnverified,
    (l) => l.teamRefusalBoundaryUnverifiedNext,
  ),
  'protocolUnverified': (
    (l) => l.teamRefusalProtocolUnverified,
    (l) => l.teamRefusalProtocolUnverifiedNext,
  ),
  'engineUnavailable': (
    (l) => l.teamRefusalEngineUnavailable,
    (l) => l.teamRefusalEngineUnavailableNext,
  ),
  'transportUncertain': (
    (l) => l.teamRefusalTransportUncertain,
    (l) => l.teamRefusalTransportUncertainNext,
  ),
  'busy': ((l) => l.teamRefusalBusy, (l) => l.teamRefusalBusyNext),
  'saveFailed': (
    (l) => l.teamRefusalSaveFailed,
    (l) => l.teamRefusalSaveFailedNext,
  ),
  'readOnly': ((l) => l.teamRefusalReadOnly, (l) => l.teamRefusalReadOnlyNext),
  'closed': ((l) => l.teamRefusalClosed, (l) => l.teamRefusalClosedNext),
  'commandRefused': (
    (l) => l.teamRefusalCommandRefused,
    (l) => l.teamRefusalCommandRefusedNext,
  ),
  'importFailed': (
    (l) => l.teamRefusalImportFailed,
    (l) => l.teamRefusalImportFailedNext,
  ),
  'payloadInvalid': (
    (l) => l.teamRefusalPayloadInvalid,
    (l) => l.teamRefusalPayloadInvalidNext,
  ),
  'schemaUnsupported': (
    (l) => l.teamRefusalSchemaUnsupported,
    (l) => l.teamRefusalSchemaUnsupportedNext,
  ),
  'engineClosed': (
    (l) => l.teamRefusalEngineClosed,
    (l) => l.teamRefusalEngineClosedNext,
  ),
};

String _did(AppLocalizations l, TeamProjectAction action) => switch (action) {
  TeamProjectAction.createProject => l.teamRefusalDidPlan,
  TeamProjectAction.createQuickTask => l.teamRefusalDidQuick,
  TeamProjectAction.approvePlan => l.teamRefusalDidApprove,
  TeamProjectAction.approveSpec => l.teamRefusalDidSpec,
  TeamProjectAction.promote => l.teamRefusalDidPromote,
  TeamProjectAction.stopProject => l.teamRefusalDidStop,
  TeamProjectAction.pauseProject => l.teamRefusalDidPause,
  TeamProjectAction.resumeProject => l.teamRefusalDidResume,
  _ => l.teamRefusalDidSave,
};

/// The sentence, way forward and code for a refused [action].
TeamRefusal teamRefusalFor(
  AppLocalizations l,
  TeamProjectAction action,
  String code,
) {
  final known = _known[code];
  if (known != null) {
    return TeamRefusal(message: known.$1(l), next: known.$2(l), code: code);
  }
  return TeamRefusal(
    message: l.teamRefusalUnknown(_did(l, action)),
    next: l.teamRefusalUnknownNext,
    code: code,
  );
}
