import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../builtin/setup/setup_contract.dart';
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'terminal_view.dart';

/// The progress of any setup job: one overall bar, a checklist of the job's
/// components, and the live log behind "Show details"
/// (docs/design/phone-setup-v2-2026-09-24.md, goal 3).
///
/// It knows nothing about where it is shown: no Scaffold, no navigation, no
/// engine. First setup hosts it on screen B; "Add tools", updates and AI
/// Team's own install host the same widget with their own [progress]. Every
/// number it draws comes straight from [progress]; where a component reports
/// only stages it says what is happening and shows an indeterminate line,
/// never an estimate dressed up as a measurement.
class SetupProgressView extends StatefulWidget {
  const SetupProgressView({
    super.key,
    required this.progress,
    required this.components,
    this.onContinue,
    this.onCancel,
    this.note,
  });

  final SetupProgress progress;

  /// Where row titles come from. Before the job reports its own components
  /// (the first poll after `run`), these are listed as pending so the
  /// screen never opens empty.
  final List<SetupComponent> components;

  /// "Continue setup" after a failure, an interruption or a cancel. Hidden
  /// when null.
  final VoidCallback? onContinue;

  /// Offered only while the job runs. The host decides whether to confirm.
  final VoidCallback? onCancel;

  /// One quiet line under the checklist while the job runs; the host's own
  /// words ("You can leave the app…"), since only it knows what leaving means.
  final String? note;

  /// Network trouble as curl, apt and the resolver word it. Matched so the
  /// person is told to reconnect instead of being shown a curl exit code.
  static final networkError = RegExp(
    r'could not resolve|resolve host|name resolution|temporary failure resolving'
    r'|\bdns\b|network is unreachable|no route to host|failed to connect'
    r'|connection (?:refused|timed out|reset)|couldn.t connect'
    r'|curl: \((?:6|7|28|35|52|56)\)|operation timed out|unable to connect'
    r'|no internet|offline',
    caseSensitive: false,
  );

  /// Formats a byte pair in the total's unit ("18 of 30 MB"). The done
  /// figure is rounded down so the row never claims more than has arrived.
  static (String done, String total) formatBytePair(int done, int total) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var unit = 0;
    var scale = 1.0;
    while (unit < units.length - 1 && total >= scale * 1000) {
      scale *= 1000;
      unit++;
    }
    final decimals = unit == 0 || total / scale >= 10 ? 0 : 1;
    String fixed(double value, {required bool down}) {
      final factor = math.pow(10, decimals);
      final rounded = down
          ? (value * factor).floor() / factor
          : (value * factor).round() / factor;
      return rounded.toStringAsFixed(decimals);
    }

    return (
      fixed(done.clamp(0, total) / scale, down: true),
      '${fixed(total / scale, down: false)} ${units[unit]}',
    );
  }

  @override
  State<SetupProgressView> createState() => _SetupProgressViewState();
}

class _SetupProgressViewState extends State<SetupProgressView> {
  /// The furthest the bar has been in this job. The engine's figure can dip
  /// (a component's weight re-estimated, a stage restarting its bytes); the
  /// bar must not, or it reads as setup going backwards.
  double _furthest = 0;
  String _jobKey = '';

  /// Bumped when a new job starts, so the bar restarts from its value
  /// instead of easing backwards from the old job's end.
  int _generation = 0;
  bool _details = false;

  @override
  void initState() {
    super.initState();
    _jobKey = _keyOf(widget.progress);
    _furthest = widget.progress.overall.clamp(0, 1).toDouble();
  }

  @override
  void didUpdateWidget(SetupProgressView old) {
    super.didUpdateWidget(old);
    final next = widget.progress;
    final key = _keyOf(next);
    // The contract carries no job id, so a job is its set of components; a
    // fresh start after a finished (or never-started) job is also new, as
    // when an update re-runs the same component.
    final restarted =
        next.state == SetupState.running &&
        (old.progress.state == SetupState.done ||
            old.progress.state == SetupState.idle);
    if (key != _jobKey || restarted) {
      _jobKey = key;
      _generation++;
      _furthest = next.overall.clamp(0, 1).toDouble();
    } else {
      _furthest = math.max(_furthest, next.overall.clamp(0, 1).toDouble());
    }
  }

