import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/sv3_tool_configuration.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/sv3_tool_configuration.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:opencode_sdk/opencode_sdk.dart' as sdk;

TypeMatcher<ToolConfigurationException> _error(ToolConfigurationError code) =>
    isA<ToolConfigurationException>().having((e) => e.code, 'code', code);

void main() {
  late Dio dio;
  late sdk.OpencodeSdk client;
  late List<RequestOptions> requests;
  var failRequest = false;

  setUp(() {
    KitRedact.clearKnownSecrets();
    requests = [];
    failRequest = false;
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
    client = sdk.OpencodeSdk(dio: dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (failRequest) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'password=fixture-only-credential',
              ),
            );
          } else {
            handler.resolve(
              Response<Object>(
                requestOptions: options,
                statusCode: 200,
                data: <String, Object?>{},
              ),
            );
          }
        },
      ),
    );
  });

  tearDown(() {
    dio.close(force: true);
    KitRedact.clearKnownSecrets();
  });

  V1ToolConfigurationGateway gateway({
    ServerCapabilities capabilities = const ServerCapabilities(),
    String? directory = '/project',
  }) => V1ToolConfigurationGateway(
    client: client,
    capabilities: capabilities,
    directory: directory,
    workspace: 'workspace-1',
  );

  test('tool off and on patch only one entry in the selected scope', () async {
    final adapter = gateway();
    await adapter.setCodingToolEnabled(
      'read',
      false,
      scope: CodingToolConfigScope.project,
    );
    await adapter.setCodingToolEnabled(
      'read',
      true,
      scope: CodingToolConfigScope.global,
    );

    expect(requests, hasLength(2));
    expect(requests.first.method, 'PATCH');
    expect(requests.first.path, '/config');
    expect(requests.first.queryParameters, {
      'directory': '/project',
      'workspace': 'workspace-1',
    });
    expect(jsonDecode(requests.first.data as String), {
      'tools': {'read': false},
    });
    expect(requests.last.path, '/global/config');
    expect(requests.last.queryParameters, isEmpty);
    expect(jsonDecode(requests.last.data as String), {
      'tools': {'read': true},
    });
  });

  test('MCP off changes only enablement and never needs credentials', () async {
    await gateway().setMcpServerEnabled(
      'docs-server',
      false,
      scope: CodingToolConfigScope.project,
    );
    expect(requests, hasLength(1));
    expect(requests.single.path, '/config');
    expect(jsonDecode(requests.single.data as String), {
      'mcp': {
        'docs-server': {'enabled': false},
      },
    });
  });

  test('capabilities and invalid targets reject without a request', () async {
    const enabled = ServerCapabilities();
    const disabled = ServerCapabilities(mcpConfigWrites: false);
    final adapter = gateway();
    expect(enabled.canConfigureCodingTools(), isFalse);
    expect(enabled.canConfigureCodingTools(gateway: adapter), isTrue);
    expect(disabled.canConfigureCodingTools(gateway: adapter), isFalse);
    expect(
      const ServerCapabilities(
        toolInventory: false,
      ).canConfigureCodingTools(gateway: adapter),
      isFalse,
    );
    expect(enabled.canConfigureMcpEnablement(), isFalse);
    expect(enabled.canConfigureMcpEnablement(gateway: adapter), isTrue);
    expect(
      const ServerCapabilities(
        serverCatalog: false,
      ).canConfigureMcpEnablement(gateway: adapter),
      isFalse,
    );
    expect(enabled.codingToolSourceMcp, isFalse);
    expect(enabled.codingToolEnabledState, isFalse);
    await expectLater(
      gateway(capabilities: disabled).setCodingToolEnabled(
        'read',
        false,
        scope: CodingToolConfigScope.global,
      ),
      throwsA(_error(ToolConfigurationError.unavailable)),
    );
    await expectLater(
      gateway(capabilities: disabled).setMcpServerEnabled(
        'docs-server',
        false,
        scope: CodingToolConfigScope.global,
      ),
      throwsA(_error(ToolConfigurationError.unavailable)),
    );
    await expectLater(
      gateway(directory: null).setCodingToolEnabled(
        'read',
        false,
        scope: CodingToolConfigScope.project,
      ),
      throwsA(_error(ToolConfigurationError.projectRequired)),
    );
    KitRedact.registerKnownSecret('fixture-credential');
    for (final id in ['', ' read ', 'read\nwrite', 'fixture-credential']) {
      await expectLater(
        adapter.setCodingToolEnabled(
          id,
          false,
          scope: CodingToolConfigScope.global,
        ),
        throwsA(_error(ToolConfigurationError.invalidToolID)),
      );
    }
    await expectLater(
      adapter.setMcpServerEnabled(
        'fixture-credential',
        false,
        scope: CodingToolConfigScope.global,
      ),
      throwsA(_error(ToolConfigurationError.invalidMcpServer)),
    );
    expect(requests, isEmpty);
  });

  test('transport failures expose only a fixed safe error', () async {
    failRequest = true;
    await expectLater(
      gateway().setCodingToolEnabled(
        'read',
        false,
        scope: CodingToolConfigScope.project,
      ),
      throwsA(
        _error(ToolConfigurationError.requestFailed).having(
          (e) => e.toString(),
          'safe message',
          'Could not update configuration',
        ),
      ),
    );
  });
}
