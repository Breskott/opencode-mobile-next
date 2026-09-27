import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/terminal_command_gateway.dart';
import 'package:opencode_mobile/api2/client.dart';
import 'package:opencode_mobile/api2/terminal_command_gateway.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/terminal_lifecycle.dart';
import 'package:opencode_sdk/opencode_sdk.dart' as sdk;

class _RealHttpOverrides extends HttpOverrides {}

const _ended = TerminalProcess(
  id: 'pty_old',
  title: 'Build',
  command: '/bin/tool',
  arguments: ['--label', 'two words', r'$(literal)'],
  directory: '/project/child',
  running: false,
  pid: 17,
  exitCode: 0,
);

const _response = {
  'id': 'pty_new',
  'title': 'Build',
  'command': '/bin/tool',
  'args': ['--label', 'two words', r'$(literal)'],
  'cwd': '/project/child',
  'status': 'running',
  'pid': 18,
};

Future<void> _withServer(
  Future<void> Function(HttpRequest request) handler,
  Future<void> Function(String baseUrl) test,
) async {
  await HttpOverrides.runZoned(() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(handler);
    try {
      await test('http://${server.address.host}:${server.port}');
    } finally {
      await server.close(force: true);
    }
  }, createHttpClient: (_) => _RealHttpOverrides().createHttpClient(null));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final v2 in [false, true]) {
    test(
      '${v2 ? 'v2' : 'v1'} reruns reported command in a new scoped PTY',
      () async {
        final requests = <({String method, Uri uri, dynamic body})>[];
        await _withServer(
          (request) async {
            requests.add((
              method: request.method,
              uri: request.uri,
              body: jsonDecode(await utf8.decoder.bind(request).join()),
            ));
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(v2 ? {'data': _response} : _response),
            );
            await request.response.close();
          },
          (baseUrl) async {
            final sdkClient = sdk.OpencodeSdk(basePathOverride: baseUrl);
            final client = Api2Client.connect(
              baseUrl: baseUrl,
              password: 'fake-test-password',
              directory: '/project',
              workspace: 'workspace-test',
            );
            try {
              final TerminalCommandGateway gateway = v2
                  ? Api2TerminalCommandGateway(client)
                  : SdkTerminalCommandGateway(
                      sdkClient,
                      directory: '/project',
                      workspace: 'workspace-test',
                    );
              final result = await gateway.rerunTerminalCommand(_ended);
              expect(result.id, 'pty_new');
              expect(result.running, isTrue);
              expect(result.arguments, _ended.arguments);
              expect(requests, hasLength(1));
              final request = requests.single;
              expect(request.method, 'POST');
              expect(request.uri.path, v2 ? '/api/pty' : '/pty');
              expect(request.uri.queryParameters, {
                if (v2)
                  'location[directory]': '/project'
                else
                  'directory': '/project',
                if (v2)
                  'location[workspace]': 'workspace-test'
                else
                  'workspace': 'workspace-test',
              });
              expect(request.body, {
                'command': _ended.command,
                'args': _ended.arguments,
                'cwd': _ended.directory,
                'title': _ended.title,
              });
              expect(
                const ServerCapabilities().supportsTerminalCommandRerun(
                  gateway,
                ),
                isTrue,
              );
              expect(
                const ServerCapabilities(
                  terminal: false,
                ).supportsTerminalCommandRerun(gateway),
                isFalse,
              );
            } finally {
              sdkClient.dio.close(force: true);
              client.close();
            }
          },
        );
      },
    );

    test(
      '${v2 ? 'v2' : 'v1'} failed response is sanitized and never retried',
      () async {
        var requests = 0;
        await _withServer(
          (request) async {
            requests++;
            await request.drain<void>();
            request.response.statusCode = 500;
            request.response.write('fake-sensitive-server-detail');
            await request.response.close();
          },
          (baseUrl) async {
            final sdkClient = sdk.OpencodeSdk(basePathOverride: baseUrl);
            final client = Api2Client.connect(
              baseUrl: baseUrl,
              password: 'fake-test-password',
              directory: '/project',
            );
            try {
              final TerminalCommandGateway gateway = v2
                  ? Api2TerminalCommandGateway(client)
                  : SdkTerminalCommandGateway(sdkClient, directory: '/project');
              await expectLater(
                gateway.rerunTerminalCommand(_ended),
                throwsA(
                  isA<ProductException>().having(
                    (error) => error.message,
                    'safe failure',
                    'Could not confirm the rerun. Refresh terminals before trying again.',
                  ),
                ),
              );
              expect(requests, 1);
            } finally {
              sdkClient.dio.close(force: true);
              client.close();
            }
          },
        );
      },
    );
  }

  test('missing facet and missing wire timing stay unavailable', () {
    const capabilities = ServerCapabilities();
    expect(capabilities.supportsTerminalCommandRerun(null), isFalse);
    expect(capabilities.terminalAge, isFalse);
    expect(capabilities.externalCommandTimeLeft, isFalse);
    expect(
      () => terminalRerunSnapshot(
        const TerminalProcess(
          id: 'pty_active',
          title: '',
          command: '/bin/sh',
          arguments: [],
          directory: '/project',
          running: true,
          pid: 7,
        ),
      ),
      throwsA(isA<ProductException>()),
    );
    expect(
      () => terminalRerunSnapshot(
        const TerminalProcess(
          id: 'pty_missing',
          title: '',
          command: '',
          arguments: [],
          directory: '/project',
          running: false,
          pid: 7,
        ),
      ),
      throwsA(isA<ProductException>()),
    );
  });

  test(
    'v2 rejects stale project location without dispatching a request',
    () async {
      var requests = 0;
      await _withServer(
        (request) async {
          requests++;
          await request.response.close();
        },
        (baseUrl) async {
          final client = Api2Client.connect(
            baseUrl: baseUrl,
            password: 'fake-test-password',
            directory: '/project',
          );
          final gateway = Api2TerminalCommandGateway(client);
          client.setLocation(directory: '/different');
          try {
            await expectLater(
              gateway.rerunTerminalCommand(_ended),
              throwsA(isA<ProductException>()),
            );
            expect(requests, 0);
          } finally {
            client.close();
          }
        },
      );
    },
  );
}
