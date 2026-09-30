/// "Turn on AI Team on this phone": the one-tap setup page.
///
/// Finish line: the person taps once and watches four real steps, each
/// with its own time and a tick: the reply finishes, OpenCode and the
/// terminals stop (only after a yes, in one line), the engine proves this
/// phone safe, OpenCode comes back protected. A failure says what happened
/// in plain words, keeps its technical text under Details and offers Start
/// again. Non-goal: the engine's own checks; this page only shows them.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../builtin/builtin_linux.dart' show BuiltinLinux;
import '../../../builtin/builtin_server.dart'
    show
        BuiltinServerStarter,
        builtinLinuxProvider,
        builtinServerStarterProvider;
import '../../../l10n/app_localizations.dart';
import '../../../state/connection.dart';
import '../../../state/phone_team_setup.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../kit/scenes/team_scenes.dart';
import 'team_page.dart' show TeamPage;

/// Opens the setup page. [autoStart] starts the run at once (the tap that
/// brought the person here was the start); the Work strip opens it without,
/// to show a run already going.
Future<void> openPhoneTeamSetup(
  BuildContext context,
  ConnectionController connection, {
  PhoneTeamSetupController? controller,
  bool autoStart = true,
}) => pushKitPage<void>(
  context,
  (_) => TeamPhoneSetupScreen(
    connection: connection,
    controller: controller,
    autoStart: autoStart,
  ),
);

/// The plain title and body of a failure; its technical text is Details.
({String title, String body}) phoneTeamProblemCopy(
  AppLocalizations l,
  PhoneTeamSetupProblem problem,
) => switch (problem) {
  PhoneTeamSetupProblem.unsafe => (
    title: l.phoneTeamFailUnsafeTitle,
    body: l.phoneTeamFailUnsafeBody,
  ),
  PhoneTeamSetupProblem.engine => (
    title: l.phoneTeamFailEngineTitle,
    body: l.phoneTeamFailEngineBody,
  ),
  PhoneTeamSetupProblem.stopFailed => (
    title: l.phoneTeamFailStopTitle,
    body: l.phoneTeamFailStopBody,
  ),
  PhoneTeamSetupProblem.serverStart => (
    title: l.phoneTeamFailServerTitle,
    body: l.phoneTeamFailServerBody,
  ),
  PhoneTeamSetupProblem.notReady => (
    title: l.phoneTeamFailNotReadyTitle,
    body: l.phoneTeamFailNotReadyBody,
  ),
  PhoneTeamSetupProblem.declined => (
    title: l.phoneTeamFailDeclinedTitle,
    body: l.phoneTeamFailDeclinedBody,
  ),
  PhoneTeamSetupProblem.noServer => (
    title: l.phoneTeamFailNoServerTitle,
    body: l.phoneTeamFailNoServerBody,
  ),
};

String _elapsed(AppLocalizations l, Duration d) => d.inSeconds < 60
    ? l.teamProjectElapsedSeconds(d.inSeconds < 0 ? 0 : d.inSeconds)
    : l.teamProjectElapsedMinutes(d.inMinutes);

String _stepTitle(AppLocalizations l, PhoneTeamSetupStep step) =>
    switch (step) {
      PhoneTeamSetupStep.reply => l.phoneTeamStepReply,
      PhoneTeamSetupStep.stop => l.phoneTeamStepStop,
      PhoneTeamSetupStep.check => l.phoneTeamStepCheck,
      PhoneTeamSetupStep.server => l.phoneTeamStepServer,
    };

/// One row per step; every mark comes from the controller's own signals.
List<KitStep> phoneTeamSetupSteps(
  AppLocalizations l,
  PhoneTeamSetupController c,
) => [
  for (final step in PhoneTeamSetupStep.values)
    () {
      final KitMarkState state;
      String? supporting;
      final took = c.took(step);
      final elapsed = c.elapsed(step);
      final failed =
          c.phase == PhoneTeamSetupPhase.failed && c.failedStep == step;
      if (failed) {
        state = KitMarkState.failed;
        if (step == PhoneTeamSetupStep.check &&
            c.problem == PhoneTeamSetupProblem.unsafe &&
            (c.details ?? '').contains('not_packaged')) {
          supporting = l.phoneTeamReasonNotPackaged;
        }
      } else if (took != null) {
        state = KitMarkState.done;
        supporting = c.wasSkipped(step)
            ? l.phoneTeamNotNeeded
            : l.aiteamComponentStageTook(_elapsed(l, took));
      } else if (elapsed != null) {
        state = KitMarkState.working;
        final words = switch (step) {
          PhoneTeamSetupStep.reply => l.phoneTeamReplyWaiting,
          PhoneTeamSetupStep.stop
              when c.phase == PhoneTeamSetupPhase.confirming =>
            l.phoneTeamStopWaiting,
          _ => null,
        };
        final time = l.aiteamComponentStageSoFar(_elapsed(l, elapsed));
        supporting = words == null ? time : '$words · $time';
      } else {
        state = KitMarkState.waiting;
      }
      return KitStep(
        key: ValueKey('phone-team-step-${step.name}'),
        title: _stepTitle(l, step),
        state: state,
        supporting: supporting,
      );
    }(),
];

