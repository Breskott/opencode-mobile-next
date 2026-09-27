/// The optional on-device AI Team step of the Termux setup (TEAM-302,
/// 03-onboarding-on-device §2): the "Also run an AI team on this phone"
/// block shown after step 3 succeeds, the five visible steps with the same
/// live output panel the OpenCode install uses, the success card and the
/// honest failure copy of §5.
///
/// Built from kit parts (owner rule 2026-09-27, R6): each state on one
/// [KitSurface] panel, the steps as [KitRow]s with a [KitStatusMark], the
/// acts in a [KitActionBlock], what went wrong in a [KitNotice], the
/// project picker in a kit sheet ([KitChoiceList], [KitField]) and the
/// log copied through [KitCopy].
///
/// Everything here reads and drives [TermuxTeamRuntime] (TEAM-301). The
/// runtime's state file is the truth: leaving the screen and coming back
/// resumes the view from `aiteam.sh status`, and a verb that finished while
/// the app was away shows as done. The block is absent (not disabled)
/// while [TermuxTeamRuntime.supportsAiTeam] is false.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/workspace_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/orchestration_store.dart';
import '../../state/profiles.dart';
import '../../termux/bridge.dart';
import '../../termux/team_runtime.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import 'setup_terminal.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

TermuxTeamRuntime? _sharedRuntime;

/// The runtime the on-device widgets share; one instance per app so the
/// manifest and the arm64 probe are read once.
TermuxTeamRuntime get teamPhoneRuntime =>
    debugTeamPhoneRuntime ?? (_sharedRuntime ??= TermuxTeamRuntime());

/// Tests swap the shared runtime for a fake; reset to null in `addTearDown`.
@visibleForTesting
TermuxTeamRuntime? debugTeamPhoneRuntime;

/// How often the steps view re-reads status and the log while a verb runs.
const teamPhonePollInterval = Duration(seconds: 2);

/// The spike's estimate when the manifest declares no sizes.
const _fallbackDownloadMb = 250;

/// The download size line's number: the manifest's declared bytes, rounded
/// up to whole megabytes, or the spike estimate.
int teamPhoneDownloadMb(TeamRuntimeManifest? manifest) {
  final bytes = manifest?.totalBytes ?? 0;
  if (bytes <= 0) return _fallbackDownloadMb;
  return (bytes / (1000 * 1000)).ceil();
}

/// The five visible steps of 03-onboarding §2.
enum TeamPhoneStep { download, packages, city, start, connect }

enum TeamPhoneStepState { idle, running, done, error }

/// The step [phase] belongs to, and whether it is under way, done or failed
/// there. `connect` is the app's own step: done once the profile carries
/// the phone config ([connected]).
Map<TeamPhoneStep, TeamPhoneStepState> teamPhoneStepStates(
  TeamRuntimeStatus status, {
  required bool connected,
}) {
  final states = {
    for (final step in TeamPhoneStep.values) step: TeamPhoneStepState.idle,
  };
  void doneThrough(TeamPhoneStep last) {
    for (final step in TeamPhoneStep.values) {
      states[step] = TeamPhoneStepState.done;
      if (step == last) break;
    }
  }

  switch (status.phase) {
    case TeamRuntimePhase.idle:
    case TeamRuntimePhase.unknown:
      break;
    case TeamRuntimePhase.queued:
      final step = _stepForVerb(status.verb);
      if (step != null) {
        if (step.index > 0) doneThrough(TeamPhoneStep.values[step.index - 1]);
        states[step] = TeamPhoneStepState.running;
      }
    case TeamRuntimePhase.downloading:
    case TeamRuntimePhase.verifying:
      states[TeamPhoneStep.download] = TeamPhoneStepState.running;
    case TeamRuntimePhase.installingPackages:
      doneThrough(TeamPhoneStep.download);
      states[TeamPhoneStep.packages] = TeamPhoneStepState.running;
    case TeamRuntimePhase.installed:
      doneThrough(TeamPhoneStep.packages);
    case TeamRuntimePhase.creatingCity:
      doneThrough(TeamPhoneStep.packages);
      states[TeamPhoneStep.city] = TeamPhoneStepState.running;
    case TeamRuntimePhase.cityReady:
    case TeamRuntimePhase.stopped:
      doneThrough(TeamPhoneStep.city);
    case TeamRuntimePhase.starting:
      doneThrough(TeamPhoneStep.city);
      states[TeamPhoneStep.start] = TeamPhoneStepState.running;
    case TeamRuntimePhase.ready:
      if (status.health != 'ok' && !status.killedByAndroid) {
        doneThrough(TeamPhoneStep.city);
        states[TeamPhoneStep.start] = TeamPhoneStepState.error;
        break;
      }
      doneThrough(TeamPhoneStep.start);
      states[TeamPhoneStep.connect] = connected
          ? TeamPhoneStepState.done
          : TeamPhoneStepState.running;
    case TeamRuntimePhase.stopping:
    case TeamRuntimePhase.removing:
      doneThrough(TeamPhoneStep.city);
    case TeamRuntimePhase.failed:
      final step = teamPhoneFailedStep(status);
      if (step.index > 0) doneThrough(TeamPhoneStep.values[step.index - 1]);
      states[step] = TeamPhoneStepState.error;
  }
  return states;
}

