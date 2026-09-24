/// The optional on-device AI Team step of the Termux setup (TEAM-302,
/// 03-onboarding-on-device §2): the "Also run an AI team on this phone"
/// block shown after step 3 succeeds, the five visible steps with the same
/// live output panel the OpenCode install uses, the success card and the
/// honest failure copy of §5.
///
/// Everything here reads and drives [TermuxTeamRuntime] (TEAM-301). The
/// runtime's state file is the truth: leaving the screen and coming back
/// resumes the view from `aiteam.sh status`, and a verb that finished while
/// the app was away shows as done. The block is absent (not disabled)
/// while [TermuxTeamRuntime.supportsAiTeam] is false.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/workspace_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/orchestration_store.dart';
import '../../state/profiles.dart';
import '../../termux/bridge.dart';
import '../../termux/team_runtime.dart';
import '../app_theme.dart';
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
      reason == 'download' ||
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
  if (reason == 'download' || reason.startsWith('manifest')) {
    return l10n.teamUiPhoneFailedDownload;
  }
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
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProjectSheet(projects: projects, runtime: _runtime),
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

  Future<void> _copyLog() async {
    final l10n = _copy(context);
    await Clipboard.setData(ClipboardData(text: _log));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(l10n.workCopied)));
  }

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

  Widget _card(
    BuildContext context, {
    required Key key,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _offer(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.mutedOf(theme),
      height: 1.4,
    );
    return _card(
      context,
      key: const ValueKey('team-phone-offer'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.teamUiPhoneOptionalTag,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 4),
          Text(l10n.teamUiPhoneOfferTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            l10n.teamUiPhoneOfferBody,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.teamUiPhoneOfferSize(teamPhoneDownloadMb(_manifest)),
            key: const ValueKey('team-phone-offer-size'),
            style: muted,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                AppIconography.warning,
                size: 18,
                color: AppTheme.statusColor(theme, AppStatusTone.attention),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.teamUiPhoneOfferWarning,
                  key: const ValueKey('team-phone-offer-warning'),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              FilledButton(
                key: const ValueKey('team-phone-skip'),
                onPressed: _skip,
                child: Text(l10n.teamUiPhoneSkip),
              ),
              OutlinedButton(
                key: const ValueKey('team-phone-set-up'),
                onPressed: _setUp,
                child: Text(l10n.teamUiPhoneSetUp),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
    return Column(
      key: const ValueKey('team-phone-steps'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final step in TeamPhoneStep.values)
          _StepRow(
            key: ValueKey('team-phone-step-${step.name}'),
            number: step.index + 1,
            title: titles[step]!,
            state: states[step]!,
          ),
      ],
    );
  }

  Widget _steps(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final running = _busy || _status.busy;
    final project = _project ?? _status.project;
    return _card(
      context,
      key: const ValueKey('team-phone-setup'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.teamUiPhoneSetupRunning,
            style: theme.textTheme.titleMedium,
          ),
          if (project.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.teamUiPhoneProjectLine(project),
              key: const ValueKey('team-phone-project'),
              textDirection: TextDirection.ltr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedOf(theme),
                fontFamily: AppTheme.monoFamily,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _stepList(context),
          const SizedBox(height: 12),
          SetupTerminal(
            output: _log,
            running: running,
            controller: _logController,
            onCopy: _log.isEmpty ? null : _copyLog,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.teamUiPhoneLeaveNote,
            key: const ValueKey('team-phone-leave-note'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedOf(theme),
            ),
          ),
          if (!running) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                key: const ValueKey('team-phone-continue'),
                onPressed: _resume,
                icon: const Icon(AppIconography.play),
                label: Text(l10n.teamUiPhoneContinue),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _success(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    return _card(
      context,
      key: const ValueKey('team-phone-success'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                AppIconography.checkCircle,
                size: 20,
                color: AppTheme.statusColor(theme, AppStatusTone.ok),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.teamUiPhoneSuccessTitle} · '
                  '${l10n.teamUiPhoneAgentsReady(_status.agents ?? 0)}',
                  key: const ValueKey('team-phone-success-title'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.teamUiPhoneOfferWarning,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedOf(theme),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              key: const ValueKey('team-phone-open-workspace'),
              onPressed: widget.onOpenWorkspace,
              icon: const Icon(AppIconography.forward),
              label: Text(l10n.teamUiPhoneOpenWorkspace),
            ),
          ),
        ],
      ),
    );
  }

  Widget _failed(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final dispatch = _dispatchError;
    return _card(
      context,
      key: const ValueKey('team-phone-failed'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.teamUiPhoneFailedTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dispatch != null
                ? '${l10n.teamUiPhoneDispatchFailed} $dispatch'
                : teamPhoneFailureText(l10n, _status),
            key: const ValueKey('team-phone-failed-reason'),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          _stepList(context),
          const SizedBox(height: 12),
          SetupTerminal(
            output: _log,
            running: false,
            controller: _logController,
            onCopy: _log.isEmpty ? null : _copyLog,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              key: const ValueKey('team-phone-retry'),
              onPressed: _busy ? null : _retry,
              icon: const Icon(AppIconography.retry),
              label: Text(l10n.teamUiPhoneRetry),
            ),
          ),
        ],
      ),
    );
  }

  Widget _killed(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    return _card(
      context,
      key: const ValueKey('team-phone-killed'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                AppIconography.warning,
                size: 20,
                color: AppTheme.statusColor(theme, AppStatusTone.attention),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.teamUiPhoneKilled,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              key: const ValueKey('team-phone-start-again'),
              onPressed: _busy ? null : _startAgain,
              icon: const Icon(AppIconography.play),
              label: Text(l10n.teamUiPhoneStartAgain),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.number,
    required this.title,
    required this.state,
  });

  final int number;
  final String title;
  final TeamPhoneStepState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Widget leading;
    final Color color;
    switch (state) {
      case TeamPhoneStepState.idle:
        color = AppTheme.mutedOf(theme);
        leading = Text(
          '$number',
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        );
      case TeamPhoneStepState.running:
        color = scheme.primary;
        leading = SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        );
      case TeamPhoneStepState.done:
        color = AppTheme.statusColor(theme, AppStatusTone.ok);
        leading = Icon(AppIconography.check, size: 18, color: color);
      case TeamPhoneStepState.error:
        color = scheme.error;
        leading = Icon(AppIconography.error, size: 18, color: color);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, height: 20, child: Center(child: leading)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: state == TeamPhoneStepState.idle
                    ? AppTheme.mutedOf(theme)
                    : scheme.onSurface,
                fontWeight: state == TeamPhoneStepState.running
                    ? FontWeight.w600
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks one of the managed server's project folders, or names a new one
/// when there are none. Pops with the chosen `/root/projects/<name>`.
class _ProjectSheet extends StatefulWidget {
  const _ProjectSheet({required this.projects, required this.runtime});

  final List<String> projects;
  final TermuxTeamRuntime runtime;

  @override
  State<_ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends State<_ProjectSheet> {
  late String? _selected = widget.projects.isEmpty
      ? null
      : widget.projects.first;
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
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const ValueKey('team-phone-project-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.teamUiPhoneChooseProjectTitle,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            widget.projects.isEmpty
                ? l10n.teamUiPhoneNoProjects(managedProjectsDirectory)
                : l10n.teamUiPhoneChooseProjectBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.mutedOf(theme),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.projects.isEmpty) ...[
            TextField(
              key: const ValueKey('team-phone-new-folder'),
              controller: _name,
              enabled: !_creating,
              autofocus: true,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l10n.teamUiPhoneNewFolderLabel,
                errorText: _problem,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('team-phone-create-folder'),
              onPressed: _creating ? null : _create,
              child: Text(l10n.teamUiPhoneCreateAndContinue),
            ),
          ] else ...[
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (value) => setState(() => _selected = value),
              child: Column(
                children: [
                  for (var i = 0; i < widget.projects.length; i++)
                    RadioListTile<String>(
                      key: ValueKey('team-phone-project-$i'),
                      contentPadding: EdgeInsets.zero,
                      value: widget.projects[i],
                      title: Text(
                        widget.projects[i].split('/').last,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        widget.projects[i],
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: AppTheme.monoFamily,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('team-phone-project-continue'),
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
              child: Text(l10n.teamUiPhoneContinue),
            ),
          ],
        ],
      ),
    );
  }
}
