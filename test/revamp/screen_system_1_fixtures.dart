// Shared set-up for screen-system-1's behaviour and golden tests: a
// connection with a named server and a chosen capability set, the phone
// facts the Keep running page reads, and a few captured errors and timings.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/diagnostics/perf_trace.dart';
import 'package:opencode_mobile/platform/app_exit.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SystemApi extends OpenCodeApi {
  SystemApi(this._capabilities) : super(baseUrl: 'http://localhost');

  final ServerCapabilities _capabilities;

  @override
  ServerCapabilities get capabilities => _capabilities;
}

class SystemRepository implements ProductRepository, UsageStatisticsGateway {
  SystemRepository({this.usageStatisticsSupported = true});

  @override
  final bool usageStatisticsSupported;

  int sends = 0;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<void> writeClientLog({
    required String message,
    Map<String, Object?> extra = const {},
  }) async => sends++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mocks the secure-storage channel ProfileStore.load touches (AGENTS.md).
void mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
}

/// A connected controller for the server "Workstation".
Future<ConnectionController> systemController(
  ServerCapabilities capabilities, {
  bool usageStatistics = true,
}) async {
  mockSecureStorage();
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'profile-1',
        'name': 'Workstation',
        'baseUrl': 'http://localhost:4096',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'profile-1',
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  return ConnectionController(store)
    ..api = SystemApi(capabilities)
    ..repository = SystemRepository(usageStatisticsSupported: usageStatistics)
    ..status = StreamStatus.connected;
}

/// Two handled errors at fixed times, the second repeated.
void recordSampleErrors(ConnectionController controller) {
  final at = DateTime(2026, 9, 27, 9, 41, 5);
  controller.diagnostics
    ..record(
      StateError('Render failed while laying out the transcript'),
      StackTrace.fromString('#0 build (lib/ui/chat.dart:42:3)'),
      source: 'flutter',
      at: at,
    )
    ..record(
      StateError('Event stream closed before the reply ended'),
      StackTrace.fromString('#0 listen (lib/api/sse.dart:88:7)'),
      source: 'sse',
      at: at.add(const Duration(minutes: 3)),
    )
    ..record(
      StateError('Event stream closed before the reply ended'),
      StackTrace.fromString('#0 listen (lib/api/sse.dart:88:7)'),
      source: 'sse',
      at: at.add(const Duration(minutes: 3, seconds: 4)),
    );
}

/// A few timings, one of them failed.
void recordSampleTimings() {
  PerfTrace.clear();
  PerfTrace.logSink = null;
  for (final ms in [120, 7700]) {
    PerfTrace.recordDuration(
      'http GET /session',
      Duration(milliseconds: ms),
      attrs: {'status': 200},
    );
  }
  PerfTrace.recordDuration(
    'sessions.refresh',
    const Duration(milliseconds: 40),
    error: StateError('offline'),
  );
}

/// Answers the Keep running page's bridge calls for a phone by [maker];
/// returns the settings it was asked to open.
List<String> mockKeepAlive({
  required String maker,
  bool battery = false,
  bool opens = true,
}) {
  final opened = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel(AppLifecycleBridge.channelName),
        (call) async {
          switch (call.method) {
            case 'keepAliveInfo':
              return {
                'manufacturer': maker,
                'brand': maker,
                'batteryOptimizationIgnored': battery,
              };
            case 'openKeepAliveSetting':
              opened.add((call.arguments as Map)['setting'] as String);
              return opens;
          }
          return null;
        },
      );
  return opened;
}

void clearKeepAliveMock() => TestDefaultBinaryMessengerBinding
    .instance
    .defaultBinaryMessenger
    .setMockMethodCallHandler(
      const MethodChannel(AppLifecycleBridge.channelName),
      null,
    );
