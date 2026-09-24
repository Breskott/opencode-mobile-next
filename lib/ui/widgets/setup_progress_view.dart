import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../builtin/setup/components.dart' show SetupComponentIds;
import '../../builtin/setup/setup_contract.dart';
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import '../kit/scenes/setup_steps_scene.dart';
import 'terminal_view.dart';

/// The progress of any setup job as one state (design standard §3, §4,
/// §10): a drawing of the journey (cloud, parcel, phone) lit as far as the
/// job has come, a title that says where the job stands, one overall bar
/// with one line under it, a checklist of the job's components, the one
/// action that fits (Continue setup, or Cancel while it runs) and the live
/// log under "Details" (docs/design/phone-setup-v2-2026-09-24.md, goal 3).
///
/// With room, the head (drawing, title, bar) stays put while the steps and
/// the log scroll under it; the log is one box, one line per line (design
/// regressions ledger row 16).
///
/// It knows nothing about where it is shown: no Scaffold, no navigation, no
/// engine. First setup hosts it on screen B; "Add tools" and updates host
/// the same widget with their own [progress] and [title]. Every number it
/// draws comes straight from [progress]; where a component reports only
/// stages it says what is happening, never an estimate dressed up as a
/// measurement.
class SetupProgressView extends StatefulWidget {
  const SetupProgressView({
    super.key,
    required this.progress,
    required this.components,
    this.onContinue,
    this.onCancel,
    this.note,
    this.title,
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

  /// One quiet line under the title while the job runs; the host's own
  /// words ("You can leave the app…"), since only it knows what leaving means.
  final String? note;

  /// What the job is, while it runs or has just finished ("Setting up
  /// OpenCode on this phone", "Adding Python"). A stopped or failed job says
  /// that instead, so the title never contradicts the bar.
  final String? title;

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

  /// The drawing of [progress] (design standard §10): which part of the
  /// journey is lit, how many components are in, and whether it stands
  /// still. [rows] defaults to the job's own components; setup start draws
  /// the same scene for a job that runs or stopped part way.
  static SetupStepsScene sceneFor(
    AppLocalizations l10n,
    SetupProgress progress, [
    List<ComponentProgress>? rows,
  ]) {
    final list = rows ?? progress.components;
    return SetupStepsScene(
      stage: _SetupProgressViewState._stageOf(l10n, progress, list),
      done: list
          .where(
            (r) =>
                r.state == ComponentState.done ||
                r.state == ComponentState.skipped,
          )
          .length,
      total: list.length,
      fraction: _SetupProgressViewState._fractionOf(list),
      halted: switch (progress.state) {
        SetupState.failed => SetupSceneHalt.failed,
        SetupState.interrupted || SetupState.cancelled => SetupSceneHalt.paused,
        _ => null,
      },
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

  /// True for the one update in which a new job started: the bar takes the
  /// new job's value at once instead of easing backwards from the old end.
  bool _jump = false;

  /// The live log under "Details", folded until asked for.
  bool _detailsOpen = false;
  final _logKey = GlobalKey();

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
    // A new job id (or, without one, a new set of components) is a new job;
    // so is a fresh start after a finished or never-started one.
    final restarted =
        next.state == SetupState.running &&
        (old.progress.state == SetupState.done ||
            old.progress.state == SetupState.idle);
    _jump = key != _jobKey || restarted;
    if (_jump) {
      _jobKey = key;
      _furthest = next.overall.clamp(0, 1).toDouble();
    } else {
      _furthest = math.max(_furthest, next.overall.clamp(0, 1).toDouble());
    }
  }

  // The engine names each job; the component list is only the fallback for
  // hosts whose progress carries no id.
  static String _keyOf(SetupProgress progress) =>
      progress.jobId ?? progress.components.map((c) => c.id).join(',');

  @override
  Widget build(BuildContext context) {
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
    final stopped =
        progress.state == SetupState.interrupted ||
        progress.state == SetupState.cancelled;
    final done = progress.state == SetupState.done;
    final running = !failed && !stopped && !done;
    final network = failed && _looksLikeNetwork(progress);
    final title = widget.title ?? l10n.phoneSetupProgressTitle;

    // The drawing at the head says the same as the title and the rows, so
    // it stays decorative (design standard §10).
    final scene = SetupProgressView.sceneFor(l10n, progress, rows);

    // A job can fail between components (the server start after the last
    // install): the body says why even though no row carries it.
    final String? body;
    Key? bodyKey;
    if (failed) {
      if (rows.any((r) => r.state == ComponentState.failed)) {
        body = null;
      } else {
        body = network
            ? l10n.setupProgressViewNoInternet
            : (progress.error ?? l10n.setupProgressViewFailedUnknown);
        bodyKey = const Key('setup-progress-job-error');
      }
    } else if (stopped) {
      body = progress.state == SetupState.interrupted
          ? l10n.setupProgressViewInterrupted
          : l10n.setupProgressViewCancelled;
    } else if (running) {
      body = widget.note;
    } else {
      body = null;
    }

    final checklist = Column(
      key: const Key('setup-progress-checklist'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
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
      ],
    );

    final theme = Theme.of(context);
    final actions = KitActionBlock(
      primary: progress.canContinue && widget.onContinue != null
          ? KitAction(
              key: const Key('setup-progress-continue'),
              label: l10n.setupProgressViewContinue,
              onPressed: widget.onContinue,
            )
          : null,
      tertiary: [
        if (running && widget.onCancel != null)
          KitAction(
            key: const Key('setup-progress-cancel'),
            label: l10n.setupProgressViewCancel,
            onPressed: widget.onCancel,
            destructive: true,
          ),
      ],
    );

    // What the job is made of and what can be done about it; under a
    // hairline, the technical Details, folded (design standard §3.6).
    final steps = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        checklist,
        if (!actions.isEmpty) ...[const SizedBox(height: 12), actions],
        const SizedBox(height: 16),
        Divider(height: 1, color: AppTheme.hairline(theme)),
        const SizedBox(height: 8),
        KitInset(
          child: TextButton.icon(
            key: const Key('setup-progress-details'),
            onPressed: _toggleDetails,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.mutedOf(theme),
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(
                horizontal: KitButton.tertiaryInset,
              ),
            ),
            icon: Icon(
              _detailsOpen
                  ? AppIconography.chevronUp
                  : AppIconography.chevronDown,
              size: 18,
            ),
            label: Text(
              _detailsOpen ? l10n.e7SetupHideDetails : l10n.e7SetupDetails,
            ),
          ),
        ),
        if (_detailsOpen) _logPanel(context, l10n, progress),
      ],
    );

    // The bar eases towards the furthest point; the first build and a new
    // job draw the value as is.
    final head = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _furthest),
      duration: reduceMotion || _jump
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => _Head(
        scene: scene,
        ambient: running,
        title: failed || stopped ? l10n.setupProgressViewFailedTitle : title,
        body: body,
        bodyKey: bodyKey,
        progress: KitProgress.known(
          shown,
          key: const Key('setup-progress-overall'),
          tone: failed
              ? AppStatusTone.failure
              : stopped
              ? AppStatusTone.neutral
              : null,
          semanticsLabel: l10n.setupProgressViewOverallLabel,
          caption: running || done ? _timeLine(l10n, progress) : null,
        ),
      ),
    );

    final bottom = 16 + MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The title and the bar stay in view while the steps and the log
        // scroll under them (ledger row 16), when there is room for that:
        // on a short screen or at large text everything scrolls together,
        // so the head never takes the screen.
        final pinned =
            constraints.hasBoundedHeight &&
            constraints.maxHeight >= 560 &&
            MediaQuery.textScalerOf(context).scale(14) <= 14 * 1.3;
        if (!pinned) {
          return SingleChildScrollView(
            key: const Key('setup-progress-scroll'),
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [head, const SizedBox(height: 20), steps],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              key: const Key('setup-progress-head'),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: head,
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('setup-progress-scroll'),
                padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
                child: steps,
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleDetails() {
    setState(() => _detailsOpen = !_detailsOpen);
    if (!_detailsOpen) return;
    // Opening the log brings it into view, under the head that stays.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final panel = _logKey.currentContext;
      if (panel == null || !panel.mounted) return;
      Scrollable.ensureVisible(
        panel,
        alignment: 1,
        duration: MediaQuery.disableAnimationsOf(panel)
            ? Duration.zero
            : KitMotion.standard,
        curve: KitMotion.enter,
      );
    });
  }

  /// The live log as one box: the panel's tint and nothing inside drawing
  /// another. Mono at the small size, one line per line (long apt lines
  /// scroll sideways), newest at the bottom and followed as it grows.
  Widget _logPanel(
    BuildContext context,
    AppLocalizations l10n,
    SetupProgress progress,
  ) {
    final theme = Theme.of(context);
    final log = progress.logTail.trimRight();
    final height = MediaQuery.sizeOf(context).height;
    return Container(
      key: _logKey,
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      constraints: BoxConstraints(maxHeight: math.max(200, height * .42)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      ),
      clipBehavior: Clip.antiAlias,
      child: log.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.setupProgressViewNoLog,
                key: const Key('setup-progress-log'),
                style: theme.textTheme.bodySmall,
              ),
            )
          // Logs are left-to-right whatever the app's direction; flipping
          // them would scramble paths and flags. Reversed, the view starts
          // at the end and stays there as lines arrive.
          : SingleChildScrollView(
              reverse: true,
              padding: const EdgeInsets.all(12),
              child: Directionality(
                key: const Key('setup-progress-log'),
                textDirection: TextDirection.ltr,
                child: TerminalView(output: log, framed: false, wrap: false),
              ),
            ),
    );
  }

  /// Where the job is, as the drawing shows it: OpenCode starting, a
  /// download (bytes still arriving), an unpack, or an install.
  static SetupSceneStage _stageOf(
    AppLocalizations l10n,
    SetupProgress progress,
    List<ComponentProgress> rows,
  ) {
    if (progress.state == SetupState.done) return SetupSceneStage.start;
    ComponentProgress? current;
    for (final row in rows) {
      if (row.state == ComponentState.running ||
          row.state == ComponentState.checking ||
          row.state == ComponentState.failed ||
          row.id == progress.current) {
        current = row;
        break;
      }
    }
    if (current == null) {
      final finished = rows.every(
        (r) =>
            r.state == ComponentState.done || r.state == ComponentState.skipped,
      );
      return finished && rows.isNotEmpty
          ? SetupSceneStage.start
          : SetupSceneStage.download;
    }
    if (current.id == SetupComponentIds.start) return SetupSceneStage.start;
    final stage = current.stage ?? '';
    if (stage == l10n.phoneSetupStageUnpackingLinux ||
        _unpacking.hasMatch(stage)) {
      return SetupSceneStage.unpack;
    }
    final total = current.bytesTotal ?? 0;
    if ((total > 0 && (current.bytesDone ?? 0) < total) ||
        stage == l10n.phoneSetupStageDownloadingLinux ||
        _downloading.hasMatch(stage)) {
      return SetupSceneStage.download;
    }
    return SetupSceneStage.install;
  }

  static final _unpacking = RegExp(r'unpack|extract', caseSensitive: false);
  static final _downloading = RegExp(r'download|fetch', caseSensitive: false);

  /// The current component's measured share, when it reports one.
  static double? _fractionOf(List<ComponentProgress> rows) {
    for (final row in rows) {
      if (row.state != ComponentState.running &&
          row.state != ComponentState.checking) {
        continue;
      }
      final total = row.bytesTotal;
      if (total != null && total > 0 && row.bytesDone != null) {
        return (row.bytesDone! / total).clamp(0, 1).toDouble();
      }
      if (row.percent case final percent?) {
        return (percent / 100).clamp(0, 1).toDouble();
      }
      return null;
    }
    return null;
  }

  String _titleOf(String id) {
    for (final component in widget.components) {
      if (component.id == id) return component.shortTitle;
    }
    return id;
  }

  /// The one line under the bar while it moves: how long is left, only
  /// when the engine knows.
  String _timeLine(AppLocalizations l10n, SetupProgress progress) {
    if (progress.state == SetupState.done) return l10n.setupProgressViewDone;
    final eta = progress.etaSeconds;
    if (eta == null) return l10n.setupProgressViewGettingStarted;
    if (eta < 60) return l10n.setupProgressViewUnderMinute;
    return l10n.setupProgressViewMinutesLeft((eta / 60).round());
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

/// The head of the progress: the drawing, the title, one line and the bar,
/// in [KitStateView]'s order and type (design standard §3, §10), laid out
/// so the host can keep it in view while the steps scroll.
class _Head extends StatelessWidget {
  const _Head({
    required this.scene,
    required this.ambient,
    required this.title,
    required this.body,
    required this.bodyKey,
    required this.progress,
  });

  final KitScene scene;
  final bool ambient;
  final String title;
  final String? body;
  final Key? bodyKey;
  final KitProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = this.body;
    return Semantics(
      container: true,
      // Each row speaks for itself when setup moves on; the head announcing
      // every byte would drown that out.
      liveRegion: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LayoutBuilder(
              builder: (context, constraints) => KitIllustration(
                key: const Key('setup-progress-scene'),
                scene: scene,
                width: math.min(constraints.maxWidth, 264),
                ambient: ambient,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            key: const Key('setup-progress-title'),
            style: theme.textTheme.titleLarge,
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body,
              key: bodyKey,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.mutedOf(theme),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          KitProgressView(progress: progress),
        ],
      ),
    );
  }
}