TeamPhoneStep? _stepForVerb(String verb) => switch (verb) {
  'install' => TeamPhoneStep.download,
  'init' => TeamPhoneStep.city,
  'start' => TeamPhoneStep.start,
  _ => null,
};

/// Which step a failed [status] belongs to, from its reason first (the
/// install verb spans two steps) and its verb second.
TeamPhoneStep teamPhoneFailedStep(TeamRuntimeStatus status) {
  final reason = status.reason ?? '';
  if (status.phase == TeamRuntimePhase.ready) return TeamPhoneStep.start;
  if (reason == 'packages') return TeamPhoneStep.packages;
  if (reason.startsWith('checksum-mismatch') ||
      status.downloadFailure != null ||
      reason == 'unsupported-arch' ||
      reason.startsWith('manifest')) {
    return TeamPhoneStep.download;
  }
  if (reason == 'no-space') {
    return status.verb == 'init' ? TeamPhoneStep.city : TeamPhoneStep.download;
  }
  if (reason.startsWith('project') ||
      reason.startsWith('gc-') ||
      reason == 'not-installed') {
    return TeamPhoneStep.city;
  }
  if (reason == 'supervisor-exited' ||
      reason == 'health-timeout' ||
      reason == 'no-city') {
    return TeamPhoneStep.start;
  }
  return _stepForVerb(status.verb) ?? TeamPhoneStep.download;
}

/// The honest sentence for a failed [status] (03-onboarding §5); the
/// checksum refusal gets its own.
String teamPhoneFailureText(AppLocalizations l10n, TeamRuntimeStatus status) {
  final reason = status.reason ?? '';
  if (status.phase == TeamRuntimePhase.ready && !status.isReady) {
    return l10n.teamUiPhoneFailedHealth(status.url);
  }
  if (status.checksumMismatch) {
    final parts = reason.split(RegExp(r'\s+'));
    return l10n.teamUiPhoneFailedChecksum(parts.length > 1 ? parts[1] : 'file');
  }
  if (reason == 'unsupported-arch') {
    return l10n.teamUiPhoneFailedUnsupportedArch;
  }
  if (reason == 'no-space') {
    final detail = status.lastError ?? '';
    return l10n.teamUiPhoneFailedNoSpace(
      detail.isEmpty ? '' : '${detail.split(':').last.trim()}.',
    );
  }
  final download = status.downloadFailure;
  if (download != null) return teamPhoneDownloadFailureText(l10n, download);
  if (reason.startsWith('manifest')) return l10n.teamUiPhoneFailedDownload;
  if (reason == 'packages') return l10n.teamUiPhoneFailedPackages;
  if (reason.startsWith('project')) return l10n.teamUiPhoneFailedProject;
  if (reason.startsWith('gc-') ||
      reason == 'not-installed' ||
      reason == 'no-city') {
    return l10n.teamUiPhoneFailedCity;
  }
  if (reason == 'supervisor-exited') {
    return l10n.teamUiPhoneFailedSupervisorExited;
  }
  if (reason == 'health-timeout') {
    return l10n.teamUiPhoneFailedHealth(status.url);
  }
  final error = status.lastError ?? '';
  if (reason == 'interrupted' || error.contains('stopped unexpectedly')) {
    return l10n.teamUiPhoneFailedInterrupted;
  }
  return l10n.teamUiPhoneFailedReason(
    error.isNotEmpty ? error : (reason.isNotEmpty ? reason : status.rawPhase),
  );
}

