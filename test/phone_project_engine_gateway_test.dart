import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/phone_project_engine.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/domain/team_project_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/inapp/phone_engine_gateway.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

class FakeEngineAdapter implements HttpClientAdapter {
  FakeEngineAdapter(this.answer);
  final Future<ResponseBody> Function(RequestOptions) answer;
  final requests = <RequestOptions>[];
  bool closed = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return answer(options);
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}

ResponseBody jsonBody(Object? value, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(value),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
Map<String, Object?> health(
  String profile, {
  bool execution = false,
  List<String> actions = const [],
}) => {
  'schemaVersion': 1,
  'engineVersion': 'test-v1',
  'profileId': profile,
  'capabilities': <String, Object?>{
    'execution': execution,
    'boundary': execution,
    'oc1Verified': execution,
    'oc2': false,
  },
  'commandActions': actions,
};
Map<String, Object?> workspace([int revision = 1]) => {
  'schemaVersion': 1,
  'revision': revision,
  'simulated': false,
  'projects': [],
  'servers': [],
  'roles': [],
};
PhoneEngineGateway gateway(
  FakeEngineAdapter adapter, {
  Duration poll = const Duration(hours: 1),
}) => PhoneEngineGateway(
  baseUrl: 'http://127.0.0.1:4098',
  profileId: 'p1',
  bearerToken: 'local-engine-secret',
  adapter: adapter,
  pollInterval: poll,
);
Matcher safeError(String code) =>
    isA<PhoneEngineException>().having((e) => e.code, 'code', code);
void main() {
  tearDown(KitRedact.clearKnownSecrets);
  test('signed proot and landlock tiers preserve executable health flags', () {
    for (final tier in ['proot', 'landlock']) {
      final wire = health('p1', execution: true)..['boundaryTier'] = tier;
      (wire['capabilities'] as Map)['boundaryTier'] = tier;
      final parsed = PhoneEngineHealth.fromJson(wire, 'p1');
      expect(parsed.boundaryTier, tier);
      expect(parsed.boundary, isTrue);
      expect(parsed.execution, isTrue);
      expect(parsed.canExecute, isTrue);
    }
  });

  test('unverified none tier keeps execution unavailable', () {
    final wire = health('p1')..['boundaryTier'] = 'none';
    (wire['capabilities'] as Map)['boundaryTier'] = 'none';
    final parsed = PhoneEngineHealth.fromJson(wire, 'p1');
    expect(parsed.boundaryTier, 'none');
    expect(parsed.canExecute, isFalse);
  });

  test('legacy health keeps its flags when the optional tier is absent', () {
    final parsed = PhoneEngineHealth.fromJson(
      health('p1', execution: true),
      'p1',
    );
    expect(parsed.boundaryTier, 'none');
    expect(parsed.canExecute, isTrue);
    expect(PhoneEngineHealth.fromJson(health('p1'), 'p1').canExecute, isFalse);
  });

  test('one reported tier is enough during an additive gateway transition', () {
    for (final topLevel in [true, false]) {
      final wire = health('p1', execution: true);
      if (topLevel) {
        wire['boundaryTier'] = 'proot';
      } else {
        (wire['capabilities'] as Map)['boundaryTier'] = 'proot';
      }
      expect(PhoneEngineHealth.fromJson(wire, 'p1').boundaryTier, 'proot');
    }
  });

  test('health refuses unknown malformed and conflicting boundary tiers', () {
    for (final bad in ['unsupported', '', null, 1, false]) {
      for (final topLevel in [true, false]) {
        final wire = health('p1', execution: true);
        if (topLevel) {
          wire['boundaryTier'] = bad;
        } else {
          (wire['capabilities'] as Map)['boundaryTier'] = bad;
        }
        expect(
          () => PhoneEngineHealth.fromJson(wire, 'p1'),
          throwsA(safeError('payloadInvalid')),
        );
      }
    }
    final conflicting = health('p1', execution: true)
      ..['boundaryTier'] = 'landlock';
    (conflicting['capabilities'] as Map)['boundaryTier'] = 'proot';
    expect(
      () => PhoneEngineHealth.fromJson(conflicting, 'p1'),
      throwsA(safeError('payloadInvalid')),
    );
  });

  test(
    'expired activity cursor remains an explicit reset requirement',
    () async {
      final adapter = FakeEngineAdapter(
        (request) async => jsonBody({
          'code': 'cursorExpired',
          'resetRequired': true,
          'eventWindow': {'prunedThroughSeq': 50, 'earliestAvailableSeq': 51},
        }, 409),
      );
      final client = gateway(adapter);
      await expectLater(
        client.activity(afterSeq: 1),
        throwsA(safeError('cursorExpired')),
      );
      await client.close();
    },
  );

  test(
    'refuses remote hosts, userinfo and credential newlines before network',
    () {
      for (final endpoint in [
        'http://100.64.0.1:4098',
        'http://localhost:4098',
        'https://example.org',
        'http://user:pass@127.0.0.1:4098',
        'http://127.0.0.1:4098?token=secret',
      ]) {
        expect(
          () => PhoneEngineGateway(
            baseUrl: endpoint,
            profileId: 'p1',
            bearerToken: 'secret',
          ),
          throwsA(safeError('endpointInvalid')),
        );
      }
    },
  );
  test(
    'every endpoint authenticated with redirect following disabled',
    () async {
      final adapter = FakeEngineAdapter(
        (r) async => jsonBody(
          r.path == '/v1/health'
              ? health('p1')
              : r.path == '/v1/events'
              ? []
              : r.method == 'DELETE'
              ? {'deleted': true}
              : workspace(),
        ),
      );
      final client = gateway(adapter);
      await client.probe();
      await client.teamWorkspace();
      await client.activity();
      await client.deleteLocalData();
      expect(adapter.requests.map((r) => r.method), [
        'GET',
        'GET',
        'GET',
        'GET',
        'DELETE',
      ]);
      for (final r in adapter.requests) {
        expect(r.headers['Authorization'], 'Bearer local-engine-secret');
        expect(r.followRedirects, isFalse);
      }
      expect(adapter.closed, isTrue);
    },
  );
  test(
    'health rejects different profile and unknown schema without raw details',
    () async {
      final adapter = FakeEngineAdapter(
        (_) async => jsonBody(health('another')),
      );
      final client = gateway(adapter);
      await expectLater(client.probe(), throwsA(safeError('profileMismatch')));
      await client.close();
      expect(
        () => PhoneEngineHealth.fromJson({
          ...health('p1'),
          'schemaVersion': 2,
        }, 'p1'),
        throwsA(safeError('schemaUnsupported')),
      );
    },
  );
  test(
    'unproven health permits workspace but rejects execution and unsupported commands',
    () async {
      final adapter = FakeEngineAdapter(
        (r) async => jsonBody(
          r.path == '/v1/health'
              ? health('p1', actions: ['promote'])
              : workspace(),
        ),
      );
      final client = gateway(adapter);
      await client.probe();
      expect(client.capabilities.projectLifecycle, isFalse);
      expect(client.capabilities.projectPromotion, isFalse);
      expect((await client.teamWorkspace()).simulated, isFalse);
      expect(
        (await client.executeProject(
          const TeamProjectCommand(
            requestId: 'r1',
            action: TeamProjectAction.promote,
          ),
        )).code,
        'boundaryUnverified',
      );
      expect(
        (await client.executeProject(
          const TeamProjectCommand(
            requestId: 'r2',
            action: TeamProjectAction.advance,
          ),
        )).code,
        'unsupportedCommand',
      );
      expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);
      await client.close();
    },
  );
  test(
    'redacts commands before transmission and never retries ambiguous mutation',
    () async {
      KitRedact.registerKnownSecret('private-provider-secret');
      final adapter = FakeEngineAdapter((r) async {
        if (r.path == '/v1/health') {
          return jsonBody(health('p1', actions: ['createProject']));
        }
        throw DioException(
          requestOptions: r,
          message: 'local-engine-secret private-provider-secret',
        );
      });
      final client = gateway(adapter);
      final result = await client.executeProject(
        const TeamProjectCommand(
          requestId: 'r1',
          action: TeamProjectAction.createProject,
          text: 'private-provider-secret',
          name: 'Project',
        ),
      );
      expect(result.code, 'transportUncertain');
      final posts = adapter.requests.where((r) => r.method == 'POST').toList();
      expect(posts, hasLength(1));
      expect(
        jsonEncode(posts.single.data),
        isNot(contains('private-provider-secret')),
      );
      await client.close();
    },
  );
  test(
    'redirect response never exposes response body or follows location',
    () async {
      final adapter = FakeEngineAdapter(
        (_) async => jsonBody({'token': 'secret'}, 302),
      );
      final client = gateway(adapter);
      await expectLater(client.probe(), throwsA(safeError('redirectRefused')));
      expect(adapter.requests, hasLength(1));
      await client.close();
    },
  );
  test(
    'deletion drains already-sent commands and permanently closes client',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final order = <String>[];
      final adapter = FakeEngineAdapter((r) async {
        if (r.path == '/v1/health') {
          return jsonBody(health('p1', actions: ['createProject']));
        }
        if (r.method == 'POST') {
          entered.complete();
          await release.future;
          order.add('command');
          return jsonBody({
            'accepted': true,
            'code': '',
            'projectId': 'p',
            'revision': 1,
            'replayed': false,
          });
        }
        order.add('delete');
        return jsonBody({'deleted': true});
      });
      final client = gateway(adapter);
      final write = client.executeProject(
        const TeamProjectCommand(
          requestId: 'r1',
          action: TeamProjectAction.createProject,
        ),
      );
      await entered.future;
      final deletion = client.deleteLocalData();
      await expectLater(
        client.teamWorkspace(),
        throwsA(safeError('engineClosed')),
      );
      expect(order, isEmpty);
      release.complete();
      await write;
      await deletion;
      expect(order, ['command', 'delete']);
      expect(client.isClosed, isTrue);
    },
  );
  test(
    'poll error reports stale read while preserving last snapshot',
    () async {
      var fail = false;
      final adapter = FakeEngineAdapter((r) async {
        if (r.path == '/v1/health') return jsonBody(health('p1'));
        if (fail) return jsonBody({}, 503);
        {
          return jsonBody(workspace());
        }
      });
      final client = gateway(adapter, poll: const Duration(milliseconds: 10));
      final first = Completer<TeamWorkspace>();
      final error = Completer<void>();
      final subscription = client.watchTeamWorkspace().listen(
        (s) {
          if (!first.isCompleted) first.complete(s);
          fail = true;
        },
        onError: (Object e) {
          if (!error.isCompleted) error.complete();
        },
      );
      expect((await first.future).revision, 1);
      await error.future;
      await subscription.cancel();
      await client.close();
    },
  );
  test(
    'chat heartbeat carries authentication and bounded observation-only body',
    () async {
      final now = DateTime.now();
      final adapter = FakeEngineAdapter(
        (_) async => jsonBody({'accepted': true}),
      );
      final client = PhoneEngineGateway(
        baseUrl: 'http://127.0.0.1:4098',
        profileId: 'p1',
        bearerToken: 'local-engine-secret',
        adapter: adapter,
        now: () => now,
      );
      await client.sendChatBusy(
        until: now.millisecondsSinceEpoch + 30000,
        sessionIds: ['person-1'],
        directories: ['/root/projects/chat'],
        known: true,
        appInstance: 'app-1',
        sequence: 3,
      );
      final request = adapter.requests.single;
      expect(request.path, '/v1/chatBusy');
      expect(request.headers['Authorization'], 'Bearer local-engine-secret');
      expect(request.followRedirects, isFalse);
      expect(request.data, {
        'until': now.millisecondsSinceEpoch + 30000,
        'sessionIds': ['person-1'],
        'directories': ['/root/projects/chat'],
        'known': true,
        'appInstance': 'app-1',
        'sequence': 3,
      });
      await expectLater(
        client.sendChatBusy(
          until: now.millisecondsSinceEpoch + 30001,
          sessionIds: [],
          directories: [],
          known: true,
          appInstance: 'app-1',
          sequence: 4,
        ),
        throwsA(safeError('payloadInvalid')),
      );
      expect(adapter.requests, hasLength(1));
      await client.close();
    },
  );
  test(
    'actual OC1 prompt, correlated prompt, shell and slash run the dispatch fence',
    () async {
      final order = <String>[];
      final api = OpenCodeApi(baseUrl: 'http://127.0.0.1:4097');
      api.dio.httpClientAdapter = FakeEngineAdapter((r) async {
        order.add('wire:${r.path}');
        return r.path.endsWith('/command')
            ? jsonBody({}, 503)
            : jsonBody(null, 204);
      });
      api.beforeSessionDispatch = (id) async {
        order.add('fence:$id');
      };
      api.sessionDispatchSettled = (id) {
        order.add('settled:$id');
      };
      await api.promptAsync('s1', text: 'person prompt');
      await api.promptWithMessageID(
        's1',
        messageID: api.createPromptMessageID(),
        text: 'correlated',
      );
      await api.shell('s1', command: 'pwd', agent: 'build');
      await expectLater(
        api.slashCommand('s1', 'help', ''),
        throwsA(isA<ApiException>()),
      );
      expect(order.where((v) => v.startsWith('fence:')), hasLength(4));
      expect(order.where((v) => v.startsWith('settled:')), hasLength(4));
      for (var i = 0; i < order.length; i += 3) {
        expect(order[i], 'fence:s1');
        expect(order[i + 1], startsWith('wire:'));
        expect(order[i + 2], 'settled:s1');
      }
      api.close();
    },
  );
  test(
    'a fence failure occurs before any OpenCode request or settlement callback',
    () async {
      final adapter = FakeEngineAdapter((_) async => jsonBody(null, 204));
      final api = OpenCodeApi(baseUrl: 'http://127.0.0.1:4097');
      api.dio.httpClientAdapter = adapter;
      var settled = false;
      api.beforeSessionDispatch = (_) async {
        throw const PhoneEngineException('engineStopFailed');
      };
      api.sessionDispatchSettled = (_) {
        settled = true;
      };
      await expectLater(
        api.promptAsync('s1', text: 'not dispatched'),
        throwsA(safeError('engineStopFailed')),
      );
      expect(adapter.requests, isEmpty);
      expect(settled, isFalse);
      api.close();
    },
  );
  test(
    'malformed OC1 status cannot become a synthetic idle admission',
    () async {
      final api = OpenCodeApi(baseUrl: 'http://127.0.0.1:4097');
      api.dio.httpClientAdapter = FakeEngineAdapter(
        (_) async => jsonBody({'person': {}}),
      );
      final statuses = await api.sessionStatuses();
      expect(statuses['person'], 'unknown');
      api.close();
    },
  );
  test(
    'heartbeat HTTP success without affirmative accepted body is not an ACK',
    () async {
      final now = DateTime.utc(2026, 9, 30);
      for (final response in [
        <String, dynamic>{},
        {'accepted': false},
        {'accepted': 'true'},
      ]) {
        final client = PhoneEngineGateway(
          baseUrl: 'http://127.0.0.1:4098',
          profileId: 'phone',
          bearerToken: 'fake-private-token',
          now: () => now,
          adapter: FakeEngineAdapter((_) async => jsonBody(response)),
        );
        await expectLater(
          client.sendChatBusy(
            until: now.millisecondsSinceEpoch + 30000,
            sessionIds: ['person'],
            directories: ['/chat'],
            known: true,
            appInstance: 'app-1',
            sequence: 1,
          ),
          throwsA(safeError('chatAdmissionUnavailable')),
        );
        await client.close();
      }
    },
  );
}
