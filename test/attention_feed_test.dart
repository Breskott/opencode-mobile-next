import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/profile_monitor.dart';
import 'package:opencode_mobile/domain/work_row_status.dart';
import 'package:opencode_mobile/state/attention_feed.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

void main() {
  final now = DateTime.utc(2026, 9, 28, 12);

  AttentionObservation observation(
    String id,
    AttentionKind kind, {
    String? sessionID = 'conversation',
    String? requestID,
    String? taskID,
    String? directory,
    String? workspace,
    String? title,
    DateTime? observedAt,
    bool isFresh = true,
  }) => AttentionObservation(
    id: id,
    kind: kind,
    facts: WorkRowFacts(
      phase: kind == AttentionKind.failedRun
          ? WorkRowPhase.failed
          : WorkRowPhase.needsYou,
    ),
    observedAt: observedAt ?? now,
    sessionID: sessionID,
    requestID: requestID,
    taskID: taskID,
    directory: directory,
    workspace: workspace,
    title: title,
    isFresh: isFresh,
  );

  AttentionServer server(
    String id, {
    List<AttentionObservation> attention = const [],
    List<MonitoredRequest> requests = const [],
    ProfileMonitorStatus status = ProfileMonitorStatus.current,
    bool complete = true,
    bool attentionComplete = true,
    DateTime? checkedAt,
    String? directory,
    String? workspace,
    String? name,
  }) => AttentionServer(
    profileID: id,
    name: name ?? 'Server $id',
    snapshot: ProfileAttentionSnapshot(
      profileID: id,
      status: status,
      checkedAt: checkedAt ?? now,
      nextCheckAt: now.add(const Duration(minutes: 1)),
      directory: directory,
      workspace: workspace,
      requests: requests,
      attention: attention,
      complete: complete,
      attentionComplete: attentionComplete,
    ),
  );

  setUp(KitRedact.clearKnownSecrets);
  tearDown(KitRedact.clearKnownSecrets);

  test(
    'all servers share urgency order with stable ties and server routing',
    () {
      final first = server(
        'first',
        attention: [
          observation('failure', AttentionKind.failedRun),
          observation(
            'permission',
            AttentionKind.permission,
            observedAt: now.subtract(const Duration(minutes: 1)),
          ),
        ],
      );
      final second = server(
        'second',
        attention: [
          observation('gate', AttentionKind.teamGate, taskID: 'task'),
          observation('form', AttentionKind.form),
        ],
      );
      final feed = AttentionFeed.fromServers([second, first], now: now);
      final reversed = AttentionFeed.fromServers([first, second], now: now);
      expect(feed.items.first.target.requestID, 'permission');
      expect(feed.items.last.kind, AttentionKind.failedRun);
      expect(
        feed.items.map((item) => item.identity),
        reversed.items.map((item) => item.identity),
      );
      expect(feed.items.first.profileID, 'first');
      expect(feed.items.first.serverName, 'Server first');
      expect(feed.items.first.target.profileID, 'first');
      expect(feed.items.first.status.facts.phase, WorkRowPhase.needsYou);
      expect(feed.isComplete, isTrue);
      expect(feed.attentionCount, 4);
    },
  );

  test('pending requests join supplemental rows, check-ins never count', () {
    final feed = AttentionFeed.fromServers([
      server(
        'a',
        directory: '/work',
        workspace: 'workspace',
        requests: [
          for (final kind in MonitoredRequestKind.values)
            MonitoredRequest(
              id: kind.name,
              sessionID: 'conversation',
              kind: kind,
            ),
        ],
        attention: [
          observation('failure', AttentionKind.failedRun),
          observation('gate', AttentionKind.teamGate, taskID: 'task'),
        ],
      ),
    ], now: now);
    expect(feed.knownAttentionCount, 5);
    expect(feed.freshAttentionCount, 5);
    expect(
      feed.items.map((item) => item.kind).toSet(),
      AttentionKind.values.toSet(),
    );
    final question = feed.items.firstWhere(
      (item) => item.kind == AttentionKind.question,
    );
    expect(question.target.sessionID, 'conversation');
    expect(question.target.requestID, 'question');
    expect(question.target.directory, '/work');
    expect(question.target.workspace, 'workspace');
    expect(question.target.hasConversation, isTrue);
    expect(feed.items.last.target.requestID, isNull);
  });

  test('dedupe uses server, location, kind and request identity', () {
    const request = MonitoredRequest(
      id: 'request',
      sessionID: 'conversation',
      kind: MonitoredRequestKind.permission,
    );
    final feed = AttentionFeed.fromServers([
      server(
        'a',
        directory: '/one',
        requests: [request, request],
        attention: [
          observation(
            'different-observation-id',
            AttentionKind.permission,
            requestID: 'request',
            title: 'Latest title',
          ),
          observation('request', AttentionKind.permission, directory: '/two'),
          observation('request', AttentionKind.question),
        ],
      ),
      server('b', requests: [request]),
    ], now: now);
    expect(feed.items, hasLength(4));
    expect(feed.items.map((item) => item.identity).toSet(), hasLength(4));
    final deduped = feed.items.singleWhere(
      (item) =>
          item.profileID == 'a' &&
          item.kind == AttentionKind.permission &&
          item.target.directory == '/one',
    );
    expect(deduped.title, 'Latest title');
    expect(deduped.target.requestID, 'request');
    final left = observation('c', AttentionKind.form, sessionID: 'a:b');
    final right = observation('b:c', AttentionKind.form, sessionID: 'a');
    expect(left.identity, isNot(right.identity));
  });

  test('failed and partial polls cannot claim current empty coverage', () {
    for (final status in ProfileMonitorStatus.values) {
      if (status == ProfileMonitorStatus.current) continue;
      final feed = AttentionFeed.fromServers([
        server('a', status: status),
      ], now: now);
      expect(feed.isComplete, isFalse, reason: status.name);
      expect(feed.attentionCount, isNull, reason: status.name);
      expect(feed.servers.single.isFresh, isFalse, reason: status.name);
    }
    final partial = AttentionFeed.fromServers([
      server('a', attentionComplete: false),
    ], now: now);
    expect(partial.items, isEmpty);
    expect(partial.servers.single.state, AttentionCheckState.partial);
    expect(partial.knownAttentionCount, 0);
    expect(partial.attentionCount, isNull);
    final noRequests = AttentionFeed.fromServers([
      server('a', complete: false),
    ], now: now);
    expect(noRequests.servers.single.state, AttentionCheckState.partial);
    expect(noRequests.attentionCount, isNull);
  });

  test('old, disconnected and unrefreshed observations stay static', () {
    final old = now.subtract(const Duration(minutes: 7));
    final feed = AttentionFeed.fromServers([
      server(
        'old',
        checkedAt: old,
        attention: [
          observation('old', AttentionKind.failedRun, observedAt: old),
        ],
      ),
      server(
        'offline',
        status: ProfileMonitorStatus.unavailable,
        attention: [observation('offline', AttentionKind.teamGate)],
      ),
      server(
        'partial',
        attentionComplete: false,
        attention: [
          observation('fresh', AttentionKind.question),
          observation('retained', AttentionKind.form).copyWith(isFresh: false),
        ],
      ),
    ], now: now);
    expect(feed.knownAttentionCount, 4);
    expect(feed.freshAttentionCount, 1);
    expect(feed.attentionCount, isNull);
    expect(feed.items.every((item) => !item.status.showLiveMark), isTrue);
    expect(
      feed.items
          .singleWhere((item) => item.target.requestID == 'fresh')
          .status
          .isFresh,
      isTrue,
    );
    expect(
      feed.servers.singleWhere((check) => check.profileID == 'old').state,
      AttentionCheckState.stale,
    );
  });

  test('new server poll does not freshen an old or future row', () {
    final feed = AttentionFeed.fromServers([
      server(
        'a',
        attention: [
          observation(
            'old',
            AttentionKind.question,
            observedAt: now.subtract(const Duration(minutes: 7)),
          ),
          observation(
            'future',
            AttentionKind.permission,
            observedAt: now.add(const Duration(minutes: 1)),
          ),
        ],
      ),
    ], now: now);
    expect(feed.freshAttentionCount, 0);
    expect(feed.isComplete, isFalse);
    expect(feed.attentionCount, isNull);
  });

  test(
    'saved server list owns membership and mismatched snapshots fail closed',
    () {
      final removed = server(
        'removed',
        attention: [observation('old', AttentionKind.permission)],
      );
      final remaining = server('remaining');
      expect(
        AttentionFeed.fromServers([removed, remaining], now: now).items,
        hasLength(1),
      );
      final feed = AttentionFeed.fromServers([remaining], now: now);
      expect(feed.items, isEmpty);
      expect(feed.servers.map((check) => check.profileID), ['remaining']);
      final mismatch = AttentionFeed.fromServers([
        AttentionServer(
          profileID: 'remaining',
          name: 'Remaining',
          snapshot: removed.snapshot,
        ),
      ], now: now);
      expect(mismatch.items, isEmpty);
      expect(mismatch.servers.single.state, AttentionCheckState.unavailable);
      expect(mismatch.isComplete, isFalse);
    },
  );

  test('titles redact secrets without changing opaque deep-link targets', () {
    const secret = 'opaque-fixture-secret';
    KitRedact.registerKnownSecret(secret);
    final feed = AttentionFeed.fromServers([
      server(
        'a',
        name: 'Server $secret',
        attention: [
          observation(
            'gate',
            AttentionKind.teamGate,
            sessionID: null,
            taskID: secret,
            requestID: secret,
            title: 'Task $secret',
          ),
        ],
      ),
    ], now: now);
    final item = feed.items.single;
    expect(item.serverName, 'Server ${KitRedact.mask}');
    expect(item.title, 'Task ${KitRedact.mask}');
    expect(item.target.hasConversation, isFalse);
    expect(item.target.sessionID, isNull);
    expect(item.target.taskID, secret);
    expect(item.target.requestID, secret);
    expect(feed.servers.single.serverName, item.serverName);
  });
}
