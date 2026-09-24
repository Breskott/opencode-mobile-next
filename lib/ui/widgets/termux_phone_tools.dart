/// The "On this phone" rows of the Termux server settings (TEAM-304/305)
/// and the watcher behind the Work tab's "OpenCode has been busy" line.
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
import '../kit/kit.dart';
import '../screens/termux_processes_screen.dart';
import '../screens/termux_storage_screen.dart';
import 'work_status_line.dart' show WorkRunawayNotice;

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The Storage and Running now rows, each with its live
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
    // Kit rows under the caller's "Options" label (design standard §6).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KitRow(
          key: const Key('termux-storage-row'),
          leading: KitRow.icon(context, AppIconography.database),
          title: l10n.termuxStorageTitle,
          supporting: TextSpan(text: storageSubtitle),
          supportingKey: const Key('termux-storage-row-subtitle'),
          trailing: const KitChevron(),
          onTap: () => _open(const TermuxStorageScreen()),
        ),
        KitRow(
          key: const Key('termux-procs-row'),
          leading: KitRow.icon(context, AppIconography.processor),
          title: l10n.termuxProcsTitle,
          supporting: TextSpan(text: processesSubtitle),
          supportingKey: const Key('termux-procs-row-subtitle'),
          trailing: const KitChevron(),
          onTap: () => _open(const TermuxProcessesScreen()),
        ),
      ],
    );
  }
}

/// The project a leftover process belongs to, by its working folder: the
/// first folder under a `projects` folder (`/root/projects/FinanceHub/src`
/// is FinanceHub). Null for the projects folder itself, a home folder or
/// anything else, which the line calls "OpenCode" rather than show a path.
String? runawayProjectName(String cwd) {
  final parts = cwd.split('/').where((part) => part.isNotEmpty).toList();
  final index = parts.lastIndexOf('projects');
  if (index < 0 || index + 1 >= parts.length) return null;
  final name = parts[index + 1];
  return name.startsWith('.') ? null : name;
}

/// Watches the managed phone server for a helper that has burned more than
/// [threshold] of CPU with nothing waiting on it, and hands the worst one to
/// [builder] as a [WorkRunawayNotice] (null when there is none, or when the
/// person dismissed this very process). Polls every [interval] while
/// mounted; a phone without the tools simply never reports one.
class TermuxRunawayWatcher extends StatefulWidget {
  const TermuxRunawayWatcher({
    super.key,
    required this.builder,
    this.interval = const Duration(seconds: 60),
    this.threshold = const Duration(minutes: 10),
    this.scan,
  });

  final Widget Function(BuildContext context, WorkRunawayNotice? notice)
  builder;
  final Duration interval;
  final Duration threshold;

  /// Test seam; defaults to [TermuxProcesses.scan] behind the bridge check.
  final Future<TermuxProcessReport> Function()? scan;

  /// Dismissed processes, by pid and name, for the life of the app: the line
  /// comes back only for a different process.
  static final _dismissed = <(int, String)>{};

  @visibleForTesting
  static void resetDismissedForTesting() => _dismissed.clear();

  @override
  State<TermuxRunawayWatcher> createState() => _TermuxRunawayWatcherState();
}

class _TermuxRunawayWatcherState extends State<TermuxRunawayWatcher> {
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
    final scan = widget.scan;
    if (scan == null && !TermuxBridge.supported) return;
    try {
      final report = await (scan ?? TermuxProcesses.scan)();
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
    final identity = worst == null ? null : (worst.pid, worst.name);
    if (worst == null || TermuxRunawayWatcher._dismissed.contains(identity)) {
      return widget.builder(context, null);
    }
    final l10n = _copy(context);
    return widget.builder(
      context,
      WorkRunawayNotice(
        identity: identity!,
        project: runawayProjectName(worst.cwd),
        busyFor: formatTermuxDuration(l10n, worst.cpuSeconds),
        onDismiss: () =>
            setState(() => TermuxRunawayWatcher._dismissed.add(identity)),
        onOpen: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TermuxProcessesScreen(),
            ),
          );
          unawaited(_check());
        },
      ),
    );
  }
}