/// Why a download failed, naming the server that was asked, so a user can
/// tell a phone that is offline from a server that refused the file (issue
/// #87: a download pointed at a private address failed as "did not finish").
String teamPhoneDownloadFailureText(
  AppLocalizations l10n,
  TeamDownloadFailure failure,
) {
  final host = failure.host;
  if (host.isEmpty) return l10n.teamUiPhoneFailedDownload;
  final code = failure.code?.toString() ?? '?';
  return switch (failure.kind) {
    TeamDownloadFailureKind.dns => l10n.teamUiPhoneFailedDownloadDns(host),
    TeamDownloadFailureKind.connect => l10n.teamUiPhoneFailedDownloadConnect(
      host,
    ),
    TeamDownloadFailureKind.timeout => l10n.teamUiPhoneFailedDownloadTimeout(
      host,
    ),
    TeamDownloadFailureKind.tls => l10n.teamUiPhoneFailedDownloadTls(host),
    TeamDownloadFailureKind.http => l10n.teamUiPhoneFailedDownloadHttp(
      host,
      code,
    ),
    TeamDownloadFailureKind.interrupted =>
      l10n.teamUiPhoneFailedDownloadInterrupted(host),
    TeamDownloadFailureKind.write => l10n.teamUiPhoneFailedDownloadWrite,
    TeamDownloadFailureKind.other => l10n.teamUiPhoneFailedDownloadOther(
      host,
      code,
    ),
  };
}

/// The Termux (managed) profile the on-device team belongs to, or null.
ServerProfile? teamPhoneProfileOf(ConnectionController connection) {
  final profile = connection.profile;
  if (profile != null && TermuxBridge.managesServerUrl(profile.baseUrl)) {
    return profile;
  }
  return null;
}

/// Writes the phone config onto [profile] and lets the connection build its
/// controller (03 §3). The store instance is the source of truth for the
/// connected profile, so the same object is updated and saved.
Future<void> teamPhoneEnable(
  ConnectionController connection,
  ServerProfile profile,
  TermuxTeamRuntime runtime,
  TeamRuntimeStatus status,
) async {
  final config = runtime.phoneOrchestrationConfig(status);
  profile.orchestration = config;
  await connection.store.upsert(profile);
  connection.syncOrchestration();
}

enum _View { checking, hidden, offer, steps, success, failed, killed }

/// The block after step 3 of the Termux setup: offer, steps, success.
class TeamPhoneOnboardingBlock extends StatefulWidget {
  const TeamPhoneOnboardingBlock({
    super.key,
    required this.connection,
    required this.profile,
    required this.onOpenWorkspace,
    this.runtime,
  });

  final ConnectionController connection;

  /// The Termux server profile the team belongs to.
  final ServerProfile profile;

  /// What the success card's Open Workspace does.
  final VoidCallback onOpenWorkspace;

  final TermuxTeamRuntime? runtime;

  @override
  State<TeamPhoneOnboardingBlock> createState() =>
      _TeamPhoneOnboardingBlockState();
}

class _TeamPhoneOnboardingBlockState extends State<TeamPhoneOnboardingBlock> {
  TermuxTeamRuntime get _runtime => widget.runtime ?? teamPhoneRuntime;
  OrchestrationStore get _prefs => widget.connection.orchestrationStore;