  static String _keyOf(SetupProgress progress) =>
      progress.components.map((c) => c.id).join(',');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final progress = widget.progress;
    final rows = progress.components.isNotEmpty
        ? progress.components
        : [
            for (final component in widget.components)
              ComponentProgress(
                id: component.id,
                state: ComponentState.pending,
              ),
          ];
    final failed = progress.state == SetupState.failed;
    final running =
        progress.state == SetupState.running ||
        progress.state == SetupState.idle;
    final network = failed && _looksLikeNetwork(progress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _OverallBar(
          key: ValueKey('setup-progress-bar-$_generation'),
          value: _furthest,
          failed: failed,
          reduceMotion: reduceMotion,
          semanticsLabel: l10n.setupProgressViewOverallLabel,
        ),
        const SizedBox(height: 10),
        Text(
          _statusLine(l10n, progress),
          key: const Key('setup-progress-status'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: failed ? theme.colorScheme.error : AppTheme.mutedOf(theme),
          ),
        ),
        const SizedBox(height: 20),
        for (final row in rows)
          _ComponentRow(
            key: ValueKey('setup-progress-row-${row.id}'),
            row: row,
            title: _titleOf(row.id),
            failure: row.state == ComponentState.failed
                ? _failureText(l10n, progress, row, network)
                : null,
            reduceMotion: reduceMotion,
          ),
        if (failed && !rows.any((r) => r.state == ComponentState.failed))
          // A job can fail between components (the server start after the
          // last install); say why even though no row carries it.
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              network
                  ? l10n.setupProgressViewNoInternet
                  : (progress.error ?? l10n.setupProgressViewFailedUnknown),
              key: const Key('setup-progress-job-error'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (running && widget.note != null) ...[
          const SizedBox(height: 20),
          Text(
            widget.note!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.mutedOf(theme),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (progress.canContinue && widget.onContinue != null) ...[
          FilledButton(
            key: const Key('setup-progress-continue'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: widget.onContinue,
            child: Text(l10n.setupProgressViewContinue),
          ),
          const SizedBox(height: 4),
        ],
        _actions(l10n, running),
        _detailsPanel(l10n, progress.logTail, reduceMotion),
      ],
    );
  }

  Widget _actions(AppLocalizations l10n, bool running) {
    final toggle = TextButton.icon(
      key: const Key('setup-progress-details'),
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: () => setState(() => _details = !_details),
      icon: Icon(
        _details ? AppIconography.chevronUp : AppIconography.chevronDown,
        size: AppIconography.inlineSize,
      ),
      label: Text(
        _details
            ? l10n.setupProgressViewHideDetails
            : l10n.setupProgressViewShowDetails,
      ),
    );
    final cancel = running && widget.onCancel != null
        ? TextButton(
            key: const Key('setup-progress-cancel'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: widget.onCancel,
            child: Text(l10n.setupProgressViewCancel),
          )
        : null;
    // Wrap rather than Row: at 2.5x text on a 320dp phone the two labels do
    // not fit side by side, and Cancel drops under the toggle instead of
    // clipping. spaceBetween keeps Cancel at the trailing edge otherwise.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [toggle, ?cancel],
    );
  }

  Widget _detailsPanel(AppLocalizations l10n, String log, bool reduceMotion) {
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.topStart,
      child: !_details
          ? const SizedBox(width: double.infinity)
          : Padding(
              key: const Key('setup-progress-log'),
              padding: const EdgeInsets.only(top: 4),
              child: log.trim().isEmpty
                  ? Text(
                      l10n.setupProgressViewNoLog,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedOf(theme),
                      ),
                    )
                  // Logs are left-to-right whatever the app's direction;
                  // flipping them would scramble paths and flags.
                  : Directionality(
                      textDirection: TextDirection.ltr,
                      // Tail-first: each new poll re-renders the last lines,
                      // so the panel follows the output without scrolling.
                      child: TerminalView(output: log.trimRight()),
                    ),
            ),
    );
  }

