// Closing a terminal whose shell already ended: the owner's phone showed
// "DELETE /pty/… failed (HTTP 404): PTY session not found" as a red error
// (2026-09-24). A 404 on close means it is already gone: done, not an error.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api2/gateway_operations.dart';

import 'api2_interaction_gateway_test.dart'
    show withServer, gatewayFor, writeJson;

void main() {
  test('OpenCode 2: closing a terminal that is already gone succeeds', () {
    return withServer(
      handler: (request) => writeJson(request, {
        'name': 'NotFoundError',
        'data': {'message': 'PTY session not found: pty_gone'},
      }, status: 404),
      (server, requests) async {
        final gateway = gatewayFor(server);
        final operations = Api2OperationsGateway(client: gateway.client);
        try {
          await operations.removeTerminal('pty_gone');
          expect(requests.single.method, 'DELETE');
          expect(requests.single.uri.path, '/api/pty/pty_gone');
        } finally {
          gateway.close();
        }
      },
    );
  });

  test('OpenCode 2: any other failure to close still says so', () {
    return withServer(
      handler: (request) => writeJson(request, {
        'name': 'UnknownError',
        'data': {'message': 'boom'},
      }, status: 500),
      (server, requests) async {
        final gateway = gatewayFor(server);
        final operations = Api2OperationsGateway(client: gateway.client);
        try {
          await expectLater(
            operations.removeTerminal('pty_live'),
            throwsA(anything),
          );
        } finally {
          gateway.close();
        }
      },
    );
  });
}
