import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/diagnostics/app_diagnostics.dart';
import 'package:opencode_mobile/diagnostics/perf_trace.dart';
import 'package:opencode_mobile/main.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: 'https://100.64.0.1:4096');

  final healthResult = Completer<Health>();
  int healthCalls = 0;

  @override
  Future<Health> health() {
    healthCalls++;
    return healthResult.future;
  }

  @override
  Future<List<Session>> sessions() async => const [];
  @override
  Future<Map<String, String>> sessionStatuses() async => const {};
  @override
  Future<ProvidersResponse> providers() async =>
      ProvidersResponse(providers: const []);
  @override
  Future<ProvidersResponse> configuredProviders() => providers();
  @override
  Future<List<AgentInfo>> agents() async => const [];
  @override
  Future<List<PermissionRequest>> pendingPermissions() async => const [];
  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));
  @override
  Future<List<Map<String, dynamic>>> pendingQuestionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));
}

class _Operations extends SdkProductRepository {
  _Operations(OpenCodeApi api) : super(api.sdkClient);

  @override
  Future<ChatDefaults> loadChatDefaults() async => const ChatDefaults();
  @override
  Future<List<PendingQuestion>> listQuestions() async => const [];
  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);
  @override
  Future<List<IntegrationInfo>> listIntegrations() async => const [];
}

class _Events extends EventStream {
  _Events({
    required super.api,
    required super.onEvent,
    required super.onStatus,
    super.onError,
  });

  @override
  void start() => onStatus(StreamStatus.connecting);
  void connected() => onStatus(StreamStatus.connected);
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('bootstrap to first connected preserves scripted dependencies', (
    tester,
  ) async {
    const secure = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secure, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(secure, null));
    // Exercise the mobile shell without native bridges or desktop scrollbars.
    debugPlatformCapabilities = const PlatformCapabilities(
      platform: TargetPlatform.android,
      isWeb: true,
    );
    addTearDown(() => debugPlatformCapabilities = null);
    PerfTrace.resetForTesting();
    PerfTrace.logSink = null;
    addTearDown(PerfTrace.resetForTesting);
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        {
          'id': 'perf',
          'name': 'Performance fixture',
          'baseUrl': 'https://100.64.0.1:4096',
          'username': '',
        },
      ]),
      'oc.activeProfile': 'perf',
    });
    final store = ProfileStore(prefs: await SharedPreferences.getInstance());
    await store.load();
    final loaded = Completer<AppBootstrap>();
    final diagnostics = AppDiagnosticsController();
    addTearDown(diagnostics.dispose);
    final api = _Api();
    final streams = <_Events>[];
    late ConnectionController controller;
    final start = tester.binding.clock.now();
    int elapsed() =>
        tester.binding.clock.now().difference(start).inMilliseconds;
    PerfTrace.markOnce('app.main');

    await tester.pumpWidget(
      AppBootstrapGate(
        diagnostics: diagnostics,
        loader: () => loaded.future,
        controllerFactory: (store, diagnostics) {
          controller = ConnectionController(
            store,
            diagnostics: diagnostics,
            apiFactory: (_) => api,
            repositoryFactory: (api) => _Operations(api),
            eventStreamFactory:
                ({required api, required onEvent, required onStatus, onError}) {
                  final stream = _Events(
                    api: api,
                    onEvent: onEvent,
                    onStatus: onStatus,
                    onError: onError,
                  );
                  streams.add(stream);
                  return stream;
                },
          );
          return controller;
        },
      ),
    );
    final firstFrame = elapsed();
    expect(find.byKey(const ValueKey('app-bootstrap-opening')), findsOneWidget);
    expect(api.healthCalls, 0);
    await tester.pump(const Duration(milliseconds: 40));
    loaded.complete(AppBootstrap(store));
    // Migration futures settle before the next shell frame; no fixed wall
    // delay is inferred from these zero-duration test-frame pumps.
    for (var i = 0; i < 5 && api.healthCalls == 0; i++) {
      await tester.pump();
    }
    expect(api.healthCalls, 1);
    final healthStarted = elapsed();
    expect(streams, isEmpty);
    expect(
      PerfTrace.spans.where((s) => s.name == 'app.first_connected'),
      isEmpty,
    );
    await tester.pump(const Duration(milliseconds: 60));
    api.healthResult.complete(Health(healthy: true));
    await tester.pump();
    expect(streams, hasLength(1));
    expect(controller.status, StreamStatus.connecting);
    await tester.pump(const Duration(milliseconds: 20));
    streams.single.connected();
    final connected = elapsed();
    expect(controller.status, StreamStatus.connected);
    expect(
      PerfTrace.spans.where((s) => s.name == 'app.first_connected'),
      hasLength(1),
    );
    debugPrint(
      'PERF_STARTUP_CONNECTION scripted_ms first_frame=$firstFrame '
      'health_started=$healthStarted first_connected=$connected '
      'health_calls=${api.healthCalls} streams=${streams.length}',
    );
    expect(firstFrame, 0);
    expect(healthStarted, 40);
    expect(connected, 120);
    // Home builds each destination on its first visit (slice-speed-ui):
    // the hidden Settings tab no longer runs its own second health read
    // before the event stream connects. Before that change this was 2.
    expect(api.healthCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
