/// Settings › Termux server › Running now (TEAM-305): every process the
/// app's Termux user owns, grouped by what owns it, with CPU and memory,
/// refreshed on pull and every 10 seconds while open. Orphans carry the
/// reason they were flagged and a one-tap Stop; stopping a whole group is
/// two-step and says what it ends; the OpenCode server and sshd are
/// protected and send the user to the server controls instead.
///
/// Built from kit parts only (KIT-1): a [KitScreen] page with the refresh
/// in its [KitTopBar], [KitSkeletonRows] while the first list is read,
/// [KitStateView] for a list that could not be read or is empty, one
/// [KitRowGroup] of [KitRow]s per owner (each row with the same menu:
/// Details, Copy command, Stop), [KitNotice] for what a stop did, a
/// [showKitSheet] for a process's details with its technical values in one
/// [KitDetailsFold], and [showKitConfirm] for every stop.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../termux/bridge.dart';
import '../../termux/processes.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import '../../state/phone_host.dart' show PhoneHostKind;
import 'this_phone_screen.dart';

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

  /// "Stop every process in AI Team?" (termux-processes-stop-group-sheet):
  /// says what else ends and how to start it again (map infoMissing).
  Future<void> _stopGroup(TermuxProcessGroup group) async {
    final l10n = _copy(context);
    final count =
        _report?.inGroup(group).where((p) => !p.protected).length ?? 0;
    final confirmed = await showKitConfirm(
      context,
      title: l10n.termuxProcsStopGroupTitle(
        termuxProcessGroupLabel(l10n, group),
      ),
      body: l10n.termuxProcsStopGroupBody(count),
      confirmLabel: l10n.termuxProcsStopConfirm(count),
      icon: AppIcons.stop,
      kind: KitConfirmKind.stop,
      consequenceItems: [
        if (group == TermuxProcessGroup.aiTeam) ...[
          KitConsequence(
            l10n.termuxProcsStopGroupTeamLost,
            mark: KitConsequenceMark.lost,
            key: const Key('termux-procs-confirm-team-lost'),
          ),
          KitConsequence(l10n.termuxProcsStopGroupTeamRestart),
        ] else
          KitConsequence(l10n.termuxProcsNoRestart),
      ],
      sheetKey: const Key('termux-procs-confirm'),
      confirmKey: const Key('termux-procs-confirm-stop'),
    );
    if (!confirmed || !mounted) return;
    await _runStop(() => TermuxProcesses.stopGroup(group));
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
    unawaited(openThisPhone(context, kind: PhoneHostKind.termux));
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
    return KitScreen(
      topBar: KitTopBar(
        title: l10n.termuxProcsTitle,
        actions: [
          KitAction(
            key: const Key('termux-procs-refresh'),
            label: l10n.termuxProcsRefresh,
            icon: AppIconography.retry,
            onPressed: _busy ? null : _refresh,
            disabledReason: _busy ? l10n.termuxProcsStopping : null,
          ),
        ],
      ),
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
    final groups = report.groups.toList();
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
        for (final group in groups)
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: tokens.sectionGap),
            child: _group(context, l10n, group, report.inGroup(group)),
          ),
      ],
    );
  }

  Widget _group(
    BuildContext context,
    AppLocalizations l10n,
    TermuxProcessGroup group,
    List<TermuxProcess> members,
  ) {
    final tokens = KitTokens.of(context);
    final stoppable = members.where((p) => !p.protected).length;
    final hint = switch (group) {
      TermuxProcessGroup.opencodeServer => l10n.termuxProcsGroupOpenCodeHint,
      TermuxProcessGroup.orphans => l10n.termuxProcsOrphansHint,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitRowGroup(
          key: Key('termux-procs-group-${group.wireName}'),
          label: '${termuxProcessGroupLabel(l10n, group)} · ${members.length}',
          children: [
            for (final process in members) _row(context, l10n, process),
            // Stop all sits last, behind the group's destructive hairline
            // (kit-v2 §4.2), not in the label: there it would squeeze the
            // group's name at large text.
            if (group.stoppable && stoppable > 0)
              KitRow(
                key: Key('termux-procs-stop-group-${group.wireName}'),
                leading: KitRow.icon(context, AppIcons.stop),
                title: l10n.termuxProcsStopGroup,
                destructive: true,
                enabled: !_busy,
                disabledReason: _busy ? l10n.termuxProcsStopping : null,
                onTap: () => _stopGroup(group),
              ),
          ],
        ),
        if (hint != null)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: tokens.gutter + tokens.space1,
              end: tokens.gutter + tokens.space1,
              top: tokens.space2,
            ),
            child: KitText(hint, role: KitTextRole.secondary),
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l10n,
    TermuxProcess process,
  ) {
    final stats = l10n.termuxProcsStats(
      formatTermuxCpuPct(process.cpuPct),
      l10n.termuxProcsMemoryMb(process.rssKb ~/ 1024),
      formatTermuxDuration(l10n, process.elapsedSeconds),
    );
    final reason = switch (process.orphanReason) {
      TermuxOrphanReason.parentGone => l10n.termuxProcsOrphanParentGone(
        formatTermuxDuration(l10n, process.elapsedSeconds),
      ),
      TermuxOrphanReason.cpuNoOwner => l10n.termuxProcsOrphanCpu(
        formatTermuxDuration(l10n, process.cpuSeconds),
      ),
      null => null,
    };
    final stopLabel = l10n.termuxProcsStopSemantics(process.name);
    return KitRow(
      key: Key('termux-proc-${process.pid}'),
      leading: KitRow.icon(context, _iconFor(process)),
      title: process.name,
      supporting: TextSpan(text: stats),
      below: reason == null && !process.protected
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reason != null)
                  KitText(
                    reason,
                    key: Key('termux-proc-reason-${process.pid}'),
                    role: KitTextRole.secondary,
                    tone: KitTextTone.primary,
                  ),
                if (process.protected)
                  KitText(
                    l10n.termuxProcsProtected,
                    key: Key('termux-proc-protected-${process.pid}'),
                    role: KitTextRole.secondary,
                  ),
              ],
            ),
      trailing: process.isOrphan && !process.protected
          ? KitIconButton(
              key: Key('termux-proc-stop-${process.pid}'),
              icon: AppIcons.stop,
              tooltip: stopLabel,
              destructive: true,
              onPressed: _busy ? null : () => _stopProcess(process),
              disabledReason: _busy ? l10n.termuxProcsStopping : null,
            )
          : const KitChevron(),
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
