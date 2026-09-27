import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api2/client.dart';
import 'package:opencode_mobile/api2/gateway_operations.dart';
import 'package:opencode_mobile/api2/transport.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:opencode_mobile/ui/widgets/product_states.dart';

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.status, this.body);

  final int status;
  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Synthetic opaque value deliberately lacks recognizable credential syntax.
  const credential = 'syntheticOpaqueCredentialAuditTwo';
  const serverProse = 'Remote explanation';
  const reason = '$serverProse $credential';

  setUp(() {
    KitRedact.clearKnownSecrets();
    KitRedact.registerKnownSecret(credential);
  });
  tearDown(KitRedact.clearKnownSecrets);

  Future<void> verify(
    Future<Object?> Function() action,
    String authoredBody,
  ) async {
    Object? caught;
    try {
      await action();
    } catch (error) {
      caught = error;
    }
    expect(caught is ProductException, isTrue);
    final body = productErrorText(caught!);
    // Boolean assertions never print the captured transport payload on failure.
    expect(body.contains(credential), isFalse, reason: 'body hides secrets');
    expect(body.contains(serverProse), isFalse, reason: 'body is app authored');
    expect(body, authoredBody);
    final details = productErrorDetails(caught);
    expect(details != null, isTrue, reason: 'technical cause is retained');
    expect(details!.contains(credential), isFalse, reason: 'Details redacts');
    expect(details.contains(serverProse), isTrue);
  }

  test(
    'OpenCode 2 operations keep server prose only in redacted Details',
    () async {
      final transport = Api2Transport(
        baseUrl: 'https://server.test',
        password: '',
      );
      transport.dio.httpClientAdapter = _ResponseAdapter(400, {
        '_tag': 'BadRequestError',
        'message': reason,
      });
      addTearDown(transport.close);
      final gateway = Api2OperationsGateway(
        client: Api2Client(transport: transport),
      );
      await verify(
        () => gateway.backgroundSession('session'),
        'Could not background running work',
      );
    },
  );

  test(
    'OpenCode 1 worktree errors retain cause without trusting its prose',
    () async {
      final api = OpenCodeApi(baseUrl: 'https://server.test');
      api.dio.httpClientAdapter = _ResponseAdapter(400, {
        'name': 'WorktreeNotGitError',
        'data': {'message': reason},
      });
      addTearDown(api.close);
      final repository = SdkProductRepository(api.sdkClient);
      await verify(
        () => repository.listWorktrees(projectDirectory: '/project'),
        'Could not load worktrees',
      );
    },
  );

  for (final status in [400, 200]) {
    test(
      'OpenCode 1 upgrade refusal with HTTP $status keeps a safe body',
      () async {
        final api = OpenCodeApi(baseUrl: 'https://server.test');
        api.dio.httpClientAdapter = _ResponseAdapter(status, {
          'success': false,
          'error': reason,
        });
        addTearDown(api.close);
        final repository = SdkProductRepository(api.sdkClient);
        await verify(
          () => repository.upgradeServer('1.19.0'),
          'Could not upgrade OpenCode',
        );
      },
    );
  }
}
