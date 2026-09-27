import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/server_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/isolated_task_launch.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_field.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_progress.dart';
import '../kit/kit_sheet.dart';
import '../kit/kit_state_view.dart';
import '../kit/kit_technical_value.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import '../widgets/product_states.dart' show productErrorText;

/// Explicit "new task in a fresh worktree" flow. Resolves with the blank
/// session once it exists in the worktree's scope, or null when the user
/// closed the sheet first. Nothing is ever sent to the session from here.
///
/// The frame is not dismissible by a swipe: leaving while the conversation
/// is being opened would drop a session the server may still create. Back,
/// Esc and a tap outside still close it as "stop waiting" in every other
/// state (the body handles them), and the body always offers Close.
Future<Session?> showIsolatedTaskSheet(
  BuildContext context, {
  required ConnectionController controller,
  required WorkspaceProject project,
  Duration readinessTimeout = const Duration(seconds: 45),
}) {
  final openingScope = controller.isolatedTaskScope;
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  return showKitSheet<Session>(
    context,
    title: l10n.isolatedTaskTitle,
    subtitle: project.name,
    icon: AppIconography.branch,
    dismissible: false,
    body: (_) => IsolatedTaskSheet(
      controller: controller,
      project: project,
      openingScope: openingScope,
      readinessTimeout: readinessTimeout,
    ),
  );
}

class IsolatedTaskSheet extends StatefulWidget {
  const IsolatedTaskSheet({
    super.key,
    required this.controller,
    required this.project,
    required this.openingScope,
    this.readinessTimeout = const Duration(seconds: 45),
  });

  final ConnectionController controller;
  final WorkspaceProject project;
  final Object openingScope;
  final Duration readinessTimeout;

  @override
  State<IsolatedTaskSheet> createState() => _IsolatedTaskSheetState();
}

