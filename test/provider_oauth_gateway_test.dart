// OpenCode 1's provider sign-in over a fake wire: the saved attempt is
// picked up by a new repository after a restart, a callback the server
// refuses (OauthMissing, after its own restart) is a server answer, and a
// cut connection is not.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/server_answer.dart';

class _Wire implements HttpClientAdapter {
  int callbackStatus = 200;
  bool cut = false;
  int callbacks = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object body;
    var status = 200;
    switch (options.path) {
      case '/provider/auth':
        body = {
          'openai': [
            {'type': 'oauth', 'label': 'ChatGPT Pro/Plus (headless)'},
          ],
        };
      case '/provider/openai/oauth/authorize':
        body = {
          'url': 'https://auth.openai.com/codex/device',
          'method': 'auto',
          'instructions': 'Enter code: VPFI-KC2ZK',
        };
      case '/provider/openai/oauth/callback':
        callbacks++;
        if (cut) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'cut',
          );
        }
        status = callbackStatus;
        body = status == 200 ? true : {'name': 'ProviderAuthOauthMissing'};
      default:
        body = {};
        status = 404;
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

SdkProductRepository _repository(_Wire wire, {String base = 'https://a.test'}) {
  final api = OpenCodeApi(baseUrl: base);
  api.dio.httpClientAdapter = wire;
  addTearDown(api.close);
  return SdkProductRepository(api.sdkClient);
}

void main() {
  test('a saved auto attempt is restored by a new repository', () async {
    final wire = _Wire();
    final first = await _repository(wire).startIntegrationOAuth('openai', '0');
    expect(first.mode, IntegrationAuthMode.auto);
    expect(first.instructions, 'Enter code: VPFI-KC2ZK');

    // The app restarted: a fresh repository, same server.
    final restored = _repository(wire);
    restored.restoreIntegrationAuthAttempt(
      integrationID: 'openai',
      attemptID: first.attemptID,
      command: false,
    );
    final status = await restored.integrationOAuthStatus(first.attemptID);
    expect(status.state, IntegrationAuthState.complete);
    expect(wire.callbacks, 1);
  });

  test('an attempt of another server or provider is refused', () async {
    final wire = _Wire();
    final first = await _repository(wire).startIntegrationOAuth('openai', '0');
    expect(
      () => _repository(wire, base: 'https://b.test')
          .restoreIntegrationAuthAttempt(
            integrationID: 'openai',
            attemptID: first.attemptID,
            command: false,
          ),
      throwsA(isA<ProductException>()),
    );
    expect(
      () => _repository(wire).restoreIntegrationAuthAttempt(
        integrationID: 'github-copilot',
        attemptID: first.attemptID,
        command: false,
      ),
      throwsA(isA<ProductException>()),
    );
  });

  test('a refused callback is a server answer, a cut one is not', () async {
    final wire = _Wire();
    final repository = _repository(wire);
    final launch = await repository.startIntegrationOAuth('openai', '0');

    wire.callbackStatus = 400; // OauthMissing after the server restarted
    Object? refused;
    try {
      await repository.integrationOAuthStatus(launch.attemptID);
    } catch (error) {
      refused = error;
    }
    expect(refused, isA<ProductException>());
    expect(errorIsServerAnswer(refused), isTrue);

    wire.cut = true;
    Object? interrupted;
    try {
      await repository.integrationOAuthStatus(launch.attemptID);
    } catch (error) {
      interrupted = error;
    }
    expect(interrupted, isA<ProductException>());
    expect(errorIsServerAnswer(interrupted), isFalse);
  });
}
