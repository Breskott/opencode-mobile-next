import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api2/gateway_mappers.dart'
    show api2ServerCapabilities;
import 'package:opencode_mobile/api2/gateway_operations.dart';
import 'package:opencode_mobile/api2/client.dart';
import 'package:opencode_mobile/api2/dialect.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';

class _Real extends HttpOverrides {}

class _Req {
  final String method;
  final Uri uri;
  final dynamic body;
  _Req(this.method, this.uri, this.body);
}

Future<void> _withServer(
  Future<void> Function(Api2OperationsGateway gateway, List<_Req> requests)
  body,
  Future<void> Function(HttpRequest request) handler,
) async {
  await HttpOverrides.runZoned(() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <_Req>[];
    server.listen((request) async {
      final text = await utf8.decoder.bind(request).join();
      requests.add(
        _Req(
          request.method,
          request.uri,
          text.isEmpty ? null : jsonDecode(text),
        ),
      );
      await handler(request);
    });
    final client = Api2Client.connect(
      baseUrl: 'http://${server.address.host}:${server.port}',
      password: 'pw',
      directory: '/root/projects/demo',
    );
    client.transport.settleDialect(Api2Dialect.stable);
    try {
      await body(Api2OperationsGateway(client: client), requests);
    } finally {
      client.close();
      await server.close(force: true);
    }
  }, createHttpClient: (_) => _Real().createHttpClient(null));
}

Future<void> _json(HttpRequest r, Object? payload, {int status = 200}) async {
  r.response.statusCode = status;
  r.response.headers.contentType = ContentType.json;
  if (payload != null) r.response.write(jsonEncode(payload));
  await r.response.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the three 2.0.29 features are advertised', () {
    expect(api2ServerCapabilities.gitInit, isTrue);
    expect(api2ServerCapabilities.worktreeCreate, isTrue);
    expect(api2ServerCapabilities.shellSettings, isTrue);
  });

  group('gitInit', () {
    test('posts /vcs/init for git in the active location', () async {
      await _withServer(
        (gateway, requests) async {
          await gateway.initializeGitRepository();
          expect(requests.single.method, 'POST');
          expect(requests.single.uri.path, '/api/vcs/init');
          expect(requests.single.uri.queryParameters['provider'], 'git');
          expect(
            requests.single.uri.queryParameters['location[directory]'],
            '/root/projects/demo',
          );
        },
        (r) async {
          r.response.statusCode = 204;
          await r.response.close();
        },
      );
    });

    test('an already-initialized folder (409) counts as done', () async {
      await _withServer((gateway, requests) async {
        await gateway.initializeGitRepository();
      }, (r) => _json(r, {'error': 'exists'}, status: 409));
    });

    test('other failures surface', () async {
      await _withServer((gateway, requests) async {
        await expectLater(
          gateway.initializeGitRepository(),
          throwsA(isA<ProductException>()),
        );
      }, (r) => _json(r, {'error': 'nope'}, status: 501));
    });
  });

  group('worktreeCreate', () {
    test(
      'posts {projectID, name} to /worktree and reads {directory}',
      () async {
        await _withServer(
          (gateway, requests) async {
            final created = await gateway.createWorktree(
              projectDirectory: '/root/projects/demo',
              name: 'probe-a',
            );
            expect(created.directory, '/data/worktree/abc123/probe-a');
            expect(created.name, 'probe-a');
            final post = requests.singleWhere((r) => r.method == 'POST');
            expect(post.uri.path, '/api/worktree');
            expect(post.body, {'projectID': 'prj_1', 'name': 'probe-a'});
          },
          (r) async {
            if (r.method == 'GET' && r.uri.path == '/api/location') {
              return _json(r, {
                'project': {'id': 'prj_1'},
              });
            }
            await _json(r, {'directory': '/data/worktree/abc123/probe-a'});
          },
        );
      },
    );
  });

  group('shellSettings', () {
    final shells = [
      {'path': '/bin/bash', 'name': 'bash', 'acceptable': true},
      {'path': '/usr/sbin/nologin', 'name': 'nologin', 'acceptable': false},
    ];

    Future<void> handler(HttpRequest r) async {
      if (r.method == 'GET' && r.uri.path == '/api/config/shell') {
        return _json(r, shells);
      }
      if (r.method == 'GET' && r.uri.path == '/api/config') {
        return _json(r, {
          'data': [
            {
              'type': 'global',
              'info': {'shell': '/bin/sh'},
            },
            {
              'type': 'project',
              'info': {'shell': '/bin/bash'},
            },
            {'type': 'project', 'info': <String, dynamic>{}},
          ],
        });
      }
      r.response.statusCode = 204;
      await r.response.close();
    }

    test('lists shells and reads the highest-priority choice', () async {
      await _withServer((gateway, requests) async {
        final settings = await gateway.loadTerminalShellSettings();
        expect(settings.selected, '/bin/bash');
        expect(settings.options.map((o) => o.path), [
          '/bin/bash',
          '/usr/sbin/nologin',
        ]);
        expect(settings.options.last.acceptable, isFalse);
      }, handler);
    });

    test('patches only an acceptable shell', () async {
      await _withServer((gateway, requests) async {
        await gateway.selectTerminalShell('/bin/bash');
        final patch = requests.singleWhere((r) => r.method == 'PATCH');
        expect(patch.uri.path, '/api/experimental/config');
        expect(patch.body, {'shell': '/bin/bash'});
      }, handler);
    });

    test('refuses unlisted or unusable shells without writing', () async {
      await _withServer((gateway, requests) async {
        for (final bad in ['/usr/sbin/nologin', '/nope/zsh']) {
          await expectLater(
            gateway.selectTerminalShell(bad),
            throwsA(isA<ProductException>()),
          );
        }
        expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
      }, handler);
    });

    test('an empty choice clears the shell with null', () async {
      await _withServer((gateway, requests) async {
        await gateway.selectTerminalShell('');
        expect(requests.singleWhere((r) => r.method == 'PATCH').body, {
          'shell': null,
        });
      }, handler);
    });
  });
}
