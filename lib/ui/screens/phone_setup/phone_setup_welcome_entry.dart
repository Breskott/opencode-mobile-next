import 'dart:async';

import 'package:flutter/material.dart';

import '../../../builtin/setup/phone_setup.dart';
import '../../../builtin/setup/setup_contract.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_theme.dart';
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
      running: progress.state == SetupState.running,
      busy: _busy,
      failure: _failure,
      onPressed: onPressed,
    );
  }
}

/// Lines, not boxes: a tinted strip with the words, a thin meter and one
/// button, the same weight as the detected-server entry above the question.
class _EntryLine extends StatelessWidget {
  const _EntryLine({
    super.key,
    required this.title,
    required this.detail,
    required this.action,
    required this.meter,
    required this.running,
    required this.busy,
    required this.failure,
    required this.onPressed,
  });

  final String title;
  final String? detail;
  final String action;
  final double? meter;
  final bool running;
  final bool busy;
  final String? failure;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 2, end: 12),
                child: Icon(
                  AppIconography.phone,
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: running,
                      child: Text(
                        title,
                        key: const ValueKey('welcome-phone-setup-title'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (meter != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: meter!.clamp(0, 1).toDouble(),
                minHeight: 4,
                color: running ? theme.colorScheme.primary : muted,
                backgroundColor: AppTheme.hairline(theme),
              ),
            ),
          ],
          if (failure != null) ...[
            const SizedBox(height: 8),
            Text(
              failure!,
              key: const ValueKey('welcome-phone-setup-failure'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('welcome-phone-setup-action'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: busy ? null : onPressed,
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(action, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

Future<void> _openFirstSetupProgress(BuildContext context) =>
    openPhoneSetupProgress(context, firstSetup: true);