class _IsolatedTaskSheetState extends State<IsolatedTaskSheet> {
  final _name = TextEditingController();
  IsolatedTaskLaunch? _launch;
  bool _autoOpened = false;
  bool _popped = false;
  late final ConnectionController _controller;
  late final Object _openingScope;
  bool _invalid = false;
  Object? _startError;
  IsolatedTaskPhase? _phase;
  DateTime? _phaseSince;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _openingScope = widget.openingScope;
    _invalid = _openingScope != _controller.isolatedTaskScope;
    _controller.addListener(_scopeChanged);
  }

  void _scopeChanged() {
    // Once launched, controller guards own the transition into the new tree.
    // Before Start, any observed mismatch permanently retires this sheet.
    if (_launch == null && _openingScope != _controller.isolatedTaskScope) {
      setState(() => _invalid = true);
    }
  }

  @override
  void didUpdateWidget(covariant IsolatedTaskSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, _controller) ||
        widget.project.id != oldWidget.project.id ||
        widget.project.directory != oldWidget.project.directory) {
      _invalid = true;
      if (_launch?.canCancel == true) _launch!.cancel();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_scopeChanged);
    _launch?.removeListener(_onLaunchChanged);
    _launch?.dispose();
    _name.dispose();
    super.dispose();
  }

  void _start() {
    if (_launch != null) return;
    if (_invalid || _openingScope != _controller.isolatedTaskScope) {
      setState(() => _invalid = true);
      return;
    }
    final IsolatedTaskLaunch launch;
    try {
      launch = _controller.startIsolatedTask(
        project: widget.project,
        expectedScope: _openingScope,
        name: _name.text,
        readinessTimeout: widget.readinessTimeout,
      );
    } catch (error) {
      setState(() => _startError = error);
      return;
    }
    launch.addListener(_onLaunchChanged);
    setState(() {
      _startError = null;
      _launch = launch;
      _phase = launch.phase;
      _phaseSince = DateTime.now();
    });
  }

  void _onLaunchChanged() {
    if (!mounted || _invalid) return;
    final launch = _launch!;
    setState(() {
      if (launch.phase != _phase) {
        _phase = launch.phase;
        _phaseSince = DateTime.now();
      }
    });
    if (launch.phase == IsolatedTaskPhase.ready && !_autoOpened) {
      // Ready is the one state that opens without another tap: the user
      // already asked for the session when they pressed Start.
      _autoOpened = true;
      unawaited(launch.open());
    } else if (launch.phase == IsolatedTaskPhase.opened && !_popped) {
      _popped = true;
      Navigator.of(context).pop(launch.session);
    }
  }

  void _close() {
    if (_popped) return;
    final launch = _launch;
    if (launch != null && launch.canCancel) launch.cancel();
    _popped = true;
    Navigator.of(context).pop();
  }

  bool get _busy {
    final launch = _launch;
    return launch != null && launch.phase == IsolatedTaskPhase.opening;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final launch = _launch;
    // Only the open step is uninterruptible: leaving mid-open would drop a
    // session the server may still create. Every other state closes as a
    // plain stop-waiting, which never deletes anything. The frame blocks
    // every pop; this scope turns back, Esc and a tap outside into Close.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          final launch = _launch;
          if (launch != null && launch.canCancel) launch.cancel();
          _popped = true;
          return;
        }
        if (!_busy) _close();
      },
      child: Column(
        key: const Key('isolated-task-sheet'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_invalid)
            KitStateView(
              icon: AppIconography.info,
              title: l10n.isolatedTaskScopeChanged,
              size: KitStateSize.inline,
              secondary: KitAction(
                key: const Key('isolated-task-dismiss'),
                label: l10n.isolatedTaskClose,
                onPressed: _close,
              ),
            )
          else if (launch == null)
            ..._form(context, l10n)
          else
            _status(context, l10n, launch),
        ],
      ),
    );
  }

  List<Widget> _form(BuildContext context, AppLocalizations l10n) {
    final tokens = KitTokens.of(context);
    final startError = _startError;
    return [
      KitText(l10n.isolatedTaskIntro(widget.project.name)),
      SizedBox(height: tokens.space4),
      KitField(
        label: l10n.isolatedTaskNameLabel,
        helper: l10n.isolatedTaskNameHelper,
        controller: _name,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _start(),
        fieldKey: const Key('isolated-task-name'),
      ),
      if (startError != null) ...[
        SizedBox(height: tokens.space3),
        KitNotice.error(
          key: const Key('isolated-task-start-error'),
          message: productErrorText(startError),
          error: startError,
        ),
      ],
      SizedBox(height: tokens.space4),
      KitActionBlock(
        primary: KitAction(
          key: const Key('isolated-task-start'),
          label: l10n.isolatedTaskStart,
          icon: AppIconography.branch,
          onPressed: _start,
        ),
        tertiary: [
          KitAction(
            key: const Key('isolated-task-close'),
            label: l10n.isolatedTaskClose,
            onPressed: _close,
          ),
        ],
      ),
      SizedBox(height: tokens.space4),
      KitDetailsFold(
        values: [
          KitTechnicalValue(
            l10n.isolatedTaskProjectFolder,
            widget.project.directory,
          ),
        ],
      ),
    ];
  }

  /// The staged wait: create (1 of 3), setup (2 of 3), open (3 of 3).
  KitProgress? _progress(AppLocalizations l10n, IsolatedTaskLaunch launch) {
    return switch (launch.phase) {
      IsolatedTaskPhase.idle ||
      IsolatedTaskPhase.creating => KitProgress.staged(
        step: 1,
        of: 3,
        label: l10n.isolatedTaskStageCreate,
        caption: l10n.isolatedTaskUsually,
      ),
      IsolatedTaskPhase.preparing => KitProgress.staged(
        step: 2,
        of: 3,
        label: l10n.isolatedTaskStagePrepare,
        caption: l10n.isolatedTaskUsually,
      ),
      IsolatedTaskPhase.ready when launch.openError == null =>
        KitProgress.staged(step: 3, of: 3, label: l10n.isolatedTaskStageOpen),
      IsolatedTaskPhase.opening => KitProgress.staged(
        step: 3,
        of: 3,
        label: l10n.isolatedTaskStageOpen,
      ),
      _ => null,
    };
  }

  Widget _status(
    BuildContext context,
    AppLocalizations l10n,
    IsolatedTaskLaunch launch,
  ) {
    final tokens = KitTokens.of(context);
    final name = launch.worktree?.name ?? launch.requestedName ?? '';
    final branch = launch.worktree?.branch;
    final failed = launch.phase == IsolatedTaskPhase.failed;
    final (String headline, String? detail) = switch (launch.phase) {
      IsolatedTaskPhase.idle || IsolatedTaskPhase.creating => (
        l10n.isolatedTaskCreating,
        l10n.isolatedTaskCreatingHint,
      ),
      IsolatedTaskPhase.preparing => (l10n.isolatedTaskPreparing(name), null),
      // After a failed open the worktree is still ready but nothing is in
      // flight: no progress, and the headline stops promising an open.
      IsolatedTaskPhase.ready when launch.openError != null => (
        l10n.isolatedTaskReadyIdle(name),
        null,
      ),
      IsolatedTaskPhase.ready => (l10n.isolatedTaskReady(name), null),
      IsolatedTaskPhase.unconfirmed => (
        l10n.isolatedTaskUnconfirmed(name),
        l10n.isolatedTaskUnconfirmedHint,
      ),
      IsolatedTaskPhase.failed => (
        launch.worktree == null
            ? l10n.isolatedTaskCreateFailed
            : l10n.isolatedTaskFailed,
        [
          launch.message ??
              (launch.failure == null
                  ? null
                  : productErrorText(launch.failure!)),
          if (launch.worktree != null) l10n.isolatedTaskFailedKept(name),
        ].whereType<String>().join('\n\n'),
      ),
      IsolatedTaskPhase.opening => (l10n.isolatedTaskOpening(name), null),
      IsolatedTaskPhase.opened => (l10n.isolatedTaskOpened(name), null),
      IsolatedTaskPhase.cancelled => (
        l10n.isolatedTaskCancelled,
        launch.worktree == null
            ? l10n.isolatedTaskCancelledUnknown
            : l10n.isolatedTaskCancelledKept(name),
      ),
    };
    final icon = switch (launch.phase) {
      IsolatedTaskPhase.failed => AppIconography.error,
      IsolatedTaskPhase.unconfirmed => AppIconography.question,
      IsolatedTaskPhase.opened => AppIconography.checkCircle,
      IsolatedTaskPhase.cancelled => AppIconography.info,
      _ => AppIconography.branch,
    };
    final progress = _progress(l10n, launch);
    final (primary, secondary, tertiary) = _actions(l10n, launch);
    final openError = launch.openError;
    return KitStateView(
      icon: icon,
      tone: failed
          ? AppStatusTone.failure
          : progress != null
          ? AppStatusTone.progress
          : AppStatusTone.neutral,
      title: headline,
      titleKey: const Key('isolated-task-status'),
      body: detail == null || detail.isEmpty ? null : detail,
      progress: progress,
      since: progress != null ? _phaseSince : null,
      size: KitStateSize.inline,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      content: branch == null && openError == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (branch != null && branch.isNotEmpty)
                  KitText(
                    l10n.isolatedTaskBranch(branch),
                    role: KitTextRole.secondary,
                  ),
                if (openError != null) ...[
                  SizedBox(height: tokens.space2),
                  KitNotice.error(
                    key: const Key('isolated-task-open-error'),
                    message: productErrorText(openError),
                    error: openError,
                  ),
                ],
              ],
            ),
    );
  }

  (KitAction?, KitAction?, List<KitAction>) _actions(
    AppLocalizations l10n,
    IsolatedTaskLaunch launch,
  ) {
    final stop = KitAction(
      key: const Key('isolated-task-stop'),
      label: l10n.isolatedTaskStopWaiting,
      onPressed: _close,
    );
    final close = KitAction(
      key: const Key('isolated-task-dismiss'),
      label: l10n.isolatedTaskClose,
      onPressed: _close,
    );
    switch (launch.phase) {
      case IsolatedTaskPhase.idle:
      case IsolatedTaskPhase.creating:
      case IsolatedTaskPhase.preparing:
        return (null, stop, const []);
      case IsolatedTaskPhase.unconfirmed:
        return (
          KitAction(
            key: const Key('isolated-task-open-anyway'),
            label: l10n.isolatedTaskOpenAnyway,
            onPressed: () => unawaited(launch.open(acceptUnconfirmed: true)),
          ),
          KitAction(
            key: const Key('isolated-task-keep-waiting'),
            label: l10n.isolatedTaskKeepWaiting,
            onPressed: launch.keepWaiting,
          ),
          [stop],
        );
      case IsolatedTaskPhase.ready:
        if (launch.openError == null) return (null, null, const []);
        return (
          KitAction(
            key: const Key('isolated-task-retry-open'),
            label: l10n.isolatedTaskRetryOpen,
            onPressed: () => unawaited(launch.open()),
          ),
          null,
          [close],
        );
      case IsolatedTaskPhase.opening:
      case IsolatedTaskPhase.opened:
        return (null, null, const []);
      case IsolatedTaskPhase.failed:
      case IsolatedTaskPhase.cancelled:
        return (null, close, const []);
    }
  }
}
