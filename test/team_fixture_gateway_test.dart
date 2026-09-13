// TEAM-104: the in-process fixture gateway (test double) over the
// recordings in tool/qa/gascity_fixture.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_mappers.dart';

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

void main() {
  late FixtureOrchestrationGateway gateway;

  setUp(() {
    gateway = FixtureOrchestrationGateway(fixturePath: _findFixtureRoot().path);
  });

  tearDown(() => gateway.close());

  test('rejects a path that is not a directory', () {
    expect(
      () => FixtureOrchestrationGateway(fixturePath: '/nonexistent/fixture'),
      throwsArgumentError,
    );
  });

  test('capabilities and host identity', () {
    expect(gateway.capabilities, same(OrchestrationCapabilities.fixture));
    expect(gateway.host, isNotNull);
    expect(gateway.host!.provider, 'fixture');
    expect(gateway.host!.version, '1.4.1');
    expect(gateway.host!.city, 'bright-lights');
    expect(gateway.isClosed, isFalse);
    expect(gateway.logLength, 418);
  });

  test('reads answer from the recordings', () async {
    expect((await gateway.projects()).map((p) => p.id), ['ocproof']);

    final runs = await gateway.runs();
    expect(runs.map((r) => r.id), contains('oc-xru'));
    expect(await gateway.run('oc-xru'), isNotNull);
    expect(await gateway.run('missing'), isNull);

    final work = await gateway.work();
    expect(work.map((w) => w.id), containsAll(['oc-loy', 'gc-19']));
    expect(work.where((w) => w.issueType == 'session'), isEmpty);
    expect((await gateway.readyWork()).map((w) => w.id), ['gc-19']);
    expect(
      (await gateway.work(projectId: 'ocproof')).map((w) => w.id),
      contains('oc-loy'),
    );

    final agents = await gateway.agents();
    expect(agents.map((a) => a.name), contains('gastown.mayor'));
    expect(await gateway.agent('gastown.mayor'), isNotNull);
    expect(await gateway.agent('bl-wisp-qqpj'), isNotNull);

    expect(await gateway.gates(), isEmpty);
    final usage = await gateway.usage();
    expect(usage, isNotNull);
    expect(usage!.isEstimated, isTrue);
  });

  test('the run bead follows the replay head', () async {
    final before = await gateway.workItem('oc-loy');
    expect(before, isNotNull);
    expect(before!.state, WorkState.queued);
    expect(before.branch, isNull);

    gateway.emit(gateway.logLength);
    expect(gateway.head, gateway.logLength);
    final after = await gateway.workItem('oc-loy');
    expect(after!.branch, 'polecat/oc-loy');
    expect(after.sessionId, 'bl-48k');

    gateway.rewind();
    expect(gateway.head, 0);
    expect((await gateway.workItem('oc-loy'))!.branch, isNull);
  });

  test('emit replays the recorded run to listeners', () async {
    final received = <OrchestrationEvent>[];
    final sub = gateway.events().listen(received.add);
    final emitted = gateway.emit(10);
    expect(emitted, hasLength(10));
    expect(emitted.first.seq, 1026);
    expect(emitted.last.seq, 1035);
    final beat = gateway.emitHeartbeat();
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(11));
    expect(received.last, same(beat));
    expect(received.whereType<UnknownOrchestrationEvent>(), isEmpty);
    await sub.cancel();

    // Past the end nothing more comes.
    gateway.emit(1000);
    expect(gateway.head, gateway.logLength);
    expect(gateway.emit(1), isEmpty);
  });

  test('activity grows with the head and stays oldest first', () async {
    final history = await gateway.activity(limit: 1000);
    expect(history.first.seq, 934);
    expect(history.last.seq, 1025);
    gateway.emit(3);
    final grown = await gateway.activity(limit: 1000);
    expect(grown.last.seq, 1028);
    final after = await gateway.activity(afterSeq: 1026);
    expect(after.map((e) => e.seq), [1027, 1028]);
    final limited = await gateway.activity(limit: 2);
    expect(limited.map((e) => e.seq), [1027, 1028]);
  });

  test('events with a cursor replay what was missed, then go live', () async {
    gateway.emit(5); // 1026..1030 emitted before anyone listened
    final received = <OrchestrationEvent>[];
    final sub = gateway
        .events(resumeFrom: const EventCursor(seq: 1028))
        .listen(received.add);
    await Future<void>.delayed(Duration.zero);
    expect(received.map((e) => e.seq), [1029, 1030]);
    gateway.emit(1);
    await Future<void>.delayed(Duration.zero);
    expect(received.map((e) => e.seq), [1029, 1030, 1031]);
    await sub.cancel();
  });

  test('controls are accepted and recorded', () async {
    final receipt = await gateway.respond(
      'gate-1',
      const GateResponse.choice('keep'),
      requestId: 'req-1',
    );
    expect(receipt.isAccepted, isTrue);
    expect(receipt.id, 'req-1');
    await gateway.message('gastown.mayor', 'hello', requestId: 'req-2');
    await gateway.controlAgent(
      'gastown.dog-1',
      AgentControlAction.start,
      requestId: 'req-3',
    );
    await gateway.cancelRun('oc-xru', requestId: 'req-4');
    await gateway.assign('gc-19', agentId: 'polecat', requestId: 'req-5');
    expect(gateway.controlCalls.map((c) => c.verb), [
      'respond',
      'message',
      'controlAgent',
      'cancelRun',
      'assign',
    ]);
    expect(gateway.controlCalls.first.arg, isA<GateResponse>());
    expect(gateway.controlCalls.last.arg, 'polecat');
  });

  test('close ends the stream and further events are dropped', () async {
    var done = false;
    final sub = gateway.events().listen((_) {}, onDone: () => done = true);
    await gateway.close();
    await Future<void>.delayed(Duration.zero);
    expect(gateway.isClosed, isTrue);
    expect(done, isTrue);
    expect(gateway.emit(1), hasLength(1)); // returned, not delivered
    expect(gateway.events(), emitsDone);
    await sub.cancel();
  });
}
