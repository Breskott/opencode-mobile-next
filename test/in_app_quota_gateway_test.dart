import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/quota_collector_host.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/quota/provider_quota_client.dart';
import 'package:opencode_mobile/state/profiles.dart';

import 'provider_quota_test.dart' show providerQuotaFixture;

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(providerQuotaFixture()),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ServerProfile _inApp() => ServerProfile(
  id: 'builtin',
  name: 'In-app Ubuntu',
  baseUrl: BuiltinLinux.serverUrl,
  username: 'opencode',
  password: 'basic-fixture-password',
);

ServerProfile _remote() => ServerProfile(
  id: 'remote',
  name: 'Remote',
  baseUrl: 'https://collector.example:8443',
  username: 'fixture-user',
  password: 'basic-fixture-password',
);

void main() {
  test(
    'In-app Ubuntu reads loopback 4195 with the Bearer token only',
    () async {
      final adapter = _Adapter();
      final gateway = HttpProviderQuotaGateway(
        _inApp(),
        adapter: adapter,
        inAppToken: () async =>
            'fixture-read-token-fixture-read-token-fixture-1234',
      );
      addTearDown(gateway.close);
      await gateway.readSnapshot();
      final request = adapter.requests.single;
      expect(request.uri.toString(), 'http://127.0.0.1:4195/ocmn/quota/v1');
      expect(
        request.headers['Authorization'],
        'Bearer fixture-read-token-fixture-read-token-fixture-1234',
      );
      expect(request.headers.toString(), isNot(contains('Basic')));
    },
  );

  test('a remote server keeps its origin and Basic sign-in', () async {
    final adapter = _Adapter();
    final gateway = HttpProviderQuotaGateway(_remote(), adapter: adapter);
    addTearDown(gateway.close);
    await gateway.readSnapshot();
    final request = adapter.requests.single;
    expect(request.uri.origin, 'https://collector.example:8443');
    expect(request.headers['Authorization'], startsWith('Basic '));
  });

  test(
    'In-app Ubuntu without a token says unsupported and sends nothing',
    () async {
      final adapter = _Adapter();
      final gateway = HttpProviderQuotaGateway(
        _inApp(),
        adapter: adapter,
        inAppToken: () async => null,
      );
      addTearDown(gateway.close);
      await expectLater(
        gateway.readSnapshot(),
        throwsA(
          isA<ProviderQuotaFailure>().having(
            (f) => f.kind,
            'kind',
            QuotaFailureKind.unsupported,
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test('only the app\'s own server gets a token reader', () {
    expect(InAppQuotaCollector.tokenReaderFor(_remote()), isNull);
    expect(InAppQuotaCollector.tokenReaderFor(_inApp()), isNotNull);
  });
}
