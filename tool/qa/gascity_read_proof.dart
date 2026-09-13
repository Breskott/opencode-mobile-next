// TEAM-114: read proof against a live Gas City supervisor, through the same
// adapter the app uses (`GasCityProbe` + `GasCityGateway`) and nothing else.
//
//   dart run tool/qa/gascity_read_proof.dart [--url http://127.0.0.1:8372]
//       [--city bright-lights] [--version 1.4.1] [--wait 20]
//
// Steps: probe the URL and city; read projects, runs (with the partial
// flag), work (list + ready set), agents, gates and usage; open the event
// stream and wait at most `--wait` seconds for one frame or heartbeat;
// record the last seq; close; reopen with `Last-Event-ID` a few events back
// and check the replay carries no duplicate ids and starts where asked.
// Alongside, the raw `/agents`, `/beads`, `/convoys` and `/pending` counts
// are fetched over plain HTTP so the report shows the adapter's counts
// match the host's.
//
// Prints one compact JSON report on stdout and exits 1 on any failure. No
// Flutter imports: the adapter is plain Dart.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_probe.dart';
import 'package:opencode_mobile/orchestration/events/cursor.dart';

Future<void> main(List<String> args) async {
  var url = 'http://127.0.0.1:8372';
  var city = 'bright-lights';
  var expectedVersion = '1.4.1';
  var wait = const Duration(seconds: 20);
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--url':
        url = args[++i];
      case '--city':
        city = args[++i];
      case '--version':
        expectedVersion = args[++i];
      case '--wait':
        wait = Duration(seconds: int.parse(args[++i]));
      default:
        stderr.writeln('unknown argument ${args[i]}');
        exit(2);
    }
  }
  final proof = _ReadProof(
    url: url,
    city: city,
    expectedVersion: expectedVersion,
    wait: wait,
  );
  final report = await proof.run();
  stdout.writeln(jsonEncode(report));
  exit(report['ok'] == true ? 0 : 1);
}

class _ReadProof {
  _ReadProof({
    required this.url,
    required this.city,
    required this.expectedVersion,
    required this.wait,
  });

  final String url;
  final String city;
  final String expectedVersion;
  final Duration wait;

  final failures = <String>[];
  final timingsMs = <String, int>{};

  void check(bool condition, String message) {
    if (!condition) failures.add(message);
  }

  Future<T> timed<T>(String name, Future<T> Function() body) async {
    final watch = Stopwatch()..start();
    try {
      return await body();
    } finally {
      timingsMs[name] = watch.elapsedMilliseconds;
    }
  }

