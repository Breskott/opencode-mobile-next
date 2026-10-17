import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api2/gateway.dart';
import 'package:opencode_mobile/state/phone_project_engine.dart';

import 'api2_interaction_gateway_test.dart' as wire;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sends = <String, Future<void> Function(Api2Gateway)>{
    'prompt': (api) => api.promptAsync('ses_person', text: 'Help'),
    'shell': (api) => api.shell('ses_person', command: 'pwd', agent: 'build'),
    'command': (api) => api.slashCommand('ses_person', 'help', ''),
  };
  for (final send in sends.entries) {
    test('${send.key} waits for admission before any request', () async {
      await wire.withServer(
        readyPermissions: true,
        handler: wire.writeNoContent,
        (server, requests) async {
          final api = wire.gatewayFor(server);
          final admission = Completer<void>();
          var settled = 0;
          api.beforeSessionDispatch = (_) => admission.future;
          api.sessionDispatchSettled = (_) => settled++;
          try {
            final result = send.value(api);
            final rejected = expectLater(result, throwsA(isA<ApiException>()));
            await Future<void>.delayed(Duration.zero);
            expect(requests, isEmpty);
            admission.completeError(ApiException('Admission unavailable'));
            await rejected;
            expect(requests, isEmpty);
            expect(settled, 0);
          } finally {
            api.close();
          }
        },
      );
    });

    test('${send.key} settles accepted dispatch exactly once', () async {
      await wire.withServer(
        readyPermissions: true,
        handler: (request) async {
          if (request.method == 'GET') {
            await wire.writeJson(request, {
              'data': wire.readyPermissionSession('ses_person'),
            });
          } else if (request.uri.path.endsWith('/prompt')) {
            await wire.writeJson(request, {
              'data': {
                'id': 'msg_accepted',
                'sessionID': 'ses_person',
                'type': 'user',
                'payload': {'text': 'Help'},
              },
            });
          } else {
            await wire.writeNoContent(request);
          }
        },
        (server, requests) async {
          final api = wire.gatewayFor(server);
          final callbacks = <String>[];
          api.beforeSessionDispatch = (id) async {
            callbacks.add('before:$id');
          };
          api.sessionDispatchSettled = (id) => callbacks.add('settled:$id');
          try {
            await send.value(api);
            expect(callbacks, ['before:ses_person', 'settled:ses_person']);
            expect(requests.where((r) => r.method == 'POST'), hasLength(1));
          } finally {
            api.close();
          }
        },
      );
    });

    test(
      '${send.key} settles uncertainty without replaying dispatch',
      () async {
        await wire.withServer(
          readyPermissions: true,
          handler: (request) async {
            if (request.method == 'GET') {
              await wire.writeJson(request, {
                'data': wire.readyPermissionSession('ses_person'),
              });
            } else {
              await wire.writeJson(request, {
                'message': 'uncertain',
              }, status: 500);
            }
          },
          (server, requests) async {
            final api = wire.gatewayFor(server);
            final tracker = PhoneChatDispatchTracker();
            api.beforeSessionDispatch = (id) async =>
                tracker.begin(id, '/work');
            api.sessionDispatchSettled = (id) => tracker.settled(id);
            try {
              await expectLater(send.value(api), throwsA(isA<ApiException>()));
              expect(requests.where((r) => r.method == 'POST'), hasLength(1));
              tracker.reconcile({}, tracker.epoch, '/work');
              expect(tracker.sessionIds, contains('ses_person'));
              tracker.reconcile({'ses_person': 'busy'}, tracker.epoch, '/work');
              tracker.reconcile({}, tracker.epoch, '/work');
              expect(tracker.sessionIds, isEmpty);
            } finally {
              api.close();
            }
          },
        );
      },
    );
  }
}
