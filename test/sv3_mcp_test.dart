import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/sv3_mcp_capabilities.dart';

class _McpGateway implements McpGateway {
  final disconnected = <String>[];
  bool fail = false;

  @override
  Future<void> disconnectMcp(String name) async {
    disconnected.add(name);
    if (fail) throw StateError('untrusted server response');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('runtime disconnect sends the exact name only when supported', () async {
    final gateway = _McpGateway();
    const available = ServerCapabilities(serverCatalog: true);
    const unavailable = ServerCapabilities(serverCatalog: false);

    expect(available.mcpRuntimeDisconnect, isTrue);
    expect(unavailable.mcpRuntimeDisconnect, isFalse);
    await gateway.disconnectMcpRuntime('docs/server', capabilities: available);
    expect(gateway.disconnected, ['docs/server']);
    await expectLater(
      gateway.disconnectMcpRuntime('docs/server', capabilities: unavailable),
      throwsA(
        isA<Sv3McpRuntimeException>().having(
          (error) => error.reason,
          'reason',
          Sv3McpRuntimeFailure.unavailable,
        ),
      ),
    );
    expect(gateway.disconnected, ['docs/server']);
  });

  test(
    'runtime disconnect rejects unsafe names and returns safe errors',
    () async {
      final gateway = _McpGateway();
      const capabilities = ServerCapabilities(serverCatalog: true);
      for (final name in ['', ' docs ', 'docs\nserver', 'token=fake-value']) {
        await expectLater(
          gateway.disconnectMcpRuntime(name, capabilities: capabilities),
          throwsA(
            isA<Sv3McpRuntimeException>().having(
              (error) => error.reason,
              'reason',
              Sv3McpRuntimeFailure.invalidName,
            ),
          ),
        );
      }
      expect(gateway.disconnected, isEmpty);

      gateway.fail = true;
      await expectLater(
        gateway.disconnectMcpRuntime('docs', capabilities: capabilities),
        throwsA(
          isA<Sv3McpRuntimeException>()
              .having(
                (error) => error.reason,
                'reason',
                Sv3McpRuntimeFailure.requestFailed,
              )
              .having(
                (error) => error.toString(),
                'safe description',
                isNot(contains('untrusted server response')),
              ),
        ),
      );
    },
  );

  test('MCP setup capabilities do not enable unsupported recovery actions', () {
    const capabilities = ServerCapabilities(
      mcpConfigWrites: true,
      mcpRuntimeAdds: true,
      mcpRuntimeRemovals: true,
      mcpOAuth: true,
      integrationCredentials: true,
    );

    expect(capabilities.mcpConfigDeletion, isFalse);
    expect(capabilities.mcpRuntimeRemovalUndo, isFalse);
    expect(capabilities.mcpOAuthTokenExpiry, isFalse);
    expect(capabilities.mcpExpiryAutoReconnect, isFalse);
  });

  test('unavailable MCP setup keeps all stronger actions unavailable', () {
    const capabilities = ServerCapabilities(
      mcpConfigWrites: false,
      mcpRuntimeAdds: false,
      mcpRuntimeRemovals: false,
      mcpOAuth: false,
      integrationCredentials: false,
    );

    expect(capabilities.mcpConfigDeletion, isFalse);
    expect(capabilities.mcpRuntimeRemovalUndo, isFalse);
    expect(capabilities.mcpOAuthTokenExpiry, isFalse);
    expect(capabilities.mcpExpiryAutoReconnect, isFalse);
  });
}
