/// Settings › Termux server › Storage (TEAM-304): what the phone server
/// uses, per category, with the exact paths a Clean removes, a background
/// scan that shows the same live-output panel as install and can be
/// cancelled, and per-category cleaning that is two-step above a gigabyte.
///
/// Projects and OpenCode itself are listed with their sizes and never
/// offered for cleaning; the script refuses those paths as well.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../termux/bridge.dart';
import '../../termux/storage.dart';
import '../app_theme.dart';
import '../desktop/desktop_interaction.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/product_states.dart';
import '../widgets/setup_terminal.dart';
import 'termux_processes_screen.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// "11.6 GB" through the catalog, so the unit reads in the user's language.
String formatTermuxBytes(AppLocalizations l10n, int bytes) {
  final split = splitBytes(bytes);
  return switch (split.unit) {
    TermuxByteUnit.gb => l10n.termuxStorageBytesGb(split.value),
    TermuxByteUnit.mb => l10n.termuxStorageBytesMb(split.value),
    TermuxByteUnit.kb => l10n.termuxStorageBytesKb(split.value),
    TermuxByteUnit.b => l10n.termuxStorageBytesB(split.value),
  };
}

String termuxStorageCategoryLabel(
  AppLocalizations l10n,
  TermuxStorageCategory category,
) => switch (category.known) {
  TermuxStorageCategoryKey.buildCaches => l10n.termuxStorageCatBuildCaches,
  TermuxStorageCategoryKey.agentScratch => l10n.termuxStorageCatAgentScratch,
  TermuxStorageCategoryKey.projectBuildOutputs =>
    l10n.termuxStorageCatProjectBuildOutputs,
  TermuxStorageCategoryKey.toolchains => l10n.termuxStorageCatToolchains,
  TermuxStorageCategoryKey.aiTeam => l10n.termuxStorageCatAiTeam,
  TermuxStorageCategoryKey.opencode => l10n.termuxStorageCatOpenCode,
  TermuxStorageCategoryKey.projects => l10n.termuxStorageCatProjects,
  null => category.key,
};

String? termuxStorageCategoryNote(
  AppLocalizations l10n,
  TermuxStorageCategory category,
) => switch (category.known) {
  TermuxStorageCategoryKey.buildCaches => l10n.termuxStorageNoteBuildCaches,
  TermuxStorageCategoryKey.agentScratch => l10n.termuxStorageNoteAgentScratch,
  TermuxStorageCategoryKey.projectBuildOutputs =>
    l10n.termuxStorageNoteProjectBuildOutputs,
  TermuxStorageCategoryKey.toolchains => l10n.termuxStorageNoteToolchains,
  TermuxStorageCategoryKey.aiTeam => l10n.termuxStorageNoteAiTeam,
  TermuxStorageCategoryKey.opencode => l10n.termuxStorageNoteOpenCode,
  TermuxStorageCategoryKey.projects => l10n.termuxStorageNoteProjects,
  null => null,
};

class TermuxStorageScreen extends StatefulWidget {
  const TermuxStorageScreen({
    super.key,
    this.now,
    this.pollInterval = const Duration(seconds: 2),
  });

  /// Clock for "scanned N min ago"; tests pass a fixed one.
  final DateTime Function()? now;

  /// How often a running scan's log is re-read.
  final Duration pollInterval;

  /// Cleaning more than this goes through the two-step confirmation.
  static const twoStepBytes = 1024 * 1024 * 1024;

  @override
  State<TermuxStorageScreen> createState() => _TermuxStorageScreenState();
}

class _TermuxStorageScreenState extends State<TermuxStorageScreen> {
  TermuxStorageScanStatus? _status;
  TermuxStorageReport? _report;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  String? _cleaningKey;
  String? _resultLine;
  bool _resultIsProblem = false;
  Timer? _poll;
  final _logScroll = ScrollController();

