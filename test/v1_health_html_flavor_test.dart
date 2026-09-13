import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/state/connection.dart';

/// An OpenCode 2 host answers the OpenCode 1 health route with its web UI:
/// HTTP 200, `text/html`. Found live on 2026-09-10 against beta-18600.
class _HtmlAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '<!doctype html><html><body>opencode</body></html>',
    200,
    headers: {
      Headers.contentTypeHeader: ['text/html; charset=utf-8'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('a non-JSON v1 health answer is an ApiException that suggests the '
      'wrong protocol generation, not a raw cast error', () async {
    final api = OpenCodeApi(baseUrl: 'http://127.0.0.1:4097')
      ..dio.httpClientAdapter = _HtmlAdapter();
    Object? caught;
    try {
      await api.health();
    } catch (error) {
      caught = error;
    }
    expect(caught, isA<ApiException>());
    final error = caught! as ApiException;
    expect(error.statusCode, 200);
    expect(error.errorTag, unexpectedHealthShapeTag);
    expect(error.message, contains('text/html'));
    // The connect path must redetect the flavor on this signal, exactly as
    // it does for 401/404/405.
    expect(ConnectionController.suggestsWrongFlavor(error), isTrue);
    expect(
      ConnectionController.suggestsWrongFlavor(
        ApiException('x', statusCode: 500),
      ),
      isFalse,
    );
  });
}
