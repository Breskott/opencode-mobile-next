import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/widgets/pickers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';

// F2/F6 (docs/qa/emulator-qa-claude-2026-09-28): a cold start saw providers
// that are signed in but not loaded (Anthropic and Google OAuth sign-ins that
// OpenCode 1.18 has no plugin for), disposed the server instance to "heal"
// them, and so aborted a reply that was still running. The transcript then
// said the person stopped it. Disposing never loads those sign-ins, so every
// start repeated the abort, and the picker kept saying "not loaded yet".

class _RealHttpOverrides extends HttpOverrides {}

/// An OpenCode 1 host: `/provider` lists Anthropic as connected (the auth
/// store holds its sign-in), `/config/providers` (the runtime) never loads
/// it, and a reply may be running.
class _Host {
  bool anthropicLoadable = false;
  bool anthropicLoaded = false;
  int running = 0;
  int disposes = 0;

  static final _anthropic = ProviderInfo(
    id: 'anthropic',
    name: 'Anthropic',
    modelIDs: const ['claude-opus'],
  );
  static final _zen = ProviderInfo(
    id: 'opencode',
    name: 'OpenCode Zen',
    modelIDs: const ['big-pickle'],
  );

  ProvidersResponse connected() => ProvidersResponse(
    providers: [_anthropic, _zen],
    defaultProviderID: 'opencode',
    defaultModelID: 'big-pickle',
  );

  ProvidersResponse runtime() =>
      ProvidersResponse(providers: [if (anthropicLoaded) _anthropic, _zen]);

  /// What `SdkProductRepository.refreshProviderRuntime` does against the
  /// server: refuse while a reply runs, otherwise dispose.
  void refreshRuntime() {
    if (running > 0) throw ProviderRuntimeBusyException(running);
    disposes += 1;
    anthropicLoaded = anthropicLoadable;
  }
}

class _HostApi extends OpenCodeApi {
  _HostApi(this.host) : super(baseUrl: 'http://127.0.0.1:1');

  final _Host host;
  final healthResult = Completer<Health>();

  @override
  Future<Health> health() => healthResult.future;

  @override
  Future<List<Session>> sessions() async => const [];

  @override
  Future<Map<String, String>> sessionStatuses() async => {
    if (host.running > 0) 'ses_running': 'busy',
  };

  @override
  Future<ProvidersResponse> providers() async => host.connected();

  @override
  Future<ProvidersResponse> configuredProviders() async => host.runtime();

  @override
  Future<List<AgentInfo>> agents() async => [AgentInfo(name: 'build')];

  @override
  Future<List<PermissionRequest>> pendingPermissions() async => const [];

  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));

  @override
  Future<List<Map<String, dynamic>>> pendingQuestionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));
}

class _Stream extends EventStream {
  _Stream({
    required super.api,
    required super.onEvent,
    required super.onStatus,
    super.onError,
  });

  @override
  void start() => onStatus(StreamStatus.connecting);

  void emit(EventEnvelope event) => onEvent(event);

  @override
  Future<void> dispose() async {}
}

class _HostRepository extends SdkProductRepository {
  _HostRepository(OpenCodeApi api, this.host) : super(api.sdkClient);

  final _Host host;

  @override
  Future<void> refreshProviderRuntime() async => host.refreshRuntime();

  @override
  Future<ChatDefaults> loadChatDefaults() async => const ChatDefaults();

  @override
  Future<List<PendingQuestion>> listQuestions() async => const [];

  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);

  @override
  Future<List<IntegrationInfo>> listIntegrations() async => const [];

  @override
  Future<WorkspaceProject?> loadCurrentProject() async => null;

  @override
  Future<List<WorkspaceProject>> listProjects() async => const [];

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => const [];
}

Future<ProfileStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return ProfileStore(prefs: await SharedPreferences.getInstance());
}

/// One app launch against [host], sharing [store] across launches.
Future<(ConnectionController, List<_Stream>)> _launch(
  WidgetTester tester,
  _Host host,
  ProfileStore store,
) async {
  final apis = <_HostApi>[];
  final streams = <_Stream>[];
  final controller = ConnectionController(
    store,
    apiFactory: (_) {
      final api = _HostApi(host);
      apis.add(api);
      return api;
    },
    repositoryFactory: (api) => _HostRepository(api, host),
    eventStreamFactory:
        ({required api, required onEvent, required onStatus, onError}) {
          final stream = _Stream(
            api: api,
            onEvent: onEvent,
            onStatus: onStatus,
            onError: onError,
          );
          streams.add(stream);
          return stream;
        },
  );
  final connect = controller.connect(
    ServerProfile(id: 'server', name: 'server', baseUrl: 'http://127.0.0.1:1'),
  );
  await tester.pump();
  apis.first.healthResult.complete(Health(healthy: true, version: '1.18.23'));
  await connect;
  await _settle(tester, controller);
  return (controller, streams);
}

