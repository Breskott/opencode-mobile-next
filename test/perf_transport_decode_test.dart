import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api2/transport.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native transport reuses its socket after a short reading pause',
    () async {
      await HttpOverrides.runZoned(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.idleTimeout = const Duration(seconds: 30);
        final ports = <String, Set<int>>{};
        server.listen((request) async {
          final client = request.uri.queryParameters['client']!;
          ports
              .putIfAbsent(client, () => {})
              .add(request.connectionInfo!.remotePort);
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"healthy":true}');
          await request.response.close();
        });
        final root = 'http://${server.address.host}:${server.port}';
        final baseline = Dio(BaseOptions(baseUrl: '$root/api'));
        final transport = Api2Transport(baseUrl: root, password: '');
        try {
          Future<void> requestPair() async {
            final before = await baseline.get<dynamic>(
              '/health',
              queryParameters: {'client': 'baseline'},
            );
            final after = await transport.getJson(
              '/health',
              query: {'client': 'configured'},
            );
            expect(before.data['healthy'], isTrue);
            expect(after['healthy'], isTrue);
          }

          await requestPair();
          await Future<void>.delayed(const Duration(seconds: 4));
          await requestPair();
          expect(ports['baseline'], hasLength(2));
          expect(ports['configured'], hasLength(1));
          // Counts only: no request headers, payloads or credentials in output.
          debugPrint(
            'HOST transport 4s pause: stock=2 TCP connections, configured=1',
          );
        } finally {
          baseline.close(force: true);
          transport.close();
          transport.close();
          expect(transport.isClosed, isTrue);
          await server.close(force: true);
        }
      }, createHttpClient: (_) => _RealHttpOverrides().createHttpClient(null));
    },
  );

  test(
    'existing large JSON decoder preserves data with and without length',
    () async {
      final transport = Api2Transport(
        baseUrl: 'http://localhost',
        password: '',
      );
      addTearDown(transport.close);
      final rows = List.generate(
        2000,
        (index) => {'id': index, 'text': 'tail $index'},
      );
      final payload = jsonEncode(rows);
      expect(utf8.encode(payload).length, greaterThan(50 * 1024));
      for (final withLength in [false, true]) {
        final decoded = await transport.dio.transformer.transformResponse(
          RequestOptions(path: '/sessions', responseType: ResponseType.json),
          ResponseBody.fromString(
            payload,
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
              if (withLength)
                Headers.contentLengthHeader: ['${utf8.encode(payload).length}'],
            },
          ),
        );
        expect(decoded, rows);
      }
    },
  );
}