  _View _view = _View.checking;
  TeamRuntimeStatus _status = const TeamRuntimeStatus(
    phase: TeamRuntimePhase.idle,
  );
  TeamRuntimeManifest? _manifest;
  String _log = '';
  String? _project;
  String? _dispatchError;
  bool _busy = false;
  bool _connected = false;
  Timer? _poll;
  final ScrollController _logController = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _logController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final runtime = _runtime;
    if (!await runtime.supportsAiTeam) {
      if (mounted) setState(() => _view = _View.hidden);
      return;
    }
    _manifest = await runtime.manifest();
    TeamRuntimeStatus status;
    try {
      status = await runtime.status();
    } on TermuxBridgeException {
      status = const TeamRuntimeStatus(phase: TeamRuntimePhase.idle);
    }
    if (!mounted) return;
    _connected =
        widget.profile.orchestration?.hostMode == OrchestrationHostMode.phone;
    _project = status.project.isNotEmpty ? status.project : null;
    await _connectIfReady(status);
    if (!mounted) return;
    _apply(status);
    if (status.busy) {
      _log = await runtime.logTail();
      if (mounted) setState(_startPolling);
    } else if (status.phase == TeamRuntimePhase.failed) {
      // A failure the app comes back to keeps its last output on screen.
      await _refreshLog();
    }
  }

  /// A team that came up while the app was away (or before this build)
  /// still gets its config: the Connect step is the app's own.
  Future<void> _connectIfReady(TeamRuntimeStatus status) async {
    if (_connected || !status.isReady) return;
    await teamPhoneEnable(widget.connection, widget.profile, _runtime, status);
    _connected = true;
  }

  /// Chooses the view for [status]: an untouched runtime shows the offer
  /// (or nothing, once skipped); a runtime with history shows where it got
  /// to. A supervisor that is up but not answering reads as a failure, not
  /// a success.
  void _apply(TeamRuntimeStatus status) {
    _status = status;
    final _View next;
    if (status.busy) {
      next = _View.steps;
    } else {
      switch (status.phase) {
        case TeamRuntimePhase.idle:
        case TeamRuntimePhase.unknown:
          next = _prefs.phoneOffer(widget.profile.id) == PhoneOffer.open
              ? _View.offer
              : _View.hidden;
        case TeamRuntimePhase.ready:
          next = status.killedByAndroid
              ? _View.killed
              : status.isReady
              ? _View.success
              : _View.failed;
        case TeamRuntimePhase.failed:
          next = _View.failed;
        default:
          next = _View.steps;
      }
    }
    if (!mounted) return;
    setState(() => _view = next);
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(teamPhonePollInterval, (_) => _tick());
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _tick() async {
    final runtime = _runtime;
    try {
      final status = await runtime.status();
      final log = await runtime.logTail();
      if (!mounted) return;
      _appendLog(log);
      if (_busy) {
        // The sequence below owns the view; the tick only feeds the panel
        // and the step list.
        setState(() => _status = status);
        return;
      }
      if (!status.busy) {
        _stopPolling();
        await _connectIfReady(status);
        if (!mounted) return;
      }
      _apply(status);
    } on TermuxBridgeException {
      // Keep polling: the bridge answers again once Termux is back.
    }
  }

  void _appendLog(String log) {
    if (log == _log) return;
    final follow =
        !_logController.hasClients ||
        _logController.position.maxScrollExtent -
                _logController.position.pixels <
            48;
    _log = log;
    if (follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_logController.hasClients) return;
        _logController.jumpTo(_logController.position.maxScrollExtent);
      });
    }
  }

  Future<void> _skip() async {
    await _prefs.setPhoneOffer(widget.profile.id, PhoneOffer.skipped);
    if (mounted) setState(() => _view = _View.hidden);
  }

  /// The project the city is created next to: the folder Workspace last
  /// opened on this server when it is one of the managed projects, else the
  /// server's first project, else one the person names here.
  Future<String?> _chooseProject() async {
    final projects = await _runtime.managedProjects();
    if (!mounted) return null;
    final saved = widget.connection.store
        .locationFor(widget.profile.id)
        ?.directory;
    if (saved != null && projects.contains(saved)) return saved;
    if (projects.length == 1) return projects.first;
    return showKitSheet<String>(
      context,
      title: _copy(context).teamUiPhoneChooseProjectTitle,
      icon: AppIconography.folders,
      body: (_) => _ProjectSheet(projects: projects, runtime: _runtime),
    );
  }

  Future<void> _setUp() async {
    final project = _project ?? await _chooseProject();
    if (project == null || !mounted) return;
    _project = project;
    await _run(from: TeamPhoneStep.download);
  }

  /// Continues from where the runtime got to: nothing installed → install;
  /// installed → init; a city → start.
  Future<void> _resume() async {
    final status = _status;
    final TeamPhoneStep from;
    if (status.hasCity) {
      from = TeamPhoneStep.start;
    } else if (status.installed) {
      from = TeamPhoneStep.city;
    } else {
      from = TeamPhoneStep.download;
    }
    if (from != TeamPhoneStep.start) {
      final project = _project ?? await _chooseProject();
      if (project == null || !mounted) return;
      _project = project;
    }
    await _run(from: from);
  }

  Future<void> _retry() async {
    final status = _status;
    if (status.phase != TeamRuntimePhase.failed) return _resume();
    final step = teamPhoneFailedStep(status);
    final from = switch (step) {
      TeamPhoneStep.download ||
      TeamPhoneStep.packages => TeamPhoneStep.download,
      TeamPhoneStep.city => TeamPhoneStep.city,
      TeamPhoneStep.start || TeamPhoneStep.connect => TeamPhoneStep.start,
    };
    if (from == TeamPhoneStep.city || !status.installed) {
      final project = _project ?? await _chooseProject();
      if (project == null || !mounted) return;
      _project = project;
    }
    await _run(from: from);
  }

  Future<void> _run({required TeamPhoneStep from}) async {
    final runtime = _runtime;
    setState(() {
      _busy = true;
      _dispatchError = null;
      _view = _View.steps;
      _status = TeamRuntimeStatus(
        phase: TeamRuntimePhase.queued,
        verb: switch (from) {
          TeamPhoneStep.download || TeamPhoneStep.packages => 'install',
          TeamPhoneStep.city => 'init',
          _ => 'start',
        },
        busy: true,
        installed: _status.installed,
        city: _status.city,
        project: _status.project,
      );
      _startPolling();
    });
    try {
      var status = _status;
      if (from.index <= TeamPhoneStep.packages.index) {
        status = await runtime.install();
        if (!mounted) return;
        if (status.phase != TeamRuntimePhase.installed) {
          return _finish(status);
        }
      }
      if (from.index <= TeamPhoneStep.city.index) {
        status = await runtime.init(_project!);
        if (!mounted) return;
        if (status.phase != TeamRuntimePhase.cityReady) {
          return _finish(status);
        }
      }
      status = await runtime.start();
      if (!mounted) return;
      if (!status.isReady) return _finish(status);
      setState(() => _status = status);
      await teamPhoneEnable(widget.connection, widget.profile, runtime, status);
      if (!mounted) return;
      _connected = true;
      _finish(status);
    } on TermuxBridgeException catch (error) {
      if (!mounted) return;
      _stopPolling();
      setState(() {
        _busy = false;
        _dispatchError = error.message;
        _view = _View.failed;
      });
    }
  }

  void _finish(TeamRuntimeStatus status) {
    _stopPolling();
    _busy = false;
    _project = status.project.isNotEmpty ? status.project : _project;
    _apply(status);
    if (status.phase == TeamRuntimePhase.failed) {
      unawaited(_refreshLog());
    }
  }

  Future<void> _refreshLog() async {
    final log = await _runtime.logTail();
    if (mounted) setState(() => _appendLog(log));
  }

  Future<void> _startAgain() async {
    setState(() {
      _busy = true;
      _dispatchError = null;
    });
    try {
      final status = await _runtime.start();
      if (!mounted) return;
      if (status.isReady && !_connected) {
        await teamPhoneEnable(
          widget.connection,
          widget.profile,
          _runtime,
          status,
        );
        _connected = true;
      }
      _busy = false;
      _apply(status);
    } on TermuxBridgeException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _dispatchError = error.message;
        _view = _View.failed;
      });
    }
  }

  Future<void> _copyLog() => KitCopy.copy(context, _log);

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      _View.checking || _View.hidden => const SizedBox.shrink(),
      _View.offer => _offer(context),
      _View.steps => _steps(context),
      _View.success => _success(context),
      _View.failed => _failed(context),
      _View.killed => _killed(context),
    };
  }

  /// Every state sits on the one panel (KitSurface), its parts spaced by
  /// the kit's steps.
  Widget _card({required Key key, required List<Widget> children}) {
    return KeyedSubtree(
      key: key,
      child: KitSurface.panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _gap(BuildContext context) =>
      SizedBox(height: KitTokens.of(context).space3);

  Widget _offer(BuildContext context) {
    final l10n = _copy(context);
    return _card(
      key: const ValueKey('team-phone-offer'),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: KitChip(label: l10n.teamUiPhoneOptionalTag),
        ),
        _gap(context),
        KitText(l10n.teamUiPhoneOfferTitle, role: KitTextRole.rowTitle),
        SizedBox(height: KitTokens.of(context).space1),
        KitText(l10n.teamUiPhoneOfferBody),
        SizedBox(height: KitTokens.of(context).space1),
        KitText(
          l10n.teamUiPhoneOfferSize(teamPhoneDownloadMb(_manifest)),
          key: const ValueKey('team-phone-offer-size'),
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        ),
        _gap(context),
        KitNotice(
          key: const ValueKey('team-phone-offer-warning'),
          icon: AppIconography.warning,
          message: l10n.teamUiPhoneOfferWarning,
          liveRegion: false,
        ),
        _gap(context),
        // The team is optional and heavy: leaving it for now is the one
        // filled button, setting it up the outlined one.
        KitActionBlock(
          primary: KitAction(
            key: const ValueKey('team-phone-skip'),
            label: l10n.teamUiPhoneSkip,
            onPressed: _skip,
          ),
          secondary: KitAction(
            key: const ValueKey('team-phone-set-up'),
            label: l10n.teamUiPhoneSetUp,
            onPressed: _setUp,
          ),
        ),
      ],
    );
  }

  /// The five steps as rows on one group, each with its step mark.
  Widget _stepList(BuildContext context) {
    final l10n = _copy(context);
    final states = teamPhoneStepStates(_status, connected: _connected);
    final titles = {
      TeamPhoneStep.download: l10n.teamUiPhoneStepDownload,
      TeamPhoneStep.packages: l10n.teamUiPhoneStepPackages,
      TeamPhoneStep.city: l10n.teamUiPhoneStepCity,
      TeamPhoneStep.start: l10n.teamUiPhoneStepStart,
      TeamPhoneStep.connect: l10n.teamUiPhoneStepConnect,
    };
    return KitRowGroup(
      key: const ValueKey('team-phone-steps'),
      margin: EdgeInsets.zero,
      children: [
        for (final step in TeamPhoneStep.values)
          KitRow(
            key: ValueKey('team-phone-step-${step.name}'),
            leading: KitStatusMark(
              state: switch (states[step]!) {
                TeamPhoneStepState.idle => KitMarkState.waiting,
                TeamPhoneStepState.running => KitMarkState.working,
                TeamPhoneStepState.done => KitMarkState.done,
                TeamPhoneStepState.error => KitMarkState.failed,
              },
            ),
            title: titles[step]!,
            titleMaxLines: 2,
          ),
      ],
    );
  }

  Widget _terminal({required bool running}) => SetupTerminal(
    output: _log,
    running: running,
    controller: _logController,
    onCopy: _log.isEmpty ? null : _copyLog,
  );

  Widget _steps(BuildContext context) {
    final l10n = _copy(context);
    final running = _busy || _status.busy;
    final project = _project ?? _status.project;
    return _card(
      key: const ValueKey('team-phone-setup'),
      children: [
        KitText(l10n.teamUiPhoneSetupRunning, role: KitTextRole.rowTitle),
        if (project.isNotEmpty) ...[
          SizedBox(height: KitTokens.of(context).space1),
          KitText.mono(
            l10n.teamUiPhoneProjectLine(project),
            key: const ValueKey('team-phone-project'),
            tone: KitTextTone.secondary,
          ),
        ],
        _gap(context),
        _stepList(context),
        _gap(context),
        _terminal(running: running),
        SizedBox(height: KitTokens.of(context).space2),
        KitText(
          l10n.teamUiPhoneLeaveNote,
          key: const ValueKey('team-phone-leave-note'),
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        ),
        if (!running) ...[
          _gap(context),
          KitActionBlock(
            primary: KitAction(
              key: const ValueKey('team-phone-continue'),
              label: l10n.teamUiPhoneContinue,
              icon: AppIconography.play,
              onPressed: _resume,
            ),
          ),
        ],
      ],
    );
  }

  Widget _success(BuildContext context) {
    final l10n = _copy(context);
    return _card(
      key: const ValueKey('team-phone-success'),
      children: [
        KitNotice(
          key: const ValueKey('team-phone-success-title'),
          tone: AppStatusTone.ok,
          icon: AppIconography.checkCircle,
          title:
              '${l10n.teamUiPhoneSuccessTitle} · '
              '${l10n.teamUiPhoneAgentsReady(_status.agents ?? 0)}',
          message: l10n.teamUiPhoneOfferWarning,
        ),
        _gap(context),
        KitActionBlock(
          primary: KitAction(
            key: const ValueKey('team-phone-open-workspace'),
            label: l10n.teamUiPhoneOpenWorkspace,
            icon: AppIconography.forward,
            onPressed: widget.onOpenWorkspace,
          ),
        ),
      ],
    );
  }

  Widget _failed(BuildContext context) {
    final l10n = _copy(context);
    final dispatch = _dispatchError;
    return _card(
      key: const ValueKey('team-phone-failed'),
      children: [
        KitNotice.error(
          title: l10n.teamUiPhoneFailedTitle,
          message: dispatch != null
              ? '${l10n.teamUiPhoneDispatchFailed} $dispatch'
              : teamPhoneFailureText(l10n, _status),
          messageKey: const ValueKey('team-phone-failed-reason'),
        ),
        _gap(context),
        _stepList(context),
        _gap(context),
        _terminal(running: false),
        _gap(context),
        KitActionBlock(
          primary: KitAction(
            key: const ValueKey('team-phone-retry'),
            label: l10n.teamUiPhoneRetry,
            icon: AppIconography.retry,
            onPressed: _busy ? null : _retry,
          ),
        ),
      ],
    );
  }

  Widget _killed(BuildContext context) {
    final l10n = _copy(context);
    return _card(
      key: const ValueKey('team-phone-killed'),
      children: [
        KitNotice(
          icon: AppIconography.warning,
          message: l10n.teamUiPhoneKilled,
        ),
        _gap(context),
        KitActionBlock(
          primary: KitAction(
            key: const ValueKey('team-phone-start-again'),
            label: l10n.teamUiPhoneStartAgain,
            icon: AppIconography.play,
            onPressed: _busy ? null : _startAgain,
          ),
        ),
      ],
    );
  }
}

