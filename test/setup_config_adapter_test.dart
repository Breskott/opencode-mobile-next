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
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

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
  for (final dialect in [null, Api2Dialect.beta, Api2Dialect.stable]) {
    final v2 = dialect != null;
    group(v2 ? 'OpenCode 2 ${dialect.name} setup' : 'OpenCode 1 setup', () {
      late _Adapter http;
      late SetupConfigGateway gateway;
      late void Function() close;
      late void Function() changeLocation;

      setUp(() {
        http = _Adapter();
        if (v2) {
          final client = Api2Client.connect(
            baseUrl: 'http://localhost:4097',
            password: 'fake-profile-password',
            directory: '/projects/app',
            workspace: 'workspace-one',
          );
          client.transport.settleDialect(dialect);
          client.transport.dio.httpClientAdapter = http;
          gateway = OpenCode2SetupConfigGateway(client: client);
          close = client.close;
          changeLocation = () => client.setLocation(
            directory: '/projects/other',
            workspace: 'workspace-other',
          );
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
          changeLocation = () => api.setLocation(
            directory: '/projects/other',
            workspace: 'workspace-other',
          );
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
        for (final patch in <Map<String, Object?>>[
          {'model': 'example/changed'},
          {'shell': '/bin/sh'},
          {
            'mcp': {
              'docs': {
                'type': 'remote',
                'url': 'https://example.com/mcp',
                'enabled': false,
              },
            },
          },
          {
            'mcp': {'docs': null},
          },
        ]) {
          await expectLater(
            gateway.patchConfig(patch),
            throwsA(
              isA<SetupFailure>().having(
                (error) => error.code,
                'code',
                SetupFailureCode.unsupported,
              ),
            ),
          );
        }
        expect(http.requests, isEmpty);
      });

      test(
        'inspection keeps its captured location after client switches',
        () async {
          changeLocation();
          http.payload = v2 ? <Object>[] : <String, Object?>{};
          await gateway.readConfig();
          http.payload = v2 ? {'data': <Object>[]} : <String, Object?>{};
          await gateway.listMcpServers();
          for (final request in http.requests) {
            expect(request.method, 'GET');
            expect(
              request.queryParameters[v2 ? 'location[directory]' : 'directory'],
              '/projects/app',
            );
            expect(
              request.queryParameters[v2 ? 'location[workspace]' : 'workspace'],
              'workspace-one',
            );
          }
        },
      );

      test(
        'loaded provider credentials are registered before returning config',
        () async {
          final secret = 'fixture-setup-${dialect?.name ?? 'v1'}-ingress-value';
          final info = {
            'providers': {
              'example': {
                'options': {'apiKey': secret},
              },
            },
          };
          http.payload = v2
              ? [
                  {'type': 'document', 'info': info},
                ]
              : info;
          await gateway.readConfig();
          expect(KitRedact.text(secret).contains(secret), isFalse);
        },
      );

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
