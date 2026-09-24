/// Settings › Termux server › Running now (TEAM-305): every process the
/// app's Termux user owns, grouped by what owns it, with CPU and memory,
/// refreshed on pull and every 10 seconds while open. Orphans carry the
/// reason they were flagged and a one-tap Stop; stopping a whole group is
/// two-step; the OpenCode server and sshd are protected and send the user
/// to the server controls instead.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../termux/bridge.dart';
import '../../termux/processes.dart';
import '../app_theme.dart';
import '../desktop/desktop_interaction.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/safety_confirms.dart';
import '../widgets/product_states.dart';
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

class _TermuxProcessesScreenState extends State<TermuxProcessesScreen> {
  TermuxProcessReport? _report;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  String? _resultLine;
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

  Future<void> _stopProcess(TermuxProcess process) async {
    final confirmed = await confirmStopProcess(
      context,
      processName: process.name,
      orphan: process.isOrphan,
    );
    if (!confirmed || !mounted) return;
    await _runStop(() => TermuxProcesses.stopPid(process.pid));
  }

  Future<void> _stopGroup(TermuxProcessGroup group) async {
    final l10n = _copy(context);
    final count =
        _report?.inGroup(group).where((p) => !p.protected).length ?? 0;
    final confirmed = await showConfirmSheet(
      context,
      title: l10n.termuxProcsStopGroupTitle(
        termuxProcessGroupLabel(l10n, group),
      ),
      message: l10n.termuxProcsStopGroupBody(count),
      confirmLabel: l10n.termuxProcsStopConfirm(count),
      cancelLabel: l10n.termuxProcsKeep,
      icon: AppIcons.stop,
      destructive: true,
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
      _resultLine = null;
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
      setState(() => _resultLine = parts.join(' · '));
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TermuxSetupScreen()));
  }

  Future<void> _showDetails(TermuxProcess process) async {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            key: const Key('termux-procs-details'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(process.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.termuxProcsPid(process.pid, process.ppid),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedOf(theme),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.termuxProcsCommand,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.mutedOf(theme),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SelectableText(
                process.cmd,
                textDirection: TextDirection.ltr,
                style: TextStyle(fontFamily: AppTheme.monoFamily, fontSize: 12),
              ),
              if (process.cwd.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.termuxProcsFolder,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.mutedOf(theme),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SelectableText(
                  process.cwd,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (process.protected)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openServerControls();
                  },
                  icon: const Icon(AppIconography.settings),
                  label: Text(l10n.termuxProcsProtected),
                )
              else
                FilledButton.icon(
                  key: const Key('termux-procs-details-stop'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    unawaited(_stopProcess(process));
                  },
                  icon: const Icon(AppIcons.stop),
                  label: Text(l10n.termuxProcsStop),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.termuxProcsTitle),
        actions: [
          IconButton(
            key: const Key('termux-procs-refresh'),
            tooltip: l10n.termuxProcsRefresh,
            onPressed: _busy ? null : _refresh,
            icon: const Icon(AppIconography.retry),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: DesktopScrollbarArea(
                builder: (controller) => ListView(
                  controller: controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  children: [
                    if (report != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.termuxProcsRowSubtitle(
                                report.count,
                                formatTermuxCpuPct(report.totalCpuPct),
                              ),
                              key: const Key('termux-procs-summary'),
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.termuxProcsAutoRefresh,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.mutedOf(theme),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                        child: Text(
                          _error!,
                          key: const Key('termux-procs-error'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    if (_resultLine != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _resultLine!,
                            key: const Key('termux-procs-result'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.successOf(theme),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (report != null && report.count == 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                        child: Text(
                          l10n.termuxProcsEmpty,
                          key: const Key('termux-procs-empty'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.mutedOf(theme),
                          ),
                        ),
                      ),
                    if (report != null)
                      for (final group in report.groups)
                        ..._buildGroup(
                          l10n,
                          theme,
                          group,
                          report.inGroup(group),
                        ),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _buildGroup(
    AppLocalizations l10n,
    ThemeData theme,
    TermuxProcessGroup group,
    List<TermuxProcess> members,
  ) {
    final stoppable = members.where((p) => !p.protected).length;
    return [
      SectionLabel(
        '${termuxProcessGroupLabel(l10n, group)} · ${members.length}',
        key: Key('termux-procs-group-${group.wireName}'),
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 4),
        trailing: group.stoppable && stoppable > 0
            ? TextButton.icon(
                key: Key('termux-procs-stop-group-${group.wireName}'),
                onPressed: _busy ? null : () => _stopGroup(group),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: const Icon(AppIcons.stop, size: 18),
                label: Text(l10n.termuxProcsStopGroup),
              )
            : null,
      ),
      if (group == TermuxProcessGroup.opencodeServer)
        _hint(theme, l10n.termuxProcsGroupOpenCodeHint),
      if (group == TermuxProcessGroup.orphans)
        _hint(theme, l10n.termuxProcsOrphansHint),
      for (final process in members)
        _ProcessRow(
          process: process,
          enabled: !_busy,
          onOpen: () => _showDetails(process),
          onStop: () => _stopProcess(process),
          onProtected: _openServerControls,
        ),
    ];
  }

  Widget _hint(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
    child: Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: AppTheme.mutedOf(theme),
        height: 1.4,
      ),
    ),
  );
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    required this.process,
    required this.enabled,
    required this.onOpen,
    required this.onStop,
    required this.onProtected,
  });

  final TermuxProcess process;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback onStop;
  final VoidCallback onProtected;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final attention = AppTheme.statusColor(theme, AppStatusTone.attention);
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
    return ListTile(
      key: Key('termux-proc-${process.pid}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      minLeadingWidth: 32,
      horizontalTitleGap: 12,
      leading: SizedBox.square(
        dimension: 32,
        child: Icon(
          process.protected
              ? AppIconography.locked
              : process.isOrphan
              ? AppIconography.warning
              : AppIconography.processor,
          size: 24,
          color: process.isOrphan ? attention : AppTheme.mutedOf(theme),
        ),
      ),
      title: Text(process.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stats, style: theme.textTheme.bodySmall),
          if (reason != null)
            Text(
              reason,
              key: Key('termux-proc-reason-${process.pid}'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: attention,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (process.protected)
            Text(
              l10n.termuxProcsProtected,
              key: Key('termux-proc-protected-${process.pid}'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedOf(theme),
              ),
            ),
        ],
      ),
      trailing: process.protected
          ? const Icon(AppIconography.chevronRight, size: 20)
          : process.isOrphan
          ? IconButton(
              key: Key('termux-proc-stop-${process.pid}'),
              tooltip: l10n.termuxProcsStopSemantics(process.name),
              onPressed: enabled ? onStop : null,
              color: theme.colorScheme.error,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(AppIcons.stop),
            )
          : const Icon(AppIconography.chevronRight, size: 20),
      onTap: process.protected ? onProtected : onOpen,
    );
  }
}
