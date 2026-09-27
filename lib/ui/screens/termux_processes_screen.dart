/// Settings › Termux server › Running now (TEAM-305): every process the
/// app's Termux user owns, with CPU and memory, refreshed on pull and every
/// 10 seconds while open.
///
/// ONE list ordered by urgency (owner rule 2026-09-27), never split into
/// sections by owner: orphans first (a warning mark and "Parent gone ·
/// CPU 99% · 43 MB · 1 h 1 min"), then everything else by CPU, each row
/// naming what it belongs to in its supporting line ("AI Team · CPU 3.5% ·
/// 48 MB · 12 min"). The OpenCode server and sshd are protected and say
/// so in words; they send the user to the server controls instead.
/// Stopping one process lives in its row's menu and its details sheet
/// ("Stop Gradle daemon"); the one bulk stop, only while orphans exist, is
/// the last row: "Stop 2 orphaned helpers".
///
/// Built from kit parts only (KIT-1): a [KitScreen] page, [KitSkeletonRows]
/// while the first list is read, [KitStateView] for a list that could not
/// be read or is empty, one [KitRowGroup] of [KitRow]s (each row with the
/// same menu: Details, Copy command, Stop), [KitNotice] for what a stop
/// did, a [showKitSheet] for a process's details with its technical values
/// in one [KitDetailsFold], and [showKitConfirm] for every stop.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../termux/bridge.dart';
import '../../termux/processes.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import 'termux_setup_screen.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

String termuxProcessGroupLabel(
  AppLocalizations l10n,
  TermuxProcessGroup group,
) => switch (group) {
  TermuxProcessGroup.opencodeServer => l10n.termuxProcsGroupOpenCode,
  TermuxProcessGroup.aiTeam => l10n.termuxProcsGroupAiTeam,
  TermuxProcessGroup.buildDaemons => l10n.termuxProcsGroupBuild,
  TermuxProcessGroup.orphans => l10n.termuxProcsGroupOrphans,
  TermuxProcessGroup.other => l10n.termuxProcsGroupOther,
};

/// What a process is, in the person's words (map infoMissing on
/// termux-processes-details-sheet: "what it is, why it is safe to stop").
String termuxProcessAbout(AppLocalizations l10n, TermuxProcess process) =>
    switch (process.group) {
      TermuxProcessGroup.opencodeServer => l10n.termuxProcsAboutOpenCode,
      TermuxProcessGroup.aiTeam => l10n.termuxProcsAboutAiTeam,
      TermuxProcessGroup.buildDaemons => l10n.termuxProcsAboutBuild,
      TermuxProcessGroup.orphans => l10n.termuxProcsAboutOrphan,
      TermuxProcessGroup.other => l10n.termuxProcsAboutOther,
    };

/// "42 s", "12 min", "3 h 5 min".
String formatTermuxDuration(AppLocalizations l10n, int seconds) {
  if (seconds < 60) return l10n.termuxProcsDurationSeconds(seconds);
  final minutes = seconds ~/ 60;
  if (minutes < 60) return l10n.termuxProcsDurationMinutes(minutes);
  return l10n.termuxProcsDurationHours(minutes ~/ 60, minutes % 60);
}

String formatTermuxCpuPct(double pct) =>
    pct >= 10 ? pct.round().toString() : pct.toStringAsFixed(1);

class TermuxProcessesScreen extends StatefulWidget {
  const TermuxProcessesScreen({
    super.key,
    this.refreshInterval = const Duration(seconds: 10),
    this.onOpenServerControls,
  });

  final Duration refreshInterval;

  /// Where a protected row (sshd, `opencode serve`) sends the user; the
  /// default opens the Termux server screen.
  final VoidCallback? onOpenServerControls;

  @override
  State<TermuxProcessesScreen> createState() => _TermuxProcessesScreenState();
}

/// What the last stop did: said in place, on the list (§4.8).
class _StopOutcome {
  const _StopOutcome(this.line, {required this.complete});

  final String line;

  /// False when something would not stop (map statesMissing: "a stop that
  /// did not take").
  final bool complete;
}

