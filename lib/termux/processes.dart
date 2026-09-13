/// Running now (TEAM-305): every process the app's Termux user owns, grouped
/// by ancestry, and polite-then-forced stopping through `~/.oc/tools.sh`.
library;

import 'dart:convert';

import 'bridge.dart';

enum TermuxProcessGroup {
  orphans('orphans'),
  opencodeServer('opencode_server'),
  aiTeam('ai_team'),
  buildDaemons('build_daemons'),
  other('other');

  const TermuxProcessGroup(this.wireName);
  final String wireName;

  static TermuxProcessGroup parse(String? value) {
    for (final group in values) {
      if (group.wireName == value) return group;
    }
    return other;
  }

  /// The OpenCode server group is managed from the server controls, never
  /// stopped wholesale from the process list.
  bool get stoppable => this != opencodeServer;
}

enum TermuxOrphanReason { parentGone, cpuNoOwner }

class TermuxProcess {
  const TermuxProcess({
    required this.pid,
    required this.ppid,
    required this.group,
    required this.name,
    required this.cmd,
    required this.cpuPct,
    required this.cpuSeconds,
    required this.rssKb,
    required this.elapsedSeconds,
    required this.cwd,
    required this.orphanReason,
    required this.protected,
  });

  final int pid;
  final int ppid;
  final TermuxProcessGroup group;
  final String name;
  final String cmd;
  final double cpuPct;
  final int cpuSeconds;
  final int rssKb;
  final int elapsedSeconds;
  final String cwd;
  final TermuxOrphanReason? orphanReason;
  final bool protected;

  bool get isOrphan => group == TermuxProcessGroup.orphans;

  static TermuxProcess? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final pid = _int(raw['pid']);
    if (pid <= 0) return null;
    return TermuxProcess(
      pid: pid,
      ppid: _int(raw['ppid']),
      group: TermuxProcessGroup.parse(raw['group']?.toString()),
      name: raw['name']?.toString() ?? '',
      cmd: raw['cmd']?.toString() ?? '',
      cpuPct: switch (raw['cpu_pct']) {
        num v => v.toDouble(),
        String v => double.tryParse(v) ?? 0,
        _ => 0,
      },
      cpuSeconds: _int(raw['cpu_seconds']),
      rssKb: _int(raw['rss_kb']),
      elapsedSeconds: _int(raw['elapsed_s']),
      cwd: raw['cwd']?.toString() ?? '',
      orphanReason: switch (raw['orphan_reason']?.toString()) {
        'parent_gone' => TermuxOrphanReason.parentGone,
        'cpu_no_owner' => TermuxOrphanReason.cpuNoOwner,
        _ => null,
      },
      protected: raw['protected'] == true,
    );
  }
}

class TermuxProcessReport {
  const TermuxProcessReport(this.processes);

  final List<TermuxProcess> processes;

  int get count => processes.length;

  double get totalCpuPct => processes.fold(0.0, (sum, p) => sum + p.cpuPct);

  int get totalRssKb => processes.fold(0, (sum, p) => sum + p.rssKb);

  List<TermuxProcess> inGroup(TermuxProcessGroup group) =>
      processes.where((p) => p.group == group).toList();

  /// Groups in display order, only those with members.
  List<TermuxProcessGroup> get groups => [
    for (final group in TermuxProcessGroup.values)
      if (processes.any((p) => p.group == group)) group,
  ];

  /// Orphans that have burned more than [threshold] of CPU: the Workspace's
  /// "Something is still running on this phone" line.
  List<TermuxProcess> orphansOver(Duration threshold) => processes
      .where((p) => p.isOrphan && p.cpuSeconds > threshold.inSeconds)
      .toList();

  static TermuxProcessReport parse(String json) {
    final trimmed = json.trim();
    if (trimmed.isEmpty) return const TermuxProcessReport([]);
    final decoded = jsonDecode(trimmed);
    if (decoded is! List) {
      throw const TermuxBridgeException(
        'Could not read the process list.',
        code: 'invalid_process_list',
      );
    }
    return TermuxProcessReport([
      for (final raw in decoded) ?TermuxProcess.fromJson(raw),
    ]);
  }
}

class TermuxProcessStopResult {
  const TermuxProcessStopResult({
    required this.stopped,
    required this.killed,
    required this.remaining,
    required this.refused,
  });

  final List<int> stopped;
  final List<int> killed;
  final List<({int pid, String name})> remaining;
  final List<({int pid, String reason})> refused;

  int get endedCount => stopped.length + killed.length;

  static TermuxProcessStopResult parse(String json) {
    final decoded = jsonDecode(json.trim());
    if (decoded is! Map) {
      throw const TermuxBridgeException(
        'Could not read the stop result.',
        code: 'invalid_stop_result',
      );
    }
    List<int> pids(Object? raw) => [
      for (final v in raw as List? ?? const [])
        if (_int(v) > 0) _int(v),
    ];
    return TermuxProcessStopResult(
      stopped: pids(decoded['stopped']),
      killed: pids(decoded['killed']),
      remaining: [
        for (final raw in decoded['remaining'] as List? ?? const [])
          if (raw is Map)
            (pid: _int(raw['pid']), name: raw['name']?.toString() ?? ''),
      ],
      refused: [
        for (final raw in decoded['refused'] as List? ?? const [])
          if (raw is Map)
            (pid: _int(raw['pid']), reason: raw['reason']?.toString() ?? ''),
      ],
    );
  }
}

/// Runs the process verbs of `~/.oc/tools.sh`.
class TermuxProcesses {
  const TermuxProcesses._();

  static Future<TermuxProcessReport> scan() async => TermuxProcessReport.parse(
    await TermuxBridge.runTool(
      'procs-scan',
      timeout: const Duration(seconds: 20),
    ),
  );

  /// TERM, five seconds, then KILL; protected processes are refused.
  static Future<TermuxProcessStopResult> stopPid(int pid) async {
    if (pid <= 1) throw ArgumentError.value(pid, 'pid');
    return TermuxProcessStopResult.parse(
      await TermuxBridge.runTool(
        'procs-stop',
        argument: '$pid',
        timeout: const Duration(seconds: 25),
      ),
    );
  }

  static Future<TermuxProcessStopResult> stopGroup(
    TermuxProcessGroup group,
  ) async => TermuxProcessStopResult.parse(
    await TermuxBridge.runTool(
      'procs-stop',
      argument: group.wireName,
      timeout: const Duration(seconds: 25),
    ),
  );
}

int _int(Object? value) => switch (value) {
  int v => v,
  num v => v.toInt(),
  String v => int.tryParse(v) ?? 0,
  _ => 0,
};
