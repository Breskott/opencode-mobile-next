import 'dart:async';

import 'package:flutter/material.dart';

import '../../../builtin/setup/phone_setup.dart';
import '../../../builtin/setup/setup_contract.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/product_states.dart' show productErrorText;
import 'phone_setup_routes.dart';

/// The first-run welcome's line about a phone setup that already exists.
///
/// Someone who started setting up OpenCode on this phone and then left (the
/// app killed, a reboot, a cancel) comes back to the welcome, because no
/// server is saved until setup ends. Without this line the welcome would ask
/// "where does your coding agent run?" as if nothing had happened, and the
/// way back to their 70%-done setup would be two screens deep. So:
///
/// - running: "Setting up OpenCode on this phone · 42%", opening its
///   progress;
/// - stopped part way: "Setup on this phone is 42% done" with Continue,
///   which resumes the same job (the checks skip what finished);
/// - done but nothing saved or connected: "OpenCode is ready on this phone"
///   with Open, which runs the job again so only its last step (start and
///   connect) happens.
///
/// With no job it shows nothing and the welcome keeps its three choices.
/// The job is read after the first frame, so the welcome never waits on it.
class PhoneSetupWelcomeEntry extends StatefulWidget {
  const PhoneSetupWelcomeEntry({
    super.key,
    this.engine,
    this.openProgress = _openFirstSetupProgress,
    this.restoreTimeout = const Duration(seconds: 3),
    this.revision = 0,
  });

  /// Bumped by the host when the person comes back from phone setup, where
  /// a job may have started: the job is read again.
  final int revision;

  /// Tests pass a fake; the app uses [PhoneSetup.engine].
  final SetupEngine? engine;

  /// Screen B as a first setup: the welcome only shows while nothing is
  /// saved, so whatever it continues is this phone's first setup.
  final Future<void> Function(BuildContext context) openProgress;

  /// How long the job read may take before the line gives up; a hung
  /// channel must never leave a spinner on the welcome.
  final Duration restoreTimeout;

  @override
  State<PhoneSetupWelcomeEntry> createState() => _PhoneSetupWelcomeEntryState();
}

class _PhoneSetupWelcomeEntryState extends State<PhoneSetupWelcomeEntry> {
  late final SetupEngine _engine = widget.engine ?? PhoneSetup.engine;

  /// Until the persisted job is read, an in-memory "done" may be stale, so
  /// nothing is offered.
  bool _restored = false;
  bool _busy = false;
  String? _failure;

  /// Gives up waiting on a read that hangs. Owned (not a `Future.timeout`)
  /// so leaving the welcome cancels it.
  Timer? _giveUp;

  @override
  void initState() {
    super.initState();
    _giveUp = Timer(widget.restoreTimeout, _showWhatIsKnown);
    unawaited(_restore());
  }

