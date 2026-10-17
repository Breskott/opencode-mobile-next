import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api2/gateway.dart';
import 'package:opencode_mobile/api2/dialect.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';

import 'api2_interaction_gateway_test.dart' as wire;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sends = <String, Future<void> Function(Api2Gateway)>{
    'prompt': (api) => api.promptAsync('s', text: 'write a file'),
    'queued prompt': (api) => api.promptAsync(
      's',
      text: 'write a file',
      delivery: PromptDelivery.queue,
    ),
    'command': (api) => api.slashCommand('s', 'review', ''),
    'shell': (api) => api.shell('s', command: 'pwd', agent: 'build'),
  };

  for (final send in sends.entries) {
    for (final failure in [
      null,
      'get',
      'agent',
      'patch',
      'readback',
      'agent changed',
    ]) {
      test(
        '${send.key}: permission preparation ${failure ?? 'completes before send'}',
        () async {
          final session = <String, dynamic>{
            'id': 's',
            'agent': 'build',
            'permissions': <Object?>[],
            'metadata': {'keep': true},
          };
          late List<wire.Recorded> recorded;
          var reads = 0;
          await wire.withServer(
            handler: (request) async {
              if (request.method == 'GET' &&
                  request.uri.path == '/api/agent/build') {
                await wire.writeJson(request, {
                  'data': {
                    'id': 'build',
                    'permissions': [
                      {'action': '*', 'resource': '*', 'effect': 'allow'},
                    ],
                  },
                }, status: failure == 'agent' ? 503 : 200);
              } else if (request.method == 'GET') {
                reads++;
                await wire.writeJson(request, {
                  'data': {
                    ...session,
                    if (failure == 'agent changed' && reads > 1)
                      'agent': 'plan',
                  },
                }, status: failure == 'get' ? 503 : 200);
              } else if (request.method == 'PATCH') {
                if (failure != 'readback') {
                  session.addAll(
                    Map<String, dynamic>.from(recorded.last.body as Map),
                  );
                }
                await wire.writeJson(
                  request,
                  null,
                  status: failure == 'patch' ? 503 : 204,
                );
              } else if (request.uri.path.endsWith('/prompt')) {
                await wire.writeJson(request, {
                  'data': {
                    'id': 'msg_one',
                    'sessionID': 's',
                    'type': 'user',
                    'payload': {'text': 'write a file'},
                  },
                });
              } else {
                await wire.writeNoContent(request);
              }
            },
            (server, requests) async {
              recorded = requests;
              final api = wire.gatewayFor(server);
              addTearDown(api.close);
              if (failure != null) {
                await expectLater(
                  send.value(api),
                  throwsA(isA<ApiException>()),
                );
                expect(requests.where((r) => r.method == 'POST'), isEmpty);
              } else {
                await send.value(api);
                expect(requests.map((r) => r.method), [
                  'GET',
                  'GET',
                  'PATCH',
                  'GET',
                  'POST',
                ]);
                expect((session['metadata'] as Map)['keep'], true);
                expect(session['permissions'], [
                  {'action': '*', 'resource': '*', 'effect': 'ask'},
                  {'action': '*', 'resource': '*', 'effect': 'ask'},
                ]);
              }
            },
          );
        },
      );
    }
  }

  test('stable Auto-approve and Allow once send decision once', () async {
    await wire.withServer(handler: wire.writeNoContent, (
      server,
      requests,
    ) async {
      final api = wire.gatewayFor(server);
      addTearDown(api.close);
      api.transport.settleDialect(Api2Dialect.stable);
      await api.respondPermissionV2('s', 'per_shell', 'once');
      expect(requests.single.body, {'decision': 'once'});
    });
  });
}