  String _titleOf(String id) {
    for (final component in widget.components) {
      if (component.id == id) return component.shortTitle;
    }
    return id;
  }

  String _statusLine(AppLocalizations l10n, SetupProgress progress) {
    switch (progress.state) {
      case SetupState.done:
        return l10n.setupProgressViewDone;
      case SetupState.failed:
        return l10n.setupProgressViewFailedTitle;
      case SetupState.interrupted:
        return l10n.setupProgressViewInterrupted;
      case SetupState.cancelled:
        return l10n.setupProgressViewCancelled;
      case SetupState.idle:
      case SetupState.running:
        final eta = progress.etaSeconds;
        if (eta == null) return l10n.setupProgressViewGettingStarted;
        if (eta < 60) return l10n.setupProgressViewUnderMinute;
        return l10n.setupProgressViewMinutesLeft((eta / 60).round());
    }
  }

  String _failureText(
    AppLocalizations l10n,
    SetupProgress progress,
    ComponentProgress row,
    bool network,
  ) {
    if (network) return l10n.setupProgressViewNoInternet;
    final reason = row.error ?? progress.error;
    final stage = row.stage;
    if (reason != null && stage != null) {
      return l10n.setupProgressViewFailedStageReason(stage, reason);
    }
    if (reason != null) return reason;
    if (stage != null) return l10n.setupProgressViewFailedDuring(stage);
    return l10n.setupProgressViewFailedUnknown;
  }

  /// Errors first, then the end of the log: a failed download often exits
  /// with a bare code while the log's last lines hold curl's own words.
  static bool _looksLikeNetwork(SetupProgress progress) {
    final lines = progress.logTail.trimRight().split('\n');
    final tail = lines.sublist(math.max(0, lines.length - 6)).join('\n');
    final texts = [
      progress.error,
      for (final c in progress.components)
        if (c.state == ComponentState.failed) c.error,
      tail,
    ];
    return texts.any(
      (text) => text != null && SetupProgressView.networkError.hasMatch(text),
    );
  }
}

/// The overall bar. It eases towards [value]; the host keeps [value] from
/// ever going backwards, and a new job gets a new key so the bar starts
/// from the new job's value rather than sliding back.
class _OverallBar extends StatelessWidget {
  const _OverallBar({
    super.key,
    required this.value,
    required this.failed,
    required this.reduceMotion,
    required this.semanticsLabel,
  });

  final double value;
  final bool failed;
  final bool reduceMotion;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A calm red: the error role, softened, so a failure reads as "stopped"
    // rather than an alarm.
    final color = failed
        ? theme.colorScheme.error.withValues(alpha: .75)
        : theme.colorScheme.primary;
    return TweenAnimationBuilder<double>(
      // Only `end`: the first build draws the value as is; later values
      // ease from wherever the bar is.
      tween: Tween<double>(end: value),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => LinearProgressIndicator(
        key: const Key('setup-progress-overall'),
        value: shown,
        minHeight: 6,
        borderRadius: BorderRadius.circular(3),
        color: color,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        semanticsLabel: semanticsLabel,
        // No localized value: Android reads a progress bar's value as a
        // number, and the default (the drawn percent) is what it can parse;
        // an Arabic percent sign there fails semantics validation.
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    super.key,
    required this.row,
    required this.title,
    required this.failure,
    required this.reduceMotion,
  });

  final ComponentProgress row;
  final String title;
  final String? failure;
  final bool reduceMotion;

  bool get _active =>
      row.state == ComponentState.running ||
      row.state == ComponentState.checking;