/// One component of the job, as a [KitRow]: its state mark, its title, and
/// what it is doing on the trailing side ("Downloading · 18 of 30 MB", or
/// the version once done). With large text the detail moves under the
/// title instead of squeezing it; a failure is said under the title.
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
    final stacked = AppTheme.stackedActions(context);
    final detailKey = Key('setup-progress-detail-${row.id}');
    final failure = this.failure;

    final InlineSpan? supporting = failure != null
        ? TextSpan(
            text: failure,
            style: TextStyle(
              color: AppTheme.statusColor(theme, AppStatusTone.failure),
            ),
          )
        : stacked && detail != null
        ? TextSpan(
            text: detail,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          )
        : null;

    final content = KitRow(
      padding: const EdgeInsets.symmetric(vertical: 4),
      leading: _mark(),
      title: title,
      supporting: supporting,
      supportingMaxLines: 4,
      supportingKey: failure != null
          ? Key('setup-progress-error-${row.id}')
          : stacked
          ? detailKey
          : null,
      trailing: !stacked && detail != null
          ? Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Text(
                detail,
                key: detailKey,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            )
          : null,
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

  /// The trailing text, from the row's own signal only.
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

  Widget _mark() {
    final state = switch (row.state) {
      ComponentState.done || ComponentState.skipped => KitMarkState.done,
      ComponentState.running || ComponentState.checking => KitMarkState.working,
      ComponentState.failed => KitMarkState.failed,
      ComponentState.pending => KitMarkState.waiting,
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
      child: KitStatusMark(
        key: ValueKey('${row.id}-${state.name}'),
        state: state,
      ),
    );
  }
}