  Future<Map<String, Object?>> run() async {
    final total = Stopwatch()..start();
    final report = <String, Object?>{
      'url': url,
      'city': city,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
    };

    // 1. Probe.
    final verdict = await timed(
      'probe',
      () => const GasCityProbe().probe(url, city: city),
    );
    report['probe'] = verdict.describe();
    if (verdict is! ProbeFound) {
      failures.add('probe: ${verdict.describe()}');
      return _finish(report, total);
    }
    check(
      verdict.version == expectedVersion,
      'probe version ${verdict.version} != $expectedVersion',
    );
    check(verdict.city == city, 'probe city ${verdict.city} != $city');
    report['version'] = verdict.version;
    report['readOnly'] = verdict.readOnly;

    // 2. Reads through the adapter.
    final gateway = GasCityGateway(url: url, city: city);
    try {
      final host = await timed('connect', gateway.connect);
      report['host'] = {
        'provider': host.provider,
        'version': host.version,
        'city': host.city,
      };

      final projects = await timed('projects', gateway.projects);
      report['projects'] = [
        for (final p in projects) {'id': p.id, 'name': p.name, 'rig': p.rig},
      ];

      final runs = await timed('runs', gateway.runs);
      final runsPartial = gateway.partialNotices['runs'];
      report['runs'] = {
        'count': runs.length,
        'partial': runsPartial != null,
        if (runsPartial != null) 'partialReasons': runsPartial.reasons,
        'states': _tally(runs.map((r) => r.state.name)),
      };

      final work = await timed('work', gateway.work);
      final ready = await timed('readyWork', gateway.readyWork);
      final workPartial = gateway.partialNotices['work'];
      final readyIds = {for (final w in ready) w.id};
      check(
        readyIds.every((id) => work.any((w) => w.id == id)),
        'ready set contains ids missing from the work list',
      );
      report['work'] = {
        'count': work.length,
        'ready': ready.length,
        'partial': workPartial != null,
        'states': _tally(work.map((w) => w.state.name)),
        'blocked': work.where((w) => w.isBlocked).length,
      };

      final agents = await timed('agents', gateway.agents);
      report['agents'] = {
        'count': agents.length,
        'states': _tally(agents.map((a) => a.state.name)),
        'names': [
          for (final a in agents) '${a.name}:${a.rawState ?? a.state.name}',
        ],
      };

      final gates = await timed('gates', gateway.gates);
      report['gates'] = {
        'count': gates.length,
        'kinds': _tally(gates.map((g) => g.kind.name)),
      };

      final usage = await timed('usage', gateway.usage);
      report['usage'] = usage == null
          ? null
          : {
              'activeAgents': usage.activeAgents,
              'runsInProgress': usage.runsInProgress,
              'workOpen': usage.workOpen,
              'workReady': usage.workReady,
              'inputTokens': usage.inputTokens,
              'outputTokens': usage.outputTokens,
              'costUsd': usage.costUsd,
            };

      final activity = await timed(
        'activity',
        () => gateway.activity(limit: 5),
      );
      final headSeq = activity
          .map((e) => e.seq)
          .whereType<int>()
          .fold<int?>(null, (max, s) => max == null || s > max ? s : max);
      report['activityHeadSeq'] = headSeq;
      check(headSeq != null, 'activity carries no seq');

      // 3. Raw counts over plain HTTP for the "matching counts" column.
      final raw = await timed('rawCounts', () => _rawCounts(gateway));
      report['raw'] = raw;
      check(
        raw['agents'] == agents.length,
        'agents: adapter ${agents.length} != raw ${raw['agents']}',
      );
      // `/beads` carries Gas City's own beads too (sessions, convoys,
      // molecules, nudges); the adapter lists only the work a person slung.
      check(
        raw['beadsWork'] == work.length,
        'work: adapter ${work.length} != raw /beads ${raw['beads']} '
        '- internal ${raw['beadsInternal']}',
      );
      check(
        raw['pending'] == gates.length,
        'gates: adapter ${gates.length} != raw /pending ${raw['pending']}',
      );
      // Runs come from `/runs` + `/convoys`; while the run projection is
      // warming the host reports `partial` and only convoys count.
      check(
        runsPartial != null
            ? runs.length >= (raw['convoys'] as int)
            : runs.length == (raw['runs'] as int) + (raw['convoys'] as int),
        'runs: adapter ${runs.length} vs raw /runs ${raw['runs']} '
        '+ /convoys ${raw['convoys']} (partial: ${runsPartial != null})',
      );

      // 4. Event stream: first frame or heartbeat within the wait.
      final first = await timed('streamFirst', () => _streamOnce(gateway));
      report['stream'] = first;
      check(first['frames'] as int > 0, 'no frame or heartbeat within $wait');
      final streamSeq = first['lastSeq'] as int?;
      final lastSeq = [
        ?streamSeq,
        ?headSeq,
      ].fold<int?>(null, (max, s) => max == null || s > max ? s : max);
      report['lastSeq'] = lastSeq;

      // 5. Reopen a few events back with Last-Event-ID: strictly increasing
      // ids, none duplicated, starting right after the requested seq.
      if (lastSeq != null) {
        final resumeFrom = (lastSeq - 5).clamp(0, lastSeq);
        final resumed = await timed(
          'streamResume',
          () => _streamResume(gateway, resumeFrom),
        );
        report['resume'] = resumed;
        final ids = (resumed['ids'] as List).cast<int>();
        check(ids.isNotEmpty, 'resume replayed nothing');
        check(
          ids.toSet().length == ids.length,
          'resume replayed duplicate ids: $ids',
        );
        check(
          ids.every((id) => id > resumeFrom),
          'resume replayed ids at or before $resumeFrom: $ids',
        );
        check(
          ids.isEmpty || ids.first == resumeFrom + 1,
          'resume started at ${ids.first}, expected ${resumeFrom + 1}',
        );
        check(
          resumed['headOnlyReplay'] == false,
          'host ignored Last-Event-ID (head-only replay)',
        );
        for (var i = 1; i < ids.length; i++) {
          check(ids[i] > ids[i - 1], 'resume ids not increasing: $ids');
        }
      }
    } on Object catch (error) {
      failures.add('exception: $error');
    } finally {
      await gateway.close();
    }
    return _finish(report, total);
  }

