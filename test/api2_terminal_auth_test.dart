import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api2/client.dart';
import 'package:opencode_mobile/api2/dialect.dart';
import 'package:opencode_mobile/api2/gateway_operations.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';

class _RealHttp extends HttpOverrides {}

Future<void> _checkTerminalAuth({
  String? username,
  bool revokeAfterTicket = false,
}) async {
  await HttpOverrides.runZoned(() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final expected =
        'Basic ${base64Encode(utf8.encode('${username ?? 'opencode'}:fixture-token'))}';
    final requests = <({Uri uri, String? auth, String? ticketHeader})>[];
    final sockets = <WebSocket>[];
    server.listen((request) async {
      final auth = request.headers.value(HttpHeaders.authorizationHeader);
      requests.add((
        uri: request.uri,
        auth: auth,
        ticketHeader: request.headers.value('x-opencode-ticket'),
      ));
      if (auth != expected || (revokeAfterTicket && request.method == 'GET')) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
      } else if (request.method == 'POST' &&
          request.uri.path == '/api/pty/pty_fixture/connect-token') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': {'ticket': 'one-use-fixture-ticket'},
          }),
        );
        await request.response.close();
      } else if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((message) => socket.add(message));
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });
    final client = Api2Client.connect(
      baseUrl: 'http://${server.address.host}:${server.port}',
      password: 'fixture-token',
      username: username ?? 'opencode',
      directory: '/work/project',
    );
    client.transport.settleDialect(Api2Dialect.stable);
    final gateway = Api2OperationsGateway(client: client);
    TerminalChannel? channel;
    try {
      if (revokeAfterTicket) {
        await expectLater(
          gateway.connectTerminal('pty_fixture'),
          throwsA(isA<ProductException>()),
        );
        expect(sockets, isEmpty);
      } else {
        channel = await gateway.connectTerminal('pty_fixture', cursor: 12);
        final output = channel.output.first;
        channel.write('fixture-output');
        expect(await output, 'fixture-output');
      }
      expect(requests, hasLength(2));
      expect(requests.map((request) => request.auth), everyElement(expected));
      expect(requests.first.ticketHeader, '1');
      final connect = requests.last.uri;
      expect(connect.path, '/api/pty/pty_fixture/connect');
      expect(connect.queryParameters['ticket'], 'one-use-fixture-ticket');
      expect(connect.queryParameters['location[directory]'], '/work/project');
      expect(connect.queryParameters.containsKey('auth_token'), isFalse);
      expect(connect.toString(), isNot(contains('fixture-token')));
      if (!revokeAfterTicket) expect(connect.queryParameters['cursor'], '12');
    } finally {
      await channel?.close();
      for (final socket in sockets) {
        await socket.close();
      }
      client.close();
      await server.close(force: true);
    }
  }, createHttpClient: (_) => _RealHttp().createHttpClient(null));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'OC2 terminal keeps its default Basic header and single-use ticket',
    () async {
      await _checkTerminalAuth();
    },
  );

  test(
    'BYO terminal forwards the per-phone Basic header through the proxy',
    () async {
      await _checkTerminalAuth(username: 'phone-fixture');
    },
  );

  test(
    'BYO revocation after ticket issuance still rejects the websocket',
    () async {
      await _checkTerminalAuth(
        username: 'phone-fixture',
        revokeAfterTicket: true,
      );
    },
  );
}