/// Picks one of the managed server's project folders (a tap chooses), or
/// names a new one when there are none. Pops with the chosen
/// `/root/projects/<name>`.
class _ProjectSheet extends StatefulWidget {
  const _ProjectSheet({required this.projects, required this.runtime});

  final List<String> projects;
  final TermuxTeamRuntime runtime;

  @override
  State<_ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends State<_ProjectSheet> {
  final _name = TextEditingController();
  String? _problem;
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final problem = projectFolderNameProblem(_name.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _creating = true;
      _problem = null;
    });
    try {
      final path = await widget.runtime.createManagedProject(_name.text);
      if (mounted) Navigator.of(context).pop(path);
    } on TermuxBridgeException catch (error) {
      if (mounted) {
        setState(() {
          _creating = false;
          _problem = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    return Column(
      key: const ValueKey('team-phone-project-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitText(
          widget.projects.isEmpty
              ? l10n.teamUiPhoneNoProjects(managedProjectsDirectory)
              : l10n.teamUiPhoneChooseProjectBody,
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        ),
        SizedBox(height: tokens.space3),
        if (widget.projects.isEmpty) ...[
          KitField(
            label: l10n.teamUiPhoneNewFolderLabel,
            controller: _name,
            kind: KitFieldKind.mono,
            autofocus: true,
            error: _problem,
            onSubmitted: (_) => _create(),
            fieldKey: const ValueKey('team-phone-new-folder'),
          ),
          SizedBox(height: tokens.space3),
          KitActionBlock(
            primary: KitAction(
              key: const ValueKey('team-phone-create-folder'),
              label: l10n.teamUiPhoneCreateAndContinue,
              working: _creating,
              onPressed: _creating ? null : _create,
            ),
          ),
        ] else
          // One answer: a tap chooses the folder and the sheet closes.
          KitChoiceList<String>.single(
            semanticsLabel: l10n.teamUiPhoneChooseProjectTitle,
            choices: [
              for (var i = 0; i < widget.projects.length; i++)
                KitChoice<String>(
                  key: ValueKey('team-phone-project-$i'),
                  value: widget.projects[i],
                  title: widget.projects[i].split('/').last,
                  supporting: widget.projects[i],
                ),
            ],
            selected: null,
            onSelected: (path) => Navigator.of(context).pop(path),
          ),
      ],
    );
  }
}