  Map<String, Object?> _finish(Map<String, Object?> report, Stopwatch total) {
    report['timingsMs'] = timingsMs;
    report['totalMs'] = total.elapsedMilliseconds;
    report['failures'] = failures;
    report['ok'] = failures.isEmpty;
    return report;
  }

  /// `/agents`, `/beads`, `/convoys`, `/pending`, `/runs` item counts,
  /// read with the adapter's HTTP client but no mapping.
  Future<Map<String, Object?>> _rawCounts(GasCityGateway gateway) async {
    final out = <String, Object?>{};
    for (final tail in ['/agents', '/beads', '/convoys', '/pending']) {
      final json = await gateway.http.getCity(tail);
      out[tail.substring(1)] = _count(json, 'items');
      if (tail == '/beads') {
        final items = (json['items'] as List? ?? const []).cast<Map>();
        final internal = items.where(_isInternalBead).length;
        out['beadsInternal'] = internal;
        out['beadsWork'] = items.length - internal;
      }
    }
    final runs = await gateway.http.getCity('/runs');
    out['runs'] = _count(runs, 'runs');
    out['runsPartial'] = runs['partial'] == true;
    return out;
  }

  /// The same rule as `isInternalBead` in the mappers, applied to the raw
  /// JSON so the comparison does not go through the adapter.
  static bool _isInternalBead(Map bead) {
    const internalTypes = {'session', 'convoy', 'message', 'molecule'};
    if (internalTypes.contains(bead['issue_type'])) return true;
    final labels = bead['labels'];
    return labels is List &&
        (labels.contains('gc:session') || labels.contains('gc:nudge'));
  }

  static int _count(Map<String, Object?> json, String key) {
    final items = json[key];
    if (items is List) return items.length;
    final total = json['total'];
    return total is int ? total : 0;
  }

  /// Opens the stream fresh and waits for one frame or heartbeat.
  Future<Map<String, Object?>> _streamOnce(GasCityGateway gateway) async {
    final client = gateway.openStream();
    final firstFrame = Completer<void>();
    var frames = 0;
    var heartbeats = 0;
    var events = 0;
    final subscription = client.frames.listen((frame) {
      frames += 1;
      if (frame.isHeartbeat) heartbeats += 1;
      if (frame.isCityEvent) events += 1;
      if (!firstFrame.isCompleted) firstFrame.complete();
    });
    final statuses = <String>[];
    final statusSub = client.status.listen((s) => statuses.add(s.name));
    client.start();
    final timedOut = await firstFrame.future
        .timeout(wait)
        .then((_) => false, onError: (_) => true);
    await subscription.cancel();
    await statusSub.cancel();
    await client.close();
    return {
      'frames': frames,
      'heartbeats': heartbeats,
      'events': events,
      'timedOut': timedOut,
      'lastSeq': client.cursor.seq,
      'lastEventId': client.cursor.lastEventId,
      'connections': client.connectionCount,
      'statuses': statuses,
    };
  }

  /// Reopens from [seq] with `Last-Event-ID`; collects replayed ids for a
  /// short window after the first frame.
  Future<Map<String, Object?>> _streamResume(
    GasCityGateway gateway,
    int seq,
  ) async {
    final client = gateway.openStream(resumeFrom: EventCursor(seq: seq));
    final ids = <int>[];
    var headOnly = false;
    final firstFrame = Completer<void>();
    final replaySub = client.headOnlyReplay.listen((_) => headOnly = true);
    final subscription = client.frames.listen((frame) {
      final id = frame.seq;
      if (id != null) ids.add(id);
      if (!firstFrame.isCompleted) firstFrame.complete();
    });
    client.start();
    await firstFrame.future.timeout(wait, onTimeout: () {});
    // Let the backlog drain before judging it.
    await Future<void>.delayed(const Duration(seconds: 2));
    await subscription.cancel();
    await replaySub.cancel();
    await client.close();
    return {
      'requestedSeq': seq,
      'ids': ids,
      'headOnlyReplay': headOnly,
      'cursorSeq': client.cursor.seq,
    };
  }

  static Map<String, int> _tally(Iterable<String> values) {
    final out = <String, int>{};
    for (final v in values) {
      out[v] = (out[v] ?? 0) + 1;
    }
    return Map.fromEntries(
      out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }
}
