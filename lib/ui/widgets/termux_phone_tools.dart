/// The "On this phone" rows of the Termux server settings (TEAM-304/305)
/// and the Workspace's "Something is still running on this phone" line.
///
/// Both read through `~/.oc/tools.sh` and swallow every bridge failure: a
/// phone without the tools installed simply shows no numbers, and a desktop
/// build never gets here (the callers gate on the Termux platform).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../termux/bridge.dart';
import '../../termux/processes.dart';
import '../../termux/storage.dart';
import '../app_theme.dart';
import '../screens/termux_processes_screen.dart';
import '../screens/termux_storage_screen.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Section label plus the Storage and Running now rows, each with its live
/// summary ("11.6 GB used", "14 processes · CPU 3%").
class TermuxPhoneToolsRows extends StatefulWidget {
  const TermuxPhoneToolsRows({super.key});

  @override
  State<TermuxPhoneToolsRows> createState() => _TermuxPhoneToolsRowsState();
}

class _TermuxPhoneToolsRowsState extends State<TermuxPhoneToolsRows> {
  TermuxStorageSummary? _storage;
  TermuxProcessReport? _processes;
  bool _storageFailed = false;
  bool _processesFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await Future.wait([
      TermuxStorage.summary()
          .then((summary) {
            if (mounted) setState(() => _storage = summary);
          })
          .catchError((Object _) {
            if (mounted) setState(() => _storageFailed = true);
          }),
      TermuxProcesses.scan()
          .then((report) {
            if (mounted) setState(() => _processes = report);
          })
          .catchError((Object _) {
            if (mounted) setState(() => _processesFailed = true);
          }),
    ]);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final storage = _storage;
    final storageSubtitle = _storageFailed
        ? l10n.termuxStorageRowNotScanned
        : storage == null
        ? l10n.termuxProcsRowLoading
        : storage.state == TermuxStorageScanState.running
        ? l10n.termuxStorageRowScanning
        : storage.totalBytes == null
        ? l10n.termuxStorageRowNotScanned
        : l10n.termuxStorageRowUsed(
            formatTermuxBytes(l10n, storage.totalBytes!),
          );
    final processes = _processes;
    final processesSubtitle = _processesFailed
        ? l10n.termuxProcsRowUnavailable
        : processes == null
        ? l10n.termuxProcsRowLoading
        : l10n.termuxProcsRowSubtitle(
            processes.count,
            formatTermuxCpuPct(processes.totalCpuPct),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Text(
            l10n.termuxStorageOnThisPhone,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.mutedOf(theme),
            ),
          ),
        ),
        ListTile(
          key: const Key('termux-storage-row'),
          contentPadding: EdgeInsets.zero,
          minLeadingWidth: 32,
          horizontalTitleGap: 12,
          leading: SizedBox.square(
            dimension: 32,
            child: Icon(
              AppIconography.database,
              size: 24,
              color: AppTheme.mutedOf(theme),
            ),
          ),
          title: Text(l10n.termuxStorageTitle),
          subtitle: Text(
            storageSubtitle,
            key: const Key('termux-storage-row-subtitle'),
          ),
          trailing: const Icon(AppIconography.chevronRight, size: 20),
          onTap: () => _open(const TermuxStorageScreen()),
        ),
        ListTile(
          key: const Key('termux-procs-row'),
          contentPadding: EdgeInsets.zero,
          minLeadingWidth: 32,
          horizontalTitleGap: 12,
          leading: SizedBox.square(
            dimension: 32,
            child: Icon(
              AppIconography.processor,
              size: 24,
              color: AppTheme.mutedOf(theme),
            ),
          ),
          title: Text(l10n.termuxProcsTitle),
          subtitle: Text(
            processesSubtitle,
            key: const Key('termux-procs-row-subtitle'),
          ),
          trailing: const Icon(AppIconography.chevronRight, size: 20),
          onTap: () => _open(const TermuxProcessesScreen()),
        ),
      ],
    );
  }
}

/// The Workspace line for the managed phone server: present only while an
/// orphaned helper has burned more than [threshold] of CPU. Polls the
/// process list every [interval] while mounted; nothing pushes a
/// notification (v1 keeps this in-app).
class TermuxAttentionLine extends StatefulWidget {
  const TermuxAttentionLine({
    super.key,
    this.interval = const Duration(seconds: 60),
    this.threshold = const Duration(minutes: 10),
  });

  final Duration interval;
  final Duration threshold;

  @override
  State<TermuxAttentionLine> createState() => _TermuxAttentionLineState();
}

class _TermuxAttentionLineState extends State<TermuxAttentionLine> {
  TermuxProcess? _worst;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
    _timer = Timer.periodic(widget.interval, (_) => unawaited(_check()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (!TermuxBridge.supported) return;
    try {
      final report = await TermuxProcesses.scan();
      final orphans = report.orphansOver(widget.threshold)
        ..sort((a, b) => b.cpuSeconds.compareTo(a.cpuSeconds));
      if (mounted) {
        setState(() => _worst = orphans.isEmpty ? null : orphans.first);
      }
    } catch (_) {
      // No tools, no Termux, or a bridge hiccup: the line simply stays away.
      if (mounted && _worst != null) setState(() => _worst = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final worst = _worst;
    if (worst == null) return const SizedBox.shrink();
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final attention = AppTheme.statusColor(theme, AppStatusTone.attention);
    return ListTile(
      key: const Key('termux-attention-line'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 32,
      horizontalTitleGap: 12,
      leading: SizedBox.square(
        dimension: 32,
        child: Icon(AppIconography.warning, size: 24, color: attention),
      ),
      title: Text(l10n.termuxProcsAttentionLine),
      subtitle: Text(
        l10n.termuxProcsAttentionDetail(
          worst.name,
          formatTermuxDuration(l10n, worst.cpuSeconds),
        ),
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(AppIconography.chevronRight, size: 20),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const TermuxProcessesScreen(),
          ),
        );
        unawaited(_check());
      },
    );
  }
}