  bool get _scanning =>
      _status?.state == TermuxStorageScanState.running ||
      _busy && _report == null;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _logScroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await TermuxStorage.status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _report = status.report ?? _report;
        _error = null;
        _loading = false;
      });
      _schedulePoll();
    } on TermuxBridgeException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    if (_status?.state != TermuxStorageScanState.running) return;
    _poll = Timer(widget.pollInterval, () {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _busy = true;
      _error = null;
      _resultLine = null;
    });
    try {
      await TermuxStorage.startScan();
      if (!mounted) return;
      setState(() {
        _status = const TermuxStorageScanStatus(
          state: TermuxStorageScanState.running,
          log: '',
          report: null,
        );
      });
      _schedulePoll();
    } on TermuxBridgeException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelScan() async {
    _poll?.cancel();
    try {
      await TermuxStorage.cancelScan();
    } on TermuxBridgeException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
    if (mounted) await _refresh();
  }

  Future<void> _clean(TermuxStorageCategory category) async {
    final l10n = _copy(context);
    final size = formatTermuxBytes(l10n, category.bytes);
    final label = termuxStorageCategoryLabel(l10n, category);
    if (category.bytes > TermuxStorageScreen.twoStepBytes) {
      final confirmed = await showConfirmSheet(
        context,
        title: l10n.termuxStorageCleanConfirmTitle(size, label),
        message: l10n.termuxStorageCleanConfirmBody,
        confirmLabel: l10n.termuxStorageCleanConfirm(size),
        cancelLabel: l10n.termuxStorageKeep,
        icon: AppIconography.delete,
        destructive: true,
        sheetKey: const Key('termux-storage-confirm'),
        confirmKey: const Key('termux-storage-confirm-remove'),
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _busy = true;
      _cleaningKey = category.key;
      _resultLine = null;
      _error = null;
    });
    try {
      final result = await TermuxStorage.clean(category.key);
      if (!mounted) return;
      final inUse = result.inUse;
      setState(() {
        if (inUse != null) {
          _resultLine = l10n.termuxStorageInUse(inUse.processes.join(', '));
          _resultIsProblem = true;
        } else {
          final freed = result.freedBytes > 0
              ? l10n.termuxStorageFreed(
                  formatTermuxBytes(l10n, result.freedBytes),
                )
              : l10n.termuxStorageFreedNothing;
          _resultLine = result.refused.isEmpty
              ? freed
              : '$freed · ${l10n.termuxStorageRefusedCount(result.refused.length)}';
          _resultIsProblem = false;
          _report = _report?.afterClean(
            category.key,
            result.removed.map((p) => p.path),
            result.freedBytes,
          );
        }
      });
    } on TermuxBridgeException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _cleaningKey = null;
        });
      }
    }
  }

  Future<void> _copyLog() async {
    final log = _status?.log ?? '';
    if (log.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: log));
  }

  String _scanAge(AppLocalizations l10n, DateTime scannedAt) {
    final now = widget.now?.call() ?? DateTime.now();
    final age = now.difference(scannedAt);
    if (age.inMinutes < 1) return l10n.termuxStorageScannedJustNow;
    if (age.inHours < 1) {
      return l10n.termuxStorageScannedMinutesAgo(age.inMinutes);
    }
    return l10n.termuxStorageScannedHoursAgo(age.inHours);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.termuxStorageTitle),
        actions: [
          if (_report != null && !_scanning)
            IconButton(
              key: const Key('termux-storage-rescan'),
              tooltip: l10n.termuxStorageRescanAction,
              onPressed: _busy ? null : _startScan,
              icon: const Icon(AppIconography.retry),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scanning
          ? _buildScanning(l10n, theme)
          : DesktopScrollbarArea(
              builder: (controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  if (_error == null)
                    const SizedBox.shrink()
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                      child: Text(
                        _error!,
                        key: const Key('termux-storage-error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  switch (_status?.state) {
                    TermuxStorageScanState.cancelled => _statusLine(
                      theme,
                      l10n.termuxStorageCancelled,
                    ),
                    TermuxStorageScanState.failed => _statusLine(
                      theme,
                      l10n.termuxStorageFailed,
                      problem: true,
                    ),
                    _ => const SizedBox.shrink(),
                  },
                  if (_report == null)
                    _buildIntro(l10n, theme)
                  else
                    ..._buildReport(l10n, theme, _report!),
                ],
              ),
            ),
    );
  }

  Widget _statusLine(ThemeData theme, String text, {bool problem = false}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: problem ? theme.colorScheme.error : AppTheme.mutedOf(theme),
          ),
        ),
      );

  Widget _buildIntro(AppLocalizations l10n, ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          AppIconography.database,
          size: 36,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.termuxStorageIntro,
          key: const Key('termux-storage-intro'),
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('termux-storage-scan'),
          onPressed: _busy ? null : _startScan,
          icon: const Icon(AppIconography.search),
          label: Text(l10n.termuxStorageScanAction),
        ),
      ],
    ),
  );

  Widget _buildScanning(AppLocalizations l10n, ThemeData theme) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.termuxStorageScanning,
                key: const Key('termux-storage-scanning'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.termuxStorageScanningDetail)),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('termux-storage-cancel'),
              onPressed: _cancelScan,
              icon: const Icon(AppIcons.stop),
              label: Text(l10n.termuxStorageCancel),
            ),
          ],
        ),
      ),
      Expanded(
        child: SetupTerminal(
          output: _status?.log ?? '',
          running: true,
          expand: true,
          controller: _logScroll,
          onCopy: _copyLog,
        ),
      ),
    ],
  );

  List<Widget> _buildReport(
    AppLocalizations l10n,
    ThemeData theme,
    TermuxStorageReport report,
  ) {
    final scannedAt = report.scannedAt;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.termuxStorageTotal(
                formatTermuxBytes(l10n, report.totalBytes),
              ),
              key: const Key('termux-storage-total'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              [
                l10n.termuxStorageDeletableTotal(
                  formatTermuxBytes(l10n, report.deletableBytes),
                ),
                if (scannedAt != null) _scanAge(l10n, scannedAt),
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedOf(theme),
              ),
            ),
          ],
        ),
      ),
      // Always one slot, so the keyed category tiles below keep their
      // expansion state when a result line appears or goes.
      if (_resultLine == null)
        const SizedBox.shrink()
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Semantics(
            liveRegion: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  _resultLine!,
                  key: const Key('termux-storage-result'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _resultIsProblem
                        ? AppTheme.statusColor(theme, AppStatusTone.attention)
                        : AppTheme.successOf(theme),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_resultIsProblem)
                  TextButton(
                    key: const Key('termux-storage-open-running'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TermuxProcessesScreen(),
                      ),
                    ),
                    child: Text(l10n.termuxStorageOpenRunning),
                  ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      for (final category in report.categories)
        _CategoryTile(
          category: category,
          cleaning: _cleaningKey == category.key,
          enabled: !_busy,
          onClean: () => _clean(category),
        ),
      if (report.projects.isNotEmpty) ...[
        SectionLabel(l10n.termuxStorageCatProjects),
        for (final project in report.projects)
          ListTile(
            key: Key('termux-storage-project-${project.name}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            minLeadingWidth: 32,
            horizontalTitleGap: 12,
            leading: SizedBox.square(
              dimension: 32,
              child: Icon(
                AppIconography.folders,
                size: 24,
                color: AppTheme.mutedOf(theme),
              ),
            ),
            title: Text(project.name),
            subtitle: Text(
              l10n.termuxStorageProjectBuild(
                formatTermuxBytes(l10n, project.bytes),
                formatTermuxBytes(l10n, project.buildBytes),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            l10n.termuxStorageNoteProjects,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedOf(theme),
            ),
          ),
        ),
      ],
    ];
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.cleaning,
    required this.enabled,
    required this.onClean,
  });

  final TermuxStorageCategory category;
  final bool cleaning;
  final bool enabled;
  final VoidCallback onClean;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final label = termuxStorageCategoryLabel(l10n, category);
    final size = formatTermuxBytes(l10n, category.bytes);
    final note = termuxStorageCategoryNote(l10n, category);
    final empty = category.paths.isEmpty;
    final canClean = category.deletable && !empty;
    return ExpansionTile(
      key: Key('termux-storage-cat-${category.key}'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(label),
      subtitle: Text(
        empty
            ? l10n.termuxStorageNothingHere
            : category.deletable
            ? size
            : '$size · ${l10n.termuxStorageNotDeletable}',
        key: Key('termux-storage-size-${category.key}'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppTheme.mutedOf(theme),
        ),
      ),
      children: [
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        if (!empty) ...[
          Text(
            category.deletable
                ? l10n.termuxStorageWillRemove
                : l10n.termuxStorageNotDeletable,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.mutedOf(theme),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          for (final entry in category.paths)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                children: [
                  Text(
                    displayTermuxPath(entry.path),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    formatTermuxBytes(l10n, entry.bytes),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.mutedOf(theme),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (canClean) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              key: Key('termux-storage-clean-${category.key}'),
              onPressed: enabled ? onClean : null,
              icon: cleaning
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIconography.delete),
              label: Text(
                cleaning ? l10n.termuxStorageCleaning : l10n.termuxStorageClean,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