  @override
  void didUpdateWidget(PhoneSetupWelcomeEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) unawaited(_restore());
  }

  @override
  void dispose() {
    _giveUp?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      await _engine.restore();
    } catch (_) {
      // No job, or no channel (desktop, tests): the welcome stays as it is.
    }
    _showWhatIsKnown();
  }

  void _showWhatIsKnown() {
    _giveUp?.cancel();
    _giveUp = null;
    // Always rebuilt: a read after coming back may have found a new job.
    if (mounted) setState(() => _restored = true);
  }

  /// The job's own components, so Continue resumes that job rather than a
  /// guess; the registry defaults only when the job listed none.
  Set<String> _selection(SetupProgress progress) {
    if (progress.components.isNotEmpty) {
      return {for (final component in progress.components) component.id};
    }
    return {
      for (final component in _engine.registry)
        if (component.required || component.defaultOn) component.id,
    };
  }

  Future<void> _resume(SetupProgress progress) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await _engine.run(
        _selection(progress),
        params: SetupJobParams.firstSetup,
      );
    } catch (error) {
      if (!mounted) return;
      final l10n = lookupAppLocalizations(Localizations.localeOf(context));
      setState(() {
        _busy = false;
        _failure = l10n.phoneSetupStartFailed(productErrorText(error));
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await widget.openProgress(context);
  }

  @override
  Widget build(BuildContext context) {
    // Watching the engine's progress makes it poll the native job, so the
    // welcome watches only once a job is known to exist: an untouched first
    // run costs one read, not a poll every half second.
    if (!_restored || _engine.progress.value.state == SetupState.idle) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<SetupProgress>(
      valueListenable: _engine.progress,
      builder: _line,
    );
  }

  Widget _line(BuildContext context, SetupProgress progress, Widget? _) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    // Never "100%" while it is still going: the last step (starting
    // OpenCode) has no bar of its own. Same rule as screen A.
    final percent = (progress.overall * 100).floor().clamp(0, 99);
    final String title;
    final String? detail;
    final String action;
    final VoidCallback onPressed;
    final double? meter;
    switch (progress.state) {
      case SetupState.idle:
        return const SizedBox.shrink();
      case SetupState.running:
        title = l10n.phoneSetupOpenWelcomeRunning(percent);
        detail = l10n.phoneSetupStartRunningBody;
        action = l10n.phoneSetupOpenWelcomeShowProgress;
        onPressed = () => unawaited(widget.openProgress(context));
        meter = progress.overall;
      case SetupState.interrupted:
      case SetupState.failed:
      case SetupState.cancelled:
        title = l10n.phoneSetupOpenWelcomeStopped(percent);
        detail = l10n.phoneSetupOpenWelcomeStoppedDetail;
        action = l10n.phoneSetupOpenWelcomeContinue;
        onPressed = () => unawaited(_resume(progress));
        meter = progress.overall;
      case SetupState.done:
        // Done, yet the welcome shows, so no server is saved: the job's
        // last step (save, start and connect) is what is missing, and
        // running the job again redoes only that.
        title = l10n.phoneSetupStartReadyHeadline;
        detail = null;
        action = l10n.phoneSetupStartOpen;
        onPressed = () => unawaited(_resume(progress));
        meter = null;
    }
    return _EntryLine(
      key: ValueKey('welcome-phone-setup-${progress.state.name}'),
      title: title,
      detail: detail,
      action: action,
      meter: meter,
      state: progress.state,
      busy: _busy,
      failure: _failure,
      onPressed: onPressed,
    );
  }
}

/// The line as an inline [KitStateView] (design standard §3): the phone icon
/// in its tonal circle, the one sentence of where setup stands, its bar, and
/// the one button, on the welcome's own rails.
class _EntryLine extends StatelessWidget {
  const _EntryLine({
    super.key,
    required this.title,
    required this.detail,
    required this.action,
    required this.meter,
    required this.state,
    required this.busy,
    required this.failure,
    required this.onPressed,
  });

  final String title;
  final String? detail;
  final String action;
  final double? meter;
  final SetupState state;
  final bool busy;
  final String? failure;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final running = state == SetupState.running;
    final failure = this.failure;
    final tone = failure != null
        ? AppStatusTone.failure
        : switch (state) {
            SetupState.running => AppStatusTone.progress,
            SetupState.done => AppStatusTone.ok,
            _ => AppStatusTone.attention,
          };
    final meter = this.meter;
    return KitStateView(
      size: KitStateSize.inline,
      padding: const EdgeInsets.only(bottom: 24),
      icon: AppIconography.phone,
      tone: tone,
      title: title,
      titleKey: const ValueKey('welcome-phone-setup-title'),
      body: failure ?? detail,
      bodyKey: failure != null
          ? const ValueKey('welcome-phone-setup-failure')
          : null,
      // Announced while it moves; a stopped line waits to be read.
      liveRegion: running,
      progress: meter == null
          ? null
          : KitProgress.known(
              meter.clamp(0, 1).toDouble(),
              tone: running ? null : AppStatusTone.neutral,
            ),
      primary: KitAction(
        key: const ValueKey('welcome-phone-setup-action'),
        label: action,
        onPressed: busy ? null : onPressed,
        working: busy,
      ),
    );
  }
}

Future<void> _openFirstSetupProgress(BuildContext context) =>
    openPhoneSetupProgress(context, firstSetup: true);
