import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/phone_project_engine.dart';
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
  'capabilities': {
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
}
