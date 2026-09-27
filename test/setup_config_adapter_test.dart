import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/setup_config_adapter.dart';
import 'package:opencode_mobile/api2/client.dart';
import 'package:opencode_mobile/api2/dialect.dart';
import 'package:opencode_mobile/api2/setup_config_adapter.dart';
import 'package:opencode_mobile/domain/setup_assistant.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object payload = <String, Object?>{};
  int status = 200;
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'token=synthetic-secret',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final v2 in [false, true]) {
    group(v2 ? 'OpenCode 2 setup' : 'OpenCode 1 setup', () {
      late _Adapter http;
      late SetupConfigGateway gateway;
      late void Function() close;

      setUp(() {
        http = _Adapter();
        if (v2) {
          final client = Api2Client.connect(
            baseUrl: 'http://localhost:4097',
            password: 'fake-profile-password',
            directory: '/projects/app',
            workspace: 'workspace-one',
          );
          client.transport.settleDialect(Api2Dialect.beta);
          client.transport.dio.httpClientAdapter = http;
          gateway = OpenCode2SetupConfigGateway(client: client);
          close = client.close;
        } else {
          final api =
              OpenCodeApi(
                baseUrl: 'http://localhost:4096',
                password: 'fake-profile-password',
              )..setLocation(
                directory: '/projects/app',
                workspace: 'workspace-one',
              );
          api.dio.httpClientAdapter = http;
          gateway = OpenCode1SetupConfigGateway(api: api);
          close = api.close;
        }
      });

      tearDown(() => close());

      test('reads config in selected location using existing auth', () async {
        http.payload = v2
            ? [
                {
                  'type': 'document',
                  'path': '/global/opencode.json',
                  'info': {'model': 'example/global'},
                },
                {
                  'type': 'document',
                  'path': '/projects/app/opencode.json',
                  'info': {'model': 'example/project'},
                },
              ]
            : {'model': 'example/project'};
        final config = await gateway.readConfig();
        if (v2) {
          final sources = config['sources']! as List;
          expect(sources.length, 2);
          expect((sources.first as Map)['path'], '/global/opencode.json');
          expect(config.containsKey('model'), isFalse);
        } else {
          expect(config['model'], 'example/project');
        }
        final request = http.requests.single;
        expect(request.path, '/config');
        expect(request.method, 'GET');
        expect(
          request.queryParameters[v2 ? 'location[directory]' : 'directory'],
          '/projects/app',
        );
        expect(
          request.queryParameters[v2 ? 'location[workspace]' : 'workspace'],
          'workspace-one',
        );
        expect(request.headers.containsKey('Authorization'), isTrue);
        expect(request.uri.query.contains('auth'), isFalse);
      });

      test('write refusal performs no transport request', () async {
        expect(gateway.support.readConfig, isTrue);
        expect(gateway.support.mcpInventory, isTrue);
        expect(gateway.support.writeConfig, isFalse);
        expect(gateway.support.assistant, isFalse);
        await expectLater(
          gateway.patchConfig({'model': 'example/changed'}),
          throwsA(
            isA<SetupFailure>().having(
              (error) => error.code,
              'code',
              SetupFailureCode.unsupported,
            ),
          ),
        );
        expect(http.requests, isEmpty);
      });

      test('inventory preserves statuses without raw server errors', () async {
        http.payload = v2
            ? {
                'data': [
                  {
                    'name': 'docs',
                    'status': {'status': 'needs_auth'},
                  },
                  {
                    'name': 'failed-server',
                    'status': {
                      'status': 'failed',
                      'error': 'token=fake-secret',
                    },
                  },
                  {
                    'name': 'future',
                    'status': {'status': 'token=fake-secret'},
                  },
                ],
              }
            : {
                'docs': {'status': 'needs_auth'},
                'failed-server': {
                  'status': 'failed',
                  'error': 'token=fake-secret',
                },
                'future': {'status': 'token=fake-secret'},
              };
        final servers = await gateway.listMcpServers();
        expect(servers.map((server) => server.name), [
          'docs',
          'failed-server',
          'future',
        ]);
        expect(servers.map((server) => server.status), [
          'needs_auth',
          'failed',
          'unknown',
        ]);
        expect(http.requests.single.path, '/mcp');
      });

      for (final status in [401, 403, 500]) {
        test('HTTP $status failure never exposes response details', () async {
          http.status = status;
          http.payload = {
            'message': 'apiKey=synthetic-secret',
            '_tag': 'Error',
          };
          await expectLater(
            gateway.readConfig(),
            throwsA(
              isA<SetupFailure>()
                  .having(
                    (error) => error.code,
                    'code',
                    status == 500
                        ? SetupFailureCode.transport
                        : SetupFailureCode.needsSignIn,
                  )
                  .having(
                    (error) => error.message.contains('synthetic-secret'),
                    'exposes server detail',
                    isFalse,
                  ),
            ),
          );
        });
      }

      test('network failure maps to offline with safe copy', () async {
        http.offline = true;
        await expectLater(
          gateway.readConfig(),
          throwsA(
            isA<SetupFailure>()
                .having((error) => error.code, 'code', SetupFailureCode.offline)
                .having(
                  (error) => error.message.contains('synthetic-secret'),
                  'exposes transport detail',
                  isFalse,
                ),
          ),
        );
      });

      test('malformed config cannot masquerade as empty config', () async {
        http.payload = 'invalid response';
        await expectLater(
          gateway.readConfig(),
          throwsA(
            isA<SetupFailure>().having(
              (error) => error.code,
              'code',
              SetupFailureCode.invalid,
            ),
          ),
        );
      });

      test('malformed inventory cannot masquerade as no servers', () async {
        http.payload = 'invalid response';
        await expectLater(
          gateway.listMcpServers(),
          throwsA(
            isA<SetupFailure>().having(
              (error) => error.code,
              'code',
              SetupFailureCode.invalid,
            ),
          ),
        );
      });
    });
  }
}
