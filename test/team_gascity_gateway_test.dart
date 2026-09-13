// TEAM-104: Gas City read adapter, probe and SSE client against the real
// Python fixture server (tool/qa/gascity_fixture), started as a subprocess
// on an ephemeral port. Skipped with a message when python3 is missing.
// TEAM-202 adds the write path against the fixture's `--front` mode: the
// well-known probe, `Idempotency-Key` receipts, replays, front problems and
// the full receipt lifecycle through the controller (stream drop included).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_mappers.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_probe.dart';
import 'package:opencode_mobile/orchestration/client/http.dart';
import 'package:opencode_mobile/orchestration/client/sse.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _city = 'bright-lights';
const _firstSeq = 1026;
const _lastSeq = 1443;
const _branchSeq = 1200;

final Directory _fixtureRoot = _findFixtureRoot();

Directory _findFixtureRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory('${dir.path}/tool/qa/gascity_fixture');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError(
    'tool/qa/gascity_fixture not found from ${Directory.current}',
  );
}

/// One running fixture server subprocess.
class _Fixture {
  _Fixture._(this.process, this.port);

  final Process process;
  final int port;

  String get baseUrl => 'http://127.0.0.1:$port';

  static Future<_Fixture> start({
    int dropAfter = 5,
    bool front = false,
    double resultDelay = 0,
  }) async {
    final process = await Process.start('python3', [
      '${_fixtureRoot.path}/fixture_server.py',
      '--port',
      '0',
      '--pace',
      '0',
      '--heartbeat',
      '0.2',
      '--drop-after',
      '$dropAfter',
      if (front) '--front',
      '--result-delay',
      '$resultDelay',
    ]);
    process.stdout.drain<void>();
    final lines = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final completer = Completer<int>();
    lines.listen(
      (line) {
        final match = RegExp(r'http://127\.0\.0\.1:(\d+)/').firstMatch(line);
        if (match != null && !completer.isCompleted) {
          completer.complete(int.parse(match.group(1)!));
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(StateError('fixture exited before binding'));
        }
      },
    );
    final port = await completer.future.timeout(const Duration(seconds: 20));
    // The socket is bound before the banner; wait until it answers.
    for (var i = 0; i < 50; i++) {
      try {
        final socket = await Socket.connect('127.0.0.1', port);
        socket.destroy();
        break;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    return _Fixture._(process, port);
  }

  Future<void> stop() async {
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }
}

Future<bool> _hasPython() async {
  try {
    final result = await Process.run('python3', ['--version']);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Subscribes to the gateway's stream from [from] and returns once an
/// event with `seq >= untilSeq` has arrived (which also drives the
/// fixture's replay head that far).
Future<List<OrchestrationEvent>> _drive(
  GasCityGateway gateway, {
  required int from,
  required int untilSeq,
}) async {
  final seen = <OrchestrationEvent>[];
  final done = Completer<void>();
  final sub = gateway.events(resumeFrom: EventCursor(seq: from)).listen((
    event,
  ) {
    seen.add(event);
    final seq = event.seq;
    if (seq != null && seq >= untilSeq && !done.isCompleted) {
      done.complete();
    }
  });
  await done.future.timeout(const Duration(seconds: 30));
  await sub.cancel();
  return seen;
}

void main() {
  late bool hasPython;
  _Fixture? fixture;
  _Fixture? frontFixture;

  setUpAll(() async {
    hasPython = await _hasPython();
    if (hasPython) {
      final both = await Future.wait([
        _Fixture.start(),
        _Fixture.start(front: true),
      ]);
      fixture = both[0];
      frontFixture = both[1];
    }
  });

  tearDownAll(() async {
    await fixture?.stop();
    await frontFixture?.stop();
  });

  /// Skips the test when python3 is missing; returns the front fixture else.
  _Fixture? needFront() {
    if (!hasPython || frontFixture == null) {
      markTestSkipped('python3 not found: fixture server tests skipped');
      return null;
    }
    return frontFixture;
  }

  /// Skips the test when python3 is missing; returns the fixture else.
  _Fixture? needFixture() {
    if (!hasPython || fixture == null) {
      markTestSkipped('python3 not found: fixture server tests skipped');
      return null;
    }
    return fixture;
  }

  GasCityGateway gatewayFor(
    _Fixture fx,
    String scenario, {
    OrchestrationHttpClient? http,
    bool front = false,
  }) => GasCityGateway(
    url: fx.baseUrl,
    city: _city,
    front: front,
    defaultQuery: {'scenario': scenario},
    backoffBase: const Duration(milliseconds: 50),
    backoffCap: const Duration(milliseconds: 400),
    http: http,
  );

  group('transport rule', () {
    test('isTailnetHost: CGNAT range, MagicDNS, loopback', () {
      expect(isTailnetHost('100.64.0.1'), isTrue);
      expect(isTailnetHost('100.100.1.2'), isTrue);
      expect(isTailnetHost('100.127.255.255'), isTrue);
      expect(isTailnetHost('100.128.0.0'), isFalse);
      expect(isTailnetHost('100.63.255.255'), isFalse);
      expect(isTailnetHost('pc.tail1234.ts.net'), isTrue);
      expect(isTailnetHost('PC.TAIL1234.TS.NET'), isTrue);
      expect(isTailnetHost('evil.ts.net.example.com'), isFalse);
      expect(isTailnetHost('localhost'), isTrue);
      expect(isTailnetHost('127.0.0.1'), isTrue);
      expect(isTailnetHost('[::1]'), isTrue);
      expect(isTailnetHost('203.0.113.5'), isFalse);
      expect(isTailnetHost('example.com'), isFalse);
      expect(isTailnetHost(''), isFalse);
    });

    test('isOrchestrationUrlAllowed: https anywhere, http only near', () {
      expect(
        isOrchestrationUrlAllowed(Uri.parse('https://example.com')),
        isTrue,
      );
      expect(
        isOrchestrationUrlAllowed(Uri.parse('http://127.0.0.1:1')),
        isTrue,
      );
      expect(isOrchestrationUrlAllowed(Uri.parse('http://100.64.1.1')), isTrue);
      expect(isOrchestrationUrlAllowed(Uri.parse('http://a.ts.net')), isTrue);
      expect(
        isOrchestrationUrlAllowed(Uri.parse('http://203.0.113.5')),
        isFalse,
      );
      expect(isOrchestrationUrlAllowed(Uri.parse('ftp://127.0.0.1')), isFalse);
      expect(isOrchestrationUrlAllowed(Uri.parse('not a url')), isFalse);
    });

    test('GasCityGateway refuses a plain-HTTP URL off the tailnet', () {
      expect(
        () => GasCityGateway(url: 'http://203.0.113.5:8372', city: _city),
        throwsArgumentError,
      );
    });

    test('backoff grows exponentially with jitter and caps at 30 s', () {
      final random = Random(7);
      Duration at(int attempt) => backoffDelay(attempt, random: random);
      expect(at(0).inMilliseconds, inInclusiveRange(250, 750));
      expect(at(1).inMilliseconds, inInclusiveRange(500, 1500));
      expect(at(3).inMilliseconds, inInclusiveRange(2000, 6000));
      for (var attempt = 6; attempt < 40; attempt++) {
        expect(at(attempt).inMilliseconds, lessThanOrEqualTo(30000));
      }
      expect(at(20).inMilliseconds, greaterThanOrEqualTo(15000));
    });
  });

  group('probe', () {
    test('plainHttpRefused is decided before any network call', () async {
      final watch = Stopwatch()..start();
      final verdict = await const GasCityProbe(
        timeout: Duration(seconds: 30),
      ).probe('http://203.0.113.5:8372', city: _city);
      watch.stop();
      expect(verdict, isA<ProbePlainHttpRefused>());
      expect((verdict as ProbePlainHttpRefused).host, '203.0.113.5');
      // 203.0.113.0/24 is TEST-NET-3: a real connect would hang to timeout.
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('unreachable on a closed port', () async {
      final socket = await ServerSocket.bind('127.0.0.1', 0);
      final port = socket.port;
      await socket.close();
      final verdict = await const GasCityProbe(
        timeout: Duration(seconds: 3),
      ).probe('http://127.0.0.1:$port', city: _city);
      expect(verdict, isA<ProbeUnreachable>());
      expect(verdict.describe(), startsWith('Unreachable'));
    });

    test(
      'notGasCity on an HTML answer, and no credential header sent',
      () async {
        final seenHeaders = <Map<String, String>>[];
        final server = await HttpServer.bind('127.0.0.1', 0);
        server.listen((request) {
          final headers = <String, String>{};
          request.headers.forEach((k, v) => headers[k] = v.join(','));
          seenHeaders.add(headers);
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('<!doctype html><title>Welcome</title>')
            ..close();
        });
        addTearDown(() => server.close(force: true));
        final verdict = await const GasCityProbe().probe(
          'http://127.0.0.1:${server.port}',
          city: _city,
        );
        expect(verdict, isA<ProbeNotGasCity>());
        expect((verdict as ProbeNotGasCity).statusCode, 200);
        expect(seenHeaders, isNotEmpty);
        for (final headers in seenHeaders) {
          for (final key in headers.keys) {
            expect(
              credentialHeaders.contains(key.toLowerCase()),
              isFalse,
              reason: 'credential header $key was sent on a probe',
            );
          }
        }
      },
    );

    test('notGasCity on JSON that is not the health shape', () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) {
        request.response
          ..headers.contentType = ContentType.json
          ..write('{"ok": true}')
          ..close();
      });
      addTearDown(() => server.close(force: true));
      final verdict = await const GasCityProbe().probe(
        'http://127.0.0.1:${server.port}',
      );
      expect(verdict, isA<ProbeNotGasCity>());
    });

    test('cityNotRunning when /v0/cities lists the city stopped', () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) {
        final path = request.uri.path;
        request.response.headers.contentType = ContentType.json;
        if (path == '/health') {
          request.response.write(
            '{"status":"ok","version":"9.9.9","city":"$_city"}',
          );
        } else if (path == '/v0/cities') {
          request.response.write(
            '{"items":[{"name":"$_city","running":false,"status":"stopped"}],'
            '"total":1}',
          );
        } else {
          request.response.statusCode = 404;
          request.response.write('{}');
        }
        request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final verdict = await const GasCityProbe().probe(
        'http://127.0.0.1:${server.port}',
        city: _city,
      );
      expect(verdict, isA<ProbeCityNotRunning>());
      final notRunning = verdict as ProbeCityNotRunning;
      expect(notRunning.city, _city);
      expect(notRunning.known, [_city]);
    });

    test(
      'found against the fixture: version, city, read-only, identity',
      () async {
        final fx = needFixture();
        if (fx == null) return;
        final verdict = await const GasCityProbe().probe(
          fx.baseUrl,
          city: _city,
        );
        expect(verdict, isA<ProbeFound>());
        final found = verdict as ProbeFound;
        expect(found.version, '1.4.1');
        expect(found.city, _city);
        expect(found.readOnly, isTrue);
        expect(found.host.provider, 'gascity');
        expect(found.host.url, fx.baseUrl);
        expect(found.host.version, '1.4.1');
        expect(found.host.city, _city);
        expect(found.host.hostMode, OrchestrationHostMode.computer);
        expect(found.describe(), contains('1.4.1'));
      },
    );

    test('found with no city asked uses the one /health reports', () async {
      final fx = needFixture();
      if (fx == null) return;
      final verdict = await const GasCityProbe().probe(fx.baseUrl);
      expect(verdict, isA<ProbeFound>());
      expect((verdict as ProbeFound).city, _city);
    });

    test('cityNotRunning for a city the fixture does not serve', () async {
      final fx = needFixture();
      if (fx == null) return;
      final verdict = await const GasCityProbe().probe(
        fx.baseUrl,
        city: 'nowhere',
      );
      expect(verdict, isA<ProbeCityNotRunning>());
      final notRunning = verdict as ProbeCityNotRunning;
      expect(notRunning.city, 'nowhere');
      expect(notRunning.known, contains(_city));
    });
  });

  group('http client', () {
    test(
      'problem+json becomes OrchestrationHttpException with request id',
      () async {
        final fx = needFixture();
        if (fx == null) return;
        final client = OrchestrationHttpClient(
          baseUrl: fx.baseUrl,
          city: _city,
        );
        addTearDown(client.close);
        try {
          await client.getCity('/bead/does-not-exist');
          fail('expected a 404');
        } on OrchestrationHttpException catch (e) {
          expect(e.statusCode, 404);
          expect(e.code, 'bead-not-found');
          expect(e.isNotFound, isTrue);
          expect(e.problem.title, 'Bead Not Found');
          expect(e.requestId, isNotNull);
          expect(e.toString(), contains('bead-not-found'));
        }
        final health = await client.getCity('/health');
        expect(health['version'], '1.4.1');
        expect(client.lastRequestId, isNotNull);
      },
    );

    test(
      'a caller-supplied Authorization header is stripped from reads',
      () async {
        final seen = <String, String>{};
        final server = await HttpServer.bind('127.0.0.1', 0);
        server.listen((request) {
          request.headers.forEach((k, v) => seen[k.toLowerCase()] = v.join());
          request.response
            ..headers.contentType = ContentType.json
            ..write('{"status":"ok"}')
            ..close();
        });
        addTearDown(() => server.close(force: true));
        final dio = Dio(
          BaseOptions(
            baseUrl: 'http://127.0.0.1:${server.port}',
            validateStatus: (_) => true,
            headers: {'Authorization': 'Basic leak', 'Cookie': 'sid=leak'},
          ),
        );
        final client = OrchestrationHttpClient(
          baseUrl: 'http://127.0.0.1:${server.port}',
          city: _city,
          dio: dio,
        );
        addTearDown(client.close);
        await client.getJson('/health');
        expect(seen.keys.where(credentialHeaders.contains), isEmpty);
      },
    );

    test('POST carries X-GC-Request and a JSON body; GET never does', () async {
      final seen = <({String method, String? request, String body})>[];
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        seen.add((
          method: request.method,
          request: request.headers.value(mutationRequestHeader),
          body: body,
        ));
        request.response
          ..headers.contentType = ContentType.json
          ..write('{"status":"slung"}')
          ..close();
      });
      addTearDown(() => server.close(force: true));
      final client = OrchestrationHttpClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        city: _city,
      );
      addTearDown(client.close);
      final response = await client.postJson('${client.cityPath}/sling', {
        'target': 'ocproof/polecat',
        'bead': 'oc-loy',
      }, requestId: 'req-test-1');
      expect(response['status'], 'slung');
      await client.getCity('/health');
      expect(seen, hasLength(2));
      expect(seen[0].method, 'POST');
      expect(seen[0].request, 'req-test-1');
      expect(jsonDecode(seen[0].body), {
        'target': 'ocproof/polecat',
        'bead': 'oc-loy',
      });
      expect(seen[1].method, 'GET');
      expect(seen[1].request, isNull);
    });
  });

  group('reads against normal', () {
    final requests = <RequestOptions>[];
    late GasCityGateway gateway;

    setUp(() {
      final fx = fixture;
      if (fx == null) return;
      requests.clear();
      gateway = gatewayFor(
        fx,
        'normal',
        http: OrchestrationHttpClient(
          baseUrl: fx.baseUrl,
          city: _city,
          defaultQuery: const {'scenario': 'normal'},
          onRequest: requests.add,
        ),
      );
    });

    tearDown(() async {
      if (fixture != null) await gateway.close();
    });

    test('capabilities, connect and host identity', () async {
      if (needFixture() == null) return;
      expect(gateway.capabilities, same(OrchestrationCapabilities.gascityRead));
      expect(gateway.host, isNull);
      final identity = await gateway.connect();
      expect(identity.provider, 'gascity');
      expect(identity.version, '1.4.1');
      expect(identity.city, _city);
      expect(gateway.host, identity);
    });

    test('projects come from /status rigs', () async {
      if (needFixture() == null) return;
      final projects = await gateway.projects();
      expect(projects.map((p) => p.id), ['ocproof']);
      expect(projects.single.rig, 'ocproof');
      expect(projects.single.directory, isNotNull);
    });

    test(
      'runs merge /runs and /convoys and surface the partial flag',
      () async {
        if (needFixture() == null) return;
        final runs = await gateway.runs();
        expect(
          runs.where((r) => r.kind == RunKind.batch).map((r) => r.id),
          contains('oc-xru'),
        );
        final notice = gateway.partialNotices['runs'];
        expect(notice, isNotNull);
        expect(notice!.reasons, contains('run projection is warming'));
        expect(await gateway.run('oc-xru'), isNotNull);
        expect(await gateway.run('nope'), isNull);
      },
    );

    test(
      'work: oc-loy on branch polecat/oc-loy after the run, ready set',
      () async {
        if (needFixture() == null) return;
        await _drive(gateway, from: _firstSeq - 1, untilSeq: _lastSeq);
        final item = await gateway.workItem('oc-loy');
        expect(item, isNotNull);
        expect(item!.branch, 'polecat/oc-loy');
        expect(item.projectId, 'ocproof');
        expect(item.sessionId, 'bl-48k');

        final work = await gateway.work();
        expect(work.map((w) => w.id), contains('oc-loy'));
        expect(work.map((w) => w.id), contains('gc-19'));
        // Internal beads (sessions, convoys, mail) are filtered out.
        expect(work.where((w) => w.issueType == 'session'), isEmpty);
        expect(work.where((w) => w.issueType == 'convoy'), isEmpty);

        final ready = await gateway.readyWork();
        expect(ready.map((w) => w.id), ['gc-19']);
        expect(ready.single.state, WorkState.ready);

        expect(await gateway.workItem('does-not-exist'), isNull);
      },
    );

    test('agents join /agents with /sessions', () async {
      if (needFixture() == null) return;
      final agents = await gateway.agents();
      final names = agents.map((a) => a.name).toList();
      expect(names, contains('gastown.mayor'));
      // TEAM-115: the unspawned dog slots and the core helper are not
      // agents; only the live ones come back.
      expect(names, isNot(contains('gastown.dog-1')));
      expect(names, isNot(contains('core.control-dispatcher')));
      expect(agents.every((a) => a.state != AgentState.stopped), isTrue);
      final mayor = agents.firstWhere((a) => a.name == 'gastown.mayor');
      expect(mayor.state, AgentState.idle);
      // Sessions without an agent entry (pool instances) appear too.
      expect(agents.map((a) => a.sessionId), contains('bl-wisp-qqpj'));
      expect(await gateway.agent('gastown.mayor'), isNotNull);
      expect(await gateway.agent('bl-wisp-qqpj'), isNotNull);
      expect(await gateway.agent('gastown.dog-1'), isNull);
      expect(await gateway.agent('nobody'), isNull);
    });

    test('gates are empty and usage is an estimate', () async {
      if (needFixture() == null) return;
      expect(await gateway.gates(), isEmpty);
      final usage = await gateway.usage();
      expect(usage, isNotNull);
      expect(usage!.costUsd, 0);
      expect(usage.isEstimated, isTrue);
      expect(usage.activeAgents, isNotNull);
    });

    test('activity is oldest first and honours afterSeq', () async {
      if (needFixture() == null) return;
      final page = await gateway.activity(limit: 20);
      expect(page.length, 20);
      for (var i = 1; i < page.length; i++) {
        expect(page[i].seq!, greaterThan(page[i - 1].seq!));
      }
      final after = await gateway.activity(afterSeq: page.last.seq! - 3);
      expect(after.first.seq, page.last.seq! - 2);
    });

    test('controls are rejected with "front required"', () async {
      if (needFixture() == null) return;
      final receipt = await gateway.cancelRun('oc-xru', requestId: 'r1');
      expect(receipt.status, MutationReceiptStatus.rejected);
      expect(receipt.message, 'front required');
      expect(
        (await gateway.respond(
          'g',
          const GateResponse.confirmation(confirmed: true),
          requestId: 'r2',
        )).message,
        'front required',
      );
      expect(
        (await gateway.assign('w', agentId: 'a', requestId: 'r3')).message,
        'front required',
      );
    });

    test('no credential header is ever sent on reads or the stream', () async {
      if (needFixture() == null) return;
      await gateway.projects();
      await gateway.runs();
      await gateway.work();
      await gateway.agents();
      await gateway.gates();
      await gateway.usage();
      await gateway.activity();
      await _drive(gateway, from: _lastSeq - 2, untilSeq: _lastSeq);
      expect(requests.length, greaterThan(10));
      expect(
        requests.any((r) => r.uri.path.endsWith('/events/stream')),
        isTrue,
      );
      for (final request in requests) {
        expect(request.method, 'GET');
        for (final key in request.headers.keys) {
          expect(
            credentialHeaders.contains(key.toLowerCase()),
            isFalse,
            reason: '${request.uri.path} sent $key',
          );
        }
        expect(request.headers.containsKey(mutationRequestHeader), isFalse);
      }
    });
  });

  group('scenarios', () {
    test('blocked yields one gate of kind choice', () async {
      final fx = needFixture();
      if (fx == null) return;
      final gateway = gatewayFor(fx, 'blocked');
      addTearDown(gateway.close);
      final events = await _drive(
        gateway,
        from: _firstSeq - 1,
        untilSeq: _branchSeq + 1,
      );
      expect(events.whereType<BeadChanged>().last.beadId, 'oc-loy');
      final gates = await gateway.gates();
      expect(gates, hasLength(1));
      final gate = gates.single;
      expect(gate.kind, GateKind.choice);
      expect(gate.choices, ['replace', 'keep', 'stop']);
      expect(gate.agentId, 'bl-48k');
      final item = await gateway.workItem('oc-loy');
      expect(item!.state, WorkState.blocked);
      expect(item.isBlocked, isTrue);
    });

    test('failed yields one run in failed with last_error', () async {
      final fx = needFixture();
      if (fx == null) return;
      final gateway = gatewayFor(fx, 'failed');
      addTearDown(gateway.close);
      await _drive(gateway, from: _firstSeq - 1, untilSeq: _branchSeq + 1);
      final runs = await gateway.runs();
      final formula = runs.where((r) => r.kind == RunKind.formula).toList();
      expect(formula, hasLength(1));
      expect(formula.single.id, 'oc-loy');
      expect(formula.single.state, RunState.failed);
      expect(formula.single.lastError, isNotEmpty);
      // The convoy tracking oc-loy derives Failed from it as well.
      final batch = runs.firstWhere((r) => r.id == 'oc-xru');
      expect(batch.kind, RunKind.batch);
      expect(batch.state, RunState.failed);
      expect(gateway.partialNotices.containsKey('runs'), isFalse);
      final gates = await gateway.gates();
      final failedGates = gates.where((g) => g.kind == GateKind.runFailed);
      expect(
        failedGates.map((g) => g.runId),
        containsAll(['oc-loy', 'oc-xru']),
      );
      final item = await gateway.workItem('oc-loy');
      expect(item!.state, WorkState.failed);
    });

    test(
      'stream-drop: reconnects with Last-Event-ID, no gaps, no duplicates',
      () async {
        final fx = needFixture();
        if (fx == null) return;
        final gateway = gatewayFor(fx, 'stream-drop');
        addTearDown(gateway.close);
        final client = gateway.openStream(
          resumeFrom: const EventCursor(seq: _firstSeq - 1),
        );
        final statuses = <OrchestrationStreamStatus>[];
        client.status.listen(statuses.add);
        final seqs = <int>[];
        var heartbeats = 0;
        final done = Completer<void>();
        final sub = client.frames.listen((frame) {
          if (frame.isHeartbeat) {
            heartbeats++;
            return;
          }
          final seq = frame.seq!;
          seqs.add(seq);
          if (seq == _lastSeq && !done.isCompleted) done.complete();
        });
        await done.future.timeout(const Duration(seconds: 30));
        // Idle now: heartbeats keep the stream live.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await sub.cancel();
        expect(client.isClosed, isTrue);

        expect(
          seqs,
          List.generate(_lastSeq - _firstSeq + 1, (i) => _firstSeq + i),
        );
        expect(
          client.connectionCount,
          greaterThanOrEqualTo(2),
          reason: 'the fixture drops after 5 events; the client must reconnect',
        );
        expect(client.cursor.seq, _lastSeq);
        expect(client.cursor.lastEventIdHeader, '$_lastSeq');
        expect(heartbeats, greaterThan(0));
        expect(client.lastLiveAt, isNotNull);
        expect(statuses.first, OrchestrationStreamStatus.connecting);
        expect(statuses, contains(OrchestrationStreamStatus.reconnecting));
        expect(
          statuses.where((s) => s == OrchestrationStreamStatus.live).length,
          greaterThanOrEqualTo(2),
        );
        expect(statuses.last, OrchestrationStreamStatus.closed);
      },
    );
  });

  group('head-only replay', () {
    // A fresh fixture so the scenario heads are at the start of the run.
    _Fixture? fresh;

    setUpAll(() async {
      if (hasPython) fresh = await _Fixture.start();
    });

    tearDownAll(() async {
      await fresh?.stop();
    });

    test(
      'a cursor far ahead resumes from the head and signals dirty-all',
      () async {
        if (needFixture() == null || fresh == null) return;
        final gateway = gatewayFor(fresh!, 'normal');
        addTearDown(gateway.close);
        final events = <OrchestrationEvent>[];
        final done = Completer<void>();
        final sub = gateway
            .events(resumeFrom: const EventCursor(seq: 999999))
            .listen((event) {
              events.add(event);
              if (event is! StreamHeartbeat && events.length >= 5) {
                if (!done.isCompleted) done.complete();
              }
            });
        await done.future.timeout(const Duration(seconds: 30));
        await sub.cancel();
        final replay = events.whereType<StreamHeadOnlyReplay>().single;
        expect(replay.requestedSeq, 999999);
        expect(replay.firstSeq, _firstSeq);
        expect(replay.type, 'stream.head_only_replay');
        // The signal precedes the first replayed event.
        final real = events.where((e) => e is! StreamHeartbeat).toList();
        expect(real.first, same(replay));
        expect(real[1].seq, _firstSeq);
      },
    );

    test('a cursor behind the retained window signals too', () async {
      if (needFixture() == null || fresh == null) return;
      final gateway = gatewayFor(fresh!, 'failed');
      addTearDown(gateway.close);
      final client = gateway.openStream(resumeFrom: const EventCursor(seq: 1));
      final replays = <HeadOnlyReplay>[];
      client.headOnlyReplay.listen(replays.add);
      final first = await client.frames
          .where((f) => !f.isHeartbeat)
          .first
          .timeout(const Duration(seconds: 10));
      await client.close();
      expect(first.seq, 934); // oldest event the fixture retains
      expect(replays, hasLength(1));
      expect(replays.single.requestedSeq, 1);
      expect(replays.single.firstSeq, 934);
    });

    test('an honoured cursor raises no signal', () async {
      if (needFixture() == null || fresh == null) return;
      final gateway = gatewayFor(fresh!, 'blocked');
      addTearDown(gateway.close);
      final events = await _drive(
        gateway,
        from: _firstSeq - 1,
        untilSeq: _firstSeq + 3,
      );
      expect(events.whereType<StreamHeadOnlyReplay>(), isEmpty);
      expect(events.first.seq, _firstSeq);
    });
  });

  group('sse client', () {
    test(
      'reconnects after a refused connection with backoff, then closes',
      () async {
        final socket = await ServerSocket.bind('127.0.0.1', 0);
        final port = socket.port;
        await socket.close();
        final http = OrchestrationHttpClient(
          baseUrl: 'http://127.0.0.1:$port',
          city: _city,
          connectTimeout: const Duration(milliseconds: 500),
        );
        addTearDown(http.close);
        final client = OrchestrationSseClient(
          http: http,
          path: '/v0/city/$_city/events/stream',
          backoffBase: const Duration(milliseconds: 20),
          backoffCap: const Duration(milliseconds: 50),
        );
        final statuses = <OrchestrationStreamStatus>[];
        client.status.listen(statuses.add);
        final sub = client.frames.listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await sub.cancel();
        expect(statuses.first, OrchestrationStreamStatus.connecting);
        expect(
          statuses.where((s) => s == OrchestrationStreamStatus.reconnecting),
          isNotEmpty,
        );
        expect(statuses.last, OrchestrationStreamStatus.closed);
        expect(client.connectionCount, 0);
        expect(client.isClosed, isTrue);
      },
    );

    test('mapStreamFrame turns fixture frames into product events', () async {
      final fx = needFixture();
      if (fx == null) return;
      final gateway = gatewayFor(fx, 'normal');
      addTearDown(gateway.close);
      final events = await _drive(
        gateway,
        from: _lastSeq - 40,
        untilSeq: _lastSeq,
      );
      expect(events.whereType<BeadChanged>(), isNotEmpty);
      expect(events.whereType<UnknownOrchestrationEvent>(), isEmpty);
      expect(events.first.seq, _lastSeq - 39);
    });
  });

  group('agent output (TEAM-111)', () {
    test('turn frames of a session stream arrive as text captures', () async {
      final fx = needFixture();
      if (fx == null) return;
      final gateway = gatewayFor(fx, 'normal');
      addTearDown(gateway.close);
      final seen = <AgentOutputEvent>[];
      final enough = Completer<void>();
      final sub = gateway.agentOutput('bl-5qc').listen((event) {
        seen.add(event);
        if (seen.whereType<AgentOutputText>().length >= 17 &&
            !enough.isCompleted) {
          enough.complete();
        }
      });
      await enough.future.timeout(const Duration(seconds: 30));
      await sub.cancel();
      final texts = seen.whereType<AgentOutputText>().toList();
      expect(texts.length, 17);
      expect(texts.first.text, contains('[tool: bash]'));
      expect(texts.first.cursor, '1');
      expect(texts.last.cursor, '17');
      expect(seen.whereType<AgentOutputEnded>(), isEmpty);
      var merged = '';
      for (final text in texts) {
        merged = mergeAgentOutput(merged, text.text);
      }
      expect(merged.length, 26132);
      expect(
        parseAgentTranscript(merged).whereType<AgentStepGroup>().length,
        greaterThanOrEqualTo(5),
      );
    });

    test('a session the host does not serve ends the stream (404)', () async {
      final fx = needFixture();
      if (fx == null) return;
      final gateway = gatewayFor(fx, 'normal');
      addTearDown(gateway.close);
      final events = await gateway
          .agentOutput('bl-nope')
          .toList()
          .timeout(const Duration(seconds: 10));
      expect(events, hasLength(1));
      final ended = events.single as AgentOutputEnded;
      expect(ended.reason, contains('bl-nope'));
    });
  });

  group('front (TEAM-202)', () {
    test('the probe finds the front first and yields gascityFront', () async {
      final fx = needFront();
      if (fx == null) return;
      final verdict = await const GasCityProbe().probe(fx.baseUrl);
      expect(verdict, isA<ProbeFound>());
      final found = verdict as ProbeFound;
      expect(found.front, isTrue);
      expect(found.identityLogin, 'fixture@example.com');
      expect(found.identityAllowed, isTrue);
      expect(found.readOnly, isFalse);
      expect(found.capabilities.controlRespond, isTrue);
      expect(found.host.url, fx.baseUrl);
      expect(found.city, _city);
      // The bare fixture has no well-known document: read-only.
      final bare = await const GasCityProbe().probe(fixture!.baseUrl);
      expect((bare as ProbeFound).front, isFalse);
      expect(bare.readOnly, isTrue);
    });

    test('a message carries the Idempotency-Key and parses the receipt; '
        'a replay is flagged', () async {
      final fx = needFront();
      if (fx == null) return;
      final seen = <String, String?>{};
      final http = OrchestrationHttpClient(
        baseUrl: fx.baseUrl,
        city: _city,
        defaultQuery: {'scenario': 'normal'},
        onRequest: (options) {
          for (final entry in options.headers.entries) {
            seen[entry.key.toLowerCase()] = entry.value?.toString();
          }
        },
      );
      final gateway = gatewayFor(fx, 'normal', http: http, front: true);
      addTearDown(gateway.close);
      expect(gateway.capabilities.controlMessage, isTrue);
      final key = 'k-${Random().nextInt(1 << 30)}';
      final receipt = await gateway.message('bl-wn9', 'hello', requestId: key);
      expect(seen['idempotency-key'], key);
      expect(seen['x-gc-request'], key);
      expect(receipt.status, MutationReceiptStatus.accepted);
      expect(receipt.id, key);
      expect(receipt.replayed, isFalse);
      expect(receipt.upstreamStatus, 202);
      expect(receipt.correlationId, startsWith('req-'));
      expect(receipt.hostRequestId, isNotNull);
      expect(receipt.raw['idempotency_key'], key);
      // Same key: the stored receipt comes back, flagged.
      final again = await gateway.message('bl-wn9', 'hello', requestId: key);
      expect(again.replayed, isTrue);
      expect(again.correlationId, receipt.correlationId);
      expect(again.hostRequestId, receipt.hostRequestId);
    });

    test('rejected, 502 and 409 answers map to receipts', () async {
      final fx = needFront();
      if (fx == null) return;
      final gateway = gatewayFor(fx, 'normal', front: true);
      addTearDown(gateway.close);
      final rejected = await gateway.controlAgent(
        'nope',
        AgentControlAction.stop,
        requestId: 'k-rej-${Random().nextInt(1 << 30)}',
      );
      expect(rejected.status, MutationReceiptStatus.rejected);
      expect(rejected.message, contains('nope'));
      expect(rejected.upstreamStatus, 404);
      final down = await gateway.message(
        'upstream-down',
        'hello',
        requestId: 'k-down-${Random().nextInt(1 << 30)}',
      );
      expect(down.status, MutationReceiptStatus.pending);
      expect(down.retryable, isTrue);
      expect(down.message, contains('did not answer'));
      final mismatch = await gateway.controlAgent(
        'bl-wn9',
        AgentControlAction.stop,
        requestId: 'mismatch-${Random().nextInt(1 << 30)}',
      );
      expect(mismatch.status, MutationReceiptStatus.rejected);
      expect(mismatch.retryable, isFalse);
      expect(mismatch.message, contains('another identity'));
    });

    test('every verb reaches its route', () async {
      final fx = needFront();
      if (fx == null) return;
      final gateway = gatewayFor(fx, 'blocked', front: true);
      addTearDown(gateway.close);
      // Drive the blocked scenario to its pending interaction.
      await _drive(gateway, from: _firstSeq - 1, untilSeq: _branchSeq + 1);
      final gates = await gateway.gates();
      final gate = gates.firstWhere((g) => g.kind == GateKind.choice);
      final rid = Random().nextInt(1 << 30);
      final answered = await gateway.respond(
        gate.id,
        const GateResponse.choice('keep'),
        requestId: 'k-resp-$rid',
      );
      expect(answered.status, MutationReceiptStatus.accepted);
      expect(answered.upstreamStatus, 202);
      final unknownGate = await gateway.respond(
        'req-nope',
        const GateResponse.choice('keep'),
        requestId: 'k-resp2-$rid',
      );
      expect(unknownGate.status, MutationReceiptStatus.rejected);

      final stop = await gateway.controlAgent(
        'bl-wn9',
        AgentControlAction.stop,
        requestId: 'k-stop-$rid',
      );
      expect(stop.upstreamStatus, 200);
      final restart = await gateway.controlAgent(
        'bl-wn9',
        AgentControlAction.restart,
        requestId: 'k-restart-$rid',
      );
      expect(restart.status, MutationReceiptStatus.accepted);
      expect(restart.raw.keys, containsAll(['stop', 'wake']));
      final pause = await gateway.controlAgent(
        'gastown.mayor',
        AgentControlAction.pause,
        requestId: 'k-pause-$rid',
      );
      expect(pause.status, MutationReceiptStatus.accepted);
      final nudge = await gateway.controlAgent(
        'bl-wn9',
        AgentControlAction.nudge,
        requestId: 'k-nudge-$rid',
      );
      expect(nudge.correlationId, startsWith('req-'));
      final batch = await gateway.cancelRun('oc-xru', requestId: 'k-conv-$rid');
      expect(batch.status, MutationReceiptStatus.accepted);
      expect(batch.upstreamStatus, 200);
      final formula = await gateway.cancelRun(
        'oc-loy',
        requestId: 'k-run-$rid',
      );
      expect(formula.status, MutationReceiptStatus.accepted);
      expect(formula.upstreamStatus, 202);
      final slung = await gateway.assign(
        'oc-loy',
        agentId: 'ocproof/gastown.polecat',
        requestId: 'k-sling-$rid',
      );
      expect(slung.status, MutationReceiptStatus.accepted);
      expect(slung.raw['body'], isA<Map<String, Object?>>());
    });

    /// A controller over a front gateway against [fx] with real probe and
    /// stream; [timeout] is the receipt window.
    Future<OrchestrationController> bootController(
      _Fixture fx, {
      required String scenario,
      required Duration timeout,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final config = OrchestrationConfig(
        provider: OrchestrationProvider.gascity,
        url: fx.baseUrl,
        city: _city,
        front: true,
        enabledAt: DateTime.utc(2026, 9, 10),
      );
      final controller = OrchestrationController(
        profile: ServerProfile(
          id: 'srv-front',
          name: 'Workstation',
          baseUrl: 'https://server.example:4096',
          orchestration: config,
        ),
        config: config,
        store: OrchestrationStore(prefs),
        gatewayFactory: (_, found) => GasCityGateway(
          url: found.host.url,
          city: _city,
          front: found.front && found.identityAllowed,
          defaultQuery: {'scenario': scenario},
          backoffBase: const Duration(milliseconds: 50),
          backoffCap: const Duration(milliseconds: 300),
        ),
        refreshDebounce: const Duration(milliseconds: 50),
        mutationTimeout: timeout,
      );
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.phase, OrchestrationPhase.ready);
      expect(controller.capabilities.controlMessage, isTrue);
      return controller;
    }

    Future<void> waitFor(
      OrchestrationController controller,
      String key,
      MutationStatus status, {
      Duration limit = const Duration(seconds: 15),
    }) async {
      final deadline = DateTime.now().add(limit);
      while (controller.mutation(key)?.status != status) {
        if (DateTime.now().isAfter(deadline)) {
          fail(
            'mutation $key is ${controller.mutation(key)?.status}, '
            'wanted $status',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    test('receipt lifecycle: message → accepted → request.result → '
        'confirmed', () async {
      final fx = needFront();
      if (fx == null) return;
      final controller = await bootController(
        fx,
        scenario: 'normal',
        timeout: const Duration(seconds: 30),
      );
      final record = await controller.messageAgent('bl-wn9', 'hello');
      // The fixture answers the result at once, so the stream may beat
      // the HTTP answer: sent or already confirmed, never anything else.
      expect(
        record.status,
        anyOf(MutationStatus.sent, MutationStatus.confirmed),
      );
      expect(record.correlationId, startsWith('req-'));
      await waitFor(controller, record.key, MutationStatus.confirmed);
      expect(controller.mutation(record.key)?.receipt?.isAccepted, isTrue);
      final gone = await controller.messageAgent('bl-wn9', 'fail: busy');
      await waitFor(controller, gone.key, MutationStatus.rejected);
      expect(controller.mutation(gone.key)?.receipt?.message, 'busy');
    });

    test('stream drop: unconfirmed after the window, confirmed once the '
        'stream resumes and the result arrives', () async {
      if (needFront() == null) return;
      final fx = await _Fixture.start(front: true, resultDelay: 2.5);
      addTearDown(fx.stop);
      final controller = await bootController(
        fx,
        scenario: 'stream-drop',
        timeout: const Duration(milliseconds: 700),
      );
      final record = await controller.messageAgent('bl-wn9', 'hello');
      expect(record.status, MutationStatus.sent);
      await waitFor(controller, record.key, MutationStatus.unconfirmed);
      expect(controller.mutation(record.key)?.canRetry, isTrue);
      // The result event lands after the drop and the reconnect.
      await waitFor(controller, record.key, MutationStatus.confirmed);
    });
  });
}