  bool get _finished =>
      row.state == ComponentState.done || row.state == ComponentState.skipped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final muted = AppTheme.mutedOf(theme);
    final detail = _detail(l10n);
    final stageOnly = _active && row.fraction == null;

    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      color: row.state == ComponentState.pending ? muted : null,
      fontWeight: _active ? FontWeight.w600 : null,
    );
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, height: 24, child: Center(child: _icon(theme))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title and detail share a line when they fit; with large
                // text the detail wraps under the title instead of
                // squeezing it. spaceBetween puts the detail at the
                // trailing edge in either direction.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(title, style: titleStyle),
                    if (detail != null)
                      Text(
                        detail,
                        key: Key('setup-progress-detail-${row.id}'),
                        style: detailStyle,
                      ),
                  ],
                ),
                if (stageOnly)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: reduceMotion
                        // A still line: something is happening, with no
                        // motion and no invented amount.
                        ? Container(
                            key: const Key('setup-progress-stage-line'),
                            height: 2,
                            color: theme.colorScheme.primary.withValues(
                              alpha: .35,
                            ),
                          )
                        : LinearProgressIndicator(
                            key: const Key('setup-progress-stage-line'),
                            minHeight: 2,
                            borderRadius: BorderRadius.circular(1),
                            backgroundColor: Colors.transparent,
                          ),
                  ),
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      failure!,
                      key: Key('setup-progress-error-${row.id}'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // The label changes with the stage or the state, not with each byte, so
    // the live region speaks when setup moves on rather than twice a second.
    // Byte and percent figures ride on the value, read on focus only.
    final state = switch (row.state) {
      ComponentState.done ||
      ComponentState.skipped => l10n.setupProgressViewStateDone,
      ComponentState.running ||
      ComponentState.checking => l10n.setupProgressViewStateRunning,
      ComponentState.pending => l10n.setupProgressViewStatePending,
      ComponentState.failed => l10n.setupProgressViewStateFailed,
    };
    final label = [
      title,
      state,
      if (_active && row.stage != null) row.stage!,
      ?failure,
      if (_finished && row.version != null) row.version!,
    ].join(', ');
    return Semantics(
      container: true,
      liveRegion: _active || row.state == ComponentState.failed,
      label: label,
      value: _active && row.fraction != null ? _measured(l10n) : null,
      child: ExcludeSemantics(child: content),
    );
  }

  /// The right-hand text, from the row's own signal only.
  String? _detail(AppLocalizations l10n) {
    if (_finished) return row.version;
    if (row.state == ComponentState.failed) return null;
    if (!_active) return null;
    final measured = _measured(l10n);
    final stage =
        row.stage ??
        (row.state == ComponentState.checking
            ? l10n.setupProgressViewChecking
            : null);
    if (measured != null && stage != null) {
      return l10n.setupProgressViewStageMeasured(stage, measured);
    }
    return measured ?? stage ?? l10n.setupProgressViewStarting;
  }

  String? _measured(AppLocalizations l10n) {
    final total = row.bytesTotal;
    final done = row.bytesDone;
    if (total != null && total > 0 && done != null) {
      final (d, t) = SetupProgressView.formatBytePair(done, total);
      return l10n.setupProgressViewBytes(d, t);
    }
    if (row.percent case final percent?) {
      return l10n.setupProgressViewPercent(percent.clamp(0, 100).floor());
    }
    return null;
  }

  Widget _icon(ThemeData theme) {
    final Widget icon = switch (row.state) {
      ComponentState.done || ComponentState.skipped => Icon(
        AppIconography.check,
        key: const ValueKey('done'),
        size: AppIconography.inlineSize,
        color: AppTheme.successOf(theme),
      ),
      ComponentState.running || ComponentState.checking =>
        reduceMotion
            ? Icon(
                AppIconography.statusDot,
                key: const ValueKey('running'),
                size: 12,
                color: theme.colorScheme.primary,
              )
            : const SizedBox(
                key: ValueKey('running'),
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      ComponentState.failed => Icon(
        AppIconography.error,
        key: const ValueKey('failed'),
        size: AppIconography.inlineSize,
        color: theme.colorScheme.error,
      ),
      ComponentState.pending => Container(
        key: const ValueKey('pending'),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.mutedOf(theme), width: 1.5),
        ),
      ),
    };
    // The check "lands" (a short scale and fade) as a row completes. It is
    // the switch between states that animates, so rows already done when
    // the view opens appear still.
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 280),
      // No overshooting curve: the fade's opacity must stay within 0..1.
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .6, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(
          '${row.id}-${_finished ? ComponentState.done : row.state}',
        ),
        child: icon,
      ),
    );
  }
}