Future<void> _settle(
  WidgetTester tester,
  ConnectionController controller,
) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (controller.catalog != null && !controller.catalogLoading) return;
  }
  fail('catalog never finished loading');
}

void main() {
  setUpAll(() => HttpOverrides.global = _RealHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('SdkProductRepository.refreshProviderRuntime', () {
    Future<List<({String method, String path, Map<String, String> query})>> run(
      Future<void> Function(SdkProductRepository repository) body, {
      required Map<String, Object?> Function(Map<String, String> query) status,
      int statusCode = HttpStatus.ok,
    }) async {
      final requests =
          <({String method, String path, Map<String, String> query})>[];
      await HttpOverrides.runZoned(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          await utf8.decoder.bind(request).join();
          requests.add((
            method: request.method,
            path: request.uri.path,
            query: request.uri.queryParameters,
          ));
          request.response.headers.contentType = ContentType.json;
          if (request.uri.path == '/session/status') {
            request.response.statusCode = statusCode;
            request.response.write(
              jsonEncode(status(request.uri.queryParameters)),
            );
          } else if (request.uri.path.startsWith('/api/integration/')) {
            request.response.statusCode = HttpStatus.noContent;
          } else {
            request.response.write('true');
          }
          await request.response.close();
        });
        try {
          final api = OpenCodeApi(
            baseUrl: 'http://${server.address.host}:${server.port}',
          );
          final repository = SdkProductRepository(api.sdkClient)
            ..setLocation(directory: '/work/app', workspace: null);
          await body(repository);
        } finally {
          await server.close(force: true);
        }
      }, createHttpClient: (_) => _RealHttpOverrides().createHttpClient(null));
      return requests;
    }

    test('refuses to dispose while a reply runs in the project', () async {
      final requests = await run(
        (repository) => expectLater(
          repository.refreshProviderRuntime(),
          throwsA(
            isA<ProviderRuntimeBusyException>().having(
              (error) => error.runningReplies,
              'runningReplies',
              1,
            ),
          ),
        ),
        status: (query) => query['directory'] == '/work/app'
            ? {
                'ses_1': {'type': 'busy'},
                'ses_2': {'type': 'idle'},
              }
            : const {},
      );
      expect(
        requests.map((request) => request.path),
        isNot(contains('/instance/dispose')),
      );
    });

    test(
      'counts replies in the server-default instance it would also dispose',
      () async {
        final requests = await run(
          (repository) => expectLater(
            repository.refreshProviderRuntime(),
            throwsA(
              isA<ProviderRuntimeBusyException>().having(
                (error) => error.runningReplies,
                'runningReplies',
                2,
              ),
            ),
          ),
          status: (query) => query.isEmpty
              ? {
                  'ses_a': {'type': 'busy'},
                  'ses_b': {'type': 'retry', 'attempt': 2},
                }
              : const {},
        );
        expect(
          requests.map((request) => request.path),
          isNot(contains('/instance/dispose')),
        );
      },
    );

    test('does not dispose when running replies cannot be read', () async {
      final requests = await run(
        (repository) => expectLater(
          repository.refreshProviderRuntime(),
          throwsA(isA<ProductException>()),
        ),
        status: (_) => const {'message': 'unavailable'},
        statusCode: HttpStatus.internalServerError,
      );
      expect(
        requests.map((request) => request.path),
        isNot(contains('/instance/dispose')),
      );
    });

    test('disposes both instances when nothing runs', () async {
      final requests = await run(
        (repository) => repository.refreshProviderRuntime(),
        status: (_) => {
          'ses_1': {'type': 'idle'},
        },
      );
      expect(requests.map((request) => request.path), [
        '/session/status',
        '/session/status',
        '/instance/dispose',
        '/instance/dispose',
      ]);
    });

    test('a key saved while a reply runs connects without a dispose', () async {
      final requests = await run(
        (repository) => repository.connectIntegrationKey('groq', 'test-key'),
        status: (_) => {
          'ses_1': {'type': 'busy'},
        },
      );
      expect(requests.map((request) => request.path), [
        '/api/integration/groq/connect/key',
        '/auth/groq',
        '/session/status',
        '/session/status',
      ]);
    });
  });

  group('cold start', () {
    testWidgets(
      'with a running reply does not reset the instance; the reload runs '
      'once the reply finishes',
      (tester) async {
        final host = _Host()
          ..running = 1
          ..anthropicLoadable = true;
        final (controller, streams) = await _launch(
          tester,
          host,
          await _store(),
        );

        expect(host.disposes, 0, reason: 'the running reply must continue');
        expect(controller.unloadedProviderIDs, {'anthropic'});
        expect(controller.providerReloadWaitingOn, 1);
        expect(controller.unloadedProvidersUnusable, isFalse);

        // The reply finishes: the held-back reload runs and loads Anthropic.
        host.running = 0;
        streams.last.emit(
          EventEnvelope(
            type: 'session.idle',
            properties: const {'sessionID': 'ses_running'},
          ),
        );
        await _settle(tester, controller);
        await tester.pump(const Duration(milliseconds: 50));
        await _settle(tester, controller);

        expect(host.disposes, 1);
        expect(controller.unloadedProviderIDs, isEmpty);
        expect(controller.providerReloadWaitingOn, 0);
        controller.dispose();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets('sign-ins the server cannot load are not reloaded on every '
        'start and are named as unusable', (tester) async {
      final host = _Host();
      final store = await _store();

      final (first, _) = await _launch(tester, host, store);
      expect(host.disposes, 1, reason: 'one idle refresh is worth trying');
      expect(first.unloadedProviderIDs, {'anthropic'});
      expect(first.unloadedProvidersUnusable, isTrue);
      first.dispose();
      await tester.pump(const Duration(seconds: 1));

      // The next cold start, now with a reply running on the server.
      host.running = 1;
      final (second, _) = await _launch(tester, host, store);
      expect(host.disposes, 1, reason: 'no reset on a later start');
      expect(second.unloadedProviderIDs, {'anthropic'});
      expect(second.unloadedProvidersUnusable, isTrue);
      expect(second.providerReloadWaitingOn, 0);
      second.dispose();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a manual reload while a reply runs waits instead of stopping '
        'it', (tester) async {
      final host = _Host()..anthropicLoadable = true;
      final store = await _store();
      // A previous launch already found Anthropic unloadable.
      await store.setProviderRuntimeUnloadable('server', 'anthropic');
      final (controller, _) = await _launch(tester, host, store);
      expect(host.disposes, 0);
      expect(controller.unloadedProvidersUnusable, isTrue);

      host.running = 2;
      await controller.reloadProviderRuntime();
      expect(host.disposes, 0);
      expect(controller.providerReloadWaitingOn, 2);

      host.running = 0;
      await controller.reloadProviderRuntime();
      await _settle(tester, controller);
      expect(host.disposes, 1);
      expect(controller.unloadedProviderIDs, isEmpty);
      expect(controller.unloadedProvidersUnusable, isFalse);
      expect(controller.providerReloadWaitingOn, 0);
      expect(store.providerRuntimeUnloadable('server'), isNull);
      controller.dispose();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('profile deletion sweeps the remembered set', (tester) async {
      final store = await _store();
      await store.setProviderRuntimeUnloadable(
        'server',
        'anthropic,google',
        directory: '/work/app',
      );
      expect(store.profileScopedPreferenceKeys('server'), hasLength(1));
    });
  });

  group('picker copy', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('says not loaded yet only before a reload was tried', () {
      final fresh = unloadedProvidersNotice(const [
        'Google',
        'Anthropic',
      ], strings: l10n);
      expect(fresh, contains('has not loaded them yet'));

      final unusable = unloadedProvidersNotice(
        const ['Google', 'Anthropic'],
        strings: l10n,
        unusable: true,
      );
      expect(unusable, isNot(contains('not loaded them yet')));
      expect(unusable, contains('Anthropic and Google'));
      expect(unusable, contains('even after a reload'));
    });

    test('names the running replies a reload waits for', () {
      final waiting = unloadedProvidersNotice(
        const ['Anthropic'],
        strings: l10n,
        waitingOnReplies: 2,
      );
      expect(waiting, contains('waits for 2 running replies'));
    });
  });
}
