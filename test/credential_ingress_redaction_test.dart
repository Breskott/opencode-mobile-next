import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api2/client.dart';
import 'package:opencode_mobile/api2/gateway_operations.dart';
import 'package:opencode_mobile/api2/transport.dart';
import 'package:opencode_mobile/diagnostics/report_problem.dart';
import 'package:opencode_mobile/feedback/problem_report.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_field.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secret =
    'audit-opaque-'
    'fixture-9237';
const _changed =
    'audit-updated-'
    'fixture-9238';

class _Http implements HttpClientAdapter {
  Object payload = <String, Object?>{};
  void Function()? beforeReply;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    beforeReply?.call();
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    KitRedact.clearKnownSecrets();
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        {'id': 'audit', 'name': 'Audit', 'baseUrl': 'http://localhost:4096'},
      ]),
    });
    messenger.setMockMethodCallHandler(
      secure,
      (call) async => call.method == 'read' ? _secret : null,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(secure, null);
    KitRedact.clearKnownSecrets();
  });

  test(
    'loaded credential is masked in persisted diagnostics and report',
    () async {
      final store = ProfileStore(prefs: await SharedPreferences.getInstance());
      await store.load();
      final directory = await Directory.systemTemp.createTemp(
        'audit-credential-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final report = await ReportProblem.open(directory: directory);
      addTearDown(report.dispose);
      report.recordError(
        'Rejected credential ${store.profiles.single.password}',
        null,
      );
      final bytes = File(
        '${directory.path}/report_problem.json',
      ).readAsStringSync();
      expect(
        bytes.contains(_secret),
        isFalse,
        reason: 'loaded credential reached disk',
      );
      expect(
        problemReportScrub(report.entries.single.message).contains(_secret),
        isFalse,
        reason: 'loaded credential reached public report',
      );
    },
  );

  test(
    'updated credential is registered before secure storage can fail',
    () async {
      final store = ProfileStore(prefs: await SharedPreferences.getInstance());
      await store.load();
      final profile = store.profiles.single..password = _changed;
      var maskedAtWrite = false;
      messenger.setMockMethodCallHandler(secure, (call) async {
        if (call.method == 'write') {
          maskedAtWrite = !KitRedact.text(
            'Rejected $_changed',
          ).contains(_changed);
          throw PlatformException(code: 'synthetic-storage-refusal');
        }
        return null;
      });
      await expectLater(store.upsert(profile), throwsA(isA<Exception>()));
      expect(
        maskedAtWrite,
        isTrue,
        reason: 'registration must precede failing storage',
      );
    },
  );

  testWidgets('secret entry registers before controller and change callbacks', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var maskedAtListener = false;
    var maskedAtChange = false;
    controller.addListener(() {
      if (controller.text.isNotEmpty) {
        maskedAtListener = !KitRedact.text(controller.text).contains(_secret);
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KitField.secret(
            label: 'Password',
            controller: controller,
            onChanged: (value) =>
                maskedAtChange = !KitRedact.text(value).contains(_secret),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), _secret);
    expect(
      maskedAtListener && maskedAtChange,
      isTrue,
      reason: 'entry must register before downstream capture',
    );
  });

  test('new authenticated transports register passwords before requests', () {
    final v1 = OpenCodeApi(baseUrl: 'http://localhost:4096', password: _secret);
    addTearDown(v1.close);
    expect(KitRedact.text(_secret).contains(_secret), isFalse);
    KitRedact.clearKnownSecrets();
    final v2 = Api2Transport(
      baseUrl: 'http://localhost:4097',
      password: _secret,
    );
    addTearDown(v2.close);
    expect(KitRedact.text(_secret).contains(_secret), isFalse);
  });

  test(
    'provider response credentials register before decoding exposes values',
    () async {
      final api = OpenCodeApi(baseUrl: 'http://localhost:4096');
      addTearDown(api.close);
      api.dio.httpClientAdapter = _Http()
        ..payload = {
          'providers': [
            {
              'id': 'custom',
              'name': 'Custom',
              'key': _secret,
              'options': {'apiKey': _changed},
              'models': {},
            },
          ],
        };
      await api.configuredProviders();
      expect(KitRedact.text(_secret).contains(_secret), isFalse);
      expect(KitRedact.text(_changed).contains(_changed), isFalse);
    },
  );
  for (final v2 in [false, true]) {
    test(
      'submitted provider credential registers before transport v2=$v2',
      () async {
        var registeredBeforeNetwork = false;
        final http = _Http()
          ..beforeReply = () {
            registeredBeforeNetwork = !KitRedact.text(
              _secret,
            ).contains(_secret);
            throw StateError('Synthetic network refusal');
          };
        final api = OpenCodeApi(baseUrl: 'http://localhost:4096');
        final client = Api2Client.connect(
          baseUrl: 'http://localhost:4097',
          password: '',
        );
        addTearDown(api.close);
        addTearDown(client.close);
        api.dio.httpClientAdapter = http;
        client.transport.dio.httpClientAdapter = http;
        final repository = v2
            ? Api2OperationsGateway(client: client)
            : SdkProductRepository(api.sdkClient);
        await expectLater(
          repository.connectIntegrationKey('custom', _secret),
          throwsA(anything),
        );
        expect(
          registeredBeforeNetwork,
          isTrue,
          reason: 'submitted key was not registered',
        );
      },
    );
  }
}