class TeamPhoneSetupScreen extends StatefulWidget {
  const TeamPhoneSetupScreen({
    super.key,
    required this.connection,
    this.controller,
    this.autoStart = true,
  });

  final ConnectionController connection;

  /// The flow to show; the app's shared one by default, tests pass a fake.
  final PhoneTeamSetupController? controller;
  final bool autoStart;

  @override
  State<TeamPhoneSetupScreen> createState() => _TeamPhoneSetupScreenState();
}

class _TeamPhoneSetupScreenState extends State<TeamPhoneSetupScreen> {
  late PhoneTeamSetupController _flow;
  Timer? _tick;
  bool _asking = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    BuiltinLinux? linux;
    BuiltinServerStarter? starter;
    if (widget.controller == null) {
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        linux = container.read(builtinLinuxProvider);
        starter = container.read(builtinServerStarterProvider);
      } catch (_) {
        // No provider scope (a bare test): the flow builds its own.
      }
    }
    _flow =
        widget.controller ??
        PhoneTeamSetup.of(
          widget.connection,
          copy: AppLocalizations.of(context),
          linux: linux,
          starter: starter,
        );
    _flow.addListener(_changed);
    if (widget.autoStart && !_flow.isRunning && !_flow.isDone) {
      unawaited(_flow.run());
    }
    _changed();
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (_started) _flow.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    // One timer for the "so far" times, only while a run is going.
    if (_flow.isRunning) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _tick?.cancel();
      _tick = null;
    }
    if (_flow.phase == PhoneTeamSetupPhase.confirming && !_asking) {
      _asking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
    }
  }

  Future<void> _ask() async {
    if (!mounted) {
      _asking = false;
      return;
    }
    final l = AppLocalizations.of(context);
    final yes = await showKitConfirm(
      context,
      title: l.phoneTeamStopTitle,
      body: l.phoneTeamStopBody,
      confirmLabel: l.phoneTeamStopConfirm,
      cancelLabel: l.phoneTeamStopCancel,
      confirmKey: const ValueKey('phone-team-stop-confirm'),
    );
    _asking = false;
    _flow.answer(yes);
  }

  /// Ready: leave the stack of pages that held the old team and open the
  /// team fresh, so nothing keeps a stopped controller.
  void _openTeam() {
    final navigator = Navigator.of(context);
    final connection = widget.connection;
    navigator.popUntil((route) => route.isFirst);
    unawaited(
      navigator.push(
        KitPageRoute<void>(builder: (_) => TeamPage(connection: connection)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final steps = phoneTeamSetupSteps(l, _flow);
    final checklist = KitChecklist(
      checklistKey: const ValueKey('phone-team-steps'),
      steps: steps,
    );
    final Widget body;
    switch (_flow.phase) {
      case PhoneTeamSetupPhase.done:
        body = KitStateView(
          key: const ValueKey('phone-team-ready'),
          icon: AppIconography.checkCircle,
          tone: AppStatusTone.ok,
          title: l.phoneTeamDoneTitle,
          body: l.phoneTeamDoneBody,
          content: checklist,
          primary: KitAction(
            key: const ValueKey('phone-team-new-project'),
            label: l.teamProjectNew,
            onPressed: _openTeam,
          ),
        );
      case PhoneTeamSetupPhase.failed:
        final problem = _flow.problem ?? PhoneTeamSetupProblem.engine;
        final copy = phoneTeamProblemCopy(l, problem);
        final calm =
            problem == PhoneTeamSetupProblem.declined ||
            problem == PhoneTeamSetupProblem.noServer;
        final details = _flow.details;
        body = KitStateView(
          key: const ValueKey('phone-team-failed'),
          icon: calm ? AppIconography.phone : AppIconography.warning,
          tone: calm ? AppStatusTone.neutral : AppStatusTone.failure,
          title: copy.title,
          body: copy.body,
          content: problem == PhoneTeamSetupProblem.noServer ? null : checklist,
          primary: problem == PhoneTeamSetupProblem.noServer
              ? null
              : KitAction(
                  key: const ValueKey('phone-team-start-again'),
                  label: l.teamStartAgain,
                  icon: AppIconography.play,
                  onPressed: () => unawaited(_flow.run()),
                ),
          details: details == null || details.isEmpty || calm ? null : details,
        );
      case PhoneTeamSetupPhase.idle:
      case PhoneTeamSetupPhase.running:
      case PhoneTeamSetupPhase.confirming:
        final finished = steps
            .where((s) => s.state == KitMarkState.done)
            .length;
        final idle = _flow.phase == PhoneTeamSetupPhase.idle;
        body = KitStateView(
          key: const ValueKey('phone-team-running'),
          icon: AppIconography.waiting,
          tone: AppStatusTone.progress,
          illustration: const TeamWakingScene(),
          illustrationAmbient: true,
          title: l.phoneTeamSetupTitle,
          progress: KitProgress.known(finished / steps.length),
          content: checklist,
          primary: idle
              ? KitAction(
                  key: const ValueKey('phone-team-start'),
                  label: l.teamIntroTurnOnPhone,
                  icon: AppIconography.play,
                  onPressed: () => unawaited(_flow.run()),
                )
              : null,
        );
    }
    return KitScreen(
      topBar: KitTopBar(title: l.teamUiHomeTitle),
      width: KitScreenWidth.reading,
      body: body,
    );
  }
}