class _TermuxProcessesScreenState extends State<TermuxProcessesScreen> {
  TermuxProcessReport? _report;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  _StopOutcome? _outcome;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _timer = Timer.periodic(widget.refreshInterval, (_) {
      if (mounted && !_busy) unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final report = await TermuxProcesses.scan();
      if (!mounted) return;
      setState(() {
        _report = report;
        _error = null;
        _loading = false;
      });
    } on TermuxBridgeException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = _copy(context).termuxProcsFailed;
        _loading = false;
      });
    }
  }

  /// "Stop java?" (termux-processes-stop-one-sheet). Raised from the
  /// details sheet it replaces that sheet's content in place (§4.7).
  Future<bool> _confirmStop(BuildContext context, TermuxProcess process) {
    final l10n = _copy(context);
    return showKitConfirm(
      context,
      title: l10n.termuxProcsStopOneTitle(process.name),
      body: process.isOrphan
          ? l10n.safetyStopOrphanBody
          : l10n.termuxProcsStopOneBody,
      confirmLabel: l10n.termuxProcsStopSemantics(process.name),
      icon: AppIcons.stop,
      kind: KitConfirmKind.stop,
      // No undo, and it says so (map actionsMissing).
      consequenceItems: [KitConsequence(l10n.termuxProcsNoRestart)],
      sheetKey: const Key('termux-procs-confirm'),
      confirmKey: const Key('termux-procs-confirm-stop'),
    );
  }

  Future<void> _stopProcess(TermuxProcess process) async {
    final confirmed = await _confirmStop(context, process);
    if (!confirmed || !mounted) return;
    await _runStop(() => TermuxProcesses.stopPid(process.pid));
  }

  /// "Stop the 2 orphaned helpers?": the one bulk stop, offered only while
  /// orphans exist; the button names what it stops.
  Future<void> _stopOrphans() async {
    final l10n = _copy(context);
    final count =
        _report
            ?.inGroup(TermuxProcessGroup.orphans)
            .where((p) => !p.protected)
            .length ??
        0;
    final confirmed = await showKitConfirm(
      context,
      title: l10n.termuxProcsStopOrphansTitle(count),
      body: l10n.termuxProcsStopGroupBody(count),
      confirmLabel: l10n.termuxProcsStopOrphans(count),
      icon: AppIcons.stop,
      kind: KitConfirmKind.stop,
      consequenceItems: [KitConsequence(l10n.termuxProcsNoRestart)],
      sheetKey: const Key('termux-procs-confirm'),
      confirmKey: const Key('termux-procs-confirm-stop'),
    );
    if (!confirmed || !mounted) return;
    await _runStop(() => TermuxProcesses.stopGroup(TermuxProcessGroup.orphans));
  }

  Future<void> _runStop(
    Future<TermuxProcessStopResult> Function() action,
  ) async {
    final l10n = _copy(context);
    setState(() {
      _busy = true;
      _outcome = null;
      _error = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      final parts = <String>[
        if (result.killed.isNotEmpty)
          l10n.termuxProcsStoppedForced(result.endedCount, result.killed.length)
        else
          l10n.termuxProcsStopped(result.endedCount),
        if (result.remaining.isNotEmpty)
          l10n.termuxProcsRemaining(result.remaining.length),
        if (result.refused.isNotEmpty)
          l10n.termuxProcsRefused(result.refused.length),
      ];
      setState(
        () => _outcome = _StopOutcome(
          parts.join(' · '),
          complete: result.remaining.isEmpty,
        ),
      );
    } on TermuxBridgeException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FormatException {
      if (mounted) setState(() => _error = l10n.termuxProcsFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _refresh();
  }

  void _openServerControls() {
    if (widget.onOpenServerControls case final open?) {
      open();
      return;
    }
    unawaited(pushKitPage<void>(context, (_) => const TermuxSetupScreen()));
  }

  /// termux-processes-details-sheet: what the process is in words, its
  /// numbers, and its command, folder and IDs folded under Details, each
  /// copyable; Copy command and a full-width "Stop java" below.
  Future<void> _showDetails(TermuxProcess process) async {
    final l10n = _copy(context);
    BuildContext? inside;
    await showKitSheet<void>(
      context,
      title: process.name,
      subtitle: l10n.termuxProcsPid(process.pid, process.ppid),
      icon: _iconFor(process),
      secondary: process.protected
          ? KitAction(
              label: l10n.termuxProcsOpenControls,
              icon: AppIconography.settings,
              onPressed: () {
                final sheet = inside;
                if (sheet != null) KitSheet.close<void>(sheet);
                _openServerControls();
              },
            )
          : KitAction(
              key: const Key('termux-procs-details-stop'),
              label: l10n.termuxProcsStopSemantics(process.name),
              icon: AppIcons.stop,
              destructive: true,
              onPressed: _busy
                  ? null
                  : () async {
                      final sheet = inside;
                      if (sheet == null) return;
                      final confirmed = await _confirmStop(sheet, process);
                      if (!confirmed || !mounted) return;
                      if (sheet.mounted) KitSheet.close<void>(sheet);
                      await _runStop(
                        () => TermuxProcesses.stopPid(process.pid),
                      );
                    },
              disabledReason: _busy ? l10n.termuxProcsStopping : null,
            ),
      tertiary: [
        KitAction.copy(
          key: const Key('termux-procs-details-copy'),
          label: l10n.termuxProcsCopyCommand,
          text: () => process.cmd,
        ),
      ],
      body: (sheetContext) {
        inside = sheetContext;
        return _ProcessDetails(process: process);
      },
    );
  }

  static IconData _iconFor(TermuxProcess process) => process.protected
      ? AppIconography.locked
      : process.isOrphan
      ? AppIconography.warning
      : AppIconography.processor;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final report = _report;
    final error = _error;
    final Widget body;
    if (report == null && _loading) {
      body = ListView(
        key: const ValueKey('termux-procs-loading'),
        padding: KitScreen.padding(context),
        children: const [KitSkeletonRows()],
      );
    } else if (report == null) {
      // Termux not answering or the bridge failed (map statesMissing).
      body = KitStateView.error(
        key: const ValueKey('termux-procs-load-error'),
        title: l10n.termuxProcsLoadFailedTitle,
        body: error ?? l10n.termuxProcsFailed,
        bodyKey: const Key('termux-procs-error'),
        retry: KitAction(label: l10n.commonRetry, onPressed: _refresh),
      );
    } else {
      body = KitRefresh(
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('termux-procs-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.only(
            top: KitTokens.of(context).space2,
            bottom: KitScreen.endPadding(context),
          ),
          children: [_list(context, l10n, report)],
        ),
      );
    }
    // The list refreshes itself every 10 seconds (and on pull), and says
    // so: no Refresh button repeats it.
    return KitScreen(
      topBar: KitTopBar(title: l10n.termuxProcsTitle),
      width: KitScreenWidth.reading,
      loading: _busy,
      loadingLabel: l10n.termuxProcsStopping,
      body: body,
    );
  }

  Widget _list(
    BuildContext context,
    AppLocalizations l10n,
    TermuxProcessReport report,
  ) {
    final tokens = KitTokens.of(context);
    final rails = EdgeInsetsDirectional.only(
      start: tokens.gutter,
      end: tokens.gutter,
      bottom: tokens.sectionGap,
    );
    final error = _error;
    final outcome = _outcome;
    // Orphans first, then the rest; each by CPU, busiest first.
    final ordered = [...report.processes]
      ..sort((a, b) {
        final orphan = (b.isOrphan ? 1 : 0) - (a.isOrphan ? 1 : 0);
        if (orphan != 0) return orphan;
        return b.cpuPct.compareTo(a.cpuPct);
      });
    final orphans = ordered.where((p) => p.isOrphan && !p.protected).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (report.count > 0)
          Padding(
            padding: rails,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KitText(
                  l10n.termuxProcsRowSubtitle(
                    report.count,
                    formatTermuxCpuPct(report.totalCpuPct),
                  ),
                  key: const Key('termux-procs-summary'),
                  role: KitTextRole.headline,
                  tabular: true,
                ),
                SizedBox(height: tokens.space1),
                KitText(l10n.termuxProcsAutoRefresh, role: KitTextRole.caption),
              ],
            ),
          ),
        if (error != null)
          Padding(
            padding: rails,
            child: KitNotice.error(
              message: error,
              messageKey: const Key('termux-procs-error'),
              retry: KitAction(label: l10n.commonRetry, onPressed: _refresh),
            ),
          ),
        if (outcome != null)
          Padding(
            padding: rails,
            child: KitNotice(
              key: const ValueKey('termux-procs-outcome'),
              tone: outcome.complete ? AppStatusTone.ok : AppStatusTone.failure,
              icon: outcome.complete
                  ? AppIconography.check
                  : AppIconography.error,
              title: outcome.complete ? null : l10n.termuxProcsNotStoppedTitle,
              message: outcome.line,
              messageKey: const Key('termux-procs-result'),
            ),
          ),
        if (report.count == 0)
          Padding(
            padding: rails,
            child: KitStateView(
              key: const Key('termux-procs-empty'),
              icon: AppIconography.processor,
              title: l10n.termuxProcsEmpty,
              body: l10n.termuxProcsEmptyBody,
              size: KitStateSize.inline,
              padding: EdgeInsets.zero,
            ),
          ),
        if (ordered.isNotEmpty)
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: tokens.sectionGap),
            child: KitRowGroup(
              key: const Key('termux-procs-list-group'),
              children: [
                for (final process in ordered) _row(context, l10n, process),
                // The one bulk stop, only while orphans exist, last behind
                // the group's destructive hairline (kit-v2 §4.2).
                if (orphans > 0)
                  KitRow(
                    key: const Key('termux-procs-stop-orphans'),
                    leading: KitRow.icon(context, AppIcons.stop),
                    title: l10n.termuxProcsStopOrphans(orphans),
                    destructive: true,
                    enabled: !_busy,
                    disabledReason: _busy ? l10n.termuxProcsStopping : null,
                    onTap: _stopOrphans,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// What a process belongs to, first in its supporting line: why an
  /// orphan was flagged, else its owner.
  static String _kind(AppLocalizations l10n, TermuxProcess process) =>
      switch (process.orphanReason) {
        TermuxOrphanReason.parentGone => l10n.termuxProcsKindParentGone,
        TermuxOrphanReason.cpuNoOwner => l10n.termuxProcsKindNoOwner,
        null => termuxProcessGroupLabel(l10n, process.group),
      };

  Widget _row(
    BuildContext context,
    AppLocalizations l10n,
    TermuxProcess process,
  ) {
    final line = [
      _kind(l10n, process),
      l10n.termuxProcsStats(
        formatTermuxCpuPct(process.cpuPct),
        l10n.termuxProcsMemoryMb(process.rssKb ~/ 1024),
        formatTermuxDuration(l10n, process.elapsedSeconds),
      ),
    ].join(' · ');
    final stopLabel = l10n.termuxProcsStopSemantics(process.name);
    return KitRow(
      key: Key('termux-proc-${process.pid}'),
      // The warning glyph marks an orphan; its words lead the line.
      leading: KitRow.icon(context, _iconFor(process)),
      title: process.name,
      supporting: TextSpan(text: line),
      supportingKey: Key('termux-proc-line-${process.pid}'),
      supportingMaxLines: 2,
      // The protected server says so in words, and where to control it.
      below: process.protected
          ? KitText(
              l10n.termuxProcsProtected,
              key: Key('termux-proc-protected-${process.pid}'),
              role: KitTextRole.secondary,
            )
          : null,
      trailing: const KitChevron(),
      onTap: process.protected
          ? _openServerControls
          : () => _showDetails(process),
      // One menu per process (map proposal): the same acts as the row,
      // its sheet and its stop button.
      menu: [
        if (process.protected)
          KitMenuItem(
            label: l10n.termuxProcsOpenControls,
            icon: AppIconography.settings,
            onSelected: _openServerControls,
          )
        else
          KitMenuItem(
            label: l10n.kitDetails,
            icon: AppIconography.info,
            onSelected: () => _showDetails(process),
          ),
        KitMenuItem.copy(
          label: l10n.termuxProcsCopyCommand,
          text: () => process.cmd,
        ),
        if (!process.protected)
          KitMenuItem(
            label: stopLabel,
            icon: AppIcons.stop,
            destructive: true,
            enabled: !_busy,
            disabledReason: _busy ? l10n.termuxProcsStopping : null,
            onSelected: () => _stopProcess(process),
          ),
      ],
    );
  }
}

/// The details sheet's body: the words first, the numbers, then every
/// technical value once, copyable, left to right, under one Details fold
/// (§4.3).
class _ProcessDetails extends StatelessWidget {
  const _ProcessDetails({required this.process});

  final TermuxProcess process;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final reason = switch (process.orphanReason) {
      TermuxOrphanReason.parentGone => l10n.termuxProcsOrphanParentGone(
        formatTermuxDuration(l10n, process.elapsedSeconds),
      ),
      TermuxOrphanReason.cpuNoOwner => l10n.termuxProcsOrphanCpu(
        formatTermuxDuration(l10n, process.cpuSeconds),
      ),
      null => null,
    };
    return Column(
      key: const Key('termux-procs-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KitText(
          termuxProcessAbout(l10n, process),
          key: const Key('termux-procs-details-about'),
        ),
        if (reason != null) ...[
          SizedBox(height: tokens.space2),
          KitText(reason, role: KitTextRole.secondary),
        ],
        SizedBox(height: tokens.space2),
        KitText(
          l10n.termuxProcsStats(
            formatTermuxCpuPct(process.cpuPct),
            l10n.termuxProcsMemoryMb(process.rssKb ~/ 1024),
            formatTermuxDuration(l10n, process.elapsedSeconds),
          ),
          role: KitTextRole.secondary,
          tabular: true,
        ),
        SizedBox(height: tokens.space4),
        KitDetailsFold(
          values: [
            KitTechnicalValue(
              l10n.termuxProcsCommand,
              process.cmd,
              key: const Key('termux-procs-details-command'),
            ),
            if (process.cwd.isNotEmpty)
              KitTechnicalValue(l10n.termuxProcsFolder, process.cwd),
            KitTechnicalValue(l10n.termuxProcsProcessId, '${process.pid}'),
            KitTechnicalValue(l10n.termuxProcsParentId, '${process.ppid}'),
          ],
        ),
      ],
    );
  }
}
